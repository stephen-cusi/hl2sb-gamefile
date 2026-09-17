--[[----------------------------------------------------------------------------
    hl2sb_playermodels.lua

    Feeds the engine's player model list (cfg/playermodel/, read by the C++ through
    hl2sb.GetPlayerModels()) into GMod's player_manager.

    Why this file has to exist: nothing in this fork's Lua ever called
    player_manager.AddValidModel, so player_manager.GetAllPlayerModels() -- which
    GMod's player model selector, DModelSelectMulti, and a lot of addon code read --
    came back empty even though cfg/playermodel was full.  The engine's own list was
    only reachable through the hl2sb.* bindings.

    Mapping:
      key   = the cfg entry's name, which is what `hl2sb_setmodel <name>` takes and
              what HL2SB_GetModelConfigByName() matches (game/shared/hl2sb_model_config.cpp)
      value = the model path, which is what `cl_playermodel` carries in this fork
              (hl2sb_model_commands.cpp:63 writes pConfig->szPlayerModel)

    ⚠️ GMod puts a player_manager *name* in cl_playermodel and translates it on read.
    This fork's server reads cl_playermodel directly as a path
    (game/server/hl2sb_player_model_manager.cpp), so the selector sends the path -
    see the note in lua/game/client/hl2sb_playermodel_gmod.lua.

    Client only: the server's model manager is C++ (HL2SB_ApplyPlayerModel), it does
    not ask Lua for the list.  Add this on the server too if a gamemode ever needs
    player_manager there.
--]]----------------------------------------------------------------------------

if ( _G.hl2sb == nil or hl2sb.GetPlayerModels == nil ) then return end
if ( _G.player_manager == nil or player_manager.AddValidModel == nil ) then return end

local ok, models = pcall( hl2sb.GetPlayerModels )

if ( not ok or type( models ) ~= "table" ) then
	Msg( "[HL2SB] player_manager bridge: hl2sb.GetPlayerModels() failed: "
		.. tostring( models ) .. "\n" )
	return
end

local nAdded = 0

--- The cfg files carry a human readable name in their "name" key, e.g.
---     cfg/playermodel/hutao_old.cfg:  "name"  "Hutao Old"
--- but the engine only exposes the config NAME (hl2sb.GetPlayerModels() -> name =
--- "hutao_old").  GMod's player model grid shows the readable one, and
--- player_manager.AddValidModel already takes it as its third argument, so it is read
--- here.  Entries added from Lua at runtime (HL2SB_RUNTIME_CONFIG_FILE, the GMod addon
--- path) have no cfg file and keep the name.
local function TitleFromConfig( entry )
	if ( _G.file == nil or file.Read == nil ) then return nil end
	if ( type( entry.file ) ~= "string" or entry.file == "" ) then return nil end

	local ok, text = pcall( file.Read, entry.file, "GAME" )
	if ( not ok or type( text ) ~= "string" ) then return nil end

	local pretty = string.match( text, '"name"%s*"([^"]*)"' )
	if ( pretty ~= nil and pretty ~= "" ) then return pretty end

	return nil
end

for _, entry in ipairs( models ) do
	if ( type( entry ) == "table" and type( entry.name ) == "string"
		and type( entry.model ) == "string" and entry.model ~= "" ) then

		player_manager.AddValidModel( entry.name, entry.model, TitleFromConfig( entry ) )
		nAdded = nAdded + 1
	end
end

if ( GetConVarNumber( "hl2sb_hud_debug" ) ~= 0 ) then
	Msg( "[HL2SB] player_manager bridge: " .. tostring( nAdded ) .. " player model(s)\n" )
end
