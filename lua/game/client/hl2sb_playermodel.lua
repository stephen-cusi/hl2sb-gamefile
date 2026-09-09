--[[----------------------------------------------------------------------------
    hl2sb_playermodel.lua

    GMod-style player model menu, written entirely in Lua.

    Modelled on garrysmod/gamemodes/sandbox/gamemode/editor_player.lua:

        +--------------------------------------------------+
        | Player Model                                     |
        +---------------------------+----------------------+
        |                           | [ search box       ] |
        |                           | +------------------+ |
        |      3D model preview     | | model            | |
        |   (drag = rotate,         | | model            | |
        |    wheel = zoom,          | | ...              | |
        |    click = next anim)     | +------------------+ |
        +---------------------------+----------------------+
        |           [ Confirm ]  [ Cancel ]                |
        +--------------------------------------------------+

    Everything interactive is drawn by hand from vgui.Panel + surface.  The
    Frame is used only for its window chrome (caption, drag, resize), because
    LFrame forwards *nothing* to Lua - no Paint, no OnCommand, no
    PerformLayout - so a registered Frame subclass cannot own its own buttons
    or react to its own commands.  Layout is therefore re-applied every frame
    from a hook.

    Console:
        hl2sb_playermodel            - open the menu
        hl2sb_playermodel_debug      - dump the panel tree
----------------------------------------------------------------------------]]--

if ( not _CLIENT ) then return end

require( "hl2sb" )

-------------------------------------------------------------------------------
-- Tunables
-------------------------------------------------------------------------------
local WINDOW_W_FRAC   = 0.72
local WINDOW_H_FRAC   = 0.78
local MIN_W           = 720
local MIN_H           = 460

local PREVIEW_FRAC    = 0.52
local LIST_ROW_H      = 22
local GAP             = 8
local CAPTION_H       = 24

local CLR_BG          = { 32, 32, 32, 245 }
local CLR_LIST_BG     = { 28, 28, 28, 255 }
local CLR_TEXT        = { 220, 220, 220, 255 }
local CLR_TEXT_DIM    = { 140, 140, 140, 255 }
local CLR_TEXT_SEL    = { 255, 255, 255, 255 }
local CLR_SEL         = { 70, 110, 160, 255 }
local CLR_HOVER       = { 60, 60, 60, 255 }
local CLR_SCROLL      = { 110, 110, 110, 200 }
local CLR_INPUT_BG    = { 22, 22, 22, 255 }
local CLR_BTN         = { 60, 60, 60, 255 }
local CLR_BTN_HOVER   = { 85, 85, 85, 255 }
local CLR_BTN_DOWN    = { 45, 45, 45, 255 }

local TEXT_TALL       = 18

local ZOOM_STEP       = 0.08
local ZOOM_MIN        = 0.25
local ZOOM_MAX        = 4.0
local ROTATE_SPEED    = 0.5
local FOV             = 54

local MOUSE_LEFT      = 107

-------------------------------------------------------------------------------
-- Fonts
-------------------------------------------------------------------------------
local hText = surface.CreateFont()
surface.SetFontGlyphSet( hText, "Default", TEXT_TALL, 600, 0, 0, 0x010 )

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

-- Panel:GetCursorPos is not bound in HL2SB (the binding is commented out and
-- only input.GetCursorPosition exists), so every handler goes through this.
local function CursorPos()
	local x, y = input.GetCursorPosition()
	return x or 0, y or 0
end

local function DrawTextAt( str, x, y, clr, alpha )
	if ( not str or str == "" ) then return 0 end

	surface.DrawSetTextFont( hText )
	surface.DrawSetTextColor( clr[1], clr[2], clr[3], alpha or clr[4] or 255 )
	surface.DrawSetTextPos( x, y )
	surface.DrawPrintText( str )

	return surface.GetTextSize( hText, str )
end

local function FillRect( x, y, w, h, clr, alpha )
	surface.DrawSetColor( clr[1], clr[2], clr[3], alpha or clr[4] or 255 )
	surface.DrawFilledRect( x, y, x + w, y + h )
