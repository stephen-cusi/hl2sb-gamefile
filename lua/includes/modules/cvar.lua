--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Implements global change callbacks for ConVars.
--
--===========================================================================--

local pairs = pairs
local Warning = dbg.Warning
local tostring = tostring
local pcall = pcall
local GlobalTable = _G   -- capture before module() swaps _ENV

module( "cvar" )

local bError, strError
local tCallbacks = {}

-------------------------------------------------------------------------------
-- Purpose: Adds a change callback
-- Input  : strConVarName - Name of the ConVar
--          strCallbackName - Name of the callback
--          pFn - pointer to function
-- Output :
-------------------------------------------------------------------------------
function AddChangeCallback( strConVarName, strCallbackName, pFn )
  tCallbacks[ strConVarName ] = tCallbacks[ strConVarName ] or {}
  tCallbacks[ strConVarName ][ strCallbackName ] = pFn
end

-------------------------------------------------------------------------------
-- Purpose: Called by the game to call global change callbacks
-- Input  : var - ConVar that has changed
--          pOldString - String value before var changed
--          flOldValue - Float value before var changed
-- Output :
-------------------------------------------------------------------------------
function CallGlobalChangeCallbacks( var, pOldString, flOldValue )
  local strName = var:GetName()

  local tCallbacks = tCallbacks[ strName ]
  if ( tCallbacks ~= nil ) then
    for k, v in pairs( tCallbacks ) do
      if ( v == nil ) then
        Warning( "Callback '" .. tostring( k ) .. "' (" .. tostring( strName ) .. ") tried to call a nil function!\n" )
        tCallbacks[ k ] = nil
        break
      else
        bError, strError = pcall( v, var, pOldString, flOldValue )
        if ( bError == false ) then
          Warning( "Callback '" .. tostring( k ) .. "' (" .. tostring( strName ) .. ") Failed: " .. tostring( strError ) .. "\n" )
          tCallbacks[ k ] = nil
        end
      end
    end
  end

  -- HL2SB: bridge the engine's global change callback into GMod's `cvars` library.
  -- The engine only ever calls cvar.CallGlobalChangeCallbacks (licvar.cpp
  -- CV_GlobalChange_Lua); GMod's cvars.AddChangeCallback table is fed by
  -- cvars.OnConVarChanged, which nothing used to invoke - so every
  -- cvars.AddChangeCallback (and every Panel:SetConVar built on it) was dead.
  -- Per the wiki the callback receives three STRINGS: name, old value, new value.
  --
  -- HL2SB: only bridge an ACTUAL change.  The engine fires CV_GlobalChange even
  -- when a script writes the value it already has, and without this guard a
  -- derma convar panel loops forever: ConVarChanged applies the value ->
  -- OnValueChanged -> RunConsoleCommand writes the SAME value -> callback fires
  -- again -> ... (C stack overflow; the minecraft SWEP's block-health slider
  -- froze the game this way).  GMod notifies on change only.
  local cvars = GlobalTable.cvars   -- resolved at call time via the captured global table
  if ( cvars and cvars.OnConVarChanged ) then
    local strNew = tostring( var:GetString() )
    local strOld = tostring( pOldString )
    if ( strNew ~= strOld ) then
      bError, strError = pcall( cvars.OnConVarChanged, strName, strOld, strNew )
      if ( bError == false ) then
        Warning( "cvars.OnConVarChanged (" .. tostring( strName ) .. ") Failed: " .. tostring( strError ) .. "\n" )
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Purpose: Returns all of the registered callbacks or only callbacks
--      pertaining to a specific ConVar
-- Input  : strConVarName - Name of the ConVar
-- Output : table
-------------------------------------------------------------------------------
function GetChangeCallbacks( strConVarName )
  if ( strConVarName ) then
    return tCallbacks[ strConVarName ]
  end
  return tCallbacks
end

-------------------------------------------------------------------------------
-- Purpose: Removes a callback from the list of registered callbacks
-- Input  : strConVarName - Name of the ConVar
--      strCallbackName - Name of the callback
-- Output :
-------------------------------------------------------------------------------
function RemoveChangeCallback( strConVarName, strCallbackName )
  if ( tCallbacks[ strConVarName ][ strCallbackName ] ) then
    tCallbacks[ strConVarName ][ strCallbackName ] = nil
  end
end
