-- Fork launch settings are separate from the original Sandbox rules.
if ( SERVER ) then
local function ApplySandboxLaunchSettings()
    if ( !GAMEMODE or !GAMEMODE.IsSandboxDerived ) then return end
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


    include( "gamemodes/sandbox/gamemode/ammo.lua" )
end
hook.Add( "Initialize", "HL2SB.SandboxLaunchSettings", ApplySandboxLaunchSettings )
end
