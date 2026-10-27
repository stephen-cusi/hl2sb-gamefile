-- Remaining weapon helpers are pending native weapon migration.

-- PrintName / header fields (GMod shows these on the HUD)
SWEP.PrintName		= "Scripted Weapon"
SWEP.Author			= ""
SWEP.Contact		= ""
SWEP.Purpose		= ""
SWEP.Instructions	= ""
SWEP.Category		= ""

SWEP.ViewModelFOV	= 62
SWEP.ViewModelFlip	= false

-- HL2SB scripted-weapon flat keys (engine reads these in InitScriptedWeapon).
-- GMod SWEPs set capitalised ViewModel/WorldModel; engine falls back to them.
SWEP.ViewModel		= "models/weapons/v_357.mdl"
SWEP.WorldModel		= "models/weapons/w_357.mdl"
SWEP.viewmodel		= SWEP.ViewModel
SWEP.playermodel	= SWEP.WorldModel
SWEP.anim_prefix	= "python"
SWEP.bucket		= 1
SWEP.bucket_position	= 1

SWEP.clip_size		= -1
SWEP.clip2_size		= -1
SWEP.default_clip		= -1
SWEP.default_clip2	= -1
SWEP.primary_ammo		= "Pistol"
SWEP.secondary_ammo	= "None"

SWEP.weight			= 5
SWEP.item_flags		= 0
SWEP.showusagehint	= 0
SWEP.autoswitchto	= 1
SWEP.autoswitchfrom	= 1
SWEP.BuiltRightHanded	= 1
SWEP.AllowFlipping	= 1
SWEP.MeleeWeapon	= 0

SWEP.Spawnable		= false
SWEP.AdminSpawnable	= false
SWEP.Spawnable		= false
SWEP.AdminOnly		= false

-- Initial hold type; native state drives the original animation mapping.
SWEP.HoldType		= "normal"

-- Default Primary/Secondary tables (GMod defaults)
SWEP.Primary = {
	Sound			= "Weapon_Pistol.Single",
	Damage			= 10,
	TakeAmmo		= 1,
	ClipSize		= -1,
	Ammo			= "Pistol",
	DefaultClip		= -1,
	Spread			= 0.01,
	NumberofShots	= 1,
	Automatic		= false,
	Recoil			= 2,
	Delay			= 0.2,
	Force			= 0,
}

SWEP.Secondary = {
	Sound			= "Weapon_Pistol.Empty",
	Damage			= 0,
	TakeAmmo		= 0,
	ClipSize		= -1,
	Ammo			= "None",
	DefaultClip		= -1,
	Spread			= 0.01,
	NumberofShots	= 1,
	Automatic		= false,
	Recoil			= 0,
	Delay			= 0.4,
	Force			= 0,
}

--[[---------------------------------------------------------
	Name: SWEP:SetLastShootTime / SWEP:LastShootTime
	Desc: GMod Weapon:SetLastShootTime( time = CurTime() ) /
		  Weapon:LastShootTime().  Engine-side it is set when the weapon
		  fires a bullet; here the Lua base records it in the default
		  PrimaryAttack/SecondaryAttack below.  Not networked, same as
		  GMod.
-----------------------------------------------------------]]
function SWEP:SetLastShootTime( t )
	self.m_tLastShoot = t or CurTime()
end

function SWEP:LastShootTime()
	return self.m_tLastShoot or 0
end

--[[---------------------------------------------------------
	Name: SWEP:Initialize
-----------------------------------------------------------]]
function SWEP:Initialize()
	self:SetHoldType( self.HoldType or "pistol" )
end

--[[---------------------------------------------------------
	Name: SWEP:PrimaryAttack
-----------------------------------------------------------]]
function SWEP:PrimaryAttack()
	if ( not self:CanPrimaryAttack() ) then return end
	self:EmitSound( self.Primary.Sound or "Weapon_AR2.Single" )
	self:ShootBullet( self.Primary.Damage or 150, self.Primary.NumberofShots or 1,
		(self.Primary.Spread or 0.01) * 0.1, self.Primary.Ammo or "Pistol",
		self.Primary.Force or 1, 5 )
	self:TakePrimaryAmmo( self.Primary.TakeAmmo or 1 )
	local owner = self:GetOwner()
	if ( IsValid( owner ) and not owner:IsNPC() ) then
		owner:ViewPunch( Angle( -( self.Primary.Recoil or 1 ), 0, 0 ) )
	end
	self:SetLastShootTime()
