--[[----------------------------------------------------------------------------
    hl2sb_playermodel.lua

    GMod-style player model menu for HL2SB, written in Lua.

    Modelled on garrysmod/gamemodes/sandbox/gamemode/editor_player.lua and the
    in-game "Player Model" menu (model thumbnail grid + colour tab):

        +------------------------------------------------------+
        | Player Model                       [title bar   ]    |
        +---------------------------+--------------------------+
        |                           | [模型] [颜色]            |
        |                           | [ search box          ]  |
        |      3D model preview     | +--thumbnail grid------+ |
        |   (drag = rotate,        | | (icon) (icon) (icon) | |
        |    wheel = zoom,         | | (icon) (icon) (icon) | |
        |    click = next anim)    | | ...                  | |
        |                           | +---------------------+ |
        +---------------------------+--------------------------+
        |             [ Confirm ]  [ Cancel ]                  |
        +------------------------------------------------------+

    The Team Sandbox Lua SDK does not register TextEntry / ListPanel / Label /
    Menu / Slider / DPropertySheet / DColorMixer (they are declared in
    lControls.h but luaopen_vgui never opens them, so vgui.TextEntry etc. are
    nil).  Everything is therefore drawn by hand from surface, on top of
    LPanel which already forwards Paint / PerformLayout / mouse / key to Lua.

    Engine additions this relies on:
        * LFrame forwarding (lFrame) so the window runs its own layout/paint.
        * vgui.ModelImage (a model-rendering panel) for the thumbnail grid.
        * global LocalPlayer() + player:SetPlayerColor() for the colour tab.

    Console:
        hl2sb_playermodel  - open the menu
        hl2sb_playermodel_dbg  - dump the panel tree
-----------------------------------------------------------------------------]]--

if ( not _CLIENT ) then return end

require( "hl2sb" )

------------------------------------------------------------------------------
-- Tunables
------------------------------------------------------------------------------
local WINDOW_W_FRAC  = 0.72
local WINDOW_H_FRAC  = 0.78
local MIN_W          = 900
local MIN_H          = 560

local PREVIEW_FRAC   = 0.48
local GAP            = 8
local CAPTION_H      = 24
local BOTTOM_H       = 34

local THUMB_SIZE     = 64
local THUMB_GAP      = 6
local THUMB_PAD      = 8

local ZOOM_STEP      = 0.08
local ZOOM_MIN       = 0.25
local ZOOM_MAX       = 4.0
local ROTATE_SPEED   = 0.5
local FOV            = 54
local MOUSE_LEFT     = 107

local CLR_BG         = { 32, 32, 32, 245 }
local CLR_CNT_BG     = { 24, 24, 24, 255 }
local CLR_LIST_BG    = { 28, 28, 28, 255 }
local CLR_TEXT       = { 220, 220, 220, 255 }
local CLR_TEXT_DIM   = { 140, 140, 140, 255 }
local CLR_TEXT_SEL   = { 255, 255, 255, 255 }
local CLR_SEL        = { 70, 110, 160, 255 }
local CLR_HOVER      = { 60, 60, 60, 255 }
local CLR_SCROLL     = { 110, 110, 110, 200 }
local CLR_INPUT_BG   = { 22, 22, 22, 255 }
local CLR_BTN        = { 60, 60, 60, 255 }
local CLR_BTN_HOVER  = { 85, 85, 85, 255 }
local CLR_BTN_DOWN   = { 45, 45, 45, 255 }
local CLR_TAB        = { 46, 46, 46, 255 }
local CLR_TAB_ACT    = { 70, 110, 160, 255 }

local FONT_SIZE      = 14
local TEXT_TALL      = 18

------------------------------------------------------------------------------
-- Fonts
------------------------------------------------------------------------------
local hDefault = surface.CreateFont()
surface.SetFontGlyphSet( hDefault, "Default", FONT_SIZE, 0, 0, 0, 0x010 )

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local clamp = function( v, lo, hi ) return max( lo, min( hi, v ) ) end

local function CursorPos()
	local x, y = input.GetCursorPosition()
	return x or 0, y or 0
end

local function DrawTextAt( str, x, y, clr, alpha )
	if ( not str or str == "" ) then return 0 end
	surface.DrawSetTextFont( hDefault )
	surface.DrawSetTextColor( clr[1], clr[2], clr[3], alpha or clr[4] or 255 )
	surface.DrawSetTextPos( x, y )
	surface.DrawPrintText( str )
	return surface.GetTextSize( hDefault, str )
end

local function FillRect( x, y, w, h, clr, alpha )
	surface.DrawSetColor( clr[1], clr[2], clr[3], alpha or clr[4] or 255 )
	surface.DrawFilledRect( x, y, x + w, y + h )
end

local function OutlineRect( x, y, w, h, clr )
	surface.DrawSetColor( clr[1], clr[2], clr[3], clr[4] or 255 )
	surface.DrawOutlinedRect( x, y, x + w, y + h )
