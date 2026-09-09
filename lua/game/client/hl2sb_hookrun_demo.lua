--[[---------------------------------------------------------------------------
    HL2SB hook.Run demo.

    Proves the GMod-compatible hook.Run(name, ...) works on HL2SB and shows
    how it couples with the ported draw library.  We register an event, fire it
    with hook.Run, use the returned value, and draw a small card with it.

    Toggle:  hl2sb_hookrun_demo <0|1>     (default on)

    Path: lua/game/client/hl2sb_hookrun_demo.lua
---------------------------------------------------------------------------]]

if ( not _CLIENT ) then return end

require( "hook" )
require( "draw" )

local draw    = draw
local hook    = hook
local surface = surface
local Color   = Color

HL2SB_HookRunDemo = HL2SB_HookRunDemo or 1

-- Console toggle.
if ( concommand and not _G.__hl2sb_hookrun_demo_cmd ) then
  _G.__hl2sb_hookrun_demo_cmd = true
  concommand.Create( "hl2sb_hookrun_demo", function( pPlayer, pCmd, argstr )
    local v = tonumber( argstr )
    if ( v ) then
      HL2SB_HookRunDemo = ( v ~= 0 ) and 1 or 0
      print( string.format( "[HL2SB][hookrun-demo] = %d\n", HL2SB_HookRunDemo ) )
    else
      print( "[HL2SB][hookrun-demo] = " .. tostring( HL2SB_HookRunDemo )
        .. "   (usage: hl2sb_hookrun_demo <0|1>)" )
    end
  end, "Toggle the hook.Run demo card" )
end

-- Register an event that generates a line of text.  This is what a GMod addon
-- would do; hook.Run( "AddHudLine", ... ) lets any script hook in.
hook.add( "HL2SB_HookLine", "hl2sb_hookrun_demo", function( prefix, n )
  -- Return a string; hook.Run returns the first non-nil value.
  return prefix .. " hook.Run#" .. tostring( n )
end )

-- Second hook on the same event, returning nil (so the first wins).
hook.add( "HL2SB_HookLine_Second", "hl2sb_hookrun_demo", function()
  -- returns nil on purpose
end )

local bLogged = false

hook.add( "HudViewportPaint", "hl2sb_hookrun_demo", function()
  if ( HL2SB_HookRunDemo == 0 ) then return end

  -- Fire the event twice via hook.Run (returns first non-nil each time).
  local line1 = hook.Run( "HL2SB_HookLine", "line1", 1 )
  local line2 = hook.Run( "HL2SB_HookLine", "line2", 2 )

  local w, h = surface.GetScreenSize()
  local pad = 10
  local x0 = 16
  local y0 = 160

  local tH = draw.GetFontHeight( "Default" )
  local boxW = 240
  local boxH = 20 + tH * 3

  draw.RoundedBox( 2, x0, y0, boxW, boxH, Color( 20, 20, 24, 200 ) )

  local yy = y0 + pad
  draw.SimpleText( "hook.Run demo", "Default", x0 + pad, yy, Color( 255, 210, 60, 255 ) )
  yy = yy + tH + 2
  draw.SimpleText( tostring( line1 ), "Default", x0 + pad, yy, Color( 220, 220, 220, 255 ) )
  yy = yy + tH + 2
  draw.SimpleText( tostring( line2 ), "Default", x0 + pad, yy, Color( 220, 220, 220, 255 ) )
  surface.DrawFlushText()

  if ( not bLogged ) then
    bLogged = true
    print( string.format( "[HL2SB][hookrun-demo] line1='%s' line2='%s'\n",
      tostring(line1), tostring(line2) ) )
  end
end )

print( "[HL2SB] hl2sb_hookrun_demo.lua loaded" )
