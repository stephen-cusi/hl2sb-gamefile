--[[---------------------------------------------------------------------------
	HL2SB GMod-style spawn menu (simple port) - v2, proven-primitives build.

	v1 used DPropertySheet/DScroller and came up with an invisible tab strip
	(the sheet port's tab/scroller paint path still has gaps).  v2 rebuilds the
	same GMod-style UI from the primitives that are PROVEN to render in this
	fork (the minecraft menu's block grid used exactly these):

	  tab row ...... DButton row (one per category)
	  icon grid .... DPanelList (EnableHorizontal + EnableVerticalScrollbar)
	                 + SpawnIcon items      [cl_init.lua MCBlockPanel pattern]
	  search ....... DTextEntry
	  labels ....... ASCII only - the derma font has no CJK glyphs

	Spawn commands are the proven set: gm_spawn [model] / gm_giveswep /
	gm_spawnnpc / gm_spawnvehicle class model script.

	Load order: sorts after hl2sb_spawnmenu.lua, so the concommand.Add calls
	below overwrite the old +smenu / -smenu / hl2sb_spawnmenu handlers.
-----------------------------------------------------------------------------]]

local ICON = 64
local TAG = "[HL2SB][SpawnMenu] "

-- ---------------------------------------------------------------------------
-- curated content
-- ---------------------------------------------------------------------------

local HL2_WEAPONS = {
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
	{ class = "weapon_toolgun",    name = "Tool Gun" },
}

local HL2_NPCS = {
	"npc_citizen", "npc_alyx", "npc_barney", "npc_kleiner", "npc_magnusson",
	"npc_eli", "npc_mossman", "npc_breen", "npc_vortigaunt", "npc_dog",
	"npc_combine_s", "npc_metropolice", "npc_manhack", "npc_stalker",
	"npc_zombie", "npc_zombie_torso", "npc_fastzombie", "npc_poisonzombie",
	"npc_headcrab", "npc_headcrab_fast", "npc_headcrab_black",
	"npc_antlion", "npc_antlionguard", "npc_rollermine", "npc_turret_floor",
	"npc_crow", "npc_pigeon", "npc_seagull", "npc_strider", "npc_helicopter",
}

local HL2_VEHICLES = {
	{ class = "prop_vehicle_prisoner_pod", name = "Chair",   model = "models/vehicles/prisoner_pod_inner.mdl", script = "scripts/vehicles/prisoner_pod.txt" },
	{ class = "prop_vehicle_jeep",         name = "Jeep",    model = "models/buggy.mdl",                       script = "scripts/vehicles/jeep.txt" },
	{ class = "prop_vehicle_airboat",      name = "Airboat", model = "models/airboat.mdl",                     script = "scripts/vehicles/airboat.txt" },
}

local HL2_PROPS = {
	"models/props_junk/wood_crate001a.mdl",
	"models/props_junk/wood_pallet001a.mdl",
	"models/props_junk/garbage_takeoutcart001a.mdl",
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
	"models/props_lab/monitor01b.mdl",
	"models/props_lab/tpplug.mdl",
	"models/props_lab/pottery01a.mdl",
	"models/props_lab/crematorcase.mdl",
	"models/props_lab/labpanel01a.mdl",
	"models/props_lab/locker.mdl",
	"models/props_combine/combine_monitor.mdl",
	"models/props_combine/combine_interface.mdl",
	"models/props_wasteland/panel_leverhandle001a.mdl",
	"models/props_wasteland/light_spotlight01_lamp.mdl",
	"models/props_junk/TrafficCone001a.mdl",
	"models/props_junk/MetalBucket01a.mdl",
	"models/props_junk/CinderBlock01a.mdl",
	"models/props_junk/cardboard_box001a.mdl",
	"models/props_junk/cardboard_box004a.mdl",
	"models/props_junk/sawblade001a.mdl",
	"models/props_trainstation/trainstation_clock001.mdl",
	"models/props_trainstation/Bench001a.mdl",
	"models/props_canal/mattpipe.mdl",
	"models/props_canal/boat001a.mdl",
	"models/props_interiors/SinkKitchen01a.mdl",
	"models/props_interiors/VendingMachineSoda01a.mdl",
	"models/props_interiors/Furniture_Lamp01a.mdl",
	"models/props_interiors/Radiator01a.mdl",
	"models/props_borealis/bluebarrel001.mdl",
	"models/props_c17/suitcase_passenger_physics.mdl",
}

local TABS = {
	{ id = "entities", label = "Entities" },
	{ id = "weapons",  label = "Weapons" },
	{ id = "npcs",     label = "NPCs" },
	{ id = "vehicles", label = "Vehicles" },
	{ id = "props",    label = "Props" },
}

-- ---------------------------------------------------------------------------
-- spawn dispatch (same command set the original port proved)
-- ---------------------------------------------------------------------------

local function SpawnEntry( e )
	local line

	if ( e.cat == "weapon" ) then
		line = "gm_giveswep " .. e.class
	elseif ( e.cat == "npc" ) then
		line = "gm_spawnnpc " .. e.class
	elseif ( e.cat == "vehicle" ) then
		-- the MODEL is part of the spawn line: a model-less prop_vehicle is a
		-- server crash (CFourWheelVehiclePhysics::Initialize).
		line = "gm_spawnvehicle " .. e.class
			.. ( ( e.model and e.model ~= "" ) and ( " " .. e.model ) or "" )
			.. ( ( e.script and e.script ~= "" ) and ( " " .. e.script ) or "" )
	elseif ( e.model ~= nil and e.model ~= "" ) then
		line = "gm_spawn " .. e.class .. " " .. e.model
	else
		line = "gm_spawn " .. e.class
	end

	if ( engine and engine.ClientCmd ) then
		engine.ClientCmd( line )
	elseif ( RunConsoleCommand ) then
		RunConsoleCommand( line )
	end
end

-- ---------------------------------------------------------------------------
-- content sources: each returns { { name, class, model, script, cat } }
-- ---------------------------------------------------------------------------

local function GetEntityEntries()
	local out = {}

	local listTab = ( list ~= nil and list.Get ) and list.Get( "SpawnableEntities" ) or nil
	if ( listTab ) then
		for spawnname, data in pairs( listTab ) do
			local mdl = ""
			local stored = ( scripted_ents and scripted_ents.GetStored ) and scripted_ents.GetStored( spawnname )
			if ( stored and stored.t ) then
				if ( isstring( stored.t.Model ) ) then
					mdl = stored.t.Model
				elseif ( istable( stored.t.Model ) ) then
					mdl = tostring( stored.t.Model[ 1 ] or "" )
				end
			end

			out[ #out + 1 ] = {
				name = tostring( data.PrintName or spawnname ),
				class = tostring( spawnname ),
				model = mdl,
				cat = "entity",
			}
		end
	end

	table.sort( out, function( a, b ) return string.lower( a.name ) < string.lower( b.name ) end )
	return out
end

local function GetWeaponEntries()
	local out = {}

	if ( weapons and weapons.GetList ) then
		for _, w in pairs( weapons.GetList() ) do
			if ( w and w.ClassName and w.Spawnable ~= false ) then
				out[ #out + 1 ] = {
					name = tostring( w.PrintName or w.ClassName ),
					class = tostring( w.ClassName ),
					model = ( isstring( w.WorldModel ) and w.WorldModel )
						or ( isstring( w.ViewModel ) and w.ViewModel )
						or "",
					cat = "weapon",
				}
			end
		end
	end
	for _, w in ipairs( HL2_WEAPONS ) do
		out[ #out + 1 ] = { name = w.name, class = w.class, model = "", cat = "weapon" }
	end

	return out
end

local function GetNPCEntries()
	local out = {}
	for _, class in ipairs( HL2_NPCS ) do
		out[ #out + 1 ] = { name = class, class = class, model = "", cat = "npc" }
	end
	return out
end

local function GetVehicleEntries()
	local out = {}
	for _, v in ipairs( HL2_VEHICLES ) do
		out[ #out + 1 ] = {
			name = v.name, class = v.class, model = v.model, script = v.script, cat = "vehicle",
		}
	end
	return out
end

local function GetPropEntries()
	local out = {}
	for _, mdl in ipairs( HL2_PROPS ) do
		local short = string.gsub( mdl, "^.*/", "" )
		short = string.gsub( short, "%.mdl$", "" )
		out[ #out + 1 ] = { name = short, class = "prop_physics", model = mdl, cat = "prop" }
	end
	return out
end

local Sources = {
	entities = GetEntityEntries,
	weapons  = GetWeaponEntries,
	npcs     = GetNPCEntries,
	vehicles = GetVehicleEntries,
	props    = GetPropEntries,
}

-- ---------------------------------------------------------------------------
-- the window
-- ---------------------------------------------------------------------------

local g_Frame, g_List, g_Search, g_TabButtons = nil, nil, nil, {}
local g_ActiveTab = "entities"
local g_Icons = {}	-- visible icons, for the search filter

local function IconRightClick( e )
	local menu = vgui.Create( "DMenu" )
	menu:AddOption( "Spawn 1", function() SpawnEntry( e ) end )
	menu:AddOption( "Spawn 5", function()
		for _ = 1, 5 do SpawnEntry( e ) end
	end )
	menu:AddSpacer()
	menu:AddOption( "Copy class name", function()
		if ( SetClipboardText ) then SetClipboardText( tostring( e.class ) ) end
	end )
	menu:Open()
end

local function PopulateList( id, filter )
	if ( g_List == nil ) then return end

	g_List:Clear()
	g_Icons = {}

	local source = Sources[ id ]
	local entries = source and source() or {}

	filter = string.lower( tostring( filter or "" ) )

	for _, e in ipairs( entries ) do
		local nameLower = string.lower( e.name or e.class or "" )
		if ( filter == "" or string.find( nameLower, filter, 1, true ) ~= nil ) then
			local icon
			if ( e.model ~= nil and e.model ~= "" ) then
				icon = vgui.Create( "SpawnIcon" )
				icon:SetModel( e.model, 0 )
			else
				icon = vgui.Create( "DButton" )
				icon:SetText( e.name or e.class )
				icon:SetWrap( true )
				icon:SetContentAlignment( 5 )
			end

			icon:SetSize( ICON, ICON )
			icon:SetTooltip( e.name or e.class )
			icon.DoClick = function() SpawnEntry( e ) end
			icon.OpenMenu = function() IconRightClick( e ) end

			g_List:AddItem( icon )
			g_Icons[ #g_Icons + 1 ] = icon
		end
	end

	g_List:InvalidateLayout( true )
end

local function SetActiveTab( id )
	g_ActiveTab = id

	for tid, btn in pairs( g_TabButtons ) do
		btn.m_bDepressed = ( tid == id )
	end

	if ( g_Search ) then g_Search:SetValue( "" ) end
	PopulateList( id, "" )
end

local function BuildMenu()
	local frame = vgui.Create( "DPanel" )
	frame:SetSize( ScrW() - 160, ScrH() - 140 )
	frame:SetPos( 80, 70 )

	-- search box
	local search = vgui.Create( "DTextEntry", frame )
	search:SetPos( 8, 8 )
	search:SetSize( 240, 22 )
	search:SetPlaceholderText( "search..." )
	search.OnTextChanged = function( pnl )
		PopulateList( g_ActiveTab, pnl:GetValue() )
	end

	-- tab buttons
	local tabs = {}
	local tx = 260
	for _, tab in ipairs( TABS ) do
		local btn = vgui.Create( "DButton", frame )
		btn:SetText( tab.label )
		btn:SetPos( tx, 8 )
		btn:SetSize( 90, 22 )
		btn.DoClick = function()
			SetActiveTab( tab.id )
		end
		tabs[ tab.id ] = btn
		tx = tx + 94
	end

	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( frame:GetWide() - 330, 12 )
	hint:SetSize( 320, 18 )
	hint:SetContentAlignment( 2 )
	hint:SetText( "LMB spawn | RMB menu | release Q to close" )

	-- the icon list (DPanelList: the minecraft menu's proven grid)
	local list = vgui.Create( "DPanelList", frame )
	list:SetPos( 8, 36 )
	list:SetSize( frame:GetWide() - 16, frame:GetTall() - 44 )
	list:EnableHorizontal( true )
	list:EnableVerticalScrollbar( true )
	list:SetSpacing( 4 )
	list:SetPadding( 6 )

	g_Frame = frame
	g_List = list
	g_Search = search
	g_TabButtons = tabs

	frame:MakePopup()
	frame:SetVisible( false )
end

local function Open()
	if ( g_Frame == nil ) then
		BuildMenu()
	end
	g_Search:SetValue( "" )
	SetActiveTab( g_ActiveTab or "entities" )
	g_Frame:SetVisible( true )
	g_Frame:MakePopup()
end

local function Close()
	if ( g_Frame ~= nil and IsValid( g_Frame ) ) then
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

-- entry points (sort order makes these overwrite hl2sb_spawnmenu.lua's)
if ( concommand and concommand.Add ) then
	concommand.Add( "hl2sb_spawnmenu", function()
		Toggle()
	end, nil, "Open the GMod-style Lua spawn menu." )

	concommand.Add( "+smenu", function()
		Open()
	end, nil, "Open the spawn menu (hold)." )

	concommand.Add( "-smenu", function()
		Close()
	end, nil, "Close the spawn menu (release)." )
end

print( TAG .. "GMod-style spawn menu v2 loaded (Entities/Weapons/NPCs/Vehicles/Props; Q = +smenu)" )
