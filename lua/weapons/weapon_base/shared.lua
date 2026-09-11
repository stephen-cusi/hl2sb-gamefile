--[[--------------------------------------------------------------------
    weapon_base  --  Faithful GMod SWEP base ported to HL2SB.

    Source: Facepunch/garrysmod  gamemodes/base/entities/weapons/
            weapon_base/shared.lua  (verbatim method set, GMod semantics).

    HL2SB adaptations (engine-level, no shims):
      * SetHoldType(t) -> drives HL2SB's m_acttable (numeric baseAct ->
        weaponAct triples) so the player body/world-model animates.  GMod's
        engine reads HoldType; HL2SB's postures from m_acttable.  We keep the
        GMod HoldType name and the helper, and map it here.
      * Clip1/Clip2/Ammo1/Ammo2/SetClip1/SetClip2/GetPrimaryAmmoType/
        GetSecondaryAmmoType refer to the engine bindings.
----------------------------------------------------------------------]]--

-- PrintName / header fields (GMod shows these on the HUD)
SWEP.PrintName		= "Scripted Weapon"
SWEP.Author			= ""
SWEP.Contact		= ""
SWEP.Purpose		= ""
SWEP.Instructions	= ""
SWEP.Category		= ""

SWEP.ViewModelFOV	= 62
SWEP.ViewModelFlip	= false
SWEP.UseHands		= true

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

-- GMod-style hold type.  Kept as a name AND mapped to m_acttable in
-- SetHoldType so HL2SB world/body animation stays correct.
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

-- Default m_acttable.  GMod SWEPs call SetHoldType("pistol") etc. so this is
-- replaced on Initialize; kept as a sane pistol default for any SWEP that
-- never sets a hold type.  Base acts: ACT_HL2MP_* / ACT_RANGE_ATTACK1.
-- Weapon acts: ACT_HL2MP_*_PISTOL / ACT_RANGE_ATTACK_PISTOL.
SWEP.m_acttable = {
	{ ACT_HL2MP_IDLE, ACT_HL2MP_IDLE_PISTOL, false },
	{ ACT_HL2MP_RUN, ACT_HL2MP_RUN_PISTOL, false },
	{ ACT_HL2MP_IDLE_CROUCH, ACT_HL2MP_IDLE_CROUCH_PISTOL, false },
	{ ACT_HL2MP_WALK_CROUCH, ACT_HL2MP_WALK_CROUCH_PISTOL, false },
	{ ACT_HL2MP_GESTURE_RANGE_ATTACK, ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL, false },
	{ ACT_HL2MP_GESTURE_RELOAD, ACT_HL2MP_GESTURE_RELOAD_PISTOL, false },
	{ ACT_HL2MP_JUMP, ACT_HL2MP_JUMP_PISTOL, false },
	{ ACT_RANGE_ATTACK1, ACT_RANGE_ATTACK_PISTOL, false },
}

-- HoldType -> m_acttable.  For now "pistol"/"normal" cover the HL2SB pistol
-- body animation; more hold types map onto the pistol set as a stable default.
local HoldTypeActtables = {
	["pistol"]	=
	{
		{ ACT_HL2MP_IDLE, ACT_HL2MP_IDLE_PISTOL, false },
		{ ACT_HL2MP_RUN, ACT_HL2MP_RUN_PISTOL, false },
		{ ACT_HL2MP_IDLE_CROUCH, ACT_HL2MP_IDLE_CROUCH_PISTOL, false },
		{ ACT_HL2MP_WALK_CROUCH, ACT_HL2MP_WALK_CROUCH_PISTOL, false },
		{ ACT_HL2MP_GESTURE_RANGE_ATTACK, ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL, false },
		{ ACT_HL2MP_GESTURE_RELOAD, ACT_HL2MP_GESTURE_RELOAD_PISTOL, false },
		{ ACT_HL2MP_JUMP, ACT_HL2MP_JUMP_PISTOL, false },
		{ ACT_RANGE_ATTACK1, ACT_RANGE_ATTACK_PISTOL, false },
	},
	["normal"]	=
	{
		{ ACT_HL2MP_IDLE, ACT_HL2MP_IDLE_PISTOL, false },
		{ ACT_HL2MP_RUN, ACT_HL2MP_RUN_PISTOL, false },
		{ ACT_HL2MP_IDLE_CROUCH, ACT_HL2MP_IDLE_CROUCH_PISTOL, false },
		{ ACT_HL2MP_WALK_CROUCH, ACT_HL2MP_WALK_CROUCH_PISTOL, false },
		{ ACT_HL2MP_GESTURE_RANGE_ATTACK, ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL, false },
		{ ACT_HL2MP_GESTURE_RELOAD, ACT_HL2MP_GESTURE_RELOAD_PISTOL, false },
		{ ACT_HL2MP_JUMP, ACT_HL2MP_JUMP_PISTOL, false },
		{ ACT_RANGE_ATTACK1, ACT_RANGE_ATTACK_PISTOL, false },
	},
}

--[[---------------------------------------------------------
	Name: SWEP:SetHoldType
	Desc: GMod sets a hold type string; HL2SB animates via m_acttable.
		  We keep the GMod API and translate to the activity table.
-----------------------------------------------------------]]
function SWEP:SetHoldType( t )
	-- GMod hold types are matched case-insensitively ("Pistol" == "pistol").
	t = string.lower( t or "normal" )
	self.HoldType = t
	self.m_acttable = HoldTypeActtables[ t ] or HoldTypeActtables[ "normal" ]
	return self.HoldType
