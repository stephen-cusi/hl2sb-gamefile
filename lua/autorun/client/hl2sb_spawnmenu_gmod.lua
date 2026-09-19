--[[---------------------------------------------------------------------------
	HL2SB spawn menu v3 -- a GMod-shaped spawn menu, rewritten from scratch.

	Replaces both older implementations (the 2000-line hl2sb_spawnmenu.lua and
	spawnmenu_gmod.lua v2).  This file is the only spawn menu now.

	LAYOUT (GMod's spawnmenu, wiki.facepunch.com/gmod/spawnmenu):
	  top row ....... search box | tab buttons (Entities/Weapons/NPCs/Vehicles/
	                  Props) | hint label
	  left sidebar .. category list ("All" + one row per GMod Category)
	  right ......... the icon grid: SpawnIcon (GMod's 3D model thumbnail,
	                  lua/vgui/SpawnIcon.lua) for everything with a model on
	                  disk, a text DButton otherwise

	CONTENT IS THE REGISTRY, not a curated hand list:
	  Entities   list.Get( "SpawnableEntities" )  +  hl2sb.GetSpawnableClasses()
	  Weapons    weapons.GetList()  (SWEP.Category / PrintName / WorldModel)
	  NPCs       list.Get( "NPC" )  +  a stock HL2 set (grouped Citizens/
	             Combine/Zombies/Xen/Wildlife)
	  Vehicles   list.Get( "Vehicles" )  +  the stock HL2 rides
	  Props      a stock set, grouped by folder
	  Entries merge on lowercase class; registry data (name/Category/model)
	  wins over the engine class list.  The cache is refreshed on every Open,
	  so lua reloads / addon changes are picked up.

	SPAWN DISPATCH (the command set the older menus proved):
	  weapon   gm_giveswep <class>
	  npc      gm_spawnnpc <class>
	  vehicle  gm_spawnvehicle <class> <model> <script>   (model-less
	           prop_vehicle = server crash, so the model always rides along)
	  else     gm_spawn <class> [model]

	THE CRASH RULES (inherited from the menus that came before, keep them):
	  * the frame is built ONCE and only ever SetVisible()d -- never removed
	    while a mouse event is inside it;
	  * a repopulate never runs inside the click that caused it -- it is
	    deferred one tick (timer.Simple( 0 ));
	  * cells are created through a per-frame budget (24 per tick), so opening
	    a big tab cannot create 400 panels in one frame;
	  * ASCII only -- the derma font has no CJK glyphs.

	CONSOLE:
	  +smenu / -smenu   hold-open (Q is bound to +smenu in cfg)
	  hl2sb_spawnmenu   toggle
-----------------------------------------------------------------------------]]

if ( not CLIENT ) then return end

local TAG    = "[HL2SB][SpawnMenu] "
local ICON   = 64
local BUDGET = 24		-- cells created per frame while a fill is pending

-- ---------------------------------------------------------------------------
-- stock content (everything the registries do not already carry)
-- ---------------------------------------------------------------------------

local STOCK_WEAPONS = {
	{ class = "weapon_crowbar",    name = "Crowbar" },
	{ class = "weapon_pistol",     name = "9mm Pistol" },
	{ class = "weapon_357",        name = ".357 Magnum" },
	{ class = "weapon_smg1",       name = "SMG" },
	{ class = "weapon_ar2",        name = "Pulse Rifle" },
	{ class = "weapon_shotgun",    name = "Shotgun" },
	{ class = "weapon_crossbow",   name = "Crossbow" },
	{ class = "weapon_frag",       name = "Grenade" },
	{ class = "weapon_rpg",        name = "RPG" },
	{ class = "weapon_physcannon", name = "Gravity Gun" },
	{ class = "weapon_physgun",    name = "Physics Gun" },
}

-- category, class list
local STOCK_NPCS = {
	{ cat = "HL2 Citizens", classes = { "npc_alyx", "npc_barney", "npc_kleiner", "npc_magnusson",
		"npc_eli", "npc_mossman", "npc_breen", "npc_monk", "npc_vortigaunt", "npc_dog", "npc_citizen" } },
	{ cat = "HL2 Combine",  classes = { "npc_combine_s", "npc_metropolice", "npc_manhack", "npc_stalker",
		"npc_cscanner", "npc_clawscanner", "npc_rollermine", "npc_turret_floor", "npc_turret_ceiling",
		"npc_strider", "npc_helicopter", "npc_hunter", "npc_combine_camera" } },
	{ cat = "HL2 Zombies",  classes = { "npc_zombie", "npc_zombie_torso", "npc_fastzombie",
		"npc_poisonzombie", "npc_headcrab", "npc_headcrab_fast", "npc_headcrab_black" } },
	{ cat = "HL2 Xen",      classes = { "npc_antlion", "npc_antlionguard", "npc_barnacle",
		"npc_sniper", "npc_combinegunship" } },
	{ cat = "HL2 Wildlife", classes = { "npc_crow", "npc_pigeon", "npc_seagull" } },
}

local STOCK_VEHICLES = {
	{ class = "prop_vehicle_prisoner_pod", name = "Chair",   model = "models/vehicles/prisoner_pod_inner.mdl", script = "scripts/vehicles/prisoner_pod.txt" },
	{ class = "prop_vehicle_jeep",         name = "Jeep",    model = "models/buggy.mdl",                       script = "scripts/vehicles/jeep.txt" },
	{ class = "prop_vehicle_airboat",      name = "Airboat", model = "models/airboat.mdl",                     script = "scripts/vehicles/airboat.txt" },
	{ class = "prop_vehicle_jeep",         name = "Jalopy",  model = "models/vehicle.mdl",                     script = "scripts/vehicles/jalopy.txt" },
}

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
				e.name     = tostring( ( istable( data ) and data.PrintName ) or spawnname )
				e.category = ( istable( data ) and isstring( data.Category ) and data.Category ~= "" ) and data.Category or nil
				e.model    = ( istable( data ) and isstring( data.Model ) ) and data.Model or ""

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

	-- the engine's SWEP registry: every loaded Lua SWEP lands in weapon.lua's
	-- table via weapon.register (weapon_nyangun and friends).  weapons.GetList()
	-- below is a DIFFERENT module whose list only fills through
	-- weapons.Register, which the stock loader never calls.
	if ( weapon ~= nil and weapon.getweapons ) then
		local ok, all = pcall( weapon.getweapons )
		if ( ok and istable( all ) ) then
			for class, w in pairs( all ) do
				if ( istable( w ) and w.Spawnable ~= false ) then
					local e, key = NewEntry( class )
					if ( e ) then
						e.name     = tostring( w.PrintName or class )
						e.category = ( isstring( w.Category ) and w.Category ~= "" ) and w.Category or "Other"
						e.model    = firstModel( w.WorldModel, w.ViewModel )
						e.cat      = "weapon"
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
					e.name      = tostring( w.PrintName or w.ClassName )
					e.category  = ( isstring( w.Category ) and w.Category ~= "" ) and w.Category or "Half-Life 2"
					e.model     = firstModel( w.WorldModel, w.ViewModel )
					e.spawnname = tostring( w.ClassName )
					e.cat       = "weapon"
					byKey[ key ] = e
				end
			end
		end
	end

	for _, w in ipairs( STOCK_WEAPONS ) do
		local e, key = NewEntry( w.class )
		if ( e and byKey[ key ] == nil ) then
			e.name     = w.name
			e.category = "Half-Life 2"
			e.cat      = "weapon"
			byKey[ key ] = e
		end
	end

	local out = {}
	for _, e in pairs( byKey ) do out[ #out + 1 ] = e end
	return SortEntries( out )
end

local function CollectNPCs()
	local byKey = {}

	local reg = ( list ~= nil and list.Get ) and list.Get( "NPC" ) or nil
	if ( istable( reg ) ) then
		for class, data in pairs( reg ) do
			local e, key = NewEntry( class )
			if ( e and istable( data ) ) then
				e.name       = tostring( data.Name or class )
				e.category   = ( isstring( data.Category ) and data.Category ~= "" ) and data.Category or "Other"
				e.model      = ( isstring( data.Model ) ) and data.Model or ""
				e.spawnname  = tostring( class )
				e.iconOverride = ( isstring( data.IconOverride ) ) and data.IconOverride or nil
				e.cat        = "npc"
				byKey[ key ] = e
			end
		end
	end

	for _, group in ipairs( STOCK_NPCS ) do
		for _, class in ipairs( group.classes ) do
			local e, key = NewEntry( class )
			if ( e and byKey[ key ] == nil ) then
				e.name     = class
				e.category = group.cat
				e.cat      = "npc"
				byKey[ key ] = e
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
					name       = tostring( data.Name or data.PrintName or spawnname ),
					class      = tostring( data.Class or spawnname ),
					key        = "v:" .. tostring( spawnname ),
					model      = data.Model,
					script     = ( isstring( kv.vehiclescript ) ) and kv.vehiclescript or "",
					cat        = "vehicle",
					spawnname  = tostring( spawnname ),
					iconOverride = ( isstring( data.IconOverride ) ) and data.IconOverride or nil,
					category   = ( isstring( data.Category ) and data.Category ~= "" ) and data.Category or nil,
				}
				byKey[ e.key ] = e
			end
		end
	end

	for _, v in ipairs( STOCK_VEHICLES ) do
		local e = {
			name     = v.name,
			class    = v.class,
			key      = v.class .. "|" .. v.model,
			model    = v.model,
			script   = v.script,
			cat      = "vehicle",
			category = "Half-Life 2",
		}
		byKey[ e.key ] = e
	end

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

local function SpawnEntry( e )
	if ( e == nil ) then return end
	local line

	if ( e.cat == "weapon" ) then
		line = "gm_giveswep " .. e.class
	elseif ( e.cat == "npc" ) then
		line = "gm_spawnnpc " .. e.class
	elseif ( e.cat == "vehicle" ) then
		-- the MODEL rides along: a model-less prop_vehicle is a server crash
		line = "gm_spawnvehicle " .. e.class
			.. ( ( e.model and e.model ~= "" ) and ( " " .. e.model ) or "" )
			.. ( ( e.script and e.script ~= "" ) and ( " " .. e.script ) or "" )
	elseif ( e.model ~= nil and e.model ~= "" ) then
		line = "gm_spawn " .. e.class .. " " .. e.model
	else
		line = "gm_spawn " .. e.class
	end

	print( TAG .. "spawn: " .. line )

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

	menu:AddOption( "Spawn 1", function() SpawnEntry( e ) end )
	menu:AddOption( "Spawn 5", function()
		for _ = 1, 5 do SpawnEntry( e ) end
	end )
	if ( menu.AddSpacer ) then menu:AddSpacer() end
	if ( SetClipboardText ) then
		menu:AddOption( "Copy class name", function() SetClipboardText( tostring( e.class ) ) end )
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

-- ⚠️ MOUSE INPUT IS A GATE IN THIS ENGINE, NOT INHERITED
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

-- GMod's icon conventions plus this fork's own (the C++ menu probed the same
-- order): the registry's IconOverride, the spawn name / class under entities/
-- and vgui/entities/, and the model's base name.  The file probe prepends
-- materials/; the returned name is the MATERIAL name (with .png for raw
-- images, without for .vmt).
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

local function MakeCell( e )
	-- 1) a shipped icon image: static and exact -- what GMod shows for
	--    everything that has one (materials/entities/<name>.png is its own
	--    convention; the vehicle/seat registrations carry IconOverride).
	local iconPath = ProbeIconPath( e )
	if ( iconPath ~= nil ) then
		local ok, btn = pcall( vgui.Create, "DImageButton" )
		if ( ok and IsValid( btn ) ) then
			btn:SetImage( iconPath )
			pcall( function() btn:SetTooltip( ( e.name or e.class ) .. "\n" .. e.class ) end )
			btn.DoClick = function() SpawnEntry( e ) end
			btn.DoRightClick = function() EntryMenu( e ) end
			return btn, "image"
		end
	end

	-- 2) a live 3D thumbnail for models.  No file.Exists gate on the MODEL:
	--    the Lua file API does not see every mounted model tree (hl2 content
	--    answered false for existing weapons), and a model that fails to come
	--    up is caught by the entity check below.
	local mdl = e.model or ""
	if ( mdl ~= "" ) then
		local ok, icon = pcall( vgui.Create, "SpawnIcon" )
		if ( ok and IsValid( icon ) ) then
			local okSet, errSet = pcall( function() icon:SetModel( mdl, 0, "" ) end )
			if ( okSet ) then
				-- did the model actually come up clientside?  A SpawnIcon whose
				-- DModelPanel has no entity paints an empty dark tile.
				local ent = icon.Entity
				if ( ent ~= nil and IsValid( ent ) ) then
					pcall( function() icon:SetTooltip( ( e.name or e.class ) .. "\n" .. e.class ) end )
					icon.DoClick = function() SpawnEntry( e ) end
					icon.DoRightClick = function() EntryMenu( e ) end
					-- GMod's SpawnIcon calls self:OpenMenu() on right click; keep
					-- the fork's DButton DoRightClick path covered as well.
					icon.OpenMenu = function() EntryMenu( e ) end
					return icon, "spawnicon"
				end
				print( TAG .. "no clientside model for '" .. mdl .. "' - text cell" )
			else
				print( TAG .. "SetModel failed for '" .. mdl .. "': " .. tostring( errSet ) )
			end
			if ( IsValid( icon ) ) then icon:Remove() end
		else
			print( TAG .. "vgui.Create( SpawnIcon ) failed: " .. tostring( icon ) )
		end
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
local g_IconsMade, g_TextsMade = 0, 0

