--[[----------------------------------------------------------------------------
    gmod_compat.lua

    GMod 全局兼容层。

    GMod 的纯 Lua 脚本（含我们从 GMod 搬过来的库）会直接用一批全局函数、常量和
    表，HL2SB 原本没有。这个文件只补“纯 Lua 能补”的那部分 —— 需要新引擎绑定的
    （derma、net 写包、navmesh…）不在这里，宁可不定义也不要给个假的。

    实际被依赖的例子：`lua/includes/extensions/table.lua` 和 `net.lua` 里到处用
    `istable(...)`，但 HL2SB 从来没定义过它。

    加载点：lua/includes/extensions/（每张地图加载一次）。
-----------------------------------------------------------------------------]]--

local type = type
local rawget = rawget
local getmetatable = getmetatable
local tostring = tostring
local tonumber = tonumber
local math_floor = math.floor

-- ===========================================================================
-- 0. Lua 5.1 兼容
--    Lua 5.4 去掉了全局 unpack()。GMod 脚本（和我们搬过来的库）到处用它。
-- ===========================================================================

unpack = unpack or table.unpack
loadstring = loadstring or load
setfenv = setfenv or function( f, env )
	-- Lua 5.4 没有 setfenv；只能对函数有效，用 debug.upvaluejoin 太重，
	-- 这里退化成“原样返回”，让老代码至少不因为 nil 调用炸掉。
	return f
end

-- ===========================================================================
-- 1. 类型谓词（GMod 全局）
--    HL2SB 的全局 type() 是引擎的 luasrc_type：有 __type 就返回 __type，
--    所以实体/Vector 这些 userdata 也能正确判定。
-- ===========================================================================

local function DefPredicate( name, checker )
	if ( _G[ name ] == nil ) then
		_G[ name ] = checker
	end
end

-- 引擎的 type() 对带 __type 的 metatable 返回 __type，否则返回 luaL_typename。
local function T( v ) return type( v ) end

DefPredicate( "istable",    function( v ) return T( v ) == "table" end )
DefPredicate( "isstring",   function( v ) return T( v ) == "string" end )
DefPredicate( "isnumber",   function( v ) return T( v ) == "number" end )
DefPredicate( "isbool",     function( v ) return T( v ) == "boolean" end )
DefPredicate( "isfunction", function( v ) return T( v ) == "function" end )
DefPredicate( "isuserdata", function( v ) return T( v ) == "userdata" end )
DefPredicate( "isthread",   function( v ) return T( v ) == "thread" end )

DefPredicate( "isentity", function( v )
	if ( T( v ) ~= "userdata" ) then return false end

	local mt = getmetatable( v )
	if ( mt == nil ) then return false end

	-- 实体/武器/面板的 metatable 都带 __type。
	return rawget( mt, "__type" ) == "entity"
end )

DefPredicate( "isvector", function( v )
	if ( T( v ) ~= "userdata" ) then return false end

	local mt = getmetatable( v )
	if ( mt == nil ) then return false end

	local t = rawget( mt, "__type" )
	return t == "Vector" or t == "vector"
end )

DefPredicate( "isangle", function( v )
	if ( T( v ) ~= "userdata" ) then return false end

	local mt = getmetatable( v )
	if ( mt == nil ) then return false end

	local t = rawget( mt, "__type" )
	return t == "QAngle" or t == "Angle" or t == "angle"
end )

DefPredicate( "ispanel", function( v )
	if ( T( v ) ~= "userdata" ) then return false end

	local mt = getmetatable( v )
	if ( mt == nil ) then return false end

	return rawget( mt, "__type" ) == "Panel"
end )

DefPredicate( "iscolor", function( v )
	if ( T( v ) ~= "userdata" ) then return false end

	local mt = getmetatable( v )
	if ( mt == nil ) then return false end

	return rawget( mt, "__type" ) == "Color"
end )

-- ===========================================================================
-- 2. 全局变量表（GMod 的 GetGlobalInt / SetGlobalInt 等）
--    注意：这一层是纯 Lua 的本地存储，服务端和客户端各存各的。
--    计分板这类“服务端自己读写”的用法没问题；要跨端同步得走 net。
-- ===========================================================================

