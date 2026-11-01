--[[----------------------------------------------------------------------------
    gmod_globals.lua

    GMod-style global helpers for HL2SB.

    The Team Sandbox Lua SDK exposes most things as *libraries* (gpGlobals.curtime,
    surface.GetScreenSize, global ConVar(...)), while GMod scripts call plain free
    functions (CurTime, ScrW, GetConVar, ...).  This file bridges just the ones
    that are pure Lua / already-backend and can be done without touching an
    entity binding, so stock GMod scripts load without "attempt to call global
    'CurTime' (a nil value)".

    Note: LocalPlayer() / IsValid() in their Entity form need a client entity
    binding and the entity-iteration set (ents.GetAll / player.GetAll), which are
    intentionally NOT defined here - they belong with the C++ entity work.

    Loaded every level from lua/includes/extensions/.
-----------------------------------------------------------------------------]]--

-- ===========================================================================
-- HL2SB GMod SWEP compat: activity / player-animation constants.  These must
-- exist before any weapon script loads (weapons are walked after includes/),
-- and GMod SWEPs use the ACT_VM_* / ACT_MP_* / PLAYER_* symbols directly.
-- Values come from Source's ai_activity.h / shareddefs.h Activity +
-- PLAYER_ANIM enums. Angle is registered by the native math library.
-- ===========================================================================

-- ===========================================================================
-- HL2SB: the ACT_* globals used to be hand-copied here from the Valve SDK
-- numbering (ACT_HL2MP_IDLE = 988 ...).  That was WRONG for this engine: models
-- resolve activities BY NAME at load (animation.cpp:151,
-- ActivityList_IndexForName) against THIS engine's list, whose values differ
-- (ACT_HL2MP_IDLE is 975 here, not 988).  The engine now publishes every
-- registered activity as a flat global with its own true value
-- (REGISTER_SHARED_ACTIVITY in activitylist.h, ~1975 entries incl. the zombie
-- swim/gesture families scp049 needs), so this block must NOT re-shadow them.
-- ===========================================================================

-- HL2SB: small GMod enum gaps the enum libs do not cover.  Values are this
-- engine's own (public/soundflags.h, shareddefs.h, public/const.h).
CHAN_VOICE		= CHAN_VOICE or 2
HITGROUP_HEAD		= HITGROUP_HEAD or 1
HITGROUP_CHEST		= HITGROUP_CHEST or 2
HITGROUP_STOMACH	= HITGROUP_STOMACH or 3
HITGROUP_LEFTARM	= HITGROUP_LEFTARM or 4
HITGROUP_RIGHTARM	= HITGROUP_RIGHTARM or 5
HITGROUP_LEFTLEG	= HITGROUP_LEFTLEG or 6
HITGROUP_RIGHTLEG	= HITGROUP_RIGHTLEG or 7
HITGROUP_GEAR		= HITGROUP_GEAR or 10
COLLISION_GROUP_IN_VEHICLE	= COLLISION_GROUP_IN_VEHICLE or 10
COLLISION_GROUP_DEBRIS		= COLLISION_GROUP_DEBRIS or 1

PLAYER_IDLE	= 0
PLAYER_WALK	= 1
PLAYER_JUMP	= 2
PLAYER_SUPERJUMP	= 3
PLAYER_DIE	= 4
PLAYER_ATTACK1	= 5
PLAYER_IN_VEHICLE	= 6
PLAYER_RELOAD	= 8
PLAYER_START_AIMING	= 9
PLAYER_LEAVE_AIMING	= 10

AddCSLuaFile = AddCSLuaFile or function( ... ) return true end

