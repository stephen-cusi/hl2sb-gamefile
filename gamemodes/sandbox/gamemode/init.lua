--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

include( "shared.lua" )
include( "player_class/player_sandbox.lua" )
-- HL2SB: 生成上限的 gamemode 层（GMod 同位文件、同位 include）。必须有：
-- 生成命令与复制/粘贴都靠 gamemode.Call( "PlayerSpawn.." ) 问这里。
include( "player.lua" )
-- HL2SB (2026-10-15): GMod 同位文件 gamemodes/sandbox/gamemode/commands.lua——
-- 生成命令（gm_spawn / gmod_spawnnpc / gm_spawnsent / gm_giveswep /
-- gm_spawnswep / gm_spawnvehicle）现在在 Lua 里，不再有引擎 C++ 版本。
-- GMod 的 init.lua 顺序是 shared -> commands -> player -> spawnmenu；这里保持
-- 本分叉既有的最小改动：player.lua 之后 include（commands.lua 在函数体内才
-- 用 gamemode.Call，加载顺序不影响语义；它在文件顶 include prop_tools.lua）。
include( "commands.lua" )

-------------------------------------------------------------------------------
-- HL2SB: Sandbox convars aligning with GMod's sandbox settings.
-- Values are read from ServerConfig.vdf and applied so that all start-game
-- settings take effect on the server.
-------------------------------------------------------------------------------
local SBOX_DEFAULTS = {
  { "sbox_weapons", "1", "If enabled, each player will receive default Half-Life 2 weapons on each spawn" },
  { "sbox_godmode", "0", "If enabled, all players will be invincible" },
  { "sbox_noclip", "1", "If enabled, players are able to use noclip" },
  { "sbox_playershurtplayers", "1", "If enabled, players will be able to hurt each other" },
  { "physgun_limited", "0", "Prevent the Physics Gun from picking up certain map entities" },
  { "sbox_maxprops", "200", "Maximum props a single player can create" },
  { "sbox_maxragdolls", "10", "Maximum ragdolls a single player can create" },
  { "sbox_maxvehicles", "4", "Maximum vehicles a single player can create" },
  { "sbox_maxeffects", "200", "Maximum effect props a single player can create" },
  { "sbox_maxballoons", "100", "Maximum balloons a single player can create" },
  { "sbox_maxcameras", "10", "Maximum cameras a single player can create" },
  { "sbox_maxnpcs", "10", "Maximum NPCs a single player can create" },
  { "sbox_maxsents", "100", "Maximum entities a single player can create" },
  { "sbox_maxdynamite", "10", "Maximum dynamites a single player can create" },
  { "sbox_maxlamps", "3", "Maximum lamps a single player can create" },
  { "sbox_maxlights", "5", "Maximum lights a single player can create" },
  { "sbox_maxwheels", "50", "Maximum wheels a single player can create" },
  { "sbox_maxthrusters", "50", "Maximum thrusters a single player can create" },
  { "sbox_maxhoverballs", "50", "Maximum hoverballs a single player can create" },
  { "sbox_maxbuttons", "50", "Maximum buttons a single player can create" },
  { "sbox_maxemitters", "20", "Maximum emitters a single player can create" },
  { "sbox_maxconstraints", "2000", "Maximum non rope-based constraints a single player can create" },
  { "sbox_maxropeconstraints", "1000", "Maximum rope-based constraints a single player can create" },
  { "sbox_bonemanip_npc", "1", "If enabled then manipulating NPC bones will be allowed" },
  { "sbox_bonemanip_player", "0", "If enabled then manipulating Player bones will be allowed" },
  { "sbox_bonemanip_misc", "0", "If enabled then manipulating the bones of other entities will be allowed" },
  { "sbox_persist", "", "Enables persistence mode" },
  { "mp_falldamage", "0", "Realistic fall damage" },
  { "gmod_maxammo", "9999", "Maximum ammo reserves" },
  { "gmod_suit", "0", "Half-Life 2 aux suit power stuff" },
}

local cvFlags = { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED }
for _, def in ipairs( SBOX_DEFAULTS ) do
  local name, defaultVal, helpText = def[ 1 ], def[ 2 ], def[ 3 ]
  if ( GetConVar == nil or GetConVar( name ) == nil ) then
    CreateConVar( name, defaultVal, cvFlags, helpText )
  end
end

