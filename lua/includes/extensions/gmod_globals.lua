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
-- HL2SB GMod SWEP compat: activity / player-animation constants + Angle
-- constructor.  These must exist before any weapon script loads (weapons are
-- walked after includes/), and GMod SWEPs use the ACT_VM_* / ACT_MP_* / PLAYER_*
-- symbols directly.  Values come from Source's ai_activity.h / shareddefs.h
-- Activity + PLAYER_ANIM enums.
-- ===========================================================================
Angle = Angle or QAngle

-- ===========================================================================
-- Sound( path )  (GMod global, both realms)
--
-- GMod's Sound() returns a sound object that EmitSound/PlaySound accept.  HL2SB
-- has no such global and its EmitSound takes the PATH STRING directly, so a
-- stock GMod SWEP doing `self:EmitSound( Sound( self.Primary.Sound ) )` died on
-- "attempt to call a nil value (global 'Sound')" -- a red error in the console
-- that also skipped everything after it in that function (pist_weagon's
-- SetNextPrimaryFire, so its fire rate was never armed).
--
-- Returning the path is exactly what AGENTS.md 9.6 tells hand-ported scripts to
-- do by hand; providing the global means the pristine addon works unmodified.
-- ===========================================================================
if ( Sound == nil ) then
	function Sound( path )
		return path
	end
end

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

-- HL2SB GMod SWEP compat: stock SWEPs call Sound("...") (identity in GMod's
-- C binding) and AddCSLuaFile (HL2SB ships all Lua to both sides already).
Sound = Sound or function( s ) return s end
AddCSLuaFile = AddCSLuaFile or function( ... ) return true end

-- GMod: Model("path") precaches the model on the server and returns the path
-- (identity on the client).  gmod_camera and many workshop SWEPs wrap their
-- ViewModel/WorldModel in Model(...), which used to die with
-- "attempt to call global 'Model' (a nil value)".
Model = Model or function( s )
	if ( not _CLIENT and util and util.PrecacheModel ) then
		util.PrecacheModel( s )
	end
	return s
end

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
-- ⚠️ This block MUST sit above the `if ( not _CLIENT )` section below: that
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
	-- Server side has no surface / skin; still bridge time + convar.
	gpGlobals = gpGlobals or _G.gpGlobals
	CurTime  = CurTime  or function() return gpGlobals.curtime() end
	RealTime = RealTime or function() return gpGlobals.realtime() end

	CreateConVar = CreateConVar or function( name, def, flags, help, min, max )
		-- HL2SB: GMod passes FLAGS AS A TABLE, and the engine ConVar takes a
		-- number plus a DIFFERENT positional layout:
		--     GMod    ( name, default, flags, helptext, min, max )
		--     engine  ( name, default, flags, help, bMin, fMin, bMax, fMax )
		-- Passing GMod's min/max straight through put them in boolean slots, and
		-- a flags table produced
		--     gmod_globals.lua:115: bad argument #3 to 'ConVar' (number expected, got table)
		-- which is exactly what killed modules/constraint.lua (52 KB).
		local iFlags = flags
		if ( type( flags ) == "table" ) then
			iFlags = 0
			for _, flag in ipairs( flags ) do
				iFlags = bit.bor( iFlags, flag )
			end
		end

		return ConVar( name, def, iFlags or 0, help, min ~= nil, min or 0, max ~= nil, max or 0 )
	end

	GetConVar = GetConVar or function( name )
		return ConVar( name )
	end

	GetConVarNumber = GetConVarNumber or function( name )
		local c = ConVar( name )
		return c and c:GetFloat() or 0
	end

	GetConVarString = GetConVarString or function( name )
		local c = ConVar( name )
		return c and c:GetString() or ""
	end

	GetConVarBool = GetConVarBool or function( name )
		local c = ConVar( name )
		return c and c:GetBool() or false
	end

	-- GMod: ConVarExists( name ) -> boolean.
	--
	-- ⚠️ cod_c4 gates the creation of every one of its convars on it:
	--     addons/cod_c4/lua/entities/cod-c4/shared.lua:19  if !ConVarExists( ... ) then CreateConVar(...)
	--     addons/cod_c4/lua/entities/cod-c4/shared.lua:46  if !ConVarExists( "C4_RedLight" ) then ...
	-- As a nil global BOTH realms failed to load that file entirely
	-- ("[Lua] FAILED ... shared.lua:19: attempt to call a nil value (global 'ConVarExists')",
	-- ds_debug.log:18941): the six C4_* convars were never created, the
	-- net.Receive( "C4_Convars_Change" ) handler was never registered and the client never
	-- built its convar-change callbacks or the tool-menu panel.
	ConVarExists = ConVarExists or function( name )
		return ConVar( name ) ~= nil
	end

	return
