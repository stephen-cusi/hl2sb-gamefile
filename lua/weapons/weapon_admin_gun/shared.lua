--===== hl2sb "Admin Gun" (GMod-style SWEP, verified Approach B) =====--
-- Fires via Lua ItemPostFrame (auto-fire) and RETURNS FALSE to suppress the
-- engine base auto-fire loop (prevents double-fire). Uses only verified
-- bindings. print() traces are for live debugging.

SWEP.printname			= "Admin Gun"
-- capitalized keys: read by C++ GetPrintName/GetSlot/GetPosition (HUD name & slot)
SWEP.PrintName			= "Admin Gun"
SWEP.Slot				= 1
SWEP.SlotPos			= 1
-- lowercase: read by C++ InitScriptedWeapon for precache/info
SWEP.viewmodel			= "models/weapons/v_pist_weagon.mdl"
SWEP.playermodel		= "models/weapons/w_pist_weagon.mdl"
-- capitalized: read by C++ GetViewModel/GetWorldModel overrides (actual displayed model)
SWEP.ViewModel			= "models/weapons/v_pist_weagon.mdl"
SWEP.WorldModel			= "models/weapons/w_pist_weagon.mdl"
SWEP.anim_prefix		= "python"
SWEP.bucket				= 1
SWEP.bucket_position	= 1

SWEP.clip_size			= 9999999
SWEP.clip2_size			= -1
SWEP.default_clip		= 9999999
SWEP.default_clip2		= -1
SWEP.primary_ammo		= "Pistol"
SWEP.secondary_ammo		= "None"

SWEP.weight				= 7
SWEP.item_flags			= 0
SWEP.damage				= 99999999

SWEP.SoundData			= { empty = "Weapon_Pistol.Empty", single_shot = "Weapon_357.Single" }

SWEP.showusagehint		= 0
SWEP.autoswitchto		= 1
SWEP.autoswitchfrom		= 1
SWEP.BuiltRightHanded	= 1
SWEP.AllowFlipping		= 1
SWEP.MeleeWeapon		= 0

-- GMod-style config
SWEP.Primary	= { Automatic = true,  Delay = 0.05, Cone = 0.02, Shots = 3 }
SWEP.Secondary	= { Automatic = false, Delay = 0.40 }

function SWEP:Initialize()
	self.m_bReloadsSingly	= false
	self.m_bFiresUnderwater	= true
end

function SWEP:Precache() end

function SWEP:PrimaryAttack()
	print("AdminGun: PrimaryAttack\n")
	if _CLIENT then return end
	local pPlayer = self:GetOwner()
	if ToBaseEntity( pPlayer ) == NULL then return end
	if self.m_iClip1 <= 0 then
		self:WeaponSound( 0 )
		self.m_flNextPrimaryAttack = gpGlobals.curtime() + 0.5
		return
	end

	self:WeaponSound( 1 )
	pPlayer:DoMuzzleFlash()
	self:SendWeaponAnim( 180 )
	pPlayer:SetAnimation( 5 )
	ToHL2MPPlayer( pPlayer ):DoAnimationEvent( 0 )

	self.m_flNextPrimaryAttack   = gpGlobals.curtime() + ( self.Primary.Delay or 0.1 )
	self.m_flNextSecondaryAttack = gpGlobals.curtime() + ( self.Primary.Delay or 0.1 )
	self.m_iClip1 = self.m_iClip1 - 1

	local c = self.Primary.Cone or 0
	local n = self.Primary.Shots or 1
	local info = { m_iShots = n, m_vecSrc = pPlayer:Weapon_ShootPosition(),
	               m_vecDirShooting = pPlayer:GetAutoaimVector( 0.08715574274766 ),
	               m_vecSpread = Vector( c, c, c ), m_flDistance = MAX_TRACE_LENGTH,
	               m_iAmmoType = self.m_iPrimaryAmmoType }
	info.m_iDamage			= self.damage
	info.m_iPlayerDamage	= self.damage
	info.m_iTracerFreq		= 5
	info.m_pAttacker		= pPlayer
	pPlayer:FireBullets( info )
	pPlayer:ViewPunch( QAngle( -1.5, 0, 0 ) )
end

function SWEP:SecondaryAttack()
	print("AdminGun: SecondaryAttack\n")
	if _CLIENT then return end
	local pPlayer = self:GetOwner()
	if ToBaseEntity( pPlayer ) == NULL then return end

	self.m_flNextPrimaryAttack   = gpGlobals.curtime() + ( self.Secondary.Delay or 0.4 )
	self.m_flNextSecondaryAttack = gpGlobals.curtime() + ( self.Secondary.Delay or 0.4 )

	local vForward = Vector(); local vRight = Vector(); local vUp = Vector()
	local angle = QAngle(0,0,0)
	pPlayer:EyeVectors( vForward, vRight, vUp )
	local vecEye = pPlayer:EyePosition()
	tr = trace_t()
	MASK_SHOT = _E.MASK.SHOT
	util.TraceLine( vecEye + vForward * 50, vecEye + vForward * 56755, MASK_SHOT, self, 0, tr )

	self:WeaponSound( 1 )
	pPlayer:DoMuzzleFlash()
	self:SendWeaponAnim( 180 )
	pPlayer:SetAnimation( 5 )
	ToHL2MPPlayer( pPlayer ):DoAnimationEvent( 0 )
	effect.ExplosionCreate( tr.endpos, angle, pPlayer, 50, 200, true )
end

function SWEP:Reload()
	local fRet = self:DefaultReload( self:GetMaxClip1(), self:GetMaxClip2(), 182 )
	return fRet
end

function SWEP:Deploy() end
function SWEP:Holster( pSwitchingTo ) end
function SWEP:CanHolster() end
function SWEP:GetDrawActivity() return 171 end

-- Auto-fire loop (server authoritative). Return false so the engine base loop
-- does not also fire (double-fire prevention).
function SWEP:ItemPostFrame()
	if _CLIENT then return nil end
	local pPlayer = self:GetOwner()
	if ToBaseEntity( pPlayer ) == NULL then return false end
	local now = gpGlobals.curtime()
	local buttons = pPlayer.m_nButtons
	local pressed = pPlayer.m_afButtonPressed

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
function SWEP:DoImpactEffect() end
