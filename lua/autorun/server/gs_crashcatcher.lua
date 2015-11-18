--Entity Crash Catcher
--Detects entities that are either going to fast or have invalid positions, and stops them from crashing the server.
-- By code_gs, Ambro, DarthTealc, TheEMP
-- GitHub: https://github.com/Kefta/Entity-Crash-Catcher
-- Facepunch thread: http://facepunch.com/showthread.php?t=1347114
-- This script is also implemented into pLib: https://github.com/SuperiorServers/plib_v2

-- Config
local EchoFreeze	= false		-- Tell players when a body is frozen
local EchoRemove	= false		-- Tell players when a body is removed

local FreezeSpeed	= 2000		-- Velocity ragdoll is frozen at; make greater than RemoveSpeed if you want to disable freezing
local RemoveSpeed	= 4000		-- Velocity ragdoll is removed at

local FreezeTime	= 1       	-- Time body is frozen for
local ThinkDelay	= 0.5     	-- How often the server should check for bad ragdolls; change to 0 to run every Think

local VelocityHook = true		-- Check entities for unreasonable velocity	
local UnreasonableHook = true		-- Check entities for unreasonable angles/positions
local NaNCheck = false			-- Check and attempt to remove any ragdolls that have NaN/inf positions
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
local MAX_REASONABLE_COORD = 15950
local MAX_REASONABLE_ANGLE = 15950
local MIN_REASONABLE_COORD = -MAX_REASONABLE_COORD
local MIN_REASONABLE_ANGLE = -MAX_REASONABLE_ANGLE

hook.Add( "PostGamemodeLoaded", "physics.CheckTTT", function()
	if ( GAMEMODE_NAME == "terrortown" or ( CORPSE and CORPSE.Create ) ) then
		IsTTT = true
	end
end )

local function KillVelocity( ent )
	if ( not IsValid( ent ) ) then return end
	
	local oldcolor = ent:GetColor() or Color( 255, 255, 255, 255 )
	local newcolor = Color( 255, 0, 255, 255 )
	ent:SetColor( newcolor )
	
	ent:SetVelocity( vector_origin )
	
	if ( IsTTT and IsValid( ent:GetOwner() ) ) then
		ent:GetOwner():GetWeapon( "weapon_zm_carry" ):Reset( false )
	end
	
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
	if ( not IsValid( ent ) or not CORPSE or CORPSE.GetFound( ent, false ) ) then return end
	
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
	
	local InvalidStrings =
	{
		["nan"] = true,
		["inf"] = true,
		["-inf"] = true,
		["-nan"] = true
	}
	
	hook.Add( "Think", "physics.Unreasonable", function()
		if ( NextThink > CurTime() ) then return end
		
		NextThink = CurTime() + ThinkDelay
		
		local ents = ents.GetUnreasonables()
		local ent
		
		for i = 1, #ents do
			ent = ents[i]
			if ( IsValid( ent ) ) then
				if ( NaNCheck ) then
					local pos = ent:GetPos()
					if ( InvalidStrings[tostring( pos.x )] or InvalidStrings[tostring( pos.y )] or InvalidStrings[tostring( pos.z )] ) then
						ent:Remove()
						continue
					end
					local ang = ent:GetAngles()
					if ( InvalidStrings[tostring( ang.p )] or InvalidStrings[tostring( ang.y )] or InvalidStrings[tostring( ang.r )] ) then
						ent:Remove()
						continue
					end
				end
				
				if ( VelocityHook ) then
					local velo = ent:GetVelocity():Length()
					
					if ( velo >= RemoveSpeed ) then
						local nick = ent:GetNWString( "nick", ent:GetClass() )
						if ( IsTTT and ent:IsPlayer() ) then
							IdentifyCorpse( ent )
						end
						ent:Remove()
						local message = "[GS] Removed " .. nick .. " for moving too fast"
						ServerLog( message .. " (" .. velo .. ")\n" )
						if ( EchoRemove ) then
							PrintMessage( HUD_PRINTTALK, message )
						end
					elseif ( velo >= FreezeSpeed ) then
						ent:CollisionRulesChanged()
						local nick = ent:GetNWString( "nick", ent:GetClass() )
						KillVelocity( ent )
						local message = "[GS] Froze " .. nick .. " for moving too fast"
						ServerLog( message .. " (" .. velo .. ") \n" )
						if ( EchoFreeze ) then
							PrintMessage( HUD_PRINTTALK, message )
						end
					end
				end
				
				if ( UnreasonableHook ) then
					local ang = ent:GetAngles()
					if ( not util.IsReasonable( ang ) ) then
						ent:SetAngles( ang.p % 360, ang.y % 360, ang.r % 360 )
					end
				
					local pos = ent:GetPos()
					if ( not util.IsReasonable( pos ) ) then
						if ( ent:IsPlayer() or ent:IsNPC() ) then
							ent:SetPos( vector_origin )
						else
							ent:Remove()
						end
					end
				end
			end
		end
	end )
end

function util.IsReasonable( struct )
	if ( isvector( struct ) ) then
		if( struct.x >= MAX_REASONABLE_COORD or struct.x <= MIN_REASONABLE_COORD or 
			struct.y >= MAX_REASONABLE_COORD or struct.y <= MIN_REASONABLE_COORD or 
			struct.z >= MAX_REASONABLE_COORD or struct.y <= MIN_REASONABLE_COORD ) then
			return false
		end
	elseif ( isangle( struct ) ) then
		if( struct.p >= MAX_REASONABLE_ANGLE or struct.p <= MIN_REASONABLE_ANGLE or 
			struct.y >= MAX_REASONABLE_ANGLE or struct.y <= MIN_REASONABLE_ANGLE or 
			struct.r >= MAX_REASONABLE_ANGLE or struct.r <= MIN_REASONABLE_ANGLE ) then
			return false
		end
	else
		error( string.format( "Invalid data type sent into util.IsReasonable ( Vector or Angle expected, got %s )", type( struct ) ) )
	end
	
	return true
end

local UnreasonableEnts =
{
	[ "prop_physics" ] = true,
	[ "prop_ragdoll" ] = true
}

function ents.GetUnreasonables()
	local ParedEnts = {}
	local AllEnts = ents.GetAll()
	
	for i = 1, #AllEnts do
		if ( UnreasonableEnts[ AllEnts[i]:GetClass() ] or AllEnts[i]:IsPlayer() or AllEnts[i]:IsNPC() ) then
			ParedEnts[#ParedEnts + 1] = AllEnts[i]
		end
	end
	
	return ParedEnts
end
