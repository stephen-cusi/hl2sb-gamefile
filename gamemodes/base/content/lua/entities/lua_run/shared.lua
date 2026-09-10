--[[--------------------------------------------------------------------------
    gamemodes/base/content/lua/entities/lua_run/shared.lua

    移植自 GMod 的 gamemodes/base/entities/entities/lua_run.lua。

    一个在地图里执行 Lua 的实体（map 里放 lua_run，keyvalue "code" 填代码）。
    引擎侧 hl2sb 把它注册成 CBaseAnimating 派生的脚本实体
    （ENT.__factory 由加载器预置），所以用 CreateEntityByName("lua_run") 就能生成。
--------------------------------------------------------------------------]]--

-- 生成时就跑一次代码的 spawnflag（和 GMod 同值）
SF_LUA_RUN_ON_SPAWN = 1

ENT.Type              = "point"
ENT.DisableDuplicator = true

AccessorFunc( ENT, "m_bDefaultCode", "DefaultCode" )
