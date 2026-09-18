--[[----------------------------------------------------------------------------
	hl2sb_derma.lua  --  HL2SB's own Derma-style control framework: class system.

	NOT a copy of Garry's Mod's lua/derma.  The API is Derma-shaped on purpose
	(derma.DefineControl / vgui.Create / vgui.Register / PANEL files / DoClick)
	so scripts written for GMod feel at home, but every line here was written
	for this engine's scripted-control layer:

	  * vgui.CreateX is the engine's C dispatch (lvgui_controls.cpp) -- it builds
	    the eight scripted panel classes (Panel, EditablePanel, Frame, Button,
	    CheckButton, Label, TextEntry, ModelPanel, PropertyDialog, PropertyPage).
	  * A control instance keeps its per-class methods in the panel's Lua ref
	    table (panel:GetTable()); the engine's __index looks there BEFORE the
	    shared Panel metatable, which is what lets a Lua class override an
	    engine method -- the same mechanism GMod's scripted panels rely on.
	  * Inheritance is a plain chain walk merged into that table at creation
	    time: the class table and every ancestor above it are copied in base-
	    first order, so a derived class simply overwrites the entry.

	Docking is NOT reimplemented here: this engine's vgui2 Panel grew native
	docking (HL2SBDockType_t in public/vgui_controls/Panel.h, laid out by the
	C++ dock pass, and SetDock/GetDock/Dock/DockMargin/DockPadding are already
	bound to Lua).  Derma controls just call them.

	Loaded from lua/derma/init.lua on the client and in the GameUI state.
-----------------------------------------------------------------------------]]

if ( not ( ( CLIENT or _GAMEUI ) and surface and vgui ) ) then return end

-- HL2SB: this file is also reached from the MAIN MENU (GameUI) state --
-- lua/gameui/addonsdialog.lua builds its dialog with it -- where lua/includes/util.lua has
-- not run, so GMod's istable() does not exist.  vgui.Create() below then died with
--
--     lua/derma/hl2sb_derma.lua:190: attempt to call a nil value (global 'istable')
--
-- and the addons dialog fell back to its plain path (which failed too, so the menu printed
-- a wall of red).  A local fallback keeps the framework usable in either state.
local istable = istable or function( v ) return type( v ) == "table" end

-- GMod scripts call ErrorNoHalt / Warning for non-fatal problems.  This fork
-- only registers dbg.Warning, and several older copied modules already assume a
-- bare global, so publish one on top of the engine's.
if ( type( Warning ) ~= "function" ) then
	Warning = function( msg, ... )
		if ( msg == nil ) then msg = "" end
		if ( select( "#", ... ) > 0 and type( msg ) == "string" ) then
			msg = string.format( msg, ... )
		end
		if ( dbg and dbg.Warning ) then dbg.Warning( msg ) else print( msg ) end
	end
end

local function ErrorNoHalt( msg )
	Warning( msg )
end

derma = derma or {}

-- The engine's C dispatch.  lua/includes/extensions/client/panel/scriptedpanels.lua
-- (loaded from panel.lua before this framework) captures it as vgui.CreateX and
-- wraps vgui.Create with its own dead registry; prefer that untouched original.
local engineCreate = vgui.CreateX or vgui.Create
vgui.CreateX = engineCreate

--[[-------------------------------------------------------------------------
	Class registry
---------------------------------------------------------------------------]]

local Classes = {}			-- [ "DButton" ] = class table

-- Class tables get their own metatable ONLY to answer the BaseClass idiom
-- (self.BaseClass:Method()).  Instance lookups never go through it -- instances
-- carry a flat merge of the chain -- so a method is a plain function call with
-- the panel as first argument, exactly like an engine bound method.
local BaseClassMap = {}		-- [ class table ] = { ClassName = <the class> }

local function attachBaseClass( parentCls )
	if ( not parentCls ) then return nil end

	local ownerName = parentCls.ClassName
	local proxy = setmetatable( {}, {
		__index = function( _, key )
			local chain = Classes[ ownerName ]
			while ( chain and rawget( chain, key ) == nil ) do
				chain = rawget( chain, "__dermaParent" )
			end
			return chain and rawget( chain, key ) or nil
		end
	} )

	BaseClassMap[ parentCls ] = proxy
	return proxy
