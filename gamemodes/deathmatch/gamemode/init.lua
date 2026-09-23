--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

include( "shared.lua" )
include( "player_class/player_deathmatch.lua" )

-- 引擎的 LUA_BASE_GAMEMODE 是 "deathmatch"（luamanager.h:40），gamemodes/base/
-- 这层从来没有被加载过——里面的通用出生链（GM:PlayerSpawn -> PlayerLoadout
-- -> RunClass）和 player_default 类因此全是死代码（2026-09-24 实锤：
-- [loadout-diag] class=nil、gamemode.get("base")==nil）。在这里 include 进来，
-- GM 函数落进当前 GM 表，deathmatch 作为 base 继续被 sandbox 等继承。
-- ⚠️ 不要写 "../../base/..."：LuaNormalizeDots 会把它归一成
-- "gamemodes/deathmatchbase/..."（实测 2026-09-24）。走 include 的第三条
-- 根路径回退（原样相对 MOD 路径）能直接命中。
include( "gamemodes/base/gamemode/init.lua" )

-- base 层的通用出生链。设类之后走这一个：OnPlayerSpawn -> RunClass("Spawn")
-- -> PlayerLoadout -> PlayerSetModel。sandbox 等子 gamemode 设完自己的类也
-- 要走这个原函数，不能走 deathmatch 的 GM:PlayerSpawn（那会把类改回
-- player_deathmatch）。
local PlayerSpawnChain = GM.PlayerSpawn
-- 暴露给子 gamemode：sandbox 设完 player_sandbox 类后走这个，而不是走
-- deathmatch 的 GM:PlayerSpawn（会把类改回 player_deathmatch）。
GM.PlayerSpawnChain = PlayerSpawnChain

local PLAYER_SOUNDS_CITIZEN = 0
local PLAYER_SOUNDS_COMBINESOLDIER = 1
local PLAYER_SOUNDS_METROPOLICE = 2

function GM:AddLevelDesignerPlacedObject( pEntity )
end

function GM:AllowDamage( pVictim, info )
end

function GM:CanEnterVehicle( pPlayer, pVehicle, nRole )
end

function GM:CanHavePlayerItem( pPlayer, pItem )
  if ( cvar.FindVar( "mp_weaponstay" ):GetInt() > 0 ) then
    if ( pPlayer:Weapon_OwnsThisType( pItem:GetClassname(), pItem:GetSubType() ) ) then
	  return false;
	end
  end
end

function GM:CanPlayerHearPlayer( pListener, pTalker, bProximity )
end

function GM:CheatImpulseCommands( pPlayer, iImpulse )
end

function GM:CheckChatForReadySignal( pPlayer, chatmsg )
end

function GM:CleanUpMap()
end

function GM:ClientConnected( pEntity, pszName, pszAddress, reject, maxrejectlen )
end

function GM:ClientDisconnected( pClient )
end

function GM:FlItemRespawnTime( pItem )
  return cvar.FindVar( "sv_hl2mp_item_respawn_time" ):GetFloat();
end

function GM:FlPlayerFallDamage( pPlayer )
end

function GM:FlPlayerSpawnTime( pPlayer )
end

function GM:FPlayerCanRespawn( pPlayer )
end

function GM:FPlayerCanTakeDamage( pPlayer, pAttacker )
end

function GM:FShouldSwitchWeapon( pPlayer, pWeapon )
end

-- 与 sandbox/base 的桥一致：出生装备唯一入口是 PLAYER:Loadout()
-- （player_class/player_deathmatch.lua），这里绝不能再发一套。
-- 默认武器切换由 Loadout 末尾的 SwitchToDefaultWeapon()（cl_defaultweapon）
-- 承担。return false = 拦住 C++ 的 GiveAllItems 兜底。
function GM:GiveDefaultItems( pPlayer )
	return false
end

-- 出生先把玩家设成 player_deathmatch 类，再走 base 层的通用出生链。
function GM:PlayerSpawn( pPlayer, transition )
	player_manager.SetPlayerClass( pPlayer, "player_deathmatch" )

	if ( PlayerSpawnChain ~= nil ) then
		return PlayerSpawnChain( self, pPlayer, transition )
	end
end
function GM:Host_Say( pPlayer, p, teamonly )
end

function GM:InitHUD( pPlayer )
end

function GM:ItemShouldRespawn( pItem )
end

function GM:LevelInit( strMapName, strMapEntities, strOldLevel, strLandmarkName, loadGame, background )
end

function GM:NetworkIDValidated( strUserName, strNetworkID )
end

function GM:PlayerCanHearChat( pListener, pSpeaker )
end

function GM:PlayerCanPickupObject( pObject, massLimit, sizeLimit )
end

function GM:PlayerDeathSound( info )
end

function GM:PlayerDeathThink( pPlayer )
end

function GM:PlayerEntSelectSpawnPoint( pHL2MPPlayer )
end

function GM:PlayerGotItem( pPlayer, pItem )
end

function GM:PlayerInitialSpawn( pPlayer )
end

function GM:PlayerPickupObject( pHL2MPPlayer, pObject, bLimitMassAndSize )
	return false
end

function GM:PlayerThink( pPlayer )
end

function GM:RemoveLevelDesignerPlacedObject( pEntity )
end

function GM:RestartGame()
end

function GM:ServerActivate( edictCount, clientMax )
end

function GM:ShouldHideServer()
end

function GM:VecItemRespawnSpot( pItem )
end

function GM:VecItemRespawnAngles( pItem )
end

function GM:WeaponShouldRespawn( pWeapon )
end

function GM:Weapon_Equip( pPlayer, pWeapon )
  return false

end
