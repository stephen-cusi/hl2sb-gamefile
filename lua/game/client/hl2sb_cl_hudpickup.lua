--[[---------------------------------------------------------------------------
    HL2SB pickup HUD - GMod cl_hudpickup.lua port.

    Shows a GMod-style pickup bar when the local player picks something up:
    a rounded bar with a coloured left tab (weapon=orange / item=green /
    ammo=blue) and the name (+ ammo count) on the right.  Slides in from the
    right, holds ~5s, fades out.

    It also suppresses the stock HL2MP pickup-history icon (the battery /
    weapon circle icons) via the HudElementShouldDraw hook, so only this bar
    appears.  The weapon-selection menu (number keys / mouse wheel) is NOT
    touched.

    Engine -> Lua: item_pickup { userid, item, amount } -> HUDItemPickedUp.

    Toggle:
        hl2sb_pickup_hud 0  -> GMod pickup bar (default)
        hl2sb_pickup_hud 1  -> also allow the stock history icon

    Path: lua/game/client/hl2sb_cl_hudpickup.lua
---------------------------------------------------------------------------]]

if ( not _CLIENT ) then return end

require( "hook" )
require( "draw" )
require( "math" )   -- HL2SB math extension (Round/Clamp)

local draw    = draw
local hook    = hook
local math    = math
local surface = surface
local Color   = Color
local curtime = gpGlobals.curtime
local floor   = math.floor
local clamp   = math.Clamp

-- ---------------------------------------------------------------------------
-- Tunables
-- ---------------------------------------------------------------------------
local HOLD    = 4.0
local FADEIN  = 0.15
local FADEOUT = 0.35
local FONT    = "Default"

-- GMod palette for the bar tab.
local WEAPON_COLOR = { 255, 170, 40, 255 }   -- orange
local ITEM_COLOR   = { 90, 200, 90, 255 }    -- green
local AMMO_COLOR   = { 90, 160, 255, 255 }   -- blue

-- ---------------------------------------------------------------------------
-- Suppress the stock pickup-history icon (battery/weapon circle icons).
-- This only hides the pickup history element; the weapon-selection menu
-- (HudWeaponSelection) is untouched.  We must return a value for every element
-- so other HUD elements keep drawing.
-- ---------------------------------------------------------------------------
local bHideStockHistory = true

hook.add( "HudElementShouldDraw", "hl2sb_cl_hudpickup", function( name )
  -- Only suppress the stock pickup-history icon.  DECLARE_HUDELEMENT uses the
  -- class name (with the CHud prefix) as the element name, so the pickup
  -- history element is "CHudHistoryResource".  For every other element we
  -- return nil so RETURN_LUA_BOOLEAN() falls through to the engine's own
  -- ShouldDraw logic (respecting HIDEHUD etc).
  if ( bHideStockHistory and name == "CHudHistoryResource" ) then
    return false
  end
  return nil
end )

-- ---------------------------------------------------------------------------
-- Pickup history
-- ---------------------------------------------------------------------------
local PickupHistory = {}

local function AddPickup( name, amount, clr )
  local pickup = {}
  pickup.time    = curtime()
  pickup.name    = name or ""
  pickup.amount  = amount
  pickup.colour  = clr or WEAPON_COLOR
  pickup.holdtime= HOLD
  pickup.fadein  = FADEIN
  pickup.fadeout = FADEOUT
  pickup.font    = FONT
  pickup.height  = 20
  table.insert( PickupHistory, pickup )
end

