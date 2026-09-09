--[[----------------------------------------------------------------------------
    hl2sb_playermodel.lua

    GMod-style player model menu, written entirely in Lua.

    Modelled on garrysmod/gamemodes/sandbox/gamemode/editor_player.lua:

        +--------------------------------------------------+
        | Player Model                                  [X]|
        +---------------------------+----------------------+
        |                           | [ search box       ] |
        |                           | +------------------+ |
        |      3D model preview     | | Category         | |
        |   (drag = rotate,         | |  model           | |
        |    wheel = zoom,          | |  model           | |
        |    click = next anim)     | | ...              | |
        |                           | +------------------+ |
        +---------------------------+----------------------+
        |           [ Confirm ]  [ Cancel ]                |
        +--------------------------------------------------+

    Everything here is built from vgui.Panel + surface, because the only
    control binding HL2SB lacked was the 3D preview (vgui.ModelPanel).

    Console:
        hl2sb_playermodel          - open the menu
        bind c "+hl2sb_playermodel" - optional hold-to-open bind
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

local PREVIEW_FRAC    = 0.52      -- preview takes this share of the width
local LIST_ROW_H      = 22
local GAP             = 8

local CLR_BG          = { 32, 32, 32, 245 }
local CLR_PANEL       = { 45, 45, 45, 255 }
local CLR_LIST_BG     = { 28, 28, 28, 255 }
local CLR_TEXT        = { 220, 220, 220, 255 }
local CLR_TEXT_DIM    = { 140, 140, 140, 255 }
local CLR_TEXT_SEL    = { 255, 255, 255, 255 }
local CLR_SEL         = { 70, 110, 160, 255 }
local CLR_HOVER       = { 60, 60, 60, 255 }
local CLR_SCROLL      = { 110, 110, 110, 200 }
local CLR_INPUT_BG    = { 22, 22, 22, 255 }

local TEXT_TALL       = 18
local TITLE_TALL      = 22

local ZOOM_STEP       = 0.08
local ZOOM_MIN        = 0.25
local ZOOM_MAX        = 4.0
local ROTATE_SPEED    = 0.5       -- degrees per pixel dragged
local FOV             = 54

-------------------------------------------------------------------------------
-- Fonts
-------------------------------------------------------------------------------
local hText = surface.CreateFont()
surface.SetFontGlyphSet( hText, "Default", TEXT_TALL, 600, 0, 0, 0x010 )

local hTitle = surface.CreateFont()
surface.SetFontGlyphSet( hTitle, "Default", TITLE_TALL, 700, 0, 0, 0x010 )

-------------------------------------------------------------------------------
-- Small helpers
-------------------------------------------------------------------------------
local floor, max, min = math.floor, math.max, math.min

local function DrawTextAt( str, x, y, clr, alpha )
	if ( not str or str == "" ) then return 0 end

	surface.DrawSetTextFont( hText )
	surface.DrawSetTextColor( clr[1], clr[2], clr[3], alpha or clr[4] or 255 )
	surface.DrawSetTextPos( x, y )
	surface.DrawPrintText( str )

	return surface.GetTextSize( hText, str )
end

-- Panel:GetCursorPos is not bound in HL2SB (the binding is commented out and
-- only input.GetCursorPosition exists), so every click handler goes through
-- this helper.
local function CursorPos()
	local x, y = input.GetCursorPosition()
	return x or 0, y or 0
end

local function FillRect( x, y, w, h, clr, alpha )
	surface.DrawSetColor( clr[1], clr[2], clr[3], alpha or clr[4] or 255 )
	surface.DrawFilledRect( x, y, x + w, y + h )
end

local function OutlineRect( x, y, w, h, clr )
	surface.DrawSetColor( clr[1], clr[2], clr[3], clr[4] or 255 )
	surface.DrawOutlinedRect( x, y, x + w, y + h )
end

-------------------------------------------------------------------------------
-- ScrollList: a scrollable, selectable text list drawn with surface.
--
-- GMod uses DPanelSelect with SpawnIcon tiles.  HL2SB has no SpawnIcon binding
-- (and no way to render a model thumbnail to a texture from Lua), so the list
-- is text based - the 3D preview on the left serves as the thumbnail.
-------------------------------------------------------------------------------
local SCROLL_LIST = {}

function SCROLL_LIST:Init()
	self.Items    = self.Items or {}
	self.Selected = self.Selected or 0
	self.Hovered  = 0
	self.Scroll   = 0
	self.OnSelect = self.OnSelect
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

function SCROLL_LIST:Paint()
	local w, h = self:GetWide(), self:GetTall()

	FillRect( 0, 0, w, h, CLR_LIST_BG )

	local nScrollbarW = ( self:GetMaxScroll() > 0 ) and 6 or 0
	local nTextW = w - nScrollbarW - 12

	for i, item in ipairs( self.Items ) do
		local y = ( i - 1 ) * LIST_ROW_H - self.Scroll
		if ( y + LIST_ROW_H < 0 ) then break end
		if ( y > h ) then break end

		if ( i == self.Selected ) then
			FillRect( 0, y, w - nScrollbarW, LIST_ROW_H, CLR_SEL )
		elseif ( i == self.Hovered ) then
			FillRect( 0, y, w - nScrollbarW, LIST_ROW_H, CLR_HOVER )
		end

		local clr = ( i == self.Selected ) and CLR_TEXT_SEL or CLR_TEXT
		local label = tostring( item.name or "?" )

		-- Truncate rather than overlap the scrollbar.
		while ( #label > 3 and surface.GetTextSize( hText, label ) > nTextW ) do
			label = string.sub( label, 1, #label - 4 ) .. "..."
		end

		DrawTextAt( label, 6, y + floor( ( LIST_ROW_H - TEXT_TALL ) * 0.5 ), clr )
	end

	-- scrollbar
	if ( nScrollbarW > 0 ) then
		local nMax = self:GetMaxScroll()
		local nThumbH = max( 20, floor( h * h / ( #self.Items * LIST_ROW_H ) ) )
		local nThumbY = floor( ( h - nThumbH ) * ( self.Scroll / nMax ) )
		FillRect( w - nScrollbarW, nThumbY, nScrollbarW, nThumbH, CLR_SCROLL )
	end
end

function SCROLL_LIST:OnMouseWheeled( delta )
	self.Scroll = max( 0, min( self.Scroll - delta * LIST_ROW_H * 2, self:GetMaxScroll() ) )
	self:Repaint()
end

-- vgui hands OnCursorMoved/OnMousePressed screen coordinates, so convert to
-- panel-local before indexing rows.
function SCROLL_LIST:ScreenToRow( screenY )
	local _, topY = self:LocalToScreen( 0, 0 )
	return floor( ( screenY - topY + self.Scroll ) / LIST_ROW_H ) + 1
end

function SCROLL_LIST:OnMousePressed( code )
	local _, y = CursorPos()
	local index = self:ScreenToRow( y )

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

vgui.register( SCROLL_LIST, "HL2SBScrollList", "Panel" )

-------------------------------------------------------------------------------
-- TextInput: minimal single-line text entry.
--
-- vgui.TextEntry is not bound to Lua, so this captures OnKeyCodeTyped and maps
-- the key code to a character with Panel:KeyCodeToString().
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

function TEXT_INPUT:SetValue( str )
	self.Value = str or ""
	self:Repaint()
end

function TEXT_INPUT:Focus()
	self:RequestFocus()
	self.bFocused = true
	self:Repaint()
end

function TEXT_INPUT:Paint()
	local w, h = self:GetWide(), self:GetTall()

	FillRect( 0, 0, w, h, CLR_INPUT_BG )
	OutlineRect( 0, 0, w, h, self.bFocused and CLR_SEL or CLR_HOVER )

	local str = self.Value
	if ( str == "" and not self.bFocused ) then
		DrawTextAt( self.Placeholder or "", 6, floor( ( h - TEXT_TALL ) * 0.5 ), CLR_TEXT_DIM )
		return
	end

	DrawTextAt( str, 6, floor( ( h - TEXT_TALL ) * 0.5 ), CLR_TEXT )

	if ( self.bFocused ) then
		local nW = surface.GetTextSize( hText, str )
		FillRect( 6 + nW + 1, 3, 1, h - 6, CLR_TEXT )
	end
end

function TEXT_INPUT:OnMousePressed()
	self:Focus()
end

function TEXT_INPUT:OnKeyCodeTyped( code )
	local name = self:KeyCodeToString( code )
	if ( not name ) then return end

	if ( name == "BACKSPACE" ) then
		self.Value = string.sub( self.Value, 1, #self.Value - 1 )
	elseif ( name == "ESCAPE" ) then
		self.bFocused = false
	elseif ( name == "ENTER" ) then
		self.bFocused = false
		if ( self.OnSubmit ) then self:OnSubmit( self.Value ) end
	else
		local ch = KEY_CHARS[ name ]

		if ( not ch and #name == 1 ) then
			ch = string.lower( name )
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

vgui.register( TEXT_INPUT, "HL2SBTextInput", "Panel" )

-------------------------------------------------------------------------------
-- Preview: vgui.ModelPanel plus drag-to-rotate / wheel-to-zoom / click-to-cycle.
-------------------------------------------------------------------------------
local PREVIEW = {}

function PREVIEW:Init()
	self.bDragging = false
	self.nDragStartX = 0
	self.nLastX = 0
	self.bMoved = false

	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
	self:SetZoomLimits( ZOOM_MIN, ZOOM_MAX )
	self:SetFOV( FOV )
	self:SetYaw( 180 )
	self:SetZoom( 1.0 )
end

function PREVIEW:LoadModel( path )
	local ok = self:SetModel( path )
	if ( ok ) then
		self:RefitCamera()
		self:SetYaw( 180 )
	end
	return ok
end

function PREVIEW:CycleAnimation()
	local n = self:GetSequenceCount()
	if ( n <= 0 ) then return end

	self.nSeq = ( self.nSeq or 0 ) + 1
	if ( self.nSeq >= n ) then self.nSeq = 0 end

	self:PlaySequence( self:GetSequenceName( self.nSeq ) )
end

function PREVIEW:OnMousePressed( code )
	if ( code ~= 107 ) then return end		-- MOUSE_LEFT

	local x = CursorPos()
	self.bDragging = true
	self.bMoved = false
	self.nDragStartX = x
	self.nLastX = x
end

function PREVIEW:OnCursorMoved()
	if ( not self.bDragging ) then return end

	local x = CursorPos()

	local dx = x - self.nLastX
	self.nLastX = x

	if ( math.abs( x - self.nDragStartX ) > 3 ) then
		self.bMoved = true
	end

	if ( dx ~= 0 ) then
		-- Track yaw in Lua: ModelPanel:GetYaw() is not reachable through the
		-- registered subclass' metatable chain.
		self.nYaw = ( self.nYaw or 180 ) + dx * ROTATE_SPEED
		self:SetYaw( self.nYaw )
	end
end

function PREVIEW:OnMouseReleased( code )
	if ( code ~= 107 or not self.bDragging ) then return end

	self.bDragging = false
	if ( not self.bMoved ) then
		self:CycleAnimation()
	end
end

function PREVIEW:OnMouseWheeled( delta )
	self.nZoom = max( ZOOM_MIN, min( ZOOM_MAX, ( self.nZoom or 1.0 ) - delta * ZOOM_STEP ) )
	self:SetZoom( self.nZoom )
end

vgui.register( PREVIEW, "HL2SBModelPreview", "ModelPanel" )

-------------------------------------------------------------------------------
-- The menu itself
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
	self:MakePopup()
	self:SetVisible( true )

	self.Preview = vgui.HL2SBModelPreview( self, "Preview" )
	self.Search = vgui.HL2SBTextInput( self, "Search" )
	self.Search.Placeholder = "search..."
	self.Search.OnValueChange = function( _, str ) self:ApplyFilter( str ) end

	self.List = vgui.HL2SBScrollList( self, "ModelList" )
	self.List.OnSelect = function( _, item ) self:PreviewModel( item ) end

	self.Confirm = vgui.Button( self, "Confirm", "Confirm", self, "Confirm" )
	self.Cancel = vgui.Button( self, "Cancel", "Cancel", self, "Cancel" )

	self.Status = ""

	self:Layout()

	self:LoadModelList()

	-- Keep the window up.  Something in the engine hides either this frame or
	-- its parent (m_pClientLuaPanel) roughly 40 seconds in; a hidden panel is
	-- not painted, so the preview "loses" its model even though the entity is
	-- still alive.  Re-assert visibility until the user actually closes it.
	hook.add( "HudViewportPaint", "hl2sb_playermodel_watch", function()
		if ( not self.bClosing and self.bBuilt and not self:IsVisible() ) then
			self:SetVisible( true )
		end
	end )
end

-- Position every child from the current size, so the window can be resized and
-- the layout survives it.
function MENU:Layout()
	local w, h = self:GetWide(), self:GetTall()
	local nPreviewW = floor( w * PREVIEW_FRAC )
	local nTop = 30
	local nBottom = 34

	if ( self.Preview ) then
		self.Preview:SetPos( 0, 24 )
		self.Preview:SetSize( nPreviewW, h - 24 - nBottom )
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
		self.Confirm:SetPos( nPreviewW + GAP, h - nBottom + 4 )
		self.Confirm:SetSize( 120, 24 )
	end

	if ( self.Cancel ) then
		self.Cancel:SetPos( nPreviewW + GAP + 128, h - nBottom + 4 )
		self.Cancel:SetSize( 120, 24 )
	end
end

function MENU:PerformLayout()
	self:Layout()
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

	-- Preview the first entry so the window is never empty.
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

	self.Preview:LoadModel( item.model )
	self:SetStatus( item.name )
end

function MENU:SetStatus( str )
	self.Status = str or ""
	if ( self.StatusLabel ) then
		self.StatusLabel:SetText( str )
	end
	self:Repaint()
end

function MENU:Paint()
	local w, h = self:GetWide(), self:GetTall()

	FillRect( 0, 0, w, h, CLR_BG )

	-- title bar
	FillRect( 0, 0, w, 24, CLR_PANEL )
	surface.DrawSetTextFont( hTitle )
	surface.DrawSetTextColor( CLR_TEXT[1], CLR_TEXT[2], CLR_TEXT[3], 255 )
	surface.DrawSetTextPos( 8, 2 )
	surface.DrawPrintText( "Player Model" )

	if ( self.Status and self.Status ~= "" ) then
		DrawTextAt( self.Status, 8, h - 26, CLR_TEXT_DIM )
	end
end

function MENU:OnCommand( command )
	if ( command == "Confirm" ) then
		local item = self.List and self.List:GetSelected()
		if ( item ) then
			local ok = hl2sb.SetPlayerModel( item.name )
			print( string.format( "[HL2SB] playermodel menu: confirm '%s' -> %s\n",
				tostring( item.name ), tostring( ok ) ) )
		end
		self:Close()
		return
	end

	if ( command == "Cancel" or command == "Close" ) then
		self:Close()
		return
	end
end

function MENU:Close()
	self.bClosing = true
	hook.remove( "HudViewportPaint", "hl2sb_playermodel_watch" )
	self:SetVisible( false )
	self:MarkForDeletion()
	g_HL2SBPlayerModelMenu = nil
end

vgui.register( MENU, "HL2SBPlayerModelMenu", "Frame" )

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

-- Dump the panel tree: layout and input state are the usual suspects when a
-- hand-built vgui tree looks right but does not respond.
concommand.Create( "hl2sb_playermodel_debug", function()
	local menu = g_HL2SBPlayerModelMenu
	if ( not menu ) then
		print( "[HL2SB] playermodel menu: not open\n" )
		return
	end

	local w, h = menu:GetSize()
	local x, y = menu:GetPos()
	print( string.format(
		"[HL2SB] menu: pos=%d,%d size=%dx%d visible=%s proportional=%s mouse=%s children=%d\n",
		x, y, w, h, tostring( menu:IsVisible() ), tostring( menu:IsProportional() ),
		tostring( menu:IsMouseInputEnabled() ), menu:GetChildCount() ) )

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

concommand.Create( "hl2sb_playermodel", function()
	hl2sb.OpenPlayerModelMenu()
end, "Open the GMod-style player model menu" )

print( "[HL2SB] hl2sb_playermodel.lua loaded - run 'hl2sb_playermodel'\n" )
