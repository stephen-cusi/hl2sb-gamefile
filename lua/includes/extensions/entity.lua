--========== Copyleft © 2013, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Extends the entity type.
--
--===========================================================================--

local type = type

function ToBaseEntity( pEntity )
  -- HL2SB: the engine stamps entity userdata with __type "entity" -- lower case
  -- (lbaseentity_shared.cpp:1974, lbaseplayer_shared.cpp:1152,
  -- lbasecombatweapon_shared.cpp:1137 all use "entity") -- while this check
  -- asked for "Entity".  So it returned NULL for EVERY entity in the game, and
  -- every caller that guards with it misbehaved:
  --
  --   ToBaseEntity( x ) == NULL  -> always true  -> the guarded code bailed out
  --     (weapon_base:ItemPostFrame stopped driving shots, so pist_weagon could
  --      deploy but never fire, and the physlauncher never launched)
  --   ToBaseEntity( x ) ~= NULL  -> always false -> the guarded block never ran
  --     (WeaponSound() emitted from the weapon instead of the player, which is
  --      the "sustained fire loses the sound" symptom)
  --
  -- Accept both spellings.
  local t = type( pEntity )
  if ( not pEntity or ( t ~= "Entity" and t ~= "entity" ) ) then
    return NULL;
  end

  local success, hEntity = pcall( _R.CBaseEntity.GetBaseEntity, pEntity )
  if ( not success ) then
    hEntity = NULL
  end
if _DEBUG then
  assert( hEntity ~= NULL );
end

  return hEntity;
end
