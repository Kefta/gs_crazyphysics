if ( CLIENT ) then return end
-- Ragdoll crash catcher for all gamemodes
-- By Ambro, DarthTealc, TheEMP, and code_gs
-- https://github.com/Kefta/Ragdoll-Remover
-- http://facepunch.com/showthread.php?t=1347114
-- Run serverside (lua/autorun/server/ragdollremover.lua)

-- Config
local EchoFreeze	= true		-- Tell players when a body is frozen
local EchoRemove	= true		-- Tell players when a body is removed

local FreezeSpeed	= 2000		-- Velocity ragdoll is frozen at; this should always be less than RemoveSpeed
local RemoveSpeed	= 4000		-- Velocity ragdoll is removed at; this should always be greater than FreezeSpeed

local FreezeTime	= 1 		-- Time body is frozen for
local ThinkDelay	= 0.5		-- How often the server should check for bad ragdolls; change to 0 to run every Think

local UnreasonableHook	= false		-- Check all entities for unreasonable angles/positions; expensive hook
local NaNCheck		= false		-- Check and attempt to remove any ragdolls that have NaN/inf positions
-- End config

local IsTTT 		= false		-- Do not change unless your TTT folder is not called terrortown

local UnreasonableAngle = 16000
local UnreasonablePosition = 16000

hook.Add( "PostGamemodeLoaded", "GS - Check TTT", function()
	if ( GAMEMODE_NAME == "terrortown" ) then
		IsTTT = true
	end
	
	if ( FreezeSpeed > RemoveSpeed ) then
		local placeholder = FreezeSpeed
		RemoveSpeed = FreezeSpeed
		FreezeSpeed = placeholder
	elseif ( FreezeSpeed == RemoveSpeed ) then
		if ( FreezeSpeed <= 1500 ) then
			RemoveSpeed = RemoveSpeed + 500
		else
			FreezeSpeed = FreezeSpeed - 500
		end
	end
	if ( FreezeTime <= 0 ) then
		FreezeTime = 1
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
	local role = ent.was_role or ply:GetRole()
	
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
	
	local roletext
	
	if ( bodyfound ) then
		if ( role == ROLE_TRAITOR ) then
			roletext = "body_found_t"
		elseif ( role == ROLE_DETECTIVE ) then
			roletext = "body_found_d"
		elseif ( role == ROLE_INNOCENT ) then
			roletext = "body_found_i"
		end
		
		if ( roletext ) then
			LANG.Msg( "body_found", { finder = "The Server", victim = nick, role = LANG.Param( roletext ) } )
		end
	end
	
	CORPSE.SetFound( ent, true )
	
	for _, vicid in pairs( ent.kills ) do
		local vic = player.GetByUniqueID( vicid )
		if ( IsValid( vic ) and not vic:GetNWBool( "body_found", false ) ) then
			LANG.Msg( "body_confirm", { finder = "The Server", victim = vic:Nick() or "N/A" } )
			vic:SetNWBool( "body_found", true )
		end
	end
end

local NextThink = 0

hook.Add( "Think", "GS - Ragdoll Crash Catcher", function()
	if ( NextThink > CurTime() ) then return end
	
	NextThink = CurTime() + ThinkDelay
	
	for _, ent in ipairs( ents.FindByClass( "prop_ragdoll" ) ) do
		if ( IsValid( ent ) ) then
			if ( NaNCheck ) then
				local pos = tostring( ent:GetPos().x )
			
				if ( pos == "nan" or pos == "inf" or pos == "-nan" or pos == "-inf" ) then 
					ent:Remove()
					continue
				end
			end
			
			local velo = ent:GetVelocity():Length()
			
			if ( velo >= RemoveSpeed ) then
				local nick = ent:GetNWString( "nick", "N/A" )
				if ( IsTTT ) then
					IdentifyCorpse( ent )
				end
				ent:Remove()
				local message = "[GS_CRASH] Removed body of " .. nick .. " for moving too fast"
				ServerLog( message .. " (" .. velo .. ")\n" )
				if ( EchoRemove ) then
					PrintMessage( HUD_PRINTTALK, message )
				end
			elseif ( velo >= FreezeSpeed ) then
				ent:CollisionRulesChanged()
				local nick = ent:GetNWString( "nick", "N/A" )
				KillVelocity( ent )
				local message = "[GS_CRASH] Froze body of " .. nick .. " for moving too fast"
				ServerLog( message .. " (" .. velo .. ") \n" )
				if ( EchoFreeze ) then
					PrintMessage( HUD_PRINTTALK, message )
				end
			end
		end
	end
end )

if ( UnreasonableHook ) then
	do 
		local NextThink = 0
	
		hook.Add( "Think", "GS - Unreasonable Position Remover", function()
			if ( NextThink > CurTime() ) then return end
	
			NextThink = CurTime() + ThinkDelay
		
			for _, ent in ipairs( ents.GetAll() ) do
				if ( IsValid( ent ) ) then
					local angles = ent:GetAngles()
					if ( angles.x >= UnreasonableAngle ) then
						angles.x = angles.x % 360
					end
					if ( angles.y >= UnreasonableAngle ) then
						angles.y = angles.y % 360
					end
					if ( angles.z >= UnreasonableAngle ) then
						angles.z = angles.z % 360
					end
					
					local pos = ent:GetPos()
					if ( pos.x >= UnreasonablePosition or pos.y >= UnreasonablePosition or pos.z >= UnreasonablePosition ) then
						if ( ent:IsPlayer() or ent:IsNPC() ) then
							ent:SetPos( vector_origin )
						else
							ent:Remove()
						end
					end
				end
			end
		end )
	end
end
