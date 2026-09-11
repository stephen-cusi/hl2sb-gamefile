
AddCSLuaFile()

SWEP.PrintName = "#weapon_flechettegun"
SWEP.Author = "garry"
SWEP.Purpose = "Shoot flechettes with primary attack."

SWEP.Slot = 1
SWEP.SlotPos = 2

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_smg1.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_smg1.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.AdminOnly = true

game.AddParticles( "particles/hunter_flechette.pcf" )
game.AddParticles( "particles/hunter_projectile.pcf" )

local ShootSound = Sound( "NPC_Hunter.FlechetteShoot" )

function SWEP:Initialize()

	self:SetHoldType( "smg" )

end

function SWEP:Reload()
end

function SWEP:CanBePickedUpByNPCs()
	return true
end

function SWEP:PrimaryAttack()

	self:SetNextPrimaryFire( CurTime() + 0.1 )

	self:EmitSound( ShootSound )
	self:ShootEffects()

	if ( CLIENT ) then return end

	SuppressHostEvents( NULL ) -- Do not suppress the flechette effects

	local ent = ents.Create( "hunter_flechette" )
	if ( !IsValid( ent ) ) then
		-- HL2SB: EP2's "hunter_flechette" entity is not registered in this build
		-- (HL2SB's server links server_base + server_hl2mp + server_lua, not
		-- server_episodic, and the class lives in episodic/npc_hunter.cpp), so
		-- Create() fails and the gun used to fire nothing at all.  Fall back to a
		-- hitscan shot with the same damage until the real projectile is ported.
		local owner = self:GetOwner()
		if ( IsValid( owner ) ) then
			self:ShootBullet( 12, 1, 0.01, self.Primary.Ammo, 5, 0 )
		end
		return
	end

	local owner = self:GetOwner()

	-- Calculate the spawn position
	local startPos = owner:GetShootPos()

	local fwd = owner:GetAimVector()
	local targetPos = startPos + fwd * 32

	-- Trace forward and check if the projectile would spawn behind a wall or something
	local tr = util.TraceLine( { start = startPos, endpos = targetPos, filter = owner } )
	if ( tr.Hit ) then targetPos = tr.HitPos - fwd * 3 end -- Also move it back a bit so they don't poke out the other side of the wall

	ent:SetPos( targetPos )

	ent:SetAngles( fwd:Angle() )
	ent:SetOwner( owner )
	ent:Spawn()
	ent:Activate()

	ent:SetVelocity( fwd * 2000 )

end

function SWEP:SecondaryAttack()
end

function SWEP:ShouldDropOnDie()

	return false

end

function SWEP:GetNPCRestTimes()

	-- Handles the time between bursts
	-- Min rest time in seconds, max rest time in seconds

	return 0.3, 0.6

end

function SWEP:GetNPCBurstSettings()

	-- Handles the burst settings
	-- Minimum amount of shots, maximum amount of shots, and the delay between each shot
	-- The amount of shots can end up lower than specificed

	return 1, 6, 0.1

end

function SWEP:GetNPCBulletSpread( proficiency )

	-- Handles the bullet spread based on the given proficiency
	-- return value is in degrees

	return 1

end
