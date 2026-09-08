SWEP.printname				= "BaseWeapon"
SWEP.viewmodel				= "models/weapons/v_pist_weagon.mdl"
SWEP.playermodel			= "models/weapons/w_pist_weagon.mdl"
SWEP.anim_prefix			= "python"
SWEP.bucket					= 1
SWEP.bucket_position		= 1

SWEP.clip_size				= 999
SWEP.clip2_size				= -1
SWEP.default_clip			= 999
SWEP.default_clip2			= -1
SWEP.primary_ammo			= "Pistol"
SWEP.secondary_ammo			= "None"

SWEP.weight					= 7
SWEP.item_flags				= 0

SWEP.damage					= 20

SWEP.SoundData				=
{
	empty					= "Weapon_Pistol.Empty",
	single_shot				= "weapons/automag/deagle-1.wav"
}

SWEP.showusagehint			= 0
SWEP.autoswitchto			= 1
SWEP.autoswitchfrom			= 1
SWEP.BuiltRightHanded		= 0
SWEP.AllowFlipping			= 1
SWEP.MeleeWeapon			= 0

function SWEP:Initialize()
	self.m_bReloadsSingly	= false;
	self.m_bFiresUnderwater	= true;
end

function SWEP:Precache()
end

function SWEP:PrimaryAttack()

	IPredictionSystem:SuppressHostEvents(NULL);

	if not _CLIENT then

	local pPlayer = self:GetOwner();

	--print(pPlayer);

	--print(type(pPlayer));

	if ( ToBaseEntity( pPlayer ) == NULL ) then
		return;
	end

	--print(pPlayer);

	if ( self.m_iClip1 <= 0 ) then
		if ( not self.m_bFireOnEmpty ) then
			self:Reload();
		else
			self:WeaponSound( 0 );
			self.m_flNextPrimaryAttack = 0.15;
		end

		return;
	end

	self:WeaponSound( 1 );
	pPlayer:DoMuzzleFlash();

	self:SendWeaponAnim( 180 );
	pPlayer:SetAnimation( 5 );
	ToHL2MPPlayer(pPlayer):DoAnimationEvent( 0 );

	self.m_flNextPrimaryAttack = gpGlobals.curtime() + 0.02;
	self.m_flNextSecondaryAttack = gpGlobals.curtime() + 0.1;

	self.m_iClip1 = self.m_iClip1 - 1;

	local vecSrc		= pPlayer:Weapon_ShootPosition();
	local vecAiming		= pPlayer:GetAutoaimVector( 0.08715574274766 );

	local info = { m_iShots = 7, m_vecSrc = vecSrc, m_vecDirShooting = vecAiming, m_vecSpread = vec3_origin, m_flDistance = MAX_TRACE_LENGTH, m_iAmmoType = self.m_iPrimaryAmmoType };
	local info = { m_iShots = 10, m_vecSrc = vecSrc, m_vecDirShooting = vecAiming, m_vecSpread = Vector( 0.17365, 0.17365, 0.17365 ), m_flDistance = MAX_TRACE_LENGTH, m_iAmmoType = self.m_iPrimaryAmmoType };
	
	info.m_pAttacker = pPlayer;

	--print(info);

	pPlayer:FireBullets( info );

	if ( self.m_iClip1 == 0 and pPlayer:GetAmmoCount( self.m_iPrimaryAmmoType ) <= 0 ) then
		-- HEV suit - indicate out of ammo condition
		--pPlayer:SetSuitUpdate( "!HEV_AMO0", 0, 0 );
	end

	end
end

function SWEP:SecondaryAttack()

	IPredictionSystem:SuppressHostEvents(NULL);

	if not _CLIENT then

	local pPlayer = self:GetOwner();
	if ( ToBaseEntity( pPlayer ) == NULL ) then
		return;
	end

	local vForward 		= Vector()
	local vRight 		= Vector()
	local vUp  			= Vector()
	local vecEye 		= pPlayer:EyePosition();
	local angle  		= QAngle(0, 0, 0);
	pPlayer:EyeVectors( vForward, vRight, vUp );

	tr = trace_t()
	MASK_SHOT = _E.MASK.SHOT
	--util.TraceLine( vecEye, vecEye + vForward * 56755, MASK_SHOT, this, 0, tr );
	util.TraceLine( vecEye + vForward * 50, vecEye + vForward * 56755, MASK_SHOT, this, 0, tr );

	self:WeaponSound( 1 );
	pPlayer:DoMuzzleFlash();

	self:SendWeaponAnim( 180 );
	pPlayer:SetAnimation( 5 );
	ToHL2MPPlayer(pPlayer):DoAnimationEvent( 0 );

	--Need a predictable explosion
	--effect.ExplosionCreate( tr.endpos, angle, pPlayer, 40, 40, true )
	effect.ExplosionCreate( tr.endpos, angle, pPlayer, 50, 200, true )

	end
end

function SWEP:Reload()
end

function SWEP:Think()
end

function SWEP:CanHolster()
end

function SWEP:Deploy()
end

function SWEP:GetDrawActivity()
	return 171;
end

function SWEP:Holster( pSwitchingTo )
end

function SWEP:ItemPostFrame()
end

function SWEP:ItemBusyFrame()
end

function SWEP:DoImpactEffect()
end