end

local function OutlineRect( x, y, w, h, clr )
	surface.DrawSetColor( clr[1], clr[2], clr[3], clr[4] or 255 )
	surface.DrawOutlinedRect( x, y, x + w, y + h )
end

-- Screen position of a panel.
--
-- Panel:LocalToScreen/ScreenToLocal are unusable in HL2SB: the bindings declare
-- local int x, y without initialising them and call the in/out method with those
-- garbage values, so they return stack junk (observed: localY = -842002995).
-- Walk the parent chain instead - every Lua-created panel is a child of the
-- full-screen Lua root, so summing GetPos() gives the real screen offset.
local function PanelScreenPos( panel )
	local x, y = 0, 0
	local p = panel

	-- GetParent() returns INVALID_PANEL (a userdata, so truthy) at the root,
	-- not nil - indexing it throws "attempt to index an INVALID_PANEL".
	while ( p and tostring( p ) ~= "INVALID_PANEL" ) do
		local px, py = p:GetPos()
		x = x + ( px or 0 )
		y = y + ( py or 0 )
		p = p:GetParent()
	end

	return x, y
end

-- vgui.register() errors if the class name is already taken, which makes
-- lua_dofile_cl abort on reload and leaves the old definitions in place.  Drop
-- the previous factory first: tHelpers inside vgui.lua is keyed by name, so the
-- freshly registered table simply replaces the old one.
local function Register( tbl, name, base )
	vgui[ name ] = nil
	vgui.register( tbl, name, base )
end

local function ScreenToLocalY( panel, screenY )
	local _, top = PanelScreenPos( panel )
	return screenY - top
end

-------------------------------------------------------------------------------
-- Button: drawn by hand, so it does not depend on the C++ Button binding or on
-- the Frame forwarding OnCommand.
-------------------------------------------------------------------------------
local BUTTON = {}

function BUTTON:Init()
	self.bDown = false
	self.bHover = false
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
end

function BUTTON:Paint()
	local w, h = self:GetWide(), self:GetTall()

	local clr = CLR_BTN
	if ( self.bDown ) then clr = CLR_BTN_DOWN
	elseif ( self.bHover ) then clr = CLR_BTN_HOVER end

	FillRect( 0, 0, w, h, clr )
	OutlineRect( 0, 0, w, h, CLR_TEXT_DIM )

	local label = self.Label or "?"
	local tw = surface.GetTextSize( hText, label )
	DrawTextAt( label, floor( ( w - tw ) * 0.5 ), floor( ( h - TEXT_TALL ) * 0.5 ), CLR_TEXT )
end

function BUTTON:OnCursorEntered()
	self.bHover = true
	self:Repaint()
end

function BUTTON:OnCursorExited()
	self.bHover = false
	self:Repaint()
end

function BUTTON:OnMousePressed( code )
	if ( code == MOUSE_LEFT ) then
		self.bDown = true
		self:Repaint()
	end
end

function BUTTON:OnMouseReleased( code )
	if ( code ~= MOUSE_LEFT or not self.bDown ) then return end

	self.bDown = false
	self:Repaint()

	if ( self.OnClick ) then
		self:OnClick()
	end
end

Register( BUTTON, "HL2SBBtn", "Panel" )

-------------------------------------------------------------------------------
-- ScrollList
-------------------------------------------------------------------------------
local SCROLL_LIST = {}

function SCROLL_LIST:Init()
	self.Items    = self.Items or {}
	self.Selected = self.Selected or 0
	self.Hovered  = 0
	self.Scroll   = 0
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
end

function SCROLL_LIST:SetItems( items )
	self.Items = items or {}
	self.Selected = 0
	self.Scroll = 0
end

function SCROLL_LIST:GetSelected()
	return self.Items[ self.Selected ]
end

