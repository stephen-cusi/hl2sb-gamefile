AddCSLuaFile()


--///// ==============================  Entity Description  ==============================/////--

ENT.Type						= "anim"
ENT.PrintName					= "Combustible Lemon Projectile"
ENT.Category					= "Aperture Laboratories"
ENT.Author						= "TiberiumFusion"
ENT.Contact						= ""
ENT.Purpose						= "Projectile thrown by the Combustible Lemon SWEP."
ENT.Instructions				= "Not for direct use."
ENT.Spawnable					= false
ENT.AdminOnly					= true
ENT.DoNotDuplicate				= true
ENT.DisableDuplicator			= true

ENT._GroundSnapDistance			= 70
ENT._InitialIgnitionRadius		= 210
ENT._InitialIgnitionTime		= 12
ENT._InitialBlastDamageRadius	= 300
ENT._InitialBlastDamageAmount	= 50
ENT._InitialBlastDamage2Radius	= 75
ENT._InitialBlastDamage2Amount	= 100
ENT._LingeringIgnitionRadius	= 150
ENT._LingeringIgnitionTime		= 7
ENT._LingeringFireDuration		= 10


--///// ==============================  Main Functionality  ==============================/////--

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Float", 0, "StateEntryTime")
	self:NetworkVar("Bool", 0, "DetonatedOnGround")
	self:NetworkVar("Vector", 0, "DetonationPos")
	self:NetworkVar("Int", 1, "LoopingFireSoundState")
end

function ENT:ChangeState(state)
	self:SetState(state)
	self:SetStateEntryTime(CurTime())
end


if CLIENT then
	
	function ENT:Initialize()
		self:ChangeState(0)
		self:SetDetonatedOnGround(false)
		self:SetDetonationPos(Vector(0, 0, 0))
		self:SetLoopingFireSoundState(0)
		
		--// The client can disable the explosion effect's dynamic light in two different ways
		self._EnableDynamicLight = true
		-- 1. Addon-specific cvar
		local dynLightCvar = GetConVar("CombustibleLemonSwep_ExplosionDynamicLight")
		if (dynLightCvar ~= nil) then
			if (dynLightCvar:GetInt() == 0) then self._EnableDynamicLight = false end
		end
		-- 2. Video settings
		if (self._EnableDynamicLight == true) then
			local shaderDetailCvar = GetConVar("mat_reducefillrate")
			if (shaderDetailCvar ~= nil) then
				if (shaderDetailCvar:GetInt() == 1) then self._EnableDynamicLight = false end
			end
		end
	end
	
	function ENT:Draw()
		if (self:GetState() == 0) then
			self:DrawModel()
		end
	end
	
	function ENT:Think()
		if (IsValid(self) == false) then return end
		
		local localself = self
		
		local state = self:GetState()
		local stateTime = CurTime() - self:GetStateEntryTime()
		
		--// Dynamic light
		if ((state >= 1 and state <= 2) or state == 10) then
			if (self._EnableDynamicLight) then
				self:UpdatePointLight()
			end
		end
		
		--// Fire looping sound workaround for https://github.com/Facepunch/garrysmod-issues/issues/5025
		-- Use BASS instead of the shitty broken engine sounds
		local loopingFireSoundState = self:GetLoopingFireSoundState()
		if (loopingFireSoundState == 1 and self._FireLoopSoundInstance == nil) then
			self:SetLoopingFireSoundState(2)
			-- Start looping sound
			self._FireLoopSoundInstance = -1
			sound.PlayFile("sound/weapons/tfusion/dumbthings/combustible_lemon_swep/fire_loop.wav", "3d noblock noplay",
			function(soundChannel, errorId, errorName)
				if (soundChannel ~= nil and IsValid(soundChannel) and IsValid(localself)) then
					localself._FireLoopSoundInstance = soundChannel
					soundChannel:EnableLooping(true)
					soundChannel:SetPos(localself:GetPos())
					soundChannel:SetVolume(1)
					soundChannel:Set3DFadeDistance(250, 1500)
					soundChannel:Play()
					
					-- Extra insurance for stopping looping sounds
					timer.Simple(localself._LingeringFireDuration * 1.1, function()
						pcall(function()
							if (soundChannel ~= nil and IsValid(soundChannel)) then
								soundChannel:Stop()
								soundChannel = nil
								if (localself ~= nil and IsValid(localself)) then
									localself._FireLoopSoundInstance = nil
								end
							end
						end)
					end)
				end
			end)
		elseif (loopingFireSoundState == 3 and self._FireFadeoutSoundInstance == nil) then
			self:SetLoopingFireSoundState(4)
			-- Stop looping sound
			if (self._FireLoopSoundInstance ~= nil and isnumber(self._FireLoopSoundInstance) == false and IsValid(self._FireLoopSoundInstance)) then
				self._FireLoopSoundInstance:Stop()
				self._FireLoopSoundInstance = nil
			end
			-- Play fadeout sound
			self._FireFadeoutSoundInstance = -1
			sound.PlayFile("sound/weapons/tfusion/dumbthings/combustible_lemon_swep/fire_fadeout.wav", "3d noblock noplay",
			function(soundChannel, errorId, errorName)
				if (soundChannel ~= nil and IsValid(soundChannel) and IsValid(localself)) then
					localself._FireFadeoutSoundInstance = soundChannel
					soundChannel:SetPos(localself:GetPos())
					soundChannel:SetVolume(1)
					soundChannel:Set3DFadeDistance(250, 1500)
					soundChannel:Play()
				end
			end)
		end
		
	end
	
	function ENT:UpdatePointLight()
		if (self._EnableDynamicLight) then
			local dlight = DynamicLight(self:EntIndex())
			if (dlight) then
				dlight.pos = self:GetPos()
				dlight.r = 255
				dlight.g = 65
				dlight.b = 0
				dlight.brightness = 4
				dlight.decay = 1000 / 1.5
				dlight.size = 400
				dlight.dietime = CurTime() + 1.5
			end
		end
	end

	function ENT:OnRemove()
		--// Insurance to stop sounds
		if (self._FireLoopSoundInstance ~= nil and isnumber(self._FireLoopSoundInstance) == false and IsValid(self._FireLoopSoundInstance)) then
			self._FireLoopSoundInstance:Stop()
		end
		self._FireLoopSoundInstance = nil
		if (self._FireFadeoutSoundInstance ~= nil and isnumber(self._FireFadeoutSoundInstance) == false and IsValid(self._FireFadeoutSoundInstance)) then
			self._FireFadeoutSoundInstance:Stop()
		end
		self._FireFadeoutSoundInstance = nil
	end
	
