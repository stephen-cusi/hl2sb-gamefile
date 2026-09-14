--[[---------------------------------------------------------------------------
    HL2SB draw library (GMod-compatible, HL2SB port).

    Mirrors GMod's lua/includes/modules/draw.lua so that scripts written for
    GMod's draw.SimpleText / draw.RoundedBox / draw.GetFontHeight keep working
    on HL2SB.  It is a thin adapter over HL2SB's surface binding, which differs
    from GMod's in a few important ways:

      * surface.SetFont(name)  : HL2SB-specific (added in LISurface.cpp).  Takes
        a font NAME string (GMod style), resolves it to an HFont through the
        scheme (falling back to "Default") and returns the HFont.
      * surface.GetTextSize(hfont, text) : HL2SB requires the HFont as arg #1.
      * surface.DrawPrintText(text)      : HL2SB's text draw (GMod uses
        surface.DrawText); it renders the CURRENT font (set by SetFont).
      * surface.DrawFilledRect / DrawTexturedSubRect : HL2SB names for GMod's
        DrawRect / DrawTexturedRectUV.

    Because we resolve fonts by name lazily, call draw.SetFont("Default") (or
    draw.SimpleText with a font) and the face is created once caching the HFont.

    Path: lua/includes/modules/draw.lua  (engine loads includes/modules).
---------------------------------------------------------------------------]]

if ( not _CLIENT ) then return end

-- Capture globals BEFORE module() switches this chunk's environment (the
-- stock Lua 5.1 module() does not seeall by itself).  We ALSO pass
-- package.seeall below so any global we forget (type, string, ipairs, ...)
-- still resolves through the module table's metatable instead of nil-ing.
local surface  = surface
local math     = math
local Color    = Color
local tostring = tostring
local string   = string
local type     = type
local print    = print
local color_white = Color( 255, 255, 255, 255 )

module( "draw", package.seeall )

-------------------------------------------------------------------------------
-- Text alignment constants (same values as GMod).
-------------------------------------------------------------------------------
TEXT_ALIGN_LEFT   = 0
TEXT_ALIGN_CENTER = 1
TEXT_ALIGN_RIGHT  = 2
TEXT_ALIGN_TOP    = 3
TEXT_ALIGN_BOTTOM = 4

-------------------------------------------------------------------------------
-- Extract r,g,b,a from a colour.
--
-- HL2SB's Color is a userdata whose indices (.r/.g/.b/.a) expose METAMETHODS
-- (functions), not fields - so col.r is a function, and calling
-- surface.DrawSetColor(col.r, ...) fails.  We must call col:r() / col:g() /
-- col:b() / col:a() for a real Color.
--
-- IMPORTANT: HL2SB's type() has been extended so that
-- type(Color(1,2,3,4)) returns "color", NOT "userdata" (a value's __type
-- field is returned).  So we must match both "userdata" AND "color" here, or
-- a real Color falls through to the white fallback below.  This is the bug
-- that made every box paint white.
-------------------------------------------------------------------------------
local function GetColorChannels( c, fallbackAlpha )
  local r, g, b, a
  local ct = type( c )

  -- HL2SB Color (its __type is "color"); also handle a plain userdata just in case.
  if ( ct == "userdata" or ct == "color" ) then
    r = c.r; g = c.g; b = c.b; a = c.a
  elseif ( ct == "table" and type(c.r) == "number" ) then
    r = c.r; g = c.g; b = c.b; a = c.a
  elseif ( ct == "table" ) then
    r = c[1]; g = c[2]; b = c[3]; a = c[4]
  elseif ( ct == "number" ) then
    r = c; g = c; b = c; a = fallbackAlpha
  else
    return 255, 255, 255, 255
  end

  a = a or fallbackAlpha or 255
  return r or 255, g or 255, b or 255, a
end

