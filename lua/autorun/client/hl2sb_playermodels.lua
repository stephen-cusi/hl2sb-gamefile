--[[----------------------------------------------------------------------------
    hl2sb_playermodels.lua

    Builds the player model list the GMod way.

    GMod needs no cfg/playermodel/ directory: a playermodel addon calls

        player_manager.AddValidModel( name, model, prettyName, category )
        player_manager.AddValidHands( name, handsModel, skin, body )

    from a lua/autorun file, and the player model selector reads
    player_manager.GetAllPlayerModels() (garrysmod/gamemodes/sandbox/gamemode/
    editor_player.lua).  This file does the same by itself: it walks models/player/
    in every mounted path and registers each .mdl it finds, so adding a playermodel
    is dropping the file in place - there is nothing to write by hand.

    Order:
      1. the engine's own table, hl2sb.GetPlayerModels() - still fed by
         cfg/playermodel/*.cfg when such files exist.  Those are OPTIONAL now: a cfg
         entry only contributes a nicer title and the model's own hands, and it is
         merged instead of being the only way in (their keys, e.g. "gmod_alyx", are
         kept so existing scripts and hl2sb_setmodel-era configs keep working).
      2. the scan - everything under models/player/ that step 1 did not already cover.

    Both end up in player_manager, and AddValidModel forwards to
    hl2sb.AddPlayerModel() -> HL2SB_AddRuntimeModelConfig, which is the table the
    menu, the server's precache and c_baseviewmodel's c_hands lookup read.

    Client only: the arms model is a client entity, and the server accepts any
    models/player/ path by itself (game/shared/hl2sb_model_scan.cpp).

    Dev log: set hl2sb_hud_debug to 1 for a per-source count.
--]]----------------------------------------------------------------------------

if ( _G.player_manager == nil or player_manager.AddValidModel == nil ) then return end

local SCAN_ROOT = "models/player"

-- How deep the walk goes.  GMod playermodel addons nest a model two or three levels
-- down (models/player/<author>/<pack>/<model>.mdl); six is well past that and still
-- bounded, because this runs in an autorun file at map load.
local MAX_DEPTH = 6

local function IsModelFile( name )
	return string.sub( string.lower( name ), -4 ) == ".mdl"
end

--- Models under models/player/ that are NOT playermodels.  GMod's own list never
--- shows them (they are the props, hats and arms a playermodel is built from), but a
--- directory scan finds them: the "items" group it produced was full of hats and the
--- "Other" one of arms (2026-09-17 screenshot).
local NOT_A_PLAYERMODEL = {
	items = true,		-- models/player/items/**  (hats, cosmetics)
	hands = true,		-- models/player/hands/**
	arms = true,
	weapons = true,
	v_models = true,
	props = true,
}

local function IsPlayermodel( path )
	local lower = string.lower( path )
	local base = string.lower( string.GetFileFromFilename( lower ) or "" )
	local dir = string.match( lower, "/player/([^/]+)/" )

	if ( dir ~= nil and NOT_A_PLAYERMODEL[ dir ] ) then return false end
	if ( string.find( base, "arms", 1, true ) ~= nil ) then return false end
	if ( string.find( base, "hands", 1, true ) ~= nil ) then return false end
	if ( string.find( base, "hat", 1, true ) == 1 ) then return false end

	return true
end

--- file.Find( name, "GAME" ) answers ( files, dirs ).  The walk is done by hand instead
--- of with a "**" pattern: Source's FindFirstEx does not have to implement it (the
--- engine's file_Find, public/lua/lfilesystem.cpp:1169, just passes the pattern on).
local function Walk( dir, depth )
	local out = {}

	local files, dirs = file.Find( dir .. "/*", "GAME" )

	for _, name in ipairs( files or {} ) do
		if ( IsModelFile( name ) ) then
			out[ #out + 1 ] = dir .. "/" .. name
		end
	end

	if ( depth > 1 ) then
		for _, name in ipairs( dirs or {} ) do
			local sub = Walk( dir .. "/" .. name, depth - 1 )

			for _, path in ipairs( sub ) do
				out[ #out + 1 ] = path
			end
		end
	end

	return out
end

--- "models/player/daniao/gi_hutao/gi_hutao_player.mdl" ->
---   key "daniao_gi_hutao_gi_hutao_player", category "daniao",
---   title "Gi Hutao Player"
---
--- The category, when the model is one of the stock ones, is GMod's own group name -
--- that is the 4th argument of player_manager.AddValidModel in GMod's playermodel list
--- (Counter-Strike / Half-Life 2 / Half-Life 2 - Citizens / Half-Life 2 - Zombies /
--- the "other" bucket).  A scan only has the path, so the group is derived from it.
local CS_MODELS = {
	arctic = true, guerilla = true, leet = true, phoenix = true, riot = true,
	swat = true, urban = true, gign = true, gsg9 = true, sas = true,
	terror = true, militia = true,
}

local HL2_ZOMBIES = {
	zombie = true, ["zombie_classic"] = true, zombiefast = true, zombine = true,
	skeleton = true, corpse = true, headcrab = true, ["fzombie"] = true,
}

local HL2_PEOPLE = {
	alyx = true, barney = true, breen = true, eli = true, gman = true,
	kleiner = true, mossman = true, odessa = true, father = true, fisher = true,
}

local function StockCategory( path )
	local lower = string.lower( path )
	local base = string.lower( string.GetFileFromFilename( path ) or "" )
	base = string.gsub( base, "%.mdl$", "" )

	if ( string.find( lower, "/group0", 1, true ) ~= nil
		or string.find( base, "male_", 1, true ) == 1
		or string.find( base, "female_", 1, true ) == 1 ) then
		return "Half-Life 2 - Citizens"
	end

	if ( HL2_ZOMBIES[ base ] ~= nil ) then return "Half-Life 2 - Zombies" end
	if ( CS_MODELS[ base ] ~= nil ) then return "Counter-Strike" end
	if ( HL2_PEOPLE[ base ] ~= nil ) then return "Half-Life 2" end

	if ( string.find( base, "combine", 1, true ) ~= nil
		or string.find( base, "police", 1, true ) ~= nil
		or string.find( base, "human", 1, true ) ~= nil ) then
		return "Half-Life 2"
	end

	return nil
end

local function Describe( path )
	local rel = string.sub( path, #SCAN_ROOT + 2 )
	rel = string.gsub( rel, "%.[Mm][Dd][Ll]$", "" )

	local category = StockCategory( path ) or "Other"
	local slash = string.find( rel, "/", 1, true )

	-- a model in its own pack folder keeps the folder as its group (custom addons)
	if ( slash ~= nil and category == "Other" ) then
		category = string.sub( rel, 1, slash - 1 )
	end

	local title = string.NiceName( string.GetFileFromFilename( rel ) or rel )
	local key = string.lower( string.gsub( rel, "[\\/]", "_" ) )

	return key, title, category
end

--- The cfg files (still optional) carry a human readable name in their "name" key:
---     cfg/playermodel/hutao_old.cfg:  "name"  "Hutao Old"
--- while the engine only exposes the config NAME with the list, so it is read here.
local function TitleFromConfig( entry )
	if ( _G.file == nil or file.Read == nil ) then return nil end
	if ( type( entry.file ) ~= "string" or entry.file == "" ) then return nil end

	local ok, text = pcall( file.Read, entry.file, "GAME" )
	if ( not ok or type( text ) ~= "string" ) then return nil end

	local pretty = string.match( text, '"name"%s*"([^"]*)"' )

	if ( pretty ~= nil and pretty ~= "" ) then return pretty end

	return nil
end

local Paths = {}	-- [ lowercase model path ] = true
local Keys = {}		-- [ key ] = true
local nCfg, nScan = 0, 0

--- A model only belongs in the list if the client can actually load it.  The check is
--- on the .mdl alone: right after a map load the .vvd/.vtx of a model that is still
--- coming down the precache/download path are not on disk yet, and asking for them
--- emptied the whole list (2026-09-17).
local function ModelIsComplete( model )
	if ( _G.file == nil or file.Exists == nil ) then return true end

	return file.Exists( model, "GAME" )
end

local function Register( key, model, title, category )
	local lower = string.lower( model )

	if ( Paths[ lower ] or Keys[ key ] ) then return false end
	if ( not ModelIsComplete( model ) ) then return false end

	Paths[ lower ] = true
	Keys[ key ] = true

	player_manager.AddValidModel( key, model, title, category )

	return true
end

-- ---------------------------------------------------------------------------
-- registration (run once at load, then a couple of times again - see below)
-- ---------------------------------------------------------------------------
local function BuildList()

-- ---------------------------------------------------------------------------
-- 1. the engine's own table (cfg/playermodel/*.cfg, when they are there)
-- ---------------------------------------------------------------------------
if ( _G.hl2sb ~= nil and hl2sb.GetPlayerModels ~= nil ) then
	local ok, models = pcall( hl2sb.GetPlayerModels )

	if ( ok and type( models ) == "table" ) then
		for _, entry in ipairs( models ) do
			if ( type( entry ) == "table" and type( entry.name ) == "string"
				and type( entry.model ) == "string" and entry.model ~= "" ) then

				if ( Register( entry.name, entry.model, TitleFromConfig( entry ) or entry.name, "Other" ) ) then
					nCfg = nCfg + 1
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 2. the scan: everything under models/player/ the list does not know yet
-- ---------------------------------------------------------------------------
-- file.Find is the engine binding this whole step rests on; without it (an offline
-- harness, a realm that has no filesystem) the cfg half above is still worth keeping.
local scanned = {}

if ( _G.file ~= nil and file.Find ~= nil ) then
	scanned = Walk( SCAN_ROOT, MAX_DEPTH )
end

for _, path in ipairs( scanned ) do
	if ( not Paths[ string.lower( path ) ] and IsPlayermodel( path ) ) then
		local key, title, category = Describe( path )

		-- the same base name can live in two packs: make the key unique
		local unique, n = key, 1

		while ( Keys[ unique ] ) do
			n = n + 1
			unique = key .. "_" .. n
		end

		if ( Register( unique, path, title, category ) ) then
			nScan = nScan + 1
		end
	end
end

end	-- BuildList

--- The player-model editor caches its window and builds the model list once, so a window
--- opened before the scan found the custom models stayed nearly empty for the session.
--- Announcing each rebuild lets it repopulate (see hl2sb_playermodel_gmod.lua).
local function Announce()
	if ( hook ~= nil and hook.Run ~= nil ) then
		hook.Run( "HL2SB_PlayerModelsBuilt" )
	end
end

-- Run it now (the normal case) and again a few seconds into the map: at autorun time the
-- custom mounts / the models the server is still precaching are not all on disk yet, and
-- the list came out nearly empty right after a map reload (2026-09-17).  Re-running is
-- idempotent - Paths/Keys reject anything already registered.
BuildList()
Announce()

if ( timer ~= nil and timer.Simple ~= nil ) then
	timer.Simple( 5, function() BuildList(); Announce() end )
	timer.Simple( 15, function() BuildList(); Announce() end )
end

if ( GetConVarNumber ~= nil and GetConVarNumber( "hl2sb_hud_debug" ) ~= 0 ) then
	Msg( "[HL2SB] player models: " .. tostring( nCfg ) .. " from cfg, "
		.. tostring( nScan ) .. " from the models/player/ scan\n" )
end

-- ---------------------------------------------------------------------------
-- ARMS COLOUR: deliberately NOT done from Lua (2026-09-17)
-- ---------------------------------------------------------------------------
-- An earlier version of this file polled cl_weaponcolor and pushed it into
-- LocalPlayer():SetPlayerColor() every frame, because the engine's arm tint
-- (game/client/c_viewmodel_attachment.cpp:659) reads HL2SB_GetPlayerColor( userid ).
--
-- That was wrong: that table IS the player colour - Player:SetPlayerColor /
-- GetPlayerColor, and the GMod-compatible source scripts - so overwriting it with the
-- weapon colour made the two mixers fight, and after a respawn the arms stopped
-- rendering at all.
--
-- The correct place is the engine: the arm tint should read cl_weaponcolor (a client
-- convar) itself, and leave the player colour table alone.