local function FillStep()
	local n = 0
	while ( #g_Pending > 0 and n < BUDGET ) do
		local e = table.remove( g_Pending, 1 )
		n = n + 1

		if ( g_Grid ~= nil and IsValid( g_Grid ) ) then
			local ok, cell, kind = pcall( MakeCell, e )
			if ( not ok ) then
				g_Failed = g_Failed + 1
				print( TAG .. "cell failed for '" .. tostring( e.class ) .. "': " .. tostring( cell ) )
			else
				if ( kind == "spawnicon" ) then g_IconsMade = g_IconsMade + 1 else g_TextsMade = g_TextsMade + 1 end
				cell:SetSize( ICON, ICON )
				g_Grid:AddItem( cell )
			end
		end
	end

	if ( #g_Pending <= 0 ) then
		if ( g_Grid ~= nil and IsValid( g_Grid ) ) then
			g_Grid:InvalidateLayout( true )
		end
		AssertMouseInput()
		print( TAG .. "fill done: cells=" .. n .. " icons=" .. g_IconsMade .. " text=" .. g_TextsMade
			.. " failed=" .. g_Failed .. ", pending=" .. #g_Pending )
		g_IconsMade, g_TextsMade = 0, 0
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

	if ( g_Grid ~= nil and IsValid( g_Grid ) ) then
		g_Grid:Clear()
	end

	local entries = EntriesFor( g_ActiveTab )

	if ( bRebuildSidebar and g_Side ~= nil and IsValid( g_Side ) ) then
		g_Side:Clear()
		g_CatButtons = {}

		local rows = { "All" }
		for _, c in ipairs( CategoriesFor( entries ) ) do
			rows[ #rows + 1 ] = c
		end

		for _, c in ipairs( rows ) do
			local btn = vgui.Create( "DButton" )
			btn:SetText( c )
			btn:SetTall( 20 )
			btn:SetContentAlignment( 4 )
			btn.m_bDepressed = ( c == "All" )
			btn.DoClick = function()
				g_ActiveCat = ( c == "All" ) and nil or c
				for cc, bb in pairs( g_CatButtons ) do
					if ( IsValid( bb ) ) then
						bb.m_bDepressed = ( cc == c or c == "All" )
					end
				end
				Repopulate( false )
			end
			g_CatButtons[ c ] = btn
			g_Side:AddItem( btn )
		end
		g_Side:InvalidateLayout( true )
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
		g_Hint:SetText( #g_Pending .. " items | LMB spawn | RMB menu" )
	end

	-- The fill is driven by the frame's OnThink (the mechanism the previous
	-- menu proved) -- NOT by the client timer library, whose driver hook adds
	-- one more thing that can silently never fire.
	print( TAG .. "repopulate: tab=" .. tostring( g_ActiveTab ) .. " cat=" .. tostring( g_ActiveCat )
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
	local frame = vgui.Create( "DPanel" )
	frame:SetSize( ScrW() - 160, ScrH() - 140 )
	frame:SetPos( 80, 70 )

	-- HL2SB: this fork's DPanel paints nothing, so the world showed through
	-- the whole menu.  GMod's spawnmenu sits on an opaque dark sheet.
	frame.Paint = function( pnl, w, h )
		surface.SetDrawColor( 39, 43, 48, 255 )
		surface.DrawRect( 0, 0, w, h )
	end

	-- search
	local search = vgui.Create( "DTextEntry", frame )
	search:SetPos( 8, 8 )
	search:SetSize( 240, 22 )
	search:SetPlaceholderText( "search..." )
	search.OnTextChanged = function()
		-- never clear the grid inside the text entry's own dispatch
		timer.Simple( 0, function()
			if ( g_Frame ~= nil and IsValid( g_Frame ) and g_Frame:IsVisible() ) then
				Repopulate( false )
			end
		end )
	end

	-- tabs
	local tabs = {}
	local tx = 260
	local order  = { "entities", "weapons", "npcs", "vehicles", "props" }
	local labels = { entities = "Entities", weapons = "Weapons", npcs = "NPCs",
	                 vehicles = "Vehicles", props = "Props" }
	for _, id in ipairs( order ) do
		local btn = vgui.Create( "DButton", frame )
		btn:SetText( labels[ id ] )
		btn:SetPos( tx, 8 )
		btn:SetSize( 88, 22 )
		btn.m_bDepressed = ( id == "entities" )
		btn.DoClick = function() SetActiveTab( id ) end
		tabs[ id ] = btn
		tx = tx + 92
	end

	-- category sidebar
	local side = vgui.Create( "DPanelList", frame )
	side:SetPos( 8, 36 )
	side:SetSize( 170, frame:GetTall() - 44 )
	side:EnableVerticalScrollbar( true )
	side:SetSpacing( 2 )
	side:SetPadding( 4 )

	-- icon grid
	local grid = vgui.Create( "DPanelList", frame )
	grid:SetPos( 186, 36 )
	grid:SetSize( frame:GetWide() - 194, frame:GetTall() - 44 )
	grid:EnableHorizontal( true )
	grid:EnableVerticalScrollbar( true )
	grid:SetSpacing( 4 )
	grid:SetPadding( 6 )

	-- hint
	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( frame:GetWide() - 330, 12 )
	hint:SetSize( 320, 18 )
	hint:SetContentAlignment( 2 )
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

local function Open()
	if ( g_Frame == nil or not IsValid( g_Frame ) ) then
		BuildMenu()
	end
	KillFill()
	g_Cache = {}		-- re-read the registries: addons may have registered since

	for id, fn in pairs( Collectors ) do
		local ok, res = pcall( fn )
		print( TAG .. "collect " .. id .. ": " .. ( ( ok and type( res ) == "table" ) and #res or ( "FAILED " .. tostring( res ) ) ) )
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
	concommand.Add( "+smenu", function() Open() end, nil, "Open the spawn menu (hold)." )
	concommand.Add( "-smenu", function() Close() end, nil, "Close the spawn menu (release)." )
end

print( TAG .. "v3 loaded: registry content, category sidebar, SpawnIcon grid (Q = +smenu)" )