local function HL2SB_ApplyStartOptions()
  if ( file == nil or file.Read == nil ) then return end

  local txt = file.Read( "ServerConfig.vdf", "GAME" )
  if ( txt == nil or txt == "" ) then return end

  for k, v in string.gmatch( txt, '"([%w_]+)"%s+"([^"]*)"' ) do
    if ( k ~= "ServerConfig" and k ~= "map" and k ~= "hostname" and k ~= "sv_password" and k ~= "maxplayers" and k ~= "sv_lan" ) then
      local cv = ( GetConVar ~= nil and GetConVar( k ) ) or nil
      if ( cv == nil and CreateConVar ~= nil ) then
        cv = CreateConVar( k, v, cvFlags )
      end
      if ( cv ~= nil and cv.SetString ~= nil ) then
        cv:SetString( v )
      end
    end
  end
end

HL2SB_ApplyStartOptions()

-- HL2SB: chain to shared.lua's GM:Initialize (the mp_falldamage / mp_flashlight
-- server commands).  Gamemode inheritance is resolved before this file's body
-- runs, so redefining the method on the same GM table silently REPLACED it --
-- the shared half never ran again.
local SharedInitialize = GM.Initialize
function GM:Initialize()
  if ( SharedInitialize ~= nil ) then SharedInitialize( self ) end
  HL2SB_ApplyStartOptions()
end

-- Damage funnel: handles global god mode and player vs player damage settings.
function GM:EntityTakeDamage( ent, info )
  if ( ent == nil or not ent:IsPlayer() ) then return end

  if ( cvars.Bool( "sbox_godmode", false ) ) then
    return true
  end

  if ( info ~= nil and info.GetAttacker ~= nil ) then
    local attacker = info:GetAttacker()
    if ( attacker ~= nil and attacker:IsValid() and attacker:IsPlayer() and ent ~= attacker ) then
      if ( not cvars.Bool( "sbox_playershurtplayers", true ) ) then
        return true
      end
    end
  end
end

-- 上限体系（CheckLimit / GetCount / AddCount / LimitHit）在
-- sandbox/gamemode/player_extension.lua —— GMod 同位文件，由 shared.lua
-- include（双 realm）。这里早先内联过一份简化版，已删除：它用的是
-- cvars.Number 的 -1 兜底（查不到 convar 就静默放行）、计数不网络化，
-- 且与 GMod 的语义（默认 0、Count.* 同步、批量刷新）不一致。

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

-- 物理枪提示（GMod sandbox 同位逻辑）。首次抓取的两条提示在 shared.lua 的
-- GM:PhysgunPickup 里入队；这里补冻结/解冻两处：冻结成功后弹"如何解冻"提示并
-- 撤下"右键冻结"提示；解冻提示在按 R 解冻后撤下。
--
-- 基类（base/gamemode/player.lua）已实现冻结本体与解冻通知，必须链式调用。
-- 注意不能在本文件加载期捕获 GM.OnPhysgunFreeze —— 本文件的函数体会在
-- gamemode.register 之前跑完，那一刻 table.inherit 还没把 base 的方法并进
-- GM 表（此刻是 nil）。所以基类一律在调用期经 self.BaseClass 取（inherit
-- 会写上这个字段）。
local function CallBase( gm, name, ... )
  local base = gm.BaseClass
  if ( base == nil and gamemode ~= nil and gamemode.Get ~= nil ) then
    base = gamemode.Get( "base" )
  end
  if ( base ~= nil and base[ name ] ~= nil ) then
    return base[ name ]( gm, ... )
  end
end

function GM:OnPhysgunFreeze( weapon, phys, ent, ply )
  -- 持久化道具不该被冻结（应已冻结）：拦下
  if ( ent ~= nil and ent.GetPersistent ~= nil and ent:GetPersistent() ) then
    local persist = ( GetConVarString ~= nil and GetConVarString( "sbox_persist" ) ) or ""
    if ( string.Trim( persist ) != "" ) then return false end
  end

  CallBase( self, "OnPhysgunFreeze", weapon, phys, ent, ply )

  ply:SendHint( "PhysgunUnfreeze", 0.3 )
  ply:SuppressHint( "PhysgunFreeze" )
end

function GM:OnPhysgunReload( weapon, ply )
  CallBase( self, "OnPhysgunReload", weapon, ply )

  ply:SuppressHint( "PhysgunUnfreeze" )
end

