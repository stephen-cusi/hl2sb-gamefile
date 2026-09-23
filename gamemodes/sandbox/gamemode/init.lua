--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

include( "shared.lua" )
include( "player_class/player_sandbox.lua" )

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