-------------------------------------------------------------------------------
-- Font cache: font name -> HFont handle.
--
-- IMPORTANT: HL2SB's surface only RENDERS fonts that were created through
-- surface.CreateFont() + surface.SetFontGlyphSet().  surface.SetFont(name)
-- (a scheme lookup) gives an HFont that can MEASURE (GetTextSize) but is not
-- wired into the renderable glyph set, so DrawPrintText draws nothing.  The
-- kill feed (which renders correctly) creates its fonts this way.  So we build
-- every draw.* font from CreateFont + SetFontGlyphSet too, caching by name.
-------------------------------------------------------------------------------
local FONTFLAG_ANTIALIAS = 0x010

local CachedFonts     = {}
local CachedFontHeights = {}

-- Return an HFont for a font face name, creating it lazily and caching it.
-- size: pixel height (default 16); weight: 0-1000 (default 700).
local function GetFont( name, size, weight )
  name = name or "Default"
  size = size or 16
  weight = weight or 700

  local cacheKey = name .. "|" .. size .. "|" .. weight
  if ( CachedFonts[ cacheKey ] ) then
    return CachedFonts[ cacheKey ]
  end

  local hfont = surface.CreateFont()
  if ( not hfont ) then
    return false
  end

  -- SetFontGlyphSet(hfont, fontFamily, tall, weight, blur, scanlines, flags, ...)
  local ok = surface.SetFontGlyphSet( hfont, name, size, weight, 0, 0, FONTFLAG_ANTIALIAS )
  CachedFonts[ cacheKey ] = hfont
  return hfont
end

