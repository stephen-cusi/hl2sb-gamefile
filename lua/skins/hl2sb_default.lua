--[[----------------------------------------------------------------------------
	skins/hl2sb_default.lua  --  HL2SB's built-in Derma skin.

	derma.DefineSkin-shaped (method names PaintX / ThinkX), all-original vector
	implementation through surface.* only.  No GWEN textures, no materials --
	nothing here can render as the purple error checker, and nothing needs the
	png fallback path.

	Colours follow the engine's own dark UI palette so a Derma window sits
	comfortably next to the stock main menu.
-----------------------------------------------------------------------------]]

if ( not ( ( CLIENT or _GAMEUI ) and surface ) ) then return end

local SKIN = {}

SKIN.Colours = {
	Background		= Color( 48,  52,  58,  255 ),
	BackgroundDark	= Color( 34,  37,  41,  255 ),
	Panel			= Color( 60,  64,  71,  235 ),
	PanelBorder		= Color( 25,  27,  30,  255 ),
	Text			= Color( 228, 228, 228, 255 ),
	TextDisabled	= Color( 120, 120, 120, 255 ),

	Button			= Color( 78,  84,  93,  255 ),
	ButtonHover		= Color( 98,  106, 118, 255 ),
	ButtonDown		= Color( 52,  108, 190, 255 ),
	ButtonSelected	= Color( 52,  108, 190, 255 ),

	FrameTitle		= Color( 37,  101, 166, 255 ),
	FrameTitleIdle	= Color( 58,  62,  69,  255 ),

	Entry			= Color( 28,  30,  34,  255 ),
	EntryBorder		= Color( 90,  95,  103, 255 ),

	Scroll			= Color( 70,  75,  83,  255 ),
	ScrollGrip		= Color( 108, 115, 126, 255 ),
	ScrollGripHover	= Color( 130, 138, 150, 255 ),

	Menu			= Color( 43,  46,  52,  255 ),
	MenuBorder		= Color( 20,  21,  24,  255 ),
	MenuHover		= Color( 52,  108, 190, 255 ),

	CheckOn			= Color( 52,  108, 190, 255 ),
	CheckOff		= Color( 28,  30,  34,  255 ),

	Slider			= Color( 28,  30,  34,  255 ),
	SliderGrip		= Color( 108, 115, 126, 255 ),

	Warning			= Color( 200, 80,  30,  255 ),
	Error			= Color( 200, 40,  40,  255 ),
}

local function col( self, key )
	return self.Colours[ key ] or SKIN.Colours[ key ] or Color( 255, 255, 255, 255 )
end

local function fontOf( pnl )
	if ( pnl and pnl.m_strDermaFont ) then return pnl.m_strDermaFont end
	return "DermaDefault"
end

-- Shared text helper: vertical centring inside the panel height.
-- clr is optional: a panel that set its own text colour (DCheckBoxLabel's
-- SetTextColor/SetDark) wins over the skin's.
local function drawText( self, pnl, strText, x, y, clr )
	local font = fontOf( pnl )
	local w, h = derma.GetTextSize( font, strText )

	if ( y == nil ) then
		y = math.floor( ( ( pnl:GetTall() ) - h ) / 2 )
	end

	derma.DrawText( font, x, y, strText, clr or col( self, "Text" ) )
	return w, h
end

--[[ Panel ------------------------------------------------------------------]]

function SKIN:PaintPanel( pnl, w, h )
	surface.DrawSetColor( col( self, "Panel" ).r, col( self, "Panel" ).g, col( self, "Panel" ).b, col( self, "Panel" ).a )
	surface.DrawFilledRect( 0, 0, w, h )
end

function SKIN:PaintBackground( pnl, w, h )
	-- DPanel:Background / DFrame body
	surface.DrawSetColor( col( self, "Background" ).r, col( self, "Background" ).g, col( self, "Background" ).b, 255 )
	surface.DrawFilledRect( 0, 0, w, h )
end