end

-- ===========================================================================
-- Client side
-- ===========================================================================

local gpGlobals = gpGlobals

-- Time
CurTime  = CurTime  or function() return gpGlobals.curtime() end
RealTime = RealTime or function() return gpGlobals.realtime() end
FrameTime = FrameTime or function() return gpGlobals.frametime() end

-- Screen size
ScrW = ScrW or function()
	local w = surface.GetScreenSize()
	return w or 0
end
ScrH = ScrH or function()
	local _, h = surface.GetScreenSize()
	return h or 0
end

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
-- GMod semantics: ScreenScale and ScreenScaleH scale by height against the
-- 480-unit baseline, ScreenScaleW scales by width against 640.
ScreenScale = ScreenScale or function( size )
	return size * ( ScrH() / 480 )
end

ScreenScaleH = ScreenScaleH or function( size )
	return size * ( ScrH() / 480 )
end

ScreenScaleW = ScreenScaleW or function( size )
	return size * ( ScrW() / 640 )
end

-- ConVar access (see above for the shape)
CreateConVar = CreateConVar or function( name, def, flags, help, min, max )
		-- HL2SB: GMod passes FLAGS AS A TABLE, and the engine ConVar takes a
		-- number plus a DIFFERENT positional layout:
		--     GMod    ( name, default, flags, helptext, min, max )
		--     engine  ( name, default, flags, help, bMin, fMin, bMax, fMax )
		-- Passing GMod's min/max straight through put them in boolean slots, and
		-- a flags table produced
		--     gmod_globals.lua:115: bad argument #3 to 'ConVar' (number expected, got table)
		-- which is exactly what killed modules/constraint.lua (52 KB).
		local iFlags = flags
		if ( type( flags ) == "table" ) then
			iFlags = 0
			for _, flag in ipairs( flags ) do
				iFlags = bit.bor( iFlags, flag )
			end
		end

		return ConVar( name, def, iFlags or 0, help, min ~= nil, min or 0, max ~= nil, max or 0 )
	end

GetConVar = GetConVar or function( name )
	return ConVar( name )
end

GetConVarNumber = GetConVarNumber or function( name )
	local c = ConVar( name )
	return c and c:GetFloat() or 0
end

GetConVarString = GetConVarString or function( name )
	local c = ConVar( name )
	return c and c:GetString() or ""
end

GetConVarBool = GetConVarBool or function( name )
	local c = ConVar( name )
	return c and c:GetBool() or false
end

-- GMod: ConVarExists( name ) -> boolean.  Client half - see the server-side note above:
-- cod_c4 checks it before CreateClientConVar (entities/cod-c4/shared.lua:46), so without it
-- the client half of that file failed to load too (ds_debug.log:19736).
ConVarExists = ConVarExists or function( name )
	return ConVar( name ) ~= nil
end

-- ===========================================================================
-- HL2SB: GMod's SysTime() and RealFrameTime()
--
-- lua/includes/notification.lua uses SysTime() for every notice lifetime --
-- Panel.StartTime = SysTime() (line 83), the timeleft/velocity maths that drives
-- the whole slide-in animation, and KillSelf's StartTime + Length test -- and
-- RealFrameTime() for the friction term and the spring step.
--
-- Neither existed in this fork, so the GMod undo notice died at
--
--     notification.lua:83: attempt to call a nil value (global 'SysTime')
--
-- RealTime() and FrameTime() (defined above, on gpGlobals) are the same
-- quantities here.
--
-- HL2SB: the SysTime alias that used to live here is GONE -- the ENGINE provides
-- SysTime() now (luaopen_UTIL_shared, Plat_FloatTime, both realms).  Do not put
-- it back:
--
--     SysTime = SysTime or RealTime        -- RealTime is CLIENT only
--
-- evaluated to nil on the SERVER, so the server had no clock at all, which
-- silently disabled the undo de-duplication in lua/includes/modules/undo.lua and
-- let the twice-dispatched "undo" run twice -- deleting entities the first pass
-- had already removed and crashing in server.dll (execute access violation).
--
-- (lua/includes/modules/gmod_compatibility/sh_init.lua:260 also assigns
-- "SysTime = Engines.GetSystemTime"; that file is not loaded -- we only include
-- its sh_enumerations.lua -- but do not start including it, or it would shadow
-- the engine global.)
-- ===========================================================================
RealFrameTime = RealFrameTime or FrameTime