-- ---------------------------------------------------------------------------
-- Draw one bar.  Returns next y and whether still alive.
-- ---------------------------------------------------------------------------
local function DrawBar( rightX, y, d )
  local age   = curtime() - d.time
  local life  = d.holdtime + d.fadeout
  local remain= life - age
  if ( remain <= 0 ) then return y, false end

  local alpha = 255
  if ( age < d.fadein ) then
    alpha = clamp( age / d.fadein, 0, 1 ) * 255
  elseif ( remain < d.fadeout ) then
    alpha = clamp( remain / d.fadeout, 0, 1 ) * 255
  end
  alpha = floor( alpha )

  local text = d.name
  if ( d.amount and tonumber( d.amount ) and tonumber( d.amount ) > 0 ) then
    text = d.name .. "   " .. tostring( d.amount )
  end

  -- Measure the text.
  local hfont = surface.CreateFont()   -- cheap: one per bar per frame is OK for now
  surface.SetFontGlyphSet( hfont, "Default", 16, 700, 0, 0, 0x010 )
  local textW, textH = surface.GetTextSize( hfont, text )
  if ( not textW or textW <= 0 ) then textW = 80 end
  if ( not textH or textH <= 0 ) then textH = 18 end

  local barH = textH + 10
  local tabW = 14          -- coloured tab width
  local padX = 10

  -- Slide in from the right.
  local slide = 1.0 - clamp( age / 0.25, 0, 1 )
  local barW  = tabW + textW + padX * 2
  local barX  = rightX - barW + slide * 80

  -- Bar background (dark).
  draw.RoundedBox( 2, barX, y, barW, barH, Color( 30, 30, 34, floor( alpha * 0.8 ) ) )

  -- Left tab (type colour).
  draw.RoundedBox( 2, barX, y, tabW, barH, Color( d.colour[1], d.colour[2], d.colour[3], alpha ) )

  -- Name + amount (white, right, vertically centred).
  draw.SimpleText( text, d.font, barX + tabW + padX, y + ( barH - textH ) / 2,
    Color( 235, 235, 235, alpha ), draw.TEXT_ALIGN_LEFT, draw.TEXT_ALIGN_TOP )

  return y + barH + 8, true
end

hook.add( "HudViewportPaint", "hl2sb_cl_hudpickup", function()
  if ( #PickupHistory == 0 ) then return end

  local sw, sh = surface.GetScreenSize()
  local rightX = sw - 20

  -- First pass: measure total stack height (bars) so we can centre the whole
  -- list on ~75% of the screen (GMod smooths PickupHistoryTop toward
  -- (ScrH()*0.75 - tall)/2).  This keeps a tall pickup history from running off
  -- the bottom of the screen.
  local stackTall = 0
  for i = 1, #PickupHistory do
    local d = PickupHistory[i]
    local age = curtime() - d.time
    if ( age >= 0 ) then
      stackTall = stackTall + ( d._h or 26 ) + 8
    end
  end

  -- Smoothly move the origin toward the centred position.
  local targetTop = ( sh * 0.75 - stackTall ) / 2
  if ( targetTop < 8 ) then targetTop = 8 end
  if ( not PickupHistoryTop ) then PickupHistoryTop = targetTop end
  PickupHistoryTop = ( PickupHistoryTop * 5 + targetTop ) / 6

  local y = PickupHistoryTop
  local alive = {}

  for i = 1, #PickupHistory do
    local newY, stillAlive = DrawBar( rightX, y, PickupHistory[i] )
    if ( stillAlive ) then
      y = newY
      alive[ #alive + 1 ] = PickupHistory[i]
    end
  end

  PickupHistory = alive
end )

-- ---------------------------------------------------------------------------
-- Handler (engine -> Lua)
-- ---------------------------------------------------------------------------
hook.add( "HUDItemPickedUp", "hl2sb_cl_hudpickup", function( userid, item, amount )
  item = item or ""
  amount = tonumber( amount ) or nil

  local low = string.lower( item )
  local clr
  if ( string.find( low, "_ammo", 1, true ) ) then
    clr = AMMO_COLOR
  elseif ( string.find( low, "item_", 1, true ) == 1 or string.find( low, "weapon_", 1, true ) ~= 1 ) then
    clr = ITEM_COLOR
  else
    clr = WEAPON_COLOR
  end

  -- GMod: merge a repeated ammo pickup into the existing card (accumulate the
  -- amount and refresh the timer) instead of stacking a new one, so picking up
  -- lots of the same ammo doesn't fill the screen.
  if ( string.find( low, "_ammo", 1, true ) ) then
    for i = 1, #PickupHistory do
      local e = PickupHistory[i]
      if ( e.name == item ) then
        local cur = tonumber( e.amount ) or 0
        e.amount = cur + ( amount or 0 )
        e.time   = curtime()        -- refresh
        print( string.format( "[HL2SB][pickup-hud] merged %s -> %s\n", item, tostring(e.amount) ) )
        return
      end
    end
  end

  AddPickup( item, amount, clr )
  print( string.format( "[HL2SB][pickup-hud] %s amount=%s\n", tostring(item), tostring(amount) ) )
end )

print( "[HL2SB] hl2sb_cl_hudpickup.lua loaded (GMod pickup bar)" )
