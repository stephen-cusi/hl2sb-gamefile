--===== weapon_base (GMod-compatible) for hl2sb =====--
-- NO m_acttable (avoids "Bad pstudiohdr in GetSequenceLinearMotion()" crash).

SWEP.Base = "weapon_base"
SWEP.HoldType = "normal"
SWEP.Spawnable = false
SWEP.AdminSpawnable = false
SWEP.Weight = 5
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = true

-- Empty defaults; each SWEP sets its own models. Both key styles: C++
-- reads lowercase "viewmodel"/"playermodel" (uppercase fallback added),
-- Lua GetViewModel()/GetWorldModel() read the capitalized keys.
SWEP.ViewModel = ""
SWEP.WorldModel = ""
SWEP.viewmodel = SWEP.ViewModel
SWEP.playermodel = SWEP.WorldModel

SWEP.Primary = {
	Sound = "Weapon_Pistol.Single", Damage = 10, TakeAmmo = 1, ClipSize = -1,
	Ammo = "Pistol", DefaultClip = -1, Spread = 0.01, NumberofShots = 1,
	Automatic = false, Recoil = 2, Delay = 0.2, Force = 0,
}
SWEP.Secondary = {
	Sound = "Weapon_Pistol.Empty", Damage = 0, TakeAmmo = 0, ClipSize = -1,
	Ammo = "None", DefaultClip = -1, Spread = 0.01, NumberofShots = 1,
	Automatic = false, Recoil = 0, Delay = 0.4, Force = 0,
}

function SWEP:Initialize()
	self.m_bReloadsSingly = false
	self.m_bFiresUnderwater = true
	if self.Primary and self.Primary.ClipSize and self.Primary.ClipSize ~= -1 then
		self.m_iClip1 = self.Primary.DefaultClip or self.Primary.ClipSize
	end
	if self.Secondary and self.Secondary.ClipSize and self.Secondary.ClipSize ~= -1 then
		self.m_iClip2 = self.Secondary.DefaultClip or self.Secondary.ClipSize
	end
	self.m_flNextPrimaryAttack = 0
	self.m_flNextSecondaryAttack = 0
	return true
end

function SWEP:SetWeaponHoldType( t )
	self.HoldType = t or "normal"
	return self.HoldType
end

function SWEP:CanPrimaryAttack()
	if self.Primary.ClipSize == nil or self.Primary.ClipSize == -1 then return true end
	if self.m_iClip1 <= 0 then self:Reload(); return false end
	return true
end

function SWEP:CanSecondaryAttack()
	if self.Secondary.ClipSize == nil or self.Secondary.ClipSize == -1 then return true end
	if self.m_iClip2 <= 0 then self:Reload(); return false end
	return true
end

function SWEP:SetNextPrimaryFire( t ) self.m_flNextPrimaryAttack = t end
function SWEP:SetNextSecondaryFire( t ) self.m_flNextSecondaryAttack = t end

function SWEP:TakePrimaryAmmo( count )
	count = count or 1
	self.m_iClip1 = self.m_iClip1 - count
	if self.m_iClip1 < 0 then self.m_iClip1 = 0 end
end

function SWEP:TakeSecondaryAmmo( count )
	count = count or 1
	self.m_iClip2 = self.m_iClip2 - count
	if self.m_iClip2 < 0 then self.m_iClip2 = 0 end
end

function SWEP:ShootEffects()
	self:SendWeaponAnim( 180 )
	local o = self:GetOwner()
	if o then o:DoMuzzleFlash(); o:SetAnimation( 5 ) end
end

function SWEP:ShootBullet( damage, num_bullets, aimcone, ammo_type, force, tracer )
	local o = self:GetOwner()
	if not o then return end
	local bullet = {
		Num = num_bullets or 1, Src = o:GetShootPos(), Dir = o:GetAimVector(),
		Spread = Vector( aimcone or 0, aimcone or 0, 0 ), Tracer = tracer or 0,
		Force = force or 1, Damage = damage or 1,
		AmmoType = ammo_type or self.Primary.Ammo or "Pistol",
	}
	o:FireBullets( bullet )
