--[[---------------------------------------------------------
	HL2SB panel docking self-test (client realm).

	Usage (in game console, no quotes needed):

		lua_dofile_cl lua/hl2sb_dock_test.lua

	Checks the GMod layout API bindings and the docking geometry that
	experiment-source#14 is about.  Every section is wrapped so one failure
	still reports the others.  Safe: it only creates panels and removes them.
-----------------------------------------------------------]]

local function say( ... )
	print( "[dock-test]", ... )
end

local function run( name, fn )
	local ok, err = pcall( fn )
	if ( !ok ) then
		say( name .. " -> ERROR: " .. tostring( err ) )
	end
end

-- 1) the GMod layout API must exist at all (it was nil before the fix)
run( "bindings", function()
	local m = FindMetaTable( "Panel" )
	say( "SizeToChildren=" .. tostring( m.SizeToChildren )
		.. " GetChildrenSize=" .. tostring( m.GetChildrenSize )
		.. " ChildrenSize=" .. tostring( m.ChildrenSize )
		.. " GetChildren=" .. tostring( m.GetChildren )
		.. "  (want all function)" )
end )

-- 2) engine dock geometry: a TOP child then a FILL child
run( "dock-geometry", function()
	local p = vgui.Create( "DPanel" )
	p:SetSize( 400, 300 )

	local a = vgui.Create( "DPanel", p )
	a:Dock( TOP )
	a:SetTall( 40 )

	local b = vgui.Create( "DPanel", p )
	b:Dock( FILL )

	p:InvalidateLayout( true )

	say( "A y=" .. a:GetY() .. " h=" .. a:GetTall()
		.. " | B y=" .. b:GetY() .. " h=" .. b:GetTall()
		.. "   (want A y=0 h=40 | B y=40 h=260)" )

	p:Remove()
end )

-- 3) contents-derived height - this is the one that used to break
run( "sizetochildren", function()
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

	say( "DListLayout h=" .. tostring( l:GetTall() )
		.. " children=" .. tostring( #l:GetChildren() )
		.. "   (want h=90 children=3)" )

	f:Remove()
end )

-- 4) same but through SizeToChildren explicitly
run( "SizeToChildren", function()
	local p = vgui.Create( "DPanel" )
	p:SetSize( 400, 300 )

	local child = vgui.Create( "DPanel", p )
	child:Dock( TOP )
	child:SetTall( 50 )

	child:SizeToChildren( false, true )

	say( "child h after SizeToChildren(false,true)=" .. child:GetTall()
		.. " GetChildrenSize=" .. tostring( child:GetChildrenSize() ) )

	p:Remove()
end )

say( "done - please paste this output back" )