-- ===========================================================================
-- HL2SB (2026-10-08): base-gamemode globals used by the ported base files.
--
--   Format         - string.format alias (GMod extensions/string.lua spells
--                    it out with a format cache; a straight alias answers
--                    the same contract).
--   ents.FindInBox - the engine binding is spelled Entities.GetInBox here.
--
-- ===========================================================================
-- ===========================================================================
-- HL2SB: server-realm stand-ins for two client-only APIs that the ported GMod
-- libraries touch at LOAD time.
--
-- lua/includes/modules/*.lua are loaded on BOTH realms (the engine's directory
-- pass cannot know which files are client-only), and two of them fail on the
-- server at every map load:
--
--   halo.lua:7         local rt_Store = render.GetScreenEffectTexture( 0 )
--                      -> "attempt to index a nil value (global 'render')"
--   properties.lua:175 net.Receive( "properties", ... )
--                      -> "attempt to call a nil value (field 'Receive')"
--
-- Neither library can do anything useful on a server (one is screen-effect
-- rendering, the other is the client->server net channel), but the throw takes
-- the whole module down with it and writes a red line into ds_debug.log once per
-- load.  The stand-ins below let them load: on the server render.* hands back a
-- function that yields nil (so `render.Foo()` is nil rather than an error), and
-- net.Receive accepts a handler and drops it.
--
-- WARNING: this block MUST sit above the `if ( not _CLIENT )` section below: that
-- section ends with a bare `return`, so on the server the rest of this file
-- never runs.  It used to be at the end of the file, where it was dead code and
-- the two errors kept appearing every load (log lines properties.lua:175 and
-- halo.lua:7 at 01:25 on 2026-09-13, AFTER gmod_globals.lua had loaded).
-- ===========================================================================
if ( SERVER ) then

	if ( render == nil ) then
		render = setmetatable( {}, {
			__index = function()
				return function() return nil end
			end
		} )
	end

	if ( net ~= nil and net.Receive == nil ) then
		net.Receive = function() end
	end

end

if ( not _CLIENT ) then
	if ( _GAMEUI ) then
		GetConVar = GetConVar or function( name ) return ConVar( name ) end
		GetConVarNumber = GetConVarNumber or function( name )
			local c = ConVar( name )
			return c and c:GetFloat() or 0
		end
		GetConVarString = GetConVarString or function( name )
			local c = ConVar( name )
			return c and c:GetString() or ""
		end
	end

	return
end

-- ===========================================================================
-- Client side
-- ===========================================================================

-- HL2SB: GMod's ScreenScale family.  These are ENGINE globals in GMod (C++),
-- not util.lua helpers -- GMod's own lua/includes/util.lua (ours, byte for
-- byte) does not define them, and lua/includes/notification.lua needs them on
-- line 2:
--
--     local textH = math.max( 12, math.ceil( ScreenScaleH( 9 ) ) )
--
-- Without them that file fails to load completely, which shows up as exactly
-- one [Lua] FAILED line -- that is how the undo notification vanished.
--
-- In the game client, the original client globals provide ScreenScale and
-- ScreenScaleH. The menu state uses its own fallback.
if ( _GAMEUI ) then
	ScreenScale = ScreenScale or function( size ) return size * ( ScrW() / 640 ) end
	ScreenScaleH = ScreenScaleH or function( size ) return size * ( ScrH() / 480 ) end
end

ScreenScaleW = ScreenScaleW or function( size )
	return size * ( ScrW() / 640 )
end

if ( _GAMEUI ) then
	GetConVar = GetConVar or function( name ) return ConVar( name ) end
	GetConVarNumber = GetConVarNumber or function( name )
		local c = ConVar( name )
		return c and c:GetFloat() or 0
	end
	GetConVarString = GetConVarString or function( name )
		local c = ConVar( name )
		return c and c:GetString() or ""
	end
end

-- NOTE: the server-realm render/net.Receive stand-ins are NOT here.  This file
-- ends the server's pass with the bare `return` above (inside the
-- `if ( not _CLIENT )` block), so anything after that point never runs on the
-- server.  They live near the top of the file instead.

-- ===========================================================================
-- HL2SB: the `achievements` table (GMod global, client)
--
-- GMod ships the achievement callbacks in lua/includes/init.lua; this fork has
-- no achievement system at all.  The only definition anywhere was
-- lua/includes/modules/gmod_compatibility/sh_init.lua:1172, which is inert
-- behind GMOD_COMPATIBILITY = false -- so the global was nil, and
--
--   gamemodes/sandbox/gamemode/spawnmenu/spawnmenu.lua:109
--       achievements.SpawnMenuOpen()      -- last line of PANEL:Open()
--
-- threw every time the spawnmenu was opened.  PANEL:Open() has already run
-- MakePopup / SetVisible by then, so the menu still appeared -- but the error
-- propagated out through hook.Run("OnSpawnMenuOpen"), which means the
-- SpawnMenuOpened hook never ran (GMod's opening hints and the menubar parent
-- hand-off both live there) and ds_debug.log got one red line per press.
--
-- Shapes copied from sh_init.lua:1172 so nothing else can notice: no-ops, and
-- false/0/"" for the getters.
-- ===========================================================================
if ( achievements == nil ) then

	achievements = {
		BalloonPopped  = function() end,
		Count          = function() return 0 end,
		EatBall        = function() end,
		GetCount       = function() return 0 end,
		GetDesc        = function() return "" end,
		GetGoal        = function() return 0 end,
		GetName        = function() return "" end,
		IncBaddies     = function() end,
		IncBystander   = function() end,
		IncGoodies     = function() end,
		IsAchieved     = function() return false end,
		Remover        = function() end,
		SpawnedNPC     = function() end,
		SpawnedProp    = function() end,
		SpawnedRagdoll = function() end,
		SpawnMenuOpen  = function() end,
	}

end
if ( CLIENT and _G.gui ~= nil and _G.input ~= nil and input.GetCursorPos ~= nil ) then

	-- HL2SB (2026-10-20 mc_swep audit B5): GMod's clipboard writer is the bare
	-- global SetClipboardText( str ) (client realm); this fork's implementation
	-- lives under system.SetClipboardText (vgui ISystem), so publish the
	-- global spelling.  The minecraft swep's right-click "Copy to Clipboard"
	-- dies on a nil global without it.
	if ( _G.SetClipboardText == nil and _G.system ~= nil and _G.system.SetClipboardText ~= nil ) then
		function _G.SetClipboardText( strText )
			return _G.system.SetClipboardText( strText )
		end
	end

end

-- ===========================================================================
-- HL2SB (2026-10-05): the gm_save / gm_load layer's remaining GMod game.*
-- surface.  These live here and NOT in extensions/gmod_compat.lua because that
-- file is in no load path at all (no include, no folder pass) - everything it
-- defines is dead code; gmod_globals.lua is the one extensions file proven to
-- run in every realm (game.GetWorld above has been answering since before the
-- save system existed).
-- ===========================================================================

-- GMod: game.CleanUpMap( dontSendToClients, extraFilters, callback ).
-- The engine part is the HL2SB_GameCleanUpMap global (game/server/lua/lutil.cpp
-- -> CHL2MPRules::CleanUpMap(), which raises the "CleanUpMap" hook itself).
-- GMod raises GM:PreCleanupMap before and GM:PostCleanupMap after; gmsave's
-- whole load flow hangs on PostCleanupMap (clean the map, then paste the dupe
-- back), so the wrapper fires both around the engine call.
if ( _G.game ~= nil and game.CleanUpMap == nil ) then

	function game.CleanUpMap( dontSendToClients, extraFilters, callback )
		if ( hook ~= nil and hook.Run ~= nil ) then
			hook.Run( "PreCleanupMap" )
		end

		if ( HL2SB_GameCleanUpMap ~= nil ) then
			HL2SB_GameCleanUpMap()
		end

		if ( hook ~= nil and hook.Run ~= nil ) then
			hook.Run( "PostCleanupMap" )
		end

		if ( callback ~= nil ) then
			callback()
		end
	end

end

-- GMod: Player:IsAdmin().  This engine has no usergroup system (cod-c4's
-- shared.lua died on the missing method).  Minimum GMod-default semantics:
-- single player is always allowed (GMod exempts SP from the admin gate), and
-- in multiplayer nobody is an admin by default - same as GMod without a
-- users.txt.

-- GMod: player.GetHumans() - non-bot players (the save loader's "the one
-- human" fallback).

-- ===========================================================================
-- HL2SB GMod compat: DEFINE_BASECLASS( name )  (both realms)
--
-- The loader's GLua rewrite pass replaces the literal identifier
-- DEFINE_BASECLASS (calls AND definitions) with
-- `local BaseClass = baseclass.Get` before the file is parsed, so a plain
-- `function DEFINE_BASECLASS( name )` definition becomes `function local ...`
-- -- a syntax error that killed THIS WHOLE FILE on 2026-09-20, taking
-- Angle/CurTime/every global here down with it (util.lua then failed with
-- "attempt to call a nil value (global 'Angle')" and every SENT broke).
-- Assemble the name at runtime so the rewriter never sees the token.
-- The result is also mirrored onto the global BaseClass so the
-- BaseClass:Initialize( self ) pattern keeps resolving.
-- ===========================================================================
-- (2026-09-20 晚) 定义已移到引擎 C++ 侧（lsrcinit.cpp，编译期拼名）：
-- Lua 侧 rawset(_G,...) 在当前加载管线里写不进可见的全局表，
-- 探针实测 DEFINE_BASECLASS=nil。这里不再重复定义。

-- HL2SB GMod compat: Msg( ... ) -- GMod's console print (wiki: Global.Msg).
-- print() already reaches the console + hl2sb_lua.log on this engine, and some
-- GMod self-check scripts call Msg unconditionally.
if ( Msg == nil ) then
	function Msg( ... )
		print( ... )
	end
end

-- HL2SB GMod compat: MsgN / Warning / ErrorNoHalt (wiki: Global.MsgN etc.) --
-- the menu realm probes for these at startup ("MISSING MsgN, Warning, ...").
if ( MsgN == nil ) then
	function MsgN( ... )
		print( ... )
	end
end
if ( Warning == nil ) then
	function Warning( ... )
		print( ... )
	end
end
if ( ErrorNoHalt == nil ) then
	function ErrorNoHalt( ... )
		print( ... )
	end
end

-- HL2SB diagnostic: proves this file ran to the end (the 2026-09-20 syntax
-- error in the DEFINE_BASECLASS block silently killed every global here).
-- SERVER/CLIENT values added 2026-09-21: if the CLIENT state shows
-- SERVER=true, the realm stamping was overwritten after openlibs and every
-- `if ( SERVER ) then return end` guard in addon client halves (sent_ball's
-- ENT:Draw!) skipped, leaving entities to draw their raw shadow models.
print( "[HL2SB] gmod_globals loaded: DEFINE_BASECLASS=" .. type( rawget( _G, "DEFINE_BASE" .. "_CLASS" ) ) .. " Angle=" .. type( Angle ) .. " SERVER=" .. tostring( SERVER ) .. " CLIENT=" .. tostring( CLIENT ) )



-- HL2SB GMod compat (2026-09-24): meta-table chain for FindMetaTable reads.
-- Addons capture methods straight off the bare metatable (PLAYER.Alive,
-- ENTITY.OnGround) - a RAW table read that never triggers the userdata
-- __index chain.  GMod carries every method on each metatable itself; this
-- fork spreads them across Entity/Animating metas.  Give the derived
-- metatables a meta-level __index that falls back to the Entity metatable so
-- PLAYER.SomeEntityMethod resolves.  (Ents created from Lua keep working:
-- only misses fall through.)
if ( FindMetaTable ~= nil ) then
	local entmeta = FindMetaTable( "Entity" )
	if ( entmeta ~= nil ) then
		for _, mtname in ipairs( { "Player", "NPC", "Vehicle", "Weapon", "NextBot" } ) do
			local mt = FindMetaTable( mtname )
			if ( mt ~= nil and mt ~= entmeta and getmetatable( mt ) == nil ) then
				setmetatable( mt, { __index = entmeta } )
			end
		end

		-- HL2SB (2026-09-25): the reverse gap - bone/flex/pose methods live on
		-- the CBaseAnimating metatable in this fork, but addons capture them as
		-- ENTITY.GetBoneMatrix / ENTITY.DestroyShadow (First Person Body does:
		-- 3896 failed shadow-hook frames in one session).  Chain Entity ->
		-- CBaseAnimating at the meta level; CBaseAnimating has no meta of its
		-- own, so the lookup terminates there (no cycle).
		local animmeta = FindMetaTable( "CBaseAnimating" )
		if ( animmeta ~= nil and animmeta ~= entmeta and getmetatable( entmeta ) == nil ) then
			setmetatable( entmeta, { __index = animmeta } )
		end
	end
end

