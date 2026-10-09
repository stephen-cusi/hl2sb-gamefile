--[[---------------------------------------------------------------------------
	HL2SB spawn menu v4 -- a GMod-shaped spawn menu, rewritten from scratch.

	Replaces both older implementations (the 2000-line hl2sb_spawnmenu.lua and
	spawnmenu_gmod.lua v2).  This file is the only spawn menu now.

LAYOUT (GMod's spawnmenu, wiki.facepunch.com/gmod/spawnmenu):
  top row ....... search box | tab buttons (Entities/Weapons/NPCs/Vehicles/
                  Props) | hint label
  left sidebar .. category list (one row per GMod Category -- GMod has NO
                  "All" page, a tab always shows ONE category, and that is
                  also what keeps every page small)
  right ......... the icon grid: SpawnIcon (GMod's 3D model thumbnail,
                  lua/vgui/SpawnIcon.lua) for PROPS, a flat image / text tile
                  for everything else (user rule, 2026-10-07: only the Props
                  page shows 3D model thumbnails)

	CONTENT IS THE REGISTRY, and each tab reads EXACTLY ONE (v4 de-dup: the
	old per-tab fallback tables listed the same stock content the registries
	already carry, under a different key -- every stock NPC and the stock
	rides appeared TWICE):
	  Entities   list.Get( "SpawnableEntities" )      (game_hl2.lua + SENTs)
	  Weapons    weapons.GetList()                    (game_hl2.lua + SWEPs)
	  NPCs       list.Get( "NPC" )                    (hl2sb_gmod_npcs.lua,
	                                                   GMod's base_npcs.lua)
	  Vehicles   list.Get( "Vehicles" )               (hl2sb_gmod_vehicles.lua
	                                                   + hl2sb_gmod_seats.lua)
	  Props      the stock prop set below (the one list there is)
	  Entries merge on lowercase class; registry data (name/Category/model)
	  wins over the engine class list.  The cache is refreshed on every Open,
	  so lua reloads / addon changes are picked up.

	LOCALIZATION (v4): registrations carry GMod's "#token" names; display
	resolves them through language.GetPhrase (lua/includes/modules/language.lua
	reads GMod's resource/localization/<lang>/*.properties, which this mod
	ships) -- so tab labels, categories, entry names and the menu strings all
	follow cl_language (english / zh-cn / ...).  A token that resolves to
	nothing falls back to the token text or the English stock spelling.

	TOUCH (v4): on Android (system.IsAndroid, or hl2sb_spawnmenu_touch 1 to
	force) the window goes near-fullscreen and the cells, tab buttons and
	category rows size up for fingers; +smenu toggles instead of holding,
	because a touch UI has no reliable key-release.

	SPAWN DISPATCH (the command set the older menus proved):
	  weapon   gm_giveswep <class>
	  npc      gm_spawnnpc <class>  (weapon/name/model/KeyValues ride along)
	  vehicle  gm_spawnvehicle <class> <model> <script>   (model-less
	           prop_vehicle = server crash, so the model always rides along)
	  else     gm_spawn <class> [model]

	THE CRASH RULES (inherited from the menus that came before, keep them):
	  * the frame is built ONCE and only ever SetVisible()d -- never removed
	    while a mouse event is inside it;
	  * a repopulate never runs inside the click that caused it -- it is
	    deferred one tick (timer.Simple( 0 ));
	  * cells are CACHED per tab (entry key -> panel) and re-docked on a
	    category / search / tab switch; the cache is wiped on every Open so a
	    stale icon decision (an image that had not decoded yet, a snapshot
	    from before a map change) can never outlive the session it was made
	    in -- only cells never built before are created, through a per-frame
	    budget, so a big tab cannot stall.

	CONSOLE:
	  +smenu / -smenu   hold-open (Q is bound to +smenu in cfg)
	  hl2sb_spawnmenu   toggle
-----------------------------------------------------------------------------]]

if ( not CLIENT ) then return end

local TAG    = "[HL2SB][SpawnMenu] "

-- PERF (2026-09-23): these diagnostics flooded the console on every menu fill;
-- gate them behind hl2sb_debug (default 0).
local cvarDbg = ( GetConVar ~= nil ) and GetConVar( "hl2sb_debug" ) or nil
local function Dbg( sText )
	if ( cvarDbg == nil ) then cvarDbg = ( GetConVar ~= nil ) and GetConVar( "hl2sb_debug" ) or nil end
	if ( cvarDbg ~= nil and cvarDbg:GetBool() ) then print( sText ) end
end
local ICON   = 64		-- desktop cell size; the touch layout enlarges it below
local BUDGET = 4		-- NEW cells created per frame while a fill is pending
						-- (a Material() decode or a clientside model is tens of ms;
						-- a burst of ten of those per frame was a visible stall)

-- ---------------------------------------------------------------------------
-- touch layout branch (v4): Android gets finger-sized cells and a
-- near-fullscreen window.  Three ways to get it: the auto detection
-- (system.IsAndroid), or hl2sb_spawnmenu_touch 1 to force it on any platform
-- (testing), 0 back to auto.  Read at BuildMenu time so a mid-session convar
-- change lands on the next open.
-- ---------------------------------------------------------------------------

local cvarTouch = ( CreateClientConVar ~= nil )
	and CreateClientConVar( "hl2sb_spawnmenu_touch", "0", true, false,
		"1 = force the touch layout, 0 = auto (touch on Android)" )
	or nil

local function IsTouchLayout()
	if ( cvarTouch ~= nil and cvarTouch.GetInt ~= nil ) then
		local ok, v = pcall( cvarTouch.GetInt, cvarTouch )
		if ( ok and v == 1 ) then return true end
	end
	if ( system ~= nil and system.IsAndroid ~= nil ) then
		local ok, res = pcall( system.IsAndroid )
		if ( ok and res == true ) then return true end
	end
	return false
end

-- the layout the current menu frame was built with (BuildMenu fills this in;
-- MakeCell reads the cell size from it)
local g_Layout = { touch = false, icon = ICON, rowTall = 20 }

-- ---------------------------------------------------------------------------
-- localization helpers (v4): every display string resolves through
-- language.GetPhrase, so "#token" registrations and the menu chrome follow
-- cl_language.  A token that resolves to nothing comes back as readable text
-- (the English stock spelling / the token itself), never as nil.
-- ---------------------------------------------------------------------------

local function Phrase( token )
	if ( _G.language ~= nil and language.GetPhrase ~= nil ) then
		local ok, res = pcall( language.GetPhrase, token )
		if ( ok and isstring( res ) and res ~= "" and string.sub( res, 1, 1 ) ~= "#" ) then
			return res
		end
	end
	return token
end

-- a Category string may itself be a "#token" (GMod's stock registrations:
-- "#spawnmenu.category.combine", weapons.Register's "#spawnmenu.category.other")
local function CategoryLabel( c )
	if ( isstring( c ) and string.sub( c, 1, 1 ) == "#" ) then
		return Phrase( c )
	end
	return tostring( c or "" )
end

-- ---------------------------------------------------------------------------
-- stock content (what no registry carries)
-- ---------------------------------------------------------------------------

-- models, grouped by the folder that names them
local STOCK_PROPS = {
	"models/props_junk/wood_crate001a.mdl",
	"models/props_junk/wood_pallet001a.mdl",
	"models/props_junk/garbage_takeoutcart001a.mdl",
	"models/props_junk/TrafficCone001a.mdl",
	"models/props_junk/MetalBucket01a.mdl",
	"models/props_junk/CinderBlock01a.mdl",
	"models/props_junk/cardboard_box001a.mdl",
	"models/props_junk/cardboard_box004a.mdl",
	"models/props_junk/sawblade001a.mdl",
	"models/props_junk/PopCan01a.mdl",
	"models/props_junk/PlasticCrate01a.mdl",
	"models/props_junk/Rock001a.mdl",
	"models/props_c17/FurnitureDrawer001a.mdl",
	"models/props_c17/FurnitureTable001a.mdl",
	"models/props_c17/FurnitureTable002a.mdl",
	"models/props_c17/FurnitureChair001a.mdl",
	"models/props_c17/FurnitureCouch001a.mdl",
	"models/props_c17/FurnitureBathtub001a.mdl",
	"models/props_c17/FurnitureFireplace001a.mdl",
	"models/props_c17/FurnitureBed001a.mdl",
	"models/props_c17/oildrum001.mdl",
	"models/props_c17/oildrum001_explosive.mdl",
	"models/props_c17/lamp001a.mdl",
	"models/props_c17/lampShade001a.mdl",
	"models/props_c17/traffic_light01a.mdl",
	"models/props_c17/utilitypole01a.mdl",
	"models/props_c17/Frame002a.mdl",
	"models/props_c17/Door001a.mdl",
	"models/props_c17/FireEscape001a.mdl",
	"models/props_c17/suitcase_passenger_physics.mdl",
	"models/props_lab/monitor01b.mdl",
	"models/props_lab/tpplug.mdl",
	"models/props_lab/pottery01a.mdl",
	"models/props_lab/crematorcase.mdl",
	"models/props_lab/labpanel01a.mdl",
	"models/props_lab/locker.mdl",
	"models/props_lab/recycler01b.mdl",
	"models/props_lab/harddrive02.mdl",
	"models/props_combine/combine_monitor.mdl",
	"models/props_combine/combine_interface.mdl",
	"models/props_combine/combine_bins.mdl",
	"models/props_wasteland/panel_leverhandle001a.mdl",
	"models/props_wasteland/light_spotlight01_lamp.mdl",
	"models/props_wasteland/prison_shelf001b.mdl",
	"models/props_interiors/SinkKitchen01a.mdl",
	"models/props_interiors/VendingMachineSoda01a.mdl",
	"models/props_interiors/Furniture_Lamp01a.mdl",
	"models/props_interiors/Radiator01a.mdl",
	"models/props_interiors/refrigerator01a.mdl",
	"models/props_canal/mattpipe.mdl",
	"models/props_canal/boat001a.mdl",
	"models/props_trainstation/trainstation_clock001.mdl",
	"models/props_trainstation/Bench001a.mdl",
	"models/props_borealis/bluebarrel001.mdl",
}

-- The stock NPCs themselves register into list.Get( "NPC" ) from
-- lua/autorun/hl2sb_gmod_npcs.lua (GMod's base_npcs.lua port) -- THIS file no
-- longer registers stock content, it only reads the registry.  STOCK_NPC_NAMES
-- below stays as the display fallback for when the localization files are
-- unavailable.

local STOCK_NPC_NAMES = {
	npc_alyx = "Alyx", npc_barney = "Barney", npc_kleiner = "Kleiner",
	npc_magnusson = "Magnusson", npc_eli = "Eli", npc_mossman = "Mossman",
	npc_breen = "Breen", npc_monk = "Father Grigori", npc_vortigaunt = "Vortigaunt",
	npc_dog = "D.O.G.", npc_citizen = "Citizen", npc_combine_s = "Combine Soldier",
	npc_metropolice = "Civil Protection Officer", npc_manhack = "Manhack",
	npc_stalker = "Stalker", npc_cscanner = "Scanner", npc_clawscanner = "Claw Scanner",
	npc_rollermine = "Rollermine", npc_turret_floor = "Turret",
	npc_turret_ceiling = "Ceiling Turret", npc_strider = "Strider",
	npc_helicopter = "Hunter-Chopper", npc_hunter = "Hunter",
	npc_combine_camera = "Combine Camera", npc_zombie = "Zombie",
	npc_zombie_torso = "Torso Zombie", npc_fastzombie = "Fast Zombie",
	npc_poisonzombie = "Poison Zombie", npc_headcrab = "Headcrab",
	npc_headcrab_fast = "Fast Headcrab", npc_headcrab_black = "Poison Headcrab",
	npc_antlion = "Antlion", npc_antlionguard = "Antlion Guard",
	npc_barnacle = "Barnacle", npc_sniper = "Sniper",
	npc_combinegunship = "Combine Gunship", npc_crow = "Crow",
	npc_pigeon = "Pigeon", npc_seagull = "Seagull",
}

-- Resolve a (possibly "#token") registration name for DISPLAY: the language
-- table first (lua/includes/modules/language.lua loads GMod's
-- resource/localization/<lang>/entities.properties, which names every
-- built-in HL2 NPC / weapon / prop / ammo in the UI language), then the old
-- English stock spellings, then the raw string.  The registrations keep the
-- raw token -- only display resolves, exactly like GMod.
local function ResolveStockName( name, class )
	class = tostring( class or "" )
	if ( name ~= nil and name ~= "" and string.sub( name, 1, 1 ) == "#" ) then
		if ( _G.language ~= nil and language.GetPhrase ~= nil ) then
			local ok, phrase = pcall( language.GetPhrase, name )
			if ( ok and phrase ~= nil and phrase ~= "" and string.sub( phrase, 1, 1 ) ~= "#" ) then
				return phrase
			end
		end
		return STOCK_NPC_NAMES[ class ] or name
	end
	if ( name ~= nil and name ~= "" ) then
		return name
	end
	return STOCK_NPC_NAMES[ class ] or class
end

-- ---------------------------------------------------------------------------
-- entry helpers
-- ---------------------------------------------------------------------------

local function NewEntry( class )
	class = tostring( class or "" )
	if ( class == "" ) then return nil, nil end

	local e = {
		class    = class,
		key      = string.lower( class ),
		name     = class,
		model    = "",
		script   = "",
		cat      = "entity",
		category = nil,		-- the GMod Category string, resolved by the collector
	}

	return e, e.key
end

local function EntryCategory( e )
	if ( e.category ~= nil and e.category ~= "" ) then return tostring( e.category ) end
	return "Other"
end

local function SortEntries( t )
	table.sort( t, function( a, b )
		local an = string.lower( a.name or a.class )
		local bn = string.lower( b.name or b.class )
		if ( an == bn ) then return a.key < b.key end
		return an < bn
	end )
	return t
end

local function NameFromModel( mdl )
	local short = string.gsub( tostring( mdl ), "^.*/", "" )
	short = string.gsub( short, "%.mdl$", "" )
	return short
end

local function firstModel( ... )
	for i = 1, select( "#", ... ) do
		local v = select( i, ... )
		if ( isstring( v ) and v ~= "" ) then return v end
	end
	return ""
end

-- ---------------------------------------------------------------------------
-- content collectors (one per tab) -> sorted entry arrays
-- ---------------------------------------------------------------------------

local function CollectEntities()
	local byKey = {}

		-- registry first: it carries names and GMod Categories
		local reg = ( list ~= nil and list.Get ) and list.Get( "SpawnableEntities" ) or nil
		if ( istable( reg ) ) then
			for spawnname, data in pairs( reg ) do
				local e, key = NewEntry( spawnname )
				if ( e ) then
					e.spawnname    = tostring( spawnname )
					e.iconOverride = ( istable( data ) and isstring( data.IconOverride ) ) and data.IconOverride or nil
					-- GMod registrations carry "#token" PrintNames (game_hl2.lua);
					-- resolve them for display in the UI language
					e.name     = ResolveStockName( tostring( ( istable( data ) and data.PrintName ) or spawnname ), tostring( spawnname ) )
					e.category = ( istable( data ) and isstring( data.Category ) and data.Category ~= "" ) and data.Category or nil
					e.model    = ( istable( data ) and isstring( data.Model ) ) and data.Model or ""
					e.cat      = "entity"

				local stored = ( scripted_ents and scripted_ents.GetStored ) and scripted_ents.GetStored( spawnname )
				if ( stored and istable( stored.t ) ) then
					e.model    = firstModel( e.model, stored.t.Model )
					e.category = e.category or ( isstring( stored.t.Category ) and stored.t.Category ) or nil
				end

				byKey[ key ] = e
			end
		end
	end

	-- GMod's Entities tab is the registry, period.  (The old SMenu fed every
	-- engine class from hl2sb.GetSpawnableClasses() into this tab -- 648 rows
	-- of ai_/env_/func_ noise that drowned the actual content and carried no
	-- models, so every cell was text.  If the raw class list is ever needed
	-- again it deserves its own tab, not this one.)

	local out = {}
	for _, e in pairs( byKey ) do out[ #out + 1 ] = e end
	return SortEntries( out )
end

local function CollectWeapons()
	local byKey = {}

	-- TWO sources, merged on class key (in-game evidence: the SWEP loader's
	-- "[HL2SB wp] REGISTER" line only fires for part of the roster, so
	-- weapons.GetList() alone loses the rest -- seal6-c4, minecraft_swep and
	-- friends were gone from the grid).  weapons.GetList() carries the stock
	-- HL2 set (game_hl2.lua -> weapons.Register) and every SWEP the
	-- ScriptedWeaponRegistered sync caught; weapon.getweapons() is the
	-- loader's own table and has the rest.  Same key -> last write wins, no
	-- duplicates.
	if ( weapon ~= nil and weapon.getweapons ~= nil ) then
		local ok, all = pcall( weapon.getweapons )
		if ( ok and istable( all ) ) then
			for class, w in pairs( all ) do
				if ( istable( w ) and isstring( class ) and w.Spawnable ~= false ) then
					local e, key = NewEntry( class )
					if ( e ) then
						e.name      = ResolveStockName( tostring( w.PrintName or class ), tostring( class ) )
						e.category  = ( isstring( w.Category ) and w.Category ~= "" ) and w.Category or "Half-Life 2"
						e.model     = firstModel( w.WorldModel, w.ViewModel )
						e.spawnname = tostring( class )
						e.cat       = "weapon"
						byKey[ key ] = e
					end
				end
			end
		end
	end

	if ( weapons and weapons.GetList ) then
		for _, w in pairs( weapons.GetList() ) do
			if ( istable( w ) and isstring( w.ClassName ) and w.Spawnable ~= false ) then
				local e, key = NewEntry( w.ClassName )
				if ( e ) then
					e.name      = ResolveStockName( tostring( w.PrintName or w.ClassName ), tostring( w.ClassName ) )
					e.category  = ( isstring( w.Category ) and w.Category ~= "" ) and w.Category or "Half-Life 2"
					e.model     = firstModel( w.WorldModel, w.ViewModel )
					e.spawnname = tostring( w.ClassName )
					e.cat       = "weapon"
					byKey[ key ] = e
				end
			end
		end
	end

	local out = {}
	for _, e in pairs( byKey ) do out[ #out + 1 ] = e end
	return SortEntries( out )
end

local function CollectNPCs()
	local byKey = {}

	-- v4: the registry is the only source (hl2sb_gmod_npcs.lua = GMod's
	-- base_npcs.lua).  The old hardcoded stock-table fallback re-added every
	-- stock NPC under a different key ("npc_alyx" vs the registry's
	-- "n:npc_alyx"), so the whole stock roster showed up TWICE.
	local reg = ( list ~= nil and list.Get ) and list.Get( "NPC" ) or nil
	if ( istable( reg ) ) then
		for spawnname, data in pairs( reg ) do
			-- GMod's NPC list is keyed by SPAWN NAME; the class to spawn is
			-- data.Class.  The hutao pack registers spawn name
			-- "gi_hutao_hostile" with Class "npc_combine_s" -- spawning the key
			-- produced "unknown entity type" server-side.
			if ( istable( data ) ) then
				local e = {
					-- stock registrations carry "#class" token Names; resolve
					-- for display in the UI language (GMod resolves at draw)
					name       = ResolveStockName( tostring( data.Name or spawnname ), tostring( data.Class or spawnname ) ),
					class      = tostring( data.Class or spawnname ),
					key        = "n:" .. tostring( spawnname ),
					model      = ( isstring( data.Model ) ) and data.Model or "",
					script     = "",
					cat        = "npc",
					spawnname  = tostring( spawnname ),
					iconOverride = ( isstring( data.IconOverride ) ) and data.IconOverride or nil,
					category   = ( isstring( data.Category ) and data.Category ~= "" ) and data.Category or "#spawnmenu.category.other",
					-- GMod forwards data.KeyValues through gmod_spawnnpc (the
					-- hutao pack's citizentype = 4 makes npc_citizen keep the
					-- reskin model); ride them on the concommand the same way
					keyvalues  = ( istable( data.KeyValues ) and data.KeyValues ) or nil,
					-- the rest of GMod's registration fields that ride as
					-- entity keyvalues on the spawn line (spawn flags / skin /
					-- health are real keyfields; Offset/OnCeiling/NoDrop stay
					-- stored-only, this fork's spawner has no floor-drop pass)
					spawnflags = ( data.SpawnFlags ~= nil or data.TotalSpawnFlags ~= nil )
						and ( tonumber( data.SpawnFlags or data.TotalSpawnFlags ) or nil ) or nil,
					skin       = ( data.Skin ~= nil ) and ( tonumber( data.Skin ) or nil ) or nil,
					health     = ( data.Health ~= nil ) and ( tonumber( data.Health ) or nil ) or nil,
				}
				byKey[ e.key ] = e
			end
		end
	end

	local out = {}
	for _, e in pairs( byKey ) do out[ #out + 1 ] = e end
	return SortEntries( out )
end

local function CollectVehicles()
	local byKey = {}

	-- The Vehicles list is keyed by GMod SPAWN NAME (not class -- every chair
	-- is prop_vehicle_prisoner_pod), the class to spawn is data.Class, and the
	-- vehicle script rides in data.KeyValues.vehiclescript (GMod's contract,
	-- lua/autorun/hl2sb_gmod_vehicles.lua / hl2sb_gmod_seats.lua).
	local reg = ( list ~= nil and list.Get ) and list.Get( "Vehicles" ) or nil
	if ( istable( reg ) ) then
		for spawnname, data in pairs( reg ) do
			-- a vehicle entry without a model is a server crash waiting to
			-- happen (gm_spawnvehicle needs the model), so it never becomes a
			-- cell -- the same rule the old menus used.
			if ( istable( data ) and isstring( data.Model ) and data.Model ~= "" ) then
				local kv = ( istable( data.KeyValues ) and data.KeyValues ) or {}
				local e = {
					-- registrations carry "#spawnmenu.vehicle.*" tokens
					-- (hl2sb_gmod_vehicles.lua / hl2sb_gmod_seats.lua); resolve
					-- for display in the UI language
					name       = ResolveStockName( tostring( data.Name or data.PrintName or spawnname ), tostring( data.Class or spawnname ) ),
					class      = tostring( data.Class or spawnname ),
					key        = "v:" .. tostring( spawnname ),
					model      = data.Model,
					script     = ( isstring( kv.vehiclescript ) ) and kv.vehiclescript or "",
					-- the registry's other KeyValues ride along (gm_spawnvehicle
					-- forwards them as trailing name/value pairs); the seats list
					-- already carries `limitview = "0"` here, and addons can add
					-- their own
					keyvalues  = kv,
					cat        = "vehicle",
					spawnname  = tostring( spawnname ),
					iconOverride = ( isstring( data.IconOverride ) ) and data.IconOverride or nil,
					category   = ( isstring( data.Category ) and data.Category ~= "" ) and data.Category or nil,
				}
				byKey[ e.key ] = e
			end
		end
	end

	-- v4: the registry is the only source.  The old hardcoded stock rides
	-- table re-added the jeep / airboat / pod under their own keys, so those
	-- three showed up twice (once as the registry's localized cell, once as
	-- the stock "Jeep / Airboat / Chair").

	local out = {}
	for _, e in pairs( byKey ) do out[ #out + 1 ] = e end
	return SortEntries( out )
end

local function CollectProps()
	local byKey = {}

	local reg = ( list ~= nil and list.Get ) and list.Get( "Props" ) or nil
	if ( istable( reg ) ) then
		for _, data in pairs( reg ) do
			if ( istable( data ) and isstring( data.Model ) and data.Model ~= "" ) then
				local e = {
					name      = tostring( data.Name or NameFromModel( data.Model ) ),
					class     = tostring( data.Class or "prop_physics" ),
					key       = string.lower( tostring( data.Model ) ),
					model     = data.Model,
					script    = "",
					cat       = "prop",
					spawnname = NameFromModel( data.Model ),
					category  = ( isstring( data.Category ) and data.Category ) or nil,
				}
				byKey[ e.key ] = e
			end
		end
	end

	for _, mdl in ipairs( STOCK_PROPS ) do
		local e = {
			name      = NameFromModel( mdl ),
			class     = "prop_physics",
			key       = mdl,
			model     = mdl,
			script    = "",
			cat       = "prop",
			spawnname = NameFromModel( mdl ),
			category  = nil,		-- resolved from the path below
		}

		-- models/props_junk/x.mdl -> "Junk"; props_c17/FurnitureX -> "Furniture"
		local group = string.match( mdl, "models/props_([^.]+)/" ) or "Misc"
		local sub   = string.match( mdl, "models/props_[^/]+/([A-Za-z]+)" ) or ""
		if ( group == "c17" and string.sub( sub, 1, 9 ) == "Furniture" ) then
			e.category = "Furniture"
		else
			e.category = string.upper( string.sub( group, 1, 1 ) ) .. string.sub( group, 2 )
		end

		byKey[ e.key ] = e
	end

	local out = {}
	for _, e in pairs( byKey ) do out[ #out + 1 ] = e end
	return SortEntries( out )
end

local Collectors = {
	entities = CollectEntities,
	weapons  = CollectWeapons,
	npcs     = CollectNPCs,
	vehicles = CollectVehicles,
	props    = CollectProps,
}

-- ---------------------------------------------------------------------------
-- spawn dispatch
-- ---------------------------------------------------------------------------

-- quote a console argument, stripping anything that could break out of it
local function Q( v )
	v = tostring( v or "" ):gsub( '"', "" )
	return '"' .. v .. '"'
end

local function SpawnEntry( e )
	if ( e == nil ) then return end
	local line

	if ( e.cat == "weapon" ) then
		line = "gm_giveswep " .. e.class
	elseif ( e.cat == "npc" ) then
		-- slot 2 is the weapon override (empty = the NPC's own / gmod_npcweapon),
		-- slot 3 the display name for undo + kill feed, slot 4 the reskin model
		-- (reskin packs register Class = a stock NPC + their own Model), slots
		-- 5.. the registry KeyValues as name/value pairs
		line = "gm_spawnnpc " .. e.class .. ' "" ' .. Q( e.name )
			.. ( ( e.model and e.model ~= "" ) and ( " " .. Q( e.model ) ) or "" )
		-- GMod ships list.Set( "NPC", ... ) data.KeyValues through gmod_spawnnpc's
		-- net table; here they ride the concommand.  Without the hutao pack's
		-- citizentype = 4 (CT_UNIQUE), npc_citizen rewrites the reskin model into
		-- models/Humans/Group01/<file> -- a file that does not exist -- and the
		-- NPC spawns as the ERROR model (2026-09-19, gi_hutao_friendly).
		if ( istable( e.keyvalues ) ) then
			for k, v in pairs( e.keyvalues ) do
				line = line .. " " .. Q( tostring( k ) ) .. " " .. Q( tostring( v ) )
			end
		end
		-- GMod's other registration fields that ARE entity keyfields ride the
		-- same way (spawnflags/skin/health applied by the spawner before Spawn)
		if ( e.spawnflags ~= nil ) then line = line .. ' "spawnflags" ' .. Q( tostring( e.spawnflags ) ) end
		if ( e.skin ~= nil and e.skin > 0 ) then line = line .. ' "skin" ' .. Q( tostring( e.skin ) ) end
		if ( e.health ~= nil ) then line = line .. ' "health" ' .. Q( tostring( e.health ) ) end
	elseif ( e.cat == "vehicle" ) then
		-- the MODEL rides along: a model-less prop_vehicle is a server crash
		line = "gm_spawnvehicle " .. e.class
			.. ( ( e.model and e.model ~= "" ) and ( " " .. e.model ) or ' ""' )
			.. ( ( e.script and e.script ~= "" ) and ( " " .. e.script ) or ' ""' )
			.. " " .. Q( e.name )
		-- slots 5.. are the registry KeyValues as name/value pairs, same
		-- convention as gm_spawnnpc above
		if ( istable( e.keyvalues ) ) then
			for k, v in pairs( e.keyvalues ) do
				line = line .. " " .. Q( tostring( k ) ) .. " " .. Q( tostring( v ) )
			end
		end
	elseif ( e.model ~= nil and e.model ~= "" ) then
		line = "gm_spawn " .. e.class .. " " .. e.model .. " " .. Q( e.name )
	else
		line = "gm_spawn " .. e.class .. ' "" ' .. Q( e.name )
	end

	Dbg( TAG .. "spawn: " .. line )

	if ( engine and engine.ClientCmd ) then
		engine.ClientCmd( line )
	elseif ( RunConsoleCommand ) then
		RunConsoleCommand( line )
	end
end

local function EntryMenu( e )
	if ( vgui == nil or vgui.Create == nil ) then return end
	local ok, menu = pcall( vgui.Create, "DMenu" )
	if ( not ok or not IsValid( menu ) ) then return end

	menu:AddOption( Phrase( "hl2sb.spawnmenu.spawn_one" ), function() SpawnEntry( e ) end )
	menu:AddOption( Phrase( "hl2sb.spawnmenu.spawn_five" ), function()
		for _ = 1, 5 do SpawnEntry( e ) end
	end )
	if ( menu.AddSpacer ) then menu:AddSpacer() end
	if ( SetClipboardText ) then
		menu:AddOption( Phrase( "spawnmenu.menu.copy" ), function() SetClipboardText( tostring( e.class ) ) end )
	end
	menu:Open()
end

-- ---------------------------------------------------------------------------
-- the window
-- ---------------------------------------------------------------------------

local g_Frame, g_Grid, g_Side, g_Search, g_Hint
local g_TabButtons = {}
local g_CatButtons = {}
local g_ActiveTab  = "entities"
local g_ActiveCat  = nil		-- nil = All
local g_Pending    = {}		-- entries queued for the grid
local g_Cache      = {}		-- tab id -> collected entries (refreshed on Open)
local g_CellCache  = {}		-- tab id -> entry key -> built cell panel.  The point
							-- of the cache: a category / search / tab switch re-docks
							-- cached panels instead of re-probing icons, re-decoding
							-- materials and re-creating clientside models.

-- MOUSE INPUT IS A GATE IN THIS ENGINE, NOT INHERITED
-- (vgui2/vgui_controls/Panel.cpp:3343 -- "if it doesn't want mouse input its
-- children can't get it either").  Every container from the popup down must
-- keep it open, and it must be RE-ASSERTED: the previous menu watched a
-- container report mouse-enabled at creation and disabled by show time.  And
-- MakePopup alone does not bring the cursor in -- the C++ menu got there via
-- vgui::Frame::Activate() = MakePopup + MoveToFront + RequestFocus.  Without
-- that, the menu paints perfectly and nothing on it is clickable.
local function AssertMouseInput()
	local function open( p )
		if ( p ~= nil and IsValid( p ) ) then
			if ( p.SetMouseInputEnabled ) then p:SetMouseInputEnabled( true ) end
			if ( p.GetCanvas ) then
				local ok, canvas = pcall( p.GetCanvas )
				if ( ok and canvas ~= nil and IsValid( canvas ) and canvas.SetMouseInputEnabled ) then
					canvas:SetMouseInputEnabled( true )
				end
			end
		end
	end

	open( g_Frame )
	open( g_Grid )
	open( g_Side )
	open( g_Search )

	for _, btn in pairs( g_TabButtons ) do
		if ( IsValid( btn ) and btn.SetMouseInputEnabled ) then btn:SetMouseInputEnabled( true ) end
	end
	for _, btn in pairs( g_CatButtons ) do
		if ( IsValid( btn ) and btn.SetMouseInputEnabled ) then btn:SetMouseInputEnabled( true ) end
	end

	if ( g_Frame ~= nil and IsValid( g_Frame ) ) then
		if ( g_Frame.SetKeyBoardInputEnabled ) then g_Frame:SetKeyBoardInputEnabled( true ) end
		if ( g_Search ~= nil and IsValid( g_Search ) and g_Search.SetKeyBoardInputEnabled ) then
			g_Search:SetKeyBoardInputEnabled( true )
		end
	end
end

local function KillFill()
	g_Pending = {}
	g_Failed = 0
end

local function EntriesFor( id )
	if ( g_Cache[ id ] == nil ) then
		local fn = Collectors[ id ]
		local ok, res = pcall( fn or function() return {} end )
		g_Cache[ id ] = ( ok and type( res ) == "table" ) and res or {}
	end
	return g_Cache[ id ]
end

local ICON_EXTS = { ".png", ".vmt" }

-- GMod icon conventions + this fork's own probe order (the C++ menu used
-- the same): registry IconOverride, spawn name / class under entities/ and
-- vgui/entities/, model base name under vgui/smenu/.  The probe returns the
-- MATERIAL name: with .png for raw images, without for .vmt.
local function ProbeIconPath( e )
	local candidates = {}
	if ( e.iconOverride and e.iconOverride ~= "" ) then
		candidates[ #candidates + 1 ] = tostring( e.iconOverride )
	end
	if ( e.spawnname and e.spawnname ~= "" ) then
		candidates[ #candidates + 1 ] = "entities/" .. e.spawnname
	end
	if ( e.class and e.class ~= "" ) then
		candidates[ #candidates + 1 ] = "entities/" .. e.class
		candidates[ #candidates + 1 ] = "vgui/entities/" .. e.class
		candidates[ #candidates + 1 ] = "vgui/smenu/" .. e.class
	end
	local base = NameFromModel( e.model or "" )
	if ( base ~= "" ) then
		candidates[ #candidates + 1 ] = "entities/" .. base
		candidates[ #candidates + 1 ] = "vgui/smenu/" .. base
	end

	for _, name in ipairs( candidates ) do
		for _, ext in ipairs( ICON_EXTS ) do
			if ( file.Exists( "materials/" .. name .. ext, "GAME" ) ) then
				return name .. ext
			end
		end
	end

	return nil
end

--- A cell is 64px wide; a longer name bled over its neighbours and read as one
--- run-on line ("utao - Frutao - He", the 2026-09-19 video).  Trim to fit.
--- surface.SetFont resolves a scheme font and returns the HFont handle;
--- surface.GetTextSize measures against an explicit handle here.
--- Trimming goes one UTF-8 CHARACTER at a time, not one byte: the localized
--- names are CJK (3 bytes per glyph), a byte-wise sub() splits a character
--- mid-sequence and the renderer draws the broken bytes as '?' inside the
--- label ("办公?座椅").
local function FitLabel( text, maxw )
	text = tostring( text or "" )

	-- measure with the EXACT handle draw.SimpleText will render with
	-- (draw.GetFont).  surface.SetFont( name ) resolves a different registry
	-- and either nil (label silently untrimmed -> "Atomic Bomb" bleeding over
	-- the neighbour cells, 2026-09-26 video) or a narrower metric than the
	-- renderer uses.
	local hFont = ( draw ~= nil and draw.GetFont ~= nil ) and draw.GetFont( "DermaDefault" ) or nil
	if ( hFont == nil or surface.GetTextSize == nil ) then return text end

	local okW, w = pcall( surface.GetTextSize, hFont, text )
	if ( not okW or w == nil or w <= maxw ) then return text end

	while ( #text > 1 ) do
		-- Step back to the start of the last UTF-8 character: a continuation
		-- byte (0x80-0xBF) is never a character start, so scan back until a
		-- lead byte / ASCII.  (utf8.offset from the compat module throws on
		-- exactly this walk -- its negative start lands ON the last byte,
		-- which for CJK is a continuation -- and a throw here used to kill
		-- the whole cell: every localized name longer than the tile came out
		-- MISSING, only short names survived.)
		local i = #text
		while ( i > 1 ) do
			local b = string.byte( text, i )
			if ( b < 0x80 or b >= 0xC0 ) then break end
			i = i - 1
		end
		if ( i <= 1 ) then return "..." end

		text = string.sub( text, 1, i - 1 )
		local okT, wt = pcall( surface.GetTextSize, hFont, text .. "..." )
		if ( okT and wt ~= nil and wt <= maxw ) then return text .. "..." end
	end

	return "..."
end

local function MakeCell( e )
	local icon = g_Layout.icon

	-- 1) a shipped icon image: static and exact, what GMod shows for anything
	--    that ships one (materials/entities/<name>.png; IconOverride rides)
	local iconPath = ProbeIconPath( e )
	if ( iconPath ~= nil ) then
		local okM, mat = pcall( Material, iconPath )
		if ( okM and mat ~= nil ) then
			-- v4: a PNG that is STILL DECODING answers IsError() true on the
			-- first call (async texture load).  The old code fell through to
			-- the next fallback on that -- and the flat cell it built instead
			-- was cached, so the icon never came back for the whole session.
			-- Build the image cell either way; Paint draws the flat tile +
			-- label until the material decodes, then the texture.  A file that
			-- never decodes keeps the flat tile instead of the magenta
			-- checkerboard, which is the same thing the blank cell drew.
			local label = FitLabel( e.name or e.class, icon - 6 )
			local ok, btn = pcall( vgui.Create, "DButton" )
			if ( ok and IsValid( btn ) ) then
				btn:SetText( "" )
				btn.Paint = function( pnl, w, h )
					surface.SetDrawColor( 45, 48, 52, 255 )
					surface.DrawRect( 0, 0, w, h )

					local bReady = not ( mat.IsError and mat:IsError() )
					if ( bReady ) then
						surface.SetMaterial( mat )
						surface.SetDrawColor( 255, 255, 255, 255 )
						surface.DrawTexturedRect( 0, 0, w, h )
					else
						surface.SetDrawColor( 70, 75, 82, 255 )
						surface.DrawOutlinedRect( 0, 0, w, h )
					end
					draw.SimpleText( label, "DermaDefault", w / 2, h - 8, Color( 220, 220, 220, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
				end
				pcall( function() btn:SetTooltip( ( e.name or e.class ) .. "\n" .. e.class ) end )
				btn.DoClick = function() SpawnEntry( e ) end
				btn.DoRightClick = function() EntryMenu( e ) end
				return btn, "image"
			end
		else
			Dbg( TAG .. "icon material call failed for '" .. iconPath .. "' - next fallback" )
		end
	end

	-- 2) a live 3D thumbnail -- the PROPS page ONLY (user rule, tightened
	--    2026-10-07: vehicles used to render here too; everything that is not
	--    a prop shows a flat image / blank tile, the way GMod's icon grid
	--    reads -- entity/weapon/NPC/vehicle 3D thumbnails of view/world models
	--    looked wrong and the viewmodels were unusable).
	--    No file.Exists gate: the Lua file API does not see every mounted
	--    model tree.  The MODEL LOAD itself is deferred inside SpawnIcon
	--    (queued, one per tick, on-screen cells only -- the load is the
	--    expensive part and a burst of them was the stutter), so there is no
	--    entity to check here anymore: a model that fails marks its icon and
	--    the icon's Paint degrades to the model's file name instead of the
	--    error checkerboard.
	local mdl = e.model or ""

	if ( e.cat == "prop" and mdl ~= "" ) then
		local ok, spicon = pcall( vgui.Create, "SpawnIcon" )
		if ( ok and IsValid( spicon ) ) then
			local okSet, errSet = pcall( function() spicon:SetModel( mdl, 0, "" ) end )
			if ( okSet ) then
				pcall( function() spicon:SetTooltip( ( e.name or e.class ) .. "\n" .. mdl ) end )
				spicon.DoClick = function() SpawnEntry( e ) end
				spicon.DoRightClick = function() EntryMenu( e ) end
				spicon.OpenMenu = function() EntryMenu( e ) end
				return spicon, "spawnicon"
			end
			Dbg( TAG .. "SetModel failed for '" .. mdl .. "': " .. tostring( errSet ) )
			if ( IsValid( spicon ) ) then spicon:Remove() end
		else
			Dbg( TAG .. "vgui.Create( SpawnIcon ) failed: " .. tostring( spicon ) )
		end
	end

	-- 2b) everything else with no shipped image: a BLANK tile (the same
	--     chrome as the image cell, minus the texture) -- per the user rule
	--     these must not fall through to a 3D model render.
	local label = FitLabel( e.name or e.class, icon - 6 )
	local ok, btn = pcall( vgui.Create, "DButton" )
	if ( ok and IsValid( btn ) ) then
		btn:SetText( "" )
		btn.Paint = function( pnl, w, h )
			surface.SetDrawColor( 45, 48, 52, 255 )
			surface.DrawRect( 0, 0, w, h )
			surface.SetDrawColor( 70, 75, 82, 255 )
			surface.DrawOutlinedRect( 0, 0, w, h )
			draw.SimpleText( label, "DermaDefault", w / 2, h - 8, Color( 220, 220, 220, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
		pcall( function() btn:SetTooltip( ( e.name or e.class ) .. "\n" .. e.class ) end )
		btn.DoClick = function() SpawnEntry( e ) end
		btn.DoRightClick = function() EntryMenu( e ) end
		return btn, "blank"
	end

	-- 3) last resort: a text button
	local btn = vgui.Create( "DButton" )
	btn:SetText( e.name or e.class )
	btn:SetWrap( true )
		btn:SetContentAlignment( 5 )
	btn:SetTooltip( ( e.name or e.class ) .. "\n" .. e.class )
	btn.DoClick = function() SpawnEntry( e ) end
	btn.DoRightClick = function() EntryMenu( e ) end
	return btn, "text"
end

local g_IconsMade, g_TextsMade, g_ImagesMade = 0, 0, 0
local g_Failed = 0
local g_VehicleProbeDumped = false

local function FillStep()
	-- Two cost classes share the queue.  Re-docking a CACHED cell is a
	-- SetVisible + AddItem (Rebuild is only an InvalidateLayout) -- do as many
	-- of those as the queue holds.  Creating a cell is an icon probe plus a
	-- Material() decode or a clientside model -- that path is budgeted.
	local nCreated = 0
	local nDocked = 0

	while ( #g_Pending > 0 ) do
		local e = table.remove( g_Pending, 1 )

		if ( g_Grid == nil or not IsValid( g_Grid ) ) then break end

		local cache = g_CellCache[ g_ActiveTab ]
		local cell = ( cache ~= nil ) and cache[ e.key ] or nil
		if ( cell ~= nil and not IsValid( cell ) ) then cell = nil end

		if ( cell ~= nil ) then
			cell:SetVisible( true )
			g_Grid:AddItem( cell )
			nDocked = nDocked + 1
		else
			if ( nCreated >= BUDGET ) then
				-- budget spent: put it back for the next frame
				table.insert( g_Pending, 1, e )
				break
			end
			nCreated = nCreated + 1

			local ok, c, kind = pcall( MakeCell, e )
			if ( not ok ) then
				g_Failed = g_Failed + 1
				Dbg( TAG .. "cell failed for '" .. tostring( e.class ) .. "': " .. tostring( c ) )
			else
				if ( kind == "spawnicon" ) then g_IconsMade = g_IconsMade + 1
				elseif ( kind == "image" ) then g_ImagesMade = g_ImagesMade + 1
				else g_TextsMade = g_TextsMade + 1 end
				c:SetSize( g_Layout.icon, g_Layout.icon )
				g_Grid:AddItem( c )

				cache = g_CellCache[ g_ActiveTab ]
				if ( cache == nil ) then cache = {}; g_CellCache[ g_ActiveTab ] = cache end
				cache[ e.key ] = c
			end
		end
	end

	if ( #g_Pending <= 0 ) then
		if ( g_Grid ~= nil and IsValid( g_Grid ) ) then
			g_Grid:InvalidateLayout( true )
		end
		AssertMouseInput()
		Dbg( TAG .. "fill done: created=" .. nCreated .. " docked=" .. nDocked
			.. " images=" .. g_ImagesMade .. " spawnicons=" .. g_IconsMade
			.. " text=" .. g_TextsMade .. " failed=" .. g_Failed )
		g_IconsMade, g_TextsMade, g_ImagesMade = 0, 0, 0
	end
end

local function CategoriesFor( entries )
	local seen, out = {}, {}
	for _, e in ipairs( entries ) do
		local c = EntryCategory( e )
		if ( not seen[ c ] ) then
			seen[ c ] = true
			out[ #out + 1 ] = c
		end
	end
	table.sort( out, function( a, b ) return string.lower( a ) < string.lower( b ) end )
	return out
end

local function Repopulate( bRebuildSidebar )
	if ( g_Frame == nil or not IsValid( g_Frame ) ) then return end
	KillFill()

	-- Detach, do NOT destroy: cells land in g_CellCache at creation, and a
	-- switch re-docks the cached ones instead of rebuilding them.  (The old
	-- g_Grid:Clear() here was ALSO the lag bug: this fork's DPanelList:Clear
	-- left the panels inside m_tItems, so every switch stacked another
	-- invisible copy of the whole grid on top of the new one and the list was
	-- walked -- and grown -- forever.)
	if ( g_Grid ~= nil and IsValid( g_Grid ) ) then
		g_Grid:DetachAll()
	end

	local entries = EntriesFor( g_ActiveTab )

	if ( bRebuildSidebar and g_Side ~= nil and IsValid( g_Side ) ) then
		g_Side:Clear()
		g_CatButtons = {}

		local rows = CategoriesFor( entries )

		-- GMod has NO "All" page: a tab always shows ONE category, chosen the
		-- moment the tab opens.  The old "All" row was also the one page that
		-- queued every entry of the tab at once -- the big page the player
		-- called out as the lag page.
		local function HasCat( list, c )
			for _, r in ipairs( list ) do
				if ( r == c ) then return true end
			end
			return false
		end
		if ( g_ActiveCat == nil or not HasCat( rows, g_ActiveCat ) ) then
			g_ActiveCat = rows[ 1 ] or nil
		end

		for _, c in ipairs( rows ) do
			local btn = vgui.Create( "DButton" )
			btn:SetText( CategoryLabel( c ) )		-- "#spawnmenu.category.*" resolves here
			btn:SetTall( g_Layout.rowTall )
			btn:SetContentAlignment( 4 )
			btn.m_bDepressed = ( c == g_ActiveCat )
			btn.DoClick = function()
				g_ActiveCat = c
				for cc, bb in pairs( g_CatButtons ) do
					if ( IsValid( bb ) ) then
						bb.m_bDepressed = ( cc == c )
					end
				end
				Repopulate( false )
			end
			g_CatButtons[ c ] = btn
			g_Side:AddItem( btn )
		end
		g_Side:InvalidateLayout( true )
	elseif ( g_ActiveCat == nil ) then
		-- no sidebar rebuild (category click / search) and no category yet:
		-- fall back to the first one so the grid is never an "everything" dump
		local rows = CategoriesFor( entries )
		g_ActiveCat = rows[ 1 ] or nil
	end

	local filter = ""
	if ( g_Search ~= nil and IsValid( g_Search ) ) then
		filter = string.lower( tostring( g_Search:GetValue() or "" ) )
	end

	for _, e in ipairs( entries ) do
		local catOK = ( g_ActiveCat == nil ) or ( EntryCategory( e ) == g_ActiveCat )
		if ( catOK ) then
			local hay = string.lower( ( e.name or "" ) .. " " .. ( e.class or "" ) )
			if ( filter == "" or string.find( hay, filter, 1, true ) ~= nil ) then
				g_Pending[ #g_Pending + 1 ] = e
			end
		end
	end

	if ( g_Hint ~= nil and IsValid( g_Hint ) ) then
		-- "%d items" template token + the control hint for the current layout
		local items = string.format( Phrase( "hl2sb.spawnmenu.items_fmt" ), #g_Pending )
		local controls = Phrase( g_Layout.touch and "hl2sb.spawnmenu.hint_touch" or "hl2sb.spawnmenu.hint_desktop" )
		g_Hint:SetText( items .. " | " .. controls )
	end

	-- The fill is driven by the frame's OnThink (the mechanism the previous
	-- menu proved) -- NOT by the client timer library, whose driver hook adds
	-- one more thing that can silently never fire.
	Dbg( TAG .. "repopulate: tab=" .. tostring( g_ActiveTab ) .. " cat=" .. tostring( g_ActiveCat )
		.. " -> " .. #g_Pending .. " cells queued" )
end

local function SetActiveTab( id )
	g_ActiveTab = id
	g_ActiveCat = nil

	-- m_bDepressed is v2's proven active-marker hack: the fork's Panel has no
	-- SetAlpha binding, and a held-down looking button reads fine as "active".
	for tid, btn in pairs( g_TabButtons ) do
		if ( IsValid( btn ) ) then
			btn.m_bDepressed = ( tid == id )
		end
	end

	if ( g_Search ~= nil and IsValid( g_Search ) ) then g_Search:SetValue( "" ) end
	Repopulate( true )
end

local function BuildMenu()
	-- v4: the touch branch sizes everything up once, here -- cells, rows,
	-- buttons and the window itself.  The desktop numbers are the v3 ones.
	local bTouch    = IsTouchLayout()
	local icon      = bTouch and 96 or 64
	local pad       = bTouch and 12 or 8
	local btnH      = bTouch and 32 or 22
	local rowTall   = bTouch and 32 or 20
	local sideW     = bTouch and 210 or 170
	local searchW   = bTouch and 280 or 240
	local spacing   = bTouch and 8 or 4

	g_Layout.touch   = bTouch
	g_Layout.icon    = icon
	g_Layout.rowTall = rowTall

	local frame = vgui.Create( "DPanel" )
	if ( bTouch ) then
		frame:SetSize( ScrW() - pad * 2, ScrH() - pad * 2 )
		frame:SetPos( pad, pad )
	else
		frame:SetSize( ScrW() - 160, ScrH() - 140 )
		frame:SetPos( 80, 70 )
	end

	-- HL2SB: this fork's DPanel paints nothing, so the world showed through
	-- the whole menu.  GMod's spawnmenu sits on an opaque dark sheet.
	frame.Paint = function( pnl, w, h )
		surface.SetDrawColor( 39, 43, 48, 255 )
		surface.DrawRect( 0, 0, w, h )
	end

	-- search
	local search = vgui.Create( "DTextEntry", frame )
	search:SetPos( pad, pad )
	search:SetSize( searchW, btnH )
	search:SetPlaceholderText( Phrase( "hl2sb.spawnmenu.search" ) )
	search.OnTextChanged = function()
		-- never clear the grid inside the text entry's own dispatch
		timer.Simple( 0, function()
			if ( g_Frame ~= nil and IsValid( g_Frame ) and g_Frame:IsVisible() ) then
				Repopulate( false )
			end
		end )
	end

	-- tabs (labels are the same category tokens the sidebar uses, so they
	-- localize with the rest)
	local tabs = {}
	local tx = pad + searchW + 12
	local order  = { "entities", "weapons", "npcs", "vehicles", "props" }
	local labels = {
		entities = "#spawnmenu.category.entities",
		weapons  = "#spawnmenu.category.weapons",
		npcs     = "#spawnmenu.category.npcs",
		vehicles = "#spawnmenu.category.vehicles",
		props    = "#spawnmenu.category.props",
	}
	local tabW = bTouch and 96 or 88
	for _, id in ipairs( order ) do
		local btn = vgui.Create( "DButton", frame )
		btn:SetText( Phrase( labels[ id ] ) )
		btn:SetPos( tx, pad )
		btn:SetSize( tabW, btnH )
		btn.m_bDepressed = ( id == "entities" )
		btn.DoClick = function() SetActiveTab( id ) end
		tabs[ id ] = btn
		tx = tx + tabW + 4
	end

	-- category sidebar
	local topY = pad + btnH + 6
	local side = vgui.Create( "DPanelList", frame )
	side:SetPos( pad, topY )
	side:SetSize( sideW, frame:GetTall() - topY - pad )
	side:EnableVerticalScrollbar( true )
	side:SetSpacing( 2 )
	side:SetPadding( 4 )

	-- icon grid
	local gridX = pad + sideW + 8
	local grid = vgui.Create( "DPanelList", frame )
	grid:SetPos( gridX, topY )
	grid:SetSize( frame:GetWide() - gridX - pad, frame:GetTall() - topY - pad )
	grid:EnableHorizontal( true )
	grid:EnableVerticalScrollbar( true )
	grid:SetSpacing( spacing )
	grid:SetPadding( 6 )

	-- hint
	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( frame:GetWide() - 330 - pad, pad + 4 )
	hint:SetSize( 320, 18 )
	hint:SetContentAlignment( 9 )
	hint:SetText( "" )

	g_Frame, g_Grid, g_Side, g_Search, g_Hint = frame, grid, side, search, hint
	g_TabButtons = tabs

	-- The per-frame pump: OnThink is the mechanism the previous menu proved --
	-- the client timer library's driver hook is one more link that can
	-- silently never fire, so nothing here depends on it.
	frame.OnThink = function()
		if ( #g_Pending > 0 ) then
			FillStep()
		end
	end

	frame:MakePopup()
	frame:SetVisible( false )
end

-- v4: cached cells are wiped on every Open.  The per-tab cache exists to make
-- category / search / tab switches cheap WITHIN one open -- it must not outlive
-- it: a cell built while an icon PNG was still decoding, or holding a texture
-- id from before a map change, would re-dock as a dead tile forever (the
-- "some icons are gone after a map change" report).
local function WipeCellCache()
	for _, cache in pairs( g_CellCache ) do
		for _, cell in pairs( cache ) do
			if ( IsValid( cell ) ) then
				cell:Remove()
			end
		end
	end
	g_CellCache = {}
end

local function Open()
	if ( g_Frame ~= nil and IsValid( g_Frame ) and g_Layout.touch ~= IsTouchLayout() ) then
		-- the touch convar flipped since this frame was built: the layout is
		-- baked into the frame's geometry, so rebuild.  Open() runs from a key
		-- or console, never from a mouse event inside the frame -- the "never
		-- remove while a mouse event is inside it" rule holds.
		g_Frame:Remove()
		g_Frame = nil
	end
	if ( g_Frame == nil or not IsValid( g_Frame ) ) then
		BuildMenu()
	end
	KillFill()
	WipeCellCache()
	g_Cache = {}		-- re-read the registries: addons may have registered since

	for id, fn in pairs( Collectors ) do
		local ok, res = pcall( fn )
		Dbg( TAG .. "collect " .. id .. ": " .. ( ( ok and type( res ) == "table" ) and #res or ( "FAILED " .. tostring( res ) ) ) )
	end

	g_Search:SetValue( "" )
	SetActiveTab( g_ActiveTab or "entities" )
	g_Frame:SetVisible( true )
	g_Frame:MakePopup()
	g_Frame:MoveToFront()
	if ( g_Frame.RequestFocus ) then g_Frame:RequestFocus() end
	AssertMouseInput()
end

local function Close()
	if ( g_Frame ~= nil and IsValid( g_Frame ) ) then
		KillFill()
		g_Frame:SetVisible( false )
	end
end

local function Toggle()
	if ( g_Frame ~= nil and IsValid( g_Frame ) and g_Frame:IsVisible() ) then
		Close()
	else
		Open()
	end
end

-- ---------------------------------------------------------------------------
-- entry points (this file sorts last among the spawnmenu files in autorun,
-- so these overwrite any older handler set)
-- ---------------------------------------------------------------------------

if ( concommand and concommand.Add ) then
	concommand.Add( "hl2sb_spawnmenu", function() Toggle() end, nil, "Toggle the spawn menu." )
	-- touch has no reliable key release (a finger lift never sends "-smenu"),
	-- so on the touch layout +smenu toggles instead of holding
	concommand.Add( "+smenu", function()
		if ( g_Layout.touch ) then Toggle() else Open() end
	end, nil, "Open the spawn menu (hold)." )
	concommand.Add( "-smenu", function() Close() end, nil, "Close the spawn menu (release)." )
end

-- The Options -> Keyboard page binds "+menu" / "-menu" (engine ConCommands in
-- cdll_client_int.cpp), which fire the GMod hooks instead of touching this
-- menu directly.  Listen to them so a rebound key (e.g. G) opens the menu too,
-- not just the legacy Q = +smenu binding left in config.cfg.
if ( hook and hook.Add ) then
	hook.Add( "OnSpawnMenuOpen", "hl2sb_spawnmenu_open", function() Open() end )
	hook.Add( "OnSpawnMenuClose", "hl2sb_spawnmenu_close", function() Close() end )
end

Dbg( TAG .. "v4 loaded: registry-only content, token localization, prop-only 3D, touch branch (Q = +smenu)" )
