--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: ConCommand implementation.
--
--===========================================================================--

local ConCommand = ConCommand
local Warning = dbg.Warning
local tostring = tostring
local pcall = pcall
local string = string
local type = type

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
--      lconvar.cpp:197 is #ifndef CLIENT_DLL), so pressing Q did nothing at all
--      -- three game launches' worth of "the menu does not come up".
--
-- hook.lua and undo.lua already carry this exact guard for the same reason.
-- Returning the existing module keeps Add and Dispatch pointing at ONE table.
--
-- `Create` is the marker: only the body below installs it.
if ( _G.concommand ~= nil and _G.concommand.Create ~= nil ) then
	return _G.concommand
end

-- NOTE: no package.seeall here, so every global this file uses has to be
-- captured above -- `module()` swaps the chunk's _ENV for the bare module table
-- and `type`/`string`/`tostring` would otherwise be nil.
module( "concommand" )

local bError, strError

-- HL2SB: GMod's concommand library keys BOTH of its tables by the LOWERCASED
-- command name (its Add / Remove / Run / AutoComplete all go through
-- string.lower), so "Undo" and "undo" are one command.  HL2SB used to key by the
-- exact string, which let a GMod script and the engine disagree about a command
-- that only differs in case -- and the engine hands us the name AS TYPED.  Both
-- tables are therefore lowercased on write and on read; callbacks still receive
-- the name the caller/engine used.
local tFnCommandCallbacks = {}    -- [lower name] = function( ply, cmd, args, argStr )
local tFnCompleteCallbacks = {}   -- [lower name] = autoCompleteFunction

-------------------------------------------------------------------------------
-- Purpose: Creates a ConCommand
-- Input  : pName - Name of the ConCommand
--          callback - Callback function for the ConCommand
--          pHelpString - Help string to be displayed
--          flags - Flags of the ConCommand
--          completeFunc - Optional GMod auto-completion callback
-- Output :
--
-- HL2SB: `flags` is accepted for source compatibility and then ignored by the
-- engine, which is not a bug here -- luasrc_ConCommand (public/lua/tier1/
-- lconvar.cpp:242-260) pops the third argument and hardcodes the flags
-- (FCVAR_CLIENTDLL|FCVAR_CLIENTCMD_CAN_EXECUTE|FCVAR_SERVER_CAN_EXECUTE on the
-- client, FCVAR_GAMEDLL|FCVAR_CLIENTCMD_CAN_EXECUTE on the server).  The
-- luaL_optint(L, 3, 0) forms are inside `#if 0`.  So passing a FLAGS TABLE --
-- which lua/includes/modules/undo.lua and cleanup.lua both do -- is harmless:
-- the table is never read.
-------------------------------------------------------------------------------
function Create( pName, callback, pHelpString, flags, completeFunc )
  local strKey = string.lower( pName )

  tFnCommandCallbacks[ strKey ] = callback
  tFnCompleteCallbacks[ strKey ] = completeFunc

  ConCommand( pName, pHelpString, flags )
end

