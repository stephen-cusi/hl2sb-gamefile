--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Hook implementation.
--
--===========================================================================--

local pairs = pairs
local Warning = dbg.Warning
local tostring = tostring
local pcall = pcall
-- HL2SB: hook.lua opens with a BARE module( "hook" ) -- no package.seeall -- so
-- after line 31 the chunk's environment is the hook table with NO __index
-- fallback to _G.  Every global this file needs must therefore be captured HERE
-- (which is exactly why pairs/Warning/tostring/pcall are localised the same way).
--
-- GlobalTable is for globals that do not exist yet at load time: GAMEMODE and
-- _GAMEMODE are published by the ENGINE in luasrc_SetGamemode(), long after this
-- file is read, so Run() below has to look them up through the real global table
-- at call time.
local GlobalTable = _G
local unpack = unpack or table.unpack
-- HL2SB: Lua 5.4 moved unpack() into the table library.  The engine installs the
-- 5.1 alias as well, but keep this defensive so hook.lua works on either runtime.
local unpack = unpack or table.unpack

-- HL2SB: re-execution guard -- read this before touching anything below.
--
-- luasrc_dofolder() loads each file in lua/includes/modules as a PLAIN FILE, so
-- package.loaded is never populated for them.  A later require("hook") from
-- any script therefore finds no cached module and EXECUTES THIS FILE AGAIN.
--
-- Without the guard the second run reaches `local tHooks = {}` and rebinds
-- add/Run/call to that brand-new empty table, orphaning every hook registered
-- by the first run (timer.lua's client tick, timer.lua's Think, ...).
--
-- `hook.add` existing is the marker: only the body below installs it, so this
-- cannot fire on the first run.
if ( _G.hook ~= nil and _G.hook.add ~= nil ) then
	return _G.hook
end

module( "hook" )

local tHooks = {}
local tReturns = {}

-------------------------------------------------------------------------------
-- Purpose: Adds a hook to the given GameRules function
-- Input  : strEventName - Name of the internal GameRules method
--     	    strHookName - Name of the hook
--          pFn - pointer to function
-- Output :
-------------------------------------------------------------------------------
function add( strEventName, strHookName, pFn )
  tHooks[ strEventName ] = tHooks[ strEventName ] or {}
  tHooks[ strEventName ][ strHookName ] = pFn
end

-------------------------------------------------------------------------------
-- Purpose: Called by the engine to call a GameRules hook
-- Input  : strEventName - Name of the internal GameRules method
--          tGamemode - Table of the current gamemode
-- Output :
-------------------------------------------------------------------------------
-- HL2SB: the body below used to BE `call`.  It is a separate local function
-- only so that call() can wrap it in the same-event re-entrancy guard -- read
-- the comment on tCallChain before changing anything here.
local function CallBody( strEventName, tGamemode, ... )
  local tHooks = tHooks[ strEventName ]
  if ( tHooks ~= nil ) then
    for k, v in pairs( tHooks ) do
      if ( v == nil ) then
        Warning( "Hook '" .. tostring( k ) .. "' (" .. tostring( strEventName ) .. ") tried to call a nil function!\n" )
        tHooks[ k ] = nil
        break
      else
        tReturns = { pcall( v, ... ) }
        if ( tReturns[ 1 ] == false ) then
          Warning( "Hook '" .. tostring( k ) .. "' (" .. tostring( strEventName ) .. ") Failed: " .. tostring( tReturns[ 2 ] ) .. "\n" )
          tHooks[ k ] = nil
        elseif ( tReturns[ 2 ] ~= nil ) then
          return unpack( tReturns, 2 )
        end
      end
    end
  end
  if ( tGamemode ~= nil ) then
    local fn = tGamemode[ strEventName ]
    if ( fn == nil ) then
      return nil
    else
      tReturns = { pcall( fn, tGamemode, ... ) }
      if ( tReturns[ 1 ] == false ) then
        Warning( "ERROR: GAMEMODE: '" .. tostring( strEventName ) .. "' Failed: " .. tostring( tReturns[ 2 ] ) .. "\n" )
        tGamemode[ strEventName ] = nil
        return nil
      end
      return unpack( tReturns, 2 )
    end
  end
end

-------------------------------------------------------------------------------
-- HL2SB: re-entrancy guard -- read this before touching call() or CallBody().
--
-- A hook or a gamemode method may call hook.call() / hook.Run() for its OWN
-- event, and then the gamemode fallback above calls straight back into it:
--
--     hook.call(E) -> _GAMEMODE[E] -> hook.call(E) -> _GAMEMODE[E] -> ...
--
-- That recurses until the Lua stack blows up.  Measured on 2026-09-11: 11060
-- "hook.lua:78: stack overflow" lines in one session, which floods the log and
-- freezes the game solid (the main thread never gets back to pumping window
-- messages, so Windows reports "not responding").  It is easy to trigger by
-- accident because every engine -> Lua event goes through here, and this fork's
-- table.inherit() is a shallow COPY (lua/includes/extensions/table.lua), so a
-- gamemode table can end up holding a function that dispatches the same event
-- straight back.
--
-- Re-entering for the same event can never produce anything the first pass did
-- not already ask for: the registered hooks were consulted before the gamemode
-- fallback, and the fallback is the last thing CallBody does.  So refuse it.
-- Refusing once per event (instead of recursing) also keeps the culprit's name
-- in the log exactly once -- that is the line to search for.
-------------------------------------------------------------------------------
local tCallChain = {}
local tReportedReentry = {}

