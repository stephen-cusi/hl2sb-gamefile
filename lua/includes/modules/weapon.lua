--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Scripted weapon implementation.
--
--===========================================================================--

_BASE_WEAPON = "weapon_hl2mpbase_scriptedweapon"

-- module() below swaps this file's environment, which hides every global --
-- including the ones defined in the lines above and the standard library
-- (type/tostring).  Snapshot what the module body needs while globals are
-- still visible.
local BASE_WEAPON = _BASE_WEAPON
local table = table
local type = type
local tostring = tostring
local Warning = dbg.Warning
-- TableInherit (below) iterates and type-checks: without seeall these would
-- be nil inside the module environment and weapon.get() would raise
-- "attempt to call a nil value (global 'pairs')" for every SWEP with a Lua
-- base -- no weapon table, a model-less viewmodel, and a client crash in
-- ResetSequenceInfo on the next weapon switch (crash_20261007_073817).
local pairs = pairs
-- istable comes from the extensions pass, whose relative order vs. this
-- module is not guaranteed -- fall back to a local definition.
local istable = istable or function( t ) return type( t ) == "table" end

module( "weapon" )

local tWeapons = {}

-------------------------------------------------------------------------------
-- Purpose: Returns a weapon table
-- Input  : strName - Name of the weapon
-- Output : table
-------------------------------------------------------------------------------
-- GMod's weapons.lua derives with a DEEP local TableInherit (subtables are
-- merged field-by-field, e.g. a child SWEP that writes SWEP.Primary.Damage
-- still sees the base's SWEP.Primary.RecoilRandom / ClipSize / DefaultClip).
-- The global table.inherit is intentionally shallow (GMod semantics), so it
-- can't be used here: child Primary/Secondary tables always exist (the engine
-- seeds them), which would drop every base-only subtable field.  That is
-- exactly how hl1sweps' weapon_hl1_357 lost Primary.RecoilRandom and aborted
-- every shot inside SendRecoil.
local function TableInherit( t, base )

	for k, v in pairs( base ) do

		if ( t[ k ] == nil ) then
			t[ k ] = v
		elseif ( k ~= "BaseClass" and istable( t[ k ] ) and istable( v ) ) then
			TableInherit( t[ k ], v )
		end

	end

	t[ "BaseClass" ] = base

	return t

end

function get( strClassname )
  local tWeapon = tWeapons[ strClassname ]
  if ( not tWeapon ) then
    return nil
  end
  tWeapon = table.copy( tWeapon )
  -- HL2SB GMod SWEP compat: GMod SWEPs declare SWEP.Base. Honor that field for
  -- inheritance (falls back to the engine-forced __base when Base is missing or
  -- self-referential). This lets a GMod SWEP chain through the Lua weapon_base.
  local sBase = tWeapon.Base
  if ( type( sBase ) ~= "string" or sBase == "" or sBase == strClassname ) then
    sBase = tWeapon.__base
  end
  if ( sBase ~= strClassname ) then
    local tBaseWeapon = get( sBase )
    if ( not tBaseWeapon ) then
      -- The engine base weapon (weapon_hl2mpbase_scriptedweapon) is loaded
      -- alphabetically after weapon_base, and a Lua weapon whose only base is
      -- the engine's own scripted base legitimately has no Lua table to inherit
      -- from (the engine fills those fields itself).  Warning there is noise on
      -- every map load, so only warn about a genuinely broken Base chain.
      if ( sBase ~= BASE_WEAPON ) then
        Warning( "WARNING: Attempted to initialize weapon \"" .. strClassname .. "\" with non-existing base class \"" .. tostring( sBase ) .. "\"!\n" )
      end
    else
      return TableInherit( tWeapon, tBaseWeapon )
    end
  end
  return tWeapon
end

-------------------------------------------------------------------------------
-- Purpose: Returns all registered weapons
-- Input  :
-- Output : table
-------------------------------------------------------------------------------
function getweapons()
  return tWeapons
end

-------------------------------------------------------------------------------
-- Purpose: Registers a weapon
-- Input  : tWeapon - Weapon table
--          strClassname - Name of the weapon
--          bReload - Whether or not we're reloading this weapon data
-- Output :
-------------------------------------------------------------------------------
function register( tWeapon, strClassname, bReload )
  if ( get( strClassname ) ~= nil and bReload ~= true ) then
    return
  end
  tWeapons[ strClassname ] = tWeapon
end
