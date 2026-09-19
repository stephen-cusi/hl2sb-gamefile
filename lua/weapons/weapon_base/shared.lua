--[[--------------------------------------------------------------------
    weapon_base  --  GMod SWEP base for HL2SB, restructured to match
    Facepunch/garrysmod gamemodes/base/entities/weapons/weapon_base:

        shared.lua    (this file)   realm-neutral methods and defaults
        init.lua      server-only fields and NPC hooks
        cl_init.lua   client-only fields and HUD hooks
        sh_anim.lua   SetWeaponHoldType / TranslateActivity parity layer
        ai_translations.lua           NPC activity translations

    The loader runs init.lua on the server and cl_init.lua on the client;
    both include shared.lua (same as GMod's entity layout).

    HL2SB adaptations (engine-level, no shims):
      * SetHoldType(t) drives the engine's m_acttable (the engine translates
        player activities itself, CBaseCombatWeapon::ActivityOverride), so
        GMod's ActivityTranslate table is filled for scripts but the engine
        consumes m_acttable.
      * The engine applies SWEP.Primary/Secondary.Delay after each attack
        (CHL2MPScriptedWeapon::ItemPostFrame) unless the SWEP called
        SetNextPrimaryFire/SetNextSecondaryFire itself -- the GMod contract.
      * Clip1/Clip2/Ammo1/Ammo2/SetClip1/SetClip2/GetPrimaryAmmoType/
        GetSecondaryAmmoType refer to the engine bindings; the engine seeds
        both clips from Primary/Secondary DefaultClip on first ItemPostFrame.
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

-- ---------------------------------------------------------------------------
-- HoldType -> m_acttable.
--
-- GMod names a weapon's pose with SWEP.HoldType ("pistol", "camera", "fist",
-- ...) and then translates the player's generic activity into the
-- weapon-specific one.  We keep the GMod name and build that translation here.
--
-- The engine walks the rows IN ORDER and takes the first activity whose
-- sequence the player's model actually has
-- (CBaseCombatWeapon::ActivityOverride -> CStudioHdr::HaveSequenceForActivity),
-- so listing a fallback family after the weapon's own family gives a sensible
-- pose on a model that only ships the classic HL2MP anims instead of leaving
-- the player frozen in whatever sequence he was in.
--
-- The families come from GMod's anim models (models/m_anm.mdl, f_anm.mdl,
-- z_anm.mdl - pulled in by GMod playermodels with $includemodel).  Ten of them
-- are the classic HL2MP sets; the other eight (fist / melee2 / knife / camera /
-- magic / revolver / passive / duel) only exist there, and the engine now
-- publishes all of them (see the end of game/shared/ai_activity.h).
--
-- Slot order inside a family is GMod's own, from
-- gamemodes/base/entities/weapons/weapon_base/sh_anim.lua:
--   +0 IDLE  +1 WALK  +2 RUN  +3 IDLE_CROUCH  +4 WALK_CROUCH
--   +5 ATTACK  +6 RELOAD  +7 JUMP
-- ---------------------------------------------------------------------------

-- The eight slots of one hold type, in GMod's order.  A name the engine did not
-- publish comes back nil, and the row for that slot is then simply not emitted.
local function Family( suffix )
	local function slot( act )
		return _G[ "ACT_HL2MP_" .. act .. "_" .. suffix ]
	end
	return {
		slot( "IDLE" ), slot( "WALK" ), slot( "RUN" ),
		slot( "IDLE_CROUCH" ), slot( "WALK_CROUCH" ),
		slot( "GESTURE_RANGE_ATTACK" ), slot( "GESTURE_RELOAD" ),
		slot( "JUMP" ),
	}
end

