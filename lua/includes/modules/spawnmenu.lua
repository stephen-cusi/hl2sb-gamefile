
-- ===========================================================================
-- HL2SB: the engine half of this library.
--
-- In GMod, `spawnmenu` is a C LIBRARY registered by the engine before any Lua
-- runs, and this file (GMod's lua/includes/modules/spawnmenu.lua) captures it
-- here as the local `spawnmenu_engine` and then re-opens the SAME global with
-- module().  This fork never bound it (zero hits for PopulateFromTextFiles /
-- SaveToTextFiles anywhere in source-engine), so the capture yielded nil and
-- BOTH entry points died:
--
--     spawnmenu/spawnmenu.lua -> GM:PopulatePropMenu()
--         spawnmenu.PopulateFromEngineTextFiles()                  [line 240]
--           -> "attempt to index a nil value (local 'spawnmenu_engine')"
--     spawnmenu/creationmenu/content/contenttypes/custom.lua:180 CheckIfAnyVisible
--     spawnmenu/creationmenu/content/contenttypes/custom.lua:256 OnSaveSpawnlist
--         spawnmenu.DoSaveToTextFiles( props )
--
-- and hook.lua UNREGISTERS a hook that throws, so PopulatePropMenu -- the only
-- thing that fills the Props/Custom spawnlist tree -- died on the first call and
-- never ran again.  That is the whole "props tab is empty" symptom.
--
-- Rather than write a C++ spawnlist parser, the two functions are provided in
-- Lua on top of bindings this engine really has:
--   * file.Find( dir )            (public/lua/lfilesystem.cpp:635 -- dir only,
--                                  it appends "/*" itself and always uses "MOD")
--   * the global KeyValues( name ) (public/lua/tier1/LKeyValues.cpp:410) with
--     LoadFromFile / SaveToFile / GetFirstSubKey / GetNextKey / GetName /
--     GetString, plus the NULL_KEYVALUES sentinel (:430)
--   * file.Open( path, mode, "MOD" )
-- The shipped spawnlists are Source KeyValues text ("TableToKeyValues" header),
-- which is exactly what KeyValues::LoadFromFile reads.
--
-- Not a byte-for-byte clone of GMod's C++: it reads settings/spawnlist_default
-- (the shipped set) and then settings/spawnlist (the user's saved set, which the
-- real engine takes precedence over), and it reports a bare filename as
-- strFilename -- the same thing the C++ passed, which is what keeps the
-- "001-construction props" ordering in custom.lua:143 SortedPairs( Props ).
-- ===========================================================================

-- HL2SB: GMod's first line.  In GMod this is the C library; here it is nil
-- unless the engine ever grows one, in which case the fallback below is skipped.
local spawnmenu_engine = spawnmenu

local function hl2sb_KVToTable( kv )

	local t = {}

	if ( kv == nil or kv == NULL_KEYVALUES ) then return t end
	if ( kv.GetFirstSubKey == nil ) then return t end

	local sub = kv:GetFirstSubKey()

	while ( sub ~= nil and sub ~= NULL_KEYVALUES ) do

		local k = sub:GetName()
		local s = sub:GetString()

		if ( s == nil or s == "" ) then
			-- No scalar value: either a nested block or a genuinely empty key.
			local nested = hl2sb_KVToTable( sub )
			if ( next( nested ) ~= nil ) then
				t[ k ] = nested
			else
				t[ k ] = ""
			end
		else
			t[ k ] = s
		end

		sub = sub:GetNextKey()

	end

	return t

end

-- GMod's KeyValues parser hands back "contents" keyed "1".."n" (and so does the
-- table above); re-index it as a real array so SortedPairs( contents ) in
-- custom.lua:159 yields the authored order instead of a string sort
-- (1, 10, 100, 101, ...).
local function hl2sb_NormaliseContents( contents )

	if ( type( contents ) ~= "table" ) then return contents end

	local keys = table.GetKeys( contents )
	local allNumeric = #keys > 0

	for _, k in ipairs( keys ) do
		if ( tonumber( k ) == nil ) then allNumeric = false break end
	end

	if ( not allNumeric ) then return contents end

	local out = {}
	local i = 0
	local maxN = 0

	for _, k in ipairs( keys ) do
		local n = tonumber( k )
		if ( n > maxN ) then maxN = n end
	end

	for n = 1, maxN do
		local v = contents[ tostring( n ) ]
		if ( v == nil ) then v = contents[ n ] end
		if ( v ~= nil ) then
			i = i + 1
			out[ i ] = v
		end
	end

	return out

end

