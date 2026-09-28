--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

include( "shared.lua" )
include( "player_class/player_sandbox.lua" )

-------------------------------------------------------------------------------
-- HL2SB (2026-09-28): GMod 沙盒开关，配合开始游戏界面的侧栏
-- (gameui CreateMultiplayerGameDialog)。名字/默认值/语义对齐 GMod：
--   sbox_weapons  - 出生时是否发放默认 HL2 武器组（player_sandbox.lua:47
--                   的 cvars.Bool 消费；convar 缺失时它恒 true，勾选框将
--                   无效，所以这里必须真正建出来）
--   sbox_godmode  - 全玩家无敌（下面 GM:EntityTakeDamage 门闩消费）
-- 侧栏把玩家的勾选写进 ServerConfig.vdf（gameui 在发 map 命令前落盘），
-- 这里在 convar 建好之后立刻回灌 -- 不走 listenserver.cfg 是因为那份 exec
-- 的时机（gamerules 构造排队）对 Lua 侧 convar 的创建顺序没有保证。
-------------------------------------------------------------------------------
local sbox_weapons = CreateConVar( "sbox_weapons", "1",
  { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE },
  "If enabled, each player will receive default Half-Life 2 weapons on each spawn" )

local sbox_godmode = CreateConVar( "sbox_godmode", "0",
  { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE },
  "If enabled, all players will be invincible" )

local function HL2SB_ApplyStartOptions()
  if ( file == nil or file.Read == nil ) then return end

  local txt = file.Read( "ServerConfig.vdf", "GAME" )
  if ( txt == nil ) then return end

  local weapons = string.match( txt, '"sbox_weapons"%s+"([%d]+)"' )
  local godmode = string.match( txt, '"sbox_godmode"%s+"([%d]+)"' )

  if ( weapons ~= nil ) then
    sbox_weapons:SetInt( tonumber( weapons ) or 1 )
  end
  if ( godmode ~= nil ) then
    sbox_godmode:SetInt( tonumber( godmode ) or 0 )
  end
end

HL2SB_ApplyStartOptions()

-- 全玩家无敌。GMod 的门闩在 GM:PlayerShouldTakeDamage（sandbox init.lua:87），
-- 但分叉的引擎没有派发那个 hook；分叉的统一伤害漏斗是 baseentity.cpp 的
-- GM:EntityTakeDamage（返回 true 整起事件被拦），规则等价落地到这里。
-- 只拦玩家：炸药桶、NPC、世界物件照常可破坏。
function GM:EntityTakeDamage( ent, info )
  if ( ent:IsPlayer() and cvars.Bool( "sbox_godmode", false ) ) then
    return true
  end
end

local tSpawnPointClassnames = {
  "info_player_deathmatch",
  "info_player_combine",
  "info_player_rebel",
  "info_player_terrorist",
  "info_player_counterterrorist",
  "info_player_axis",
  "info_player_allies",
  "info_player_start"
}

function GM:AddLevelDesignerPlacedObject( pEntity )
  return false
end

-- 与 base/gamemode/init.lua 的桥一致：出生装备的唯一入口是 PLAYER:Loadout()，
-- 这里绝不能再发一套（否则每次出生配给跑两遍：先这里发全套，紧接着
-- GM:PlayerSpawn -> PlayerLoadout -> PLAYER:Loadout 又发全套）。
-- return false = 告诉 C++ 的 RETURN_LUA_NONE() "Lua 处理完了，别走 GiveAllItems 兜底"。
function GM:GiveDefaultItems( pPlayer )
  return false
end

-- GMod sandbox 原版就是这一层（sandbox/gamemode/init.lua:39）：出生先把玩家
-- 设成 player_sandbox 类，再走 base 层暴露的通用出生链
-- OnPlayerSpawn -> RunClass("Spawn") -> PlayerLoadout -> PlayerSetModel。
-- 没有这一层 RunClass("Loadout") 落到 player_default，配给就不是沙盒预设了；
-- 也不能链到 deathmatch 的 GM:PlayerSpawn（会把类改回 player_deathmatch）。
function GM:PlayerSpawn( pl, transition )
  player_manager.SetPlayerClass( pl, "player_sandbox" )

  if ( self.PlayerSpawnChain ~= nil ) then
    return self.PlayerSpawnChain( self, pl, transition )
  end
end

function GM:ItemShouldRespawn( pItem )
  pItem:AddSpawnFlags( 2^30 )
  -- return 6
end

function GM:PlayerEntSelectSpawnPoint( pHL2MPPlayer )
  local tSpawnPoints = {}
  local pSpot = NULL
  for _, classname in ipairs( tSpawnPointClassnames ) do
    pSpot = gEntList.FindEntityByClassname( NULL, classname )
    while ( pSpot ~= NULL ) do
      table.insert( tSpawnPoints, pSpot )
      pSpot = gEntList.FindEntityByClassname( pSpot, classname )
    end
  end
  return tSpawnPoints[ math.random( 1, #tSpawnPoints ) ]
end

function GM:PlayerPickupObject( pHL2MPPlayer, pObject, bLimitMassAndSize )
end
