--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: ConCommand implementation.
--
--===========================================================================--

local ConCommand = ConCommand
local Warning = dbg.Warning
local tostring = tostring
local pcall = pcall

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
