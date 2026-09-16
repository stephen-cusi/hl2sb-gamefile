--[[----------------------------------------------------------------------------
	hl2sb_spawnmenu.lua  --  HL2SB's spawn menu, in Lua, on this fork's own Derma
	                        framework (lua/derma + lua/vgui).

	WHAT IT IS
	    A GMod-shaped creation menu: creation tabs across the top, a category tree
	    down the side, an icon grid in the middle and a search box, spawning through
	    the engine's own `ent_create` line.  It replaces the C++ menu
	    (game/client/menu/sm_menu_list.cpp), which is why the data sources are the
	    same ones that menu used:

	        hl2sb.GetSpawnableClasses()        the engine's spawnable classes
	                                           (client class map + the server's
	                                           published SMenuEntityList table) -
	                                           the only data Lua cannot reach;
	        list.Get( "Weapon" / "SpawnableEntities" / "Entities" / "NPC" /
	                  "Vehicles" )             what content registered
	        scripted_ents.GetStored / weapon.get   the entity and SWEP tables
	        language.GetPhrase                     GMod's localization
	        file.Exists + surface.DrawSetTextureFile   thumbnails

	THE RULE THAT KEEPS IT ALIVE: NOTHING IS DESTROYED ON A REFRESH
	    Three crashes in a row came from rebuilding panels:
	      * removing the panel whose mouse event was still being dispatched;
	      * 442 Lua panels created in one frame on the Entities tab;
	      * and finally a use-after-free - the client executed at
	        `client.dll+0xBD54C0` = `ConVar::vftable`, i.e. a call through a panel
	        pointer whose memory had already been recycled.
	    So the containers are built ONCE, the sidebar rows and the grid cells are
	    RE-POINTED (never removed), and the fill is spread over frames within a
	    budget - exactly what the C++ menu did with its SMENU_BUILD_BUDGET_MS
	    (sm_menu_list.cpp:3219).  Nothing here calls Remove() after Open().

	GMOD REFERENCES
	    spawnmenu/creationmenu/content/content.lua:85-114
	        local Category = language.GetPhrase( v.Category or
	                                             "#spawnmenu.category.other" )
	        categorised[ Category ] = categorised[ Category ] or {}
	        -> the sidebar is the category tree, one node per resolved Category.
	    contenttypes/weapons.lua:13-17 / npcs.lua:22-27
	        PopulateFromList( "Weapon", tree, { SortName = "PrintName",
	                          CategoryIcon = "icon16/gun.png" } )
	        -> the per-node icon.
	    contenticon.lua:355-393
	        the NPC weapon override (gmod_npcweapon), which this fork's server already
	        applies as `additionalequipment`.
	    spawnmenu.lua:141 / sm_menu_list.cpp:4314-4333
	        the frame's size: screen minus a 10% border, clamped, never under 640x480.
	    sm_menu_list.cpp:643-767
	        the icon search order (vgui/smenu/<class> -> entities/<class> ->
	        vgui/entities/<class> -> the category floor), and the file:line rules for
	        binding a .vmt (no extension) versus a raw image (WITH its extension).

	HOW TO OPEN
	    hl2sb_spawnmenu      (console)   toggle
----------------------------------------------------------------------------]]--

if ( not CLIENT ) then return end

local TAG = "[HL2SB][SpawnMenu] "

-- Stage tracing: the last line printed before a crash IS the step that crashed.
local function Trace( str )
	print( TAG .. str )
end

if ( not vgui or not vgui.Create ) then
	ErrorNoHalt( TAG .. "vgui is not available - the Lua spawn menu cannot load\n" )
	return
end

-- ---------------------------------------------------------------------------
-- 1. the creation tabs.  Same five the C++ menu had; tokens are GMod's.
-- ---------------------------------------------------------------------------
local CATEGORIES = {
	{ id = "weapon",  title = "Weapons",  token = "spawnmenu.category.weapons",  icon = "icon16/gun.png" },
	{ id = "entity",  title = "Entities", token = "spawnmenu.category.entities", icon = "icon16/bricks.png" },
	{ id = "npc",     title = "NPCs",     token = "spawnmenu.category.npcs",     icon = "icon16/monkey.png" },
	{ id = "prop",    title = "Props",    token = "spawnmenu.category.props",    icon = "icon16/bricks.png" },
	{ id = "vehicle", title = "Vehicles", token = "spawnmenu.category.vehicles", icon = "icon16/car.png" },
}

-- Cell geometry: the numbers the C++ menu used (sm_menu_list.cpp:3366-3367).
local CELL_W, CELL_H = 90, 96
local ICON_SIZE = 72
local CELL_GAP = 4

-- GMod's frame sizing (sm_menu_list.cpp:3016 / 4314-4333, from spawnmenu.lua:141).
local BORDER_FRACTION = 0.1
local FRAME_MIN_W, FRAME_MIN_H = 640, 480

local PAD = 6
local TAB_H = 24
local TAB_W = 104
local SIDEBAR_W = 200
local ROW_H = 20

-- how many sidebar rows the window builds up front.  A tab's folder count is in the
-- single digits (the log says 3-4); 32 leaves room for a long spawnlist and costs
-- nothing while the menu is closed, because the rows only exist while it is open.
local ROW_POOL = 32