end

-- GMod API name: stock SWEP Initialize calls self:SetWeaponHoldType(t).
SWEP.SetWeaponHoldType = SWEP.SetHoldType

--[[---------------------------------------------------------
	Name: SWEP:Initialize
-----------------------------------------------------------]]
function SWEP:Initialize()
	self:SetHoldType( self.HoldType or "pistol" )
	self.m_bReloadsSingly	= false
	self.m_bFiresUnderwater	= true
	if ( self.Primary and self.Primary.ClipSize and self.Primary.ClipSize ~= -1 ) then
		self.m_iClip1 = self.Primary.DefaultClip or self.Primary.ClipSize
	end
	if ( self.Secondary and self.Secondary.ClipSize and self.Secondary.ClipSize ~= -1 ) then
		self.m_iClip2 = self.Secondary.DefaultClip or self.Secondary.ClipSize
	end
	self.m_flNextPrimaryAttack	= 0
	self.m_flNextSecondaryAttack	= 0
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:PrimaryAttack
-----------------------------------------------------------]]
function SWEP:PrimaryAttack()
	if ( not self:CanPrimaryAttack() ) then return end
	-- HL2SB FX DEBUG (temporary): which realm runs the Lua attack?  If both run,
	-- every sound is emitted twice (client + server) and bullet effects depend
	-- on the client-side FireBullets actually executing.
	print( "[swepdbg] PrimaryAttack realm=" .. ( SERVER and "sv" or "cl" ) )
	self:EmitSound( self.Primary.Sound or "Weapon_AR2.Single" )
	self:ShootBullet( self.Primary.Damage or 150, self.Primary.NumberofShots or 1,
		(self.Primary.Spread or 0.01) * 0.1, self.Primary.Ammo or "Pistol",
		self.Primary.Force or 1, 5 )
	self:TakePrimaryAmmo( self.Primary.TakeAmmo or 1 )
	local owner = self:GetOwner()
	if ( IsValid( owner ) and not owner:IsNPC() ) then
		owner:ViewPunch( Angle( -( self.Primary.Recoil or 1 ), 0, 0 ) )
	end
end

--[[---------------------------------------------------------
	Name: SWEP:SecondaryAttack
-----------------------------------------------------------]]
function SWEP:SecondaryAttack()
	if ( not self:CanSecondaryAttack() ) then return end
	-- HL2SB FX DEBUG (temporary)
	print( "[swepdbg] SecondaryAttack realm=" .. ( SERVER and "sv" or "cl" ) )
	self:EmitSound( self.Secondary.Sound or "Weapon_Shotgun.Single" )
	self:ShootBullet( self.Secondary.Damage or 150, self.Secondary.NumberofShots or 9,
		(self.Secondary.Spread or 0.2) * 0.1, self.Secondary.Ammo or self.Primary.Ammo or "Pistol",
		self.Secondary.Force or 1, 5 )
	self:TakeSecondaryAmmo( self.Secondary.TakeAmmo or 1 )
	local owner = self:GetOwner()
	if ( IsValid( owner ) and not owner:IsNPC() ) then
		owner:ViewPunch( Angle( -( self.Secondary.Recoil or 10 ), 0, 0 ) )
	end
end

--[[---------------------------------------------------------
	Name: SWEP:Reload
-----------------------------------------------------------]]
function SWEP:Reload()
	return self:DefaultReload( self:GetMaxClip1(), self:GetMaxClip2(), ACT_VM_RELOAD )
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
-----------------------------------------------------------]]
function SWEP:Deploy()
	self:SendWeaponAnim( ACT_VM_DRAW )
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
	if ( self:GetOwner() ) then
		self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
		owner:DoMuzzleFlash()
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
	if ( not self:GetOwner() ) then return 0 end
	return self:GetOwner():GetAmmoCount( self:GetPrimaryAmmoType() )
end

--[[---------------------------------------------------------
	Name: SWEP:Ammo2
-----------------------------------------------------------]]
function SWEP:Ammo2()
	if ( not self:GetOwner() ) then return 0 end
	return self:GetOwner():GetAmmoCount( self:GetSecondaryAmmoType() )
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

--[[---------------------------------------------------------
	SWEP:NetworkVar( type, slot, name )

	GMod declares network variables inside SWEP:SetupDataTables(), and its
	engine turns each declaration into the Set<name>/Get<name> methods the SWEP
	calls (weapon_medkit declares LastAmmoRegen, for instance).  HL2SB's engine
	has no DataTable slots for Lua weapons, so the accessors are defined here and
	keep their value on the weapon's own table -- one table per entity, because
	the engine hands every weapon a copy of the class table in InitScriptedWeapon.

	SetupDataTables() itself is called by the engine, the same place GMod calls it.
-----------------------------------------------------------]]
local NW_DEFAULTS = {
	Float = 0,
	Int = 0,
	Bool = false,
	String = "",
}

function SWEP:NetworkVar( nwType, slot, name )
	local key = "__nw_" .. name

	self[ "Set" .. name ] = function( self, value )
		self[ key ] = value
	end

	self[ "Get" .. name ] = function( self )
		local value = self[ key ]

		if ( value == nil ) then
			if ( nwType == "Vector" ) then return Vector( 0, 0, 0 ) end
			if ( nwType == "Angle" ) then return Angle( 0, 0, 0 ) end
			return NW_DEFAULTS[ nwType ]
		end

		return value
	end
end