end

--- Chain order for merging: root-most ancestor first, self last.
local function chainOf( cls )
	local chain = {}
	local c = cls
	while ( c ~= nil ) do
		table.insert( chain, 1, c )
		c = rawget( c, "__dermaParent" )
	end
	return chain
end

--- GMod's vgui.Register( name, table, base ).  `base` is either another
--- registered class or one of the engine's scripted classes (Panel / Frame /
--- Label / TextEntry / ...).  Returns the control table so a control file can
--- end with the classic `vgui.Register( "DButton", PANEL, "DPanel" )`.
--- HL2SB: convar <-> control wiring that survives the load order.
---
--- derma/init.lua is included BEFORE the control list (lua/includes/init.lua
--- includes derma/init.lua, and only then vgui_base.lua registers the controls),
--- so a linker that runs there asking vgui.GetControlTable( "DCheckBox" ) gets
--- nil and silently did nothing -- which is why the whole Panel:SetConVar family
--- was never installed on anything, and GMod's own wiki example
--- (vgui.Create( "DCheckBoxLabel" ):SetConVar( "cl_drawhud" )) threw
--- "attempt to call a nil value (method 'SetConVar')".
---
--- InstallConVarLink runs the linker immediately when the class is already
--- registered, and parks it here to be replayed from vgui.Register otherwise.
--- Order-independent on purpose: any control registered later gets its link too.
derma.m_tConVarLinkers = {}

function derma.InstallConVarLink( strClass, fnLink )
	local cls = Classes[ strClass ]
	if ( cls ~= nil ) then
		fnLink( cls )
		return
	end

	derma.m_tConVarLinkers[ strClass ] = fnLink
end

function vgui.Register( strName, tbl, strBase )
	tbl = tbl or {}

	local parent = nil
	local engineBase = strBase or "Panel"

	if ( Classes[ strBase ] ) then
		parent = Classes[ strBase ]
		engineBase = parent.Base
	elseif ( strBase ~= nil and not rawget( vgui, strBase ) ) then
		error( "vgui.Register: base class '" .. tostring( strBase ) ..
			"' is not an engine class and not a registered control", 2 )
	end

	tbl.ClassName = strName
	tbl.Base = engineBase
	rawset( tbl, "__dermaParent", parent )

	Classes[ strName ] = tbl

	-- Replay a convar link that was requested before this control existed (see
	-- derma.InstallConVarLink above).  Guarded: a broken linker must not take
	-- the whole control list down with it.
	local fnConVarLink = derma.m_tConVarLinkers[ strName ]
	if ( fnConVarLink ~= nil ) then
		derma.m_tConVarLinkers[ strName ] = nil

		local ok, err = pcall( fnConVarLink, tbl )
		if ( not ok ) then
			ErrorNoHalt( "derma: convar link for '" .. strName .. "' failed: " .. tostring( err ) .. "\n" )
		end
	end

	-- GMod's scriptedpanels mirrored each registered class into baseclass, so
	-- baseclass.Get( "DPanel" ) keeps working for code that reads it.
	if ( baseclass and baseclass.Set ) then
		baseclass.Set( strName, tbl )
	end

	-- GMod lets scripts call a control like a factory (vgui.DButton( parent )).
	-- The engine publishes exactly that for its own classes, so do the same.
	if ( not rawget( vgui, strName ) ) then
		vgui[ strName ] = function( pParent, strPanelName, ... )
			return vgui.Create( strName, pParent, strPanelName )
		end
	end

	return tbl
end

--- GMod's vgui.GetControlTable / vgui.Exists.
function vgui.GetControlTable( strName )
	return Classes[ strName ]
end

function vgui.Exists( strName )
	return Classes[ strName ] ~= nil
end