function SKIN:PaintBorder( pnl, w, h )
	local c = col( self, "PanelBorder" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawOutlinedRect( 0, 0, w, h )
end

-- Generic fallback every control's Paint ends with when it has no skin hook.
function SKIN:Paint( pnl, w, h )
end

--[[ Button / Label ----------------------------------------------------------]]

function SKIN:PaintButton( pnl, w, h )
	local bg
	if ( pnl.m_bDepressed ) then		bg = col( self, "ButtonDown" )
	elseif ( pnl.m_bHover ) then		bg = col( self, "ButtonHover" )
	else								bg = col( self, "Button" ) end

	surface.DrawSetColor( bg.r, bg.g, bg.b, bg.a )
	surface.DrawFilledRect( 0, 0, w, h )

	local c = col( self, "PanelBorder" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawOutlinedRect( 0, 0, w, h )
end

function SKIN:PaintLabel( pnl, w, h )
	-- labels are transparent by default; the text is painted by the control
end

function SKIN:PaintImageButton( pnl, w, h )
	self:PaintButton( pnl, w, h )
end

--[[ TextEntry ---------------------------------------------------------------]]

function SKIN:PaintTextEntry( pnl, w, h )
	local bg = col( self, "Entry" )
	surface.DrawSetColor( bg.r, bg.g, bg.b, bg.a )
	surface.DrawFilledRect( 0, 0, w, h )

	local bd = col( self, "EntryBorder" )
	surface.DrawSetColor( bd.r, bd.g, bd.b, bd.a )
	surface.DrawOutlinedRect( 0, 0, w, h )
end

function SKIN:PaintText( pnl, w, h )
	local text = ""
	if ( pnl.GetText ) then text = pnl:GetText() or "" end
	if ( text == "" and pnl.GetPlaceholderText ) then
		text = pnl:GetPlaceholderText() or ""
	end
	drawText( self, pnl, text, 6, nil )
end

--[[ CheckBox ----------------------------------------------------------------]]

-- GMod's DCheckBox is a plain panel and the skin draws all of it: the box, the
-- tick and the caption.  Geometry comes from the control (m_iBoxX / m_iBoxSize /
-- m_iTextGap, see lua/vgui/dcheckbox.lua) so the skin and SizeToContents cannot
-- disagree.
--
-- ⚠️ surface.DrawFilledRect / DrawOutlinedRect take TWO CORNERS (x0,y0,x1,y1) in
-- this engine -- the size-shaped DrawRect is the GMod-name shim in
-- gmod_surface.lua.  This function used to call DrawFilledRect( x, y, size, size ),
-- which draws from (x,y) to (size,size): a wrong rectangle.  Nobody noticed
-- because nothing called PaintCheck until DCheckBox became a DPanel.
function SKIN:PaintCheck( pnl, w, h )
	local checked = pnl.IsChecked and pnl:IsChecked()

	local size = pnl.m_iBoxSize or 16
	local x = pnl.m_iBoxX or 2
	local y = math.floor( ( h - size ) / 2 )

	local c = checked and col( self, "CheckOn" ) or col( self, "CheckOff" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( x, y, x + size, y + size )

	local bd = col( self, "EntryBorder" )
	surface.DrawSetColor( bd.r, bd.g, bd.b, bd.a )
	surface.DrawOutlinedRect( x, y, x + size, y + size )

	if ( checked ) then
		-- a 2px tick (two passes): a single 1px line reads as a scratch next to
		-- the tick GMod's own skin draws
		surface.DrawSetColor( 255, 255, 255, 255 )
		for i = 0, 1 do
			surface.DrawLine( x + 4 + i, y + math.floor( size / 2 ), x + math.floor( size / 2 ) + i, y + size - 4 )
			surface.DrawLine( x + math.floor( size / 2 ) + i, y + size - 4, x + size - 4 + i, y + 4 )
		end
	end

	local textX = ( pnl.GetCaptionX and pnl:GetCaptionX() ) or ( size + 8 )
	drawText( self, pnl, pnl:GetText() or "", textX, nil, pnl.m_colText )
end

--[[ ScrollBar ----------------------------------------------------------------]]

function SKIN:PaintScrollBar( pnl, w, h )
	local c = col( self, "Scroll" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( 0, 0, w, h )
end

function SKIN:PaintScrollGrip( pnl, w, h )
	local c = pnl.m_bHover and col( self, "ScrollGripHover" ) or col( self, "ScrollGrip" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( 2, 2, w - 4, h - 4 )
end

--[[ Menu ---------------------------------------------------------------------]]

function SKIN:PaintMenu( pnl, w, h )
	local c = col( self, "Menu" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( 0, 0, w, h )

	local bd = col( self, "MenuBorder" )
	surface.DrawSetColor( bd.r, bd.g, bd.b, bd.a )
	surface.DrawOutlinedRect( 0, 0, w, h )
end

function SKIN:PaintMenuOption( pnl, w, h )
	if ( pnl.m_bHover ) then
		local c = col( self, "MenuHover" )
		surface.DrawSetColor( c.r, c.g, c.b, c.a )
		surface.DrawFilledRect( 0, 0, w, h )
	end
	drawText( self, pnl, pnl:GetText() or "", 8, nil )
end

function SKIN:PaintTooltip( pnl, w, h )
	local c = col( self, "Background" )
	surface.DrawSetColor( c.r, c.g, c.b, 245 )
	surface.DrawFilledRect( 0, 0, w, h )
	local bd = col( self, "PanelBorder" )
	surface.DrawSetColor( bd.r, bd.g, bd.b, bd.a )
	surface.DrawOutlinedRect( 0, 0, w, h )
end

--[[ Frame --------------------------------------------------------------------]]

-- GMod's default skin paints the window caption buttons with the Marlett glyph font
-- (r = close, 0 = minimize, 1 = maximize, 2 = restore) - that is where GMod's
-- "fullscreen square" icon comes from.  Same here, so the chrome matches.
-- GMod's caption glyphs come from the Marlett font (r = close, 0 = minimize,
-- 1 = maximize, 2 = restore).
--
-- NOTE: do NOT surface.CreateFont( "Marlett", ... ) here.  resource/clientscheme.res
-- already defines it (lines ~706/710: "Marlett" / "name" "Marlett") and the font file
-- ships as resource/marlett.ttf, so the engine has a working HFont for that name.
-- Creating our own shadows the scheme entry (the Lua font registry is consulted first),
-- the face then fails to resolve, and CreateFont silently falls back to Verdana - which
-- is why the buttons rendered as the literal letters "0 1 r".

local function CaptionGlyph( pnl, w, h, glyph, hoverCol, textCol )

	if ( pnl.m_bHover or pnl.Hovered ) then
		local c = hoverCol or Color( 90, 90, 90, 255 )
		surface.DrawSetColor( c.r, c.g, c.b, c.a )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	local col = textCol or Color( 230, 230, 230, 255 )
	local font = "Marlett"
	local tw, th = 0, 0

	if ( derma.GetTextSize ) then
		tw, th = derma.GetTextSize( font, glyph )
	end

	if ( derma.DrawText ) then
		derma.DrawText( font, math.floor( ( w - tw ) / 2 ), math.floor( ( h - th ) / 2 ), glyph, col )
	else
		surface.DrawSetTextFont( font )
		surface.DrawSetTextColor( col.r, col.g, col.b, col.a )
		surface.DrawSetTextPos( math.floor( ( w - tw ) / 2 ), math.floor( ( h - th ) / 2 ) )
		surface.DrawPrintText( glyph )
	end
end

function SKIN:PaintFrame( pnl, w, h )
	local c = col( self, "Background" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( 0, 0, w, h )
end

function SKIN:PaintFrameTitle( pnl, w, h )
	local active = pnl.IsActive and pnl:IsActive()
	local c = active and col( self, "FrameTitle" ) or col( self, "FrameTitleIdle" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( 0, 0, w, h )
end

function SKIN:PaintFrameTitleText( pnl, w, h )
	local font = "DermaDefaultBold"
	local _, th = derma.GetTextSize( font, "Xg" )
	derma.DrawText( font, 8, math.floor( ( h - th ) / 2 ), pnl:GetTitle() or "", col( self, "Text" ) )
end

function SKIN:PaintCloseButton( pnl, w, h )
	CaptionGlyph( pnl, w, h, "r", Color( 200, 60, 60, 255 ), col( self, "Text" ) )
end

-- GMod's DFrame caption buttons, drawn with the Marlett glyphs GMod uses
-- (0 = minimize, 1 = maximize, 2 = restore).
function SKIN:PaintMinimizeButton( pnl, w, h )
	CaptionGlyph( pnl, w, h, "0", nil, col( self, "Text" ) )
end

function SKIN:PaintMaximizeButton( pnl, w, h )
	local pParent = pnl:GetParent()
	local bMax = pParent and pParent.IsMaximized and pParent:IsMaximized()
	CaptionGlyph( pnl, w, h, bMax and "2" or "1", nil, col( self, "Text" ) )
end

--[[ Slider -------------------------------------------------------------------]]

function SKIN:PaintSlider( pnl, w, h )
	local c = col( self, "Slider" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( 0, math.floor( h / 2 ) - 2, w, 4 )

	local gc = col( self, "SliderGrip" )
	surface.DrawSetColor( gc.r, gc.g, gc.b, gc.a )
	local gw = 12
	local t = pnl.GetValue and pnl:GetValue() or 0
	local gx = math.floor( ( w - gw ) * math.Clamp( t, 0, 1 ) )
	surface.DrawFilledRect( gx, 0, gw, h )
end

function SKIN:PaintNumberSlider( pnl, w, h )
	self:PaintSlider( pnl, w, h )
end

--[[ ComboBox ------------------------------------------------------------------]]

function SKIN:PaintComboBox( pnl, w, h )
	self:PaintTextEntry( pnl, w, h )

	-- dropdown arrow
	local c = col( self, "Text" )
	surface.DrawSetColor( c.r, c.g, c.b, 220 )
	local ax = w - 14
	local ay = math.floor( h / 2 )
	surface.DrawLine( ax, ay - 2, ax + 8, ay - 2 )
	surface.DrawLine( ax + 8, ay - 2, ax + 4, ay + 3 )
	surface.DrawLine( ax + 4, ay + 3, ax, ay - 2 )
end

--[[ ListView -------------------------------------------------------------------]]

function SKIN:PaintListView( pnl, w, h )
	local c = col( self, "Entry" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( 0, 0, w, h )

	local bd = col( self, "EntryBorder" )
	surface.DrawSetColor( bd.r, bd.g, bd.b, bd.a )
	surface.DrawOutlinedRect( 0, 0, w, h )
end

function SKIN:PaintListViewLine( pnl, w, h )
	if ( pnl.m_bSelected ) then
		local c = col( self, "ButtonDown" )
		surface.DrawSetColor( c.r, c.g, c.b, c.a )
		surface.DrawFilledRect( 0, 0, w, h )
	elseif ( pnl.m_bHover ) then
		local c = col( self, "ButtonHover" )
		surface.DrawSetColor( c.r, c.g, c.b, 120 )
		surface.DrawFilledRect( 0, 0, w, h )
	end
end

function SKIN:PaintListViewColumn( pnl, w, h )
	self:PaintButton( pnl, w, h )
end

--[[ CollapsibleCategory --------------------------------------------------------]]

function SKIN:PaintCategoryHead( pnl, w, h )
	local c = pnl.m_bDepressed and col( self, "ButtonDown" ) or col( self, "Button" )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( 0, 0, w, h )
end

--[[ Notification ----------------------------------------------------------------]]

-- GMod's notice: a FLAT translucent near-black box -- GMod sets it with
-- SetBackgroundColor( Color( 20, 20, 20, 255 * 0.6 ) ) on the panel itself, and
-- puts the type's meaning in the icon (vgui/notices/*) rather than in a colour
-- bar.  An earlier version of this function filled the panel with the skin's
-- "Panel" colour plus an outlined border, and the panel added a hard left
-- colour stripe: a gray slab with a blue line, which is not the GMod look.
--
-- ⚠️ Do NOT read pnl:GetBackgroundColor() here.  Measured 2026-09-15: it comes
-- back FULLY TRANSPARENT (the panel's SetBgColor does not survive), and because
-- the notice icon is a textured draw it inherits the current draw colour -- so
-- the transparent body also made the icon vanish.  Only the caption survived,
-- because derma.DrawText sets its own colour.  The panel passes its body colour
-- through m_colBody instead (and still calls SetBgColor for GMod parity).
function SKIN:PaintNotify( pnl, w, h )
	local c = pnl.m_colBody or Color( 20, 20, 20, 153 )

	surface.DrawSetColor( c.r, c.g, c.b, c.a or 153 )
	surface.DrawFilledRect( 0, 0, w, h )
end

derma.DefineSkin( "HL2SBDefault", "HL2SB's built-in vector Derma skin", SKIN )