local Families = {
	pistol		= Family( "PISTOL" ),
	revolver	= Family( "REVOLVER" ),
	smg1		= Family( "SMG1" ),
	ar2			= Family( "AR2" ),
	shotgun		= Family( "SHOTGUN" ),
	rpg			= Family( "RPG" ),
	crossbow	= Family( "CROSSBOW" ),
	grenade		= Family( "GRENADE" ),
	slam		= Family( "SLAM" ),
	melee		= Family( "MELEE" ),
	physgun		= Family( "PHYSGUN" ),
	melee2		= Family( "MELEE2" ),
	knife		= Family( "KNIFE" ),
	fist		= Family( "FIST" ),
	camera		= Family( "CAMERA" ),
	magic		= Family( "MAGIC" ),
	passive		= Family( "PASSIVE" ),
	duel		= Family( "DUEL" ),
}

-- The bare HL2MP set, i.e. the "no weapon-specific pose" answer.  There is no
-- bare ACT_HL2MP_JUMP in any anim model, so the jump slot borrows the SLAM jump
-- exactly the way GMod's own table does ("normal" jump animation doesn't exist).
Families.normal = {
	ACT_HL2MP_IDLE, ACT_HL2MP_WALK, ACT_HL2MP_RUN,
	ACT_HL2MP_IDLE_CROUCH, ACT_HL2MP_WALK_CROUCH,
	ACT_HL2MP_GESTURE_RANGE_ATTACK, ACT_HL2MP_GESTURE_RELOAD,
	ACT_HL2MP_JUMP_SLAM,
}

-- Which generic activity reads which family slot.
local BaseSlots = {
	{ ACT_HL2MP_IDLE,					1 },
	{ ACT_HL2MP_WALK,					2 },
	{ ACT_HL2MP_RUN,					3 },
	{ ACT_HL2MP_IDLE_CROUCH,			4 },
	{ ACT_HL2MP_WALK_CROUCH,			5 },
	{ ACT_HL2MP_GESTURE_RANGE_ATTACK,	6 },
	{ ACT_HL2MP_GESTURE_RELOAD,			7 },
	{ ACT_HL2MP_JUMP,					8 },
}