end

--[[---------------------------------------------------------
	Name: SWEP:SecondaryAttack
-----------------------------------------------------------]]
function SWEP:SecondaryAttack()
	if ( not self:CanSecondaryAttack() ) then return end
	self:EmitSound( self.Secondary.Sound or "Weapon_Shotgun.Single" )
	self:ShootBullet( self.Secondary.Damage or 150, self.Secondary.NumberofShots or 9,
		(self.Secondary.Spread or 0.2) * 0.1, self.Secondary.Ammo or self.Primary.Ammo or "Pistol",
		self.Secondary.Force or 1, 5 )
	self:TakeSecondaryAmmo( self.Secondary.TakeAmmo or 1 )
	local owner = self:GetOwner()
	if ( IsValid( owner ) and not owner:IsNPC() ) then
		owner:ViewPunch( Angle( -( self.Secondary.Recoil or 10 ), 0, 0 ) )
	end
	self:SetLastShootTime()
end

--[[---------------------------------------------------------
	Name: SWEP:Reload
	Desc: GMod form -- DefaultReload( act ) fills both clips from the
	      weapon's max clip sizes (the engine binding accepts the GMod
	      single-argument call and the Source three-argument call).
-----------------------------------------------------------]]
function SWEP:Reload()
	return self:DefaultReload( ACT_VM_RELOAD )
end

--[[---------------------------------------------------------
	Name: SWEP:Think
-----------------------------------------------------------]]
function SWEP:Think()
end

--[[---------------------------------------------------------
	Name: SWEP:Holster
-----------------------------------------------------------]]
function SWEP:Holster( wep )
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:Deploy
	Desc: GMod verbatim -- return true.  The draw animation comes from
	      GetDrawActivity() below, which the engine dispatches.
-----------------------------------------------------------]]
function SWEP:Deploy()
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:CanHolster
-----------------------------------------------------------]]
function SWEP:CanHolster()
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:GetDrawActivity
-----------------------------------------------------------]]
function SWEP:GetDrawActivity()
	return ACT_VM_DRAW
end

--[[---------------------------------------------------------
	Name: SWEP:ShootEffects
-----------------------------------------------------------]]
function SWEP:ShootEffects()
	local owner = self:GetOwner()
	if ( owner ) then
		self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
		-- GMod names it MuzzleFlash; older HL2SB scripts use DoMuzzleFlash.
		if ( owner.MuzzleFlash ) then
			owner:MuzzleFlash()
		elseif ( owner.DoMuzzleFlash ) then
			owner:DoMuzzleFlash()
		end
		owner:SetAnimation( PLAYER_ATTACK1 )
	end
end

--[[---------------------------------------------------------
	Name: SWEP:ShootBullet
	Desc: A convenience function to shoot bullets (GMod).
-----------------------------------------------------------]]
function SWEP:ShootBullet( damage, num_bullets, aimcone, ammo_type, force, tracer )
	self:ShootEffects()
	local owner = self:GetOwner()
	if ( not IsValid( owner ) ) then return end
	local bullet = {}
	bullet.Num		= num_bullets
	bullet.Src		= owner:GetShootPos()
	bullet.Dir		= owner:GetAimVector()
	bullet.Spread	= Vector( aimcone or 0, aimcone or 0, 0 )
	bullet.Tracer	= tracer or 5
	bullet.Force	= force or 1
	bullet.Damage	= damage
	bullet.AmmoType = ammo_type or self.Primary.Ammo or "Pistol"
	bullet.Attacker	= owner
	bullet.Inflictor = self
	owner:FireBullets( bullet )
end

--[[---------------------------------------------------------
	Name: SWEP:TakePrimaryAmmo
-----------------------------------------------------------]]
function SWEP:TakePrimaryAmmo( num )
	if ( self:Clip1() <= 0 ) then
		if ( self:Ammo1() <= 0 ) then return end
		self:GetOwner():RemoveAmmo( num, self:GetPrimaryAmmoType() )
		return
	end
	self:SetClip1( self:Clip1() - num )
end

--[[---------------------------------------------------------
	Name: SWEP:TakeSecondaryAmmo
-----------------------------------------------------------]]
function SWEP:TakeSecondaryAmmo( num )
	if ( self:Clip2() <= 0 ) then
		if ( self:Ammo2() <= 0 ) then return end
		self:GetOwner():RemoveAmmo( num, self:GetSecondaryAmmoType() )
		return
	end
	self:SetClip2( self:Clip2() - num )
