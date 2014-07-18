-- By Ambro, DarthTealc, and code_gs
-- Run shared (lua/autorun)

local freezespeed = 500
local removespeed = 4000

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
   timer.Simple( 3, function() SetSubPhysMotionEnabled( ent, true ) end )
end

local function IdentifyCorpse( corpse )
        if ( corpse and IsTTT ) then
                local ply = player.GetByUniqueID( corpse.uqid )
                ply:SetNWBool( "body_found", true )
                CORPSE.SetFound( corpse, true )
        end
end

local function CatchCrash()
        for k, ent in pairs( ents.FindByClass( "prop_ragdoll" ) ) do
                if ( IsValid( ent ) ) then
                        if ( ent.player_ragdoll ) then
                                local velo = ent:GetVelocity():Length()
                                if ( velo >= removespeed ) then
                                        ent:Remove()
                                        ServerLog( "[!CRASHCATCHER!] Caught ragdoll entity moving too fast (" .. velo .. "), removing offending ragdoll entity from world.\n" )
                                        local messageToShow = "[!CRASHCATCHER!] A ragdoll was removed to prevent server crashing. It was "
                                        PrintMessage( HUD_PRINTTALK, messageToShow .. ent:GetNWString( "nick" ) .. "'s body." )
                                        if ( CORPSE.GetFound( ent, true ) and IsTTT ) then
                                                IdentifyCorpse( ent )
                                        end
                                elseif velo >= freezespeed then
                                        KillVelocity( ent )
                                        ServerLog( "[!CRASHCATCHER!] Caught ragdoll entity moving too fast (" .. velo .. "), disabling motion. \n" )
                                end
                        end
                end
        end
end )

hook.Add( "Think", "CrashCatcher", CatchCrash )
