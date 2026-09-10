--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

include( "shared.lua" )

function GM:AddLevelDesignerPlacedObject( pEntity )
  return false
end

-- 战役的出生装备统一由 player_class/player_campaign.lua 决定（故意不发武器）。
local tBaseGamemode = gamemode.get( "base" )



function GM:ItemShouldRespawn( pItem )
  pItem:AddSpawnFlags( 2^30 )
  -- return 6
end

function GM:DebugEntityNames()
  local pEntity = gEntList.FirstEnt()
  while ( pEntity ~= NULL ) do
    if ( pEntity:GetEntityName() ~= "" ) then
      print( tostring( pEntity ) .. " (" .. pEntity:GetEntityName() .. ")" )
    end
    pEntity = gEntList.NextEnt( pEntity )
  end
end

function GM:ResetChangeLevel()
  local pEntity = gEntList.FindEntityByClassname( NULL, "trigger_changelevel" )
  local tTriggers = {}
  while ( pEntity ~= NULL ) do
    local pTrigger = CreateEntityByName( "trigger_changelevel_scripted" );
    if ( pTrigger ~= NULL ) then
      local vecMins = pEntity:WorldAlignMins()
      local vecMaxs = pEntity:WorldAlignMaxs()
      local vecOrigin = vecMaxs - ((vecMaxs - vecMins) / 2)
      pTrigger:SetAbsOrigin( vecOrigin )
      pTrigger.m_vecMins = vecMins
      pTrigger.m_vecMaxs = vecMaxs
      pTrigger.m_szMapName = pEntity.m_szMapName
      pTrigger.m_szLandmarkName = pEntity.m_szLandmarkName

      pTrigger:Spawn()

      -- Huh?
      if ( pTrigger.m_szMapName == gpGlobals.mapname ) then
        pTrigger:Remove()
      end
    end
    table.insert( tTriggers, pEntity )
    pEntity = gEntList.FindEntityByClassname( pEntity, "trigger_changelevel" )
  end

  for i, pTrigger in ipairs( tTriggers ) do
    pTrigger:Remove()
  end
end

function GM:RemoveFallTriggers()
  local pEntity = gEntList.FindEntityByName( NULL, "fall_trigger" )
  local tTriggers = {}
  while ( pEntity ~= NULL ) do
    table.insert( tTriggers, pEntity )
    pEntity = gEntList.FindEntityByClassname( pEntity, "fall_trigger" )
  end

  for i, pTrigger in ipairs( tTriggers ) do
    pTrigger:Remove()
  end
end

function GM:LevelInit( strMapName, strMapEntities, strOldLevel, strLandmarkName, loadGame, background )
  gpGlobals.mapname = strMapName

  -- self:DebugEntityNames()
  self:ResetChangeLevel()
  self:RemoveFallTriggers()

  -- Sometimes an ent will Remove() itself during its precache, so RemoveImmediate won't happen.
  -- This makes sure those ents get cleaned up.
  gEntList.CleanupDeleteList();
end

GM.m_tPickups = {}

function GM:CheckPickups()
  local pEntity = gEntList.FindEntityByName( NULL, "player_spawn_items" )
  local tEntities = {}
  while ( pEntity ~= NULL ) do
    table.insert( self.m_tPickups, pEntity:GetClassname() )
    table.insert( tEntities, pEntity )
    pEntity = gEntList.FindEntityByName( pEntity, "player_spawn_items" )
  end

  for i, pEntity in ipairs( tEntities ) do
    pEntity:Remove()
  end
end

function GM:PlayerGotItem( pPlayer, pItem )
  pItem:Remove()
end

function GM:PlayerInitialSpawn( pPlayer )
  self:CheckPickups()
end

local g_bFirstPlayerSpawned = false

function GM:PlayerSpawn( pPlayer, transition )
  -- 战役出生流程：先定玩家类，再处理地图拾取物，最后交给 base 发装备/设模型
  player_manager.SetPlayerClass( pPlayer, "player_campaign" )

  for _, classname in ipairs( self.m_tPickups ) do
    local pEntity = CreateEntityByName( classname )
    pEntity:SetAbsOrigin( pPlayer:GetAbsOrigin() )
    pEntity:Spawn()
    pEntity:Touch( pPlayer )
  end

  if ( not g_bFirstPlayerSpawned ) then
    g_bFirstPlayerSpawned = true
  else
    -- 第一次出生不放故事板模板，之后的每次重生都要放
    local pEntity = gEntList.FindEntityByName( NULL, "global_newgame_template*" )
    while ( pEntity ~= NULL ) do
      pEntity:AcceptInput( "ForceSpawn", pPlayer, pPlayer, 0 )
      pEntity = gEntList.FindEntityByName( pEntity, "global_newgame_template*" )
    end
  end

  if ( tBaseGamemode ~= nil and tBaseGamemode.PlayerSpawn ~= nil ) then
    return tBaseGamemode.PlayerSpawn( self, pPlayer, transition )
  end
end

function GM:PlayerPickupObject( pHL2MPPlayer, pObject, bLimitMassAndSize )
  return false

end