local function hl2sb_PopulateDir( dir, callback, seen )

	local files = file.Find( dir )
	if ( files == nil ) then return end

	table.sort( files )

	for _, fname in ipairs( files ) do

		if ( fname:sub( -4 ) == ".txt" and not seen[ fname ] ) then

			seen[ fname ] = true

			local path = dir .. "/" .. fname
			local kv = KeyValues( fname )
			local loaded = false

			if ( kv ~= nil and kv.LoadFromFile ~= nil ) then
				local ok, res = pcall( kv.LoadFromFile, kv, path )
				loaded = ( ok and res )
			end

			if ( loaded ) then

				local t = hl2sb_KVToTable( kv )

				callback(
					fname,
					t.name,
					hl2sb_NormaliseContents( t.contents ),
					t.icon,
					tonumber( t.id ) or 0,
					tonumber( t.parentid ) or 0,
					t.needsapp
				)

			else
				Msg( "[HL2SB] spawnmenu: could not read " .. path .. "\n" )
			end

		end

	end

end

if ( spawnmenu_engine == nil or spawnmenu_engine.PopulateFromTextFiles == nil ) then

	spawnmenu_engine = {}

	function spawnmenu_engine.PopulateFromTextFiles( callback )

		local seen = {}

		hl2sb_PopulateDir( "settings/spawnlist_default", callback, seen )
		hl2sb_PopulateDir( "settings/spawnlist", callback, seen )

	end

	-- custom.lua:256 -> spawnmenu.DoSaveToTextFiles( props ), and props values
	-- are already finished KeyValues TEXT (custom.lua:107 uses
	-- util.TableToKeyValues), so this is a plain write.  module() has not run
	-- yet, so use file.Open directly (extensions/file.lua's file.Write is
	-- hard-wired to the DATA path).
	function spawnmenu_engine.SaveToTextFiles( props )

		if ( type( props ) ~= "table" ) then return end

		for filename, data in pairs( props ) do

			if ( type( data ) == "string" ) then

				local path = "settings/spawnlist/" .. filename .. ".txt"
				local f = file.Open( path, "wb", "MOD" )

				if ( f ~= nil ) then
					f:Write( data )
					f:Close()
				else
					Msg( "[HL2SB] spawnmenu: could not write " .. path .. "\n" )
				end

			end

		end

	end

	Msg( "[HL2SB] spawnmenu: installed the Lua spawnlist reader (no engine spawnmenu library).\n" )

end

module( "spawnmenu", package.seeall )

local g_ToolMenu = {}
local CreationMenus = {}
local PropTable = {}
local PropTableCustom = {}

local ActiveToolPanel = nil
local ActiveSpawnlistID = 1000

--[[---------------------------------------------------------

	Tool Tabs

-----------------------------------------------------------]]

function SetActiveControlPanel( pnl )
	ActiveToolPanel = pnl
end

function ActiveControlPanel()
	return ActiveToolPanel
end

function GetTools()
	return g_ToolMenu
end

function GetToolMenu( name, label, icon )

	--
	-- This is a dirty hack so that Main stays at the front of the tabs.
	--
	if ( name == "Main" ) then name = "AAAAAAA_Main" end

	label = label or name
	icon = icon or "icon16/wrench.png"

	for k, v in ipairs( g_ToolMenu ) do

		if ( v.Name == name ) then return v.Items end

	end

	local NewMenu = { Name = name, Items = {}, Label = label, Icon = icon }
	table.insert( g_ToolMenu, NewMenu )

	--
	-- Order the tabs by NAME
	--
	table.SortByMember( g_ToolMenu, "Name", true )

	return NewMenu.Items

end

function ClearToolMenus()

	g_ToolMenu = {}

end

function AddToolTab( strName, strLabel, Icon )

	GetToolMenu( strName, strLabel, Icon )

end

function SwitchToolTab( id )

	local Tab = g_SpawnMenu:GetToolMenu():GetToolPanel( id )
	if ( !IsValid( Tab ) or !IsValid( Tab.PropertySheetTab ) ) then return end

	Tab.PropertySheetTab:DoClick()

end

function ActivateToolPanel( tabId, ctrlPnl, toolName )

	local Tab = g_SpawnMenu:GetToolMenu():GetToolPanel( tabId )
	if ( !IsValid( Tab ) ) then return end

	spawnmenu.SetActiveControlPanel( ctrlPnl )

	if ( ctrlPnl ) then
		Tab:SetActive( ctrlPnl )
	end

	SwitchToolTab( tabId )

	if ( toolName && Tab.SetActiveToolText ) then
		Tab:SetActiveToolText( toolName )
	end

end

