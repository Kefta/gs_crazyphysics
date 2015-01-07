-- Ragdoll Crash Catcher for TTT and any other gamemode
-- By Ambro, DarthTealc, TheEMP, and code_gs
-- Run shared (lua/autorun)

-- Config
local EchoFreeze = true         -- Tell players when a body is frozen
local EchoRemove = true         -- Tell players when a body is removed

local FreezeSpeed = 500         -- Velocity ragdoll is frozen at
local RemoveSpeed = 4000        -- Velocity ragdoll is removed at

local FreezeTime = 3            -- Time body is frozen for
-- End config

local IsTTT = false             -- Change to true if the name of your TTT folder is not terrortown, otherwise, leave it false
local bodyfound = false 

hook.Add( "Initialize", "GS_CheckTTT", function()
	if ( GAMEMODE_NAME == "terrortown" ) then 
		IsTTT = true 
		if ( IsValid( GetConVar( "ttt_announce_body_found" ) ) ) then
                        bodyfound = GetConVar( "ttt_announce_body_found" ):GetBool() or true
                else
                        bodyfound = true
                end
	end
end )
 
local function SetSubPhysMotionEnabled( ent, enable )
        if ( not IsValid( ent ) ) then return end
	
        if ( not enable ) then
                ent:SetColor( Color( 255, 0, 255, 255 ) )
                if ( IsTTT and IsValid( ent:GetOwner() ) ) then
                	ent:GetOwner():GetWeapon( "weapon_zm_carry" ):Reset( false )
                end
        else
                ent:SetColor( Color( 255, 255, 255, 255 ) )
        end
	
        for i = 0, ent:GetPhysicsObjectCount() - 1 do
                local subphys = ent:GetPhysicsObjectNum( i )
                if ( IsValid( subphys ) ) then
                        subphys:EnableMotion( enable )
                        if ( not enable ) then
                                subphys:SetVelocity( vector_origin )
                                subphys:SetMass( subphys:GetMass() * 20 )
                        else
                                subphys:SetMass( subphys:GetMass() / 20 )
                                subphys:Wake()
                        end
                end
	end

        ent:SetVelocity( vector_origin )
        ent:SetLocalAngularVelocity( angle_zero )
        
end
 
local function KillVelocity( ent )
	if ( not IsValid( ent ) ) then return end
	
	SetSubPhysMotionEnabled( ent, false )
	
	if ( EchoFreeze ) then 
		PrintMessage( HUD_PRINTTALK, "[GS_CRASH] Body frozen for " .. FreezeTime .. " seconds!" ) 
	end
	
	timer.Simple( FreezeTime, function() 
		SetSubPhysMotionEnabled( ent, true )
		if ( EchoFreeze ) then 
			PrintMessage( HUD_PRINTTALK, "[GS_CRASH] Body unfrozen!" )
		end
	end )
end

local function IdentifyCorpse( corpse )
        if ( not IsValid( corpse ) or CORPSE.GetFound( corpse, true ) ) then return end
        
	local dti = CORPSE.dti
	local ply = corpse:GetDTEntity( dti.ENT_PLAYER )
	local nick = CORPSE.GetPlayerNick( corpse, "" )
	local role = CORPSE.was_role
	
	if ( IsValid( ply ) ) then
		ply:SetNWBool( "body_found", true )
		if ( role == ROLE_TRAITOR ) then
			SendConfirmedTraitors( GetInnocentFilter( false ) )
		end
	end
	
	if ( bodyfound ) then
		local roletext = nil
		local role = CORPSE.was_role
		if ( role == ROLE_TRAITOR ) then
			roletext = "body_found_t"
		elseif ( role == ROLE_DETECTIVE ) then
			roletext = "body_found_d"
		elseif ( role == ROLE_INNOCENT ) then
			roletext = "body_found_i"
		end

		LANG.Msg( "body_found", { finder = "The Server",
		victim = nick,
		role = LANG.Param( roletext ) } )
	end
	CORPSE.SetFound( corpse, true )
	
	for k, vicid in pairs( corpse.kills ) do
		
		local vic = player.GetByUniqueID( vicid )
		
		if IsValid( vic ) and ( not vic:GetNWBool( "body_found", false ) ) then
			LANG.Msg( "body_confirm", { finder = "The Server", victim = vic:Nick() } )
			vic:SetNWBool( "body_found", true )
		end
	end
end

function GS_CrashCatch()
        for k, ent in pairs( ents.FindByClass( "prop_ragdoll" ) ) do
                if ( IsValid( ent ) and ent.player_ragdoll ) then
                        local velo = ent:GetVelocity():Length()
			local nick = ent:GetNWString( "nick", "N/A" )
                        if ( velo >= RemoveSpeed ) then
                                ent:Remove()
				local message = "[GS_CRASH] Removed body of " .. nick .. " for moving too fast"
                                ServerLog( message .. " (" .. velo .. ")\n" )
				if ( EchoRemove ) then
					PrintMessage( HUD_PRINTTALK, message )
				end
                                if ( IsTTT ) then
                                	IdentifyCorpse( ent )
                                end
                                ent:Remove()
                        elseif ( velo >= FreezeSpeed ) then
                                KillVelocity( ent )
                                ServerLog( "[GS_CRASH] Disabling motion for the body of " .. nick .. " (" .. velo .. ") \n" )
                        end
                end
        end
end
hook.Add( "Think", "GS_CrashCatcher", GS_CrashCatch )
