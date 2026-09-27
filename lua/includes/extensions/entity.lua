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

--===========================================================================--
-- HL2SB: GMod's NextBot:PlaySequenceAndWait( name, speed ) -- "to be called in
-- the behaviour coroutine only".  scp049's CreateZombie plays its "pickup"
-- sequence through it; without it the zombie-spawn path aborted with
-- "attempt to call a nil value (method 'PlaySequenceAndWait')".
-- This fork has no separate NextBot metatable (nextbot methods live on the
-- entity chain), so the method goes on the Entity metatable.  The wait rides
-- the behaviour coroutine (coroutine.wait) while the bot's BodyUpdate advances
-- the cycle; the timeout only guards a bot whose BodyUpdate never runs.
--===========================================================================--
if ( _R ~= nil and _R.CBaseEntity ~= nil and _R.CBaseEntity.PlaySequenceAndWait == nil ) then
  function _R.CBaseEntity:PlaySequenceAndWait( name, speed )
    local seq = self:LookupSequence( name or "" )
    if ( seq == nil or seq < 0 ) then return end

    self:ResetSequence( seq )
    self:SetCycle( 0 )
    self:SetPlaybackRate( speed or 1 )

    local duration = 1
    local ok, dur = pcall( self.SequenceDuration, self, seq )
    if ( ok and dur and dur > 0 ) then duration = dur end

    local t0 = CurTime()
    while ( self:GetCycle() < 1 and CurTime() - t0 < duration + 1 ) do
      coroutine.wait( 0 )
    end
  end
end

-- HL2SB (2026-09-27): GMod's Entity:SetBodyGroups( "0010000" ) -- one digit
-- per body group, left to right.  The engine only exposes the per-group
-- SetBodygroup( index, value ) on both realms, so parse the string onto those
-- calls (GM:PlayerSetHandsModel feeds it the hands bodygroups).
if ( _R ~= nil and _R.CBaseEntity ~= nil and _R.CBaseEntity.SetBodyGroups == nil ) then
  function _R.CBaseEntity:SetBodyGroups( str )
    if ( self.GetNumBodyGroups == nil ) then return end
    local numGroups = self:GetNumBodyGroups() or 0
    str = tostring( str or "" )
    for i = 1, #str do
      if ( i > numGroups ) then break end
      local n = tonumber( str:sub( i, i ) )
      if ( n ~= nil ) then
        self:SetBodygroup( i - 1, n )
      end
    end
  end
end
