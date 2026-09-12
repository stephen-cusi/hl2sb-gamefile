--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Scripted entity implementation.
--
--===========================================================================--

_BASE_ENTITY_CLASS = "prop_scripted"

--========== HL2SB - GMod compat ==========--
-- GMod's engine registers its own base class NAMES in C++, so no
-- lua/entities/<name> script exists for them here.  A stock GMod entity script
-- starts with DEFINE_BASECLASS( "base_anim" ), which the engine-side preprocessor
-- turns into `local BaseClass = baseclass.Get( "base_anim" )`; that call sets
-- ENT.Base = "base_anim" (lua/includes/modules/baseclass.lua:24).
--
-- Without this map the lookup below finds nothing, and then two things go wrong:
-- it warns, and - much worse - it returns the entity table WITHOUT inheriting
-- anything, so the fallback to __base (HL2SB's own prop_scripted, which carries
-- the real entity Lua methods) never happens either.  sent_ball hit exactly this.
--
-- Aliasing to prop_scripted is the honest mapping: in GMod these names resolve to
-- the engine's scripted-entity base, and prop_scripted IS this fork's equivalent.
local GMOD_BASE_ALIASES = {
	base_anim       = _BASE_ENTITY_CLASS,
	base_entity     = _BASE_ENTITY_CLASS,
	base_gmodentity = _BASE_ENTITY_CLASS,
	base_ai         = _BASE_ENTITY_CLASS,
	base_nextbot    = _BASE_ENTITY_CLASS,
}

local table = table
local type = type
local string = string
local tostring = tostring
local Warning = dbg.Warning

module( "entity" )

local tEntities = {}

-------------------------------------------------------------------------------
-- Purpose: Returns an entity table
-- Input  : strName - Name of the entity
-- Output : table
-------------------------------------------------------------------------------
function get( strClassname )
  local tEntity = tEntities[ strClassname ]
  if ( not tEntity ) then
    return nil
  end
  tEntity = table.copy( tEntity )

  -- HL2SB GMod 实体兼容：GMod 的实体脚本写 ENT.Base = "base_entity"。
  -- 优先用 Base 解析继承，没有才回落到引擎塞的 __base（= prop_scripted）。
  -- 和 weapon.get 的 SWEP.Base 处理保持一致。
  local sBase = tEntity.Base
  if ( type( sBase ) ~= "string" or sBase == "" or sBase == strClassname ) then
    sBase = tEntity.__base
  elseif ( GMOD_BASE_ALIASES[ sBase ] ) then
    -- GMod's engine-level base names (base_anim and friends) -> this fork's
    -- scripted entity base, so the entity inherits a real Lua table instead of
    -- coming back bare with a warning.
    sBase = GMOD_BASE_ALIASES[ sBase ]
  end

  if ( sBase ~= strClassname ) then
    local tBaseEntity = get( sBase )
    if ( not tBaseEntity ) then
      -- 引擎的 prop_scripted 在实体目录按字母序里最后加载，一个只以它为基类的
      -- 实体本来就没有 Lua 表可继承（字段由引擎填），别刷警告。
      if ( sBase ~= _BASE_ENTITY_CLASS ) then
        Warning( "WARNING: Attempted to initialize entity \"" .. strClassname ..
                 "\" with non-existing base class \"" .. tostring( sBase ) .. "\"!\n" )
      end
    else
      return table.inherit( tEntity, tBaseEntity )
    end
  end
  return tEntity
end

-------------------------------------------------------------------------------
-- Purpose: Returns all registered entities
-- Input  :
-- Output : table
-------------------------------------------------------------------------------
function getentities()
  return tEntities
end

-------------------------------------------------------------------------------
-- Purpose: Registers an entity
-- Input  : tEntity - Entity table
--          strClassname - Name of the entity
--          bReload - Whether or not we're reloading this entity data
-- Output :
-------------------------------------------------------------------------------
function register( tEntity, strClassname, bReload )
  if ( get( strClassname ) ~= nil and bReload ~= true ) then
    return
  end
  tEntities[ strClassname ] = tEntity
end
