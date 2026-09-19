-- Server-side entry for the weapon_base SWEP.
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "ai_translations.lua" )
AddCSLuaFile( "sh_anim.lua" )
AddCSLuaFile( "shared.lua" )

include( "ai_translations.lua" )
include( "sh_anim.lua" )
include( "shared.lua" )

-- HL2SB: the engine reads the flat lowercase keys (weight / autoswitchto /
-- autoswitchfrom) in InitScriptedWeapon, but prefers the GMod-cased fields
-- when they exist (Slot/Weight/AutoSwitchTo/AutoSwitchFrom).  Keep the flat
-- defaults for anything that does not override them.
SWEP.weight			= SWEP.weight or 5
SWEP.autoswitchto	= 1
SWEP.autoswitchfrom	= 1

SWEP.Weight			= 5		-- Decides whether we should switch from/to this
SWEP.AutoSwitchTo	= true	-- Auto switch to if we pick it up
SWEP.AutoSwitchFrom	= true	-- Auto switch from if you pick up a better weapon

-- NPC capability bits.  The values match this engine's
-- bits_CAP_WEAPON_RANGE_ATTACK1 family (basecombatcharacter.h); the AI's
-- CapabilitiesGet() consumer tests those exact bits.
if ( CAP_WEAPON_RANGE_ATTACK1 == nil ) then CAP_WEAPON_RANGE_ATTACK1 = 0x2000 end
if ( CAP_WEAPON_RANGE_ATTACK2 == nil ) then CAP_WEAPON_RANGE_ATTACK2 = 0x4000 end
if ( CAP_WEAPON_MELEE_ATTACK1 == nil ) then CAP_WEAPON_MELEE_ATTACK1 = 0x0800 end
if ( CAP_WEAPON_MELEE_ATTACK2 == nil ) then CAP_WEAPON_MELEE_ATTACK2 = 0x1000 end

--[[---------------------------------------------------------
	Name: OnRestore
	Desc: The game has just been reloaded. This is usually the right place
		to call the GetNW* functions to restore the script's values.
-----------------------------------------------------------]]
function SWEP:OnRestore()
end

--[[---------------------------------------------------------
	Name: AcceptInput
	Desc: Accepts input, return true to override/accept input
-----------------------------------------------------------]]
function SWEP:AcceptInput( name, activator, caller, data )
	return false
end

--[[---------------------------------------------------------
	Name: KeyValue
	Desc: Called when a keyvalue is added to us
-----------------------------------------------------------]]
function SWEP:KeyValue( key, value )
end

--[[---------------------------------------------------------
	Name: Equip
	Desc: A player or NPC has picked the weapon up
-----------------------------------------------------------]]
function SWEP:Equip( newOwner )
end

--[[---------------------------------------------------------
	Name: EquipAmmo
	Desc: The player has picked up the weapon and has taken the ammo from it
		The weapon will be removed immediately after this call.
-----------------------------------------------------------]]
function SWEP:EquipAmmo( newOwner )
end

--[[---------------------------------------------------------
	Name: OnDrop
	Desc: Weapon was dropped
-----------------------------------------------------------]]
function SWEP:OnDrop()
end

--[[---------------------------------------------------------
	Name: ShouldDropOnDie
	Desc: Should this weapon be dropped when its owner dies?
-----------------------------------------------------------]]
function SWEP:ShouldDropOnDie()
	return true
end

--[[---------------------------------------------------------
	Name: GetCapabilities
	Desc: For NPCs, returns what they should try to do with it.
-----------------------------------------------------------]]
function SWEP:GetCapabilities()

	return CAP_WEAPON_RANGE_ATTACK1

end

--[[---------------------------------------------------------
	Name: NPCShoot_Secondary
	Desc: NPC tried to fire secondary attack
-----------------------------------------------------------]]
function SWEP:NPCShoot_Secondary( shootPos, shootDir )

	self:SecondaryAttack()

end

--[[---------------------------------------------------------
	Name: NPCShoot_Primary
	Desc: NPC tried to fire primary attack
-----------------------------------------------------------]]
function SWEP:NPCShoot_Primary( shootPos, shootDir )

	self:PrimaryAttack()

end

-- These tell the NPC how to use the weapon
AccessorFunc( SWEP, "fNPCMinBurst",		"NPCMinBurst" )
AccessorFunc( SWEP, "fNPCMaxBurst",		"NPCMaxBurst" )
AccessorFunc( SWEP, "fNPCFireRate",		"NPCFireRate" )
AccessorFunc( SWEP, "fNPCMinRestTime",	"NPCMinRest" )
AccessorFunc( SWEP, "fNPCMaxRestTime",	"NPCMaxRest" )
