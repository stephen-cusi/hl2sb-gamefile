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

-- HL2SB (2026-10-08): the Lua SetBodyGroups shim that used to live here is
-- gone.  GMod's Entity:SetBodyGroups is the engine's own C binding (hex, one
-- character per bodygroup) on both realms, and this fork's CBaseAnimating
-- binding now carries the same thing - the Lua copy only shadowed it with
-- decimal-only parsing.
------------------------------------------------------------------------------
-- HL2SB (2026-10-08): GMod extensions/entity.lua carries these two as plain
-- Lua over a per-entity script field (m_bUnFreezable).  The physgun freeze
-- chain (obj_player_extend.lua / base gamemode player.lua) reads them; GMod
-- ships no C binding for either name.
------------------------------------------------------------------------------

local meta = FindMetaTable( "Entity" )
if ( !meta ) then return end

include( "hl2sb/original/entity_helpers.lua" )

function meta:GetUnFreezable()
	return self.m_bUnFreezable or false
end

function meta:SetUnFreezable( bFreeze )
	self.m_bUnFreezable = tobool( bFreeze ) or false
end

--===========================================================================--
-- HL2SB (2026-10-15): GMod's Entity:DropToFloor() engine method.
--
-- This fork binds the same engine call only as util.DropToFloor( ent, mask
-- [, filter] ) (game/server/lua/lutil.cpp, UTIL_DropToFloor), so every GMod
-- file that calls the METHOD died with
--   attempt to call a nil value (method 'DropToFloor')
-- -- lua/entities/base_entity/init.lua's default SENT SpawnFunction (its last
-- line), and sandbox/gamemode/commands.lua's NPC / SENT floor drop.
--
-- Installed only where the util binding exists (server realm; the method is
-- server-only in GMod too), with the mask the engine's own "drop the NPC to
-- the floor" uses (MASK_NPCSOLID: game/server/ai_concommands.cpp npc_create
-- drops with exactly this mask).
--===========================================================================--
if ( meta.DropToFloor == nil and _G.util ~= nil and util.DropToFloor ~= nil ) then
	function meta:DropToFloor()
		return util.DropToFloor( self, MASK_NPCSOLID )
	end
end

--===========================================================================--
-- HL2SB (2026-10-16): Entity:GetPersistent() / Entity:SetPersistent( bool ).
--
-- The reference binds both as engine methods reading the entity's persistent
-- flag; this engine has no such flag.  The only consumer in the reference
-- gamemode tree is sandbox persistence.lua, which uses the tag to mark
-- entities between save and paste within one running session, so a plain
-- instance-table field answers the same contract.  The nil-guards here are
-- sound because the lookup is on the Entity meta itself (contrast the old
-- SendLua stub bug: that one checked the PLAYER meta for a binding that
-- lives on the ENTITY meta, so the guard always passed).
--
-- HL2SB (2026-10-16, second pass): the mark is MIRRORED into the NW store
-- (SetNWBool "hl2sb_persistent") because the C menu's persist/stop-persisting
-- Filter runs on the CLIENT, where the server's instance table does not
-- exist: with the plain field the client always answered false and showed
-- "Make Persistent" even for an already-persisted entity.  The field stays
-- the primary store (server-side iteration reads it without a network
-- round-trip); the NW flag only supplies the cross-realm truth.
--===========================================================================--
if ( meta.GetPersistent == nil ) then
	function meta:GetPersistent()
		if ( self.m_bPersistent == true ) then return true end
		return self:GetNWBool( "hl2sb_persistent" ) == true
	end
end

if ( meta.SetPersistent == nil ) then
	function meta:SetPersistent( bPersistent )
		self.m_bPersistent = tobool( bPersistent ) or false
		self:SetNWBool( "hl2sb_persistent", self.m_bPersistent )
	end
end
