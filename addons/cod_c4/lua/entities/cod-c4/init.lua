
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

function ENT:SpawnFunction( ply, tr )
	if ( !tr.Hit ) then
		return
	end
	local SpawnPos = tr.HitPos + tr.HitNormal * 16
	local ent = ents.Create( "cod-c4" )
	ent:SetPos( SpawnPos )
	ent:Spawn()
	ent:Activate()

	if IsValid(ply) then
		ent:SetOwner(ply)
	end
	return ent
end


function ENT:Initialize()
	self:SetModel( "models/hoff/weapons/c4/w_c4.mdl" )
	self:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:DrawShadow(false)

	local phys = self:GetPhysicsObject()

	if (phys:IsValid()) then
		phys:Wake()
	end

	self.Hit = false

	self.ExplodedViaWorld = false

	self:SetDTFloat( 0, math.Rand( 0.5, 1.3 ) )
	self:SetDTFloat( 1, math.Rand( 0.3, 1.2 ) )

	--self.Entity:SetOwner(self.C4Owner)

	self:SetNWBool("CanUse", false)
end

function ENT:PhysgunPickup(ply, ent)
	if ent:GetClass() == "cod-c4" then
		return false
	end
end
hook.Add("PhysgunPickup", "my_physgun_pickup_hook", function(ply, ent)
	if IsValid(ent) and ent.PhysgunPickup then
		return ent:PhysgunPickup(ply, ent)
	end
end)

function ENT:SetupDataTables()
	self:DTVar( "Float", 0, "RotationSeed1" )
	self:DTVar( "Float", 1, "RotationSeed2" )
end

function ENT:OnRemove()
	if IsValid(self.C4Owner) and self.C4Owner.C4s then
		table.RemoveByValue(self.C4Owner.C4s, self)
	end
end

