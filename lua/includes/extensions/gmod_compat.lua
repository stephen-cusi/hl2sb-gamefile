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
-- 2. Shared storage for the native global variable bindings.
-- ===========================================================================

local tGlobals = _G.__HL2SB_GLOBALS or {}
_G.__HL2SB_GLOBALS = tGlobals

-- ===========================================================================
-- 2.1 跨端复制（2026-09-24）
--     上面的表原本“服务端和客户端各存各的”（见本节开头注释）。GMod 的
--     SetGlobal* 是跨 realm 的 —— nukepack 的 cl_init 读
--     GetGlobalInt("nuke_yield") 在客户端永远拿到 0：Yield=0 使它把所有爆炸
--     音效预标记成“已播放”、把客户端 Think 停摆 999 秒，核弹全程静默。
--     修复：服务端每次 Set* 后用 net 广播；玩家进服 1 秒后补发全量快照。
-- ===========================================================================
local NET_GVAR = "HL2SB_GVar"

if SERVER then
	if util and util.AddNetworkString then
		util.AddNetworkString( NET_GVAR )
	end

	local function broadcast( key )
		local v = tGlobals[ key ]
		net.Start( NET_GVAR )
			net.WriteString( tostring( key ) )
			net.WriteType( v )
		net.Broadcast()
	end

	-- 迟到的玩家：进服 1 秒后补发全量快照
	hook.add( "PlayerInitialSpawn", "HL2SB_GVarSnapshot", function( ply )
		timer.Simple( 1, function()
			if not IsValid( ply ) then return end
			for k in pairs( tGlobals ) do
				local v = tGlobals[ k ]
				net.Start( NET_GVAR )
					net.WriteString( tostring( k ) )
					net.WriteType( v )
				net.Send( ply )
			end
		end )
	end )

	-- 包一层：服务端存完即广播（跨端语义只属于服务端写入，GMod 同）
	local _SetVar, _SetInt, _SetFloat, _SetString, _SetBool, _SetVector, _SetAngle, _SetEntity =
		SetGlobalVar, SetGlobalInt, SetGlobalFloat, SetGlobalString, SetGlobalBool, SetGlobalVector, SetGlobalAngle, SetGlobalEntity

	SetGlobalVar   = function( k, v ) local r = _SetVar( k, v ); broadcast( k ); return r end
	SetGlobalInt   = function( k, v ) local r = _SetInt( k, v ); broadcast( k ); return r end
	SetGlobalFloat = function( k, v ) local r = _SetFloat( k, v ); broadcast( k ); return r end
	SetGlobalString= function( k, v ) local r = _SetString( k, v ); broadcast( k ); return r end
	SetGlobalBool  = function( k, v ) local r = _SetBool( k, v ); broadcast( k ); return r end
	SetGlobalVector = function( k, v ) local r = _SetVector( k, v ); broadcast( k ); return r end
	SetGlobalAngle = function( k, v ) local r = _SetAngle( k, v ); broadcast( k ); return r end
	SetGlobalEntity = function( k, v ) local r = _SetEntity( k, v ); broadcast( k ); return r end
end

if CLIENT then
	-- net.Receive 是追加式注册：文件重载会挂两个接收器（undo.lua 的教训），
	-- 用标记防重。
	if not _G.__HL2SB_GVAR_RECV then
		_G.__HL2SB_GVAR_RECV = true
		net.Receive( NET_GVAR, function()
			local key = net.ReadString()
			tGlobals[ key ] = net.ReadType()
		end )
	end
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

-- HL2SB: 引擎本体（lsrcinit）注册过 game.SinglePlayer（gpGlobals->maxClients <= 1，
-- 服务端语义准确）。这里旧版整函数覆盖成 engine.GetMaxClients —— 但本引擎没有
-- 这个绑定，兜底恒 true，把多人局判成单机；GMod 的契约是"单机不设限"（
-- player_extension.lua CheckLimit 第一行），沙盒上限因此整体失效。改为：优先用
-- engine.GetMaxClients（有绑定才走），否则回退覆盖前的引擎绑定；两者都拿不到
-- 才回答 false（按多人算，让限制体系说话）。
local EngineSinglePlayer = game.SinglePlayer

