--==========================================================--
--  pist_weagon  --  hl2sb "Admin Gun"-style SWEP
--
--  Modeled on the verified weapon_admin_gun (Approach B): native lowercase
--  fields + GMod self.Primary/self.Secondary tables + a Lua ItemPostFrame
--  that auto-fires and RETURNS FALSE to suppress the engine base loop
--  (prevents double-fire).  Only verified bindings are used.
--  Explosion goes through env_explosion entity + AcceptInput (no trace / no
--  _E.MASK dependency, which is nil at runtime).
--==========================================================--

-- Fallback for the C++ macro MAX_TRACE_LENGTH (worldsize.h) which is not a Lua
-- global; gmod_compat normally provides it.  Keep this so we don't depend on it.
if MAX_TRACE_LENGTH == nil then MAX_TRACE_LENGTH = 32768 end

SWEP.printname			= "pist_weagon"
-- capitalized keys: read by C++ GetPrintName/GetSlot/GetPosition (HUD name & slot)
SWEP.PrintName			= "pist_weagon"
SWEP.Slot				= 1
SWEP.SlotPos			= 1
-- lowercase: read by C++ InitScriptedWeapon for precache/info
SWEP.viewmodel			= "models/weapons/v_pist_weagon.mdl"
SWEP.playermodel		= "models/weapons/w_pist_weagon.mdl"
-- capitalized: read by C++ GetViewModel/GetWorldModel overrides (displayed model)
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
-- m_iPlayerDamage is an int; keep inside 32-bit range.
SWEP.damage				= 999999999

SWEP.SoundData			= { empty = "Weapon_Pistol.Empty", single_shot = "weapons/automag/deagle-1.wav" }

SWEP.showusagehint		= 0
SWEP.autoswitchto		= 1
SWEP.autoswitchfrom		= 1
SWEP.BuiltRightHanded	= 1
SWEP.AllowFlipping		= 1
SWEP.MeleeWeapon		= 0

-- GMod-style config (Primary/Secondary tables are pre-seeded by the loader)
SWEP.Primary	= { Automatic = true,  Delay = 0.05, Cone = 0.025, Shots = 75 }
SWEP.Secondary	= { Automatic = true, Delay = 0.05, Magnitude = 250, Radius = 100 }

function SWEP:Initialize()
	self.m_bReloadsSingly	= false
	self.m_bFiresUnderwater	= true
end

function SWEP:Precache() end

function SWEP:PrimaryAttack()
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

	self.m_flNextPrimaryAttack   = gpGlobals.curtime() + ( self.Primary.Delay or 0.1 )
	self.m_flNextSecondaryAttack = gpGlobals.curtime() + ( self.Primary.Delay or 0.1 )
	self.m_iClip1 = self.m_iClip1 - 1

	local c = self.Primary.Cone or 0
	local n = self.Primary.Shots or 1
	local info = {
		m_iShots = n,
		m_vecSrc = pPlayer:Weapon_ShootPosition(),
		m_vecDirShooting = pPlayer:GetAutoaimVector( 0.08715574274766 ),
		m_vecSpread = Vector( c, c, c ),
		m_flDistance = MAX_TRACE_LENGTH,
		m_iAmmoType = self.m_iPrimaryAmmoType,
		m_flDamage = self.damage,
	}
	info.m_iTracerFreq		= 5
	info.m_pAttacker		= pPlayer
	pPlayer:FireBullets( info )
	pPlayer:ViewPunch( QAngle( -1, 0, 0 ) )
end

function SWEP:SecondaryAttack()
	if _CLIENT then return end
	local pPlayer = self:GetOwner()
	if ToBaseEntity( pPlayer ) == NULL then return end

	self.m_flNextPrimaryAttack   = gpGlobals.curtime() + ( self.Secondary.Delay or 0.4 )
	self.m_flNextSecondaryAttack = gpGlobals.curtime() + ( self.Secondary.Delay or 0.4 )

	-- No trace (avoids the nil MASK/_E.MASK problem): put the explosion a bit in
	-- front of the player's eye along the aim direction.
	local vForward = Vector()
	pPlayer:EyeVectors( vForward, nil, nil )
	local vecEye = pPlayer:EyePosition()
	local hitpos = vecEye + vForward * 200

	local ent = CreateEntityByName( "env_explosion" )
	if ent then
		ent:SetAbsOrigin( hitpos )
		ent:SetOwnerEntity( pPlayer )
		-- Keep the damage radius small (iRadiusOverride caps iMagnitude*2.5 which
		-- would otherwise be huge: 250*2.5=625 units hits the whole map).  Set the
		-- fireball sprite so the explosion is visible.
		ent:KeyValue( "iMagnitude", tostring( self.Secondary.Magnitude or 250 ) )
		ent:KeyValue( "iRadiusOverride", tostring( self.Secondary.Radius or 100 ) )
		ent:KeyValue( "fireballsprite", "sprites/zerogxplode.vmt" )
		ent:Spawn()
		ent:Fire( "Explode", 0, 0 )
		ent:EmitSound( "weapon_AWP.Single" )
	end
end

function SWEP:Reload()
	return self:DefaultReload( self:GetMaxClip1(), self:GetMaxClip2(), 182 )
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
function SWEP:Think() end

-- GMod-compatible SWEP HUD hooks.  hl2sb's client Lua has a limited drawing API,
-- so these are stubs that prove the engine forwards the hook; draw with the
-- available surface bindings when they are wired up.  The weapon's NAME in the
-- selection menu is drawn by the C++ HUD via SWEP.PrintName (capitalized key).
function SWEP:DrawHUD()
	-- print("[pist] DrawHUD called")
end

function SWEP:DrawWeaponSelection( x, y, w, h, bSelected )
	-- print("[pist] DrawWeaponSelection", x, y, w, h, tostring(bSelected))
end

function SWEP:DrawAmmo()
	-- print("[pist] DrawAmmo called")
end