function ENT:DelayedDestroy(bTriggeredByOwner)
	if !IsValid(self) then
		return
	end
	local LastC4Position = self:GetPos()
	local ExplodedViaWorld = self.ExplodedViaWorld
	local Owner = self.C4Owner
	local CachedC4s = IsValid(Owner) and table.Copy(Owner.C4s or {}) or {}
	self.ExplodedViaWorld = false
	self.QueuedForExplode = true

	-- Set a timer to explode the found C4 entity after a delay of 0.1 seconds
	if IsValid(self:GetParent()) then
		self:SetParent()
	end
	timer.Simple(0.1, function()
		if bTriggeredByOwner then
			if IsValid(self) and IsValid(Owner) and Owner.C4s then
				-- Index 2 is the next c4 to activate, since index 1 is this one (probably)
				while #Owner.C4s >= 2 and !IsValid(Owner.C4s[2]) do
					table.remove(Owner.C4s, 2)
				end
				local NextEnt = Owner.C4s[2]
				if IsValid(NextEnt) then
					NextEnt.ExplodedViaWorld = false
					NextEnt:DelayedDestroy(true)
				end
				table.RemoveByValue(Owner.C4s, self)
				if #Owner.C4s <= 0 then
					Owner.C4s = {}
				end
			end
		end

		-- Find all C4 entities within a radius of 128 units from the current C4 entity
		local entities = ents.FindInSphere(LastC4Position, 128)

		-- Sort the entities by distance
		table.sort(entities, function(a, b)
			-- Calculate the distance from the C4 to each entity
			local distanceA = a:GetPos():Distance(LastC4Position)
			local distanceB = b:GetPos():Distance(LastC4Position)

			-- Compare the distances and return the result of the comparison
			return distanceA < distanceB
		end)

		-- Iterate over the sorted entities
		for k, v in pairs(entities) do

			if v ~= self and IsValid(v) then
				-- Check if the current entity is a C4 entity, is not the current C4 entity, and is valid
				if v:GetClass() == "cod-c4" then
					if (ExplodedViaWorld or !table.HasValue(CachedC4s, v)) and v.QueuedForExplode == false then
							
						-- Check if the found C4 entity has an "Explode" function
						if (type(v.Explode) == "function") then
							
							-- Explode the found C4 entity
							--v.ThisTrigger = self.ThisTrigger
							v.ExplodedViaWorld = true
							v:DelayedDestroy(false)
								
						end
						-- Break the loop after finding and exploding the first C4 entity
						break
					end
					break
				end
			end
		end

		-- Explode this c4 and remove it from the array (if it's in there)
		if IsValid(self) then
			if IsValid(Owner) and Owner.C4s then
				table.RemoveByValue(Owner.C4s, self)
			end
			self:Explode(bTriggeredByOwner)
		end
	end)
end

function ENT:Explode(bTriggeredByOwner)
	if not IsValid(self) then
		return
	end

	self:EmitSound( "ambient/explosions/explode_4.wav" )

	local detonate = ents.Create( "env_explosion" )
	if IsValid(self.C4Owner) then
		detonate:SetOwner(self.C4Owner)
	end
		detonate:SetPos( self:GetPos() )
	local MagnitudeConVar = GetConVar("C4_Magnitude")
	detonate:SetKeyValue( "iMagnitude", MagnitudeConVar and MagnitudeConVar:GetString() or "175" )
		--detonate:SetKeyValue( "iRadiusOverride", GetConVar("C4_Radius"):GetString() )
		detonate:Spawn()
		detonate:Activate()
		detonate:Fire( "Explode", "", 0 )

	local shake = ents.Create( "env_shake" )
	if IsValid(self.C4Owner) then
		shake:SetOwner(self.C4Owner)
	end
		shake:SetPos( self:GetPos() )
		shake:SetKeyValue( "amplitude", "2000" )
		shake:SetKeyValue( "radius", "400" )
		shake:SetKeyValue( "duration", "2.5" )
		shake:SetKeyValue( "frequency", "255" )
		shake:SetKeyValue( "spawnflags", "4" )
		shake:Spawn()
		shake:Activate()
		shake:Fire( "StartShake", "", 0 )

	self.QueuedForExplode = true

	local KnockDoorsConVar = GetConVar("C4_KnockDoors")
	if KnockDoorsConVar and KnockDoorsConVar:GetBool() then
		self:KnockDownDoors()
	end

	-- Search nearby this exploding c4, if it finds one not in the c4 table, explode it
	self:DelayedDestroy(bTriggeredByOwner)

	self:Remove()
end

function ENT:KnockDownDoors()
	local DoorSearchRadiusConVar = GetConVar("C4_DoorSearchRadius")
	local SearchRadius = DoorSearchRadiusConVar and DoorSearchRadiusConVar:GetInt() or 100
	local entities = ents.FindInSphere(self:GetPos(), SearchRadius)
	for k, ItDoor in pairs(entities) do
		local DoorClass = ItDoor:GetClass()
		if DoorClass == "func_door" or DoorClass == "func_door_rotating" or DoorClass == "prop_door_rotating" then
			if !ItDoor.KnockedDown then
				self:BlastDoor(ItDoor)
			end
		end
	end
end

function ENT:BlastDoor(FoundDoor)
	FoundDoor.KnockedDown = true
	FoundDoor:Fire("lock","",0)
	FoundDoor:Fire("Open","",0)
	FoundDoor:SetCollisionGroup(COLLISION_GROUP_WORLD)
	FoundDoor:CollisionRulesChanged()
	FoundDoor:SetNoDraw(true)

	FoundDoor.FakeDoor = ents.Create("prop_physics")
	FoundDoor.FakeDoor:SetModel(FoundDoor:GetModel())
	FoundDoor.FakeDoor:SetPos(FoundDoor:GetPos())
	FoundDoor.FakeDoor:SetAngles(FoundDoor:GetAngles())
	FoundDoor.FakeDoor:Spawn()
	FoundDoor.FakeDoor:Activate()
	if FoundDoor:GetSkin() then
		FoundDoor.FakeDoor:SetSkin(FoundDoor:GetSkin())
	end

	local phys = FoundDoor.FakeDoor:GetPhysicsObject()
	if IsValid(phys) then
		local DoorKnockStrengthConVar = GetConVar("C4_DoorKnockStrength")
		local KnockStrength = DoorKnockStrengthConVar and DoorKnockStrengthConVar:GetFloat() or 500
		KnockStrength = KnockStrength * -1
		phys:ApplyForceOffset((self:GetAngles():Up() * KnockStrength) * phys:GetMass(), self:GetPos())
	end
end

ENT.PhysData = nil
ENT.PhysRef = nil
function ENT:PhysicsCollide(data, phys)
	local HitEntity = data.HitEntity
	local bHitWorld = (not HitEntity) or (IsValid(HitEntity) and HitEntity:IsWorld())

	-- Skip self and owner hits
	if IsValid(HitEntity) and (HitEntity:GetClass() == "cod-c4" or HitEntity == self.C4Owner) then
		return
	end

	if self:IsValid() and not self.Hit then
		self.ChangeCollisionGroup = true
		timer.Simple(0, function()
			if IsValid(self) and self.ChangeCollisionGroup then
				self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
				self.ChangeCollisionGroup = false

				local bHitValidEntity = IsValid(HitEntity)
				if bHitValidEntity and not bHitWorld then
					-- Hit a non-world entity: parent to it
					local bHitAnotherC4 = HitEntity:GetClass() == "cod-c4"
					local bHitAnNPC = HitEntity:IsNPC()
					local bHitAPlayer = HitEntity:IsPlayer()
					if not bHitAnotherC4 and not bHitAnNPC and not bHitAPlayer then
						self:SetSolid(SOLID_VPHYSICS)
						self:SetMoveType(MOVETYPE_NONE)
						self:SetParent(HitEntity)
						self.Stuck = true
						self.Hit = true
					elseif bHitAnNPC or (bHitAPlayer and HitEntity ~= self:GetOwner()) then
						self:SetSolid(SOLID_VPHYSICS)
						self:SetMoveType(MOVETYPE_NONE)
						self:SetParent(HitEntity)
						self.Stuck = true
						self.Hit = true
						self:SetOwner(nil)
					end
				else
					-- World hit: freeze in place (HL2SB fix - original returned early
					-- when HitEntity was nil, so C4 never stuck to walls/floors)
					self:SetSolid(SOLID_VPHYSICS)
					self:SetMoveType(MOVETYPE_NONE)
					if IsValid(phys) then
						phys:SetVelocity(Vector(0, 0, 0))
						phys:SetAngleVelocity(Vector(0, 0, 0))
						phys:EnableMotion(false)
						phys:Sleep()
					end
					self.Hit = true
					self.Stuck = true
				end
				self:SetNWBool("CanUse", true)

				if IsValid(phys) then
					local angVel = phys:GetAngleVelocity()
					local maxAngVel = 1000
					if angVel:Length() > maxAngVel then
						angVel = angVel:GetNormalized() * maxAngVel
						phys:SetAngleVelocity(angVel)
					end
				end

				local HitAngle = data.HitNormal:Angle()
				HitAngle.p = HitAngle.p + 270

				self:SetPos(data.HitPos + ((data.HitNormal / 5) * -11))

				-- Generate a random yaw angle between -60 and 60 degrees
				local yaw = math.random(-60, 60)

				self:SetAngles(HitAngle)
				HitAngle:RotateAroundAxis(self:GetUp(), yaw)
				self:SetAngles(HitAngle)
				self:SetOwner(nil)
			end
		end)
		self:SetNWBool("Hit", true)
		self.Hit = true
		self.PhysData = data
		self.PhysRef = phys

		-- Play plant sound on first hit
		self:EmitSound("hoff/mpl/seal_c4/satchel_plant.wav")
	end
end

function ENT:OnTakeDamage( dmginfo )
	self:TakePhysicsDamage( dmginfo )

	-- Check if the attacker is not the owner of the C4, or if the damage type is not blast damage
	if dmginfo:GetDamageType() ~= DMG_BLAST then
		self.ExplodedViaWorld = true
		self:Explode(false)
	end
end

function ENT:Touch(ent)
	if ent == self.C4Owner or ent == self.ThisTrigger or ent == self:GetOwner() then
		return false
	end
	if IsValid(ent) and !self.Stuck then
		if ent:IsNPC() or (ent:IsPlayer() and ent ~= self:GetOwner()) or ent:IsVehicle() then
			self:SetSolid(SOLID_VPHYSICS)
			self:SetMoveType(MOVETYPE_NONE)
			self:SetParent(ent)
			self.Stuck = true
			self.Hit = true
			self:SetOwner(nil)
		end
	end
end
--[[
ENT.CanUse = true
function ENT:Use( activator, caller )
	if activator:IsPlayer() and self.CanUse and self:GetNWString("OwnerID") == activator:SteamID() then
		self.CanUse = false
		if SERVER then
			if GetConVar("C4_Infinite"):GetBool() == false then
				if activator:HasWeapon("seal6-c4") then
					activator:EmitSound("hoff/mpl/seal_c4/ammo.wav")
					activator:GiveAmmo(1, "Slam", true)
				else
					activator:Give("seal6-c4")
					activator:SelectWeapon("seal6-c4")
					activator:RemoveAmmo(4, "Slam")
				end
			end
			table.RemoveByValue( activator.C4s, self )
			self:Remove()
		end
	end
end
]]