function call( strEventName, tGamemode, ... )
  if ( tCallChain[ strEventName ] ) then
    if ( not tReportedReentry[ strEventName ] ) then
      tReportedReentry[ strEventName ] = true
      Warning( "HL2SB: '" .. tostring( strEventName ) .. "' re-entered hook.call for the SAME event -- " ..
               "recursion refused.  Something that handles this event (a registered hook or the gamemode " ..
               "method) calls hook.call/hook.Run for it again; that used to blow the Lua stack and freeze " ..
               "the game.  Reported once per event.\n" )
    end
    return nil
  end

  -- pcall, not a bare call: if CallBody ever threw, the flag would stay set and
  -- that event would be refused for the rest of the level.  This also names the
  -- event in the error report, which the raw error path could not.
  tCallChain[ strEventName ] = true
  local tRet = { pcall( CallBody, strEventName, tGamemode, ... ) }
  tCallChain[ strEventName ] = nil

  if ( tRet[ 1 ] == false ) then
    Warning( "ERROR: HOOK: '" .. tostring( strEventName ) .. "' Failed: " .. tostring( tRet[ 2 ] ) .. "\n" )
    return nil
  end

  return unpack( tRet, 2 )
end

-------------------------------------------------------------------------------
-- Purpose: Returns all of the registered hooks or only hooks pertaining to a
--          specific event
-- Input  : strEventName - Name of the internal GameRules method
-- Output : table
-------------------------------------------------------------------------------
function gethooks( strEventName )
  if ( strEventName ) then
    return tHooks[ strEventName ]
  end
  return tHooks
end

-------------------------------------------------------------------------------
-- Purpose: Removes a hook from the list of registered hooks
-- Input  : strEventName - Name of the internal GameRules method
--          strHookName - Name of the hook
-- Output :
-------------------------------------------------------------------------------
function remove( strEventName, strHookName )
  if ( tHooks[ strEventName ][ strHookName ] ) then
    tHooks[ strEventName ][ strHookName ] = nil
  end
end

-------------------------------------------------------------------------------
-- Purpose: Run the given hook (GMod-compatible hook.Run).
--
-- HL2SB fix (2026-09-13): this used to run ONLY the registered hooks and never
-- the gamemode method, which is NOT what GMod does.  GMod's contract is
--
--     hook.Run( name, ... )  ==  hook.Call( name, GAMEMODE, ... )
--
-- and GMod's own code depends on that.  The whole spawnmenu open path is proof:
--
--   gamemodes/base/gamemode/cl_spawnmenu.lua:10
--       concommand.Add( "+menu", function() hook.Run( "OnSpawnMenuOpen" ) end )
--   gamemodes/sandbox/gamemode/spawnmenu/spawnmenu.lua:241
--       function GM:OnSpawnMenuOpen() ... end      <-- the ONLY implementation
--
-- With the old body that call reached no implementation at all, so +menu (and
-- every other gamemode callback GMod invokes this way: SpawnMenuEnabled,
-- AddGamemodeToolMenuTabs, AddToolMenuTabs, AddGamemodeToolMenuCategories,
-- AddToolMenuCategories, PopulateToolMenu, PreReloadToolsMenu,
-- PostReloadToolsMenu, SpawnMenuCreated, SpawnMenuOpened, SpawnMenuClosed,
-- OnSpawnMenuClose) silently did nothing: no error, no log line, no menu.
--
-- hook.Call already runs the registered hooks first and falls back to the
-- gamemode method, which is exactly GMod's order, so delegate instead of
-- duplicating the loop.
-- Input  : strEventName - Name of the hook
-- Output : first non-nil result, else nil
-------------------------------------------------------------------------------
function Run( strEventName, ... )
  -- GlobalTable, not _G: see the capture next to `local pcall` at the top --
  -- this module has NO package.seeall, so a bare _G here is nil and reading
  -- _G.GAMEMODE threw "attempt to index a nil value (global '_G')".
  return call( strEventName, GlobalTable.GAMEMODE or GlobalTable._GAMEMODE, ... )
end

-- ===========================================================================
-- GMod 大小写别名
--   GMod 的 hook 库是 hook.Add / hook.Remove / hook.Call / hook.GetTable。
--   HL2SB 原本只有小写的 add / remove / call（外加 Run）。GMod 自己的文件
--   （lua/includes/modules/undo.lua、gamemodes/*/cl_hudpickup.lua、
--   gmod_camera 等）全用大写形式，缺了就直接
--   "attempt to call a nil value (field 'Add')"。
--   Call 与 Run 的区别：GMod 的 Call 第一个参数是 gamemode 表，这里只需要
--   把它透传给 call()（同 add 的回调签名）。
--
--   ⚠️ 这里**绝不能**写成 `Add = Add or add`。本文件可能被 require 二次执行
--   （见文件顶部的守卫），那时 `Add` 字段已存在 —— 于是它会保留**第一次执行**
--   的那个函数，而那个函数闭包指向的 tHooks 早已被丢弃。结果就是：
--   hook.Add(...) 把钩子写进死表，hook.Run 在活表里查 —— 静默什么都不发生。
--   2026-09-11 的双表错位就是这么来的：hook.add 生效、hook.Add 全部失效，
--   拾取 HUD 怎么都不显示（`hook.GetTable("HUDDrawPickupHistory")` 为 nil，
--   而同一个文件里 hook.add 注册的 HudViewportPaint 在表里）。
--   remove/GetTable 同理，必须无条件指向本库自己的函数。
-- ===========================================================================
Add       = add
Remove    = remove
GetTable  = gethooks

function Call( strEventName, tGamemode, ... )
  return call( strEventName, tGamemode, ... )
end
