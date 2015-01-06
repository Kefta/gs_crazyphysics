-- Ragdoll Crash Catcher for TTT and any other gamemode
-- By Ambro, DarthTealc, and code_gs
-- Run shared (lua/autorun)

-- Config
local EchoFreeze = true         -- Tell players when a body is frozen
local EchoRemove = true         -- Tell players when a body is removed

local FreezeSpeed = 500         -- Velocity ragdoll is frozen at
local RemoveSpeed = 4000        -- Velocity ragdoll is removed at

local FreezeTime = 3            -- Time body is frozen for

local IsTTT = false

hook.Add("InitPostEntity","CheckForTTT", function() -- This is something I'm not quite sure about, but we may run into an issue that when the file is loaded the TTT gamemode hasn't been loaded. This insures that we check after everything has been loaded.
	IsTTT = GAMEMODE_NAME == "terrortown" and true or false
end)
IsTTT = GAMEMODE_NAME == "terrortown" and true or false
 
local entMeta = FindMetaTable("Entity") -- Why? Both ways work but I think the looks cleaner :P

function entMeta:SetSubPhysMotion( enable )
	if not IsValid( self ) then return end
	
	if ( not enable ) then
		self:SetColor( Color( 255, 0, 255, 255 ) )
		if IsValid( self:GetOwner() ) and IsTTT then
			self:GetOwner():GetWeapon( "weapon_zm_carry" ):Reset( false )
		end
	else
		self:SetColor( Color( 255, 255, 255, 255 ) )
	end
	
	for i = 0, self:GetPhysicsObjectCount() - 1 do
		local subphys = self:GetPhysicsObjectNum( i )
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
	self:SetVelocity( vector_origin )
end
 
local function KillVelocity( ent )
	if not IsValid(ent) then return end
	
	ent:SetSubPhysMotion(false)
	
	if ( EchoFreeze ) then 
		PrintMessage( HUD_PRINTTALK, "[GS_CRASH] Body frozen for " .. FreezeTime .. " seconds!" ) 
	end
	
	timer.Simple(FreezeTime, function()
		if IsValid(ent) then -- Just in case
			ent:SetSubPhysMotion(true)
			if ( EchoFreeze ) then 
				PrintMessage( HUD_PRINTTALK, "[GS_CRASH] Body unfrozen!" )
			end
		end
	end)
end

local bodyfound = GetConVar("ttt_announce_body_found", "1")

local function IdentifyCorpse( corpse )
	if not IsValid(corpse) or CORPSE.GetFound(corpse, false) then return end
	
	local dti = CORPSE.dti
	local ply = corpse:GetDTEntity( dti.ENT_PLAYER )
	local nick = CORPSE.GetPlayerNick(corpse, "")
	local traitor = (corpse.was_role == ROLE_TRAITOR)
	
	if IsValid(ply) then
		ply:SetNWBool("body_found", true)
		if traitor then
			-- update innocent's list of traitors
			SendConfirmedTraitors(GetInnocentFilter(false))
		end
	end
	
	if bodyfound:GetBool() then
		local roletext = nil
		local role = corpse.was_role
		if role == ROLE_TRAITOR then
			roletext = "body_found_t"
		elseif role == ROLE_DETECTIVE then
			roletext = "body_found_d"
		else
			roletext = "body_found_i"
		end

		LANG.Msg("body_found", {finder = "The Server",
		victim = nick,
		role = LANG.Param(roletext)})
	end
	CORPSE.SetFound( corpse, true )
	
	-- Handle kill list
	for k, vicid in pairs(corpse.kills) do
		-- filter out disconnected
		local vic = player.GetByUniqueID(vicid)
		-- is this an unconfirmed dead?
		if IsValid(vic) and (not vic:GetNWBool("body_found", false)) then
			LANG.Msg("body_confirm", {finder = "The Server", victim = vic:Nick()})

			-- update scoreboard status
			vic:SetNWBool("body_found", true)
		end
	end
end

function GS_CrashCatch()
    for k, ent in pairs( ents.FindByClass( "prop_ragdoll" ) ) do
		if (IsValid( ent ) and ent.player_ragdoll) then
			local velo = ent:GetVelocity():Length()
			local nick = ent:GetNWString( "nick", "N/A" )
			
			if ( velo >= RemoveSpeed ) then
				local message = "[GS_CRASH] Removed body of " .. nick .. " for moving too fast"
				ServerLog( message .. " (" .. velo .. ")\n" )
				if ( EchoRemove ) then
					PrintMessage( HUD_PRINTTALK, message )
				end
				
				if ( IsTTT ) then
					IdentifyCorpse( ent )
				end
				ent:Remove() -- Remove the Ragdoll after we ID it, just in case that it's not valid when we try to id it.
			elseif ( velo >= FreezeSpeed ) then
				KillVelocity( ent )
				ServerLog( "[GS_CRASH] Disabling motion for the body of " .. nick .. " (" .. velo .. ") \n" )
			end
		end
	end
end
hook.Add( "Think", "GS_CrashCatcher", GS_CrashCatch )
