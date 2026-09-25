--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Wraps the font type so handles are persistent through screen size
--          changes, and fonts work properly without having to manually
--          recreate them.
--
-- HL2SB (2026-09-25): GMod compat rewrite.  The old version REPLACED
-- surface.CreateFont with a zero-argument container factory, so the GMod
-- spelling surface.CreateFont( name, fontData ) had its font data silently
-- discarded (an INVALID font handle inside a container), and the surface.*
-- font functions rejected plain font NAME strings:
--
--     cl_hitdamagenumbers.lua:127: bad argument #1 to 'GetTextSize'
--         (font or fontcontainer expected, got string)
--
-- which aborted the addon's init handler and left its "initialized" flag
-- unset forever (no damage numbers, no font measurement anywhere).
--
-- Now: GMod spellings pass straight through to the C bindings, which resolve
-- font names via luaL_checkfont / the surface.CreateFont registry.  The
-- HFontContainer is kept ONLY for the legacy bare surface.CreateFont() call
-- style (gmod_deathnotice.lua uses it) with its OnScreenSizeChanged rebuild.
--===========================================================================--

if not _CLIENT then return end

-- HL2SB (2026-09-25): install-once guard.  On listen servers the Lua loader
-- scans the game/client folder TWICE (lua_cache pass), and a second execution
-- would capture this file's OWN wrappers as the "C bindings" - nesting
-- containers inside containers and killing SetFontGlyphSet with
-- "HFont expected, got table" on every kill-feed redraw.
if ( _HL2SB_FONT_LUA_INSTALLED ) then return end
_HL2SB_FONT_LUA_INSTALLED = true

require( "UTIL" )
require( "surface" )
require( "hook" )

local INVALID_FONT = INVALID_FONT
local setmetatable = setmetatable
local ipairs = ipairs
local type = type
local ComputeStringWidth = UTIL.ComputeStringWidth
local GetFontName = _R.IScheme.GetFontName
local CreateFont = surface.CreateFont
local DrawSetTextFont = surface.DrawSetTextFont
local GetCharABCwide = surface.GetCharABCwide
local GetCharacterWidth = surface.GetCharacterWidth
local GetFontAscent = surface.GetFontAscent
local GetFontTall = surface.GetFontTall
local GetTextSize = surface.GetTextSize
local IsFontAdditive = surface.IsFontAdditive
local SetFontGlyphSet = surface.SetFontGlyphSet

-------------------------------------------------------------------------------
-- _R.HFontContainer
-- Purpose: Class metatable (legacy bare-call style only)
-------------------------------------------------------------------------------
_R.HFontContainer = {
  __index = {},
  __type = "fontcontainer"
}

local HFontContainerIndex = 1
local HFontContainers = {}

function HFontContainer()
  local t = {
    index = 0,
    font = INVALID_FONT,
    windowsFontName = "",
    tall = 0,
    weight = 0,
    blur = 0,
    scanlines = 0,
    flags = 0,
    nRangeMin = nil,
    nRangeMax = nil
  }
  setmetatable( t, _R.HFontContainer )
  return t
end

function _R.HFontContainer:__tostring()
  return "HFontContainer: " .. self.index
end

hook.add( "OnScreenSizeChanged", "HFontContainerManager", function()
  for i, fontcontainer in ipairs( HFontContainers ) do
    fontcontainer.font = CreateFont()
    SetFontGlyphSet( fontcontainer.font,
                     fontcontainer.windowsFontName,
                     fontcontainer.tall,
                     fontcontainer.weight,
                     fontcontainer.blur,
                     fontcontainer.scanlines,
                     fontcontainer.flags,
                     fontcontainer.nRangeMin,
                     fontcontainer.nRangeMax )
  end
end )

-- HL2SB: unwrap a font argument.  GMod addons pass font NAME strings, the
-- legacy Experiment code passes HFont userdata or containers - all resolve,
-- and the C bindings accept names through luaL_checkfont anyway.
local function unwrapFont( font )
  local t = type( font )
  if ( t == "table" and font.font ~= nil ) then
    return font.font
  end
  return font
end

function UTIL.ComputeStringWidth( font, str )
  return ComputeStringWidth( unwrapFont( font ), str )
end

function _R.IScheme.GetFontName( font )
  return GetFontName( unwrapFont( font ) )
end

function surface.CreateFont( a, b )
  -- HL2SB (2026-09-25): ALWAYS pass through to the C binding now.  The old
  -- container branch (bare CreateFont() -> HFontContainer table) broke every
  -- C-captured caller: draw.lua's draw.GetFont captured the raw C
  -- SetFontGlyphSet at load, then got our CONTAINER back from CreateFont() ->
  -- "HFont expected, got table" 2200x/frame, and gmod_deathnotice failed to
  -- load (kill feed gone).  A bare CreateFont() now returns a real HFont.
  return CreateFont( a, b )
end

function surface.DrawSetTextFont( font )
  return DrawSetTextFont( unwrapFont( font ) )
end

function surface.GetCharABCwide( font, ch )
  return GetCharABCwide( unwrapFont( font ), ch )
end

function surface.GetCharacterWidth( font, ch )
  return GetCharacterWidth( unwrapFont( font ), ch )
end

function surface.GetFontAscent( font, ch )
  return GetFontAscent( unwrapFont( font ), ch )
end

function surface.GetFontTall( font )
  return GetFontTall( unwrapFont( font ) )
end

function surface.GetTextSize( font, text )
  -- GMod: surface.GetTextSize( text ) measures with the font last set by
  -- surface.SetFont (single string argument); the engine binding implements
  -- that form.  Two arguments: ( font, text ) with names/containers unwrapped.
  if ( text == nil and type( font ) == "string" ) then
    return GetTextSize( font )
  end
  return GetTextSize( unwrapFont( font ), text )
end

function surface.IsFontAdditive( font )
  return IsFontAdditive( unwrapFont( font ) )
end

function surface.SetFontGlyphSet( font, windowsFontName, tall, weight, blur, scanlines, flags, nRangeMin, nRangeMax )
  local t = type( font )
  if ( t == "table" and font.font ~= nil ) then
    -- container: remember the glyph set so resolution changes can rebuild
    font.windowsFontName = windowsFontName
    font.tall = tall
    font.weight = weight
    font.blur = blur
    font.scanlines = scanlines
    font.flags = flags
    font.nRangeMin = nRangeMin
    font.nRangeMax = nRangeMax
    return SetFontGlyphSet( font.font, windowsFontName, tall, weight, blur, scanlines, flags, nRangeMin, nRangeMax )
  end
  return SetFontGlyphSet( font, windowsFontName, tall, weight, blur, scanlines, flags, nRangeMin, nRangeMax )
end