function game.SinglePlayer()
	if ( engine ~= nil and engine.GetMaxClients ~= nil ) then
		return ( SafeCall( engine.GetMaxClients ) or 1 ) <= 1
	end
	if ( EngineSinglePlayer ~= nil ) then
		local ok, v = pcall( EngineSinglePlayer )
		if ( ok and v ~= nil ) then return v == true end
	end
	return false
end

game.IsSinglePlayer = game.SinglePlayer

function game.GetMap()
	if ( engine == nil or engine.GetLevelName == nil ) then return "" end
	return SafeCall( engine.GetLevelName ) or ""
end

function game.GetMapName()
	return game.GetMap()
end

-- GMod: game.GetWorld() -- 世界实体（entindex 0）。gmsave.SaveMap 把它加进
-- 复制列表，只为取"只挂在世界上"的约束；本引擎没有 C 绑定，Entity(0) 等价。
if ( game.GetWorld == nil ) then
	function game.GetWorld()
		if ( Entity == nil ) then return nil end
		return Entity( 0 )
	end
end

-- GMod: player.GetHumans() -- 非机器人玩家。gmsave 读档兜底找"唯一的那个
-- 玩家"用；本引擎没有 C 绑定，在 GetAll 上滤 IsBot 等价。
if ( player ~= nil and player.GetHumans == nil and player.GetAll ~= nil ) then
	function player.GetHumans()
		local out = {}
		for _, ply in ipairs( player.GetAll() or {} ) do
			if ( ply.IsBot == nil or not ply:IsBot() ) then
				out[ #out + 1 ] = ply
			end
		end
		return out
	end
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

function game.GetTimeScale()
	return 1
end

-- GMod: game.CleanUpMap( dontSendToClients, extraFilters, callback )
--
-- 引擎侧实体是 HL2SB_GameCleanUpMap（game/server/lua/lutil.cpp），它调用
-- CHL2MPRules::CleanUpMap()：重建地图自身实体、删掉其余（玩家/手持武器除外）并
-- 触发 CleanUpMap 钩子 —— 与 GMod 文档描述一致。GMod 的三个可选参数这里接受但
-- 忽略（callback 仍在结束后被调用）。
--
-- HL2SB (2026-10-05): GMod 在清理前后各发一个 GM:PreCleanupMap /
-- GM:PostCleanupMap 钩子；本引擎 C++ 只发 "CleanUpMap" 一个。gmsave.LoadMap 的
-- 整个读档流程挂在 PostCleanupMap 上（清完图再 Paste 回去），所以包装器按
-- GMod 的次序补发这两个钩子；C++ 原有的 "CleanUpMap" 钩子保持不动。
function game.CleanUpMap( dontSendToClients, extraFilters, callback )
	if ( hook ~= nil and hook.Run ~= nil ) then
		hook.Run( "PreCleanupMap" )
	end

	if ( HL2SB_GameCleanUpMap ) then
		HL2SB_GameCleanUpMap()
	end

	if ( hook ~= nil and hook.Run ~= nil ) then
		hook.Run( "PostCleanupMap" )
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

	-- GMod: ply:IsAdmin()。本引擎没有 usergroup 体系（cod-c4 曾因它不存在
	-- 报过 attempt to call nil）。按 GMod 默认语义的最低实现：单人恒真
	-- （GMod 单人本来就豁免管理员门），多人恒假（GMod 默认也没有人自带
	-- admin 组，users.txt 那套这里没有）。
	if ( plymeta.IsAdmin == nil ) then
		plymeta.IsAdmin = function()
			return game.SinglePlayer() == true
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
end

-- ===========================================================================
-- 4b. NW 库的 GMod 旧拼法（SetNetworkedBool == SetNWBool 等）
--     minecraft 等老插件全用 Networked 拼法。
-- ===========================================================================

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
-- 6b. ents.GetAll / FindInSphere / FindInCone —— scp049 等 nextbot 插件的
-- 目标搜索命脉。同样走 gEntList 的链式原语（FirstEnt/NextEnt/FindEntityInSphere）。
-- FindInCone 按 wiki：以 WorldSpaceCenter 落在半角余弦 angle_cos 内为准。
-- ===========================================================================

if ( _G.ents ~= nil and _G.gEntList ~= nil ) then

	if ( ents.GetAll == nil ) then
		function ents.GetAll()
			local out = {}
			local e = gEntList.FirstEnt()
			while ( e ~= nil and e ~= NULL ) do
				table.insert( out, e )
				e = gEntList.NextEnt( e )
			end
			return out
		end
	end

	if ( ents.FindInSphere == nil ) then
		function ents.FindInSphere( pos, radius )
			local out = {}
			local e = NULL
			while true do
				e = gEntList.FindEntityInSphere( e, pos, radius )
				if ( e == nil or e == NULL ) then break end
				table.insert( out, e )
			end
			return out
		end
	end

	if ( ents.FindInCone == nil ) then
		function ents.FindInCone( pos, dir, range, angleCos )
			local out = {}
			if ( dir == nil or angleCos == nil ) then return out end

			-- GMod's 4th argument changed meaning at some point: old addons
			-- (scp0492base passes 155) hand an ANGLE IN DEGREES, the current wiki
			-- documents the cosine of the half-angle.  A cosine is -1..1, so any
			-- value above 1 can only be the legacy degrees form.
			if ( angleCos > 1 ) then
				angleCos = math.cos( math.rad( angleCos ) )
			end

			local normal = dir:GetNormalized()
			for _, v in ipairs( ents.FindInSphere( pos, range or 0 ) ) do
				local ok, center = pcall( v.WorldSpaceCenter, v )
				if ( ok and center ~= nil ) then
					local offset = center - pos
					-- 恰在锥顶的实体按命中处理，否则长度为 0 的向量没有方向
					if ( offset:Length() < 1 or normal:Dot( offset:GetNormalized() ) >= angleCos ) then
						table.insert( out, v )
					end
				end
			end

			-- HL2SB TEMPORARY: disambiguates which targeting path scp049-2 runs
			-- (FindInCone only runs on nb_targetmethod 1)
			if ( HL2SB_FindInConeDiag == nil or HL2SB_FindInConeDiag < 3 ) then
				HL2SB_FindInConeDiag = ( HL2SB_FindInConeDiag or 0 ) + 1
				print( "[HL2SB] ents.FindInCone: requested (method-1 targeting in use), results=" .. #out .. "\n" )
			end
			return out
		end
	end

end

-- ===========================================================================
-- 6c. sound.Add —— GMod 的运行时音效脚本。addons 在 autorun 里注册
-- "SCP049_Alert" 这类名字，之后 EmitSound / CreateSound 直接用名字。
-- HL2SB 的引擎没有可注入的 soundscript 表，这里建一个 Lua 注册表，并把
-- Entity:EmitSound 和全局 CreateSound 包一层：名字命中脚本时解析成随机
-- 变体路径，同时把脚本里的 soundlevel/volume/channel 作为未显式传参时的默认值。
-- ===========================================================================

if ( _G.sound == nil ) then _G.sound = {} end

local hl2sb_soundscripts = {}

function sound.Add( tbl )
	if ( not istable( tbl ) ) then return end
	if ( tbl.name == nil or tbl.name == "" ) then return end

	-- GMod 的 sound 字段可以是单串或表（随机变体）
	local variants = {}
	if ( istable( tbl.sound ) ) then
		for i = 1, #tbl.sound do
			variants[ #variants + 1 ] = tbl.sound[ i ]
		end
	elseif ( tbl.sound ~= nil ) then
		variants[ #variants + 1 ] = tostring( tbl.sound )
	end

	if ( #variants == 0 ) then return end

	hl2sb_soundscripts[ string.lower( tbl.name ) ] = {
		Name = tbl.name,
		Sounds = variants,
		Channel = tbl.channel,
		Volume = tonumber( tbl.volume ),
		Level = tonumber( tbl.soundlevel ) or tonumber( tbl.level ),
		Pitch = tonumber( tbl.pitchstart ) or tonumber( tbl.pitch ),
	}
end

-- 名字 → 脚本；未注册返回 nil（调用方走原始路径）
function sound.GetProperties( name )
	if ( name == nil ) then return nil end
	return hl2sb_soundscripts[ string.lower( tostring( name ) ) ]
end

-- EmitSound / CreateSound 的名字解析。变体在"每次发声"时随机（GMod 语义），
-- CreateSound 是长驻通道，解析一次后固定。
local function HL2SB_ResolveSoundScript( name, level, volume, channel, pick )
	if ( name == nil or hl2sb_soundscripts == nil ) then return name, level, volume, channel end

	local script = hl2sb_soundscripts[ string.lower( tostring( name ) ) ]
	if ( script == nil ) then return name, level, volume, channel end

	local path = name
	if ( #script.Sounds > 0 ) then
		path = script.Sounds[ pick and math.random( #script.Sounds ) or 1 ]
	end

	return path,
		level or script.Level,
		volume or script.Volume,
		channel or script.Channel
end

-- Entity:EmitSound( name, soundLevel, pitchPercent, volume, channel, ... )
local ENTITY_META = FindMetaTable( "Entity" )
if ( ENTITY_META ~= nil and ENTITY_META.EmitSound ~= nil and ENTITY_META.EmitSound ~= true ) then
	local hl2sb_orig_EmitSound = ENTITY_META.EmitSound
	ENTITY_META.EmitSound = function( self, name, soundLevel, pitchPercent, volume, channel, ... )
		local path, lvl, vol, ch = HL2SB_ResolveSoundScript( name, soundLevel, volume, channel, true )
		return hl2sb_orig_EmitSound( self, path, lvl, pitchPercent, vol, ch, ... )
	end
end

-- 全局 CreateSound( ent, name ) —— CSoundPatch 长驻通道
if ( _G.CreateSound ~= nil ) then
	local hl2sb_orig_CreateSound = CreateSound
	CreateSound = function( ent, name, ... )
		local path = HL2SB_ResolveSoundScript( name, nil, nil, nil, false )
		return hl2sb_orig_CreateSound( ent, path, ... )
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
-- 10. engine.ActiveGamemode()
--
-- GMod: the active gamemode's folder name.  It was defined ONLY in the never-loaded
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


-- ===========================================================================
-- HL2SB GMod compat (2026-09-24): combustible-lemon addon round.
--
-- Gaps surfaced by addons/combustible_lemon (and confirmed against the wiki):
--   1. seven enum globals (CHAN_ITEM, GMOD_CHANNEL_*, COLLISION_GROUP_WEAPON
--      /WORLD, MAT_*)            -> plain constants below.
--   2. Entity:NearestPoint       -> pure-Lua OBB nearest point.
--   3. DynamicLight / sound.PlayFile (IGModAudioChannel) -> documented stubs.
--      This fork binds no dlight renderer and no BASS audio channel; the stubs
--      keep addons that touch them error-free.  Player:StripWeapon and
--      DamageInfo:IsDamageType / Entity:GetMaterialType / Player:KeyDownLast
--      needed real bindings and were done engine-side the same day.
--
-- NOTE: unlike sh_init.lua (which sits behind the never-loaded
-- gmod_compatibility/ folder pass), everything in THIS file actually loads --
-- the lemon's StripWeapon error was exactly a shim defined in the wrong file.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Enum globals (values from the GMod wiki; COLLISION_GROUP_WEAPON == 11
--    also matches this engine's Collision_Group_t in public/const.h).
-- ---------------------------------------------------------------------------
CHAN_REPLACE  = CHAN_REPLACE  or -1
CHAN_AUTO     = CHAN_AUTO     or 0
CHAN_WEAPON   = CHAN_WEAPON   or 1
CHAN_VOICE    = CHAN_VOICE    or 2
CHAN_ITEM     = CHAN_ITEM     or 3
CHAN_BODY     = CHAN_BODY     or 4
CHAN_STREAM   = CHAN_STREAM   or 5
CHAN_VOICE2   = CHAN_VOICE2   or 7

GMOD_CHANNEL_STOPPED = GMOD_CHANNEL_STOPPED or 0
GMOD_CHANNEL_PLAYING = GMOD_CHANNEL_PLAYING or 1
GMOD_CHANNEL_PAUSED  = GMOD_CHANNEL_PAUSED  or 2
GMOD_CHANNEL_STALLED = GMOD_CHANNEL_STALLED or 3

COLLISION_GROUP_WEAPON = COLLISION_GROUP_WEAPON or 11
-- GMod's COLLISION_GROUP_WORLD is 20 (a group past LAST_SHARED); the engine now
-- publishes it as 20 too (public/lenumerations_shared.cpp). The "or 20" only
-- helps if that global arrives nil; when the engine used to publish it as
-- COLLISION_GROUP_DEBRIS(1) this line could NOT correct it (1 is truthy), which
-- is why entities set to WORLD were treated as debris and box sweeps passed
-- through them.
COLLISION_GROUP_WORLD  = COLLISION_GROUP_WORLD  or 20

-- GMod's MAT_ globals carry the raw gamematerial byte ('A'=65 .. 'Y'=89),
-- which is exactly what Entity:GetMaterialType() returns on this fork.
MAT_ANTLION     = MAT_ANTLION     or 65
MAT_BLOODYFLESH = MAT_BLOODYFLESH or 66
MAT_CONCRETE    = MAT_CONCRETE    or 67
MAT_DIRT        = MAT_DIRT        or 68
MAT_EGGSHELL    = MAT_EGGSHELL    or 69
MAT_FLESH       = MAT_FLESH       or 70
MAT_GRATE       = MAT_GRATE       or 71
MAT_ALIENFLESH  = MAT_ALIENFLESH  or 72
MAT_CLIP        = MAT_CLIP        or 73
MAT_SNOW        = MAT_SNOW        or 74
MAT_PLASTIC     = MAT_PLASTIC     or 76
MAT_METAL       = MAT_METAL       or 77
MAT_SAND        = MAT_SAND        or 78
MAT_FOLIAGE     = MAT_FOLIAGE     or 79
MAT_COMPUTER    = MAT_COMPUTER    or 80
MAT_SLOSH       = MAT_SLOSH       or 83
MAT_TILE        = MAT_TILE        or 84
MAT_GRASS       = MAT_GRASS       or 85
MAT_VENT        = MAT_VENT        or 86
MAT_WOOD        = MAT_WOOD        or 87
MAT_DEFAULT     = MAT_DEFAULT     or 88
MAT_GLASS       = MAT_GLASS       or 89
MAT_WARPSHIELD  = MAT_WARPSHIELD  or 90

do
	local ENTITY_META = FindMetaTable( "Entity" )

	if ( ENTITY_META ~= nil ) then
		if ( ENTITY_META.GetModelRenderBounds == nil ) then
			function ENTITY_META:GetModelRenderBounds()
				return self:OBBMins(), self:OBBMaxs()
			end
		end

		-- HL2SB (2026-10-19): GetBoneCount / GetBoneName must NOT be stubbed here.
		-- The engine already binds both (bone count from the studio header, the
		-- "__INVALIDBONE__" name for an out-of-range index), and this file runs
		-- BEFORE those bindings are registered on the table that entity userdata
		-- actually resolve through -- so the "== nil" guard below was always
		-- true and the stubs ended up SHADOWING the real functions for the rest
		-- of the session.  Symptom: every model reported a bone count of 0 and
		-- every bone name was "__INVALIDBONE__", which silently broke every
		-- script that walks a skeleton or resolves a bone by name.
		--
		-- The correct fallbacks are therefore installed LATE, only if the
		-- engine binding really is missing once the map is up (see the
		-- InitPostEntity handler at the end of this block).
	end

	local PLAYER_META = FindMetaTable( "Player" )
	if ( PLAYER_META ~= nil ) then
		if ( PLAYER_META.SetEyeAngles == nil and PLAYER_META.SnapEyeAngles ~= nil ) then
			PLAYER_META.SetEyeAngles = PLAYER_META.SnapEyeAngles
		end
	end

	local CMD_META = FindMetaTable( "CUserCmd" )
	if ( CMD_META ~= nil ) then
		if ( CMD_META.GetViewAngles == nil ) then
			function CMD_META:GetViewAngles()
				return self.viewangles or Angle( 0, 0, 0 )
			end
		end
		if ( CMD_META.SetViewAngles == nil ) then
			function CMD_META:SetViewAngles( ang )
				self.viewangles = ang
			end
		end
		if ( CMD_META.AddKey == nil ) then
			function CMD_META:AddKey( key )
				self.buttons = bit.bor( self.buttons or 0, key or 0 )
			end
		end
		if ( CMD_META.KeyDown == nil ) then
			function CMD_META:KeyDown( key )
				return bit.band( self.buttons or 0, key or 0 ) ~= 0
			end
		end
		if ( CMD_META.CommandNumber == nil ) then
			function CMD_META:CommandNumber()
				return self.command_number or 0
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 3. Client stubs: DynamicLight( index ) and sound.PlayFile.
--    DynamicLight is real since 2026-10-07: render.DynamicLight allocates an
--    engine dlight and returns a live table view (field writes land in the
--    light struct), so the global just forwards to it.  PlayFile reports a
--    channel error so addons skip their VO gracefully
--    (combustible_lemon checks `if soundChannel ~= nil` before storing it).
-- ---------------------------------------------------------------------------
if ( CLIENT ) then
	if ( render ~= nil and render.DynamicLight ~= nil ) then
		DynamicLight = function( index, elight )
			return render.DynamicLight( index, elight == true )
		end
	else
		DynamicLight = function( index, elight )
			return { index = index, elight = elight == true }
		end
	end

	sound = sound or {}
	if ( sound.PlayFile == nil ) then
		sound.PlayFile = function( path, flags, callback )
			if ( isfunction( callback ) ) then
				-- GMod callback signature: ( channel, errorId, errorName )
				callback( nil, 0, "hl2sb: no IGModAudioChannel binding" )
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 4. EyeVector( ) -- GMod global (client): the forward vector of the main
--    view.  The render library already exposes exactly that value as
--    render.MainViewForward, so the global is just an alias for it.
--    hl1sweps' RPG laser spot (ent_hl1_laser_spot) pulls its dot a few units
--    back along this vector on every translucent pass.
-- ---------------------------------------------------------------------------
if ( CLIENT and EyeVector == nil and render ~= nil and render.MainViewForward ~= nil ) then
	EyeVector = render.MainViewForward
	Msg( "[HL2SB]   EyeVector added (render.MainViewForward alias)\n" )
end

-- ---------------------------------------------------------------------------
-- 5. util.QuickTrace( startPos, delta, filter ) -- GMod's lighter trace.
--    A plain util.TraceLine answers the same result for every consumer this
--    tree has (hl1sweps' satchel charge detonation reads HitPos / HitNormal
--    off the returned table); the trace-result contract already matches
--    GMod's field semantics, Normal = ray direction, HitNormal = face normal.
-- ---------------------------------------------------------------------------
if ( util ~= nil and util.QuickTrace == nil ) then
	function util.QuickTrace( startPos, delta, filter )
		return util.TraceLine( { start = startPos, endpos = startPos + delta, filter = filter } )
	end
	Msg( "[HL2SB]   util.QuickTrace added (util.TraceLine wrapper)\n" )
end

-- ---------------------------------------------------------------------------
-- 6. Bone-accessor fallbacks, installed LATE on purpose.
--
--    GetBoneCount / GetBoneName used to be stubbed unconditionally at the top
--    of this file, which ran before the engine bindings were reachable through
--    FindMetaTable( "Entity" ) -- so the stubs won and every model reported
--    "0 bones" / "__INVALIDBONE__" for the whole session.  Installing them
--    once the map is up (InitPostEntity) means the engine binding wins
--    whenever it exists, and plugins still get GMod's harmless defaults when a
--    build really lacks it.
-- ---------------------------------------------------------------------------
local function HL2SB_InstallBoneFallbacks()
	if ( FindMetaTable == nil ) then return end
	local meta = FindMetaTable( "Entity" )
	if ( meta == nil ) then return end

	if ( meta.GetBoneCount == nil ) then
		function meta:GetBoneCount() return 0 end
	end

	if ( meta.GetBoneName == nil ) then
		function meta:GetBoneName( id ) return "__INVALIDBONE__" end
	end
end

if ( hook ~= nil and hook.Add ~= nil ) then
	hook.Add( "InitPostEntity", "hl2sb_gmod_compat_bone_fallbacks", HL2SB_InstallBoneFallbacks )
end