local tGlobals = _G.__HL2SB_GLOBALS or {}
_G.__HL2SB_GLOBALS = tGlobals

function GetGlobalVar( key, default )
	local v = tGlobals[ key ]
	if ( v == nil ) then return default end
	return v
end

function SetGlobalVar( key, value )
	tGlobals[ key ] = value
	return value
end

function GetGlobalInt( key, default )
	local v = tGlobals[ key ]
	if ( v == nil ) then return default or 0 end
	return math_floor( tonumber( v ) or 0 )
end

function SetGlobalInt( key, value )
	tGlobals[ key ] = math_floor( tonumber( value ) or 0 )
	return tGlobals[ key ]
end

function GetGlobalFloat( key, default )
	local v = tGlobals[ key ]
	if ( v == nil ) then return default or 0 end
	return tonumber( v ) or 0
end

function SetGlobalFloat( key, value )
	tGlobals[ key ] = tonumber( value ) or 0
	return tGlobals[ key ]
end

function GetGlobalString( key, default )
	local v = tGlobals[ key ]
	if ( v == nil ) then return default or "" end
	return tostring( v )
end

function SetGlobalString( key, value )
	tGlobals[ key ] = tostring( value or "" )
	return tGlobals[ key ]
end

function GetGlobalBool( key, default )
	local v = tGlobals[ key ]
	if ( v == nil ) then return default and true or false end
	return v and true or false
end

function SetGlobalBool( key, value )
	tGlobals[ key ] = value and true or false
	return tGlobals[ key ]
end

-- ===========================================================================
-- 3. 全局 game 表
--    GMod 的 game 是 C++ 绑定的表；HL2SB 没有，用现有绑定拼一个等价的。
-- ===========================================================================

-- GMod 用 AddCSLuaFile 标记“这个文件也要发给客户端”。HL2SB 的 Lua 本来
-- 就在客户端和服务端各有一份，所以是空操作。
if ( _G.AddCSLuaFile == nil ) then
	function AddCSLuaFile( ... )
	end
end

-- GMod 的字符串格式化缩写
if ( _G.Format == nil ) then
	Format = string.format
end

-- GMod 的 RealTime()：服务器/客户端都从引擎的 gpGlobals 取
if ( _G.RealTime == nil ) then
	function RealTime()
		if ( gpGlobals ~= nil and gpGlobals.realtime ~= nil ) then
			return gpGlobals.realtime()
		end
		return 0
	end
end

-- GMod 的 GetHostName()
if ( _G.GetHostName == nil ) then
	function GetHostName()
		if ( _G.GetConVarString ~= nil ) then
			local ok, v = pcall( GetConVarString, "hostname" )
			if ( ok and v ~= nil ) then return v end
		end
		return "HL2SB Server"
	end
end

game = game or {}

local function SafeCall( fn, ... )
	local ok, a, b, c = pcall( fn, ... )
	if ( not ok ) then return nil end
	return a, b, c
end

function game.SinglePlayer()
	if ( engine == nil or engine.GetMaxClients == nil ) then return true end
	return ( SafeCall( engine.GetMaxClients ) or 1 ) <= 1
end

game.IsSinglePlayer = game.SinglePlayer

function game.GetMap()
	if ( engine == nil or engine.GetLevelName == nil ) then return "" end
	return SafeCall( engine.GetLevelName ) or ""
end

function game.GetMapName()
	return game.GetMap()
end

function game.GetIP()
	if ( engine == nil or engine.GetGameDir == nil ) then return "" end
	return SafeCall( engine.GetGameDir ) or ""
end

function game.GetPort()
	return 27015
end

function game.GetHostName()
	if ( GetConVarString == nil ) then return "" end
	return GetConVarString( "hostname" ) or ""
end