end

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then return end
	local o = self:GetOwner()
	if not o then return end
	self:ShootEffects()
	self:ShootBullet( self.Primary.Damage or 1, self.Primary.NumberofShots or 1,
		(self.Primary.Spread or 0) * 0.1, self.Primary.Ammo or "Pistol",
		self.Primary.Force or 1, 0 )
	if self.Primary.Sound then self:EmitSound( Sound( self.Primary.Sound ) ) end
	if self.Primary.Recoil then
		local r = self.Primary.Recoil
		o:ViewPunch( Angle( -r, r * math.random( -1, 1 ), 0 ) )
	end
	self:TakePrimaryAmmo( self.Primary.TakeAmmo or 1 )
	local d = self.Primary.Delay or 0.2
	self:SetNextPrimaryFire( CurTime() + d )
	self:SetNextSecondaryFire( CurTime() + d )
end

function SWEP:SecondaryAttack()
	if not self:CanSecondaryAttack() then return end
	local o = self:GetOwner()
	if not o then return end
	self:ShootEffects()
	self:ShootBullet( self.Secondary.Damage or 1, self.Secondary.NumberofShots or 1,
		(self.Secondary.Spread or 0) * 0.1, self.Secondary.Ammo or "Pistol",
		self.Secondary.Force or 1, 0 )
	if self.Secondary.Sound then self:EmitSound( Sound( self.Secondary.Sound ) ) end
	if self.Secondary.Recoil then
		local r = self.Secondary.Recoil
		o:ViewPunch( Angle( -r, r * math.random( -1, 1 ), 0 ) )
	end
	self:TakeSecondaryAmmo( self.Secondary.TakeAmmo or 1 )
	local d = self.Secondary.Delay or 0.4
	self:SetNextPrimaryFire( CurTime() + d )
	self:SetNextSecondaryFire( CurTime() + d )
end

function SWEP:Reload()
	if self.m_bInReload then return false end
	return self:DefaultReload( self:GetMaxClip1(), self:GetMaxClip2(), 182 )
end

function SWEP:Deploy() return true end
function SWEP:Holster( pSwitchingTo ) return true end
function SWEP:CanHolster() return true end
function SWEP:GetDrawActivity() return 171 end
function SWEP:OwnerChanged() end
function SWEP:OnRemove() end

function SWEP:ItemPostFrame()
	if _CLIENT then return nil end
	local o = self:GetOwner()
	if ToBaseEntity( o ) == NULL then return false end
	if self._gmod_clip_seeded ~= true then
		self._gmod_clip_seeded = true
		if self.Primary and self.Primary.ClipSize and self.Primary.ClipSize ~= -1 then
			self.m_iClip1 = self.Primary.DefaultClip or self.Primary.ClipSize
		end
		if self.Secondary and self.Secondary.ClipSize and self.Secondary.ClipSize ~= -1 then
			self.m_iClip2 = self.Secondary.DefaultClip or self.Secondary.ClipSize
		end
	end
	local now = gpGlobals.curtime()
	local buttons = o.m_nButtons
	local pressed = o.m_afButtonPressed
	if bit.band( buttons, 1 ) ~= 0 then
		if self.Primary.Automatic then
			if self.m_flNextPrimaryAttack <= now then self:PrimaryAttack() end
		elseif bit.band( pressed, 1 ) ~= 0 and self.m_flNextPrimaryAttack <= now then
			self:PrimaryAttack()
		end
	end
	if bit.band( buttons, 2048 ) ~= 0 then
		if self.Secondary.Automatic then
			if self.m_flNextSecondaryAttack <= now then self:SecondaryAttack() end
		elseif bit.band( pressed, 2048 ) ~= 0 and self.m_flNextSecondaryAttack <= now then
			self:SecondaryAttack()
		end
	end
	if bit.band( buttons, 8192 ) ~= 0 and self:UsesClipsForAmmo1() and not self.m_bInReload then
		self:Reload()
	end
	return false
end

function SWEP:ItemBusyFrame() end
function SWEP:Think() end
function SWEP:DoImpactEffect() end