--- The creation path.  GMod's argument order and return contract are kept:
--- vgui.Create( class, parent, name ).  Unknown class names fall through to
--- the engine factory, so plain "Panel" / "Frame" / "TextEntry" requests still
--- build scripted engine controls directly.
function vgui.Create( strClass, pParent, strName )
	-- GMod also accepts an anonymous control table here (dragdrop.lua does).
	if ( istable( strClass ) ) then
		return vgui.CreateFromTable( strClass, pParent, strName )
	end

	local cls = Classes[ strClass ]

	if ( not cls ) then
		return engineCreate( strClass, pParent, strName or strClass )
	end

	-- Engine factories differ in their trailing argument (Label/Button take a
	-- text, Frame a bShowClose); the C dispatch already pads those.
	local panel = engineCreate( cls.Base or "Panel", pParent, strName or strClass )
	if ( not panel ) then
		ErrorNoHalt( "derma: vgui.Create('" .. strClass .. "'): engine base '" ..
			tostring( cls.Base ) .. "' could not be created\n" )
		return nil
	end

	-- Base-first merge of the whole chain -- written through the PANEL itself,
	-- not panel:GetTable().  Every scripted class routes panel[key] = value via
	-- its __newindex into the very ref table the engine dispatch macros read
	-- (BEGIN_LUA_CALL_PANEL_METHOD), but GetTable() is NOT the same accessor on
	-- every class: LTextEntry's metatable has no GetTable at all and falls
	-- through to Panel's, and mixing the two paths left LTextEntry's own
	-- ref table without the merged methods (probe: OnTextChanged never fired on
	-- DTextEntry).  Assigning per key keeps one truth for every class.
	for _, link in ipairs( chainOf( cls ) ) do
		for key, value in pairs( link ) do
			if ( key ~= "Base" and key ~= "ClassName" ) then
				panel[ key ] = value
			end
		end
	end

	panel.ClassName = strClass
	panel.BaseClass = attachBaseClass( rawget( cls, "__dermaParent" ) )

	-- Init runs root-most ancestor first, then each derived class.  GMod relies
	-- on control code chaining explicitly; running the whole chain here means a
	-- subclass never silently loses its base's initialisation.
	local seen = {}
	for _, link in ipairs( chainOf( cls ) ) do
		local fn = rawget( link, "Init" )
		if ( fn and not seen[ fn ] ) then
			seen[ fn ] = true
			local ok, err = pcall( fn, panel )
			if ( not ok ) then
				Warning( "derma: " .. strClass .. " Init failed: " .. tostring( err ) .. "\n" )
			end
		end
	end

	return panel
end

