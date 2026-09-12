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

--[[-----------------------------------------------------------------------
	5) the GMod enumeration tables the engine now publishes.

	sh_enumerations.lua only ever reported a MISSING table as a hard error; a
	table that existed but was EMPTY (its own `_E.X = _E.X or {}` stub winning)
	silently left every global it derives nil.  DOCK_TYPE shipped that way with
	TOP/RIGHT swapped, and RENDERMODE_* / PLAYER_* / SURF_* / IN_* / the stencil
	tables were nil for the same reason.

	This section prints, for each of those tables, the raw members the engine
	published AND the globals the file derived from them, so a table that is
	missing, empty, or populated with the WRONG values is visible in one run.
	Every row is "name = value".
--------------------------------------------------------------------------]]

run( "gmod-enums", function()
	local function dump( label, t, keys )
		if ( t == nil ) then
			say( label .. ": MISSING (the file's shutdown stub will win)" )
			return
		end

		local n = 0
		for _ in pairs( t ) do n = n + 1 end

		local parts = {}
		for _, k in ipairs( keys ) do
			parts[ #parts + 1 ] = k .. "=" .. tostring( t[ k ] )
		end

		say( label .. " [" .. n .. " members] " .. table.concat( parts, " " ) )
	end

	local function g( ... )
		local parts = {}
		for _, name in ipairs( { ... } ) do
			parts[ #parts + 1 ] = name .. "=" .. tostring( rawget( _G, name ) )
		end
		say( "  -> " .. table.concat( parts, " " ) )
	end

	local E = _E or {}

	-- which tables the engine must have published at all
	local required = {
		"DOCK_TYPE", "CULL_MODE", "STENCIL_COMPARISON_FUNCTION", "STENCIL_OPERATION",
		"RENDER_MODE", "RENDER_GROUP", "EDICT_FLAG", "PLAYER_ANIMATION", "INPUT",
		"SURFACE", "USABILITY_TYPE", "CONTENTS", "COLLISION_GROUP", "FCVAR",
		"SOLID_FLAG", "GESTURE_SLOT", "LIFE", "MASK", "MOVE_COLLIDE", "MOVE_TYPE",
		"OBSERVER_MODE", "SOLID", "SOUND_CHANNEL", "DAMAGE_TYPE", "HIT_GROUP",
		"MATERIAL_TYPE", "ACTIVITY", "BUTTON", "ENTITY_EFFECT", "ENGINE_FLAG",
	}

	local missing, empty = {}, {}
	for _, key in ipairs( required ) do
		local t = _E and _E[ key ]
		if ( t == nil ) then
			missing[ #missing + 1 ] = key
		elseif ( next( t ) == nil ) then
			empty[ #empty + 1 ] = key
		end
	end

	say( "engine _E tables missing: " .. ( #missing == 0 and "none" or table.concat( missing, ", " ) ) )
	say( "engine _E tables empty:   " .. ( #empty == 0 and "none" or table.concat( empty, ", " ) )
		.. "   (want none: an empty table means the file's stub won)" )

	-- the four the stubs got wrong, plus the tables that were absent entirely
	dump( "_E.DOCK_TYPE (want NONE=0 FILL=1 LEFT=2 RIGHT=3 TOP=4 BOTTOM=5)",
		E.DOCK_TYPE, { "NONE", "FILL", "LEFT", "RIGHT", "TOP", "BOTTOM" } )
	g( "NODOCK", "FILL", "LEFT", "RIGHT", "TOP", "BOTTOM" )

	dump( "_E.CULL_MODE (want COUNTER_CLOCKWISE=0 CLOCKWISE=1)",
		E.CULL_MODE, { "COUNTER_CLOCKWISE", "CLOCKWISE" } )
	g( "MATERIAL_CULLMODE_CCW", "MATERIAL_CULLMODE_CW" )

	dump( "_E.STENCIL_COMPARISON_FUNCTION (want NEVER=0 LESS=1 EQUAL=2 LESS_OR_EQUAL=3 GREATER=4 NOT_EQUAL=5 GREATER_OR_EQUAL=6 ALWAYS=7)",
		E.STENCIL_COMPARISON_FUNCTION,
		{ "NEVER", "LESS", "EQUAL", "LESS_OR_EQUAL", "GREATER", "NOT_EQUAL", "GREATER_OR_EQUAL", "ALWAYS" } )
	g( "STENCIL_NEVER", "STENCIL_LESSEQUAL", "STENCIL_GREATEREQUAL", "STENCIL_ALWAYS" )

	dump( "_E.STENCIL_OPERATION (want KEEP=0 ZERO=1 REPLACE=2 INCREMENT_CLAMP=3 DECREMENT_CLAMP=4 INVERT=5 INCREMENT_WRAP=6 DECREMENT_WRAP=7)",
		E.STENCIL_OPERATION,
		{ "KEEP", "ZERO", "REPLACE", "INCREMENT_CLAMP", "DECREMENT_CLAMP", "INVERT", "INCREMENT_WRAP", "DECREMENT_WRAP" } )
	g( "STENCIL_INCRSAT", "STENCIL_DECRSAT", "STENCIL_INCR", "STENCIL_DECR" )

	dump( "_E.RENDER_MODE (want NORMAL=0 TRANSPARENT_COLOR=1 TRANSPARENT_TEXTURE=2 GLOW=3 TRANSPARENT_ALPHA=4 TRANSPARENT_ADD=5 ENVIRONMENTAL=6 NONE=10)",
		E.RENDER_MODE,
		{ "NORMAL", "TRANSPARENT_COLOR", "TRANSPARENT_TEXTURE", "GLOW", "TRANSPARENT_ALPHA",
			"TRANSPARENT_ADD", "ENVIRONMENTAL", "TRANSPARENT_ADD_FRAME_BLEND",
			"TRANSPARENT_ALPHA_ADD", "WORLD_GLOW", "NONE" } )
	g( "RENDERMODE_NORMAL", "RENDERMODE_TRANSCOLOR", "RENDERMODE_GLOW", "RENDERMODE_NONE" )

	dump( "_E.RENDER_GROUP (want OPAQUE_STATIC_HUGE=0 OPAQUE_ENTITY_HUGE=1 OPAQUE_STATIC=6 OPAQUE_ENTITY=7 TRANSLUCENT_ENTITY=8 TWOPASS=9 VIEW_MODEL_OPAQUE=10 OPAQUE_BRUSH=12 OTHER=13)",
		E.RENDER_GROUP,
		{ "OPAQUE_STATIC_HUGE", "OPAQUE_ENTITY_HUGE", "OPAQUE_STATIC", "OPAQUE_ENTITY",
			"TRANSLUCENT_ENTITY", "TWOPASS", "VIEW_MODEL_OPAQUE", "VIEW_MODEL_TRANSLUCENT",
			"OPAQUE_BRUSH", "OTHER" } )
	g( "RENDERGROUP_STATIC", "RENDERGROUP_OPAQUE", "RENDERGROUP_TRANSLUCENT", "RENDERGROUP_VIEWMODEL" )

	dump( "_E.EDICT_FLAG (want ALWAYS=4 DONTSEND=16 PVSCHECK=32)",
		E.EDICT_FLAG, { "ALWAYS", "DONTSEND", "PVSCHECK" } )
	g( "TRANSMIT_ALWAYS", "TRANSMIT_NEVER", "TRANSMIT_PVS" )

	dump( "_E.PLAYER_ANIMATION (want IDLE=0 WALK=1 JUMP=2 SUPER_JUMP=3 DIE=4 ATTACK1=5)",
		E.PLAYER_ANIMATION, { "IDLE", "WALK", "JUMP", "SUPER_JUMP", "DIE", "ATTACK1" } )
	g( "PLAYER_IDLE", "PLAYER_JUMP", "PLAYER_SUPERJUMP" )

	-- INPUT / SURFACE are consumed by the merge loop, so the globals carry an
	-- IN_ / SURF_ prefix rather than the table's own names.
	dump( "_E.INPUT (want ATTACK=1 JUMP=2 DUCK=4 FORWARD=8 LEFT=128 RIGHT=256)",
		E.INPUT, { "ATTACK", "JUMP", "DUCK", "FORWARD", "LEFT", "RIGHT" } )
	g( "IN_ATTACK", "IN_JUMP", "IN_DUCK", "IN_FORWARD" )

	dump( "_E.SURFACE (want LIGHT=1 SKY2D=2 SKY=4 WARP=8 TRANS=16 NOPORTAL=32 TRIGGER=64 NODRAW=128 HITBOX=32768)",
		E.SURFACE, { "LIGHT", "SKY2D", "SKY", "WARP", "TRANS", "NOPORTAL", "TRIGGER", "NODRAW", "HITBOX" } )
	g( "SURF_NODRAW", "SURF_TRIGGER", "SURF_SKY" )
	-- the engine publishes the same table under the team-sandbox key too
	if ( E.SURF ~= nil ) then
		say( "_E.SURF is also published (" .. tostring( E.SURF.SKY ) .. " == _E.SURFACE.SKY: "
			.. tostring( E.SURF.SKY == ( E.SURFACE and E.SURFACE.SKY ) ) .. ")" )
	end

	-- the merge-loop spellings the file is responsible for
	dump( "_E.USABILITY_TYPE (want CONTINUOUS=32 ON_OFF=64 DIRECTIONAL=128 IMPULSE=16)",
		E.USABILITY_TYPE, { "CONTINUOUS", "ON_OFF", "DIRECTIONAL", "IMPULSE" } )
	g( "CONTINUOUS_USE", "ONOFF_USE", "DIRECTIONAL_USE", "SIMPLE_USE" )

	-- a couple of the merge-generated names, to prove the loops ran at all
	g( "DMG_BULLET", "HITGROUP_HEAD", "MAT_GLASS", "CONTENTS_SOLID", "FCVAR_ARCHIVE", "MASK_SHOT" )
end )

