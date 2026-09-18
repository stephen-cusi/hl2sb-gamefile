
AddCSLuaFile( "shared.lua" )

SWEP.Author			= "Hoff"
SWEP.Instructions	= ""

SWEP.Category = "CoD Multiplayer"
SWEP.Spawnable			= true
SWEP.AdminSpawnable		= true

SWEP.ViewModel			= "models/hoff/weapons/c4/c_c4.mdl"
SWEP.WorldModel			= "models/hoff/weapons/c4/w_c4.mdl"
SWEP.ViewModelFOV = 75

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= 5
SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo		= "slam"
SWEP.Primary.Delay = 1

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= true
SWEP.Secondary.Ammo			= "none"

SWEP.Weight				= 5
SWEP.AutoSwitchTo		= false
SWEP.AutoSwitchFrom		= false

SWEP.PrintName			= "C4"
SWEP.Slot				= 4
SWEP.SlotPos			= 1
SWEP.DrawAmmo			= true
SWEP.DrawCrosshair		= true

SWEP.UseHands = true

SWEP.Offset = {
	Pos = {
		Up = 0,
		Right = 7,
		Forward = 3.5,
	},
	Ang = {
		Up = 0,
		Right = 90,
		Forward = 190,
	}
}
function SWEP:DrawWorldModel( )
	if not IsValid( self:GetOwner() ) then
		self:DrawModel( )
		return
	end

	local bone = self:GetOwner():LookupBone( "ValveBiped.Bip01_R_Hand" )
	if not bone then
		self:DrawModel( )
		return
	end

	local pos, ang = self:GetOwner():GetBonePosition( bone )
	pos = pos + ang:Right() * self.Offset.Pos.Right + ang:Forward() * self.Offset.Pos.Forward + ang:Up() * self.Offset.Pos.Up
	ang:RotateAroundAxis( ang:Right(), self.Offset.Ang.Right )
	ang:RotateAroundAxis( ang:Forward(), self.Offset.Ang.Forward )
	ang:RotateAroundAxis( ang:Up(), self.Offset.Ang.Up )

	self:SetRenderOrigin( pos )
	self:SetRenderAngles( ang )

	self:DrawModel()
end

function SWEP:Initialize()
	-- something keeps setting deploy speed to 4, this is a workaround
	self:SetDeploySpeed(1)
end