function SCROLL_LIST:GetMaxScroll()
	return max( 0, #self.Items * LIST_ROW_H - self:GetTall() )
end

function SCROLL_LIST:EnsureVisible( index )
	local y = ( index - 1 ) * LIST_ROW_H
	local tall = self:GetTall()

	if ( y < self.Scroll ) then
		self.Scroll = y
	elseif ( y + LIST_ROW_H > self.Scroll + tall ) then
		self.Scroll = y + LIST_ROW_H - tall
	end

	self.Scroll = max( 0, min( self.Scroll, self:GetMaxScroll() ) )
end

function SCROLL_LIST:Select( index )
	if ( index < 1 or index > #self.Items ) then return end

	self.Selected = index
	self:EnsureVisible( index )

	if ( self.OnSelect ) then
		self:OnSelect( self.Items[ index ], index )
	end
end

function SCROLL_LIST:ScreenToRow( screenY )
	return floor( ( ScreenToLocalY( self, screenY ) + self.Scroll ) / LIST_ROW_H ) + 1
end

function SCROLL_LIST:Paint()
	local w, h = self:GetWide(), self:GetTall()

	FillRect( 0, 0, w, h, CLR_LIST_BG )

	local nScrollbarW = ( self:GetMaxScroll() > 0 ) and 6 or 0
	local nTextW = w - nScrollbarW - 12

	-- Note the loop must SKIP rows scrolled above the viewport, not break: with
	-- a break the very first (negative) row ended the whole loop, which is what
	-- made the list go completely black as soon as it was scrolled.
	for i, item in ipairs( self.Items ) do
		local y = ( i - 1 ) * LIST_ROW_H - self.Scroll
		if ( y > h ) then break end

		if ( y + LIST_ROW_H >= 0 ) then

		if ( i == self.Selected ) then
			FillRect( 0, y, w - nScrollbarW, LIST_ROW_H, CLR_SEL )
		elseif ( i == self.Hovered ) then
			FillRect( 0, y, w - nScrollbarW, LIST_ROW_H, CLR_HOVER )
		end

		local clr = ( i == self.Selected ) and CLR_TEXT_SEL or CLR_TEXT
		local label = tostring( item.name or "?" )

		while ( #label > 3 and surface.GetTextSize( hText, label ) > nTextW ) do
			label = string.sub( label, 1, #label - 4 ) .. "..."
		end

			DrawTextAt( label, 6, y + floor( ( LIST_ROW_H - TEXT_TALL ) * 0.5 ), clr )
		end
	end

	if ( nScrollbarW > 0 ) then
		local nMax = self:GetMaxScroll()
		local nThumbH = max( 20, floor( h * h / ( #self.Items * LIST_ROW_H ) ) )
		local nThumbY = floor( ( h - nThumbH ) * ( self.Scroll / nMax ) )
		FillRect( w - nScrollbarW, nThumbY, nScrollbarW, nThumbH, CLR_SCROLL )
	end
end

function SCROLL_LIST:OnMouseWheeled( delta )
	print( string.format( "[HL2SB] DIAG list wheel: delta=%d scroll=%d max=%d tall=%d items=%d\n",
		delta, self.Scroll or -1, self:GetMaxScroll(), self:GetTall(), #( self.Items or {} ) ) )
	self.Scroll = max( 0, min( self.Scroll - delta * LIST_ROW_H * 2, self:GetMaxScroll() ) )
	self:Repaint()
end

function SCROLL_LIST:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end

	local _, y = CursorPos()
	local localY = ScreenToLocalY( self, y )
	local index = self:ScreenToRow( y )

	print( string.format( "[HL2SB] DIAG list click: screenY=%d localY=%d row=%d items=%d\n",
		y, localY, index, #self.Items ) )

	if ( index >= 1 and index <= #self.Items ) then
		self:Select( index )
		self:Repaint()
	end
end

function SCROLL_LIST:OnCursorMoved()
	local _, y = CursorPos()
	local index = self:ScreenToRow( y )

	if ( index ~= self.Hovered ) then
		self.Hovered = ( index >= 1 and index <= #self.Items ) and index or 0
		self:Repaint()
	end
end

Register( SCROLL_LIST, "HL2SBScrollList", "Panel" )

-------------------------------------------------------------------------------
-- TextInput
-------------------------------------------------------------------------------
local KEY_CHARS = {
	SPACE = " ", PERIOD = ".", MINUS = "-", UNDERLINE = "_", COMMA = ",",
	SLASH = "/", BACKSLASH = "\\", SEMICOLON = ";", APOSTROPHE = "'",
	LBRACKET = "[", RBRACKET = "]", EQUAL = "=", BACKTICK = "`",
	KP_0 = "0", KP_1 = "1", KP_2 = "2", KP_3 = "3", KP_4 = "4",
	KP_5 = "5", KP_6 = "6", KP_7 = "7", KP_8 = "8", KP_9 = "9",
}

local TEXT_INPUT = {}

function TEXT_INPUT:Init()
	self.Value = self.Value or ""
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( true )
end

function TEXT_INPUT:GetValue()
	return self.Value
end

function TEXT_INPUT:Focus()
	self:RequestFocus()
	self.bFocused = true
	self:Repaint()
end

function TEXT_INPUT:Paint()
	local w, h = self:GetWide(), self:GetTall()

	FillRect( 0, 0, w, h, CLR_INPUT_BG )
	OutlineRect( 0, 0, w, h, self.bFocused and CLR_SEL or CLR_TEXT_DIM )

	if ( self.Value == "" and not self.bFocused ) then
		DrawTextAt( self.Placeholder or "", 6, floor( ( h - TEXT_TALL ) * 0.5 ), CLR_TEXT_DIM )
		return
	end

	DrawTextAt( self.Value, 6, floor( ( h - TEXT_TALL ) * 0.5 ), CLR_TEXT )

	if ( self.bFocused ) then
		local nW = surface.GetTextSize( hText, self.Value )
		FillRect( 6 + nW + 1, 3, 1, h - 6, CLR_TEXT )
	end
end

function TEXT_INPUT:OnMousePressed( code )
	print( string.format( "[HL2SB] DIAG search press: code=%d\n", code ) )
	if ( code == MOUSE_LEFT ) then
		self:Focus()
	end
end

function TEXT_INPUT:OnKeyCodeTyped( code )
	local name = self:KeyCodeToString( code )
	print( string.format( "[HL2SB] DIAG search key: code=%d name=%s\n", code, tostring( name ) ) )
	if ( not name ) then return end

	-- KeyCodeToString() prefixes every name with "KEY_" ("KEY_BACKSPACE",
	-- "KEY_1", ...), so strip it once before classifying the key.
	local key = name
	if ( string.sub( key, 1, 4 ) == "KEY_" ) then
		key = string.sub( key, 5 )
	end

	if ( key == "BACKSPACE" ) then
		self.Value = string.sub( self.Value, 1, #self.Value - 1 )
	elseif ( key == "ESCAPE" ) then
		self.bFocused = false
	elseif ( key == "ENTER" ) then
		self.bFocused = false
	else
		local ch = KEY_CHARS[ name ] or KEY_CHARS[ key ]
		if ( not ch and #key == 1 ) then
			ch = string.lower( key )
		end
		if ( ch ) then
			self.Value = self.Value .. ch
		end
	end

	self:Repaint()

	if ( self.OnValueChange ) then
		self:OnValueChange( self.Value )
	end
end

Register( TEXT_INPUT, "HL2SBTextInput", "Panel" )

-------------------------------------------------------------------------------
-- Preview
-------------------------------------------------------------------------------
local PREVIEW = {}

-- Preview state lives in this weak-keyed table rather than on the panel itself.
-- Writing fields on a ModelPanel goes through ModelPanel___newindex, which
-- throws "attempt to index a non-scripted panel" once the panel is no longer a
-- live LModelPanel (observed at line 461 after the menu was reopened).
-- Keyed by VPANEL, not by the panel object: every lua_pushpanel() hands Lua a
-- fresh userdata for the same panel, so keying by the userdata never hits and
-- the state (and the method snapshot) was rebuilt empty on every call.
local PreviewState = {}

local function PState( panel )
	local key = panel:GetVPanel()
	local st = PreviewState[ key ]
	if ( not st ) then
		st = { bDragging = false, nDragStartX = 0, nLastX = 0, bMoved = false,
			   nYaw = 180, nZoom = 1.0, nSeq = 0 }
		PreviewState[ key ] = st
	end
	return st
end

function PREVIEW:Init()
	print( string.format(
		"[HL2SB] DIAG methods: SetModel=%s SetYaw=%s SetZoom=%s SetFOV=%s Refit=%s Play=%s GetSeq=%s\n",
		tostring( self.SetModel ), tostring( self.SetYaw ), tostring( self.SetZoom ),
		tostring( self.SetFOV ), tostring( self.RefitCamera ),
		tostring( self.PlaySequence ), tostring( self.GetSequenceCount ) ) )
	local st = PState( self )
	st.bDragging = false
	st.nDragStartX = 0
	st.nLastX = 0
	st.bMoved = false
	st.nYaw = 180
	st.nZoom = 1.0

	-- No method snapshots here: whether the C-side methods resolve through the
	-- metatable chain has proven unreliable (they can come back nil), so each
	-- call site checks for the method before using it.

	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
	if ( self.SetZoomLimits ) then self:SetZoomLimits( ZOOM_MIN, ZOOM_MAX ) end
	if ( self.SetFOV ) then self:SetFOV( FOV ) end
	if ( self.SetYaw ) then self:SetYaw( st.nYaw ) end
	if ( self.SetZoom ) then self:SetZoom( st.nZoom ) end
end

function PREVIEW:LoadModel( path )
	if ( not self.SetModel ) then return false end

	local ok = self:SetModel( path )
	if ( ok ) then
		local st = PState( self )
		if ( self.RefitCamera ) then self:RefitCamera() end
		st.nYaw = 180
		if ( self.SetYaw ) then self:SetYaw( st.nYaw ) end
	end
	return ok
end

function PREVIEW:CycleAnimation()
	if ( not self.GetSequenceCount or not self.PlaySequence ) then return end

	local n = self:GetSequenceCount()
	if ( n <= 0 ) then return end

	local st = PState( self )
	st.nSeq = ( st.nSeq or 0 ) + 1
	if ( st.nSeq >= n ) then st.nSeq = 0 end

	if ( self.GetSequenceName ) then
		self:PlaySequence( self:GetSequenceName( st.nSeq ) )
	end
end

function PREVIEW:OnMousePressed( code )
	print( string.format( "[HL2SB] DIAG preview press: code=%d SetYaw=%s SetZoom=%s\n",
		code, tostring( self.SetYaw ), tostring( self.SetZoom ) ) )
	if ( code ~= MOUSE_LEFT ) then return end

	local st = PState( self )
	local x = CursorPos()
	st.bDragging = true
	st.bMoved = false
	st.nDragStartX = x
	st.nLastX = x
end

function PREVIEW:OnCursorMoved()
	local st = PState( self )
	if ( not st.bDragging ) then return end

	local x = CursorPos()
	local dx = x - st.nLastX
	st.nLastX = x

	if ( abs( x - st.nDragStartX ) > 3 ) then
		st.bMoved = true
	end

	if ( dx ~= 0 ) then
		st.nYaw = st.nYaw + dx * ROTATE_SPEED
		if ( self.SetYaw ) then self:SetYaw( st.nYaw ) end
	end
end

function PREVIEW:OnMouseReleased( code )
	local st = PState( self )
	if ( code ~= MOUSE_LEFT or not st.bDragging ) then return end

	st.bDragging = false
	if ( not st.bMoved ) then
		self:CycleAnimation()
	end
end

function PREVIEW:OnMouseWheeled( delta )
	print( string.format( "[HL2SB] DIAG preview wheel: delta=%d\n", delta ) )
	local st = PState( self )
	st.nZoom = max( ZOOM_MIN, min( ZOOM_MAX, ( st.nZoom or 1.0 ) - delta * ZOOM_STEP ) )
	if ( self.SetZoom ) then self:SetZoom( st.nZoom ) end
end

Register( PREVIEW, "HL2SBModelPreview", "ModelPanel" )

-------------------------------------------------------------------------------
-- The menu
-------------------------------------------------------------------------------
local MENU = {}

function MENU:Init()
	self.bBuilt = false
	self.bClosing = false
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( true )
end

function MENU:Build()
	if ( self.bBuilt ) then return end
	self.bBuilt = true

	local sw, sh = surface.GetScreenSize()
	local w = floor( max( MIN_W, sw * WINDOW_W_FRAC ) )
	local h = floor( max( MIN_H, sh * WINDOW_H_FRAC ) )

	self:SetSize( w, h )
	self:SetPos( floor( ( sw - w ) * 0.5 ), floor( ( sh - h ) * 0.5 ) )
	self:SetTitle( "Player Model", true )
	self:SetCloseButtonVisible( false )
	self:SetMinimizeButtonVisible( false )
	self:SetMaximizeButtonVisible( false )
	self:MakePopup()
	self:SetVisible( true )

	self.Preview = vgui.HL2SBModelPreview( self, "Preview" )

	self.Search = vgui.HL2SBTextInput( self, "Search" )
	self.Search.Placeholder = "search..."
	self.Search.OnValueChange = function( _, str ) self:ApplyFilter( str ) end

	self.List = vgui.HL2SBScrollList( self, "ModelList" )
	self.List.OnSelect = function( _, item ) self:PreviewModel( item ) end

	self.Confirm = vgui.HL2SBBtn( self, "Confirm" )
	self.Confirm.Label = "Confirm"
	self.Confirm.OnClick = function() self:ConfirmSelection() end

	self.Cancel = vgui.HL2SBBtn( self, "Cancel" )
	self.Cancel.Label = "Cancel"
	self.Cancel.OnClick = function() self:Close() end

	self.Status = ""
	self:LoadModelList()
	self:Layout()

	-- LFrame forwards nothing to Lua, so PerformLayout/Paint never fire on this
	-- table.  Re-apply the layout every frame instead, and keep the window up:
	-- something in the engine hides it (or its parent) about 40 seconds in, and
	-- a hidden panel is not painted.
	hook.add( "HudViewportPaint", "hl2sb_playermodel_tick", function()
		if ( self.bClosing ) then return end

		if ( not self:IsVisible() ) then
			self:SetVisible( true )
		end

		self:Layout()
	end )
end

-- Position every child from the current size, so resizing keeps the layout.
function MENU:Layout()
	local w, h = self:GetWide(), self:GetTall()
	local nPreviewW = floor( w * PREVIEW_FRAC )
	local nTop = CAPTION_H + 6
	local nBottom = 34

	if ( self.Preview ) then
		self.Preview:SetPos( 0, CAPTION_H )
		self.Preview:SetSize( nPreviewW, h - CAPTION_H - nBottom )
	end

	if ( self.Search ) then
		self.Search:SetPos( nPreviewW + GAP, nTop )
		self.Search:SetSize( w - nPreviewW - GAP * 2, 22 )
	end

	if ( self.List ) then
		self.List:SetPos( nPreviewW + GAP, nTop + 22 + GAP )
		self.List:SetSize( w - nPreviewW - GAP * 2, h - nTop - 22 - GAP * 2 - nBottom )
	end

	if ( self.Confirm ) then
		self.Confirm:SetPos( nPreviewW + GAP, h - nBottom + 5 )
		self.Confirm:SetSize( 120, 24 )
	end

	if ( self.Cancel ) then
		self.Cancel:SetPos( nPreviewW + GAP + 128, h - nBottom + 5 )
		self.Cancel:SetSize( 120, 24 )
	end
end

function MENU:LoadModelList()
	self.AllModels = hl2sb.GetPlayerModels() or {}
	self:ApplyFilter( self.Search and self.Search:GetValue() or "" )
end

function MENU:ApplyFilter( str )
	str = string.lower( str or "" )

	local filtered = {}
	for _, m in ipairs( self.AllModels or {} ) do
		if ( str == "" or string.find( string.lower( m.name or "" ), str, 1, true )
					   or string.find( string.lower( m.model or "" ), str, 1, true ) ) then
			filtered[ #filtered + 1 ] = m
		end
	end

	self.List:SetItems( filtered )
	self:SetStatus( string.format( "%d / %d models", #filtered, #( self.AllModels or {} ) ) )

	if ( #filtered > 0 ) then
		self.List:Select( 1 )
	end
end

function MENU:PreviewModel( item )
	if ( not item or not self.Preview ) then return end

	if ( not hl2sb.IsModelPrecached( item.model ) ) then
		self:SetStatus( string.format( "%s is not available", item.name ) )
		return
	end

	-- Do not reload the same model: ApplyFilter() re-selects the first match on
	-- every keystroke, and reloading resets the camera and animation each time.
	if ( self.szPreviewPath ~= item.model ) then
		self.szPreviewPath = item.model
		self.Preview:LoadModel( item.model )
	end

	self:SetStatus( item.name )
end

function MENU:ConfirmSelection()
	local item = self.List and self.List:GetSelected()
	if ( item ) then
		local ok = hl2sb.SetPlayerModel( item.name )
		print( string.format( "[HL2SB] playermodel menu: confirm '%s' -> %s\n",
			tostring( item.name ), tostring( ok ) ) )
	end
	self:Close()
end

function MENU:SetStatus( str )
	self.Status = str or ""
	self:Repaint()
end

function MENU:Close()
	self.bClosing = true
	hook.remove( "HudViewportPaint", "hl2sb_playermodel_tick" )
	self:SetVisible( false )
	self:MarkForDeletion()
	g_HL2SBPlayerModelMenu = nil
end

Register( MENU, "HL2SBPlayerModelMenu", "Frame" )

-------------------------------------------------------------------------------
-- Entry point
-------------------------------------------------------------------------------
function hl2sb.OpenPlayerModelMenu()
	if ( g_HL2SBPlayerModelMenu ) then
		g_HL2SBPlayerModelMenu:MarkForDeletion()
		g_HL2SBPlayerModelMenu = nil
	end

	print( "[HL2SB] playermodel menu: opening\n" )

	local menu = vgui.HL2SBPlayerModelMenu( nil, "HL2SBPlayerModelMenu" )
	g_HL2SBPlayerModelMenu = menu
	menu:Build()

	print( string.format( "[HL2SB] playermodel menu: built, models=%d visible=%s\n",
		#( menu.AllModels or {} ), tostring( menu:IsVisible() ) ) )

	return menu
end

concommand.Create( "hl2sb_playermodel", function()
	hl2sb.OpenPlayerModelMenu()
end, "Open the GMod-style player model menu" )

concommand.Create( "hl2sb_playermodel_debug", function()
	local menu = g_HL2SBPlayerModelMenu
	if ( not menu ) then
		print( "[HL2SB] playermodel menu: not open\n" )
		return
	end

	local w, h = menu:GetSize()
	local x, y = menu:GetPos()
	print( string.format(
		"[HL2SB] menu: pos=%d,%d size=%dx%d visible=%s children=%d\n",
		x, y, w, h, tostring( menu:IsVisible() ), menu:GetChildCount() ) )

	for i = 0, menu:GetChildCount() - 1 do
		local child = menu:GetChild( i )
		if ( child ) then
			local cw, ch = child:GetSize()
			local cx, cy = child:GetPos()
			print( string.format(
				"[HL2SB]   child[%d] '%s' pos=%d,%d size=%dx%d visible=%s mouse=%s\n",
				i, tostring( child:GetName() ), cx, cy, cw, ch,
				tostring( child:IsVisible() ), tostring( child:IsMouseInputEnabled() ) ) )
		end
	end

	if ( menu.List ) then
		print( string.format( "[HL2SB]   list items=%d selected=%d scroll=%d\n",
			#( menu.List.Items or {} ), menu.List.Selected or 0, menu.List.Scroll or 0 ) )
	end
end, "Dump the player model menu panel tree" )

print( "[HL2SB] hl2sb_playermodel.lua loaded - run 'hl2sb_playermodel'\n" )
