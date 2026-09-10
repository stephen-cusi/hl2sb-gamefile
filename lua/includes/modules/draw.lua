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

  if ( bordersize <= 0 ) then
    surface.DrawFilledRect( x, y, x + w, y + h )
    return
  end

  bordersize = math.min( math.max( math.Round( bordersize ), 0 ), math.floor( w / 2 ), math.floor( h / 2 ) )
  x = math.Round( x )
  y = math.Round( y )
  w = math.Round( w )
  h = math.Round( h )

  -- Plain solid rectangle.  The HL2SB gui/cornerX textures render as crisp
  -- round corners, but the user chose to keep the simple sharp-cornered box,
  -- so we just fill the whole rect with the draw colour.
  surface.DrawFilledRect( x, y, x + w, y + h )
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

-- Load marker.
print( "[HL2SB] draw library loaded" )
