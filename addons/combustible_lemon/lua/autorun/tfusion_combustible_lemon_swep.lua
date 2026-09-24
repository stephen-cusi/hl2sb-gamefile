--///// Sound scripts

sound.Add({
	name = "TFusion_CombustibleLemonSWEP.PullPin",
	channel = CHAN_ITEM,
	volume = 1.0,
	sound = "weapons/tfusion/dumbthings/combustible_lemon_swep/pullpin.wav"
})
sound.Add({
	name = "TFusion_CombustibleLemonSWEP.Throw1",
	channel = CHAN_ITEM,
	volume = 1.0,
	pitch = {95, 107},
	sound = "weapons/tfusion/dumbthings/combustible_lemon_swep/throw1.wav"
})
sound.Add({
	name = "TFusion_CombustibleLemonSWEP.Throw2",
	channel = CHAN_ITEM,
	volume = 1.0,
	pitch = {95, 107},
	sound = "weapons/tfusion/dumbthings/combustible_lemon_swep/throw2.wav"
})
sound.Add({
	name = "TFusion_CombustibleLemonSWEP.Detonate",
	channel = CHAN_STATIC,
	level = 85,
	volume = 1.0,
	pitch = {90, 115},
	sound = "weapons/tfusion/dumbthings/combustible_lemon_swep/detonate.wav"
})



--///// Particle systems

game.AddParticles("particles/tfusion/archanor_rfs_binary2.pcf")
PrecacheParticleSystem("tfusion_fire_field_base")
PrecacheParticleSystem("tfusion_fire_field_flat")
PrecacheParticleSystem("tfusion_fire_field_smoke")
PrecacheParticleSystem("tfusion_fire_field_glow")
PrecacheParticleSystem("tfusion_fire_field_simple_embers")
PrecacheParticleSystem("tfusion_fire_field_full")
PrecacheParticleSystem("tfusion_fire_explosion_directional_base")
PrecacheParticleSystem("tfusion_fire_explosion_directional_flat_fire")
PrecacheParticleSystem("tfusion_fire_explosion_directional_glow")
PrecacheParticleSystem("tfusion_fire_explosion_directional_smoke_up")
PrecacheParticleSystem("tfusion_fire_explosion_directional_smoke_radial")
PrecacheParticleSystem("tfusion_fire_explosion_directional_blast_embers")
PrecacheParticleSystem("tfusion_fire_explosion_directional_full")
PrecacheParticleSystem("tfusion_fire_explosion_directional_noground")



--///// Ammo types

hook.Add("Initialize", "Initialize_CombustibleLemonSwep", function()
	game.AddAmmoType({
		name = "tfusion_combustible_lemon",
		dmgtype = DMG_BURN
	})
	if CLIENT then
		language.Add("tfusion_combustible_lemon_ammo", "Combustible Lemon")
	end
end)



--///// Cvars

CreateConVar("CombustibleLemonSwep_AllowCaveJohnsonVO",
	1,
	FCVAR_ARCHIVE + FCVAR_REPLICATED,
	"Serverside cvar. Enables/disables the ability to play Cave Johnson's rant about lemons while holding the Combustible Lemon SWEP. 0 = disable, 1 = enable.",
	0,
	1
)

CreateClientConVar("CombustibleLemonSwep_ExplosionDynamicLight",
	1,
	true,
	false,
	"Clientside cvar. Enables/disables the explosion effect's dynamic light. 0 = disable, 1 = enable. Disable to improve performance.",
	0,
	1
)

CreateClientConVar("CombustibleLemonSwep_CaveJohnsonVOVolume",
	1,
	true,
	false,
	"Clientside cvar. Sets the volume of the Cave Johnson lemon rant voice-over. Example values: 1.0 = 100% volume, 0.5 = 50% volume, 0 = 0% volume (full mute).",
	0,
	1
)



--///// Handler for dropping live combustible lemons on player death

