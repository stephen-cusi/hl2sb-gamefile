--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Hook implementation.
--
--===========================================================================--

local pairs = pairs
local Warning = dbg.Warning
local tostring = tostring
local pcall = pcall
-- HL2SB: Lua 5.4 moved unpack() into the table library.  The engine installs the
-- 5.1 alias as well, but keep this defensive so hook.lua works on either runtime.
local unpack = unpack or table.unpack

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
function call( strEventName, tGamemode, ... )
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
--          Calls every hook registered under strEventName in order and returns
--          the first non-nil result, exactly like GMod's hook.Run(name, ...).
--          This is the entry point most GMod addons use to fire callbacks, so
--          ported scripts calling hook.Run("PlayerSpawn", ply) keep working.
-- Input  : strEventName - Name of the hook
-- Output : first non-nil result, else nil
-------------------------------------------------------------------------------
function Run( strEventName, ... )
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
  return nil
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
-- ===========================================================================
Add       = Add       or add
Remove    = Remove    or remove
GetTable  = GetTable  or gethooks

function Call( strEventName, tGamemode, ... )
  return call( strEventName, tGamemode, ... )
end
