-- Entity Crash Catcher
-- This script detects entities that are moving too fast or falling out of the world, leading to a potential server crash
-- By code_gs, Ambro, DarthTealc, TheEMP, and LuaTenshi
-- GitHub: https://github.com/Kefta/Entity-Crash-Catcher
-- Facepunch: http://facepunch.com/showthread.php?t=1347114

-- Config
local EchoFreeze	= false		-- Tell players when a body is frozen
local EchoRemove	= false		-- Tell players when a body is removed

local FreezeSpeed	= 2000		-- Velocity ragdoll is frozen at; make greater than RemoveSpeed if you want to disable freezing
local RemoveSpeed	= 4000		-- Velocity ragdoll is removed at

local FreezeTime	= 1       	-- Time body is frozen for
local ThinkDelay	= 0.5     	-- How often the server should check for bad ragdolls; change to 0 to run every Think

local VelocityHook = true		-- Check entities for unreasonable velocity	
local UnreasonableHook = true		-- Check entities for unreasonable positions
-- End config

local IsTTT = false			-- Internal variable for detecting TTT
--[[
MAX_COORD = 16000
MIN_COORD = -MAX_COORD
MAX_ANGLE = 16000
MIN_ANGLE = -MAX_ANGLE
COORD_EXTENT = 2*MAX_COORD
MAX_TRACE_LENGTH = math.sqrt(3)*COORD_EXTENT
]]--
local MAX_REASONABLE_COORD = 15000
local MAX_REASONABLE_ANGLE = 15000
local MIN_REASONABLE_COORD = -MAX_REASONABLE_COORD
local MIN_REASONABLE_ANGLE = -MAX_REASONABLE_ANGLE

hook.Add( "PostGamemodeLoaded", "GS - CheckTTT", function()
	if ( GAMEMODE_NAME == "terrortown" or engine.ActiveGamemode() == "terrortown" ) then
		IsTTT = true
	end
end )

local function KillVelocity( ent )
	if ( not IsValid( ent ) ) then return end
	
	local oldcolor = ent:GetColor() or Color( 255, 255, 255, 255 )
	local newcolor = Color( 255, 0, 255, 255 )
	
	ent:SetColor( newcolor )
	ent:SetVelocity( vector_origin )
	
	for i = 0, ent:GetPhysicsObjectCount() - 1 do
		local subphys = ent:GetPhysicsObjectNum( i )
		if ( IsValid( subphys ) ) then
			subphys:EnableMotion( false )
			subphys:SetMass( subphys:GetMass() * 20 )
			subphys:SetVelocity( vector_origin )
		end
	end
	
	timer.Simple( FreezeTime, function()
		if ( not IsValid( ent ) ) then return end
		for i = 0, ent:GetPhysicsObjectCount() - 1 do
			local subphys = ent:GetPhysicsObjectNum( i )
			if ( IsValid( subphys ) ) then
				subphys:SetMass( subphys:GetMass() / 20 )
				subphys:EnableMotion( true )
				subphys:Wake()
			end
		end
		
		ent:SetColor( oldcolor )
	end )
end

local function IdentifyCorpse( ent )
	if ( not IsValid( ent ) or not CORPSE or not CORPSE.GetFound or CORPSE.GetFound( ent, false ) ) then return end -- Thanks no ragdoll metatable
	
	local dti = CORPSE.dti
	local ply = ent:GetDTEntity( dti.ENT_PLAYER ) or player.GetByUniqueID( ent.uqid )
	local nick = CORPSE.GetPlayerNick( ent, nil ) or ply:Nick() or "N/A"
	local role = ent.was_role or ( ply.GetRole and ply:GetRole() ) or ROLE_INNOCENT
	
	if ( IsValid( ply ) ) then
		ply:SetNWBool( "body_found", true )
		if ( role == ROLE_TRAITOR ) then
			SendConfirmedTraitors( GetInnocentFilter( false ) )
		end
	end
	
	local bodyfound = true
	
	if ( IsValid( GetConVar( "ttt_announce_body_found" ) ) ) then
		bodyfound = GetConVar( "ttt_announce_body_found" ):GetBool()
	end
	
	local roletext = "body_found_i"
	
	if ( bodyfound ) then
		if ( role == ROLE_TRAITOR ) then
			roletext = "body_found_t"
		elseif ( role == ROLE_DETECTIVE ) then
			roletext = "body_found_d"
		end
		
		LANG.Msg( "body_found", { finder = "The Server", victim = nick, role = LANG.Param( roletext ) } )
	end
	
	CORPSE.SetFound( ent, true )
	
	for _, vicid in pairs( ent.kills ) do
		local vic = player.GetByUniqueID( vicid )
		if ( IsValid( vic ) and not vic:GetNWBool( "body_found", false ) ) then
			LANG.Msg( "body_confirm", { finder = "The Server", victim = vic:Nick() or vic:GetClass() } )
			vic:SetNWBool( "body_found", true )
		end
	end
