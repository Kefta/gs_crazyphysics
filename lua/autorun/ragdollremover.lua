-- Ragdoll Crash Catcher for TTT and any other gamemode
-- By Ambro, DarthTealc, and code_gs
-- Run shared (lua/autorun)

-- Config
local EchoFreeze = true         -- Tell players when a body is frozen
local EchoRemove = true         -- Tell players when a body is removed

local FreezeSpeed = 500         -- Velocity ragdoll is frozen at
local RemoveSpeed = 4000        -- Velocity ragdoll is removed at

local FreezeTime = 3            -- Time body is frozen for

if ( GAMEMODE_NAME == "terrortown" ) then
        local IsTTT = true
else
        local IsTTT = false
end
 
local function SetSubPhysMotionEnabled( ent, enable )
        if not IsValid( ent ) then return end
	
        ent:SetVelocity( vector_origin )
	
        if ( not enable ) then
                ent:SetColor( Color( 255, 0, 255, 255 ) )
                if IsValid( ent:GetOwner() ) then
                        if ( IsTTT ) then
                                ent:GetOwner():GetWeapon( "weapon_zm_carry" ):Reset( false )
                        end
                end
        else
                ent:SetColor( Color( 255, 255, 255, 255 ) )
        end
	
        for i = 0, ent:GetPhysicsObjectCount() - 1 do
                local subphys = ent:GetPhysicsObjectNum( i )
                if IsValid( subphys ) then
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
end
 
local function KillVelocity( ent )
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
        if not ( corpse ) then return end
	local dti = CORPSE.dti
	local ply = corpse:GetDTEntity( dti.ENT_PLAYER )
	if not IsValid( ply ) then
		ply = rag:GetNWString("nick", default)
	end
	if not IsValid( ply ) then return end
	ply:SetNWBool( "body_found", true )
	CORPSE.SetFound( corpse, true )
end

function GS_CrashCatch()
        for k, ent in pairs( ents.FindByClass( "prop_ragdoll" ) ) do
                if ( IsValid( ent ) and ent.player_ragdoll ) then
                        local velo = ent:GetVelocity():Length()
			local nick = ent:GetNWString( "nick" )
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
                        elseif ( velo >= FreezeSpeed ) then
                                KillVelocity( ent )
                                ServerLog( "[GS_CRASH] Disabling motion for the body of " .. nick .. " (" .. velo .. ") \n" )
                        end
                end
        end
end
hook.Add( "Think", "GS_CrashCatcher", GS_CrashCatch )