end


if SERVER then
	
	function ENT:Initialize()
		self:ChangeState(0)
		self:SetDetonatedOnGround(false)
		self:SetDetonationPos(Vector(0, 0, 0))
		self:SetLoopingFireSoundState(0)
		
		self:SetModel("models/weapons/tfusion/dumbthings/combustible_lemon_swep_p.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:DrawShadow(true)
		
		self:SetMaxHealth(5)
		self:SetHealth(5)
		
		self._DamageAttacker = self._ThrownByPlayer
		self._LastIgniteExpiry = {}
		
		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:SetMass(3)
			phys:Wake()
		end
		
		self:Think()
	end
	
	function ENT:OnTakeDamage(damageinfo)
		if (IsValid(self) == false) then return end
		
		--// Dont take take while invulnerable
		if (isnumber(self._InvulnerableUntil) and CurTime() < self._InvulnerableUntil) then
			damageinfo:SetDamage(0)
			return 0
		end
		
		--// Only count damage that occurs before we detonate
		local state = self:GetState()
		if (state == 0) then
			self:SetHealth(self:Health() - damageinfo:GetDamage())
			self._DamageAttacker = damageinfo:GetAttacker()
		else
			damageinfo:SetDamage(0)
			return 0
		end
	end

	function ENT:Think()
		if (IsValid(self) == false) then return end
		
		local state = self:GetState()
		local stateTime = CurTime() - self:GetStateEntryTime()
		
		if (state == 0) then -- traveling as a projectile
			
			if (isnumber(self._FuseEndTime)) then
				if (self._FuseEndTime >= 0 and CurTime() >= self._FuseEndTime) then
					self._FuseEndTime = nil
					timer.Simple(0, function()
						self:Detonate()
					end)
				end
			end
			
			if (self:Health() <= 0) then
				self:Detonate()
			end
			
		elseif (state == 1) then -- detonated, waiting to spawn lingering fire effect
			
			if (stateTime > 0.4) then
				if (self:GetDetonatedOnGround() == true) then -- only spawn the lingering fire if we detonated on the ground
					self:StartLingeringFire()
					self:ChangeState(2)
				end
			end
			
			
		elseif (state == 2) then -- running lingering fire effect
			
			self:IgniteEntitiesNear(self:GetPos() + Vector(0, 0, 0.1), self._LingeringIgnitionRadius, self._LingeringIgnitionTime)
			
			if (stateTime > self._LingeringFireDuration) then
				self:StopLingeringFire()
				self:ChangeState(3)
			end
		
		elseif (state == 3) then -- fading out lingering fire effect
			
			if (stateTime > 0.75) then -- wait a bit for the fire looping sound to fade out before we destroy ourself
				self:CleanupAndRemove()
			end
		
		end
		
		self:NextThink(CurTime())
		return true
	end
	
	function ENT:PhysicsCollide(colData, phys)
		if (IsValid(self) == false) then return end
		
		local state = self:GetState()
		if (state == 0) then
			if (colData.HitSpeed:LengthSqr() > 50 * 50) then
				self:EmitSound("Flesh.ImpactSoft")
			end
			
			if (self._DetonateOnImpact == true) then
				if (isnumber(self._InvulnerableUntil) and CurTime() < self._InvulnerableUntil) then -- dont allow detonations while invulnerable
					return
				end
				
				if (IsValid(colData.HitEntity)) then
					if (colData.HitEntity:GetMaterialType() == MAT_GLASS) then return end -- dont detonate when hitting glass, break it instead
				end
				
				local ent = self
				timer.Simple(0, function()
					ent:Detonate()
				end)
			end
		end
	end
	
	function ENT:Detonate()
		if (IsValid(self) == false) then return end
		if (self:GetState() > 0) then return end -- already detonated
		
		if (self:WaterLevel() >= 3) then -- dont detonate if underwater
			return
		end
		
		if (isnumber(self._InvulnerableUntil) and CurTime() < self._InvulnerableUntil) then -- dont detonate while invulnerable
			return
		end
		
		self:ChangeState(1)
		
		--// Become intangible
		local ent = self
		timer.Simple(0, function()
			if (IsValid(ent)) then
				ent:SetSolid(SOLID_NONE)
				local phys = ent:GetPhysicsObject()
				phys:SetVelocity(Vector(0, 0, 0))
				phys:SetAngles(Angle(0, 0, 0))
				phys:Sleep()
			end
		end)
		
		--// Determine if we hit the ground (or are close enough) or hit a wall or ceiling or something, as well as our final detonation position
		-- We do 4 traces making a square around the impact spot to better catch uneven terrain
		-- The lowest trace hit will be the position we take
		self:SetDetonatedOnGround(false)
		local finalDetonationPos = self:GetPos()
		local traceDepth = self._GroundSnapDistance
		local squareSize = 5
		local offsets = {
			Vector(squareSize * -0.5, squareSize * -0.5, 0),
			Vector(squareSize * -0.5, squareSize * 0.5, 0),
			Vector(squareSize * 0.5, squareSize * 0.5, 0),
			Vector(squareSize * 0.5, squareSize * -0.5, 0),
		}
		-- Filter out nocollided entities from the trace
		local trFilter = { self }
		for _, filterEnt in ipairs(ents.FindInBox(finalDetonationPos + offsets[1] - Vector(0, 0, traceDepth), finalDetonationPos + offsets[3])) do
			if (IsValid(filterEnt) and filterEnt ~= self) then
				if (filterEnt:GetCollisionGroup() == COLLISION_GROUP_WORLD) then
					trFilter[#trFilter + 1] = filterEnt
				end
			end
		end
		for _, offset in ipairs(offsets) do
			-- 1. Trace from center pos to offset pos to check for air -> solid
			local tr1 = util.TraceLine({
				start = finalDetonationPos,
				endpos = finalDetonationPos + offset,
				filter = trFilter,
				mask = MASK_SOLID,
			})
			if (tr1.Hit == false or (tr1.Hit == true and IsValid(tr1.Entity) and tr1.Entity:IsPlayer())) then -- if we hit something solid, then the offset trace pos is likely on the other side of a wall and thus we must skip it
				-- 2. Trace straight down from offset pos to check for air -> solid
				local tr2 = util.TraceLine({
					start = finalDetonationPos + offset,
					endpos = finalDetonationPos + offset - Vector(0, 0, traceDepth),
					filter = trFilter,
					mask = MASK_SOLID,
				})
				if (tr2.Hit and (not (IsValid(tr2.Entity) and tr2.Entity:IsPlayer())) and tr2.FractionLeftSolid <= 0) then
					-- 3. Trace to ensure endpos is not inside something solid
					local radius = 0.2
					local tr3 = util.TraceHull({
						start = finalDetonationPos,
						endpos = finalDetonationPos,
						mins = Vector(-radius, -radius, radius),
						maxs = Vector(radius, radius, radius),
						filter = trFilter,
						mask = MASK_SOLID,
					})
					if (tr3.Hit == false or (tr3.Hit == true and IsValid(tr3.Entity) and tr3.Entity:IsPlayer())) then
						self:SetDetonatedOnGround(true)
						if (tr2.HitPos.z < finalDetonationPos.z) then
							finalDetonationPos = tr2.HitPos
						end
					end
				end
			end
		end
		self:SetDetonationPos(finalDetonationPos + Vector(0, 0, 0.25)) -- scoot it up a little above the ground to help with z-fighting on shitty maps
		
		--// Initial explosion effect
		if (self:GetDetonatedOnGround() == true) then
			ParticleEffect("tfusion_fire_explosion_directional_full", self:GetDetonationPos(), Angle(0, 0, 0))
		else
			ParticleEffect("tfusion_fire_explosion_directional_noground", self:GetDetonationPos(), Angle(0, 0, 0))
		end
		self:EmitSound("TFusion_CombustibleLemonSWEP.Detonate")
		
		--// Initial nearby entity ignition
		self:IgniteEntitiesNear(self:GetDetonationPos(), self._InitialIgnitionRadius, self._InitialIgnitionTime)
		
		--// Initial blast damage
		local blastDamageAttacker = self._DamageAttacker
		if (IsValid(blastDamageAttacker) == false) then blastDamageAttacker = self end
		util.BlastDamage(self, blastDamageAttacker, self:GetDetonationPos(), self._InitialBlastDamageRadius, self._InitialBlastDamageAmount) -- low damage wide blast
		util.BlastDamage(self, blastDamageAttacker, self:GetDetonationPos(), self._InitialBlastDamage2Radius, self._InitialBlastDamage2Amount) -- high damage small center blast
		
		--// Initial screen shake
		util.ScreenShake(self:GetDetonationPos(), 5, 1, 1, 900)
		
		--// If we detonated on the ground, we'll spawn the lingering fire several ticks later
		--// Otherwise we are done and can destroy ourself now
		if (self:GetDetonatedOnGround() == false) then
			self:ChangeState(10)
			self:CleanupAndRemove(0.2)
			return
		end
		
		--// Move to the detontation pos so that the lingering fire works correctly
		self:SetPos(self:GetDetonationPos())
		
	end
	
	function ENT:StartLingeringFire()
		if (IsValid(self) == false) then return end
		if (self:GetState() > 1) then return end -- already started the lingering fire
		
		--// Particle effect
		ParticleEffectAttach("tfusion_fire_field_full", PATTACH_ABSORIGIN_FOLLOW, self, -1)
		
		--// Start looping fire sound
		if (self:GetLoopingFireSoundState() == 0) then
			self:SetLoopingFireSoundState(1)
		end
	end
	
	function ENT:IgniteEntitiesNear(pos, radius, baseOnfireDuration, usePureTraceTest)
		
		local entsInRadius = ents.FindInSphere(pos, radius)

		-- Filter out nocollided entities from traces
		local trFilter = { self }
		for _, filterEnt in ipairs(entsInRadius) do
			if (IsValid(filterEnt) and filterEnt ~= self) then
				if (filterEnt:GetCollisionGroup() == COLLISION_GROUP_WORLD) then
					trFilter[#trFilter + 1] = filterEnt
				end
			end
		end
		
		for _, ent in ipairs(entsInRadius) do
			if (IsValid(ent) == true and ent ~= self) then
				local entPos = ent:GetPos()
				local canIgnite = true
				
				-- Dont ignite entities owned by players, otherwise we'll end up setting their weapons and viewmodels on fire which will instakill them
				local entOwner = ent:GetOwner()
				if (IsValid(entOwner)) then
					if (entOwner:IsPlayer()) then canIgnite = false end
				end
				
				-- Dont ignite flame entities
				if (ent:GetClass() == "entityflame") then canIgnite = false end
				
				-- Dont ignite other combustible lemon projectiles
				if (ent:GetClass() == "tfusion_combustible_lemon_projectile") then canIgnite = false end
				
				if (canIgnite) then
					local distToFireNormalized = -1
					
					if (usePureTraceTest) then -- use a direct trace to determine if something gets set on fire
						local toEnt = entPos - pos
						toEnt:Normalize()
						local tr = util.TraceLine({
							start = pos,
							endpos = pos + (toEnt * radius),
							filter = trFilter,
							mask = MASK_SHOT_HULL,
						})
						if (tr.Hit and tr.HitWorld == false and tr.HitSky == false and IsValid(tr.Entity) and tr.Entity ~= self) then
							distToFireNormalized = tr.Fraction
						end
					else -- basic distance test + 2 basic up/down traces to prevent fire damage from going through floors/ceilings
						local toEnt = entPos - pos
						local toEntLength = toEnt:Length()
						if (toEntLength <= radius) then
							-- Ceiling test (entity below fire, potential ceiling between entity and fire)
							local passCeilingTest = true
							if (entPos.z < pos.z - 5) then
								local tr1Start = Vector(entPos.x, entPos.y, pos.z)
								local tr1 = util.TraceLine({
									start = tr1Start,
									endpos = tr1Start + (Vector(0, 0, -1) * toEntLength),
									filter = trFilter,
									mask = MASK_SHOT_HULL,
								})
								passCeilingTest = (
									tr1.Hit == false -- no solid objects blocking path from ent to fire
									or
									(tr1.Hit == true and  -- we hit something solid but...
										(
											(tr1.HitWorld == false and tr1.HitSky == false and IsValid(tr1.Entity) and tr1.Entity == ent) -- ...we simply hit ourself or...
											or
											(tr1.FractionLeftSolid > 0) -- ...the trace started in a solid and left the solid
										)
									)
								)
							end
							if (passCeilingTest) then
								-- Floor test (entity above fire, potential floor between entity and fire)
								local passFloorTest = true
								if (entPos.z > pos.z + 5) then
									local tr2Start = Vector(entPos.x, entPos.y, pos.z)
									local tr2 = util.TraceLine({
										start = tr2Start,
										endpos = tr2Start + (Vector(0, 0, 1) * toEntLength),
										filter = trFilter,
										mask = MASK_SHOT_HULL,
									})
									passFloorTest = (
										tr2.Hit == false -- no solid objects blocking path from ent to fire
										or
										(tr2.Hit == true and  -- we hit something solid but...
											(
												(tr2.HitWorld == false and tr2.HitSky == false and IsValid(tr2.Entity) and tr2.Entity == ent) -- ...we simply hit ourself or...
												or
												(tr2.FractionLeftSolid > 0) -- ...the trace started in a solid and left the solid
											)
										)
									)
								end
								if (passFloorTest) then
									distToFireNormalized = toEntLength / radius
								end
							end
						end
					end
					
					if (distToFireNormalized >= 0) then
						local newOnfireDuration = (1 - math.pow(distToFireNormalized, 0.4)) * baseOnfireDuration -- modulate the onfire time so that it is less strong near the fringe
						-- Because Ignite() resets the onfire time and there is no way to get the current time that someone is on fire for, we have to fucking keep track of it ourself
						local entCurrentIgniteExpiry = -1
						if (self._LastIgniteExpiry ~= nil) then
							local check = self._LastIgniteExpiry[ent]
							if (isnumber(check)) then entCurrentIgniteExpiry = check end
						end
						if (entCurrentIgniteExpiry ~= -1) then -- we will only reignite the player if the new ignition duration will ultimately increase the time they are on fire for
							local remainingIgniteDuration = entCurrentIgniteExpiry - CurTime()
							if (remainingIgniteDuration <= 0 or newOnfireDuration > remainingIgniteDuration) then
								-- (re)ignite for the full newOnfireDuration amount
							else
								newOnfireDuration = 0 -- let the current ignition instance continue as normal
							end
						end
						if (newOnfireDuration > 0) then
							ent:Ignite(newOnfireDuration, 0)
							self._LastIgniteExpiry[ent] = CurTime() + newOnfireDuration
							--print(">>> IGNITED ", ent, " FOR ", newOnfireDuration)
						end
					end
				end
			end
		end
		
	end
	
	function ENT:StopLingeringFire()
		self:StopParticles()
		self:SetLoopingFireSoundState(3) -- stop looping sound effect
	end
	
	
	function ENT:CleanupAndRemove(delay)
		self:StopLingeringFire()
		if (isnumber(delay) and delay >= 0) then
			local ent = self
			timer.Simple(delay, function()
				ent:Remove()
			end)
		else
			self:Remove()
		end
	end
	
	function ENT:OnRemove()
		-- Insurance
		self:StopParticles()
	end

end