--- GMod's vgui.CreateFromTable( metatable, parent, name ) -- an anonymous
--- control table, exactly as returned by derma.DefinePanel( ... ) style code.
function vgui.CreateFromTable( tbl, pParent, strName )
	tbl = tbl or {}

	local strBase = tbl.Base or "Panel"
	local temp = {}
	for k, v in pairs( tbl ) do temp[ k ] = v end
	temp.Base = nil

	local name = "__derma_temp_" .. tostring( ( #Classes ) )
	vgui.Register( name, temp, strBase )
	local panel = vgui.Create( name, pParent, strName )
	Classes[ name ] = nil
	return panel
end

--- GMod's vgui.RegisterTable( tbl, base ) -- registers an ANONYMOUS control table and
--- returns it, for controls that are built inline rather than in their own file:
---
---   local tblRow = vgui.RegisterTable( { Init = ..., Paint = ... }, "Panel" )
---   ... self.Container:Add( tblRow )
---
--- (GMod's own DProperties is written exactly that way - two such tables, the row
--- and the category.)  The whole implementation is the Base field: this fork's
--- Panel:Add already forwards a table to vgui.CreateFromTable
--- (lua/includes/extensions/client/panel.lua:515), which reads tbl.Base.  GMod
--- additionally wraps the table in a metatable; nothing in the framework needs
--- that here.
function vgui.RegisterTable( tbl, strBase )
	tbl = tbl or {}
	tbl.Base = strBase or tbl.Base or "Panel"

	return tbl
end

--[[-------------------------------------------------------------------------
	derma namespace
---------------------------------------------------------------------------]]

--- GMod's derma.DefineControl( name, description, table, base ).
---
--- GMod also publishes every control as a global ("Store as a global so controls
--- can 'baseclass' easier -- TODO: STOP THIS", lua/derma/derma.lua:114-116), and
--- that is load-bearing: GMod's own files call the parent class that way
--- (lua/vgui/dlabeleditable.lua:21 `DLabel.GetContentSize( self )`,
--- lua/vgui/dlabelurl.lua:59 `self:SetFGColor(...)` from the URLLabel base), and so
--- do addons (`DPanel.Paint( self, w, h )`, `DButton.Init( self )`).
function derma.DefineControl( strName, strDescription, tbl, strBase )
	tbl = vgui.Register( strName, tbl, strBase )

	if ( strName ) then
		-- Already-registered globals that are not control tables win: the one
		-- collision that matters is "Material" - global Material( path ) is the
		-- IMaterial factory and lua/vgui/Material.lua registers a panel of that
		-- name.  GMod avoids the clash by calling vgui.Register directly there
		-- (gmod/vgui/material.lua:60), so this keeps the same outcome.
		local existing = rawget( _G, strName )

		if ( existing == nil or type( existing ) == "table" ) then
			_G[ strName ] = tbl
		end
	end

	return tbl
end

--- GMod's derma.DefinePanel( name, description, PANEL ) -- the base class has
--- to be spelled as PANEL.Base inside the table.
function derma.DefinePanel( strName, strDescription, tbl )
	return vgui.Register( strName, tbl, tbl and tbl.Base or "Panel" )
end

--- GMod's derma.NewCallablePanelTable( parameters, tbl ).  Used by scripts to
--- hand a control table around without a registered name; here it is just the
--- table itself (this framework's Create accepts tables through
--- vgui.CreateFromTable).
function derma.NewCallablePanelTable( parameters, tbl )
	tbl = tbl or {}
	for k, v in pairs( parameters or {} ) do
		if ( tbl[ k ] == nil ) then tbl[ k ] = v end
	end
	return tbl
end

--- Class listing for debug commands / future spawnmenu filters.
function derma.GetControlList()
	local names = {}
	for name in pairs( Classes ) do names[ #names + 1 ] = name end
	table.sort( names )
	return names
end

function derma.GetControlTable( strName )
	return vgui.GetControlTable( strName )
end

--- GMod helper: run a method on the base class implementation (the idiom
--- behind self:DermaCall-style scripts).  Cheap because the chain was merged
--- flat: walk up from the class the panel was created as.
function derma.GetDerivedControlClasses( pnl )
	local cls = pnl and Classes[ pnl.ClassName ] or nil
	local derived = {}
	for name, c in pairs( Classes ) do
		local up = rawget( c, "__dermaParent" )
		while ( up ~= nil ) do
			if ( up == cls ) then derived[ #derived + 1 ] = name; break end
			up = rawget( up, "__dermaParent" )
		end
	end
	return derived
end

--- Panel:CursorPos() -- GMod spells it, and this engine never bound it.
--- Screen cursor (input.GetCursorPosition / gui.MousePos fallbacks) minus the
--- panel's screen origin (LocalToScreen is engine-bound).
function derma.CursorPos( pnl )
	local mx, my = nil, nil

	-- this fork's gui library (gmod_globals.lua) spells the accessors
	-- gui.MouseX() / gui.MouseY(); input.GetCursorPosition is the engine's.
	if ( gui and gui.MouseX and gui.MouseY ) then
		mx, my = gui.MouseX(), gui.MouseY()
	end
	if ( ( not mx or not my ) and input and input.GetCursorPosition ) then
		mx, my = input.GetCursorPosition()
	end
	if ( not mx ) then return 0, 0 end

	local px, py = pnl:LocalToScreen( 0, 0 )
	return mx - ( px or 0 ), my - ( py or 0 )
end

print( "[HL2SB] derma framework core loaded" )
