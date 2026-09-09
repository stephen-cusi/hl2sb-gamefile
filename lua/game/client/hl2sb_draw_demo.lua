--[[---------------------------------------------------------------------------
    HL2SB draw library demo (visible in game immediately).

    Draws a small debug card over the kill feed using the ported GMod-style
    draw library (draw.SimpleText / draw.RoundedBox / draw.GetFontHeight).
    This is a proof that:
        - the draw.lua port loads,
        - surface.SetFont(name) resolves HL2SB scheme fonts,
        - math.Round/Clamp (the ported math extension) work,
        - the HudViewportPaint hook reaches Lua.

    Toggle with:  hl2sb_draw_demo <0|1>   (default on)
        hl2sb_draw_demo                   (print value)

    Path: lua/game/client/hl2sb_draw_demo.lua
---------------------------------------------------------------------------]]

if ( not _CLIENT ) then return end

require( "hook" )
require( "surface" )
require( "math" )   -- pulls the HL2SB math extension (Round/Clamp/...)

-- draw module is loaded from includes/modules by the engine already; guard in
-- case a hot-reload runs this before the module list.
if ( not draw ) then
  if ( require ) then
    pcall( require, "draw" )
  end
  if ( not draw ) then
    print( "[HL2SB][draw-demo] draw library not available, aborting" )
    return
  end
end

local draw    = draw
local surface = surface
local Color   = Color
local math    = math
local curtime = gpGlobals.curtime

-- One-shot draw log guard.
local bLoggedDraw = false

-- Demo cvar (client).
-- Use concommand? No - this is a simple numeric toggle; a plain global is fine,
-- but for a proper convar we register through the ConCommand path.  For the
-- demo we just read/set a Lua global + expose a console command.
HL2SB_DrawDemo = HL2SB_DrawDemo or 1

-- Console toggle.
if ( concommand and not _G.__hl2sb_draw_demo_cmd ) then
  _G.__hl2sb_draw_demo_cmd = true
  concommand.Create( "hl2sb_draw_demo", function( pPlayer, pCmd, argstr )
    local v = tonumber( argstr )
    if ( v ) then
      HL2SB_DrawDemo = ( v ~= 0 ) and 1 or 0
      print( string.format( "[HL2SB][draw-demo] = %d\n", HL2SB_DrawDemo ) )
    else
      print( string.format( "[HL2SB][draw-demo] = %d   (usage: hl2sb_draw_demo <0|1>)\n",
        HL2SB_DrawDemo ) )
    end
  end, "Toggle the draw.lua demo card (0 = off, 1 = on)" )
end

-- Draw a small card near the top-left.
local function DrawCard()
  local w, h = surface.GetScreenSize()

  local NOW = curtime()

  -- Anchored top-left, below the crosshair area, labelled clearly.
  local x0 = 16
  local y0 = 16
  local bw = 2

  local pad = 10
  local font = "Default"
  local smallFont = "Default"   -- HL2SB scheme has Default / DefaultSmall / DefaultVerySmall

  local title = "draw lib demo"
  local line1 = "curtime " .. string.format( "%.2f", NOW )
  local line2 = "Round(1.6)=" .. tostring( math.Round( 1.6 ) )
    .. "  Clamp(5,0,1)=" .. tostring( math.Clamp( 5, 0, 1 ) )
  local line3 = "Size " .. tostring( w ) .. "x" .. tostring( h )

  -- Measure the box.
  local hfont = surface.SetFont( font )   -- no-op warm, but read for width if needed
  local tw = 0
  local tH = draw.GetFontHeight( font )
  tw = #title

  -- We cannot easily string-measure width of arbitrary text without a helper;
  -- approximate with the longest line's char count * a rough per-char width.
  local perChar = 7
  local maxLen = #line1
  if ( #line2 > maxLen ) then maxLen = #line2 end
  if ( #line3 > maxLen ) then maxLen = #line3 end
  if ( #title > maxLen ) then maxLen = #title end

  local boxW = 20 + maxLen * perChar
  local boxH = 20 + tH * 4

  -- Background.
  draw.RoundedBox( bw, x0, y0, boxW, boxH, Color( 20, 20, 24, 200 ) )

  -- Outline.
  surface.DrawSetColor( 255, 255, 255, 40 )
  surface.DrawOutlinedRect( x0, y0, x0 + boxW, y0 + boxH )

  -- Title (gold).
  draw.SimpleText( title, font, x0 + pad, y0 + pad, Color( 255, 210, 60, 255 ) )

  -- Body lines (white).
  local yy = y0 + pad + tH + 4
  draw.SimpleText( line1, smallFont, x0 + pad, yy, Color( 220, 220, 220, 255 ) ); yy = yy + tH + 2
  draw.SimpleText( line2, smallFont, x0 + pad, yy, Color( 220, 220, 220, 255 ) ); yy = yy + tH + 2
  draw.SimpleText( line3, smallFont, x0 + pad, yy, Color( 220, 220, 220, 255 ) )
  surface.DrawFlushText()   -- ensure the text is flushed on screen

  -- One-shot log so we can confirm the demo actually drew.
  if ( not bLoggedDraw ) then
    bLoggedDraw = true
    print( string.format( "[HL2SB][draw-demo] drew  box=%dx%d  fontTall=%d\n",
      boxW, boxH, tH ) )
  end
end

hook.add( "HudViewportPaint", "hl2sb_draw_demo", function()
  if ( HL2SB_DrawDemo == 0 ) then return end
  local ok, err = pcall( DrawCard )
  if ( not ok ) then
    print( "[HL2SB][draw-demo] error: " .. tostring( err ) )
    HL2SB_DrawDemo = 0   -- stop spamming on failure
  end
end )

print( "[HL2SB] hl2sb_draw_demo.lua loaded" )