if SERVER then

	local LastPlayerSwepInfo = {}
	
	hook.Add("Tick", "Tick_CombustibleLemonSwep_DropOnDeath", function()
		for _, p in ipairs(player.GetAll()) do
			LastPlayerSwepInfo[p] = nil
			if (IsValid(p) and p:Alive()) then
				local wep = p:GetActiveWeapon()
				if (IsValid(wep)) then
					if (wep:GetClass() == "tfusion_combustible_lemon") then
						LastPlayerSwepInfo[p] = {
							S = wep:GetState(),
							DI = wep._NextThrowDetonateOnImpact,
							FT = wep._NextThrowFuseTime,
							FS = wep._FuseStartTime,
							FD = wep._FuseDuration,
						}
					end
				end
			end
		end
	end)
	
	-- Player weapons are partially disposed by the time this hook is called, which is why we have the previous hook tracking the weapon state from the previous game tick
	hook.Add("PostPlayerDeath", "PostPlayerDeath_CombustibleLemonSwep_DropOnDeath", function(victim, inflictor, attacker)
		if (IsValid(victim)) then
			local wep = victim:GetActiveWeapon()
			if (IsValid(wep)) then
				if (wep:GetClass() == "tfusion_combustible_lemon") then
					local lastSwepInfo = LastPlayerSwepInfo[victim]
					if (lastSwepInfo ~= nil) then
						if (lastSwepInfo.S == 2) then -- pin pulled, player was cooking nade before they died
							
							local proj = ents.Create("tfusion_combustible_lemon_projectile")
							if (IsValid(proj) == false) then return end -- this shouldn't happen, but just in case
							
							proj:SetPos(victim:GetShootPos())
							proj:SetAngles(victim:EyeAngles())
							proj._ThrownByPlayer = victim
							proj._DetonateOnImpact = lastSwepInfo.DI or false
							if (isnumber(lastSwepInfo.FT) and lastSwepInfo.FT >= 0) then -- grenade has a fuse
								local remainingFuse = math.max(0, (lastSwepInfo.FS + lastSwepInfo.FD) - CurTime())
								proj._FuseEndTime = CurTime() + remainingFuse
							end
							
							proj:Spawn()
							
						end
					end
				end
			end
		end
	end)
	
end



--///// Cave Johnson lemon rant VO handler

