--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

include( "shared.lua" )

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

-- GMod sandbox preset loadout (gamemodes/sandbox/gamemode/player_class/player_sandbox.lua).
-- gmod_tool -> weapon_toolgun (HL2SB C++ equivalent).
-- gmod_camera omitted: only a half-copied shared.lua exists, no init.lua, no model.
function GM:GiveDefaultItems( pPlayer )
  pPlayer:RemoveAllAmmo()

  pPlayer:GiveAmmo( 256, "Pistol",     true )
  pPlayer:GiveAmmo( 256, "SMG1",       true )
  pPlayer:GiveAmmo( 5,   "grenade",    true )
  pPlayer:GiveAmmo( 64,  "Buckshot",   true )
  pPlayer:GiveAmmo( 32,  "357",        true )
  pPlayer:GiveAmmo( 32,  "XBowBolt",   true )
  pPlayer:GiveAmmo( 6,   "AR2AltFire", true )
  pPlayer:GiveAmmo( 100, "AR2",        true )

  pPlayer:GiveNamedItem( "weapon_crowbar" )
  pPlayer:GiveNamedItem( "weapon_pistol" )
  pPlayer:GiveNamedItem( "weapon_smg1" )
  pPlayer:GiveNamedItem( "weapon_frag" )
  pPlayer:GiveNamedItem( "weapon_physcannon" )
  pPlayer:GiveNamedItem( "weapon_crossbow" )
  pPlayer:GiveNamedItem( "weapon_shotgun" )
  pPlayer:GiveNamedItem( "weapon_357" )
  pPlayer:GiveNamedItem( "weapon_rpg" )
  pPlayer:GiveNamedItem( "weapon_ar2" )
  pPlayer:GiveNamedItem( "weapon_physgun" )
  pPlayer:GiveNamedItem( "weapon_toolgun" )

  return false
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