end

local function Register( tbl, name, base )
	vgui[ name ] = nil
	vgui.register( tbl, name, base )
end

------------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------------
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
	local tw = surface.GetTextSize( hDefault, label )
	DrawTextAt( label, floor( ( w - tw ) * 0.5 ), floor( ( h - TEXT_TALL ) * 0.5 ), CLR_TEXT )
end
function BUTTON:OnCursorEntered() self.bHover = true; self:Repaint() end
function BUTTON:OnCursorExited()  self.bHover = false; self:Repaint() end
function BUTTON:OnMousePressed( code )
	if ( code == MOUSE_LEFT ) then self.bDown = true; self:Repaint() end
end
function BUTTON:OnMouseReleased( code )
	if ( code ~= MOUSE_LEFT or not self.bDown ) then return end
	self.bDown = false; self:Repaint()
	if ( self.OnClick ) then self:OnClick() end
end
Register( BUTTON, "HL2SBBtn", "Panel" )

------------------------------------------------------------------------------
-- TextInput (search box)
------------------------------------------------------------------------------
local KEY_CHARS = {
	SPACE = " ", PERIOD = ".", MINUS = "-", UNDERLINE = "_", COMMA = ",",
	SLASH = "/", BACKSLASH = "\\", SEMICOLON = ";", APOSTROPHE = "'",
	LBRACKET = "[", RBRACKET = "]", EQUAL = "=", BACKTICK = "`",
	KP_0 = "0", KP_1 = "1", KP_2 = "2", KP_3 = "3", KP_4 = "4",
	KP_5 = "5", KP_6 = "6", KP_7 = "7", KP_8 = "8", KP_9 = "9",
}
local SEARCH_PANEL = {}
function SEARCH_PANEL:Init()
	self.Value = self.Value or ""
	self.bFocused = false
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( true )
end
function SEARCH_PANEL:GetValue() return self.Value end
function SEARCH_PANEL:Focus()
	-- LPanel::OnRequestFocus no longer calls vgui's BaseClass (which AV'd), so
	-- RequestFocus is safe now and gives the box real keyboard focus.
	self:RequestFocus()
	self.bFocused = true
	self:Repaint()
end
function SEARCH_PANEL:Paint()
	local w, h = self:GetWide(), self:GetTall()
	FillRect( 0, 0, w, h, CLR_INPUT_BG )
	OutlineRect( 0, 0, w, h, self.bFocused and CLR_SEL or CLR_TEXT_DIM )
	if ( self.Value == "" and not self.bFocused ) then
		DrawTextAt( self.Placeholder or "", 6, floor( ( h - TEXT_TALL ) * 0.5 ), CLR_TEXT_DIM )
		return
	end
	DrawTextAt( self.Value, 6, floor( ( h - TEXT_TALL ) * 0.5 ), CLR_TEXT )
	if ( self.bFocused ) then
		local nW = surface.GetTextSize( hDefault, self.Value )
		FillRect( 6 + nW + 1, 3, 1, h - 6, CLR_TEXT )
	end
end
function SEARCH_PANEL:OnMousePressed( code )
	if ( code == MOUSE_LEFT ) then self:Focus() end