-- GMod: Entity:CallOnRemove( identifier, callback )
--
-- 引擎在每个脚本实体移除时派发 ENT:OnRemove，但 GMod 还允许对**任意**实体注册回调
-- （callback( ent, identifier )）。这里用 EntityRemoved 钩子代跑；弱键表，实体被回收
-- 后条目自动消失。
if ( FindMetaTable ) then
	local hl2sb_EntityMeta = FindMetaTable( "Entity" )

	if ( hl2sb_EntityMeta and not hl2sb_EntityMeta.CallOnRemove ) then
		local hl2sb_OnRemoveCallbacks = setmetatable( {}, { __mode = "k" } )

		hook.Add( "EntityRemoved", "hl2sb_callonremove", function( ent )
			local list = hl2sb_OnRemoveCallbacks[ ent ]
			if ( !list ) then return end

			hl2sb_OnRemoveCallbacks[ ent ] = nil

			for id, fn in pairs( list ) do
				local ok, err = pcall( fn, ent, id )
				if ( !ok ) then
					ErrorNoHalt( "[HL2SB] CallOnRemove '" .. tostring( id ) .. "' failed: " .. tostring( err ) .. "\n" )
				end
			end
		end )

		function hl2sb_EntityMeta:CallOnRemove( identifier, callback )
			if ( type( callback ) ~= "function" ) then return end

			local list = hl2sb_OnRemoveCallbacks[ self ]
			if ( !list ) then
				list = {}
				hl2sb_OnRemoveCallbacks[ self ] = list
			end

			if ( identifier == nil ) then
				identifier = tostring( self ) .. "#" .. tostring( #list + 1 )
			end

			list[ identifier ] = callback
		end
	end
end

function game.GetTimeScale()
	return 1
end

-- GMod: game.CleanUpMap( dontSendToClients, extraFilters, callback )
--
-- 引擎侧实体是 HL2SB_GameCleanUpMap（game/server/lua/lutil.cpp），它调用
-- CHL2MPRules::CleanUpMap()：重建地图自身实体、删掉其余（玩家/手持武器除外）并
-- 触发 CleanUpMap 钩子 —— 与 GMod 文档描述一致。GMod 的三个可选参数这里接受但
-- 忽略（callback 仍在结束后被调用）。
function game.CleanUpMap( dontSendToClients, extraFilters, callback )
	if ( HL2SB_GameCleanUpMap ) then
		HL2SB_GameCleanUpMap()
	end

	if ( callback ) then
		callback()
	end
end

function game.GetMaxPlayers()
	if ( engine == nil or engine.GetMaxClients == nil ) then return 1 end
	return SafeCall( engine.GetMaxClients ) or 1
end

-- 服务端执行控制台命令（GMod: game.ConsoleCommand）
if ( _GAME ) then
	function game.ConsoleCommand( cmd )
		if ( engine ~= nil and engine.ServerCommand ~= nil ) then
			engine.ServerCommand( tostring( cmd ) .. "\n" )
		end
	end
else
	function game.ConsoleCommand( cmd )
		if ( engine ~= nil and engine.ClientCmd ~= nil ) then
			engine.ClientCmd( tostring( cmd ) )
		end
	end
end

-- ===========================================================================
-- 4. 实体 / 玩家的 GMod 方法别名
--    GMod 脚本大量用 ply:Team() / ply:Nick() / ply:Alive() / ent:GetModel()。
--    HL2SB 的绑定叫别的名字，直接在 metatable 上加别名，不动 C++。
--    引擎的 __index 回退链会走到这些 metatable，所以别名立刻生效。
-- ===========================================================================

local function Alias( mt, name, source )
	if ( mt == nil or source == nil ) then return end
	if ( mt[ name ] == nil ) then
		mt[ name ] = source
	end
end

local entmeta = _R ~= nil and _R.CBaseEntity or nil
local plymeta = _R ~= nil and _R.CBasePlayer or nil
local hl2meta = _R ~= nil and _R.CHL2MP_Player or nil

if ( entmeta ~= nil ) then
	Alias( entmeta, "GetModel",      entmeta.GetModelName )
	Alias( entmeta, "EntIndex",      entmeta.entindex )
	Alias( entmeta, "SetModelName",  entmeta.SetModel )
	Alias( entmeta, "GetPos",        entmeta.GetAbsOrigin )
	Alias( entmeta, "SetPos",        entmeta.SetAbsOrigin )
	Alias( entmeta, "GetAngles",     entmeta.GetAbsAngles )
	Alias( entmeta, "SetAngles",     entmeta.SetAbsAngles )
	Alias( entmeta, "GetVelocity",   entmeta.GetAbsVelocity )
	Alias( entmeta, "SetVelocity",   entmeta.SetAbsVelocity )
	Alias( entmeta, "GetClass",      entmeta.GetClassname )
	-- HL2SB: GetTable has to answer the entity's per-entity Lua field table (the
	-- same table the engine __newindex writes), never the classname.  The old
	-- GetClassname alias made ent:GetTable() a STRING, so tab[key] fell through
	-- the string metatable and every custom entity field read back nil
	-- silently - player.lua's __index fallback (Owner.C4s in cod_c4) and
	-- construct.lua's ent:GetTable().toggle both died on it.
	Alias( entmeta, "GetTable",      entmeta.GetRefTable )
	Alias( entmeta, "Health",        entmeta.GetHealth )
	Alias( entmeta, "SetHealth",     entmeta.SetHealth )
	Alias( entmeta, "GetOwner",      entmeta.GetOwnerEntity )
	Alias( entmeta, "Remove",        entmeta.Remove )
	Alias( entmeta, "IsWorld",       entmeta.IsWorld )