-- HL2SB: expose the cached-font helper.  GMod-style HUD code measures text with
-- surface.GetTextSize, which needs an HFont rather than a face name, so it has
-- to be able to resolve one (GMod's cl_hudpickup.lua does exactly this).
--
-- Must be spelled draw.GetFont = GetFont: a bare `GetFont = GetFont` resolves
-- the name on BOTH sides to the local above and is a no-op, leaving
-- draw.GetFont nil -- which made hl2sb_undo_notify.lua fail every frame.
draw.GetFont = GetFont

-- Height of a single line of the given font name (cached).
function GetFontHeight( font )
  if ( not font ) then font = "Default" end

  if ( CachedFontHeights[ font ] ) then
    return CachedFontHeights[ font ]
  end

  local hfont = GetFont( font )
  if ( not hfont ) then
    CachedFontHeights[ font ] = 0
    return 0
  end

  local w, h = surface.GetTextSize( hfont, "W" )
  CachedFontHeights[ font ] = h
  return h
end

-------------------------------------------------------------------------------
-- SimpleText(text, font, x, y, colour, xalign, yalign)
-------------------------------------------------------------------------------
function SimpleText( text, font, x, y, colour, xalign, yalign )
  text = tostring( text )
  font = font or "Default"
  x = x or 0
  y = y or 0
  xalign = xalign or TEXT_ALIGN_LEFT
  yalign = yalign or TEXT_ALIGN_TOP

  local hfont = GetFont( font )
  if ( not hfont ) then return 0, 0 end

  local w, h = surface.GetTextSize( hfont, text )

  if ( xalign == TEXT_ALIGN_CENTER ) then
    x = x - w / 2
  elseif ( xalign == TEXT_ALIGN_RIGHT ) then
    x = x - w
  end

  if ( yalign == TEXT_ALIGN_CENTER ) then
    y = y - h / 2
  elseif ( yalign == TEXT_ALIGN_BOTTOM ) then
    y = y - h
  end

  surface.DrawSetTextFont( hfont )
  surface.DrawSetTextPos( math.ceil( x ), math.ceil( y ) )

  if ( colour ) then
    local cr, cg, cb, ca = GetColorChannels( colour, 255 )
    surface.DrawSetTextColor( cr, cg, cb, ca )
  else
    surface.DrawSetTextColor( 255, 255, 255, 255 )
  end

  surface.DrawPrintText( text )
  surface.DrawFlushText()   -- HL2SB text is buffered; flush so it appears

  return w, h
end

-------------------------------------------------------------------------------
-- SimpleTextOutlined(...)
-------------------------------------------------------------------------------
function SimpleTextOutlined( text, font, x, y, colour, xalign, yalign, outlinewidth, outlinecolour )
  local steps = ( outlinewidth * 2 ) / 3
  if ( steps < 1 ) then steps = 1 end

  for _x = -outlinewidth, outlinewidth, steps do
    for _y = -outlinewidth, outlinewidth, steps do
      SimpleText( text, font, x + _x, y + _y, outlinecolour, xalign, yalign )
    end
  end

  return SimpleText( text, font, x, y, colour, xalign, yalign )
end

-------------------------------------------------------------------------------
-- Text(tab): table structure {text, font, pos, color, xalign, yalign}
-------------------------------------------------------------------------------
function Text( tab )
  return SimpleText( tab.text, tab.font, tab.pos[ 1 ], tab.pos[ 2 ], tab.color, tab.xalign, tab.yalign )
end

-------------------------------------------------------------------------------
-- TextShadow(tab, distance, alpha)
-------------------------------------------------------------------------------
function TextShadow( tab, distance, alpha )
  alpha = alpha or 200

  local color = tab.color
  local pos = tab.pos
  tab.color = Color( 0, 0, 0, alpha )
  tab.pos = { pos[ 1 ] + distance, pos[ 2 ] + distance }

  Text( tab )

  tab.color = color
  tab.pos = pos

  return Text( tab )
end

-- Set the current draw colour (see GetColorChannels above).
local function SetDrawColour( c, r, g, b, a )
  if ( c ) then
    local cr, cg, cb, ca = GetColorChannels( c, a )
    surface.DrawSetColor( cr, cg, cb, ca )
  else
    surface.DrawSetColor( r, g, b, a or 255 )
  end
end

-------------------------------------------------------------------------------
-- RoundedBox(bordersize, x, y, w, h, color)
-- Implements a rounded box with the gui/cornerX textures, matching GMod.
-- Textures are loaded lazily through surface.DrawSetTextureFile.
-------------------------------------------------------------------------------
local cornerTex = {
  [8]   = "gui/corner8",
  [16]  = "gui/corner16",
  [32]  = "gui/corner32",
  [64]  = "gui/corner64",
  [512] = "gui/corner512",
}
local cornerTexId = {}

-- Return a texture id for the given gui/cornerX name, caching by name.
local function GetTexture( name )
  if ( cornerTexId[ name ] ) then
    return cornerTexId[ name ]
  end

  local id = surface.CreateNewTextureID()
  surface.DrawSetTextureFile( id, name, 1, false )   -- 1 = clamp, false = no restore
  cornerTexId[ name ] = id
  return id
end

function RoundedBoxEx( bordersize, x, y, w, h, color, tl, tr, bl, br )
  if ( not color ) then return end

  SetDrawColour( color )

  -- Do not waste performance if they don't want rounded corners.
  if ( bordersize <= 0 ) then
    surface.DrawFilledRect( x, y, x + w, y + h )
    return
  end

  bordersize = math.min( math.Round( bordersize ), math.floor( w / 2 ), math.floor( h / 2 ) )
  x = math.Round( x )
  y = math.Round( y )
  w = math.Round( w )
  h = math.Round( h )

  -- GMod's body: three flat rects, then four corners blitted from gui/cornerN.
  -- The UVs are what place a *single*-corner texture in the four screen corners
  -- (this is the same mapping surface.DrawTexturedRectRotated( 0/90/180/270 )
  -- gets from rotating the quad):
  --     top-left (0,0,1,1)   top-right (1,0,0,1)
  --     bottom-left (0,1,1,0) bottom-right (1,1,0,0)
  surface.DrawFilledRect( x + bordersize, y, x + w - bordersize, y + h )
  surface.DrawFilledRect( x, y + bordersize, x + bordersize, y + h - bordersize )
  surface.DrawFilledRect( x + w - bordersize, y + bordersize, x + w, y + h - bordersize )

  local tex = cornerTex[ 8 ]
  if ( bordersize > 8 ) then tex = cornerTex[ 16 ] end
  if ( bordersize > 16 ) then tex = cornerTex[ 32 ] end
  if ( bordersize > 32 ) then tex = cornerTex[ 64 ] end
  if ( bordersize > 64 ) then tex = cornerTex[ 512 ] end

  -- surface.SetTexture() is what GMod's draw.lua does, and it is mandatory:
  -- without it the bound texture is still the engine's default white one and
  -- the "corners" paint solid white over the box.
  surface.SetTexture( GetTexture( tex ) )

  if ( tl ) then
    surface.DrawTexturedRectUV( x, y, bordersize, bordersize, 0, 0, 1, 1 )
  else
    surface.DrawFilledRect( x, y, x + bordersize, y + bordersize )
  end

  if ( tr ) then
    surface.DrawTexturedRectUV( x + w - bordersize, y, bordersize, bordersize, 1, 0, 0, 1 )
  else
    surface.DrawFilledRect( x + w - bordersize, y, x + w, y + bordersize )
  end

  if ( bl ) then
    surface.DrawTexturedRectUV( x, y + h - bordersize, bordersize, bordersize, 0, 1, 1, 0 )
  else
    surface.DrawFilledRect( x, y + h - bordersize, x + bordersize, y + h )
  end

  if ( br ) then
    surface.DrawTexturedRectUV( x + w - bordersize, y + h - bordersize, bordersize, bordersize, 1, 1, 0, 0 )
  else
    surface.DrawFilledRect( x + w - bordersize, y + h - bordersize, x + w, y + h )
  end
end

function RoundedBox( bordersize, x, y, w, h, color )
  return RoundedBoxEx( bordersize, x, y, w, h, color, true, true, true, true )
end

-------------------------------------------------------------------------------
-- WordBox(bordersize, x, y, text, font, boxcolor, textcolor, xalign, yalign)
-- Draws a rounded box behind text, sized to the text.
-------------------------------------------------------------------------------
function WordBox( bordersize, x, y, text, font, color, fontcolor, xalign, yalign )
  local hfont = GetFont( font or "Default" )
  if ( not hfont ) then return 0, 0 end

  local w, h = surface.GetTextSize( hfont, text )

  if ( xalign == TEXT_ALIGN_CENTER ) then
    x = x - ( bordersize + w / 2 )
  elseif ( xalign == TEXT_ALIGN_RIGHT ) then
    x = x - ( bordersize * 2 + w )
  end

  if ( yalign == TEXT_ALIGN_CENTER ) then
    y = y - ( bordersize + h / 2 )
  elseif ( yalign == TEXT_ALIGN_BOTTOM ) then
    y = y - ( bordersize * 2 + h )
  end

  RoundedBox( bordersize, x, y, w + bordersize * 2, h + bordersize * 2, color )

  SimpleText( text, font, x + bordersize, y + bordersize, fontcolor )

  return w + bordersize * 2, h + bordersize * 2
end

-------------------------------------------------------------------------------
-- DrawText( text, font, x, y, colour, xalign )
--
-- GMod (wiki): "Simple draw text at position, but this will expand newlines and
-- tabs."  Defaults: font "DermaDefault", x/y 0, colour color_white,
-- xalign TEXT_ALIGN_LEFT.  Returns nothing.
--
-- SimpleText above is the single-line primitive; this one splits on "\n" and
-- walks y down by one line height per row (GMod does the same, and expands a tab
-- to four spaces).  Each row is aligned on its own, so TEXT_ALIGN_CENTER centres
-- every row independently -- exactly like GMod.
-------------------------------------------------------------------------------
local TabExpansion = "    "   -- GMod expands "\t" to 4 spaces

function DrawText( text, font, x, y, colour, xalign )
	text    = tostring( text )
	font    = font or "DermaDefault"
	x       = x or 0
	y       = y or 0
	xalign  = xalign or TEXT_ALIGN_LEFT
	colour  = colour or color_white

	local lineHeight = GetFontHeight( font )

	-- Append "\n" so gmatch also yields the last row when there is no trailing
	-- newline ("a\nb" -> "a", "b"; "a\n" -> "a", "").
	for line in string.gmatch( text .. "\n", "([^\n]*)\n" ) do
		SimpleText( ( string.gsub( line, "\t", TabExpansion ) ), font, x, y, colour, xalign, TEXT_ALIGN_TOP )
		y = y + lineHeight
	end
end

-------------------------------------------------------------------------------
-- NoTexture()
--
-- GMod (wiki): "Sets drawing texture to a default white texture (vgui/white) via
-- surface.SetMaterial. Useful for resetting the drawing texture."
--
-- Two HL2SB facts force the shape below:
--
--   * the engine's surface.SetMaterial is the raw binding (luaL_checkmaterial),
--     so it only accepts a real IMaterial -- and Material() is a Lua proxy table
--     in this fork, which would make that binding throw;
--   * binding by texture id is the path this tree already proves: RoundedBox
--     binds gui/cornerN with surface.SetTexture + DrawSetTextureFile and the
--     rounded corners render (game commit 976e52d).
--
-- The observable result is the same one GMod gives: the next DrawTexturedRect
-- paints solid white.  materials/vgui/white.vmt ships with the mod so the path
-- resolves for GMod scripts that call Material("vgui/white") themselves.
-------------------------------------------------------------------------------
local NoTextureID = nil

function NoTexture()
	if ( NoTextureID == nil ) then
		NoTextureID = surface.GetTextureID( "vgui/white" )
	end

	surface.SetTexture( NoTextureID )
end

-------------------------------------------------------------------------------
-- TexturedQuad( texturedata )
--
-- GMod (wiki) draws a texture from a TextureData structure:
--
--     { texture = <surface.GetTextureID() number>,   -- required
--       x = 0, y = 0, w = 0, h = 0,                   -- the quad
--       color = color_white }                          -- optional tint
--
-- GMod implements it with a mesh so the four corners can carry independent UVs;
-- this engine has no mesh binding, and the mesh is only needed for a ROTATED
-- quad.  Axis-aligned UVs -- every atlas/sub-rect use, which is what
-- TexturedQuad is for -- are exact through DrawTexturedRectUV, so that is what
-- this uses.  uv1 (top-left) / uv3 (bottom-right) are honoured when present,
-- which is the field pair GMod's older TextureData carried.
-------------------------------------------------------------------------------
function TexturedQuad( texturedata )
	if ( texturedata == nil ) then return end

	local tex = texturedata.texture
	if ( tex ~= nil ) then
		-- Accept the id number, or anything material-shaped (the Lua Material()
		-- proxy, an IMaterial) by asking it for its texture id.
		if ( type( tex ) == "table" and tex.GetTextureID ~= nil ) then
			surface.SetTexture( tex:GetTextureID() )
		else
			surface.SetTexture( tex )
		end
	end

	SetDrawColour( texturedata.color, 255, 255, 255, 255 )

	local x = texturedata.x or 0
	local y = texturedata.y or 0
	local w = texturedata.w or 0
	local h = texturedata.h or 0

	local uv1 = texturedata.uv1
	local uv3 = texturedata.uv3

	if ( uv1 ~= nil and uv3 ~= nil ) then
		local u0 = uv1[ 1 ] or uv1.u or 0
		local v0 = uv1[ 2 ] or uv1.v or 0
		local u1 = uv3[ 1 ] or uv3.u or 1
		local v1 = uv3[ 2 ] or uv3.v or 1

		surface.DrawTexturedRectUV( x, y, w, h, u0, v0, u1, v1 )
	else
		surface.DrawTexturedRect( x, y, w, h )
	end
end

-- Load marker.
print( "[HL2SB] draw library loaded" )