end

if ( VelocityHook or UnreasonableHook ) then
	local NextThink = 0
	
	hook.Add( "Think", "GS - Check Velocity", function()
		if ( NextThink > CurTime() ) then return end
		
		NextThink = CurTime() + ThinkDelay
		
		local pos
		local velo
		local nick
		local ent
		local rMessage = "[GS] Removed %s for moving too fast"
		local fMessage = "[GS] Froze %s for moving too fast"
		local veloMessage = " (%f)\n"
		local tempMessage
		local nickString = "nick" -- Don't run StringBuilder everytime
		
		for i = 0, #EntList do
			ent = EntList[i]
			if ( IsValid( ent ) ) then
				if ( UnreasonableHook ) then
					--[[local ang = ent:GetAngles() -- Need to do some more testing before I want to check for these
					if ( not util.IsReasonable( ang ) ) then
						ent:SetAngles( ang.p % 360, ang.y % 360, ang.r % 360 )
					end]]
					
					pos = ent:GetPos()
					
					if ( isnan( pos:Length() ) or not util.IsReasonable( pos ) ) then
						ent:Remove() -- Just remove the entity, no use trying to find somewhere to put them
					end
				end
				
				if ( VelocityHook ) then
					velo = ent:GetVelocity():Length()
					
					if ( velo >= RemoveSpeed ) then
						nick = ent:GetNWString( nickString, ent:GetClass() )
						if ( IsTTT ) then
							IdentifyCorpse( ent )
						end
						
						ent:Remove()
						
						tempMessage = string.format( rMessage, nick )
						ServerLog( tempMessage .. string.format( veloMessage, velo ) )
						if ( EchoRemove ) then
							PrintMessage( HUD_PRINTTALK, tempMessage )
						end
						
						return -- Don't use a removed ent anymore
					elseif ( velo >= FreezeSpeed ) then
						ent:CollisionRulesChanged()
						nick = ent:GetNWString( nickString, ent:GetClass() )
						KillVelocity( ent )
						
						tempMessage = string.format( rMessage, nick )
						ServerLog( tempMessage .. string.format( veloMessage, velo ) )
						if ( EchoFreeze ) then
							PrintMessage( HUD_PRINTTALK, tempMessage )
						end
					end
				end
			else
				EntList[i] = nil -- Entity is now invalid, but it didn't call EntityRemoved for some reason
			end
		end
	end )
end

function util.IsReasonable( struct )
	--if ( isvector( struct ) ) then
		if( struct.x >= MAX_REASONABLE_COORD or struct.x <= MIN_REASONABLE_COORD or 
			struct.y >= MAX_REASONABLE_COORD or struct.y <= MIN_REASONABLE_COORD or 
			struct.z >= MAX_REASONABLE_COORD or struct.y <= MIN_REASONABLE_COORD ) then
			return false
		end
	--[[elseif ( isangle( struct ) ) then
		if( struct.p >= MAX_REASONABLE_ANGLE or struct.p <= MIN_REASONABLE_ANGLE or 
			struct.y >= MAX_REASONABLE_ANGLE or struct.y <= MIN_REASONABLE_ANGLE or 
			struct.r >= MAX_REASONABLE_ANGLE or struct.r <= MIN_REASONABLE_ANGLE ) then
			return false
		end
	else
		error( string.format( "Invalid data type sent into util.IsReasonable ( Vector or Angle expected, got %s )", type( struct ) ) )
	end]]
	
	return true
end

local UnreasonableEnts =
{
	[ "prop_physics" ] = true,
	[ "prop_ragdoll" ] = true
}

local EntList = {}
local EntIDs = {}

hook.Add( "OnEntityCreated", "GS - Create Soft Entity List", function( ent )
	if ( not ( ent:IsValid() and UnreasonableEnts[ ent:GetClass() ] )) then return end
	
	EntIDs[ ent:EntIndex() ] = table.insert( EntList, ent )
end )

hook.Add( "EntityRemoved", "GS - Remove Soft Entity List", function( ent )
	EntList[ table.remove( EntIDs, ent:EntIndex() ) ] = nil
end )

function ents.GetUnreasonables()
	return EntList
end

function isnan( num )
	-- NaN can't ever be equal to itself; thanks Meepen and MetaMan!
	if ( num == num ) then
		return false
	end
	
	return true
end
