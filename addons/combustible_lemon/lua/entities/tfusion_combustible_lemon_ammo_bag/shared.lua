AddCSLuaFile()


--///// ==============================  Entity Description  ==============================/////--

ENT.Type						= "anim"
ENT.PrintName					= "Combustible Lemon Ammo Bag"
ENT.Category					= "Aperture Laboratories"
ENT.Author						= "TiberiumFusion"
ENT.Contact						= ""
ENT.Purpose						= "A bag of 10 Combustible Lemons™. Can be collected for ammo or shot for a massive explosion."
ENT.Instructions				= ""
ENT.Spawnable					= true
ENT.AdminOnly					= false
ENT.DoNotDuplicate				= false -- allow duplicator
ENT.DisableDuplicator			= false -- ditto


--///// ==============================  Main Functionality  ==============================/////--

if CLIENT then
	
	function ENT:Initialize()
		
	end
	
	function ENT:Draw()
		self:DrawModel()
	end
	
end

if SERVER then

	function ENT:SpawnFunction(ply, tr)
		if (!tr.Hit) then return end
		
		local SpawnPos = tr.HitPos + tr.HitNormal * 16
		local SpawnAng = ply:EyeAngles()
		SpawnAng.p = 0 SpawnAng.y = SpawnAng.y + 180
		
		local ent = ents.Create("tfusion_combustible_lemon_ammo_bag")
		
		ent._SpawnedByPlayer = ply
		
		ent:SetPos(SpawnPos)
		ent:SetAngles(SpawnAng)
		ent:Spawn()
		ent:Activate()
		
		return ent
	end
	
	function ENT:Initialize()
		self:SetModel("models/items/tfusion/dumbthings/combustible_lemon_ammo_bag.mdl")
		
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_NONE)
		self:DrawShadow(true)
		
		self:SetMaxHealth(5)
		self:SetHealth(5)
		
		self._ConvertedToRagdoll = false
		self._SpawnedByPlayer = self._SpawnedByPlayer
		self._DamageAttacker = self._SpawnedByPlayer
		self:SetUseType(SIMPLE_USE)
		
		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:SetMass(8)
			phys:Wake()
		end
		
		self:Think()
	end
	
	function ENT:Think()
		if (IsValid(self) == false) then return end
		
		if (self._ConvertedToRagdoll ~= true) then
			self:ConvertToRagdoll()
		end
		
		self:NextThink(CurTime())
		return true
	end
	
	--// Entities spawned from the spawnmenu cannot be ragdolls for some stupid fucking reason
	-- So to work around this, we immediately delete the default-type entity and spawn a ragdoll in its place, then create the necessary functions on the ragdoll
	-- prop_ragdoll has a pathetically limited interface, so we also emulate some of the SENT interface (see the autorun file)
	function ENT:ConvertToRagdoll()
		if (self._ConvertedToRagdoll == true) then return end
		
		self._ConvertedToRagdoll = true
		
		local ragdoll = ents.Create("prop_ragdoll")
		if (IsValid(ragdoll) == false) then return end -- in case something goes horrible wrong
		
		ragdoll:SetModel(self:GetModel())
		ragdoll:SetPos(self:GetPos())
		ragdoll:SetAngles(self:GetAngles())
		ragdoll:Spawn()
		ragdoll:Activate()
		
		--// Align ragdoll with ground
		--// Adapted from: https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/sandbox/gamemode/commands.lua#L332
			-- Attempt to move the object so it sits flush
			-- We could do a TraceEntity instead of doing all
			-- of this - but it feels off after the old way
			local vFlushPoint = ragdoll:GetPos() + Vector(0, 0, -512)	-- Find a point that is definitely out of the object in the direction of the floor
			vFlushPoint = ragdoll:NearestPoint( vFlushPoint )			-- Find the nearest point inside the object to that point
			vFlushPoint = ragdoll:GetPos() - vFlushPoint				-- Get the difference
			vFlushPoint = ragdoll:GetPos() + vFlushPoint				-- Add it to our target pos

			local VecOffset = vFlushPoint - ragdoll:GetPos()
			for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
				local phys = ragdoll:GetPhysicsObjectNum( i )
				phys:SetPos( phys:GetPos() + VecOffset )
			end
		
		ragdoll:SetHealth(5)
		ragdoll:SetMaxHealth(5)
		
		ragdoll._IsTfusionCombustibleLemonSwepAmmoBag = true
		ragdoll._Detonated = false
		ragdoll._DamageAttacker = self._DamageAttacker
		
		if (IsValid(self._SpawnedByPlayer) and self._SpawnedByPlayer:IsPlayer()) then
			undo.Create("Combustible Lemon Ammo Bag")
				undo.SetPlayer(self._SpawnedByPlayer)
				undo.AddEntity(ragdoll)
			undo.Finish("Combustible Lemon Ammo Bag (" .. tostring( model ) .. ")")
		end
		
		
		function ragdoll:CanTool(ply, tr, toolname, tool, button)
			if (toolname == "remover") then
				return true
			end
		end
		
		
		function ragdoll:EmulatedUse(ply)
			if (IsValid(ply) and ply:IsPlayer()) then
				if (IsValid(ply:GetWeapon("tfusion_combustible_lemon")) == false) then
					ply:Give("tfusion_combustible_lemon")
					ply:GiveAmmo(9, "tfusion_combustible_lemon")
				else
					ply:GiveAmmo(10, "tfusion_combustible_lemon")
				end
				self._MarkedForRemoval = true
				self:Remove()
			end
		end
		
		
		function ragdoll:OnTakeDamage(damageinfo)
			if (IsValid(self) == false) then return end
			
			self:SetHealth(self:Health() - damageinfo:GetDamage())
			self._DamageAttacker = damageinfo:GetAttacker()
		end
		
		
		function ragdoll:Think()
			if (IsValid(self) == false) then return end
			
			if (self:Health() <= 0 and self._Detonated == false) then
				self:Detonate()
			end
		end
		
		
		function ragdoll:Detonate()
			if (IsValid(self) == false) then return end
			if (self._Detonated == true) then return end
			
			if (self:WaterLevel() >= 3) then -- dont detonate if underwater
				return
			end
			
			self._Detonated = true
			
			local detonatePos = self:WorldSpaceCenter() + Vector(0, 0, 1)
			
			--// Become static
			for i = 0, self:GetPhysicsObjectCount() - 1 do
				local phys = self:GetPhysicsObjectNum(i)
				phys:SetVelocity(Vector(0, 0, 0))
				phys:SetAngles(Angle(0, 0, 0))
				phys:Sleep()
			end
			
			--// Find the normal of the surface we are on
			local groundNormal = Vector(0, 0, 1)
			local tr = util.TraceLine({
				start = detonatePos + Vector(0, 0, 0.1),
				endpos = detonatePos + Vector(0, 0, -500),
				filter = self,
				mask = MASK_SOLID,
			})
			if (tr.Hit and tr.HitNormal ~= Vector(0, 0, 0)) then
				groundNormal = tr.HitNormal
			end
			
			--// Detonate 1 combustible lemon at our pos
			local proj = ents.Create("tfusion_combustible_lemon_projectile")
			if (IsValid(proj) == false) then return end -- this shouldn't happen, but just in case
			proj:SetPos(detonatePos)
			proj:SetAngles(Angle(0, 0, 0))
			if (IsValid(self._DamageAttacker)) then
				proj._ThrownByPlayer = self._DamageAttacker
			end
			proj._FuseEndTime = CurTime()
			proj:Spawn()
			proj:Activate()
			
			--// Launch some live combustible lemon projectiles
			for i = 1, math.Rand(6, 9) do
				local proj = ents.Create("tfusion_combustible_lemon_projectile")
				if (IsValid(proj) == false) then return end -- this shouldn't happen, but just in case
				
				-- Random direction for the projectile to fly off in
				local dir = groundNormal * 1
				dir:Rotate(Angle(math.Rand(-80, 80), math.Rand(-80, 80), 0))
				
				proj:SetPos(detonatePos)
				proj:SetAngles(AngleRand())
				if (IsValid(self._DamageAttacker)) then
					proj._ThrownByPlayer = self._DamageAttacker
				end
				proj._DetonateOnImpact = false
				proj._FuseEndTime = CurTime() + math.Rand(0.4, 1.5) -- random fuse
				proj._InvulnerableUntil = proj._FuseEndTime - 0.01
				
				proj:Spawn()
				proj:Activate()
				
				local phys = proj:GetPhysicsObject()
				if (IsValid(phys) == false) then return end -- sanity
				
				phys:ApplyForceCenter(dir * math.Rand(1500, 2000)) -- random velocity
				phys:SetAngleVelocity((Vector(math.Rand(-10, 10), math.Rand(5, 12), math.Rand(9, 20))) * 1000)
			end
			
			self._MarkedForRemoval = true
			self:Remove()
		end
		
		self:Remove()
		
	end
	
end