end

if ( plymeta ~= nil ) then
	Alias( plymeta, "Team",      plymeta.GetTeamNumber )
	Alias( plymeta, "SetTeam",   plymeta.ChangeTeam )
	Alias( plymeta, "Nick",      plymeta.GetPlayerName )
	Alias( plymeta, "Alive",     plymeta.IsAlive )
	Alias( plymeta, "GetModel",  plymeta.GetModelName )
	Alias( plymeta, "SteamID",   plymeta.GetNetworkIDString )
	Alias( plymeta, "UniqueID",  plymeta.GetUserID )
	Alias( plymeta, "Ping",      function() return 0 end )
	Alias( plymeta, "SetModel",  plymeta.SetModel )
	-- GMod 的 Player:Give() == HL2SB 的 GiveNamedItem
	Alias( plymeta, "Give",      plymeta.GiveNamedItem )
	-- GMod 的武器查询/切换
	Alias( plymeta, "HasWeapon",    plymeta.Weapon_OwnsThisType )
	Alias( plymeta, "SelectWeapon", plymeta.Weapon_Switch )

	-- GMod: ply:GetInfo( "cl_playermodel" ) 读客户端 userinfo
	if ( plymeta.GetInfo == nil and engine ~= nil and engine.GetClientConVarValue ~= nil ) then
		plymeta.GetInfo = function( ply, key )
			local idx = engine.IndexOfEdict( ply )
			if ( idx == nil or idx == 0 ) then return "" end
			local ok, v = pcall( engine.GetClientConVarValue, idx, key )
			if ( not ok or v == nil ) then return "" end
			return v
		end
	end

	-- player_manager 在 extensions 之后加载，所以这两个别名要晚绑定。
	if ( plymeta.SetPlayerClass == nil ) then
		plymeta.SetPlayerClass = function( ply, class )
			if ( _G.player_manager ~= nil ) then
				return player_manager.SetPlayerClass( ply, class )
			end
		end
	end

	if ( plymeta.GetPlayerClass == nil ) then
		plymeta.GetPlayerClass = function( ply )
			if ( _G.player_manager ~= nil ) then
				return player_manager.GetPlayerClass( ply )
			end
			return nil
		end
	end
end

-- CHL2MP_Player 的 __index 会回退到 CBasePlayer，两边别名互补。
if ( hl2meta ~= nil ) then
	Alias( hl2meta, "Team",     hl2meta.GetTeamNumber )
	Alias( hl2meta, "Nick",     hl2meta.GetPlayerName )
	Alias( hl2meta, "Alive",    hl2meta.IsAlive )
	Alias( hl2meta, "GetModel", hl2meta.GetModelName )