-------------------------------------------------------------------------------
-- Purpose: Called by the game to dispatch a ConCommand (LEGACY HL2SB ENTRY)
-- Input  : pPlayer - Player who ran the ConCommand
--          pCmd - Name of the ConCommand
--          ArgS - All args that occur after the 0th arg, in string form
-- Output : boolean
--
-- The engine prefers Run() now (that is the GMod entry point, and it gets a real
-- arguments table); Dispatch stays because in-tree Lua calls it directly --
-- GetConVar/RunConsoleCommand in lua/includes/extensions/gmod_globals.lua:351
-- is the caller that matters -- and because a build whose engine is older than
-- this file must keep working.  Its callback shape is the original HL2SB one:
-- fn( ply, cmd, argString ).
-------------------------------------------------------------------------------
function Dispatch( pPlayer, pCmd, ArgS )
  local fnCommandCallback = tFnCommandCallbacks[ string.lower( pCmd ) ]
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
-- Purpose: Runs a ConCommand's Lua callback (GMod's engine entry point)
-- Input  : pPlayer - Player to run the command on
--          pCmd - Name of the command
--          pArguments - table of the arguments AFTER the command
--          pArgString - the raw argument string
-- Output : boolean - true if the command exists (GMod contract); the engine
--          prints "Unknown command" for false, so Run itself stays quiet.
--
-- GMod: concommand.Run( player, command, arguments, argumentsStr ) ->
--     CommandList[ lower ]( player, command, arguments, argumentsStr )
-- Note it passes the command name AS TYPED, not lowercased.
-------------------------------------------------------------------------------
function Run( pPlayer, pCmd, pArguments, pArgString )
  local fnCommandCallback = tFnCommandCallbacks[ string.lower( pCmd ) ]
  if ( not fnCommandCallback ) then
    return false
  end

  bError, strError = pcall( fnCommandCallback, pPlayer, pCmd, pArguments, pArgString )
  if ( bError == false ) then
    Warning( "ConCommand '" .. tostring( pCmd ) .. "' Failed: " .. tostring( strError ) .. "\n" )
  end

  return true
end

-------------------------------------------------------------------------------
-- Purpose: Autocompletion for a ConCommand (GMod's engine entry point)
-- Input  : pCmd - Name of the command
--          pArgString - the raw argument string
--          pArguments - table of the arguments AFTER the command
-- Output : table (whatever the auto-complete callback returned), or nil
--
-- GMod: concommand.AutoComplete( command, argumentsStr, arguments ) ->
--     CompleteList[ lower ]( command, argumentsStr, arguments )
--
-- NOTE: this engine's console has its own (Lua-free) completion, so nothing
-- calls AutoComplete yet -- it exists for scripts that call it directly and so
-- that registering one through Add() is no longer silently dropped.
-------------------------------------------------------------------------------
function AutoComplete( pCmd, pArgString, pArguments )
  local fnComplete = tFnCompleteCallbacks[ string.lower( pCmd ) ]
  if ( fnComplete == nil ) then
    return nil
  end

  return fnComplete( pCmd, pArgString, pArguments )
end

-------------------------------------------------------------------------------
-- Purpose: Returns the tables of console commands and auto-complete functions
-- Output : CommandList, CompleteList   (GMod's shape -- lowercased keys)
-------------------------------------------------------------------------------
function GetTable()
  return tFnCommandCallbacks, tFnCompleteCallbacks
end

-------------------------------------------------------------------------------
-- Purpose: Removes a ConCommand callback
-- Input  : pName - Name of the ConCommand
-- Output :
-------------------------------------------------------------------------------
function Remove( pName )
  local strKey = string.lower( pName )

  tFnCommandCallbacks[ strKey ] = nil
  tFnCompleteCallbacks[ strKey ] = nil
end

-------------------------------------------------------------------------------
-- Purpose: GMod 兼容别名。
--   GMod 的库是 concommand.Add( cmd, fn, autoCompleteFunction, helpString, flags )
--   （Remove 同名同义）。HL2SB 的 Create 是
--   ( name, fn, helpString, flags )，回调签名一致，都是 fn( ply, cmd, args, argStr )
--   —— 走 Run 这条引擎通道时 args 是表；老引擎通道（Dispatch）给的是原始字符串。
--   第三个参数曾经被当成 "canExecute" 收下再丢掉（HL2SB 没有 per-command 权限
--   钩子），于是 GMod 脚本注册的自动补全函数静默消失；现在它就是 GMod 的
--   autoCompleteFunction，交给 AutoComplete 用。
--
--   必须定义在这个模块里：lua/includes/extensions/ 比 modules/ 先加载，
--   那时全局 concommand 还不存在，在 extensions 里加别名会被静默跳过。
-------------------------------------------------------------------------------
function Add( cmd, fn, autoCompleteFunction, helpString, flags )
  if ( type( fn ) ~= "function" ) then
    Warning( "concommand.Add - bad argument #2 (function expected, got " .. type( fn ) .. ")\n" )
    return
  end

  return Create( cmd, fn, helpString, flags, autoCompleteFunction )
end