-- ===========================================================================
-- RunConsoleCommand( cmd, ... )   (GMod global, both realms)
--
-- This fork has no binding for it at all: there is no engine Lua function for
-- "execute this console command line" (no ClientCmd / ServerCommand exposure),
-- and lua/includes/modules/concommand.lua only offers Dispatch() for commands
-- registered *in Lua*.  GMod Lua calls RunConsoleCommand constantly -- the
-- player model panel is one of them:
--
--     RunConsoleCommand( "cl_playermodel", entry.name )
--
-- Two paths cover what GMod scripts actually do:
--   1. a Lua concommand (concommand.Create / concommand.Add) -> run it, so its
--      callback gets GMod's ( ply, cmd, args, argStr ) signature;
--   2. anything else (an engine ConVar, which is what cl_playermodel is) ->
--      set the ConVar, which is what typing it in the console does for a plain
--      cvar anyway.
--
-- HL2SB: path 1 goes through concommand.Run with a real arguments TABLE, the way
-- the engine does it now (public/lua/tier1/lconvar.cpp pushes arguments[1..n] +
-- the raw tail).  It used to call Dispatch with just the raw string, so a GMod
-- command reached through RunConsoleCommand saw a string in the arguments slot
-- and arguments[1] was nil -- the same defect the engine path had.  Dispatch is
-- kept as the fallback for a lua/includes/ tree that predates Run.
--
-- TODO(engine): bind the real thing once an engine command executor is
-- exposed; this cannot run commands that are neither a cvar nor a Lua
-- concommand ("say", "noclip", ...).
-- ===========================================================================
if ( RunConsoleCommand == nil ) then
	function RunConsoleCommand( cmd, ... )
		local strCmd = tostring( cmd )
		local name, inlineArgs = string.match( strCmd, "^(%S+)%s*(.*)$" )

		if ( name == nil ) then return end

		local strArgs = inlineArgs or ""

		for i = 1, select( "#", ... ) do
			local arg = select( i, ... )
			strArgs = ( strArgs == "" ) and tostring( arg ) or ( strArgs .. " " .. tostring( arg ) )
		end

		if ( concommand ~= nil ) then
			local tArguments = {}

			if ( concommand.Run ~= nil ) then
				for strArg in string.gmatch( strArgs, "%S+" ) do
					tArguments[ #tArguments + 1 ] = strArg
				end

				if ( concommand.Run( nil, name, tArguments, strArgs ) ) then
					return
				end
			elseif ( concommand.Dispatch ~= nil and concommand.Dispatch( nil, name, strArgs ) ) then
				return
			end
		end

		local cv = ( GetConVar_Internal ~= nil ) and GetConVar_Internal( name ) or nil

		if ( cv ~= nil and cv.SetString ~= nil and strArgs ~= "" ) then
			cv:SetString( strArgs )
			return
		end

		-- Engine console command ("jpeg", "noclip", "retry", ...): neither a
		-- Lua concommand nor a ConVar, so hand the whole line to the engine.
		-- gmod_camera fires "jpeg" on every snapshot without this.
		if ( HL2SB_EngineCommand ~= nil ) then
			HL2SB_EngineCommand( ( strArgs ~= "" ) and ( name .. " " .. strArgs ) or name )
		end
	end
end

-- NOTE: the server-realm render/net.Receive stand-ins are NOT here.  This file
-- ends the server's pass with the bare `return` above (inside the
-- `if ( not _CLIENT )` block), so anything after that point never runs on the
-- server.  They live near the top of the file instead.