function SWEP:Deploy()
	-- something keeps setting deploy speed to 4, this is a workaround
	self:SetDeploySpeed(1)

	local Owner = self:GetOwner()
	if IsValid(Owner) and (not Owner.C4s or #Owner.C4s == 0) then
		Owner.C4s = {}
	end
	timer.Simple(0.3, function()
		if IsValid(self) then
			self:EmitSound("hoff/mpl/seal_c4/bar_selectorswitch.wav", 45)
		end
	end)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetHoldType("Slam")

	return true
end

function SWEP:StartExplosionChain()
	local Owner = self:GetOwner()
	if not IsValid(Owner) or not Owner.C4s or #Owner.C4s <= 0 then
		return
	end
	local Ent = Owner.C4s[1]

	if not IsValid(Ent) then
		table.remove(Owner.C4s, 1)
		self:StartExplosionChain()
		return
	end

	if Ent.QueuedForExplode then
		return
	end

	Ent.QueuedForExplode = true
	Ent.ExplodedViaWorld = false
	Ent:DelayedDestroy(true)
end

function SWEP:PrimaryAttack()
	local Owner = self:GetOwner()
	if not IsValid(Owner) or not Owner:Alive() then
		return
	end

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	timer.Simple(0.1,function()
		if IsValid(self) then
			self:EmitSound("hoff/mpl/seal_c4/c4_click.wav")
		end
	end)

	if SERVER then
		timer.Simple(0.175, function()
			if IsValid(self) and IsValid(Owner) and Owner:Alive() then
				self:StartExplosionChain()
			end
		end)
	end

	self:SetNextPrimaryFire(CurTime() + 1.1)

	-- Need to stop insane values from crashing servers
	local ThrowSpeedConVar = GetConVar("C4_ThrowSpeed")
	local ClampedThrowSpeed = math.Clamp(ThrowSpeedConVar and ThrowSpeedConVar:GetFloat() or 1, 0.25, 10)
	self:SetNextSecondaryFire(CurTime() + (0.8 / ClampedThrowSpeed))
end


if SERVER then
	hook.Add("PlayerDeath", "SetAllC4sUnowned", function(Victim, Weapon, Killer)
		if IsValid(Victim) and Victim:IsPlayer() and Victim.C4s then
			for _, Ent in pairs(Victim.C4s) do
				if IsValid(Ent) then
					Ent.ExplodedViaWorld = true
				end
			end
		end
	end)
end

function SWEP:SecondaryAttack()
	local Owner = self:GetOwner()
	if not IsValid(Owner) or not Owner:Alive() then
		return
	end

	local InfiniteConVar = GetConVar("C4_Infinite")
	if InfiniteConVar and InfiniteConVar:GetInt() == 0 and self:Ammo1() <= 0 then
		return
	end

	self:SendWeaponAnim(ACT_VM_THROW)
	Owner:SetAnimation(PLAYER_ATTACK1)

	self:EmitSound("hoff/mpl/seal_c4/whoosh_01.wav")
	timer.Simple(0.095, function()
		if not IsValid(self) or not IsValid(Owner) or not Owner:Alive() then
			return
		end
		if SERVER then

			local TargetPosition = Owner:GetShootPos() + (Owner:GetRight() * -8) + (Owner:GetUp() * -1) + (Owner:GetForward() * 10)

			local model = "models/hoff/weapons/c4/w_c4.mdl"
			util.PrecacheModel(model)

			local TempC4 = ents.Create("prop_physics")
			if not IsValid(TempC4) then
				return
			end
			TempC4:SetModel(model)
			TempC4:SetPos(TargetPosition)
			TempC4:SetCollisionGroup(COLLISION_GROUP_NONE)
			TempC4:Spawn()

			local mins, maxs = TempC4:GetCollisionBounds()

			TempC4:Remove()

			-- Use the mins and maxs vectors to check if there is enough space to spawn another c4
			local tr = util.TraceHull({start = TargetPosition, endpos = TargetPosition, mins = mins, maxs = maxs, mask = MASK_BLOCKLOS})

			-- Check if the trace hit something
			if not Owner:IsLineOfSightClear(TargetPosition) or tr.Hit then
				TargetPosition = Owner:EyePos()
			end

			local ent = ents.Create("cod-c4")
			if not IsValid(ent) then
				return
			end
			ent:SetPos(Vector(0,0,0))
			ent:SetOwner(Owner)
			ent:SetPos(TargetPosition)
			ent:SetAngles(Angle(1,0,0))
			ent:Spawn()
			ent:SetOwner(Owner)
			ent.C4Owner = Owner
			ent.ThisTrigger = self
			ent.ExplodedViaWorld = false
			ent.QueuedForExplode = false
			ent.UniqueExplodeTimer = "ExplodeTimer" .. Owner:SteamID() .. math.Rand(1, 1000)
			ent:SetNWString("OwnerID", Owner:SteamID())

			local phys = ent:GetPhysicsObject()
			if not IsValid(phys) then
				ent:Remove()
				return
			end

			--phys:SetMass(0.6)

			-- Compensate for the offcenter spawn
			local aimvector = Owner:GetAimVector()
			local aimangle = aimvector:Angle()
			aimangle:RotateAroundAxis(aimangle:Up(), -1.5)
			aimvector = aimangle:Forward()
			phys:ApplyForceCenter( aimvector * 1500)

			-- The positive z coordinate emulates the spin from a left underhand throw
			local angvel = Vector(0, math.random(-5000,-2000), math.random(-100,-900))
			angvel:Rotate(-1 * ent:EyeAngles())
			angvel:Rotate(Angle(0, Owner:EyeAngles().y, 0))

			--local angvel = Vector(0, math.random(-5000,-2000), math.random(-100,-900))
			angvel.x = math.Clamp(angvel.x, -1000, 1000)
			angvel.y = math.Clamp(angvel.y, -1000, 1000)
			angvel.z = math.Clamp(angvel.z, -1000, 1000)

			phys:SetAngleVelocity(Vector(math.Clamp(angvel.x, -2000, 2000), math.Clamp(angvel.y, -2000, 2000), math.Clamp(angvel.z, -2000, 2000)))

			Owner.C4s = Owner.C4s or {}
			Owner.C4s[#Owner.C4s + 1] = ent
			if engine.ActiveGamemode() ~= "nzombies" then
				undo.Create("C4")
					undo.AddEntity(ent)
					undo.SetPlayer(Owner)
					undo.AddFunction(function(UndoFunc)
						local UndoEnt = UndoFunc.Entities[1]

						-- Check if the entity is still valid
						if IsValid(UndoEnt) and IsValid(UndoFunc.Owner) and UndoFunc.Owner.C4s then
							-- Remove the entity from the owner's C4s table
							table.RemoveByValue(UndoFunc.Owner.C4s, UndoEnt)
						else
							-- The c4 doesn't exist anymore (probably exploded)
							return false
						end
					end)
				undo.Finish()

				Owner:AddCount("sents", ent)
				Owner:AddCount("my_props", ent)
				Owner:AddCleanup("sents", ent)
				Owner:AddCleanup("my_props", ent)
			end
		end

		if InfiniteConVar and InfiniteConVar:GetInt() == 0 then
			Owner:RemoveAmmo(1,"slam")
		end
	end)

	self:SetNextPrimaryFire(CurTime() + 1.1)

	-- Need to stop insane values from crashing servers
	local ThrowSpeedConVar = GetConVar("C4_ThrowSpeed")
	local ClampedThrowSpeed = math.Clamp(ThrowSpeedConVar and ThrowSpeedConVar:GetFloat() or 1, 0.25, 10)
	self:SetNextSecondaryFire(CurTime() + (0.8 / ClampedThrowSpeed))
end

function SWEP:ShouldDropOnDie()
	return false
end

function SWEP:Reload()
	-- First, check if the reload delay has expired
	if self.ReloadDelay and CurTime() < self.ReloadDelay then
		return
	end

	local Owner = self:GetOwner()
	if not IsValid(Owner) or not Owner:Alive() then
		return
	end

	-- Trace a line to a hit location and do a sphere trace from there and sort by distance
	-- We have to do this because GetEyeTrace to a c4 parented to an entity is unreliable
	local trace = util.TraceLine({
		start = Owner:EyePos(),
		endpos = Owner:EyePos() + Owner:EyeAngles():Forward() * 85,
		filter = {Owner}
	})
	local hitPos = trace.HitPos
	local c4s = ents.FindInSphere(hitPos, 1)
	table.sort(c4s, function(a, b) return a:GetPos():Distance(hitPos) < b:GetPos():Distance(hitPos) end)
	local hitEnt = nil
	for _, ent in ipairs(c4s) do
		if ent:GetClass() == "cod-c4" then
			hitEnt = ent
			break
		end
	end

	-- Check if the trace hit an entity and if it is a C4 entity
	if IsValid(hitEnt) and hitEnt:GetClass() == "cod-c4" and hitEnt:GetNWString("OwnerID") == Owner:SteamID() then
		-- Check if the C4 entity is owned by the player
		--if hitEnt:GetNWString("OwnerID") == self:GetOwner():SteamID() then

			if Owner:EyePos():Distance(hitEnt:GetPos()) > 85 then
				return
			end

			local effectData = EffectData()
			effectData:SetOrigin(hitEnt:GetPos())
			util.Effect("inflator_magic", effectData)

			if SERVER then
				local InfiniteConVar = GetConVar("C4_Infinite")
				if InfiniteConVar and InfiniteConVar:GetBool() == false then
					-- Give the player one "Slam" ammo
					Owner:GiveAmmo(1, "Slam")
				end

				-- Remove the C4 entity from the player's C4s array
				if Owner.C4s and table.HasValue(Owner.C4s, hitEnt) then
					table.RemoveByValue(Owner.C4s, hitEnt)
				end

				-- Remove the C4 entity from the world
				hitEnt:Remove()
			--else
				--if self.HasContextAnims then
				--	net.Start("VManip_SimplePlay") 
				--	net.WriteString("use") 
				--	net.Send(self.Owner)
				--end
			end

			-- Set the reload delay so the player cannot reload again for 0.5 seconds
			self.ReloadDelay = CurTime() + 0.5
		--end
	end
end

function SWEP:DoDrawCrosshair(x, y)
	surface.SetDrawColor( 255, 255, 255, 255 )
	surface.SetMaterial( Material("models/hoff/weapons/c4/c4_reticle.png") )
	surface.DrawTexturedRect( ScrW() / 2 - 16, ScrH() / 2 - 16, 32, 32 )
	return true
end
