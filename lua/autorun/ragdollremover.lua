-- By Ambro, DarthTealc, and code_gs
-- Run shared

local freezespeed = 500
local removespeed = 4000

local function corpse_identify( corpse )
        if ( corpse ) then
                local ply = player.GetByUniqueID( corpse.uqid )
                ply:SetNWBool( "body_found", true )
                CORPSE.SetFound( corpse, true )
        end
end

hook.Add( "Think", "CrashCatcher", function()
        for k, ent in pairs( ents.FindByClass( "prop_ragdoll" ) ) do
                if ( IsValid( ent ) ) then
                        if ( ent.player_ragdoll ) then
                                local velo = ent:GetVelocity():Length()
                                if ( velo >= removespeed ) then
                                        ent:Remove()
                                        ServerLog( "[!CRASHCATCHER!] Caught ragdoll entity moving too fast (" .. velo .. "), removing offending ragdoll entity from world.\n" )
                                        local messageToShow = "[!CRASHCATCHER!] A ragdoll was removed to prevent server crashing. It was "
                                        if ( CORPSE.GetFound(ent, true) ) then
                                                corpse_identify( ent )
                                        end
                                        PrintMessage( HUD_PRINTTALK, messageToShow .. ent:GetNWString( "nick" ) .. "'s body." )
                                elseif velo >= freezespeed then
                                        KillVelocity( ent )
                                        ServerLog( "[!CRASHCATCHER!] Caught ragdoll entity moving too fast (" .. velo .. "), disabling motion. \n" )
                                end
                        end
                end
        end
end )
 
local function SetSubPhysMotionEnabled( ent, enable )
        if not IsValid( ent ) then return end
   
        ent:SetVelocity( vector_origin )
       
        if ( not enable ) then
                ent:SetColor( Color( 255, 0, 255, 255 ) )
                if IsValid( ent:GetOwner() ) then
                        ent:GetOwner():GetWeapon( "weapon_zm_carry" ):Reset( false )
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
 
local function AMB_KillVelocity( ent )
   SetSubPhysMotionEnabled( ent, false )
   timer.Simple( 3, function() SetSubPhysMotionEnabled( ent, true ) end )
end
