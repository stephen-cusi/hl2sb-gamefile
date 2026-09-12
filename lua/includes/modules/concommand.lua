--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: ConCommand implementation.
--
--===========================================================================--

local ConCommand = ConCommand
local Warning = dbg.Warning
local tostring = tostring
local pcall = pcall

-- HL2SB: re-execution guard -- read this before touching anything below.
--
-- luasrc_dofolder() loads lua/includes/modules/*.lua as PLAIN FILES, so
-- package.loaded is never populated for them; any later require("concommand")
-- therefore finds no cached module and EXECUTES THIS FILE AGAIN.
--
-- That is not hypothetical -- the sandbox gamemode does it on every map load:
--
--     gamemodes/sandbox/gamemode/in_main.lua:7    require( "concommand" )
--     lua/includes/modules/undo.lua:41            require( "concommand" )
--     lua/gameui/basepanel.lua:11                 require( "concommand" )
--
-- and the load order makes the damage silent and total:
--
--   1. luasrc_LoadGamemode( "base" ) -> gamemodes/base/gamemode/cl_init.lua
--        -> include( "cl_spawnmenu.lua" )
--        -> concommand.Add( "+menu", ... )      registers into table A
--        -> and creates the real engine ConCommand "+menu"
--   2. luasrc_LoadGamemode( "sandbox" ) -> gamemodes/sandbox/gamemode/cl_init.lua
--        -> include( "in_main.lua" )  ->  require( "concommand" )
--        -> THIS FILE RUNS A SECOND TIME, `local tFnCommandCallbacks = {}` makes
--           table B, and _G.concommand/Dispatch/Add are rebound to B
--   3. the engine's "+menu" ConCommand still exists and still runs
--        CC_ConCommand -> concommand.Dispatch( L, "+menu", ... )
--      but Dispatch is B's, and B's table is EMPTY.  Dispatch returns false.
--      On the client that prints NOTHING (the "Unknown command" report at
--      luconvar.cpp:197 is #ifndef CLIENT_DLL), so pressing Q did nothing at all
--      -- three game launches' worth of "the menu does not come up".
--
-- hook.lua and undo.lua already carry this exact guard for the same reason.
-- Returning the existing module keeps Add and Dispatch pointing at ONE table.
--
-- `Create` is the marker: only the body below installs it.
if ( _G.concommand ~= nil and _G.concommand.Create ~= nil ) then
	return _G.concommand
end

module( "concommand" )

local bError, strError
local tFnCommandCallbacks = {}

-------------------------------------------------------------------------------
-- Purpose: Creates a ConCommand
-- Input  : pName - Name of the ConCommand
--          callback - Callback function for the ConCommand
--          pHelpString - Help string to be displayed
--          flags - Flags of the ConCommand
-- Output :
-------------------------------------------------------------------------------
function Create( pName, callback, pHelpString, flags )
  tFnCommandCallbacks[ pName ] = callback
  ConCommand( pName, pHelpString, flags )
end

-------------------------------------------------------------------------------
-- Purpose: Called by the game to dispatch a ConCommand
-- Input  : pPlayer - Player who ran the ConCommand
--          pCmd - Name of the ConCommand
--          ArgS - All args that occur after the 0th arg, in string form
-- Output : boolean
-------------------------------------------------------------------------------
function Dispatch( pPlayer, pCmd, ArgS )
  local fnCommandCallback = tFnCommandCallbacks[ pCmd ]
  if ( not fnCommandCallback ) then
    return false
  else
    bError, strError = pcall( fnCommandCallback, pPlayer, pCmd, ArgS )
    if ( bError == false ) then
      Warning( "ConCommand '" .. tostring( pCmd ) .. "' Failed: " .. tostring( strError ) .. "\n" )
    end
    return true
  end
end

-------------------------------------------------------------------------------
-- Purpose: Removes a ConCommand callback
-- Input  : pName - Name of the ConCommand
-- Output :
-------------------------------------------------------------------------------
function Remove( pName )
  if ( tFnCommandCallbacks[ pName ] ) then
    tFnCommandCallbacks[ pName ] = nil
  end
end

-------------------------------------------------------------------------------
-- Purpose: GMod 兼容别名。
--   GMod 的库是 concommand.Add( cmd, fn, canExecute, helpString, flags )
--   （Remove 同名同义）。HL2SB 的 Create 是
--   ( name, fn, helpString, flags )，回调签名一致，都是 fn( ply, cmd, args )。
--   canExecute 被接受但忽略：HL2SB 没有 per-command 的权限钩子。
--
--   必须定义在这个模块里：lua/includes/extensions/ 比 modules/ 先加载，
--   那时全局 concommand 还不存在，在 extensions 里加别名会被静默跳过。
-------------------------------------------------------------------------------
function Add( cmd, fn, canExecute, helpString, flags )
  return Create( cmd, fn, helpString, flags )
end
