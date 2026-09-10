--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/init.lua

    服务端半边。对应 GMod 的 gamemodes/base/gamemode/init.lua。

    缺绑定而省略的部分（HL2SB 没有，写个假的只会掩盖问题）：
      - ply:CreateRagdoll() / AddDeaths() / AddFrags()  —— 没有分数绑定
      - GM:ShowTeam 的 ChatPrint + SendLua 团队选择界面
      - GM:CheckPassword 仍实现（只用到引擎的 sv_password 语义）
--------------------------------------------------------------------------]]--

include( "shared.lua" )

-------------------------------------------------------------------------------
-- 出生 —— 这是整套玩家类体系的驱动点（GMod 在 base/gamemode/player.lua 里）
--
--   顺序和 GMod 一致：
--     player_manager.OnPlayerSpawn -> RunClass("Spawn")
--     -> PlayerLoadout -> RunClass("Loadout")   <-- 出生装备在这里决定
--     -> PlayerSetModel -> RunClass("SetModel")
--
--   HL2SB 的 C++ 在 CHL2MPRules::PlayerSpawn 里调 Lua 的 "PlayerSpawn" 钩子，
--   所以这里定义 GM:PlayerSpawn 就会被调到。
-------------------------------------------------------------------------------

local HookCall = ( _G.hook ~= nil and ( hook.Call or hook.call ) ) or nil

local function CallHook( name, ... )
	if ( HookCall ~= nil ) then
		return HookCall( name, GAMEMODE, ... )
	end
	return nil
end

-------------------------------------------------------------------------------
-- Purpose: 团队制 gamemode 里没分队的玩家先当观察者
-------------------------------------------------------------------------------
function GM:PlayerSpawnAsSpectator( pl )
	if ( pl.RemoveAllItems ~= nil ) then pl:RemoveAllItems( true ) end

	if ( GAMEMODE.TeamBased and pl.Team ~= nil and pl:Team() == TEAM_UNASSIGNED ) then
		return
	end

	if ( pl.SetTeam ~= nil ) then pl:SetTeam( TEAM_SPECTATOR ) end
end

-------------------------------------------------------------------------------
-- Purpose: 玩家出生
-------------------------------------------------------------------------------
function GM:PlayerSpawn( pl, transition )
	if ( not IsValid( pl ) ) then return end

	-- 团队制：没分队 -> 观察者
	if ( self.TeamBased and pl.Team ~= nil ) then
		local t = pl:Team()
		if ( t == TEAM_SPECTATOR or t == TEAM_UNASSIGNED ) then
			self:PlayerSpawnAsSpectator( pl )
			return
		end
	end

	-- 不是关卡切换才重置武器
	if ( not transition and pl.UnSpectate ~= nil ) then
		pl:UnSpectate()
	end

	player_manager.OnPlayerSpawn( pl, transition )
	player_manager.RunClass( pl, "Spawn" )

	if ( not transition ) then
		CallHook( "PlayerLoadout", pl )
	end

	CallHook( "PlayerSetModel", pl )

	if ( pl.SetupHands ~= nil ) then
		pl:SetupHands()
	end
end

-------------------------------------------------------------------------------
-- Purpose: 出生装备 —— 全权交给玩家类
-------------------------------------------------------------------------------
function GM:PlayerLoadout( pl )
	player_manager.RunClass( pl, "Loadout" )
end

-------------------------------------------------------------------------------
-- Purpose: 出生时设模型 —— 全权交给玩家类
-------------------------------------------------------------------------------
function GM:PlayerSetModel( pl )
	player_manager.RunClass( pl, "SetModel" )
end

-------------------------------------------------------------------------------
-- Purpose: HL2SB 专用的桥
--
--   引擎在 CHL2MP_Player::Spawn() 里除了 PlayerSpawn 之外，还会调一次 Lua 的
--   "GiveDefaultItems" 钩子（C++ 侧有自己的兜底 GiveAllItems）。
--   装备已经由上面的 GM:PlayerLoadout -> PLAYER:Loadout 发过了，所以这里
--   明确返回 false —— 对 C++ 的 RETURN_LUA_NONE() 来说就是“Lua 处理完了，
--   别再兜底”，否则会发第二套武器。
-------------------------------------------------------------------------------
function GM:GiveDefaultItems( pl )
	return false
end

-------------------------------------------------------------------------------
-- 生命周期
-------------------------------------------------------------------------------
function GM:Initialize()
end

function GM:InitPostEntity()
end

function GM:Think()
	-- GMod 的 GM:Tick 是每 tick；这里用每帧的 Think 顶上。
	if ( self.Tick ~= nil ) then
		self:Tick()
	end
end

function GM:ShutDown()
end

-------------------------------------------------------------------------------
-- 死亡 / 伤害
-------------------------------------------------------------------------------
function GM:DoPlayerDeath( ply, attacker, dmginfo )
	-- HL2SB 没有 ragdoll / 分数绑定，只保留引擎侧的默认处理。
end

function GM:PlayerShouldTakeDamage( ply, attacker )
	return true
end

function GM:EntityTakeDamage( ent, info )
end

function GM:PlayerHurt( ply, attacker, healthleft, healthtaken )
end

function GM:CreateEntityRagdoll( ent, ragdoll )
end

-------------------------------------------------------------------------------
-- 服务器名广播（GMod 每 30 秒写一次全局字符串，供客户端读）
-------------------------------------------------------------------------------
local function HostnameThink()
	SetGlobalString( "ServerName", GetHostName() )
end

-- 加载期语句一旦抛错，luasrc_dofile 会返回非 0，引擎就判定 gamemode 无效、
-- 整条 base 链都不注册（所有 gamemode 都会失去基类）。所以这里兜一层。
if ( _G.timer ~= nil and timer.Create ~= nil ) then
	local ok, err = pcall( timer.Create, "HostnameThink", 30, 0, HostnameThink )
	if ( not ok ) then
		dbg.Warning( "[base] HostnameThink timer failed: " .. tostring( err ) .. "\n" )
	end
end

-------------------------------------------------------------------------------
-- 团队选择界面（客户端在 cl_pickteam.lua 里画）
-------------------------------------------------------------------------------
function GM:ShowTeam( ply )
	if ( not GAMEMODE.TeamBased ) then return end

	local switchDelay = GAMEMODE.SecondsBetweenTeamSwitches or 10
	if ( ply.LastTeamSwitch ~= nil and RealTime() - ply.LastTeamSwitch < switchDelay ) then
		return
	end

	ply.LastTeamSwitch = RealTime()
end

-------------------------------------------------------------------------------
-- 密码校验（非本地玩家加入时调用）
-------------------------------------------------------------------------------
function GM:CheckPassword( steamid, networkid, server_password, password, name )
	if ( server_password ~= nil and server_password ~= "" and server_password ~= password ) then
		return false
	end

	return true
end

-------------------------------------------------------------------------------
-- 载具
-------------------------------------------------------------------------------
function GM:VehicleMove( ply, vehicle, mv )
end

-------------------------------------------------------------------------------
-- 撤销 —— HL2SB 自己就有撤销栈（lua/includes/modules/undo.lua + 引擎侧），
-- 这里的钩子和 GMod 同名，直接接上。
-------------------------------------------------------------------------------
function GM:PreUndo( undo )
	return true
end

function GM:PostUndo( undo, count )
end
