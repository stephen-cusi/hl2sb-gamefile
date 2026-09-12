--[[---------------------------------------------------------
	HL2SB panel-docking PROBE (client realm).  Temporary diagnostic.

	Usage (in game console, no quotes needed):

		lua_dofile_cl lua/hl2sb_dock_probe.lua

	hl2sb_dock_test.lua checks the geometry.  This one checks the two
	machineries behind it, so a failure says WHICH one broke:

	  * the vgui library table must NOT have been clobbered by the new Panel
	    bindings (vgui.Label / vgui.Panel / ... must still be the C factories,
	    and the new methods must live on the "Panel" metatable only),
	  * InvalidateLayout( true ) must lay out a panel created in the SAME
	    frame (before any paint/think has applied the scheme),
	  * a parent's Lua OnChildAdded must actually run -- DListLayout /
	    DDragBase dock their children from there, so a row that was never
	    docked shows up as y = 0 for every child.

	Section 3 of hl2sb_dock_test.lua only notices a missing OnChildAdded
	through the resulting height.  This one prints the child positions.
-----------------------------------------------------------]]

local function say( ... )
	print( "[dock-probe]", ... )
end

local function run( name, fn )
	local ok, err = pcall( fn )
	if ( !ok ) then
		say( name .. " -> ERROR: " .. tostring( err ) )
	end
end

-- 1) the vgui library table vs the Panel metatable
run( "vgui-table", function()
	local m = FindMetaTable( "Panel" )

	say( "type(vgui.Label)=" .. type( vgui.Label )
		.. " type(vgui.Panel)=" .. type( vgui.Panel )
		.. " type(vgui.Create)=" .. type( vgui.Create )
		.. " type(vgui.CreateX)=" .. type( vgui.CreateX )
		.. "   (want all function)" )

	say( "rawget(vgui,'Label')==vgui.Label -> " .. tostring( rawget( vgui, "Label" ) == vgui.Label ) )

	-- the new bindings belong to the metatable, NOT to the vgui library
	local leaked = {}
	for _, k in ipairs( { "SizeToChildren", "GetChildrenSize", "ChildrenSize",
		"GetChildren", "InvalidateParentLayout", "SetDock", "SetDockMargin",
		"SetDockPadding", "Dock", "SetTall", "SetWide" } ) do
		if ( rawget( vgui, k ) ~= nil ) then table.insert( leaked, k ) end
	end
	say( "vgui[] pollution: " .. ( #leaked == 0 and "none (good)" or table.concat( leaked, "," ) ) )

	local missing = {}
	for _, k in ipairs( { "SizeToChildren", "GetChildrenSize", "ChildrenSize",
		"GetChildren", "InvalidateParentLayout" } ) do
		if ( m[ k ] == nil ) then table.insert( missing, k ) end
	end
	say( "Panel metatable missing: " .. ( #missing == 0 and "none (good)" or table.concat( missing, "," ) ) )

	-- The DOCK enum the engine's dock pass switches on:
	-- NODOCK=0 FILL=1 LEFT=2 RIGHT=3 TOP=4 BOTTOM=5.
	-- A swapped TOP/RIGHT here stays invisible until geometry is measured: a
	-- Dock( TOP ) child then takes the RIGHT branch (pinned to the right edge at
	-- full height, consuming no vertical space).
	say( "DOCK enum: NODOCK=" .. tostring( NODOCK ) .. " FILL=" .. tostring( FILL )
		.. " LEFT=" .. tostring( LEFT ) .. " RIGHT=" .. tostring( RIGHT )
		.. " TOP=" .. tostring( TOP ) .. " BOTTOM=" .. tostring( BOTTOM )
		.. "   (want 0 1 2 3 4 5)" )

	local dt = _E and _E.DOCK_TYPE
	say( "_E.DOCK_TYPE: " .. tostring( dt and dt.NONE ) .. " " .. tostring( dt and dt.FILL )
		.. " " .. tostring( dt and dt.LEFT ) .. " " .. tostring( dt and dt.RIGHT )
		.. " " .. tostring( dt and dt.TOP ) .. " " .. tostring( dt and dt.BOTTOM )
		.. "   (want 0 1 2 3 4 5)" )
end )

-- 2) same-frame layout: TOP 40 + FILL inside a 400x300 parent
run( "same-frame-layout", function()
	local p = vgui.Create( "DPanel" )
	p:SetSize( 400, 300 )

	local a = vgui.Create( "DPanel", p )
	a:Dock( TOP )
	a:SetTall( 40 )

	local b = vgui.Create( "DPanel", p )
	b:Dock( FILL )

	say( "before InvalidateLayout: A=" .. a:GetY() .. "," .. a:GetTall()
		.. " B=" .. b:GetY() .. "," .. b:GetTall() )

	p:InvalidateLayout( true )

	say( "after  InvalidateLayout: A=" .. a:GetY() .. "," .. a:GetTall()
		.. " B=" .. b:GetY() .. "," .. b:GetTall()
		.. "   (want A=0,40 B=40,260)" )

	p:Remove()
end )

-- 3) OnChildAdded reach: DDragBase/DListLayout dock their children from Lua
run( "onchildadded", function()
	local f = vgui.Create( "DFrame" )
	f:SetSize( 400, 300 )

	local l = vgui.Create( "DListLayout", f )
	l:Dock( TOP )

	for i = 1, 3 do
		local d = vgui.Create( "DButton", l )
		d:SetTall( 30 )
		d:SetText( "row " .. i )
	end

	l:InvalidateLayout( true )
	f:InvalidateLayout( true )

	local kids = l:GetChildren()
	local ys = {}
	for i = 1, #kids do
		table.insert( ys, kids[ i ]:GetY() .. "/" .. kids[ i ]:GetTall() )
	end

	say( "rows(y/tall)=" .. table.concat( ys, " " )
		.. "  list h=" .. l:GetTall()
		.. "   (want y/tall 0/30 30/30 60/30 and list h=90)" )

	f:Remove()
end )

-- 4) SizeToChildren on an empty panel must yield 0, not the 64x24 default
run( "sizetochildren", function()
	local p = vgui.Create( "DPanel" )
	p:SetSize( 400, 300 )

	local child = vgui.Create( "DPanel", p )
	child:Dock( TOP )
	child:SetTall( 50 )

	child:SizeToChildren( false, true )

	say( "empty child h=" .. child:GetTall()
		.. " GetChildrenSize=" .. tostring( child:GetChildrenSize() )
		.. "   (want h=0)" )

	p:Remove()
end )

say( "done - also check that the console above has NO 'attempt to call a Panel value'" )
