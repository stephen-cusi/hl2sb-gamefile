--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/shared.lua

    HL2SB 的基础 gamemode —— 对应 GMod 的 gamemodes/base。

    和 GMod 版的差异（都是缺绑定导致的，不是设计选择）：
      - drive.* 整个库 HL2SB 没有，所以 GM:Move / SetupMove / FinishMove /
        StartEntityDriving / EndEntityDriving 只保留 player_manager 那一半。
      - GAMEMODE 全局由引擎在 luasrc_SetGamemode 里设好（等价 GMod 的 GAMEMODE）。
      - DEFINE_BASECLASS 是 GMod 的加载期文本宏，HL2SB 没有，
        子 gamemode 里要写 local BaseClass = baseclass.Get( "base" )。

    这个文件客户端和服务端都会加载。
--------------------------------------------------------------------------]]--

-- 顺序重要：player_default 定义 TauntCamera 和 player_default 类，
-- player_shd 只往引擎 metatable 上挂方法。万一 player_shd 出错，
-- 也不能把 base gamemode 的注册拖死（否则所有 gamemode 都失去基类）。
include( "player_class/player_default.lua" )

local fOk, fErr = pcall( include, "player_shd.lua" )
if ( not fOk ) then
	dbg.Warning( "[base] player_shd.lua failed: " .. tostring( fErr ) .. "\n" )
end

GM.Name      = "Base Gamemode"
GM.Author    = "HL2SB"
GM.Email     = ""
GM.Website   = ""
GM.TeamBased = false

-------------------------------------------------------------------------------
-- GMod 同名钩子（默认空实现，子 gamemode 覆盖）
-------------------------------------------------------------------------------
function GM:KeyPress( ply, key )
end

function GM:KeyRelease( ply, key )
end

function GM:PlayerConnect( name, address )
end

function GM:PropBreak( attacker, prop )
end

function GM:PhysgunPickup( ply, ent )
	-- 不让物理枪抓玩家（GMod 同款默认行为）
	if ( ent ~= nil and ent.IsPlayer ~= nil and ent:IsPlayer() ) then return false end

	return true
end

function GM:PhysgunDrop( ply, ent )
end

function GM:GetGameDescription()
	return self.Name
end

function GM:Saved()
end

function GM:Restored()
end

function GM:EntityRemoved( ent )
end

-------------------------------------------------------------------------------
-- Tick —— GMod 是每 tick 都调；HL2SB 的 "Think" 钩子每帧一次，
-- 语义上够用，所以这里转发过去，让 GMod 脚本里的 GM:Tick 也能跑。
-------------------------------------------------------------------------------
function GM:Tick()
end

function GM:OnEntityCreated( ent )
end

function GM:EntityKeyValue( ent, key, value )
end

-------------------------------------------------------------------------------
-- CreateTeams —— 必须是 shared
-------------------------------------------------------------------------------
function GM:CreateTeams()
	if ( not GAMEMODE.TeamBased ) then return end

	TEAM_BLUE = 1
	team.SetUp( TEAM_BLUE, "Blue Team", Color( 0, 0, 255 ) )

	TEAM_ORANGE = 2
	team.SetUp( TEAM_ORANGE, "Orange Team", Color( 255, 150, 0 ) )

	team.SetSpawnPoint( TEAM_SPECTATOR, "info_player_start" )
end

function GM:ShouldCollide( Ent1, Ent2 )
	return true
end

-------------------------------------------------------------------------------
-- 移动钩子：HL2SB 没有 drive 库，只保留 player_manager 那半
-------------------------------------------------------------------------------
function GM:Move( ply, mv )
	if ( player_manager.RunClass( ply, "Move", mv ) ) then return true end
end

function GM:SetupMove( ply, mv, cmd )
	if ( player_manager.RunClass( ply, "StartMove", mv, cmd ) ) then return true end
end

function GM:FinishMove( ply, mv )
	if ( player_manager.RunClass( ply, "FinishMove", mv ) ) then return true end
end

function GM:PlayerPostThink( ply )
end

function GM:StartEntityDriving( ent, ply )
end

function GM:EndEntityDriving( ent, ply )
end

function GM:PlayerDriveAnimate( ply )
end

function GM:OnReloaded()
end

function GM:PreGamemodeLoaded()
end

function GM:OnGamemodeLoaded()
end

function GM:PostGamemodeLoaded()
end

-------------------------------------------------------------------------------
-- 玩家换武器导致 viewmodel 变化时，转发给玩家类
-------------------------------------------------------------------------------
function GM:OnViewModelChanged( vm, old, new )
	local ply = vm.GetOwner and vm:GetOwner() or nil

	if ( IsValid( ply ) ) then
		player_manager.RunClass( ply, "ViewModelChanged", vm, old, new )
	end
end

-- 非 sandbox 派生的 gamemode 默认关掉属性编辑
function GM:CanProperty( ply, property, ent )
	return false
end

-- 允许 hook 覆盖子弹而不吃掉其它 hook
function GM:EntityFireBullets( ent, bullets )
	return true
end