-- While technically tool class names CAN be duplicate, it normally should never happen.
function ActivateTool( strName, noCommand )

	-- I really don't like this triple loop
	for tab, v in ipairs( g_ToolMenu ) do
		for _, category in pairs( v.Items ) do
			for _, item in pairs( category ) do

				if ( istable( item ) && item.ItemName && item.ItemName == strName ) then

					if ( !noCommand && item.Command && string.len( item.Command ) > 1 ) then
						RunConsoleCommand( unpack( string.Explode( " ", item.Command ) ) )
					end

					local cp = controlpanel.Get( strName )
					if ( !cp:GetInitialized() ) then
						cp:FillViaTable( { Text = item.Text, ControlPanelBuildFunction = item.CPanelFunction } )
					end

					ActivateToolPanel( tab, cp, strName )

					return

				end

			end
		end
	end

end

function AddToolCategory( tab, RealName, PrintName )

	local Menu = GetToolMenu( tab )

	-- Does this category already exist?
	for k, v in ipairs( Menu ) do

		if ( v.Text == PrintName ) then return end
		if ( v.ItemName == RealName ) then return end

	end

	table.insert( Menu, { Text = PrintName, ItemName = RealName } )

end

function AddToolMenuOption( tab, category, itemname, text, command, controls, cpanelfunction, TheTable )

	local Menu = GetToolMenu( tab )
	local CategoryTable = nil

	for k, v in ipairs( Menu ) do
		if ( v.ItemName && v.ItemName == category ) then CategoryTable = v break end
	end

	-- No table found.. lets create one
	if ( !CategoryTable ) then
		CategoryTable = { Text = "#" .. category, ItemName = category }
		table.insert( Menu, CategoryTable )
	end

	TheTable = TheTable or {}

	TheTable.ItemName = itemname
	TheTable.Text = text
	TheTable.Command = command
	TheTable.Controls = controls
	TheTable.CPanelFunction = cpanelfunction

	table.insert( CategoryTable, TheTable )

	-- Keep the table sorted
	table.SortByMember( CategoryTable, "Text", true )

end

--[[---------------------------------------------------------

	Creation Tabs

-----------------------------------------------------------]]
function AddCreationTab( strName, pFunction, pMaterial, iOrder, strTooltip )

	iOrder = iOrder or 1000

	pMaterial = pMaterial or "icon16/exclamation.png"

	CreationMenus[ strName ] = { Function = pFunction, Icon = pMaterial, Order = iOrder, Tooltip = strTooltip }

end

function GetCreationTabs()

	return CreationMenus

end

function SwitchCreationTab( id )

	local tab = g_SpawnMenu:GetCreationMenu():GetCreationTab( id )
	if ( !tab or !IsValid( tab.Tab ) ) then return end

	tab.Tab:DoClick()

end

--[[---------------------------------------------------------

	Spawn lists

-----------------------------------------------------------]]
function GetPropTable()

	return PropTable

end

function GetCustomPropTable()

	return PropTableCustom

end

function AddPropCategory( strFilename, strName, tabContents, icon, id, parentid, needsapp )

	PropTableCustom[ strFilename ] = {
		name = strName,
		contents = tabContents,
		icon = icon,
		id = id or ActiveSpawnlistID,
		parentid = parentid or 0,
		needsapp = needsapp
	}

	if ( !id ) then ActiveSpawnlistID = ActiveSpawnlistID + 1 end

end

-- Populate the spawnmenu from the text files (engine)
function PopulateFromEngineTextFiles()

	-- Reset the already loaded prop list before loading them again.
	-- This caused the spawnlists to duplicate into crazy trees when spawnmenu_reload'ing after saving edited spawnlists
	PropTable = {}

	spawnmenu_engine.PopulateFromTextFiles( function( strFilename, strName, tabContents, icon, id, parentid, needsapp )
		PropTable[ strFilename ] = {
			name = strName,
			contents = tabContents,
			icon = icon,
			id = id,
			parentid = parentid or 0,
			needsapp = needsapp
		}
	end )

end

-- Save the spawnfists to text files (engine)
function DoSaveToTextFiles( props )

	spawnmenu_engine.SaveToTextFiles( props )

end

--[[

Content Providers

Functions that populate the spawnmenu from the spawnmenu txt files.

function MyFunction( ContentPanel, ObjectTable )

	local myspawnicon = CreateSpawnicon( ObjectTable.model )
	ContentPanel:AddItem( myspawnicon )

end

spawnmenu.AddContentType( "model", MyFunction )

--]]

local cp = {}

function AddContentType( name, func )
	cp[ name ] = func
end

function GetContentType( name )

	if ( !name ) then
		ErrorNoHaltWithStack( "spawnmenu.GetContentType got an invalid value\n" )
		return
	end

	if ( !cp[ name ] ) then

		cp[ name ] = function() end
		Msg( "spawnmenu.GetContentType( ", name, " ) - not found!\n" )

	end

	return cp[ name ]
end

function CreateContentIcon( type, parent, tbl )

	local ctrlpnl = GetContentType( type )
	if ( ctrlpnl ) then return ctrlpnl( parent, tbl ) end

end
