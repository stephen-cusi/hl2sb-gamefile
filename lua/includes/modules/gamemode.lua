--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Gamemode handling.
--
--===========================================================================--

-- 必须和 C++ 的 LUA_BASE_GAMEMODE 一致（game/shared/lua/luamanager.h）。
-- 之前这里是 "deathmatch"，改成 GMod 结构后基础 gamemode 叫 "base"。
_BASE_GAMEMODE = "deathmatch"

require( "hook" )

local hook = hook
local table = table
local print = print
local _BASE_GAMEMODE = _BASE_GAMEMODE
local _G = _G
local tostring = tostring
local Warning = dbg.Warning

module( "gamemode" )

local tGamemodes = {}

-------------------------------------------------------------------------------
-- Purpose: Calls a gamemode function
-- Input  : strEventName - Name of the internal GameRules method
-- Output :
-------------------------------------------------------------------------------
function call( strEventName, ... )
  if ( _G._GAMEMODE and _G._GAMEMODE[ strEventName ] == nil ) then
    return false
  end
  return hook.call( strEventName, _G._GAMEMODE, ... )
end

-- HL2SB: GMod spells this Call (capital C).  lua/derma/derma.lua:167 calls
-- gamemode.Call( "ForceDermaSkin" ) from GetDefaultSkin(), and GetDefaultSkin()
-- runs on every panel skin lookup -- with only the lowercase name defined that
-- threw
--
--     lua/derma/derma.lua:167: attempt to call a nil value (field 'Call')
--
-- once per frame, so the GMod notice panel existed but could never paint (the
-- "no animation" symptom).  Same function, both names.
Call = call

-------------------------------------------------------------------------------
-- Purpose: Returns a gamemode table object
-- Input  : strName - Name of the gamemode
-- Output : table
-------------------------------------------------------------------------------
function get( strName )
  return tGamemodes[ strName ]
end

-------------------------------------------------------------------------------
-- Purpose: Registers a gamemode
-- Input  : tGamemode - Gamemode table object
--          strName - Name of the gamemode
--          strBaseClass - Name of the base class
-- Output :
-------------------------------------------------------------------------------
function register( tGamemode, strName, strBaseClass )
  if ( get( strName ) ~= nil and _G._GAMEMODE ~= nil ) then
    tGamemode = table.inherit( tGamemode, _G._GAMEMODE )
  end
  if ( strName ~= _BASE_GAMEMODE ) then
    -- 父 gamemode 必须先加载好（引擎是按 base -> 当前 gamemode 的顺序加载的）。
    -- 拿不到就只警告，不要 table.inherit(nil) 直接把加载打断。
    local tBase = get( strBaseClass )
    if ( tBase ~= nil ) then
      tGamemode = table.inherit( tGamemode, tBase )
    else
      Warning( "WARNING: gamemode \"" .. tostring( strName ) ..
               "\" declares base \"" .. tostring( strBaseClass ) ..
               "\" but it is not registered yet!\n" )
    end
  end
  tGamemodes[ strName ] = tGamemode
end
