--[[ hl2sb_derma_check.lua  (client)

	Two console commands for checking the Derma control list in-game - the wiki's
	VGUI/Derma element list (https://wiki.facepunch.com/gmod/VGUI_Element_List) is the
	checklist, and the fork's own registry (derma.GetControlList) is the state.

		hl2sb_derma_list          - print every registered control, then the ones from the
		                            wiki list that are still MISSING
		hl2sb_derma_show <Class>  - open a frame with that control inside, so a control
		                            can be looked at without writing Lua by hand

	Written because the alternative is typing quoted Lua into the console (which the
	user has ruled out) or guessing from the log.
--]]

if ( not CLIENT ) then return end

--- The wiki checklist.  Panels that cannot exist here are marked with a reason and are
--- reported separately instead of as failures.
---
--- The list is the union of the wiki's VGUI element list
--- (https://wiki.facepunch.com/gmod/VGUI_Element_List) and every derma.DefineControl()
--- in GMod's own garrysmod/lua/vgui (93 files / 96 registrations, checked against
--- Facepunch/garrysmod master and the local reference copy).  The wiki page alone is
--- not enough: it lists DTab only in a sentence, and it never mentions the four
--- "bar" sub-controls the dividers and the horizontal scrollbar are built from.
local EXPECTED = {
	-- Base panels
	"DPanel", "DFrame", "DLabel", "DLabelEditable", "DLabelURL", "DTextEntry", "DButton",
	"DExpandButton", "DBinder", "DCheckBox", "DCheckBoxLabel", "ImageCheckBox", "DComboBox",
	"DImage", "DImageButton", "DModelPanel", "DAdjustableModelPanel", "DBubbleContainer",
	"DCategoryHeader", "DCategoryList", "DCollapsibleCategory", "DForm", "DSlider", "DNumSlider",
	"DNumberScratch", "DNumberWang", "DPropertySheet", "DTab", "DColumnSheet", "DScrollPanel",
	"DVScrollBar", "DHScrollBar", "DScrollBarGrip", "DIconBrowser", "DMenu", "DMenuBar",
	"DMenuOption", "DMenuOptionCVar", "MatSelect", "SpawnIcon", "DProgress", "DFileBrowser",
	"DKillIcon", "DListBox", "DListBoxItem",
	-- Color panels
	"DColorButton", "DColorPalette", "DColorCombo", "DColorCube", "DColorMixer",
	"DRGBPicker", "DAlphaBar",
	-- Utility panels
	"DPanelOverlay", "DDragBase", "DSizeToContents", "DShape", "Material", "DSprite",
	"DTileLayout", "DNotify", "DIconLayout", "DListLayout", "DGrid",
	"DHorizontalDivider", "DHorizontalDividerBar", "DVerticalDivider", "DVerticalDividerBar",
	"DHorizontalScroller", "DTooltip", "DDrawer", "ContextBase",
	-- DProperties + its editors
	"DProperties", "DEntityProperties", "DProperty_Generic", "DProperty_Boolean",
	"DProperty_Float", "DProperty_Int", "DProperty_Combo", "DProperty_Entity",
	"DProperty_VectorColor",
	-- The rest of what GMod ships in lua/vgui
	"DPanelList", "DPanelSelect", "DModelSelect", "DModelSelectMulti", "DNumPad",
	"DTree", "DTree_Node", "DTree_Node_Button",
	-- The DListView family (GMod's is Lua - lua/vgui/dlistview.lua + two helper files)
	"DListView", "DListViewLine", "DListViewLabel", "DListView_Column",
	"DListView_ColumnPlain", "DListViewHeaderLabel", "DListView_DraggerBar",
	-- Ships in lua/vgui but is a tool panel, absent from the element list
	"PropSelect",
}

--- Panels that are expected to stay missing, with the reason.  Never reported as a gap.
local NOT_PORTABLE = {
	DHTML = "needs Awesomium",
	DHTMLControls = "needs Awesomium",
	FingerPoser = "needs the finger poser entity",
	FingerVar = "needs the finger poser entity",
	DPanPanel = "GMod's joke panel; not on the wiki element list and ships nowhere else",
	-- The engine's own vgui2 classes already answer vgui.Create() for these two names
	-- (scripted_controls/lButton.cpp and the engine Slider), so GMod's Lua shims for
	-- them are not needed - see the notes in lua/includes/vgui_base.lua.
	Button = "engine vgui2 Button (scripted_controls/lButton.cpp) - GMod's is the same class in Lua",
	Slider = "engine vgui2 Slider - DSlider/DNumSlider are the Lua controls callers use",
	-- Not a real control: the wiki's element list mentions the name, but its page
	-- 404s and GMod ships no such file or DefineControl (checked over the whole
	-- garrysmod/lua tree).  The closest thing GMod has is PropSelect, which is the
	-- model picker its DProperties rows use.
	DProperty_GenericSelect = "not in GMod (wiki page 404s; PropSelect is the real control)",
}

local function Registered()
	local out = {}

	for _, name in ipairs( derma.GetControlList() or {} ) do
		out[ name ] = true
	end

	return out
end

concommand.Add( "hl2sb_derma_list", function()
	local have = Registered()

	local names = derma.GetControlList() or {}
	local sorted = {}

	for _, n in ipairs( names ) do sorted[ #sorted + 1 ] = n end
	table.sort( sorted )

	print( string.format( "[HL2SB derma] %d control(s) registered:\n", #sorted ) )
	print( "  " .. table.concat( sorted, " " ) .. "\n" )

	local missing, skipped = {}, {}

	for _, name in ipairs( EXPECTED ) do
		if ( not have[ name ] ) then
			missing[ #missing + 1 ] = name
		end
	end

	-- The unportable ones are reported with their reason instead of as gaps, whether
	-- or not they are part of EXPECTED (Button/Slider are engine classes here).
	for name, reason in pairs( NOT_PORTABLE ) do
		if ( not have[ name ] ) then
			skipped[ #skipped + 1 ] = name .. " (" .. reason .. ")"
		end
	end

	print( string.format( "[HL2SB derma] wiki list: %d of %d present, %d still missing%s\n",
		#EXPECTED - #missing - #skipped, #EXPECTED, #missing,
		#skipped > 0 and ( ", " .. #skipped .. " not portable" ) or "" ) )

	if ( #missing > 0 ) then
		table.sort( missing )
		print( "  MISSING: " .. table.concat( missing, " " ) .. "\n" )
	end

	if ( #skipped > 0 ) then
		table.sort( skipped )
		print( "  skipped: " .. table.concat( skipped, ", " ) .. "\n" )
	end
end, nil, "List the registered Derma controls against the GMod wiki list" )

--- hl2sb_derma_show <Class> [w] [h]
concommand.Add( "hl2sb_derma_show", function( _, _, args )
	local class = args and args[ 1 ]
	if ( not class or class == "" ) then
		print( "[HL2SB derma] usage: hl2sb_derma_show <Class> [w] [h]\n" )
		return
	end

	if ( not ( vgui.Exists and vgui.Exists( class ) ) ) then
		print( "[HL2SB derma] '" .. class .. "' is not registered\n" )
		return
	end

	local w = tonumber( args[ 2 ] ) or 320
	local h = tonumber( args[ 3 ] ) or 240

	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then
		print( "[HL2SB derma] could not create a DFrame\n" )
		return
	end

	frame:SetTitle( class )
	frame:SetSize( w + 20, h + 50 )
	frame:Center()
	frame:MakePopup()

	local pnl = vgui.Create( class, frame )

	if ( not pnl or not pnl.SetSize ) then
		print( "[HL2SB derma] '" .. class .. "' answered a panel without SetSize\n" )
		return
	end

	pnl:SetPos( 10, 30 )
	pnl:SetSize( w, h )

	-- a couple of the controls need a starting value before they show anything
	if ( pnl.SetFraction ) then pnl:SetFraction( 0.6 ) end
	if ( pnl.SetType ) then pcall( pnl.SetType, pnl, class == "DPanelOverlay" and 1 or "Rect" ) end
	if ( pnl.SetValue and pnl.SetBarColor ) then pnl:SetBarColor( Color( 80, 160, 255, 255 ) ) end

	print( "[HL2SB derma] showing '" .. class .. "'\n" )
end, nil, "Show one Derma control in a frame (for looking at it)" )

--- hl2sb_derma_wiki <Class> -- build the WIKI page's own example for a control, so what
--- is on screen can be compared with the picture on the wiki page.
---
--- Every entry below is the example code from that control's wiki page, with the
--- engine substitutions the control itself documents (DModelPanel: cam.Start3D ->
--- render.PushView3D, etc).
local WIKI_EXAMPLES = {}

WIKI_EXAMPLES[ "DModelPanel" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetTitle( "DModelPanel  -  wiki example" )
	frame:SetSize( 450, 280 )
	frame:Center()
	frame:MakePopup()

	-- Example 1 from the wiki page: the local player's model, default rotation
	local p1 = vgui.Create( "DPanel", frame )
	p1:SetPos( 10, 30 )
	p1:SetSize( 200, 200 )

	local icon = vgui.Create( "DModelPanel", p1 )
	icon:SetSize( 200, 200 )

	local ply = LocalPlayer()

	if ( IsValid( ply ) and ply.GetModel ) then
		icon:SetModel( ply:GetModel() )
	end

	-- Example 2 from the wiki page: Alyx, rotation disabled, player colour red
	local p2 = vgui.Create( "DPanel", frame )
	p2:SetPos( 220, 30 )
	p2:SetSize( 200, 200 )

	local icon2 = vgui.Create( "DModelPanel", p2 )
	icon2:SetSize( 200, 200 )
	icon2:SetModel( "models/player/alyx.mdl" )

	-- "you can only change colors on playermodels" - the wiki disables the default
	-- rotation here, which is what makes the model stand still facing the camera
	function icon2:LayoutEntity( ent )
		return
	end

	-- the wiki sets a Vector (RGB / 255), not a Color.  Whether the render path asks
	-- for it is up to the engine - in this fork a clientside model is not a player, so
	-- this may have no visible effect (the model simply stays its own skin colour).
	if ( IsValid( icon2.Entity ) ) then
		function icon2.Entity:GetPlayerColor()
			return Vector( 1, 0, 0 )
		end
	end

	return frame
end

--- https://wiki.facepunch.com/gmod/DDragBase  (wiki example, verbatim apart from
--- the comments: drag a button and drop it on another to reorder them; each
--- button's Think prints its ID and the Z position the drop actions assigned).
WIKI_EXAMPLES[ "DDragBase" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 300, 500 )
	frame:SetTitle( "DDragBase  -  wiki example" )
	frame:Center()
	frame:MakePopup()

	local dragbase = vgui.Create( "DDragBase", frame )
	dragbase:Dock( FILL )
	dragbase:MakeDroppable( "test" )
	dragbase:SetDropPos( "82" )

	for i = 0, 10 do
		local butt = dragbase:Add( "DButton" )
		--butt:Dock( TOP )
		butt:SetPos( 25, i * 25 )
		butt:SetWidth( 100 )
		butt:Droppable( "test" )
		butt.id = i

		butt.Think = function( s )
			s:SetText( "ID: " .. i .. " ZPOS: " .. s:GetZPos() )
		end
	end

	return frame
end

--- https://wiki.facepunch.com/gmod/DTileLayout  -- the wiki's example.  The wiki
--- adds the children with the engine's `Label( text )` factory; this fork's
--- equivalent is a DLabel with an explicit size (DTileLayout packs by size).
WIKI_EXAMPLES[ "DTileLayout" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 300, 300 )
	frame:SetTitle( "DTileLayout Example  -  wiki example" )
	frame:MakePopup()
	frame:Center()

	local layout = vgui.Create( "DTileLayout", frame )
	layout:SetBaseSize( 32 )		-- Tile size
	layout:Dock( FILL )

	-- Draw a background so we can see what it's doing
	layout:SetDrawBackground( true )
	layout:SetBackgroundColor( Color( 0, 100, 100 ) )

	layout:MakeDroppable( "unique_name", true )	-- Allows us to rearrange children

	for i = 1, 32 do
		local lbl = vgui.Create( "DLabel", layout )
		lbl:SetText( " Label " .. i )
		lbl:SetSize( 64, 18 )
	end

	return frame
end

--- https://wiki.facepunch.com/gmod/DHorizontalScroller  -- the wiki's first
--- example, plus the btnLeft/btnRight colouring from its second one (the second
--- example's `draw.RoundedBox( 0, 0, 0, w, h, colour )` is reproduced literally,
--- including the wiki's own argument count).
WIKI_EXAMPLES[ "DHorizontalScroller" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 500, 100 )
	frame:SetTitle( "DHorizontalScroller Example  -  wiki example" )
	frame:Center()
	frame:MakePopup()

	local scroller = vgui.Create( "DHorizontalScroller", frame )
	scroller:Dock( FILL )
	scroller:SetOverlap( -4 )

	-- second wiki example: colour the two arrow buttons
	scroller.btnLeft.Paint = function( self, w, h )
		draw.RoundedBox( 0, 0, 0, w, h, Color( 200, 100, 0 ) )
	end

	scroller.btnRight.Paint = function( self, w, h )
		draw.RoundedBox( 0, 0, 0, w, h, Color( 0, 100, 200 ) )
	end

	for i = 0, 16 do
		local img = vgui.Create( "DImage", scroller )
		img:SetImage( "scripted/breen_fakemonitor_1" )
		scroller:AddPanel( img )
	end

	return frame
end

--- https://wiki.facepunch.com/gmod/DSprite  -- the wiki's example.  The wiki creates
--- the sprite bare (no parent, no frame); it is put in a DFrame here so it can be
--- closed again -- the sprite itself is the sprite of the example.
WIKI_EXAMPLES[ "DSprite" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 260, 290 )
	frame:SetTitle( "DSprite  -  wiki example" )
	frame:Center()
	frame:MakePopup()

	local sprite = vgui.Create( "DSprite", frame )
	sprite:SetMaterial( Material( "sprites/sent_ball" ) )
	sprite:SetColor( Color( 0, 255, 255 ) )
	sprite:SetSize( 200, 200 )
	sprite:SetPos( 30, 40 )

	return frame
end

--- https://wiki.facepunch.com/gmod/Material  -- the wiki's first example: TV static
--- in a Material panel, with the spinning Garry's Mod logo model on top.
WIKI_EXAMPLES[ "Material" ] = function()
	-- Background panel
	local BGPanel = vgui.Create( "DPanel" )
	if ( not BGPanel ) then return nil end

	BGPanel:SetSize( 400, 400 )
	BGPanel:Center()
	BGPanel:SetBackgroundColor( Color( 0, 0, 0, 255 ) )

	-- Material panel with TV static
	local mat = vgui.Create( "Material", BGPanel )
	mat:SetPos( 10, 10 )
	mat:SetSize( 380, 380 )
	mat:SetMaterial( "effects/tvscreen_noise002a" )		-- Path to material VMT

	-- Set this to false to enable material stretching
	mat.AutoSize = false

	-- Model panel for GMod Logo
	local mdl = vgui.Create( "DModelPanel", BGPanel )
	mdl:SetPos( 10, 10 )
	mdl:SetSize( 380, 380 )
	mdl:SetModel( "models/maxofs2d/logo_gmod_b.mdl" )
	mdl:SetCamPos( Vector( 240, 0, 0 ) )
	mdl:SetLookAt( Vector( 0, 0, 0 ) )
	mdl:SetFOV( 40 )

	-- Spin faster
	function mdl:LayoutEntity( ent )
		ent:SetAngles( Angle( 0, RealTime() * 100, 0 ) )
	end

	BGPanel:MakePopup()

	return BGPanel
end

--- https://wiki.facepunch.com/gmod/ImageCheckBox  -- the wiki's "Check list"
--- example: a head row that counts the checked boxes, and 10 rows of
--- ImageCheckBox + DLabel.
WIKI_EXAMPLES[ "ImageCheckBox" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 300, 305 )
	frame:Center()
	frame:SetTitle( "Check list" )
	frame:MakePopup()

	frame.Items = {}		-- Create table to store lines

	local Head = frame:Add( "DPanel" )		-- Create head line
	Head:Dock( TOP )
	Head:SetHeight( 20 )

	function Head:Paint( w, h )
		local completed = 0		-- Variable to store amount of checked ImageCheckBox'es

		for k, v in ipairs( frame.Items ) do
			if ( v.ImageCheckBox:GetChecked() ) then
				completed = completed + 1		-- Get ImageCheckBox'es state and count checked
			end
		end

		draw.SimpleText( "You've completed " .. completed .. " of " .. #frame.Items .. " items",
			"DermaDefaultBold", w / 2, h / 2, Color( 255, 255, 255 ),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )	-- Draw the text
	end

	-- Convenience function to quickly add items
	local function addItem( text )
		local RulePanel = frame:Add( "DPanel" )
		RulePanel:Dock( TOP )
		RulePanel:DockMargin( 0, 1, 0, 0 )

		table.insert( frame.Items, RulePanel )

		local box = RulePanel:Add( "ImageCheckBox" )
		box:SetMaterial( "icon16/accept.png" )
		box:SetWidth( 24 )
		box:Dock( LEFT )
		box:SetChecked( false )

		RulePanel.ImageCheckBox = box

		local label = RulePanel:Add( "DLabel" )
		label:SetText( text )
		label:Dock( FILL )
		label:DockMargin( 5, 0, 0, 0 )
		label:SetTextColor( Color( 0, 0, 0 ) )
	end

	-- Adding items
	addItem( "Learn something" )
	addItem( "Do something" )
	addItem( "Make something" )
	addItem( "Create something" )
	addItem( "Play something" )
	addItem( "Test something" )
	addItem( "Write a really long item for testing purposes" )
	addItem( "Break something" )
	addItem( "Rebuild something" )
	addItem( "Release something" )

	return frame
end

--[[ hl2sb_derma_demo <name> -- hand-written demos for controls whose wiki page has
	no example but which cannot be judged from a bare `hl2sb_derma_show`: they
	need a parent that drives them, and two of them double as the in-game check for
	the engine's PaintOver dispatch (see AGENTS.md 5.0.4).

	Every one of them is also listed by hl2sb_derma_demo with no argument.  --]]
local DEMOS = {}

--- DVScrollBar, wired exactly like the usage note on its wiki page:
---   scrollbar:SetUp( _barsize_, _canvassize_ ) / scrollbar:GetOffset()
DEMOS[ "DVScrollBar" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 380, 320 )
	frame:SetTitle( "DVScrollBar  -  demo" )
	frame:Center()
	frame:MakePopup()

	-- the "window" into the canvas
	local view = vgui.Create( "DPanel", frame )
	view:SetPos( 10, 40 )
	view:SetSize( 340, 240 )
	view:SetBackgroundColor( Color( 30, 30, 30, 255 ) )

	-- the canvas: taller than the window, with visible rows
	local canvas = vgui.Create( "DPanel", view )
	canvas:SetPos( 0, 0 )
	canvas:SetSize( 324, 900 )
	canvas:SetDrawBackground( false )

	for i = 1, 18 do
		local row = vgui.Create( "DPanel", canvas )
		row:SetPos( 0, ( i - 1 ) * 50 )
		row:SetSize( 324, 46 )
		row:SetBackgroundColor( Color( 40 + i * 8, 60, 110 - i * 3, 255 ) )
		row.Paint = function( self, w, h )
			derma.SkinHook( "Paint", "Panel", self, w, h )
			derma.DrawText( "DermaDefault", 8, 14, "canvas row " .. i .. "  (y = " .. ( i - 1 ) * 50 .. ")",
				Color( 230, 230, 230, 255 ) )
		end
	end

	local vbar = vgui.Create( "DVScrollBar", view )
	vbar:SetSize( 16, 240 )

	-- the wiki's own contract: SetUp on layout, GetOffset to place the canvas
	function view:PerformLayout( w, h )
		vbar:SetPos( w - 16, 0 )
		vbar:SetSize( 16, h )
		vbar:SetUp( h, canvas:GetTall() )

		canvas:SetPos( 0, vbar:GetOffset() )
		canvas:SetWide( w - 16 )
	end

	local hideBox = vgui.Create( "DCheckBoxLabel", frame )
	hideBox:SetPos( 10, 288 )
	hideBox:SetText( "HideButtons" )
	hideBox:SetValue( 0 )
	hideBox.OnChange = function( self )
		vbar:SetHideButtons( self:GetChecked() )
		vbar:InvalidateLayout()
	end

	local resetBtn = vgui.Create( "DButton", frame )
	resetBtn:SetPos( 180, 286 )
	resetBtn:SetSize( 90, 20 )
	resetBtn:SetText( "AnimateTo 500" )
	resetBtn.DoClick = function() vbar:AnimateTo( 500, 0.5, 0, -1 ) end

	return frame
end

--- DPanelSelect: clicking an entry moves the yellow PaintOver highlight, which is
--- the engine's PaintOver dispatch (PostChildPaint is enabled in
--- scripted_controls/lPanel.cpp) actually working.
DEMOS[ "DPanelSelect" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 340, 200 )
	frame:SetTitle( "DPanelSelect  -  demo (click a colour)" )
	frame:Center()
	frame:MakePopup()

	local sel = vgui.Create( "DPanelSelect", frame )
	sel:SetPos( 10, 40 )
	sel:SetSize( 320, 140 )

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 10, 20 )
	status:SetSize( 320, 16 )
	status:SetText( "selected: (nothing yet)" )

	local colours = {
		{ "red", Color( 180, 60, 60, 255 ) },
		{ "green", Color( 60, 180, 60, 255 ) },
		{ "blue", Color( 60, 60, 180, 255 ) },
		{ "yellow", Color( 180, 180, 60, 255 ) },
	}

	for _, entry in ipairs( colours ) do
		local button = vgui.Create( "DButton", sel )
		button:SetSize( 150, 40 )
		button:SetText( entry[ 1 ] )
		button.Paint = function( self, w, h )
			surface.SetDrawColor( entry[ 2 ].r, entry[ 2 ].g, entry[ 2 ].b, 255 )
			surface.DrawRect( 2, 2, w - 4, h - 4 )
			derma.DrawText( "DermaDefaultBold", 8, math.floor( h / 2 ) - 7, entry[ 1 ],
				Color( 240, 240, 240, 255 ) )
		end

		sel:AddPanel( button )
	end

	function sel:OnActivePanelChanged( pnlOld, pnlNew )
		if ( IsValid( pnlNew ) ) then
			status:SetText( "selected: " .. tostring( pnlNew:GetText() ) )
		end
	end

	sel:SelectPanel( sel:GetItems()[ 1 ] )

	return frame
end

--- DMenuOptionCVar: a menu row that reads and writes a real convar, and draws a
--- tick (lua/vgui/DMenu.lua's OPT:SetChecked/OnChecked/Paint).
DEMOS[ "DMenuOptionCVar" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 320, 180 )
	frame:SetTitle( "DMenuOptionCVar  -  demo (cl_drawhud)" )
	frame:Center()
	frame:MakePopup()

	local cvar = "cl_drawhud"

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 10, 30 )
	status:SetSize( 300, 16 )

	local menu = vgui.Create( "DMenu", frame )
	menu:SetPos( 10, 60 )
	menu:SetSize( 220, 40 )

	local option = vgui.Create( "DMenuOptionCVar", menu )
	option:SetText( cvar .. " (tick to switch)" )
	option:SetSize( 220, 22 )
	option:SetConVar( cvar )
	option:SetIsCheckable( true )

	menu:AddPanel( option )
	menu:Open( 10, 60 )

	local function refresh()
		status:SetText( cvar .. " = " .. tostring( GetConVarString( cvar ) ) )
	end

	-- the option's own OnThink polls the convar, so mirror it into the label
	-- (this engine dispatches OnThink, not Think - AGENTS.md 5.0.3)
	frame.OnThink = refresh
	refresh()

	return frame
end

--- DNumPad: press the keys, the label shows what arrived through
--- OnButtonPressed (GMod's override hook), and sticky keys stay lit.
DEMOS[ "DNumPad" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 220, 220 )
	frame:SetTitle( "DNumPad  -  demo" )
	frame:Center()
	frame:MakePopup()

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 10, 24 )
	status:SetSize( 320, 16 )
	status:SetText( "pressed: (none)" )

	local pad = vgui.Create( "DNumPad", frame )
	pad:SetPos( 10, 44 )

	pad.OnButtonPressed = function( self, iNum, pButton )
		status:SetText( "pressed: " .. tostring( iNum ) .. "   selected: " .. tostring( self:GetValue() ) )
	end

	return frame
end

--- DNumberWang: three fields (integer, decimals, negative range), the arrows,
--- the wheel over an arrow, and a convar-bound one at the bottom.
DEMOS[ "DNumberWang" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 300, 200 )
	frame:SetTitle( "DNumberWang  -  demo" )
	frame:Center()
	frame:MakePopup()

	local rows = {
		{ "0..255, no decimals", 0, 255, 0, 128 },
		{ "0..1, 2 decimals", 0, 1, 2, 0.25 },
		{ "-100..100, 1 decimal", -100, 100, 1, -12.5 },
	}

	local y = 30
	for _, row in ipairs( rows ) do
		local label = vgui.Create( "DLabel", frame )
		label:SetPos( 10, y + 3 )
		label:SetSize( 150, 16 )
		label:SetText( row[ 1 ] )

		local wang = vgui.Create( "DNumberWang", frame )
		wang:SetPos( 170, y )
		wang:SetMinMax( row[ 2 ], row[ 3 ] )
		wang:SetDecimals( row[ 4 ] )
		wang:SetValue( row[ 5 ] )
		wang:SizeToContents()

		y = y + 30
	end

	local cvar = vgui.Create( "DNumberWang", frame )
	cvar:SetPos( 10, y + 10 )
	cvar:SetMinMax( 0, 1 )
	cvar:SetDecimals( 0 )
	cvar:SetConVar( "cl_drawhud" )
	cvar:SizeToContents()

	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( 120, y + 14 )
	hint:SetSize( 170, 16 )
	hint:SetText( "bound to cl_drawhud" )

	return frame
end

--- DColumnSheet: three tabs down the left; the active one is toggled and its
--- page is the only visible one (DButton:SetToggle + SetSelected).
DEMOS[ "DColumnSheet" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 360, 220 )
	frame:SetTitle( "DColumnSheet  -  demo" )
	frame:Center()
	frame:MakePopup()

	local sheet = vgui.Create( "DColumnSheet", frame )
	sheet:SetPos( 10, 30 )
	sheet:SetSize( 340, 180 )

	local colours = {
		{ "red", Color( 120, 40, 40, 255 ) },
		{ "green", Color( 40, 120, 40, 255 ) },
		{ "blue", Color( 40, 40, 120, 255 ) },
	}

	for _, entry in ipairs( colours ) do
		local page = vgui.Create( "DPanel" )
		page:SetBackgroundColor( entry[ 2 ] )

		-- ⚠️ DColumnSheet does NOT size its pages - GMod does not either
		-- (dcolumnsheet.lua only does SetParent( self.Content )), so the caller has to
		-- give the page a size or it keeps the engine's ~64px default and clips
		-- everything inside it.  Docking to the content area is the cheapest fix that
		-- also follows a resize.
		page:Dock( FILL )

		local label = vgui.Create( "DLabel", page )
		label:SetPos( 10, 10 )
		label:SetSize( 190, 16 )
		label:SetText( "this is the " .. entry[ 1 ] .. " page" )

		sheet:AddSheet( entry[ 1 ], page )
	end

	return frame
end

--- SpawnIcon: GMod's model thumbnail.  This is also the in-game check for the
--- engine's "ModelImage" (scripted CModelPanel): if the models render at all, the
--- substitution in lua/vgui/SpawnIcon.lua works.  Hovering one shows the fade
--- border, which is the PaintOver dispatch again.
DEMOS[ "SpawnIcon" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 320, 160 )
	frame:SetTitle( "SpawnIcon  -  demo" )
	frame:Center()
	frame:MakePopup()

	local models = {
		"models/props_c17/oildrum001.mdl",
		"models/props_junk/watermelon01.mdl",
		"models/props_c17/canister01a.mdl",
		"models/player/alyx.mdl",
	}

	local x = 12
	for _, mdl in ipairs( models ) do
		local icon = vgui.Create( "SpawnIcon", frame )
		icon:SetPos( x, 40 )
		icon:SetSize( 64, 64 )
		icon:SetModel( mdl )

		x = x + 72
	end

	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( 12, 112 )
	hint:SetSize( 290, 16 )
	hint:SetText( "4 models - hover for the fade border" )

	return frame
end

--- DModelSelect: a clickable list of model thumbnails; the selection is the
--- DPanelSelect PaintOver highlight, and OnActivePanelChanged reports it.
DEMOS[ "DModelSelect" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 320, 260 )
	frame:SetTitle( "DModelSelect  -  demo" )
	frame:Center()
	frame:MakePopup()

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 10, 26 )
	status:SetSize( 290, 16 )
	status:SetText( "click a thumbnail" )

	local sel = vgui.Create( "DModelSelect", frame )
	sel:SetPos( 10, 46 )
	sel:SetSize( 290, 200 )
	sel:SetHeight( 2 )

	sel:SetModelList( {
		[ "models/props_c17/oildrum001.mdl" ] = {},
		[ "models/props_junk/watermelon01.mdl" ] = {},
		[ "models/props_c17/canister01a.mdl" ] = {},
		[ "models/player/alyx.mdl" ] = {},
	}, nil, false, true )

	function sel:OnActivePanelChanged( pnlOld, pnlNew )
		if ( IsValid( pnlNew ) ) then
			status:SetText( "selected: " .. tostring( pnlNew.Model ) )
		end
	end

	return frame
end

--- DModelSelectMulti: two DModelSelects behind a DPropertySheet's tabs.
DEMOS[ "DModelSelectMulti" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 320, 260 )
	frame:SetTitle( "DModelSelectMulti  -  demo" )
	frame:Center()
	frame:MakePopup()

	local multi = vgui.Create( "DModelSelectMulti", frame )
	multi:SetPos( 10, 30 )
	multi:SetSize( 300, 220 )
	multi:SetHeight( 2 )

	multi:AddModelList( "props", {
		[ "models/props_c17/oildrum001.mdl" ] = {},
		[ "models/props_c17/canister01a.mdl" ] = {},
	}, nil, false, true )

	multi:AddModelList( "players", {
		[ "models/player/alyx.mdl" ] = {},
	}, nil, false, true )

	return frame
end

--- DProperties: one row of every editor type, each wired to DataChanged /
--- DataUpdate so the label underneath shows what the row reported.
DEMOS[ "DProperties" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 420, 320 )
	frame:SetTitle( "DProperties  -  demo" )
	frame:Center()
	frame:MakePopup()

	local props = vgui.Create( "DProperties", frame )
	props:SetPos( 10, 30 )
	props:SetSize( 400, 240 )

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 10, 276 )
	status:SetSize( 400, 16 )
	status:SetText( "no changes yet" )

	local values = {
		Text = "hello world",
		Amount = 5,
		Count = 3,
		Enabled = 1,
		Mode = 2,
	}

	local function report( name )
		return function( _, val )
			values[ name ] = val
			status:SetText( name .. " = " .. tostring( val ) )
		end
	end

	local rows = {
		{ "General", "Text", "String", nil },
		{ "General", "Amount", "Float", { min = 0, max = 100 } },
		{ "General", "Count", "Int", { min = 0, max = 10 } },
		{ "General", "Enabled", "Bool", nil },
		{ "General", "Mode", "Combo", { values = { "One", "Two", "Three" }, select = "Two" } },
	}

	for _, spec in ipairs( rows ) do
		local row = props:CreateRow( spec[1], spec[2] )
		row:Setup( spec[3], spec[4] )

		row.DataChanged = report( spec[2] )
		row.DataUpdate = function() end

		row:SetValue( values[ spec[2] ] )
	end

	return frame
end

--- DForm: one row of every input kind GMod's quick form offers.
DEMOS[ "DForm" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 460, 340 )
	frame:SetTitle( "DForm  -  demo" )
	frame:Center()
	frame:MakePopup()

	local form = vgui.Create( "DForm", frame )
	form:SetPos( 10, 30 )
	form:SetSize( 440, 290 )
	form:SetName( "My Form" )

	local entry = form:TextEntry( "Text", "cl_drawhud" )
	form:CheckBox( "Check", "cl_drawhud" )
	form:NumberWang( "Number", "cl_drawhud", 0, 10, 0 )
	form:NumSlider( "Slider", "cl_drawhud", 0, 1, 2 )
	form:ComboBox( "Combo", "cl_drawhud" )
	form:Help( "This is a wrapped help label: it grows vertically to fit its text, which is what SetAutoStretchVertical does." )
	form:ControlHelp( "And this is the smaller control help line under a control." )

	local btn = form:Button( "A button with a console command", "echo", "hello from DForm" )
	if ( IsValid( entry ) ) then entry:SetText( "1" ) end

	return frame
end

--- DEntityProperties: drives the whole DProperties system from an entity's
--- GetEditingData.  The picked-up entity here is the local player, whose
--- client-side editing data is whatever the gamemode registered (usually empty) -
--- so the demo also shows a hand-written fake when nothing is registered.
DEMOS[ "DEntityProperties" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 420, 260 )
	frame:SetTitle( "DEntityProperties  -  demo" )
	frame:Center()
	frame:MakePopup()

	local sheet = vgui.Create( "DEntityProperties", frame )
	sheet:SetPos( 10, 30 )
	sheet:SetSize( 400, 180 )

	local note = vgui.Create( "DLabel", frame )
	note:SetPos( 10, 216 )
	note:SetSize( 400, 16 )
	note:SetText( "showing a hand-written editing set (no entity here has one)" )

	-- GMod reads entity:GetEditingData(); nothing in this fork populates it, so the
	-- demo supplies one to show the rows the system builds (type -> editor).
	local fake = {
		GetEditingData = function()
			return {
				speed	= { type = "Float", title = "Speed", category = "Movement", order = 1, min = 0, max = 200 },
				health	= { type = "Int", title = "Health", category = "Movement", order = 2, min = 0, max = 500 },
				model	= { type = "String", title = "Model", category = "Appearance", order = 3 },
				solid	= { type = "Boolean", title = "Solid", category = "Appearance", order = 4 },
				tint	= { type = "VectorColor", title = "Tint", category = "Appearance", order = 5 },
			}
		end,
		GetNetworkKeyValue = function( self, name ) return name == "speed" and 120 or 1 end,
		EditValue = function( self, name, val )
			print( "[HL2SB derma] EditValue( " .. tostring( name ) .. ", " .. tostring( val ) .. " )\n" )
		end,
	}

	sheet:SetEntity( fake )

	return frame
end

--- PropSelect: a grid of model thumbnails bound to a convar (GMod's spawnmenu
--- model picker).
DEMOS[ "PropSelect" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 420, 300 )
	frame:SetTitle( "PropSelect  -  demo" )
	frame:Center()
	frame:MakePopup()

	local props = vgui.Create( "PropSelect", frame )
	props:SetPos( 10, 30 )
	props:SetSize( 400, 220 )

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 10, 256 )
	status:SetSize( 400, 16 )
	status:SetText( "click a thumbnail" )

	local models = {
		"models/props_c17/oildrum001.mdl",
		"models/props_junk/watermelon01.mdl",
		"models/props_c17/canister01a.mdl",
		"models/props_c17/chair02a.mdl",
		"models/props_lab/monitor01a.mdl",
		"models/player/alyx.mdl",
	}

	for _, mdl in ipairs( models ) do
		props:AddModel( mdl )
	end

	props.Height = 2

	function props:OnSelect( model, pnl )
		status:SetText( "selected: " .. tostring( model ) )
	end

	return frame
end

--- DTree: the wiki's own example, plus the one node that populates itself for real
--- ("maps" out of GAME, through file.Find).  Clicking a node selects it (its label
--- takes SKIN.Colours.Tree.Selected) and clicking the arrow drops the child list
--- open; each node's children live in a DListLayout, which is a DDragBase here.
DEMOS[ "DTree" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 330, 430 )
	frame:SetTitle( "DTree  -  demo" )
	frame:Center()
	frame:MakePopup()

	local tree = vgui.Create( "DTree", frame )
	tree:SetPos( 10, 30 )
	tree:SetSize( 310, 356 )

	tree:AddNode( "Node One", "icon16/page.png" )

	local two = tree:AddNode( "Node Two", "icon16/folder.png" )
	two:AddNode( "Node 2.1", "icon16/page_white.png" )
	two:AddNode( "Node 2.2", "icon16/page_white.png" )

	local deep = two:AddNode( "Node 2.3", "icon16/folder.png" )
	for i = 1, 12 do
		deep:AddNode( "Node 2.3." .. i, "icon16/page_white.png" )
	end

	-- a real folder: file.Find( "maps/*", "GAME" ) when it is expanded
	tree:AddNode( "Maps ( a real folder )", "icon16/folder.png" ):MakeFolder( "maps", "GAME" )

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 10, 392 )
	status:SetSize( 310, 16 )
	status:SetText( "click a node, or an arrow" )

	function tree:OnNodeSelected( node )
		status:SetText( "selected: " .. tostring( node:GetText() ) )
	end

	return frame
end

--- DBinder: the key binder.  Click it (the caption turns into "press a key"), then
--- press a key - the key's name appears and the code is written to the convar on the
--- right.  Middle click restores the default, right click opens a DMenu.
DEMOS[ "DBinder" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 300, 190 )
	frame:SetTitle( "DBinder  -  demo" )
	frame:Center()
	frame:MakePopup()

	CreateClientConVar( "hl2sb_demo_bind", "0", true, false )

	local bind = vgui.Create( "DBinder", frame )
	bind:SetPos( 12, 40 )
	bind:SetSize( 120, 30 )
	bind:SetConVar( "hl2sb_demo_bind" )
	bind:SetValue( 0 )

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 12, 80 )
	status:SetSize( 270, 16 )
	status:SetText( "click the button, then press any key" )

	local raw = vgui.Create( "DLabel", frame )
	raw:SetPos( 12, 100 )
	raw:SetSize( 270, 16 )
	raw:SetText( "convar hl2sb_demo_bind = " .. GetConVarString( "hl2sb_demo_bind" ) )

	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( 12, 128 )
	hint:SetSize( 270, 40 )
	hint:SetWrap( true )
	hint:SetText( "middle click = reset to the convar's default, right click = the menu" )

	function bind:OnChange( iNum )
		status:SetText( "key code " .. tostring( iNum ) .. "  (name: " .. tostring( input.GetKeyName( iNum ) ) .. ")" )
		raw:SetText( "convar hl2sb_demo_bind = " .. GetConVarString( "hl2sb_demo_bind" ) )
	end

	return frame
end

--- DLabelEditable: double click the label and it turns into a text entry; Enter
--- commits, losing focus cancels.  OnLabelTextChanged shows what was committed.
DEMOS[ "DLabelEditable" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 320, 170 )
	frame:SetTitle( "DLabelEditable  -  demo" )
	frame:Center()
	frame:MakePopup()

	local label = vgui.Create( "DLabelEditable", frame )
	label:SetPos( 12, 45 )
	label:SetText( "double click me" )
	label:SizeToContents()

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 12, 80 )
	status:SetSize( 290, 16 )
	status:SetText( "committed: (nothing yet)" )

	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( 12, 110 )
	hint:SetSize( 290, 30 )
	hint:SetWrap( true )
	hint:SetText( "Enter commits through OnLabelTextChanged, losing focus just closes the editor" )

	function label:OnLabelTextChanged( text )
		status:SetText( "committed: " .. tostring( text ) )
		return text
	end

	return frame
end

--- DLabelURL: two links.  Hovering brightens the text (OnCursorEntered/Exited) and
--- clicking hands the URL to gui.OpenURL, which is this fork's ISystem::ShellExecute.
DEMOS[ "DLabelURL" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 340, 160 )
	frame:SetTitle( "DLabelURL  -  demo" )
	frame:Center()
	frame:MakePopup()

	local one = vgui.Create( "DLabelURL", frame )
	one:SetPos( 12, 45 )
	one:SetSize( 300, 20 )
	one:SetText( "the GMod wiki - DLabelURL" )
	one:SetURL( "https://wiki.facepunch.com/gmod/DLabelURL" )

	local two = vgui.Create( "DLabelURL", frame )
	two:SetPos( 12, 70 )
	two:SetSize( 300, 20 )
	two:SetText( "the GMod wiki - VGUI element list" )
	two:SetURL( "https://wiki.facepunch.com/gmod/VGUI_Element_List" )

	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( 12, 102 )
	hint:SetSize( 300, 40 )
	hint:SetWrap( true )
	hint:SetText( "hover = brighter blue, click = opens the page in your browser" )

	return frame
end

--- DNumberScratch: hold the left button on a field and drag sideways to scrub, up
--- and down to change the zoom; the scratch window is drawn from PaintOver here
--- (this fork has no DrawOverlay hook) and only while it is being dragged.
DEMOS[ "DNumberScratch" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 320, 200 )
	frame:SetTitle( "DNumberScratch  -  demo" )
	frame:Center()
	frame:MakePopup()

	CreateClientConVar( "hl2sb_demo_scratch", "0", true, false )

	local scratch = vgui.Create( "DNumberScratch", frame )
	scratch:SetPos( 12, 45 )
	scratch:SetSize( 16, 16 )
	scratch:SetMin( 0 )
	scratch:SetMax( 100 )
	scratch:SetDecimals( 2 )
	scratch:SetValue( 50 )
	scratch:SetConVar( "hl2sb_demo_scratch" )

	local whole = vgui.Create( "DNumberScratch", frame )
	whole:SetPos( 40, 45 )
	whole:SetSize( 16, 16 )
	whole:SetMin( 0 )
	whole:SetMax( 10 )
	whole:SetDecimals( 0 )
	whole:SetValue( 5 )

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 12, 80 )
	status:SetSize( 290, 16 )
	status:SetText( "value: 50.00" )

	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( 12, 110 )
	hint:SetSize( 290, 60 )
	hint:SetWrap( true )
	hint:SetText( "left button on the icon = scratch (the window above), right button = scrub " ..
		"without it, shift = hold the zoom, middle of the field = the exact value" )

	function scratch:OnValueChanged( value )
		status:SetText( string.format( "value: %.2f   convar: %s", value, GetConVarString( "hl2sb_demo_scratch" ) ) )
	end

	return frame
end

--- DHScrollBar: a horizontal scrollbar with its own canvas.  Drag the grip, click
--- an arrow, click either side of the grip, or wheel - the status line shows the
--- value DHorizontalScroller/DFileBrowser read through GetScroll/GetOffset.
DEMOS[ "DHScrollBar" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 420, 150 )
	frame:SetTitle( "DHScrollBar  -  demo" )
	frame:Center()
	frame:MakePopup()

	local bar = vgui.Create( "DHScrollBar", frame )
	bar:SetPos( 12, 45 )
	bar:SetSize( 396, 16 )
	bar:SetUp( 100, 500 )			-- bar size, canvas size

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 12, 75 )
	status:SetSize( 396, 16 )
	status:SetText( "scroll 0" )

	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( 12, 100 )
	hint:SetSize( 396, 30 )
	hint:SetWrap( true )
	hint:SetText( "drag the grip / click the arrows / click the track / wheel over it" )

	-- DHorizontalScroller and friends call this back with the offset
	function frame:OnHScroll( offset )
		status:SetText( "offset " .. tostring( offset ) .. "   scroll " .. tostring( math.floor( bar:GetScroll() ) ) )
	end

	return frame
end

--- DCategoryHeader: GMod's collapsible-category header button.  Clicking it toggles
--- its parent (the DCollapsibleCategory below), and the caption colour follows
--- Skin.Colours.Category for the open/closed state.
DEMOS[ "DCategoryHeader" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 320, 190 )
	frame:SetTitle( "DCategoryHeader  -  demo" )
	frame:Center()
	frame:MakePopup()

	local cat = vgui.Create( "DCollapsibleCategory", frame )
	cat:SetPos( 12, 45 )
	cat:SetSize( 296, 24 )				-- the body grows when it expands
	cat:SetLabel( "a category" )
	cat:SetExpanded( true )

	-- GMod's category creates the header itself; this fork's category paints its own,
	-- so the header is created here to show the control on its own
	local header = vgui.Create( "DCategoryHeader", cat )
	header:SetPos( 0, 0 )
	header:SetSize( 296, 22 )
	header:SetText( "a category (DCategoryHeader)" )

	local hint = vgui.Create( "DLabel", frame )
	hint:SetPos( 12, 80 )
	hint:SetSize( 296, 60 )
	hint:SetWrap( true )
	hint:SetText( "click the header: it toggles its parent category.  GMod's category " ..
		"paints the header caption itself; this fork's does too, so the control draws " ..
		"its own caption through the skin's CategoryHead hook when it is on its own" )

	return frame
end

--- DPropertySheet: three tabs, each one a DTab control (GMod's tab strip).  Clicking
--- a tab switches the visible page, the active tab is the taller one, and
--- OnActiveTabChanged reports the switch.
DEMOS[ "DPropertySheet" ] = function()
	local frame = vgui.Create( "DFrame" )
	if ( not frame ) then return nil end

	frame:SetSize( 380, 330 )
	frame:SetTitle( "DPropertySheet  -  demo" )
	frame:Center()
	frame:MakePopup()

	local sheet = vgui.Create( "DPropertySheet", frame )
	sheet:SetPos( 10, 30 )
	sheet:SetSize( 360, 250 )

	local status = vgui.Create( "DLabel", frame )
	status:SetPos( 10, 288 )
	status:SetSize( 360, 16 )
	status:SetText( "active tab: (none)" )

	local pages = {
		{ "first",  Color( 120, 40, 40, 255 ) },
		{ "second", Color( 40, 120, 40, 255 ) },
		{ "third",  Color( 40, 40, 120, 255 ), "icon16/page.png" },
	}

	for _, entry in ipairs( pages ) do
		local page = vgui.Create( "DPanel" )
		page:SetBackgroundColor( entry[ 2 ] )

		-- a DLabel has no size of its own (its text is clipped to its bounds), so the
		-- demo sizes it - the same thing every GMod example does
		local label = vgui.Create( "DLabel", page )
		label:SetPos( 10, 10 )
		label:SetSize( 330, 16 )
		label:SetText( "this is the " .. entry[ 1 ] .. " page (a " .. tostring( page:GetClassName() ) .. ")" )

		local sheetEntry = sheet:AddSheet( entry[ 1 ], page, entry[ 3 ] )
		if ( entry[ 3 ] ) then
			status:SetText( "entry " .. tostring( sheetEntry.Name ) .. " carries " .. entry[ 3 ] )
		end
	end

	function sheet:OnActiveTabChanged( old, new )
		status:SetText( "active tab: " .. tostring( new:GetText() ) ..
			"   (" .. tostring( new:GetTabHeight() ) .. "px tall)" )
	end

	return frame
end

concommand.Add( "hl2sb_derma_wiki", function( _, _, args )
	local class = args and args[ 1 ]

	if ( not class or class == "" ) then
		local names = {}

		for name in pairs( WIKI_EXAMPLES ) do names[ #names + 1 ] = name end
		table.sort( names )

		print( "[HL2SB derma] usage: hl2sb_derma_wiki <Class>   -- have: " ..
			table.concat( names, " " ) .. "\n" )
		return
	end

	local builder = WIKI_EXAMPLES[ class ]

	if ( not builder ) then
		print( "[HL2SB derma] no wiki example recorded for '" .. class .. "'\n" )
		return
	end

	local ok, frame = pcall( builder )

	if ( not ok ) then
		print( "[HL2SB derma] the wiki example for '" .. class .. "' failed: " ..
			tostring( frame ) .. "\n" )
		return
	end

	print( "[HL2SB derma] wiki example for '" .. class .. "' opened\n" )
end, nil, "Open the wiki page's own example for a control" )

concommand.Add( "hl2sb_derma_demo", function( _, _, args )
	local name = args and args[ 1 ]

	if ( not name or name == "" ) then
		local names = {}

		for demo in pairs( DEMOS ) do names[ #names + 1 ] = demo end
		table.sort( names )

		print( "[HL2SB derma] usage: hl2sb_derma_demo <name>   -- have: " ..
			table.concat( names, " " ) .. "\n" )
		return
	end

	local builder = DEMOS[ name ]

	if ( not builder ) then
		print( "[HL2SB derma] no demo recorded for '" .. name .. "'\n" )
		return
	end

	local ok, frame = pcall( builder )

	if ( not ok ) then
		print( "[HL2SB derma] the demo for '" .. name .. "' failed: " ..
			tostring( frame ) .. "\n" )
		return
	end

	print( "[HL2SB derma] demo for '" .. name .. "' opened\n" )
end, nil, "Open a hand-written demo for a control whose wiki page has no example" )

print( "[HL2SB] hl2sb_derma_check.lua loaded (hl2sb_derma_list / hl2sb_derma_show / hl2sb_derma_wiki / hl2sb_derma_demo)\n" )