-- Which tree the SIDEBAR shows.
--
-- false = the tree derived from the content itself: the AUTHOR (the addon or the
-- hand that wrote it) is the folder, and that author's own categories sit under it.
-- That is the "lua author -> lua plugin" shape, and it survives any addon: whatever
-- registers content appears under whoever shipped it.
--
-- true  = the authored settings/spawnlist/*.txt folders.  Those files exist here,
-- but they only name three folders for the whole game, so every addon's content
-- collapsed into "Other" and the per-author structure was lost.  Kept as a switch
-- because the loader is still what supplies folder icons; flip this if the files are
-- ever filled out per addon.
local USE_SPAWNLIST_TREE = false

-- How much of the grid is built per frame.  The C++ menu used 4 ms
-- (SMENU_BUILD_BUDGET_MS); the hard cell cap is what keeps this bounded even when
-- CurTime() stands still (a paused game).
local BUILD_BUDGET_MS = 3.0
local BUILD_MAX_CELLS = 24

-- The most cells one selection will ever put on the grid.  Lua panels are not free
-- here, and the Entities page holds 442 entries: an uncapped "show me everything"
-- selection is exactly what made the menu crawl.  Search reaches anything past it,
-- and the frame's title says how many of how many are shown.
local MAX_CELLS = 200

local MENU_FONT = "DermaDefault"

-- RealTime/SysTime keep advancing while the game is paused; CurTime does not.
local Now = RealTime or SysTime or CurTime

-- ---------------------------------------------------------------------------
-- 2. registry helpers
-- ---------------------------------------------------------------------------
local function Phrase( str )
	if ( str == nil or str == "" ) then return nil end

	if ( str:sub( 1, 1 ) == "#" ) then
		local key = str:sub( 2 )

		if ( language and language.GetPhrase ) then
			local out = language.GetPhrase( str )
			if ( out and out ~= "" and out ~= str ) then return out end
		end

		return key
	end

	return str
end

local LIST_IDS = { "Weapon", "SpawnableEntities", "Entities", "NPC", "Vehicles" }

local function ListTable( id )
	if ( not list or not list.Get ) then return {} end
	return list.Get( id ) or {}
end

local function StoredEntity( class )
	if ( not scripted_ents or not scripted_ents.GetStored ) then return nil end

	local rec = scripted_ents.GetStored( class )
	if ( not rec ) then return nil end

	return rec.t or rec
end

local function Swep( class )
	if ( weapon and weapon.get ) then
		local w = weapon.get( class )
		if ( w ) then return w end
	end

	if ( weapons and weapons.GetStored ) then
		local w = weapons.GetStored( class )
		if ( w ) then return w end
	end

	return nil
end

-- ---------------------------------------------------------------------------
-- 3. entries: one spawnable thing each
-- ---------------------------------------------------------------------------
local entries = {}
local byClass = {}

local function NewEntry( class )
	local e = byClass[ class ]
	if ( e ) then return e end

	e = { class = class, spawn = "ent_create " .. class }
	entries[ #entries + 1 ] = e
	byClass[ class ] = e
	return e
end

local function ApplyListEntry( e, key, data )
	local class = ( type( data ) == "table" and data.Class ) or key
	if ( class == nil or class == "" ) then return end

	e.class = class
	byClass[ class ] = e

	local model = ( type( data ) == "table" ) and data.Model or nil

	if ( model and model ~= "" ) then
		e.model = model
		e.spawn = "ent_create " .. class .. " model " .. model
	else
		e.spawn = "ent_create " .. class
	end

	if ( type( data ) == "table" ) then
		if ( data.PrintName ) then e.name = Phrase( data.PrintName ) end
		if ( data.Category ) then e.category = Phrase( data.Category ) end
		if ( data.IconOverride ) then e.iconOverride = data.IconOverride end
	end

	e.fromLua = true
end

-- GMod shows the seats and the drivable vehicles on the Vehicles page, and so did the
-- C++ menu (SMenu_IsVehicleClass: "prop_vehicle_" OR "vehicle_").  Both prefixes -
-- the second one is what vehicles registered by script use here.
local VEHICLE_NAMES = {
	prop_vehicle_prisoner_pod = "Seat",
	prop_vehicle_jeep         = "Jeep",
	prop_vehicle_airboat      = "Airboat",
	prop_vehicle_jalopy       = "Jalopy",
	prop_vehicle_apc          = "APC",
	prop_vehicle_crane        = "Crane",
	prop_vehicle_choreo_generic = "Choreo Vehicle",
}

local function Classify( class )
	if ( class:sub( 1, 7 ) == "weapon_" or class:sub( 1, 5 ) == "gmod_" ) then return "weapon" end
	if ( class:sub( 1, 4 ) == "npc_" ) then return "npc" end

	-- ⚠️ BOTH prefixes, and checked BEFORE "prop_": a vehicle is a prop by name, so
	-- with only the prop test it would be filed under Props and the Vehicles page
	-- would be left with nothing to show.
	if ( class:sub( 1, 13 ) == "prop_vehicle_" or class:sub( 1, 12 ) == "prop_vehicle"
		or class:sub( 1, 8 ) == "vehicle_" ) then return "vehicle" end
	if ( class:sub( 1, 5 ) == "prop_" or class:sub( 1, 5 ) == "func_" ) then return "prop" end

	local stored = StoredEntity( class )
	if ( stored and ( stored.Type == "nextbot" or stored.Base == "base_nextbot" ) ) then return "npc" end

	return "entity"
end

local function DisplayName( e )
	if ( e.name and e.name ~= "" ) then return e.name end

	local w = Swep( e.class )
	if ( w and w.PrintName and w.PrintName ~= "" ) then return Phrase( w.PrintName ) end

	local stored = StoredEntity( e.class )
	if ( stored and stored.PrintName and stored.PrintName ~= "" ) then return Phrase( stored.PrintName ) end

	-- the game's own vehicles have no PrintName anywhere, and a page of
	-- "prop_vehicle_prisoner_pod" is a page nobody recognises - GMod calls them Seat,
	-- Jeep, Airboat...
	if ( VEHICLE_NAMES[ e.class ] ) then return VEHICLE_NAMES[ e.class ] end

	return e.class
end

local function BucketOf( e )
	if ( e.bucket ) then return e.bucket end

	local cat = e.category

	if ( not cat ) then
		local w = Swep( e.class )
		if ( w ) then cat = w.Category end
	end

	if ( not cat ) then
		local stored = StoredEntity( e.class )
		if ( stored ) then cat = stored.Category end
	end

	-- The stock weapons are the ENGINE's: no Lua SWEP table, so no Category.  GMod
	-- files content under the game it came from, and the C++ menu had exactly this
	-- bucket (sm_menu_list.cpp:181 SMENU_SRC_HL2 = "Half-Life 2").
	if ( not cat and e.cat == "weapon" and not Swep( e.class ) ) then
		e.bucket = "Half-Life 2"
		return e.bucket
	end

	e.bucket = Phrase( cat ) or "Other"
	return e.bucket
end

--[[
	GMod's spawnmenu groups its sidebar by WHERE content came from and then by the
	item's own Category.  Every part of that is declared by the content itself:

		SWEP.Author     "robotboy655, MaxOfS2D, code_gs"   lua/weapons/weapon_medkit
		ENT.Author      "Shaklin"                          addons/scp096/.../shared.lua
		SWEP.Category   "Robotboy655's Weapons"            addons/nyangun/...
		ENT.Category    "#spawnmenu.category.fun_games"    lua/entities/sent_ball.lua

	and scripted_ents.GetStored answers that very table
	(lua/includes/modules/scripted_ents.lua:42 returns `t`), so the tree needs no
	engine help.  Engine content declares neither - it is the game's own, and this
	fork's base game is Half-Life 2 (the C++ menu had the same bucket,
	sm_menu_list.cpp:181 SMENU_SRC_HL2).
]]--
local function SourceOf( e )
	if ( e.source ) then return e.source end

	local t = Swep( e.class ) or StoredEntity( e.class )
	local author = t and t.Author

	if ( author and author ~= "" ) then
		e.source = author
	elseif ( t ) then
		e.source = "Lua"
	else
		e.source = "Half-Life 2"
	end

	return e.source
end

-- ---------------------------------------------------------------------------
-- GMod's own spawnlist: settings/spawnlist/*.txt, read by the module this fork
-- already ships (lua/includes/modules/spawnmenu.lua:240 PopulateFromEngineTextFiles
-- -> gmod_compatibility/sh_init.lua:1780 spawnmenu.PopulateFromTextFiles, which
-- loads every settings/spawnlist/*.txt as KeyValues and hands over
-- name / contents / icon / id / parentid).
--
-- This fork had no data for it, so the files are authored for it now (see
-- settings/spawnlist/*.txt): one file per folder, `contents` a space-separated list
-- of entity CLASS NAMES, id/parentid giving the tree.  When they are present this is
-- the sidebar, exactly as in GMod; when they are not, the menu falls back to the
-- tree derived from the content's own Author/Category.
-- ---------------------------------------------------------------------------
local propNodes = nil

-- Which creation tab a file's contents belong to.  GMod's spawnlist KVs carry a
-- "type" (1 props, 2 weapons, 3 npcs, 4 entities, 5 vehicles); the files this game
-- ships do not, so the page comes from the FILE NAME, which is how they were named
-- (hl2sb_weapons_hl2.txt, hl2sb_npcs_addons.txt, ...).  A file that does not say
-- falls back to NodeTab below - i.e. whichever tab most of its classes sit on.
local TAB_FROM_FILENAME = {
	weapon = "weapon", weapons = "weapon",
	npc = "npc", npcs = "npc",
	prop = "prop", props = "prop",
	vehicle = "vehicle", vehicles = "vehicle",
	entity = "entity", entities = "entity",
}

local function SpawnlistTab( filename )
	local lower = filename:lower()

	for word, tab in pairs( TAB_FROM_FILENAME ) do
		if ( lower:find( word, 1, true ) ) then return tab end
	end

	-- nil on purpose: NodeTab is declared further down, so this function cannot see
	-- it (a `local function` below is a different local, not the same one).  The
	-- callers write ( node.tab or NodeTab( node ) ), and they run after both exist.
	return nil
end

--- One spawnlist file -> a list of field tables.  A file is one or more blocks of
---     "spawnlist" { "name" "Half-Life 2" "icon" "icon16/gun.png" "id" "10"
---                   "parentid" "0" "contents" "class class class" }
--- which is all the structure they have.  %b{} takes a block and the quoted pairs
--- inside it are the fields; comments live outside the braces, so they cannot be
--- mistaken for one.
local function ParseSpawnlistFile( text )
	local blocks = {}

	for block in tostring( text or "" ):gmatch( "%b{}" ) do
		local fields = {}

		for key, value in block:gmatch( '"([%w_]+)"%s+"([^"]*)"' ) do
			fields[ key:lower() ] = value
		end

		if ( fields.name or fields.contents ) then
			blocks[ #blocks + 1 ] = fields
		end
	end

	return blocks
end

local function LoadSpawnlists()
	if ( propNodes ) then return propNodes end

	propNodes = {}

	-- ⚠️ The files are read HERE, not through lua/includes/modules/spawnmenu.lua.
	-- That module is not loaded yet when this autorun file runs: the trace said
	-- "spawnlist=false", because the `spawnmenu` global was nil and the loader
	-- returned an empty table - so the sidebar fell back to the tree derived from
	-- each item's Author/Category, which is where the repeated rows came from.
	--
	-- ⚠️ NOT through KeyValues: in this realm `KeyValues` is a FUNCTION, not the
	-- library table - it is the luaopen_ entry (game/shared/lua/lsrcinit.cpp:136)
	-- and the library itself is opened on another lua_State (luamanager.cpp:320),
	-- so `KeyValues.Create` dies with "attempt to index a function value".  The
	-- files are plain text, so they are read with file.Read and parsed here.
	if ( not ( file and file.Find and file.Read ) ) then
		Trace( "spawnlist: file library unavailable" )
		return propNodes
	end

	local files = file.Find( "settings/spawnlist/*.txt", "GAME" ) or {}

	for _, filename in ipairs( files ) do
		local blocks = nil
		local ok, err = pcall( function()
			blocks = ParseSpawnlistFile( file.Read( "settings/spawnlist/" .. filename, "GAME" ) )
		end )

		if ( not ok or type( blocks ) ~= "table" ) then
			Trace( "spawnlist: cannot read " .. filename .. " (" .. tostring( err ) .. ")" )
		else
			for _, parsed in ipairs( blocks ) do
				local classes = {}

				for c in tostring( parsed.contents or "" ):gmatch( "%S+" ) do
					classes[ #classes + 1 ] = c
				end

				local node = {
					file = filename,
					name = parsed.name or filename,
					icon = parsed.icon,
					id = tonumber( parsed.id ) or 0,
					parent = tonumber( parsed.parentid ) or 0,
					contents = classes,
				}

				node.tab = SpawnlistTab( filename )

				propNodes[ #propNodes + 1 ] = node
			end
		end
	end

	-- sources first (parent 0), then by id, then by name - GMod's own order
	table.sort( propNodes, function( a, b )
		if ( ( a.parent == 0 ) ~= ( b.parent == 0 ) ) then return a.parent == 0 end
		if ( a.id ~= b.id ) then return a.id < b.id end
		return a.name < b.name
	end )

	Trace( string.format( "spawnlist: %d files -> %d nodes", #files, #propNodes ) )

	return propNodes
end

--- Every class a node covers - its own contents plus every child's, because
--- selecting a folder in GMod shows the whole folder.
local function NodeClasses( node )
	if ( node.m_tClasses ) then return node.m_tClasses end

	local set = {}
	node.m_tClasses = set

	for _, c in ipairs( node.contents or {} ) do
		set[ c ] = true
	end

	for _, child in ipairs( propNodes ) do
		if ( child.parent == node.id ) then
			for c in pairs( NodeClasses( child ) ) do
				set[ c ] = true
			end
		end
	end

	return set
end

--- Which creation tab a spawnlist node belongs to: the tab most of its classes are
--- in.  A folder is therefore offered on the Weapons page or the NPCs page, not on
--- both, and a stale selection cannot empty another page's grid.
local function NodeTab( node )
	local counts = {}
	local best, bestN = nil, 0

	for c in pairs( NodeClasses( node ) ) do
		local e = byClass[ c ]

		if ( e and e.cat ) then
			counts[ e.cat ] = ( counts[ e.cat ] or 0 ) + 1
		end
	end

	for cat, n in pairs( counts ) do
		if ( n > bestN ) then
			best, bestN = cat, n
		end
	end

	return best
end

--- Port of the C++ menu's SMenu_IsHiddenClass
--- (game/client/menu/sm_menu_list.cpp:225-240 in HEAD).  Those prefixes are engine
--- plumbing, never content: with them in, the Entities page held 442 entries of
--- env_* / game_* / filter_* / logic_* with no icons at all.
local HIDDEN_PREFIXES = {
	"_", "base", "ai_", "logic_", "math_", "path_", "filter_", "func_",
	"trigger_", "info_", "point_", "env_", "phys_", "game_", "team_",
}

local function IsHiddenClass( class )
	local lower = class:lower()

	for _, prefix in ipairs( HIDDEN_PREFIXES ) do
		if ( lower:sub( 1, #prefix ) == prefix ) then return true end
	end

	return false
end

local function BuildEntries()
	entries = {}
	byClass = {}

	if ( hl2sb and hl2sb.GetSpawnableClasses ) then
		local ok, classes = pcall( hl2sb.GetSpawnableClasses )

		if ( ok and type( classes ) == "table" ) then
			for _, info in ipairs( classes ) do
				local class = info.class

				if ( class and class ~= "" ) then
					local e = NewEntry( class )
					e.cpp = info.cpp
					e.scripted = info.scripted
				end
			end
		else
			print( TAG .. "hl2sb.GetSpawnableClasses() failed: " .. tostring( classes ) )
		end
	end

	for _, id in ipairs( LIST_IDS ) do
		for key, data in pairs( ListTable( id ) ) do
			local class = ( type( data ) == "table" and data.Class ) or key
			if ( class and class ~= "" ) then
				ApplyListEntry( NewEntry( class ), key, data )
			end
		end
	end

	local nLua = 0
	local kept = {}
	local nHidden = 0

	-- ⚠️ Filter the engine's plumbing out of the spawn list, the way the C++ menu
	-- did.  The class map is "every class this client registered", which is not the
	-- same question as "what can a player spawn": without this the Entities page was
	-- 442 entries of env_* / game_* / filter_* / logic_*, none of them usable and
	-- most of them icon-less.
	--
	-- Applied to NON-scripted classes only: a Lua SENT that names itself env_thing is
	-- content, not plumbing.
	for _, e in ipairs( entries ) do
		if ( not e.cat ) then e.cat = Classify( e.class ) end
		if ( not e.name ) then e.name = DisplayName( e ) end

		if ( not ( e.scripted or e.fromLua ) and IsHiddenClass( e.class ) ) then
			nHidden = nHidden + 1
		else
			if ( not e.bucket ) then BucketOf( e ) end
			SourceOf( e )
			if ( e.fromLua ) then nLua = nLua + 1 end
			kept[ #kept + 1 ] = e
		end
	end

	entries = kept

	if ( nHidden > 0 ) then
		Trace( string.format( "hidden classes filtered out: %d", nHidden ) )
	end

	table.sort( entries, function( a, b )
		if ( a.cat ~= b.cat ) then return a.cat < b.cat end
		if ( a.bucket ~= b.bucket ) then return a.bucket < b.bucket end
		return a.name < b.name
	end )

	local n = { weapon = 0, npc = 0, prop = 0, vehicle = 0, entity = 0 }
	for _, e in ipairs( entries ) do
		n[ e.cat ] = ( n[ e.cat ] or 0 ) + 1
	end

	print( string.format( TAG .. "%d entries (%d weapons, %d NPCs, %d entities, %d props, %d vehicles)",
		#entries, n.weapon, n.npc, n.entity, n.prop, n.vehicle ) )

	return #entries
end

-- ---------------------------------------------------------------------------
-- 4. thumbnails
-- ---------------------------------------------------------------------------
local RAW_EXTS = { ".png", ".jpg", ".jpeg", ".tga" }

local function FileOnDisk( path )
	return file and file.Exists and file.Exists( path, "GAME" )
end

--- One candidate base -> the name to BIND, or nil (sm_menu_list.cpp:682-694):
--- a .vmt is bound WITHOUT its extension, a raw image WITH it.
local function ResolveIcon( base )
	if ( FileOnDisk( "materials/" .. base .. ".vmt" ) and FileOnDisk( "materials/" .. base .. ".vtf" ) ) then
		return base
	end

	for _, ext in ipairs( RAW_EXTS ) do
		if ( FileOnDisk( "materials/" .. base .. ext ) ) then
			return base .. ext
		end
	end

	return nil
end

local GENERIC_ICON = {
	weapon  = "vgui/smenu/weapon_default",
	npc     = "icon16/monkey",
	vehicle = "icon16/car",
	prop    = "icon16/box",
	entity  = "icon16/plugin",
}

--- One texture id per material NAME, shared by every cell that draws it: a spawn
--- list is mostly repeats, and DImageButton:SetImage would create an id per call.
local texIds = {}

local function SharedTextureID( path )
	local id = texIds[ path ]

	if ( id == nil ) then
		if ( surface.CreateNewTextureID ) then
			id = surface.CreateNewTextureID()
			surface.DrawSetTextureFile( id, path, 1, true )
		else
			id = false
		end

		texIds[ path ] = id
	end

	return id or nil
end

local iconCache = {}

local function IconPath( e )
	local cached = iconCache[ e.class ]
	if ( cached ~= nil ) then return cached or nil end

	local resolved = nil
	local candidates = {}

	if ( e.iconOverride ) then candidates[ #candidates + 1 ] = e.iconOverride end
	candidates[ #candidates + 1 ] = "entities/" .. e.class
	candidates[ #candidates + 1 ] = "vgui/entities/" .. e.class

	-- ⚠️ No "one generic icon per tab" fallback, and no vgui/smenu/<class>: those
	-- are the C++ menu's 256x128 BANNERS, and stretching a 2:1 picture into a square
	-- tile is what made half the grid look like the same pale slab.  GMod's
	-- thumbnails are square (materials/entities/<class>.png), and an entry that has
	-- none shows its caption on an empty tile - honest, where a wrong picture is not.
	for _, base in ipairs( candidates ) do
		resolved = ResolveIcon( base )
		if ( resolved ) then break end
	end

	iconCache[ e.class ] = resolved or false
	return resolved
end

-- ---------------------------------------------------------------------------
-- 5. spawning
-- ---------------------------------------------------------------------------
local function Spawn( e )
	-- GMod's spawn menu talks to its own commands (sandbox's commands.lua), and so
	-- does this one now:
	--
	--   gm_giveswep      weapons - handed to the player, NOT created in the world.
	--                    A world weapon entity has no owner, and that is exactly what
	--                    killed the client on `ent_create weapon_rpg`.
	--   gm_spawnnpc      npcs - the server applies the configured NPC weapon
	--   gm_spawnvehicle  vehicles
	--   gm_spawn         everything else, with the model when the entry names one
	--
	-- All four register an undo entry server-side, with the name the content uses.
	local line

	if ( e.cat == "weapon" ) then
		line = "gm_giveswep " .. e.class
	elseif ( e.cat == "npc" ) then
		-- the configured NPC weapon rides along as the second argument (see the
		-- server's gm_spawnnpc): no cvar to set, so nothing to rebuild
		local wep = MENU.npcWeapon or ""

		line = "gm_spawnnpc " .. e.class .. ( wep ~= "" and ( " " .. wep ) or "" )
	elseif ( e.cat == "vehicle" ) then
		line = "gm_spawnvehicle " .. e.class
	elseif ( e.model ~= nil and e.model ~= "" ) then
		line = "gm_spawn " .. e.class .. " " .. e.model
	else
		line = "gm_spawn " .. e.class
	end

	Trace( "spawn: " .. tostring( line ) )

	-- engine.ClientCmd is what the C++ menu used (sm_menu_list.cpp:3640/3662
	-- `engine->ClientCmd( szCommand )`), and the Lua binding exists
	-- (public/lua/lcdll_int.cpp:458).  RunConsoleCommand must not lead: this fork
	-- implements it on its own Lua concommand registry, where an ENGINE command like
	-- ent_create does not exist - Run() answers false and stays quiet.
	if ( engine and engine.ClientCmd ) then
		engine.ClientCmd( line )
		return
	end

	if ( RunConsoleCommand ) then
		RunConsoleCommand( line )
	end
end

-- ---------------------------------------------------------------------------
-- 6. the window: built once, only ever re-pointed
-- ---------------------------------------------------------------------------
local MENU = {
	cat = 1,
	node = nil,			-- the selected settings/spawnlist node (GMod's own tree)
	source = "all",		-- fallback tree: the first level (author / the game it came from)
	bucket = "all",		-- fallback tree: the second level (the item's own Category)
	search = "",
	rows = {},			-- [bucket] = row button
	cells = {},			-- the cell pool
	shown = {},			-- what the current filter shows
	next = 1,			-- where the budgeted fill got to
	built = false,
}

--- Every container whose mouse input this menu depends on - the whole chain from the
--- frame down to the layouts that hold the rows and the cells.
---
--- It is a function, re-run after every parenting step, because a panel can be
--- parented onto a scroll panel's canvas long after it was configured, and this
--- engine's hit test is a GATE: vgui2/vgui_controls/Panel.cpp:3343 returns NULL for
--- the whole subtree as soon as one ancestor answers IsMouseInputEnabled() == false.
--- Setting it once at creation therefore was not enough - the trace showed
--- `layout=false` on a layout that had just been created with `true`.
local function OpenMenuMouse()
	-- the tab buttons: the same self-healing rule as the rows and cells.  They are
	-- built once with the window, and the screenshot that came back with an empty tab
	-- strip says a button can be gone (or hidden) by the time the menu is shown again.
	for i, tab in ipairs( MENU.tabs or {} ) do
		if ( tab and tab.SetVisible ) then
			tab:SetVisible( true )
		elseif ( MENU.content and MENU.content.SetSize ) then
			Trace( "tab " .. i .. ": button is gone, rebuilding it" )

			local btn = vgui.Create( "DButton", MENU.content )

			if ( btn and btn.SetSize ) then
				local label = CATEGORIES[ i ] and ( Phrase( CATEGORIES[ i ].token ) or CATEGORIES[ i ].title ) or "?"

				if ( label:find( "spawnmenu%.category%." ) and CATEGORIES[ i ] ) then label = CATEGORIES[ i ].title end

				btn:SetText( label )
				btn:SetPos( PAD + ( i - 1 ) * ( ( MENU.tabW or TAB_W ) + 2 ), 0 )
				btn:SetSize( MENU.tabW or TAB_W, TAB_H - 4 )
				btn.DoClick = function()
					MENU.cat = i
					MENU.node = nil
					MENU.source = "all"
					MENU.bucket = "all"
					MENU.SetDirty()
				end

				MENU.tabs[ i ] = btn
			end
		end
	end

	local chain = { MENU.frame, MENU.content, MENU.sideList, MENU.gridLayout }

	for _, p in ipairs( chain ) do
		if ( p and p.SetMouseInputEnabled ) then p:SetMouseInputEnabled( true ) end
	end

	for _, scroll in ipairs( { MENU.sideScroll, MENU.gridScroll } ) do
		if ( scroll and scroll.SetMouseInputEnabled ) then scroll:SetMouseInputEnabled( true ) end

		if ( scroll and scroll.GetCanvas ) then
			local canvas = scroll:GetCanvas()

			if ( canvas and canvas.SetMouseInputEnabled ) then
				canvas:SetMouseInputEnabled( true )
			end
		end
	end
end

local function Filtered()
	local cat = CATEGORIES[ MENU.cat ].id
	local want = MENU.search:lower()
	local out = {}

	-- A selected spawnlist node wins: it is the explicit category the user picked.
	local nodeSet = MENU.node and NodeClasses( MENU.node ) or nil

	for _, e in ipairs( entries ) do
		local picked

		if ( nodeSet ) then
			-- a spawnlist node is the explicit category the user picked, so it alone
			-- decides what the grid shows
			picked = ( nodeSet[ e.class ] == true )
		else
			picked = ( MENU.source == "all" or e.source == MENU.source )
				and ( MENU.bucket == "all" or e.bucket == MENU.bucket )
		end

		if ( e.cat == cat and picked ) then
			if ( want == "" or e.name:lower():find( want, 1, true ) or e.class:lower():find( want, 1, true ) ) then
				out[ #out + 1 ] = e
			end
		end
	end

	return out
end

-- ---------------------------------------------------------------------------
-- a grid cell.  DImageButton is this fork's own icon+caption button; the Paint is
-- taken over for two reasons, both documented at lua/vgui/DImageButton.lua:
--   1. its SkinHook leaves the BORDER colour set, and a textured rect is modulated
--      by the current colour, so icons came out as empty dark tiles;
--   2. the caption has to be cut to fit a cell.
-- ---------------------------------------------------------------------------
local function CellPaint( self, w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Button", self, w, h )

	-- press / hover feedback: GMod's spawn icons brighten under the cursor and
	-- depress while held.  m_bDepressed and m_bHover are DButton's own fields
	-- (lua/vgui/DButton.lua:23-24), toggled by its OnMousePressed and
	-- OnCursorEntered, so the state costs nothing to read here.
	if ( self.m_bDepressed ) then
		surface.DrawSetColor( 255, 255, 255, 48 )
		surface.DrawFilledRect( 0, 0, w, h )
	elseif ( self.m_bHover ) then
		surface.DrawSetColor( 255, 255, 255, 24 )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	if ( self.m_iTexture ) then
		local isz = self.m_iImageSize or ICON_SIZE
		local x = math.floor( ( w - isz ) / 2 )
		local y = math.max( 2, math.floor( ( h - isz ) / 2 ) - 6 )

		surface.DrawSetColor( 255, 255, 255, 255 )
		surface.DrawSetTexture( self.m_iTexture )
		surface.DrawTexturedRect( x, y, isz, isz )
	end

	-- The caption is read off the panel, NOT through GetText: the DImageButton this
	-- menu gets back carries its own methods but not DButton's (see RowPaint's note),
	-- and calling the missing one threw "attempt to call a nil value (method
	-- 'SetText')" from inside Invalidate - which aborted the fill before a single
	-- cell existed, leaving nothing on screen that could be clicked.
	local text = self.m_strCaption
	if ( text and text ~= "" ) then
		if ( #text > 13 ) then text = text:sub( 1, 12 ) .. "..." end

		local tw, th = derma.GetTextSize( MENU_FONT, text )
		derma.DrawText( MENU_FONT, math.floor( ( w - tw ) / 2 ), h - th - 4,
			text, Color( 228, 228, 228, 255 ) )
	end
end

local function CellMenu( cell, e )
	if ( not e or not DermaMenu ) then return end

	local menu = DermaMenu( nil, cell )
	if ( not menu or not menu.AddOption ) then return end

	-- GMod's per-icon submenu (contenticon.lua:411-419)
	if ( e.cat == "npc" and menu.AddSubMenu ) then
		local sub = menu:AddSubMenu( "NPC weapon" )

		if ( sub ) then
			sub:AddOption( "Default weapon", function()
				MENU.npcWeapon = ""
				if ( RunConsoleCommand ) then RunConsoleCommand( "gmod_npcweapon", "" ) end
			end )

			sub:AddOption( "No weapon", function()
				MENU.npcWeapon = "none"
				if ( RunConsoleCommand ) then RunConsoleCommand( "gmod_npcweapon", "none" ) end
			end )

			for _, w in ipairs( entries ) do
				if ( w.cat == "weapon" ) then
					sub:AddOption( w.name, function()
						MENU.npcWeapon = w.class
						if ( RunConsoleCommand ) then RunConsoleCommand( "gmod_npcweapon", w.class ) end
					end )
				end
			end
		end
	end

	menu:AddOption( "Spawn", function() Spawn( e ) end )
	menu:AddOption( "Copy class name", function()
		if ( SetClipboardText ) then SetClipboardText( e.class ) end
	end )
end

-- ---------------------------------------------------------------------------
-- one sidebar row: a DButton with the category icon drawn by its own Paint.
--
-- ⚠️ These were DImageButton rows until one answered
--     "attempt to call a nil value (method 'SetText')"
-- while its SetImageSize (a DImageButton-only method) worked - i.e. the instance
-- carried the derived control's own methods but not the base's.  A DButton is one
-- step from DPanel, it is what every other button in this menu is, and the icon is
-- just a texture id, so the row no longer depends on the DImageButton class at all.
--
-- The Paint resets the draw colour before the texture for the same reason CellPaint
-- does: the skin's PaintButton leaves the BORDER colour set, and a textured rect is
-- modulated by it.
-- ---------------------------------------------------------------------------
local function RowPaint( self, w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Button", self, w, h )

	-- selected / pressed / hovered: GMod tints the folder that is open, and a row
	-- answers the cursor the same way a spawn icon does
	if ( self.m_bSelected ) then
		surface.DrawSetColor( 68, 112, 176, 110 )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	if ( self.m_bDepressed ) then
		surface.DrawSetColor( 255, 255, 255, 40 )
		surface.DrawFilledRect( 0, 0, w, h )
	elseif ( self.m_bHover ) then
		surface.DrawSetColor( 255, 255, 255, 20 )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	local text = self.m_strCaption or ""
	local th = 0

	if ( text ~= "" ) then
		local _, hText = derma.GetTextSize( MENU_FONT, text )
		th = hText
	end

	surface.DrawSetColor( 255, 255, 255, 255 )

	-- a source node carries the category icon; its Category children are drawn
	-- dimmer and without one, which is what makes the two levels read as a tree
	if ( self.m_bSourceRow and self.m_iTexture ) then
		surface.DrawSetTexture( self.m_iTexture )
		surface.DrawTexturedRect( 4, math.floor( ( h - 16 ) / 2 ), 16, 16 )
	end

	if ( text ~= "" ) then
		local col = self.m_bSourceRow and Color( 240, 240, 240, 255 ) or Color( 186, 186, 186, 255 )

		-- a child row steps in under its source.  Without the step the tree reads as
		-- one flat list, and the same name under two sources looks like a duplicate.
		local indent = self.m_bSourceRow and 24 or 38

		derma.DrawText( MENU_FONT, indent, math.floor( ( h - th ) / 2 ), text, col )
	end
end

local function MakeCell( parent )
	-- ⚠️ A DButton, NOT a DImageButton.  The DImageButton this fork hands back
	-- carries the derived control's own methods but NOT DButton's - SetText and
	-- GetText were missing on it (see RowPaint), and OnMousePressed lives in that
	-- same base class (lua/vgui/DButton.lua:53), so a DImageButton cell is
	-- unreachable by the cursor no matter how the mouse is routed: the clicks the
	-- log recorded were always row clicks.  The icon is a texture id drawn by
	-- CellPaint, so nothing about the cell needs the DImageButton class.
	local cell = vgui.Create( "DButton", parent )

	-- A panel that comes back without its engine class cannot be sized, positioned
	-- or clicked; saying so beats letting it take the fill down (see BuildWindow).
	if ( not cell or not cell.SetSize ) then
		Trace( "MakeCell: the engine answered a panel without SetSize" )
		return cell
	end

	cell:SetSize( CELL_W, CELL_H )
	cell.m_strCaption = ""
	cell.m_iImageSize = ICON_SIZE

	-- One-shot API probe on the first cell, out loud in the log: whether a cell can be
	-- CLICKED is the exact question this menu keeps failing, and the answer is a
	-- property of the panel the engine handed back, not of the code that stores it.
	if ( not MENU.m_bCellProbed ) then
		MENU.m_bCellProbed = true

		Trace( string.format( "cell probe: SetSize=%s OnMousePressed=%s OnMouseReleased=%s DoClick=%s",
			tostring( cell.SetSize ~= nil ), tostring( cell.OnMousePressed ~= nil ),
			tostring( cell.OnMouseReleased ~= nil ), tostring( cell.DoClick ~= nil ) ) )
	end
	cell.Paint = CellPaint

	cell.DoClick = function( self )
		Trace( "left click: " .. tostring( self.m_tEntry and self.m_tEntry.class ) )
		if ( self.m_tEntry ) then Spawn( self.m_tEntry ) end
	end

	cell.DoRightClick = function( self )
		Trace( "right click: " .. tostring( self.m_tEntry and self.m_tEntry.class ) )
		CellMenu( self, self.m_tEntry )
	end

	return cell
end

--- Re-point a cell at an entry.  No removal, no creation - that is the whole point.
local function PointCell( cell, e )
	if ( not cell ) then return end

	cell.m_tEntry = e

	if ( not cell.SetVisible ) then return end

	if ( not e ) then
		cell:SetVisible( false )
		return
	end

	cell.m_strCaption = e.name

	local path = IconPath( e )

	if ( path ) then
		cell.m_strImage = path
		cell.m_iTexture = SharedTextureID( path )
	else
		cell.m_strImage = ""
		cell.m_iTexture = nil
	end

	cell:SetVisible( true )
end

-- ---------------------------------------------------------------------------
-- 7. the fill.  The filter is applied at once (it is a loop over a few hundred
--    entries); the cells are then pointed at their entries over as many frames as
--    the budget needs, which is what keeps a 442-entry tab from arriving in one go.
-- ---------------------------------------------------------------------------
local FillStep

--- A click only RECORDS the new selection; the rebuild happens on the frame's next
--- OnThink (see BuildWindow's OnThink for why it must not happen inside the click).
MENU.SetDirty = function()
	MENU.m_bDirty = true
end

MENU.Invalidate = function()
	MENU.shown = Filtered()
	MENU.next = 1
	MENU.m_bFilling = true

	Trace( string.format( "fill: tab=%s bucket=%s search='%s' -> %d entries",
		CATEGORIES[ MENU.cat ].id, tostring( MENU.bucket ), MENU.search, #MENU.shown ) )

	-- Cells left over from a wider filter are hidden first, so nothing keeps showing
	-- an entry the new filter does not have; the fill reveals them again as it points
	-- them.  Hidden, never removed - see the header.
	for i = 1, #MENU.cells do
		local cell = MENU.cells[ i ]

		if ( cell and cell.SetVisible ) then cell:SetVisible( false ) end
	end

	-- cheap, and it is the one thing that silently makes the whole page dead
	OpenMenuMouse()

	-- the sidebar.  GMod's own tree when settings/spawnlist has data (the authored
	-- folders), otherwise the tree derived from the content's Author/Category.
	--
	-- ⚠️ There is deliberately NO global "All" node.  GMod's spawnmenu never offers
	-- one - you always pick a folder - and an "All" here meant "build 442 cells for
	-- the Entities page in one selection", which is what made the menu crawl and then
	-- come apart.  A selection therefore always exists.
	local catID = CATEGORIES[ MENU.cat ].id
	local tree = {}
	local props = LoadSpawnlists()
	local usingProps = false

	if ( USE_SPAWNLIST_TREE and #props > 0 ) then
		for _, node in ipairs( props ) do
			if ( node.parent == 0 and ( node.tab or NodeTab( node ) ) == catID ) then
				usingProps = true
				tree[ #tree + 1 ] = { node = node, text = node.name, sourceRow = true, icon = node.icon }

				for _, child in ipairs( props ) do
					if ( child.parent == node.id ) then
						tree[ #tree + 1 ] = { node = child, text = child.name, icon = child.icon }
					end
				end
			end
		end
	end

	if ( usingProps ) then
		-- One folder for everything the files do not name.  Nothing may become
		-- unreachable just because a spawnlist did not list it, and the count in the
		-- name says how much the page actually holds.
		local listed, leftovers = {}, {}

		for _, node in ipairs( props ) do
			if ( ( node.tab or NodeTab( node ) ) == catID ) then
				for c in pairs( NodeClasses( node ) ) do
					listed[ c ] = true
				end
			end
		end

		for _, e in ipairs( entries ) do
			if ( e.cat == catID and not listed[ e.class ] ) then
				leftovers[ #leftovers + 1 ] = e.class
			end
		end

		if ( #leftovers > 0 ) then
			local other = {
				name = string.format( "Other (%d)", #leftovers ),
				id = 90,
				parent = 0,
				contents = leftovers,
			}

			props[ #props + 1 ] = other
			tree[ #tree + 1 ] = { node = other, text = other.name, sourceRow = true }
		end
	end

	if ( not usingProps ) then
		local bySource, sourceNames = {}, {}

		for _, e in ipairs( entries ) do
			if ( e.cat == catID ) then
				local src = SourceOf( e )
				local node = bySource[ src ]

				if ( not node ) then
					node = { cats = {}, seen = {} }
					bySource[ src ] = node
					sourceNames[ #sourceNames + 1 ] = src
				end

				if ( not node.seen[ e.bucket ] ) then
					node.seen[ e.bucket ] = true
					node.cats[ #node.cats + 1 ] = e.bucket
				end
			end
		end

		table.sort( sourceNames )

		for _, src in ipairs( sourceNames ) do
			local node = bySource[ src ]

			-- ⚠️ No rows that read as duplicates of each other:
			--   * a category named exactly like its own source ("Half-Life 2" under
			--     "Half-Life 2") is the same word twice - the source row already
			--     selects everything in it;
			--   * a lone "Other" is redundant for the same reason: with nothing else
			--     in the source, the source row and "Other" are the same set.
			local cats = {}

			for _, c in ipairs( node.cats ) do
				if ( c ~= src and not ( c == "Other" and #node.cats == 1 ) ) then
					cats[ #cats + 1 ] = c
				end
			end

			table.sort( cats )

			tree[ #tree + 1 ] = { source = src, bucket = "all", text = src, sourceRow = true }

			for _, c in ipairs( cats ) do
				tree[ #tree + 1 ] = { source = src, bucket = c, text = c }
			end
		end
	end

	-- a selection always exists: GMod shows a folder, never "everything"
	local haveSelection = false

	for _, row in ipairs( tree ) do
		if ( row.node ~= nil and row.node == MENU.node ) then
			haveSelection = true
			break
		end

		if ( row.node == nil and row.source == MENU.source and row.bucket == MENU.bucket ) then
			haveSelection = true
			break
		end
	end

	if ( not haveSelection ) then
		local pick = tree[ 1 ]

		-- prefer a folder that actually has classes behind it
		for _, row in ipairs( tree ) do
			if ( row.node and #( row.node.contents or {} ) > 0 ) then
				pick = row
				break
			end
		end

		if ( pick ) then
			-- ⚠️ Deliberately NOT selecting it.  The first source in the tree is the
			-- alphabetically first author, which on this game is one whose folder holds
			-- a single weapon - so opening the menu on a 32-weapon page showed ONE cell
			-- and looked like the menu was losing content.  A tab opens on everything it
			-- has; a folder row narrows it from there.
			Trace( string.format( "sidebar: default selection would be '%s' - left on All", tostring( pick.text ) ) )
		end
	end

	local rowIcon = ResolveIcon( GENERIC_ICON[ catID ] or "icon16/plugin" )
	local rowW = MENU.sideList:GetWide()

	for i, node in ipairs( tree ) do
		-- re-point only, never create: the pool was built with the window (see
		-- BuildWindow for what creating a panel here costs)
		local row = MENU.rows[ i ]

		-- ⚠️ Self-healing pool.  A pooled panel can be GONE by the time the next
		-- rebuild runs: the log showed every row answering "panel without SetSize",
		-- i.e. dead handles, and the sidebar then froze on whatever folder had been
		-- selected - the page could not be changed again, and the room it left behind
		-- is why the menu looked emptier with every open.  Whatever took the panels,
		-- the answer is the same: build a new one here, in the rebuild (which never
		-- runs inside a click - see OnThink).
		if ( not row or not IsValid( row ) or not row.SetSize ) then
			row = vgui.Create( "DButton", MENU.sideList )

			if ( row and row.SetSize and row.Paint ) then
				row.Paint = RowPaint
				row.m_strCaption = ""
				row.m_bSourceRow = false
				row.m_bSelected = false
				row:SetSize( rowW, ROW_H )
				row:SetVisible( false )

				row.DoClick = function( self )
					MENU.node = self.m_tNode
					-- never assign nil: a nil filter is what pinned the page to a
					-- single entry (see Filtered)
					MENU.source = self.m_strSource or "all"
					MENU.bucket = self.m_strBucket or "all"
					MENU.SetDirty()
				end

				MENU.rows[ i ] = row
			else
				Trace( "row " .. i .. ": could not create a row" )
				break
			end
		end

		row.m_tNode = node.node
		row.m_strSource = node.source
		row.m_strBucket = node.bucket
		row.m_bSourceRow = node.sourceRow or false

		-- the caption is a plain field: RowPaint draws it, so a row never has to
		-- depend on a method the instance may or may not carry
		row.m_strCaption = node.text

		-- the current selection, so the row can show it (GMod tints the open folder)
		row.m_bSelected = ( node.node ~= nil and node.node == MENU.node )
			or ( node.node == nil and node.source == MENU.source and node.bucket == MENU.bucket )

		-- a spawnlist node can name its own icon (GMod's `icon` field); otherwise the
		-- tabs' own icon stands in for a folder header
		local icon = node.icon and ResolveIcon( node.icon )
		if ( not icon and node.sourceRow ) then icon = rowIcon end

		row.m_iTexture = icon and SharedTextureID( icon ) or nil

		-- guarded: a row that is not what it claims must not take the whole fill
		-- down with it, or the grid keeps the previous page and looks dead
		if ( row.SetSize ) then
			row:SetSize( rowW, ROW_H )
			row:SetVisible( true )
		else
			Trace( "row " .. i .. ": panel without SetSize, skipped" )
		end
	end

	for i = #tree + 1, #MENU.rows do
		local row = MENU.rows[ i ]

		if ( row and row.SetVisible ) then row:SetVisible( false ) end
	end

	Trace( string.format( "sidebar: %d rows (spawnlist=%s)", #tree, tostring( usingProps ) ) )

	-- DListLayout lays the rows out itself (lua/vgui/DListLayout.lua); the height it
	-- reports is what the scroll panel needs to know
	MENU.sideList:SetSize( rowW, math.max( MENU.sideScroll:GetTall(), #tree * ROW_H ) )
	MENU.sideList:InvalidateLayout( true )

	local sideCanvas = MENU.sideScroll:GetCanvas()
	if ( IsValid( sideCanvas ) ) then
		sideCanvas:SetSize( MENU.sideScroll:InnerWidth(), MENU.sideScroll:GetTall() )
	end

	MENU.sideScroll:SetContentHeight( MENU.sideList:GetTall() )

	if ( not MENU.built ) then
		return
	end

	FillStep( true )
end

FillStep = function( bFirst )
	-- The bar's 14px are subtracted unconditionally: InnerWidth() answers 14 more
	-- until the bar has been enabled, and a column count that changes between fills
	-- would re-wrap the whole grid mid-build.
	local sh = MENU.gridScroll:GetTall()
	local contentW = math.max( CELL_W + 2 * PAD, MENU.gridScroll:GetWide() - 14 )
	local cols = math.max( 1, math.floor( ( contentW + CELL_GAP ) / ( CELL_W + CELL_GAP ) ) )

	-- the ceiling one selection gets (MAX_CELLS): the Entities page alone holds 442
	-- entries, and an uncapped selection is what made the menu crawl
	local nShow = math.min( #MENU.shown, MAX_CELLS )

	local t0 = Now and ( Now() * 1000 ) or 0
	local nDone = 0

	while ( MENU.next <= nShow ) do
		local cell = MENU.cells[ MENU.next ]

		-- same self-healing rule as the rows: a pooled cell that died is replaced
		if ( not cell or not IsValid( cell ) or not cell.SetSize ) then
			cell = MakeCell( MENU.gridLayout )
			MENU.cells[ MENU.next ] = cell
		end

		-- a branch rather than a goto: same effect, and it keeps the cell index the
		-- single place that advances
		if ( cell and cell.SetSize ) then
			PointCell( cell, MENU.shown[ MENU.next ] )
			nDone = nDone + 1
		else
			Trace( "cell " .. MENU.next .. ": panel without SetSize, skipped" )
		end

		MENU.next = MENU.next + 1

		if ( nDone >= BUILD_MAX_CELLS ) then break end
		if ( Now and ( ( Now() * 1000 ) - t0 ) >= BUILD_BUDGET_MS ) then break end
	end

	-- anything the new filter does not need is hidden, never removed
	if ( MENU.next > nShow ) then
		for i = nShow + 1, #MENU.cells do
			local cell = MENU.cells[ i ]

			if ( cell and cell.SetVisible ) then cell:SetVisible( false ) end
		end
	end

	-- Positions are set here AS WELL as by DIconLayout.  The layout is asked to
	-- re-layout, but a layout runs on the engine's own schedule, and a cell that has
	-- not been placed yet is a cell that cannot be clicked - which is what "many of
	-- them do not respond" was.
	for i = 1, math.min( MENU.next - 1, nShow ) do
		local cell = MENU.cells[ i ]

		if ( cell and cell.SetPos ) then
			local idx = i - 1
			cell:SetPos( ( idx % cols ) * ( CELL_W + CELL_GAP ),
				math.floor( idx / cols ) * ( CELL_H + CELL_GAP ) )
		end
	end

	local shownN = math.min( MENU.next - 1, nShow )

	-- The height has to match the wrap rule DIconLayout itself uses (border 0, equal
	-- cells), or the estimate disagrees with the layout and the last row gets cut off.
	-- The layout positions the cells; this is only what the scroll range needs.
	cols = math.max( 1, math.floor( ( contentW + CELL_GAP ) / ( CELL_W + CELL_GAP ) ) )

	local rows = math.ceil( shownN / cols )
	local layoutH = rows * CELL_H + math.max( 0, rows - 1 ) * CELL_GAP

	if ( bFirst ) then
		Trace( string.format( "fill: %d of %d cells, %d columns, %d rows (budget %d/frame)",
			shownN, #MENU.shown, cols, rows, BUILD_MAX_CELLS ) )
	end

	MENU.gridLayout:SetSize( contentW, math.max( 1, layoutH ) )
	MENU.gridLayout:InvalidateLayout( true )

	local canvas = MENU.gridScroll:GetCanvas()
	if ( IsValid( canvas ) ) then
		canvas:SetSize( MENU.gridScroll:InnerWidth(), sh )
	end

	MENU.gridScroll:SetContentHeight( MENU.gridLayout:GetTall() )

	if ( MENU.next > nShow ) then
		MENU.m_bFilling = false

		if ( #MENU.shown > MAX_CELLS ) then
			Trace( string.format( "fill: done - showing the first %d of %d; Search reaches the rest",
				MAX_CELLS, #MENU.shown ) )
		else
			Trace( "fill: done" )
		end

		-- the title says what the grid shows, the way GMod's panel names the folder
		-- you are looking at
		if ( IsValid( MENU.frame ) ) then
			local what = MENU.node and MENU.node.name
				or ( MENU.bucket ~= "all" and MENU.bucket )
				or "All"

			MENU.frame:SetTitle( string.format( "Spawn Menu  -  %s  (%d%s)",
				tostring( what ), shownN,
				( #MENU.shown > MAX_CELLS ) and ( "/" .. #MENU.shown ) or "" ) )
		end
	end
end

-- ---------------------------------------------------------------------------
-- 8. build the window once
-- ---------------------------------------------------------------------------
local function BuildWindow()
	local sw, sh = ScrW(), ScrH()

	local marginX = math.floor( ( sw - 1024 ) * BORDER_FRACTION )
	local marginY = math.floor( ( sh - 768 ) * BORDER_FRACTION )

	marginX = math.max( 25, math.min( 256, marginX ) )
	marginY = math.max( 25, math.min( 256, marginY ) )

	if ( sw < 1024 or sh < 768 ) then
		marginX, marginY = 0, 0
	end

	local fw = math.max( FRAME_MIN_W, sw - 2 * marginX )
	local fh = math.max( FRAME_MIN_H, sh - 2 * marginY )

	local frame = vgui.Create( "DFrame" )
	frame:SetTitle( "Spawn Menu" )
	frame:SetSize( fw, fh )
	frame:SetPos( math.floor( ( sw - fw ) / 2 ), math.floor( ( sh - fh ) / 2 ) )
	frame:SetSizable( false )
	-- NOT delete-on-close: the window is hidden, not destroyed (see Open).  With
	-- false, the title bar's close button hides it like GMod's does, and the next open
	-- reuses every panel instead of rebuilding them.
	frame:SetDeleteOnClose( false )
	frame:SetMinimizeButtonVisible( false )
	frame:SetMaximizeButtonVisible( false )
	frame:MakePopup()

	-- ⚠️ MakePopup alone is NOT enough here.  The C++ menu reached the same state
	-- through vgui::Frame::Activate(), which is MakePopup + MoveToFront +
	-- RequestFocus; with MakePopup only, the frame is painted but the cursor never
	-- goes to it - which is the whole of "the menu cannot be clicked" although every
	-- panel on it reports OnMousePressed and DoClick (see the cell probe in the log).
	frame:MoveToFront()
	frame:RequestFocus()

	Trace( string.format( "frame: %dx%d on a %dx%d screen", fw, fh, sw, sh ) )

	local cx, cy, cw, ch = frame:GetClientArea()

	local content = vgui.Create( "DPanel", frame )
	content:SetPos( cx, cy )
	content:SetSize( cw, ch )
	content.Paint = function() end

	-- mouse input is a GATE in this engine, not inherited:
	-- vgui2/vgui_controls/Panel.cpp:3343 - "if it doesn't want mouse input its
	-- children can't get it either" - and DPanel starts mouse-disabled
	-- (lua/vgui/DPanel.lua:Init).  EVERY container in the chain has to open it.
	content:SetMouseInputEnabled( true )

	-- the creation tabs
	local tabW = math.min( TAB_W, math.max( 64, math.floor( ( cw - 280 ) / #CATEGORIES ) ) )

	MENU.tabs = {}
	MENU.tabW = tabW

	for i, cat in ipairs( CATEGORIES ) do
		local label = Phrase( cat.token ) or cat.title
		if ( label:find( "spawnmenu%.category%." ) ) then label = cat.title end

		local btn = vgui.Create( "DButton", content )
		MENU.tabs[ i ] = btn
		btn:SetText( label )
		btn:SetPos( PAD + ( i - 1 ) * ( tabW + 2 ), 0 )
		btn:SetSize( tabW, TAB_H - 4 )
		btn.DoClick = function()
			MENU.cat = i
			MENU.node = nil
			MENU.source = "all"
			MENU.bucket = "all"
			MENU.SetDirty()
		end
	end

	-- No search box: this menu is navigated by its folders, the way GMod's is, and
	-- the box was only ever in the way here (it rebuilt the page on every keystroke
	-- and took a strip of the tab row).  MENU.search stays "" so Filtered() is
	-- unchanged.

	local top = TAB_H + 2
	local bodyH = ch - top - PAD

	-- sidebar: a DScrollPanel holding a DListLayout, which is exactly the shape the
	-- wiki describes ("You can place this inside a DScrollPanel when adding many
	-- panels") and means no row is ever positioned by hand.
	local sideScroll = vgui.Create( "DScrollPanel", content )
	sideScroll:SetPos( PAD, top )
	sideScroll:SetSize( SIDEBAR_W, bodyH )
	sideScroll:SetMouseInputEnabled( true )

	local sideList = vgui.Create( "DListLayout" )
	sideList:SetMouseInputEnabled( true )
	sideScroll:AddItem( sideList )
	sideList:SetSize( sideScroll:InnerWidth(), bodyH )

	if ( IsValid( sideScroll:GetCanvas() ) ) then
		sideScroll:GetCanvas():SetMouseInputEnabled( true )
	end

	-- ⚠️ The sidebar rows are built HERE, once, together with the window - and
	-- Invalidate only ever re-points them.  A panel created later can come back
	-- without its derma class: rows made inside a click had no SetText and no
	-- OnMousePressed, and one made during a rebuild answered the NEXT Invalidate with
	-- "attempt to call a nil value (method 'SetSize')" - which stopped the grid from
	-- being filled at all, so the menu stayed up and answered nothing.  Build time is
	-- the one context known to be good; the tabs just above are made exactly here.
	MENU.rows = {}

	for i = 1, ROW_POOL do
		local row = vgui.Create( "DButton", sideList )
		row.Paint = RowPaint
		row.m_strCaption = ""
		row.m_bSourceRow = false
		row.m_bSelected = false
		row:SetSize( sideScroll:InnerWidth(), ROW_H )
		row:SetVisible( false )

		row.DoClick = function( self )
			MENU.node = self.m_tNode
			MENU.source = self.m_strSource
			MENU.bucket = self.m_strBucket
			MENU.SetDirty()
		end

		MENU.rows[ i ] = row
	end

	-- grid: a DScrollPanel holding a DIconLayout
	local gridX = PAD + SIDEBAR_W + PAD
	local gridW = cw - gridX - PAD

	local gridScroll = vgui.Create( "DScrollPanel", content )
	gridScroll:SetPos( gridX, top )
	gridScroll:SetSize( gridW, bodyH )
	gridScroll:SetMouseInputEnabled( true )

	local gridLayout = vgui.Create( "DIconLayout" )
	gridLayout:SetMouseInputEnabled( true )
	gridLayout:SetSpaceX( CELL_GAP )
	gridLayout:SetSpaceY( CELL_GAP )
	gridLayout:SetBorder( 0 )
	gridScroll:AddItem( gridLayout )
	gridLayout:SetSize( gridScroll:InnerWidth() - 2 * PAD, bodyH )

	if ( IsValid( gridScroll:GetCanvas() ) ) then
		gridScroll:GetCanvas():SetMouseInputEnabled( true )
	end

	-- The queued work lands here, on the frame's per-frame hook.  ⚠️ It is OnThink,
	-- not Think: the scripted panel dispatches its per-frame callback under that name
	-- only (scripted_controls/lPanel.cpp:181-187).
	frame.OnThink = function()
		-- A callback that outlives its window is the crash this menu had: the frame is
		-- only ever hidden now, but the guard costs one call and makes that class of
		-- failure impossible.
		if ( not IsValid( MENU.frame ) ) then return end

		-- ⚠️ The rebuild runs HERE, never inside a click.  A panel created inside a
		-- mouse callback does not come back with its derma class: rows made in a
		-- DoClick had no SetText ("attempt to call a nil value (method 'SetText')"
		-- from Invalidate, which killed the fill) and no OnMousePressed - so they
		-- could not be clicked either way.  Doing the work one frame later, outside
		-- the input dispatch, is what makes them real DButtons.
		if ( MENU.m_bDirty ) then
			MENU.m_bDirty = false

			local ok, err = pcall( MENU.Invalidate )
			if ( not ok ) then Trace( "invalidate failed: " .. tostring( err ) ) end
		end

		if ( MENU.m_bSearchDirty and
			( ( Now and Now() or 0 ) - ( MENU.m_flSearchAt or 0 ) ) > 0.25 ) then
			MENU.m_bSearchDirty = false
			MENU.Invalidate()
			return
		end

		if ( MENU.m_bFilling ) then
			-- same contract as the rebuild above: a single bad cell ends the fill for
			-- this frame, and never for the menu
			local ok, err = pcall( FillStep, false )

			if ( not ok ) then
				MENU.m_bFilling = false
				Trace( "fill failed: " .. tostring( err ) )
			end
		end
	end

	MENU.frame = frame
	MENU.content = content
	MENU.sideScroll = sideScroll
	MENU.sideList = sideList
	MENU.gridScroll = gridScroll
	MENU.gridLayout = gridLayout

	-- ⚠️ Re-assert mouse input on the whole chain AFTER everything is parented.
	-- AddItem re-parents its child onto the scroll panel's canvas, and that drops the
	-- child's mouse input: the trace read
	--     input chain: frame=true popup=true content=true scroll=true layout=false
	-- for a layout that had just been created with SetMouseInputEnabled( true ).
	-- This engine stops the hit test at ANY ancestor that does not want mouse input
	-- (vgui2/vgui_controls/Panel.cpp:3343 - "if it doesn't want mouse input its
	-- children can't get it either"), so that single false was the whole of "the menu
	-- draws but nothing on it can be clicked".
	-- ⚠️ GMod keeps this option in the strip under the tabs: the NPC weapon override
	-- (gmod_npcweapon) - the weapon an NPC spawns with, applied to everything spawned
	-- afterwards.  It used to live only on a single icon's right-click menu, which is
	-- per-icon, easy to miss and impossible to check afterwards.
	--
	-- Built LAST so it draws above the sidebar and the grid (a later child paints on
	-- top), which is what lets the open list cover the page without moving anything.
	MENU.bOptOpen = false

	local OPT_W, OPT_ROWS_H = 190, 180

	local optBtn = vgui.Create( "DButton", content )
	optBtn:SetText( "NPC weapon   +" )
	optBtn:SetPos( PAD, top )
	optBtn:SetSize( OPT_W, 20 )
	optBtn.DoClick = function( self )
		MENU.bOptOpen = not MENU.bOptOpen
		optList:SetVisible( MENU.bOptOpen )
		self:SetText( MENU.bOptOpen and "NPC weapon   -" or "NPC weapon   +" )
	end

	local optList = vgui.Create( "DPanel", content )
	optList:SetPos( PAD, top + 21 )
	optList:SetSize( OPT_W, OPT_ROWS_H )
	optList:SetVisible( false )
	optList:SetMouseInputEnabled( true )
	optList.Paint = function( self, w, h )
		surface.DrawSetColor( 32, 32, 32, 240 )
		surface.DrawFilledRect( 0, 0, w, h )
		surface.DrawSetColor( 90, 90, 90, 255 )
		surface.DrawOutlinedRect( 0, 0, w, h )
	end

	local optScroll = vgui.Create( "DScrollPanel", optList )
	optScroll:SetPos( 2, 2 )
	optScroll:SetSize( OPT_W - 4, OPT_ROWS_H - 4 )
	optScroll:SetMouseInputEnabled( true )

	local optLayout = vgui.Create( "DListLayout" )
	optLayout:SetMouseInputEnabled( true )
	optScroll:AddItem( optLayout )
	optLayout:SetSize( optScroll:InnerWidth() - 2, OPT_ROWS_H - 4 )

	if ( IsValid( optScroll:GetCanvas() ) ) then
		optScroll:GetCanvas():SetMouseInputEnabled( true )
	end

	local function AddWeaponOption( label, value )
		local btn = vgui.Create( "DButton", optLayout )
		btn:SetText( label )
		btn:SetSize( optLayout:GetWide(), 20 )
		btn.DoClick = function()
			-- kept on the MENU and sent with every gm_spawnnpc: this fork binds no
			-- CreateConVar, so there is no gmod_npcweapon cvar to write
			MENU.npcWeapon = value

			if ( RunConsoleCommand ) then RunConsoleCommand( "gmod_npcweapon", value ) end

			Trace( "npc weapon: " .. tostring( value ) )
		end
	end

	-- GMod's own choices, then every weapon this game has (sandbox/spawnmenu: the
	-- override takes any weapon class, and "" is the NPC's default)
	AddWeaponOption( "Default", "" )
	AddWeaponOption( "No weapon", "none" )

	for _, e in ipairs( entries ) do
		if ( e.cat == "weapon" ) then AddWeaponOption( e.name, e.class ) end
	end

	OpenMenuMouse()

	local function MouseOf( p )
		return tostring( p and p.IsMouseInputEnabled and p:IsMouseInputEnabled() )
	end

	Trace( string.format( "input chain: frame=%s popup=%s content=%s side=%s sideCanvas=%s scroll=%s layout=%s canvas=%s",
		MouseOf( frame ), tostring( frame.IsPopup and frame:IsPopup() ),
		MouseOf( content ), MouseOf( sideList ), MouseOf( sideScroll:GetCanvas() ),
		MouseOf( gridScroll ), MouseOf( gridLayout ), MouseOf( gridScroll:GetCanvas() ) ) )

	MENU.built = true
end

local function Open()
	-- One-shot probe: the class registry is worth reading out loud once per session,
	-- because a control that silently is not what it claims is exactly how a row
	-- ended up without SetText.
	if ( not MENU.m_bProbed ) then
		MENU.m_bProbed = true

		local probe = vgui.Create( "DImageButton" )

		if ( probe ) then
			Trace( string.format( "probe: DImageButton registered=%s class=%s SetText=%s SetImageSize=%s SetVisible=%s",
				tostring( vgui.Exists and vgui.Exists( "DImageButton" ) ),
				tostring( probe.ClassName or ( probe.GetClassName and probe:GetClassName() ) ),
				tostring( probe.SetText ~= nil ),
				tostring( probe.SetImageSize ~= nil ),
				tostring( probe.SetVisible ~= nil ) ) )
			probe:Remove()
		else
			Trace( "probe: vgui.Create('DImageButton') answered nil" )
		end
	end

	-- ⚠️ The window is BUILT ONCE and then shown/hidden.  It used to be destroyed
	-- and rebuilt on every open, and that is what crashed the second open: Q is bound
	-- to +smenu / -smenu, so one press is an open AND a close, and the panels were
	-- deleted while the work queued for them (frame.OnThink -> FillStep) and their own
	-- callbacks were still pointing at them - a use-after-free, not a Lua error, hence
	-- the access violation with no Lua traceback.  GMod's spawnmenu is created once
	-- too; hiding is the whole difference.
	if ( IsValid( MENU.frame ) ) then
		-- MakePopup ONCE.  It is what turns the frame into a popup and hands it the
		-- cursor; calling it again on a frame that already is one is not a no-op, and
		-- the pooled rows coming back as dead handles after a reopen is exactly what
		-- re-running the popup setup looks like from the outside.
		if ( not MENU.m_bPopuped ) then
			MENU.m_bPopuped = true
			MENU.frame:MakePopup()
		end

		-- ⚠️ Reset the folder selection on every OPEN.  Keeping it looked like the menu
		-- "changed by itself": spawn one weapon, close, reopen - and the page was still
		-- showing whatever folder had been clicked before, which after a tab change is a
		-- folder that page may not even have.  A tab opens on everything it holds; the
		-- user narrows it from there.
		MENU.node = nil
		MENU.source = "all"
		MENU.bucket = "all"

		MENU.frame:SetVisible( true )
		MENU.frame:MoveToFront()
		MENU.frame:RequestFocus()
		OpenMenuMouse()
		MENU.SetDirty()
		return
	end

	-- the content list: rebuilt on the FIRST open only.  Content can register long
	-- after level init (the C++ menu had a build that ran before the Lua entries
	-- existed - "0 Lua" in its log), but rebuilding it is not a reason to rebuild the
	-- window, so it is refreshed here and through OnLevelChange below.
	if ( ( not MENU.m_bEntries ) or #entries == 0 ) then
		BuildEntries()
		MENU.m_bEntries = true
	end

	MENU.rows = {}
	MENU.cells = {}
	MENU.built = false
	MENU.m_bPopuped = false

	BuildWindow()
	MENU.m_bPopuped = true
	MENU.Invalidate()
end

local function Close()
	-- hide, never delete: see Open.  A hidden frame owns no cursor and paints nothing,
	-- and everything it holds stays valid for the next open.
	if ( IsValid( MENU.frame ) ) then
		MENU.frame:SetVisible( false )
	end

	-- stop anything queued for it: a fill that keeps running against a hidden window
	-- is the same stale-work problem, just slower
	MENU.m_bFilling = false
	MENU.m_bDirty = false
	MENU.m_bSearchDirty = false
end

local function Toggle()
	if ( IsValid( MENU.frame ) and MENU.frame:IsVisible() ) then
		Close()
	else
		Open()
	end
end

if ( concommand and concommand.Add ) then
	concommand.Add( "hl2sb_spawnmenu", function()
		Toggle()
	end, nil, "Open HL2SB's Lua spawn menu (GMod-style)." )

	-- ⚠️ These two used to belong to the C++ menu
	-- (game/client/menu/sm_menu_list.cpp:214/220 set the `sm_menu` convar from
	-- +smenu/-smenu), and cfg/config_hl2sb.cfg binds Q to +smenu.  That menu is
	-- deleted, so this is now the only handler.
	--
	-- Hold to open, release to close - Q's own behaviour, and what the C++ menu did
	-- (game/client/menu/sm_menu_list.cpp:214/220).  This is safe now that Open shows
	-- and Close hides: neither destroys anything, so a press/release pair costs a
	-- SetVisible and nothing else.
	concommand.Add( "+smenu", function()
		Open()
	end, nil, "Open the spawn menu (hold)." )

	concommand.Add( "-smenu", function()
		Close()
	end, nil, "Close the spawn menu (release)." )
end

print( TAG .. "loaded - 'hl2sb_spawnmenu' opens it (Lua/Derma; the C++ menu still owns Q for now)" )
