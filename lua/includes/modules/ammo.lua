--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Ammo type definitions.
--
--===========================================================================--

local type = type
local pairs = pairs
local table = table
local Warning = dbg.Warning

module( "ammo" )

-------------------------------------------------------------------------------
-- Damage type bits (mirrors DMG_* in game/shared/shareddefs.h).
-- HL2SB does not expose the engine enums to Lua, so they live here.
-------------------------------------------------------------------------------
DMG_GENERIC     = 0
DMG_CRUSH       = 1
DMG_BULLET      = 2
DMG_SLASH       = 4
DMG_BURN        = 8
DMG_VEHICLE     = 16
DMG_FALL        = 32
DMG_BLAST       = 64
DMG_CLUB        = 128
DMG_SHOCK       = 256
DMG_SONIC       = 512
DMG_ENERGYBEAM  = 1024
DMG_NEVERGIB    = 4096
DMG_ALWAYSGIB   = 8192
DMG_DROWN       = 16384
DMG_POISON      = 131072
DMG_ACID        = 1048576
DMG_SLOWBURN    = 2097152
DMG_PHYSGUN     = 8388608
DMG_PLASMA      = 16777216
DMG_AIRBOAT     = 33554432
DMG_DISSOLVE    = 67108864
DMG_BUCKSHOT    = 536870912

-------------------------------------------------------------------------------
-- Tracer styles (mirrors AmmoTracer_t in game/shared/ammodef.h).
-------------------------------------------------------------------------------
TRACER_NONE          = 0
TRACER_LINE          = 1
TRACER_RAIL          = 2
TRACER_BEAM          = 3
TRACER_LINE_AND_WHIZ = 4

local tAmmoTypes = {}
local tAmmoLookup = {}

-------------------------------------------------------------------------------
-- Purpose: Returns an ammo type table
-- Input  : strName - Name of the ammo type
-- Output : table
-------------------------------------------------------------------------------
function get( strName )
  return tAmmoLookup[ strName ]
end

-------------------------------------------------------------------------------
-- Purpose: Returns all registered ammo types
-- Input  :
-- Output : table
-------------------------------------------------------------------------------
function getammotypes()
  return tAmmoTypes
end

-------------------------------------------------------------------------------
-- Purpose: Registers or overrides an ammo type
-- Input  : tAmmo - Ammo table
--            name      (string, required) ammo type name, e.g. "Pistol"
--            dmgtype   (number) damage type bits, see ammo.DMG_*
--            tracer    (number) tracer style, see ammo.TRACER_*
--            plydmg    (number) player damage
--            npcdmg    (number) NPC damage
--            maxcarry  (number) max amount a player may carry
--            force     (number) physics force impulse
--            minsplash (number) minimum splash size
--            maxsplash (number) maximum splash size
--
--          Fields left out keep the value the engine already has. A name the
--          engine does not know becomes a new ammo type.
-- Output : table - the stored table
-------------------------------------------------------------------------------
function register( tAmmo )
  if ( type( tAmmo ) ~= "table" ) then
    Warning( "WARNING: ammo.register expects a table!\n" )
    return nil
  end

  if ( type( tAmmo.name ) ~= "string" ) then
    Warning( "WARNING: ammo.register requires a string 'name'!\n" )
    return nil
  end

  local tStored = tAmmoLookup[ tAmmo.name ]

  if ( tStored ~= nil ) then
    -- Merge into the existing definition so a later file can tweak one field.
    for k, v in pairs( tAmmo ) do
      tStored[ k ] = v
    end
    return tStored
  end

  tAmmoLookup[ tAmmo.name ] = tAmmo
  table.insert( tAmmoTypes, tAmmo )

  return tAmmo
end

-------------------------------------------------------------------------------
-- Purpose: Removes an ammo type from the Lua-side definition list
-- Input  : strName - Name of the ammo type
-- Output : boolean
-------------------------------------------------------------------------------
function remove( strName )
  local tStored = tAmmoLookup[ strName ]

  if ( tStored == nil ) then
    return false
  end

  tAmmoLookup[ strName ] = nil

  for i = #tAmmoTypes, 1, -1 do
    if ( tAmmoTypes[ i ] == tStored ) then
      table.remove( tAmmoTypes, i )
    end
  end

  return true
end