end

-- ===========================================================================
-- 4b. NW 库的 GMod 旧拼法（SetNetworkedBool == SetNWBool 等）
--     minecraft 等老插件全用 Networked 拼法。
-- ===========================================================================
if ( entmeta ~= nil ) then
	Alias( entmeta, "SetNetworkedBool",   entmeta.SetNWBool )
	Alias( entmeta, "GetNetworkedBool",   entmeta.GetNWBool )
	Alias( entmeta, "SetNetworkedInt",    entmeta.SetNWInt )
	Alias( entmeta, "GetNetworkedInt",    entmeta.GetNWInt )
	Alias( entmeta, "SetNetworkedFloat",  entmeta.SetNWFloat )
	Alias( entmeta, "GetNetworkedFloat",  entmeta.GetNWFloat )
	Alias( entmeta, "SetNetworkedString", entmeta.SetNWString )
	Alias( entmeta, "GetNetworkedString", entmeta.GetNWString )
	Alias( entmeta, "SetNetworkedEntity", entmeta.SetNWEntity )
	Alias( entmeta, "GetNetworkedEntity", entmeta.GetNWEntity )
	Alias( entmeta, "SetNetworkedVector", entmeta.SetNWVector )
	Alias( entmeta, "GetNetworkedVector", entmeta.GetNWVector )
	Alias( entmeta, "SetNetworkedAngle",  entmeta.SetNWAngle )
	Alias( entmeta, "GetNetworkedAngle",  entmeta.GetNWAngle )
end

-- ===========================================================================
-- 4c. ClientsideModel( model, renderGroup ) —— 客户端临时模型全局
--     引擎侧已有 Entities.CreateClientEntity，这里补 GMod 的全局拼法。
--     返回的实体走 CBaseFlex 元表链（继承 CBaseAnimating/CBaseEntity 方法：
--     SetPos/SetAngles/SetSkin/SetNoDraw/DrawShadow/DrawModel/Remove/骨骼操作）。
-- ===========================================================================
if ( CLIENT and _G.ClientsideModel == nil and entmeta ~= nil and Entities ~= nil and Entities.CreateClientEntity ~= nil ) then
	_G.ClientsideModel = function( model, renderGroup )
		return Entities.CreateClientEntity( model, renderGroup )
	end
end

-- ===========================================================================
-- 5. player.Iterator —— GMod 用它遍历玩家（team.lua 等直接依赖）
-- ===========================================================================

if ( _G.player ~= nil and player.GetAll ~= nil and player.Iterator == nil ) then
	function player.Iterator()
		local t = player.GetAll()
		local i = 0
		return function()
			i = i + 1
			if ( t[ i ] ~= nil ) then
				return i, t[ i ]
			end
		end
	end
end

-- ===========================================================================
-- 6. ents.FindByClass / FindByName —— GMod 版是返回表，HL2SB 的 gEntList 是链表
-- ===========================================================================

if ( _G.ents ~= nil and ents.FindByClass == nil and _G.gEntList ~= nil ) then
	function ents.FindByClass( classname )
		local out = {}
		local e = gEntList.FindEntityByClassname( NULL, classname )
		while ( e ~= NULL and e ~= nil ) do
			table.insert( out, e )
			e = gEntList.FindEntityByClassname( e, classname )
		end
		return out
	end

	function ents.FindByName( name )
		local out = {}
		local e = gEntList.FindEntityByName( NULL, name )
		while ( e ~= NULL and e ~= nil ) do
			table.insert( out, e )
			e = gEntList.FindEntityByName( e, name )
		end
		return out
	end
end

-- ===========================================================================
-- 8. AccessorFunc / RunString —— GMod 常用全局
-- ===========================================================================