-- Rows for one hold type: every family in the argument list, in order, so the
-- first family that the player's model can satisfy wins.
local function HoldTypeRows( ... )
	local rows = {}
	for _, unit in ipairs( { ... } ) do
		for _, slot in ipairs( BaseSlots ) do
			local act = unit[ slot[ 2 ] ]
			if ( act ) then
				rows[ #rows + 1 ] = { slot[ 1 ], act, false }
			end
		end
	end
	return rows
end

local HoldTypeActtables = {
	-- No weapon-specific pose at all: the bare set, then the pistol pose for
	-- models that do not carry the bare activities (classic HL2MP anims).
	[ "normal" ]	= HoldTypeRows( Families.normal, Families.pistol ),

	-- Handguns.
	[ "pistol" ]	= HoldTypeRows( Families.pistol, Families.normal ),
	[ "revolver" ]	= HoldTypeRows( Families.revolver, Families.pistol ),
	[ "357" ]		= HoldTypeRows( Families.revolver, Families.pistol ),

	-- Long guns.
	[ "smg" ]		= HoldTypeRows( Families.smg1, Families.pistol ),
	[ "smg1" ]		= HoldTypeRows( Families.smg1, Families.pistol ),
	[ "mg" ]		= HoldTypeRows( Families.smg1, Families.pistol ),
	[ "ar2" ]		= HoldTypeRows( Families.ar2, Families.pistol ),
	[ "rifle" ]		= HoldTypeRows( Families.ar2, Families.pistol ),
	[ "shotgun" ]	= HoldTypeRows( Families.shotgun, Families.pistol ),
	[ "rpg" ]		= HoldTypeRows( Families.rpg, Families.pistol ),
	[ "crossbow" ]	= HoldTypeRows( Families.crossbow, Families.pistol ),

	-- Throwables.
	[ "grenade" ]	= HoldTypeRows( Families.grenade, Families.pistol ),
	[ "slam" ]		= HoldTypeRows( Families.slam, Families.pistol ),

	-- Melee.  GMod gives each of these its own pose; HL2MP only has the one
	-- melee set, which is the fallback.
	[ "melee" ]		= HoldTypeRows( Families.melee, Families.pistol ),
	[ "melee2" ]	= HoldTypeRows( Families.melee2, Families.melee ),
	[ "knife" ]		= HoldTypeRows( Families.knife, Families.melee ),
	[ "fist" ]		= HoldTypeRows( Families.fist, Families.melee ),
	[ "stunstick" ]	= HoldTypeRows( Families.melee, Families.pistol ),
	[ "crowbar" ]	= HoldTypeRows( Families.melee, Families.pistol ),

	-- Tools.
	[ "physgun" ]	= HoldTypeRows( Families.physgun, Families.pistol ),

	-- GMod hold types that only GMod's anim models carry.
	[ "camera" ]	= HoldTypeRows( Families.camera, Families.normal, Families.pistol ),
	[ "magic" ]		= HoldTypeRows( Families.magic, Families.normal, Families.pistol ),
	[ "passive" ]	= HoldTypeRows( Families.passive, Families.normal, Families.pistol ),
	[ "duel" ]		= HoldTypeRows( Families.duel, Families.pistol ),
}

-- The engine also asks for ACT_RANGE_ATTACK1 when the weapon fires
-- (CHL2MP_Player::SetAnimation -> Weapon_TranslateActivity( ACT_RANGE_ATTACK1 )),
-- so every variant gets that row too.  Missing constants are simply skipped.
local RangeAttackVariants = {
	[ "pistol" ]	= ACT_RANGE_ATTACK_PISTOL,
	[ "revolver" ]	= ACT_RANGE_ATTACK_PISTOL,
	[ "357" ]		= ACT_RANGE_ATTACK_PISTOL,
	[ "smg" ]		= ACT_RANGE_ATTACK_SMG1,
	[ "smg1" ]		= ACT_RANGE_ATTACK_SMG1,
	[ "mg" ]		= ACT_RANGE_ATTACK_SMG1,
	[ "ar2" ]		= ACT_RANGE_ATTACK_AR2,
	[ "rifle" ]		= ACT_RANGE_ATTACK_AR2,
	[ "shotgun" ]	= ACT_RANGE_ATTACK_SHOTGUN,
	[ "rpg" ]		= ACT_RANGE_ATTACK_RPG,
	[ "crossbow" ]	= ACT_RANGE_ATTACK_CROSSBOW,
	[ "grenade" ]	= ACT_RANGE_ATTACK_GRENADE,
	[ "slam" ]		= ACT_RANGE_ATTACK_SLAM,
	[ "melee" ]		= ACT_RANGE_ATTACK_MELEE,
	[ "melee2" ]	= ACT_RANGE_ATTACK_MELEE,
	[ "knife" ]		= ACT_RANGE_ATTACK_MELEE,
	[ "fist" ]		= ACT_RANGE_ATTACK_MELEE,
	[ "stunstick" ]	= ACT_RANGE_ATTACK_MELEE,
	[ "crowbar" ]	= ACT_RANGE_ATTACK_MELEE,
	[ "physgun" ]	= ACT_RANGE_ATTACK_PHYSGUN,
}

for holdType, rangeAct in pairs( RangeAttackVariants ) do
	local rows = HoldTypeActtables[ holdType ]
	if ( rows and rangeAct ) then
		rows[ #rows + 1 ] = { ACT_RANGE_ATTACK1, rangeAct, false }
	end
end

--[[---------------------------------------------------------
	Name: SWEP:SetHoldType
	Desc: GMod sets a hold type string; HL2SB animates via m_acttable.
		  We keep the GMod API and translate to the activity table.
		  (GMod's SetWeaponHoldType entry point lives in sh_anim.lua and
		  routes here.)
-----------------------------------------------------------]]
function SWEP:SetHoldType( t )
	-- GMod hold types are matched case-insensitively ("Pistol" == "pistol").
	t = string.lower( t or "normal" )
	self.HoldType = t
	self.m_acttable = HoldTypeActtables[ t ] or HoldTypeActtables[ "normal" ]
	return self.HoldType
end

--[[---------------------------------------------------------
	Name: SWEP:Initialize
-----------------------------------------------------------]]
function SWEP:Initialize()
	-- GMod applies SWEP.HoldType automatically; this engine's hold type is
	-- consumed through SetHoldType, so honour the field here.
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

-- ===========================================================================
-- HL2SB: initial NetworkVar seed for the predicted client realm.
--
-- GMod replicates NetworkVars; this engine's Lua NW storage does not.  The
-- server realm seeds SetupDataTables values (gmod_camera: SetZoom( 70 )), but
-- the client realm's storage started empty, so GetZoom() answered 0 and the
-- first zoom ran from FOV 0.1 instead of 70.  One seed at creation is enough:
-- afterwards both realms integrate the same prediction deltas, and
-- Reload/Equip resync by themselves.
--
--      client, after SetupDataTables:  hl2sb_nwrequest <entindex>
--      server: reads the weapon's __hl2sb_nw_* fields, replies
--              hl2sb_nwseed <entindex> <name>=<value> ...
--      client: writes them back onto the weapon's table (the NW storage).
-- The engine records the declared names as __hl2sb_nw_names right after
-- SetupDataTables (CHL2MPScriptedWeapon::InitScriptedWeapon) and fires the
-- request; the handlers here are the two ends of it.
-- ===========================================================================
if ( SERVER ) then
	concommand.Add( "hl2sb_nwrequest", function( ply, _, args )

		if ( not IsValid( ply ) or args == nil or args[ 1 ] == nil ) then return end
		if ( ents == nil or ents.GetByIndex == nil ) then return end

		local ent = ents.GetByIndex( tonumber( args[ 1 ] ) or 0 )
		if ( ent == nil or ent.__hl2sb_nw_names == nil ) then
			print( "[HL2SB] nwseed: request for ent " .. tostring( args[ 1 ] ) .. " but no names table" )
			return
		end
		print( "[HL2SB] nwseed: request for ent " .. tostring( args[ 1 ] ) )

		local parts = { args[ 1 ] }
		for _, name in ipairs( ent.__hl2sb_nw_names ) do
			local ok, value = pcall( function() return ent[ "__hl2sb_nw_" .. name ] end )
			if ( ok and value ~= nil ) then
				parts[ #parts + 1 ] = name .. "=" .. tostring( value )
			end
		end

		if ( #parts > 1 ) then
			print( "[HL2SB] nwseed: replying -> " .. table.concat( parts, " " ) )
			ply:ConCommand( "hl2sb_nwseed " .. table.concat( parts, " " ) )
		else
			print( "[HL2SB] nwseed: nothing to send for ent " .. tostring( args[ 1 ] ) )
		end

	end )
end

if ( CLIENT ) then
	concommand.Add( "hl2sb_nwseed", function( _, _, args )

		if ( args == nil or args[ 1 ] == nil ) then return end
		if ( ents == nil or ents.GetByIndex == nil ) then return end

		local ent = ents.GetByIndex( tonumber( args[ 1 ] ) or 0 )
		if ( ent == nil ) then
			print( "[HL2SB] nwseed: seed for ent " .. tostring( args[ 1 ] ) .. " but no local entity" )
			return
		end
		print( "[HL2SB] nwseed: applying seed for ent " .. tostring( args[ 1 ] ) )

		for i = 2, #args do
			local name, value = string.match( args[ i ], "^([%w_]+)=(.*)$" )
			if ( name ~= nil and value ~= nil ) then
				local num = tonumber( value )
				ent[ "__hl2sb_nw_" .. name ] = ( num ~= nil ) and num or value
			end
		end

	end )
end