if SERVER then
	util.AddNetworkString("CombustibleLemonSWEP_StartCaveJohnsonVO_ClTx")
	util.AddNetworkString("CombustibleLemonSWEP_StartCaveJohnsonVO_ClRx")
	
	--// Client telling us that they started playing the VO locally
	net.Receive("CombustibleLemonSWEP_StartCaveJohnsonVO_ClTx", function(bitlength, p)
		if (IsValid(p)) then
			local dummy = net.ReadBool()
			
			-- Tell other clients to start playing the VO locally
			net.Start("CombustibleLemonSWEP_StartCaveJohnsonVO_ClRx")
			net.WriteEntity(p)
			net.WriteBool(true)
			
			local recipients = {}
			for _, p2 in ipairs(player.GetAll()) do
				if (p2 ~= p) then recipients[#recipients + 1] = p2 end
			end
			net.Send(recipients)
		end
	end)
	
	--// Tell all clients to stop playing a specific VO when a player dies
	hook.Add("PostPlayerDeath", "PostPlayerDeath_CombustibleLemonSwep_CJVO", function(victim, inflictor, attacker)
		if (IsValid(victim)) then
			net.Start("CombustibleLemonSWEP_StartCaveJohnsonVO_ClRx")
			net.WriteEntity(victim)
			net.WriteBool(false)
			net.Broadcast()
		end
	end)
end

if CLIENT then
	
	local OwnerToIgacInstance = {}
	local VOBaseVolume = 1
	
	local function StartVOForPlayer(p)
		if (IsValid(p) == false) then return end
		if (OwnerToIgacInstance[p] ~= nil) then return end
		if (p._CombustibleLemonSWEP_CaveJohnsonVOEndTime == nil or (isnumber(p._CombustibleLemonSWEP_CaveJohnsonVOEndTime) and SysTime() > p._CombustibleLemonSWEP_CaveJohnsonVOEndTime)) then
			p._CombustibleLemonSWEP_CaveJohnsonVOEndTime = SysTime() + 34
			
			local voVolumeScale = 1.0
			local voVolumeScaleCvar = GetConVar("CombustibleLemonSwep_CaveJohnsonVOVolume")
			if (voVolumeScaleCvar ~= nil) then voVolumeScale = voVolumeScaleCvar:GetFloat() end
			if (voVolumeScale < 0) then voVolumeScale = 0 end
			
			sound.PlayFile("sound/weapons/tfusion/dumbthings/combustible_lemon_swep/cavejohnson_lemons.wav", "3d noblock noplay",
				function(soundChannel, errorId, errorName)
					if (soundChannel ~= nil) then
						OwnerToIgacInstance[p] = soundChannel
						soundChannel:SetPos(p:GetPos())
						soundChannel:SetVolume(VOBaseVolume * voVolumeScale)
						soundChannel:Set3DFadeDistance(250, 1200)
						soundChannel:Play()
					end
				end)
			return true
		end
		
		return false
	end
	
	--// Adjust VO instance volumes if the client VO volume scale cvar is changed live
	--[[   This doesnt work. The callback is never raised for some retarded reason. Source spaghetti.
	cvars.AddChangeCallback("CombustibleLemonSwep_CaveJohnsonVOVolume",
		function(cvarName, oldVal, newVal)
			local newVolumeScale = tonumber(newVal)
			if (isnumber(newVolumeScale) == false) then newVolumeScale = 1.0 end
			for ownerPlayer, igacInstance in pairs(OwnerToIgacInstance) do
				if (IsValid(igacInstance)) then
					igacInstance:SetVolume(VOBaseVolume * newVolumeScale)
				end
			end
		end,
		"CombustibleLemonSwep_CaveJohnsonVOVolume_InternalListener")
		]]
	
	--// Update the VO instances every tick
	hook.Add("Tick", "Tick_CombustibleLemonSwep_CJVO", function()
		local removeKeys = {}
		
		local voVolumeScale = 1.0
		local voVolumeScaleCvar = GetConVar("CombustibleLemonSwep_CaveJohnsonVOVolume")
		if (voVolumeScaleCvar ~= nil) then voVolumeScale = voVolumeScaleCvar:GetFloat() end
		if (voVolumeScale < 0) then voVolumeScale = 0 end
		
		for ownerPlayer, igacInstance in pairs(OwnerToIgacInstance) do
			if (IsValid(ownerPlayer) and IsValid(igacInstance)) then
				if (IsValid(ownerPlayer)) then
					igacInstance:SetPos(ownerPlayer:GetPos())
					igacInstance:SetVolume(VOBaseVolume * voVolumeScale)
					if (igacInstance:GetState() == GMOD_CHANNEL_STOPPED and igacInstance:GetTime() > 0.1) then
						removeKeys[#removeKeys + 1] = ownerPlayer
					end
				else
					igacInstance:Stop()
					removeKeys[#removeKeys + 1] = ownerPlayer
				end
			else
				removeKeys[#removeKeys + 1] = ownerPlayer
			end
		end
		for _, removeKey in ipairs(removeKeys) do
			removeKey._CombustibleLemonSWEP_CaveJohnsonVOEndTime = 0
			OwnerToIgacInstance[removeKey] = nil
		end
	end)
	
	--// Server telling us that a player has started playing the VO locally or has died
	net.Receive("CombustibleLemonSWEP_StartCaveJohnsonVO_ClRx", function(bitlength)
		local p = net.ReadEntity()
		local startPlaying = net.ReadBool()
		if (startPlaying) then
			-- Start the VO for this player
			if (IsValid(p)) then
				StartVOForPlayer(p)
			end
		else
			-- Stop the VO for this player
			local igac = OwnerToIgacInstance[p]
			if (IsValid(igac)) then
				igac:Stop()
			end
			p._CombustibleLemonSWEP_CaveJohnsonVOEndTime = 0
			OwnerToIgacInstance[p] = nil
		end
	end)
	
	--// Hook called from the SWEP that tells us to start playing the VO locally and network it to the other players
	hook.Add("CombustibleLemonSWEP_StartCaveJohnsonVO", "CombustibleLemonSWEP_StartCaveJohnsonVO_ClHandler", function(p)
		if (IsValid(p)) then
			local didStartVO = StartVOForPlayer(p)
			if (didStartVO) then
				net.Start("CombustibleLemonSWEP_StartCaveJohnsonVO_ClTx")
				net.WriteBool(true)
				net.SendToServer()
			end
		end
	end)
end


--///// Ragdoll ammo entity handling
--// prop_ragdoll has a pathetically limited interface and is not suitable for use as a SENT, so we have to recreate some SENT functionality ourself

if SERVER then

	--// Emulated think
	hook.Add("Think", "CombustibleLemonSWEP_Think_AmmoEntity", function()
		local allRagdolls = ents.FindByClass("prop_ragdoll")
		for _, ragdoll in ipairs(allRagdolls) do
			local success, errorMessage = pcall(function()
				if (ragdoll._IsTfusionCombustibleLemonSwepAmmoBag == true) then
					ragdoll:Think()
				end
			end)
			if (success ~= true) then
				pcall(function() ragdoll:Remove() end)
			end
		end
	end)
	
	--// Emulated ontakedamage event
	hook.Add("EntityTakeDamage", "CombustibleLemonSWEP_EntityTakeDamage_AmmoEntity", function(ent, dmginfo)
		local success, errorMessage = pcall(function()
			if (ent._IsTfusionCombustibleLemonSwepAmmoBag == true) then
				if (dmginfo:IsDamageType(DMG_CRUSH) == false and dmginfo:IsDamageType(DMG_VEHICLE) == false and dmginfo:IsDamageType(DMG_FALL) == false) then -- ignore damage from physics
					ent:OnTakeDamage(dmginfo)
				end
			end
		end)
		if (success ~= true) then
			pcall(function() ent:Remove() end)
		end
	end)
	
	--// Emulated +use on entity
	hook.Add("FindUseEntity", "CombustibleLemonSWEP_FindUseEntity_AmmoEntity", function(ply, ent)
		-- Do a trace to see if the player is looking at a nearby lemon ammo bag entity
		if (IsValid(ply)) then
			local tr = util.TraceLine({
				start = ply:EyePos(),
				endpos = ply:EyePos() + (ply:EyeAngles():Forward() * 100),
				filter = ply,
				mask = MASK_SOLID,
			})
			if (tr.Hit and IsValid(tr.Entity)) then
				if (tr.Entity._IsTfusionCombustibleLemonSwepAmmoBag == true and tr.Entity._MarkedForRemoval ~= true) then
					tr.Entity:EmulatedUse(ply)
					return ent
				end
			end
		end
	end)

end