end
function SEARCH_PANEL:OnKeyCodeTyped( code )
	local name = self:KeyCodeToString( code )
	if ( not name ) then return end
	local key = name
	if ( string.sub( key, 1, 4 ) == "KEY_" ) then key = string.sub( key, 5 ) end
	if ( key == "BACKSPACE" ) then
		self.Value = string.sub( self.Value, 1, #self.Value - 1 )
	elseif ( key == "ESCAPE" or key == "ENTER" ) then
		self.bFocused = false
	else
		local ch = KEY_CHARS[ name ] or KEY_CHARS[ key ]
		if ( not ch and #key == 1 ) then ch = string.lower( key ) end
		if ( ch ) then self.Value = self.Value .. ch end
	end
	self:Repaint()
	if ( self.OnValueChange ) then self:OnValueChange( self.Value ) end
end
Register( SEARCH_PANEL, "HL2SBSearch", "Panel" )

------------------------------------------------------------------------------
-- Thumbnail grid.  Each cell is a vgui.ModelImage (model-rendering panel); the
-- grid scrolls and shows the cells that intersect the viewport.
------------------------------------------------------------------------------
local MODEL_GRID = {}
function MODEL_GRID:Init()
	self.AllItems = self.AllItems or {}
	self.Items    = self.Items or {}
	self.Selected = 0
	self.Scroll   = 0
	self.Cells    = {}
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
end

function MODEL_GRID:SetAllItems( items )
	self.AllItems = items or {}
	self:ApplyFilter( self.Filter or "" )
end

function MODEL_GRID:ApplyFilter( str )
	str = string.lower( str or "" )
	self.Filter = str
	local filtered = {}
	for _, m in ipairs( self.AllItems ) do
		if ( str == "" or string.find( string.lower( m.name or "" ), str, 1, true )
					   or string.find( string.lower( m.model or "" ), str, 1, true ) ) then
			filtered[ #filtered + 1 ] = m
		end
	end
	self.Items = filtered
	self.Selected = 0
	self.Scroll = 0
	self:RebuildCells()
	if ( self.OnFilter ) then self:OnFilter( #filtered, #self.AllItems ) end
end

function MODEL_GRID:GetColumns()
	local w = self:GetWide()
	if ( w <= 0 ) then return 4 end
	return max( 1, floor( ( w - THUMB_PAD * 2 ) / ( THUMB_SIZE + THUMB_GAP ) ) )
end

function MODEL_GRID:GetRows()
	local cols = self:GetColumns()
	if ( cols <= 0 ) then return 0 end
	return math.ceil( #self.Items / cols )
end

function MODEL_GRID:GetContentHeight()
	local rows = self:GetRows()
	if ( rows <= 0 ) then return 0 end
	return rows * ( THUMB_SIZE + THUMB_GAP ) + THUMB_PAD
end

function MODEL_GRID:GetMaxScroll()
	return max( 0, self:GetContentHeight() - self:GetTall() )
end

function MODEL_GRID:RebuildCells()
	-- Destroy every cell panel and drop the cell records; the viewport cells are
	-- recreated lazily on the next Paint.
	for _, c in ipairs( self.Cells ) do
		if ( c.panel ) then c.panel:MarkForDeletion() end
	end
	self.Cells = {}
end

function MODEL_GRID:GetCell( index )
	if ( self.Cells[ index ] ) then return self.Cells[ index ] end
	local item = self.Items[ index ]
	if ( not item ) then return nil end
	local cell = { panel = nil, model = item.model, name = item.name, index = index }
	self.Cells[ index ] = cell
	return cell
end

function MODEL_GRID:CellRect( index )
	local cols = self:GetColumns()
	local col = ( index - 1 ) % cols
	local row = floor( ( index - 1 ) / cols )
	local x = THUMB_PAD + col * ( THUMB_SIZE + THUMB_GAP )
	local y = THUMB_PAD + row * ( THUMB_SIZE + THUMB_GAP ) - self.Scroll
	return x, y
end

function MODEL_GRID:Paint()
	local w, h = self:GetWide(), self:GetTall()
	FillRect( 0, 0, w, h, CLR_LIST_BG )

	-- Build / refresh the viewport cell panels, then position them.
	self:EnsureViewportCells()

	for index = 1, #self.Items do
		local x, y = self:CellRect( index )
		if ( y > h ) then break end
		if ( y + THUMB_SIZE >= 0 ) then
			local cell = self.Cells[ index ]
			if ( cell and cell.panel ) then
				cell.panel:SetPos( x, y )
				if ( index == self.Selected ) then
					OutlineRect( x - 1, y - 1, THUMB_SIZE + 2, THUMB_SIZE + 2, CLR_SEL )
				elseif ( index == self.Hovered ) then
					OutlineRect( x - 1, y - 1, THUMB_SIZE + 2, THUMB_SIZE + 2, CLR_TEXT_DIM )
				end
			end
		end
	end

	-- scrollbar
	local nScroll = self:GetMaxScroll()
	if ( nScroll > 0 ) then
		local nT = self:GetTall()
		local nThumbH = max( 20, floor( nT * nT / max( 1, self:GetContentHeight() ) ) )
		local nThumbY = floor( ( nT - nThumbH ) * ( self.Scroll / nScroll ) )
		FillRect( w - 6, nThumbY, 6, nThumbH, CLR_SCROLL )
	end
end

function MODEL_GRID:EnsureViewportCells()
	local h = self:GetTall()
	local cols = self:GetColumns()
	local nItems = #self.Items
	if ( cols <= 0 or h <= 0 ) then
		self:RebuildCells()
		return
	end

	-- Determine the index range that intersects the viewport.
	local firstIndex, lastIndex = 1, 0
	for index = 1, nItems do
		local _, y = self:CellRect( index )
		if ( y + THUMB_SIZE >= 0 and firstIndex == 1 ) then firstIndex = index end
		if ( y < h ) then lastIndex = index end
	end

	-- Remove cells outside the viewport.
	for index, cell in pairs( self.Cells ) do
		if ( index < firstIndex or index > lastIndex ) then
			if ( cell.panel ) then cell.panel:MarkForDeletion() end
			self.Cells[ index ] = nil
		end
	end

	-- Create cells for the visible range that don't have a panel yet.
	local maxCells = self.MaxCells or 9999
	for index = firstIndex, lastIndex do
		if ( index > maxCells ) then break end
		local item = self.Items[ index ]
		if ( item ) then
			local cell = self.Cells[ index ]
			if ( not cell ) then
				cell = { panel = nil, model = item.model, name = item.name, index = index }
				self.Cells[ index ] = cell
			end
			if ( not cell.panel ) then
				local x, y = self:CellRect( index )
				local p = vgui.ModelImage( self, "TG" .. index )
				p:SetPos( x, y )
				p:SetSize( THUMB_SIZE, THUMB_SIZE )
				-- The model panel must not swallow the mouse: the grid's own
				-- OnMousePressed / OnCursorMoved hit-test the cells by screen
				-- position, so thumbnails are click-through.
				p:SetMouseInputEnabled( false )
				p:SetModel( cell.model )
				p:SetYaw( 180 )
				p:SetZoom( 1.0 )
				p:SetFOV( 54 )
				p:RefitCamera()
				cell.panel = p
			end
		end
	end
end

function MODEL_GRID:ScreenToIndex( screenY, screenX )
	local cols = self:GetColumns()
	if ( cols <= 0 ) then return 0 end
	local sx, sy = screenX or CursorPos(), screenY
	local lx, ly = self:ScreenToLocal( sx, sy )
	local row = floor( ( ly + self.Scroll - THUMB_PAD ) / ( THUMB_SIZE + THUMB_GAP ) )
	local col = floor( ( lx - THUMB_PAD ) / ( THUMB_SIZE + THUMB_GAP ) )
	if ( row < 0 or col < 0 ) then return 0 end
	return row * cols + col + 1
end

function MODEL_GRID:Select( index )
	if ( index < 1 or index > #self.Items ) then return end
	self.Selected = index
	self:Repaint()
	if ( self.OnSelect ) then self:OnSelect( self.Items[ index ], index ) end
end

function MODEL_GRID:OnMouseWheeled( delta )
	self.Scroll = clamp( self.Scroll - delta * 40, 0, self:GetMaxScroll() )
	self:Repaint()
end

function MODEL_GRID:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end
	local sx, sy = CursorPos()
	local index = self:ScreenToIndex( sy, sx )
	if ( index >= 1 and index <= #self.Items ) then
		self:Select( index )
	end
end

function MODEL_GRID:OnCursorMoved()
	local sx, sy = CursorPos()
	local index = self:ScreenToIndex( sy, sx )
	if ( index ~= self.Hovered ) then
		self.Hovered = ( index >= 1 and index <= #self.Items ) and index or 0
		self:Repaint()
	end
end

function MODEL_GRID:PerformLayout()
	-- Invalidating the layout on a size change is enough; the viewport cells are
	-- rebuilt lazily by EnsureViewportCells on the next Paint.  Do NOT call
	-- RebuildCells() here - it runs every frame and would thrash the panels.
end

Register( MODEL_GRID, "HL2SBModelGrid", "Panel" )

------------------------------------------------------------------------------
-- Model preview (left).  vgui.ModelPanel forwards interaction callbacks; state
-- lives in an external table keyed by VPANEL because writing fields on a
-- ModelPanel goes through ModelPanel___newindex which can throw.
------------------------------------------------------------------------------
local PREVIEW = {}
local PreviewState = {}
local function GetState( panel )
	local key = panel:GetVPanel()
	local st = PreviewState[ key ]
	if ( not st ) then
		st = { nYaw = 180, nZoom = 1.0, bDragging = false,
			   nLastX = 0, nDragStartX = 0, bMoved = false, nSeq = 0, fovW = 0, fovH = 0 }
		PreviewState[ key ] = st
	end
	return st
end
local function M( st, name, self, ... )
	if ( st[ name ] == nil and self ) then st[ name ] = self[ name ] end
	local fn = st[ name ]
	if ( fn ) then return fn( self, ... ) end
	return nil
end

function PREVIEW:Init()
	local st = GetState( self )
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
	M( st, "SetZoomLimits", self, ZOOM_MIN, ZOOM_MAX )
	M( st, "SetYaw", self, st.nYaw )
	M( st, "SetZoom", self, st.nZoom )
	self._hl2sb_st = st   -- force script table so mouse/paint callbacks fire
end

function PREVIEW:UpdateFOV()
	local w, h = self:GetWide(), self:GetTall()
	if ( w <= 0 or h <= 0 ) then return end
	local st = GetState( self )
	if ( st.fovW == w and st.fovH == h ) then return end
	st.fovW, st.fovH = w, h
	local aspect = w / h
	local fovY = FOV
	if ( aspect < 1.0 ) then
		fovY = 2 * math.deg( math.atan( math.tan( math.rad( FOV ) * 0.5 ) / aspect ) )
	end
	M( st, "SetFOV", self, floor( fovY ) )
	M( st, "RefitCamera", self )
end

function PREVIEW:LoadModel( path )
	local st = GetState( self )
	if ( not M( st, "SetModel", self, path ) ) then return false end
	M( st, "RefitCamera", self )
	st.nYaw = 180
	M( st, "SetYaw", self, st.nYaw )
	return true
end

function PREVIEW:CycleAnimation()
	local st = GetState( self )
	local n = M( st, "GetSequenceCount", self )
	if ( not n or n <= 0 ) then return end
	st.nSeq = ( st.nSeq + 1 ) % n
	M( st, "PlaySequence", self, M( st, "GetSequenceName", self, st.nSeq ) )
end

function PREVIEW:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end
	local st = GetState( self ); local x = CursorPos()
	st.bDragging = true; st.bMoved = false; st.nDragStartX = x; st.nLastX = x
end
function PREVIEW:OnCursorMoved()
	local st = GetState( self )
	if ( not st.bDragging ) then return end
	local x = CursorPos(); local dx = x - st.nLastX; st.nLastX = x
	if ( abs( x - st.nDragStartX ) > 3 ) then st.bMoved = true end
	if ( dx ~= 0 ) then st.nYaw = st.nYaw + dx * ROTATE_SPEED; M( st, "SetYaw", self, st.nYaw ) end
end
function PREVIEW:OnMouseReleased( code )
	local st = GetState( self )
	if ( code ~= MOUSE_LEFT or not st.bDragging ) then return end
	st.bDragging = false
	if ( not st.bMoved ) then self:CycleAnimation() end
end
function PREVIEW:OnMouseWheeled( delta )
	local st = GetState( self )
	st.nZoom = clamp( st.nZoom - delta * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX )
	M( st, "SetZoom", self, st.nZoom )
end
Register( PREVIEW, "HL2SBModelPreview", "ModelPanel" )

------------------------------------------------------------------------------
-- Colour tab.
------------------------------------------------------------------------------
local COLOR_PANEL = {}
local PALETTE = {
	{ 255, 255, 255 }, { 200, 200, 200 }, { 62, 88, 106 }, { 0, 0, 0 },
	{ 255, 0, 0 },     { 255, 128, 0 },   { 255, 255, 0 },   { 0, 255, 0 },
	{ 0, 255, 255 },   { 0, 0, 255 },     { 128, 0, 255 },   { 255, 0, 255 },
	{ 150, 60, 30 },   { 128, 128, 0 },   { 0, 128, 128 },   { 60, 60, 150 },
}
function COLOR_PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
	-- r/g/b 0..255 sliders
	self.r, self.g, self.b = 62, 88, 106
	self.Drag = nil
	self.DragVal = 0
	self:LoadCurrent()
end

local function GetLocalPlayerColor()
	-- LocalPlayer() returns a NULL-ent userdata before spawn; guarding the whole
	-- call avoids "attempt to index a NULL entity" when the menu opens early.
	local pok, pl = pcall( LocalPlayer )
	if ( not pok or not pl ) then return nil end
	local cok, c = pcall( function() return pl:GetPlayerColor() end )
	if ( cok and c ) then return c end
	return nil
end

local function SetLocalPlayerColor( r, g, b )
	local pok, pl = pcall( LocalPlayer )
	if ( not pok or not pl ) then return end
	pcall( function() pl:SetPlayerColor( Color( r, g, b, 255 ) ) end )
end

function COLOR_PANEL:LoadCurrent()
	-- Initialise from the local player's current colour, if any.
	local c = GetLocalPlayerColor()
	if ( c ) then
		self.r = clamp( c.r, 0, 255 )
		self.g = clamp( c.g, 0, 255 )
		self.b = clamp( c.b, 0, 255 )
	end
end

function COLOR_PANEL:Apply()
	SetLocalPlayerColor( self.r, self.g, self.b )
	if ( self.OnChange ) then self:OnChange( self.r, self.g, self.b ) end
end

function COLOR_PANEL:SetColor( r, g, b )
	self.r = clamp( r, 0, 255 )
	self.g = clamp( g, 0, 255 )
	self.b = clamp( b, 0, 255 )
	self:Repaint()
end

function COLOR_PANEL:ChannelRect( index )
	local w, h = self:GetWide(), self:GetTall()
	-- 3 colour channels stacked, then a preview swatch + palette grid.
	local y0 = 8
	local cH = 22
	local y = y0 + ( index - 1 ) * ( cH + 8 )
	return 8, y, w - 16, cH
end

function COLOR_PANEL:SwatchRect()
	local w, h = self:GetWide(), self:GetTall()
	return 8, 100, w - 16, 40
end

function COLOR_PANEL:PaletteRect()
	local w, h = self:GetWide(), self:GetTall()
	return 8, 148, w - 16, h - 156
end

function COLOR_PANEL:Paint()
	local w, h = self:GetWide(), self:GetTall()
	FillRect( 0, 0, w, h, CLR_LIST_BG )

	local labels = { "Red", "Green", "Blue" }
	local vals   = { self.r, self.g, self.b }
	for i = 1, 3 do
		local x, y, cw, ch = self:ChannelRect( i )
		FillRect( x, y, cw, ch, CLR_INPUT_BG )
		local col = { ( i == 1 ) and 180 or 40, ( i == 2 ) and 180 or 40, ( i == 3 ) and 180 or 40, 255 }
		-- channel fill
		local val = vals[ i ] / 255
		FillRect( x + 70, y, ( cw - 70 ) * val, ch, col, 160 )
		DrawTextAt( labels[ i ], x + 6, y + floor( ( ch - TEXT_TALL ) * 0.5 ), CLR_TEXT )
		DrawTextAt( tostring( vals[ i ] ), x + cw - 40, y + floor( ( ch - TEXT_TALL ) * 0.5 ), CLR_TEXT_DIM )
	end

	-- preview swatch
	local sx, sy, sw, sh = self:SwatchRect()
	FillRect( sx, sy, sw, sh, { self.r, self.g, self.b, 255 } )
	OutlineRect( sx, sy, sw, sh, CLR_TEXT_DIM )
	DrawTextAt( "Shirt / body colour", sx + 6, sy + floor( ( sh - TEXT_TALL ) * 0.5 ), { 0, 0, 0, 200 } )

	-- palette
	local px, py, pw, ph = self:PaletteRect()
	local cols = max( 1, floor( pw / 24 ) )
	for idx, col in ipairs( PALETTE ) do
		local cx = px + ( ( idx - 1 ) % cols ) * 24
		local cy = py + floor( ( idx - 1 ) / cols ) * 24
		if ( cy + 20 <= py + ph ) then
			FillRect( cx, cy, 20, 20, col )
			OutlineRect( cx, cy, 20, 20, CLR_TEXT_DIM )
		end
	end
end

function COLOR_PANEL:PaletteIndexAt( x, y )
	local px, py, pw, ph = self:PaletteRect()
	local cols = max( 1, floor( pw / 24 ) )
	local cx = x - px; local cy = y - py
	if ( cx < 0 or cy < 0 ) then return 0 end
	local col = floor( cx / 24 ) + 1
	local row = floor( cy / 24 ) + 1
	local idx = ( row - 1 ) * cols + col
	if ( idx < 1 or idx > #PALETTE ) then return 0 end
	return idx
end

function COLOR_PANEL:ChannelIndexAt( x, y )
	for i = 1, 3 do
		local rx, ry, rw, rh = self:ChannelRect( i )
		if ( x >= rx and x <= rx + rw and y >= ry and y <= ry + rh ) then
			return i
		end
	end
	return nil
end

function COLOR_PANEL:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end
	local x, y = CursorPos()
	local lx, ly = self:ScreenToLocal( x, y )
	-- palette?
	local pi = self:PaletteIndexAt( lx, ly )
	if ( pi > 0 ) then
		local c = PALETTE[ pi ]
		self:SetColor( c[1], c[2], c[3] )
		self:Apply()
		return
	end
	-- channel drag?
	local i = self:ChannelIndexAt( lx, ly )
	if ( i ) then
		self.Drag = i
		local rx, ry, rw, rh = self:ChannelRect( i )
		self.DragMinX = rx + 70
		self.DragW = rw - 70
		self:DragChannel( lx )
	end
end

function COLOR_PANEL:DragChannel( lx )
	local i = self.Drag
	if ( not i ) then return end
	local val = clamp( ( lx - self.DragMinX ) / max( 1, self.DragW ), 0, 1 )
	if ( i == 1 ) then self.r = floor( val * 255 )
	elseif ( i == 2 ) then self.g = floor( val * 255 )
	else self.b = floor( val * 255 ) end
	self:Repaint()
	self:Apply()
end

function COLOR_PANEL:OnCursorMoved()
	if ( self.Drag ) then
		local x, y = CursorPos()
		local lx = self:ScreenToLocal( x, y )
		self:DragChannel( lx )
	end
end

function COLOR_PANEL:OnMouseReleased( code )
	if ( code == MOUSE_LEFT ) then self.Drag = nil end
end

Register( COLOR_PANEL, "HL2SBColorPanel", "Panel" )

------------------------------------------------------------------------------
-- Tab container (模型 / 颜色).  Owns its content panels (Search + ModelGrid for
-- the model tab, ColorPanel for the colour tab) and lays them out below the
-- tab header.
------------------------------------------------------------------------------
local TABS = {}
function TABS:Init()
	self.Tabs = { { name = "Model", label = "模型" }, { name = "Color", label = "颜色" } }
	self.Active = 1
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
end
function TABS:GetTabH() return 26 end
function TABS:SetActive( i )
	self.Active = i
	if ( self.Grid ) then self.Grid:SetVisible( i == 1 ) end
	if ( self.Search ) then self.Search:SetVisible( i == 1 ) end
	if ( self.Color ) then self.Color:SetVisible( i == 2 ) end
	self:InvalidateLayout()
	self:Repaint()
end
function TABS:PerformLayout()
	local th = self:GetTabH()
	local cw = self:GetWide()
	local ch = self:GetTall() - th - GAP
	local cy = th + GAP -- content top (below header)

	if ( self.Search ) then
		self.Search:SetPos( 0, cy )
		self.Search:SetSize( cw, 22 )
	end
	if ( self.Grid ) then
		self.Grid:SetPos( 0, cy + 22 + GAP )
		self.Grid:SetSize( cw, ch - 22 - GAP )
	end
	if ( self.Color ) then
		self.Color:SetPos( 0, cy )
		self.Color:SetSize( cw, ch )
	end
end
function TABS:Paint()
	local w = self:GetWide()
	local th = self:GetTabH()
	local tw = 90
	for i, t in ipairs( self.Tabs ) do
		local x = ( i - 1 ) * ( tw + 4 )
		local act = ( i == self.Active )
		FillRect( x, 0, tw, th, act and CLR_TAB_ACT or CLR_TAB )
		DrawTextAt( t.label, x + 8, floor( ( th - TEXT_TALL ) * 0.5 ), act and CLR_TEXT_SEL or CLR_TEXT_DIM )
	end
end
function TABS:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end
	local x, y = CursorPos()
	local lx, ly = self:ScreenToLocal( x, y )
	local tw = 90
	for i = 1, #self.Tabs do
		local lx0 = ( i - 1 ) * ( tw + 4 )
		if ( lx >= lx0 and lx <= lx0 + tw and ly >= 0 and ly < self:GetTabH() ) then
			self:SetActive( i )
			return
		end
	end
end
Register( TABS, "HL2SBTabs", "Panel" )

------------------------------------------------------------------------------
-- The menu (Frame).
------------------------------------------------------------------------------
local MENU = {}
function MENU:Init()
	self.bClosing = false
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( true )
end

function MENU:Build()
	local sw, sh = surface.GetScreenSize()
	local w = floor( max( MIN_W, sw * WINDOW_W_FRAC ) )
	local h = floor( max( MIN_H, sh * WINDOW_H_FRAC ) )
	self:SetSize( w, h )
	self:SetPos( floor( ( sw - w ) * 0.5 ), floor( ( sh - h ) * 0.5 ) )
	self:SetTitle( "选择玩家模型", true )
	self:SetCloseButtonVisible( false )
	self:SetMinimizeButtonVisible( false )
	self:SetMaximizeButtonVisible( false )
	self:SetSizeable( false )
	self:MakePopup()
	self:SetVisible( true )

	-- left preview
	self.Preview = vgui.HL2SBModelPreview( self, "Preview" )

	-- right tab container (owns search + model grid + colour panel)
	self.Tabs = vgui.HL2SBTabs( self, "Tabs" )

	-- model grid tab
	self.Grid = vgui.HL2SBModelGrid( self.Tabs, "ModelGrid" )
	self.Grid.OnSelect = function( _, item ) self:PreviewModel( item ) end
	self.Grid.OnFilter = function( n, total )
		self:SetStatus( string.format( "%d / %d 模型", tonumber( n ) or 0, tonumber( total ) or 0 ) )
	end
	self.Tabs.Grid = self.Grid

	-- colour tab
	self.Color = vgui.HL2SBColorPanel( self.Tabs, "ColorPanel" )
	self.Color.OnChange = function( r, g, b ) end
	self.Tabs.Color = self.Color

	-- search box (model tab)
	self.Search = vgui.HL2SBSearch( self.Tabs, "Search" )
	self.Search.Placeholder = "搜索模型..."
	self.Search.OnValueChange = function( _, str ) self.Grid:ApplyFilter( str ) end
	self.Tabs.Search = self.Search

	-- start on the model tab
	self.Tabs:SetActive( 1 )

	self.Confirm = vgui.HL2SBBtn( self, "Confirm" )
	self.Confirm.Label = "确认"
	self.Confirm.OnClick = function() self:ConfirmSelection() end

	self.Cancel = vgui.HL2SBBtn( self, "Cancel" )
	self.Cancel.Label = "取消"
	self.Cancel.OnClick = function() self:Close() end

	self.Status = ""
	self:LoadModelList()
	self:PerformLayout()
	self:RequestFocus()   -- make the popup frame the vgui keyboard focus; its
	                      -- OnKeyCodeTyped forwards typing to the focused search box
end

function MENU:PerformLayout()
	local w, h = self:GetWide(), self:GetTall()
	local nPreviewW = floor( w * PREVIEW_FRAC )
	local nRightX = nPreviewW + GAP
	local nRightW = w - nPreviewW - GAP * 2
	local nTop = CAPTION_H + 6
	local nBottom = BOTTOM_H
	local nBodyH = h - CAPTION_H - nBottom

	if ( self.Preview ) then
		self.Preview:SetPos( 0, CAPTION_H )
		self.Preview:SetSize( nPreviewW, nBodyH )
		self.Preview:UpdateFOV()
	end

	if ( self.Tabs ) then
		self.Tabs:SetPos( nRightX, nTop )
		self.Tabs:SetSize( nRightW, nBodyH )
		self.Tabs:InvalidateLayout()
	end

	if ( self.Confirm ) then
		self.Confirm:SetPos( nRightX, h - nBottom + 5 )
		self.Confirm:SetSize( 120, 24 )
	end
	if ( self.Cancel ) then
		self.Cancel:SetPos( nRightX + 128, h - nBottom + 5 )
		self.Cancel:SetSize( 120, 24 )
	end
end

function MENU:LoadModelList()
	local ok, models = pcall( hl2sb.GetPlayerModels )
	if ( ok and type( models ) == "table" ) then
		-- Filter out the "hutao" model: its studio render (Genshin-impact
		-- custom model) overflows the stack in the HL2SB/old-Source studiorender
		-- and crashes the client (0xc0000409).  hutao_old is a separate, safe
		-- entry and is kept.
		local filtered = {}
		for _, m in ipairs( models ) do
			local name = tostring( m.name or "" )
			if ( name ~= "hutao"
				and tostring( m.model or "" ) ~= "models/player/genshin_impact/hutao_sheepylord_pm.mdl" ) then
				filtered[ #filtered + 1 ] = m
			end
		end
		self.AllModels = filtered
	else
		self.AllModels = {}
	end
	self.Grid:SetAllItems( self.AllModels )
	self:SetStatus( string.format( "%d 模型", #self.AllModels ) )
end

function MENU:PreviewModel( item )
	if ( not item or not self.Preview ) then return end
	if ( not hl2sb.IsModelPrecached( item.model ) ) then
		self:SetStatus( string.format( "%s 不可用", item.name ) )
		return
	end
	if ( self.szPreviewPath ~= item.model ) then
		self.szPreviewPath = item.model
		self.Preview:LoadModel( item.model )
	end
	self:SetStatus( item.name )
end

function MENU:ConfirmSelection()
	local item = self.Grid and self.Grid.Items[ self.Grid.Selected ]
	if ( item ) then
		hl2sb.SetPlayerModel( item.name )
	end
	self:Close()
end

function MENU:SetStatus( str )
	self.Status = str or ""
	self:Repaint()
end

function MENU:Close()
	self.bClosing = true
	self:SetVisible( false )
	self:MarkForDeletion()
	g_HL2SBPlayerModelMenu = nil
end

function MENU:Paint()
	local w, h = self:GetWide(), self:GetTall()
	FillRect( 0, 0, w, h, CLR_BG )
	if ( self.Status and self.Status ~= "" ) then
		DrawTextAt( self.Status, floor( w * PREVIEW_FRAC ) + GAP, h - 30, CLR_TEXT_DIM )
	end
end

-- LFrame forwards OnKeyCodeTyped, so capture typing on the menu frame and hand
-- it to the search box when it is focused.  The search box no longer calls
-- RequestFocus() (that access-violates in vgui Panel::OnRequestFocus for this
-- hierarchy), so it doesn't receive input directly.
function MENU:OnKeyCodeTyped( code )
	if ( self.Search and self.Search.bFocused ) then
		self.Search:OnKeyCodeTyped( code )
	end
end

Register( MENU, "HL2SBPlayerModelMenu", "Frame" )

------------------------------------------------------------------------------
-- Entry point
------------------------------------------------------------------------------
function hl2sb.OpenPlayerModelMenu()
	if ( g_HL2SBPlayerModelMenu ) then
		g_HL2SBPlayerModelMenu:MarkForDeletion()
		g_HL2SBPlayerModelMenu = nil
	end
	local menu = vgui.HL2SBPlayerModelMenu( nil, "HL2SBPlayerModelMenu" )
	g_HL2SBPlayerModelMenu = menu
	menu:Build()
	return menu
end

concommand.Create( "hl2sb_playermodel", function()
	hl2sb.OpenPlayerModelMenu()
end, "Open the GMod-style player model menu" )

concommand.Create( "hl2sb_playermodel_dbg", function()
	local menu = g_HL2SBPlayerModelMenu
	if ( not menu ) then
		print( "[HL2SB] playermodel menu: not open\n" )
		return
	end
	print( string.format( "[HL2SB][dbg] menu visible=%s size=%dx%d\n",
		tostring( menu:IsVisible() ), menu:GetWide(), menu:GetTall() ) )
end, "Dump the player model menu panel tree" )

print( "[HL2SB] hl2sb_playermodel.lua loaded - run 'hl2sb_playermodel'\n" )