-- ===========================================================================
-- HL2SB: input.IsKeyTrapping()  (GMod global on the input library)
--
-- gamemodes/base/gamemode/cl_spawnmenu.lua:15 is
--
--     concommand.Add( "-menu", function()
--         if ( input.IsKeyTrapping() ) then return end
--         hook.Run( "OnSpawnMenuClose" )
--     end, ... )
--
-- (and lua/vgui/dbinder.lua:81 calls it too).  This fork's vgui IInput has no
-- IsKeyTrapping at all (public/vgui/IInput.h has no such virtual -- GMod added
-- it to its fork of vgui2), so it cannot be bound; the only definition anywhere
-- was lua/includes/modules/gmod_compatibility/sh_init.lua:1298, which is inert
-- behind GMOD_COMPATIBILITY = false.
--
-- GMod's semantics: true while the console or a text entry is trapping the
-- keyboard.  input.GetFocus() IS bound (public/lua/vgui/LIInput.cpp:312) and
-- returns the panel holding keyboard focus, which is the same signal, so test
-- the focused panel's class.  It only needs to be conservative: returning true
-- keeps a text entry from being closed under the user's fingers.
--
-- HL2SB (2026-09-17): the engine binding for input.IsKeyTrapping now exists too
-- (public/lua/vgui/LIInput.cpp, added for lua/vgui/DBinder.lua), and it reports the
-- input.StartKeyTrapping() trap mode.  GMod's function is the UNION of the two, so
-- both are consulted below - the binding alone would let the "-menu" concommand
-- close the spawn menu while a text entry is being typed into.
-- ===========================================================================
if ( input ~= nil ) then

	local EngineIsKeyTrapping = input.IsKeyTrapping

	function input.IsKeyTrapping()

		if ( EngineIsKeyTrapping ~= nil and EngineIsKeyTrapping() ) then return true end

		if ( input.GetFocus == nil ) then return false end

		local pnl = input.GetFocus()
		if ( not IsValid( pnl ) ) then return false end

		if ( pnl.GetClassName == nil ) then return false end

		local class = pnl:GetClassName()

		return class == "TextEntry" or class == "EditablePanel"

	end

end
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
-- ===========================================================================
-- HL2SB: gui.MouseX / gui.MouseY  and  game.GetWorld()   (2026-09-13)
--
-- Both came out of tools/globals_audit.py, which diffs every bare global call
-- and every library.Member( in the spawnmenu path against what this fork binds.
-- Both are on the Derma surface the spawnmenu builds with.
--
-- gui.MouseX / gui.MouseY
--   lua/vgui/dframe.lua uses them for window dragging (11 + 17 sites, e.g.
--   :139,:140,:212) and lua/includes/extensions/client/panel/dragdrop.lua:216,262
--   and selections.lua:79 use them for spawn-icon drag & drop.  This fork's `gui`
--   library binds only IsGameUIVisible / ScreenToVector / ... -- no MouseX/MouseY.
--   input.GetCursorPos() (public/lua/vgui/LIInput.cpp, bound in round 2) is the
--   same cursor the engine's ISurface reads, so these are exact.
--
-- game.GetWorld()
--   gamemodes/sandbox/gamemode/spawnmenu/toolpanel.lua:148 builds its CanTool
--   argument with it while the tool tabs are populated:
--       local fakeTrace = { Entity = game.GetWorld(), Hit = false }
--   so without it UpdateToolDisabledStatus throws and the whole tool panel fails
--   to build.  lua/includes/modules/constraint.lua and duplicator.lua use it too.
--   Implemented through ents.FindByClass (extensions/gmod_compat.lua:384, which
--   wraps the working gEntList.FindEntityByClassname) rather than guessing at a
--   world accessor: it returns the real worldspawn entity, or nil if the entity
--   list cannot answer.
-- ===========================================================================
if ( CLIENT and _G.gui ~= nil and _G.input ~= nil and input.GetCursorPos ~= nil ) then

	if ( gui.MouseX == nil ) then
		function gui.MouseX()
			local x = input.GetCursorPos()
			return x or 0
		end
	end

	if ( gui.MouseY == nil ) then
		function gui.MouseY()
			local _, y = input.GetCursorPos()
			return y or 0
		end
	end

end

if ( _G.game ~= nil and game.GetWorld == nil and _G.ents ~= nil and ents.FindByClass ~= nil ) then

	function game.GetWorld()
		local found = ents.FindByClass( "worldspawn" )
		if ( found ~= nil ) then
			return found[ 1 ]
		end
		return nil
	end

end

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
rawset( _G, "DEFINE_BASE" .. "_CLASS", function( name )
	BaseClass = baseclass.Get( name )
	return BaseClass
end )

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
print( "[HL2SB] gmod_globals loaded: DEFINE_BASECLASS=" .. type( DEFINE_BASECLASS ) .. " Angle=" .. type( Angle ) )