end

--[[---------------------------------------------------------
	Name: SWEP:CanPrimaryAttack
-----------------------------------------------------------]]
function SWEP:CanPrimaryAttack()
	if ( self:Clip1() <= 0 ) then
		self:EmitSound( "Weapon_Pistol.Empty" )
		self:SetNextPrimaryFire( CurTime() + 0.2 )
		self:Reload()
		return false
	end
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:CanSecondaryAttack
-----------------------------------------------------------]]
function SWEP:CanSecondaryAttack()
	if ( self:Clip2() <= 0 ) then
		self:EmitSound( "Weapon_Pistol.Empty" )
		self:SetNextSecondaryFire( CurTime() + 0.2 )
		return false
	end
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:OnRemove
-----------------------------------------------------------]]
function SWEP:OnRemove()
end

--[[---------------------------------------------------------
	Name: SWEP:OwnerChanged
-----------------------------------------------------------]]
function SWEP:OwnerChanged()
end

--[[---------------------------------------------------------
	Name: SWEP:Ammo1
-----------------------------------------------------------]]
function SWEP:Ammo1()
	-- Owner cannot have ammo? Such as NPCs.  (Also covers "no owner".)
	local owner = self:GetOwner()
	if ( not owner or not owner.GetAmmoCount ) then return 0 end
	return owner:GetAmmoCount( self:GetPrimaryAmmoType() )
end

--[[---------------------------------------------------------
	Name: SWEP:Ammo2
-----------------------------------------------------------]]
function SWEP:Ammo2()
	local owner = self:GetOwner()
	if ( not owner or not owner.GetAmmoCount ) then return 0 end
	return owner:GetAmmoCount( self:GetSecondaryAmmoType() )
end

--[[---------------------------------------------------------
	Name: SWEP:KeyDown / SWEP:KeyDownLast
	Desc: GMod SWEP base forwards these to the owning player
	      (Player:KeyDown / Player:KeyDownLast, IN_* masks).
-----------------------------------------------------------]]
function SWEP:KeyDown( inKey )
	local owner = self:GetOwner()
	if ( not owner or not owner.KeyDown ) then return false end
	return owner:KeyDown( inKey )
end

function SWEP:KeyDownLast( inKey )
	local owner = self:GetOwner()
	if ( not owner or not owner.KeyDownLast ) then return false end
	return owner:KeyDownLast( inKey )
end

--[[---------------------------------------------------------
	Name: SWEP:DoImpactEffect
-----------------------------------------------------------]]
function SWEP:DoImpactEffect( tr, nDamageType )
	return false
end

--[[---------------------------------------------------------
	Name: SWEP:ItemBusyFrame
-----------------------------------------------------------]]
function SWEP:ItemBusyFrame()
end

-- ===========================================================================
-- HL2SB (2026-10-03): WEAPON:CallOnClient( method, argument ) -- GMod
-- contract.  GMod queues a method call on the client-side copy of this
-- weapon for its owner (a "SWEPCmd" usermessage: weapon entindex, method
-- name, one optional argument string).  The same trip here goes over the
-- net library, which both realms already register; this fork's net payload
-- is capped at 255 bytes, the same practical limit GMod's usermessage has.
--
-- NOTE: this is a weapon_base class method, not an engine binding -- GMod
-- binds it C-side on every scripted weapon, so weapons that do not derive
-- from weapon_base do not have it here.
-- ===========================================================================
if ( SERVER ) then
	util.AddNetworkString( "hl2sb_swepcmd" )
end

if ( CLIENT ) then
	net.Receive( "hl2sb_swepcmd", function()
		local wep = net.ReadEntity()
		local method = net.ReadString()
		local argument = net.ReadString()

		if ( not IsValid( wep ) or method == "" ) then return end

		local fn = wep[ method ]
		if ( type( fn ) != "function" ) then return end

		fn( wep, argument )
	end )
end

function SWEP:CallOnClient( method, argument )
	if ( not SERVER ) then return end

	local owner = self:GetOwner()
	if ( not IsValid( owner ) or not owner.IsPlayer or not owner:IsPlayer() ) then
		print( "[HL2SB] ERROR! CallOnClient called on weapon without an owner!\n" )
		return
	end

	net.Start( "hl2sb_swepcmd" )
	net.WriteEntity( self )
	net.WriteString( method or "" )
	net.WriteString( argument or "" )
	net.Send( owner )
end