-- GMod: AccessorFunc( tab, "m_var", "Name" ) 生成 Name()/SetName() 一对方法
if ( _G.AccessorFunc == nil ) then
	function AccessorFunc( tab, key, name, force )
		local n = name or key

		tab[ "Get" .. n ] = function( self ) return self[ key ] end
		tab[ "Set" .. n ] = function( self, v ) self[ key ] = v end

		-- GMod 还会加不带 Get/Set 前缀的短名；force 控制是否覆盖已有方法
		if ( tab[ n ] == nil or force == 2 ) then
			tab[ n ] = tab[ "Get" .. n ]
		end

		if ( tab[ "Set" .. n ] == nil or force == 1 ) then
			tab[ "Set" .. n ] = tab[ "Set" .. n ]
		end

		return tab
	end
end

-- GMod: RunString( code, identifier ) —— 执行一段 Lua
if ( _G.RunString == nil ) then
	function RunString( code, identifier )
		local chunk, err = loadstring( tostring( code ), tostring( identifier or "RunString" ) )
		if ( chunk == nil ) then
			if ( dbg ~= nil and dbg.Warning ~= nil ) then
				dbg.Warning( "[RunString] " .. tostring( err ) .. "\n" )
			end
			return false
		end

		local ok, runErr = pcall( chunk )
		if ( not ok and dbg ~= nil and dbg.Warning ~= nil ) then
			dbg.Warning( "[RunString:" .. tostring( identifier or "?" ) .. "] " .. tostring( runErr ) .. "\n" )
		end

		return ok
	end
end

-- ===========================================================================
-- 9. cvars 表 —— GMod 的 cvars.Bool / cvars.Number / cvars.String
--    GMod 里是 C++，纯 Lua 用 cvar.FindVar 拼一个。
-- ===========================================================================

if ( _G.cvars == nil ) then
	cvars = {}

	local function Var( name )
		if ( _G.cvar == nil or cvar.FindVar == nil ) then return nil end
		local ok, v = pcall( cvar.FindVar, name )
		if ( not ok ) then return nil end
		return v
	end

	function cvars.Bool( name, default )
		local v = Var( name )
		if ( v == nil ) then return default and true or false end
		return v:GetBool()
	end

	function cvars.Number( name, default )
		local v = Var( name )
		if ( v == nil ) then return default or 0 end
		return v:GetFloat()
	end

	function cvars.String( name, default )
		local v = Var( name )
		if ( v == nil ) then return default or "" end
		return v:GetString()
	end
end

-- ===========================================================================
-- 9. 队伍常量（HL2MP 的取值；只有引擎没给的时候才补）
-- ===========================================================================

TEAM_CONNECTING = TEAM_CONNECTING or 0
TEAM_UNASSIGNED = TEAM_UNASSIGNED or 0
TEAM_SPECTATOR  = TEAM_SPECTATOR  or 1

-- ===========================================================================
-- 10. engine.ActiveGamemode()
--
-- GMod: the active gamemode's folder name.  ⚠️ It was defined ONLY in the never-loaded
-- modules/gmod_compatibility/sh_init.lua:335 - via `Gamemodes.GetActiveName()`, a symbol
-- from Experiment: Source that does not exist in this fork either - so addons calling it
-- raised "attempt to call a nil value (method 'ActiveGamemode')".
--
-- cod_c4 throws a charge through
--     if engine.ActiveGamemode() ~= "nzombies" then undo.Create( "C4" ) ... end
-- (addons/cod_c4/lua/weapons/seal6-c4/shared.lua:256), i.e. right after the charge was
-- registered in Owner.C4s, so the error killed the undo entry and the cleanup registration
-- (and printed once per throw).
--
-- This fork's equivalent is the replicated `gamemode` convar
-- (game/shared/lua/luamanager.cpp:57, default "sandbox") - the same string GMod's gamemode
-- folder name carries.
-- ===========================================================================

if ( engine ~= nil and engine.ActiveGamemode == nil ) then
	engine.ActiveGamemode = function()
		local cvar = GetConVar and GetConVar( "gamemode" )

		if ( cvar ~= nil ) then return cvar:GetString() end

		return "sandbox"
	end
end

