-----------------------------------------------------------------------------
-- HL2SB HUD 2D probe: one-command reproduction for "tarkov HUD draws nothing".
--
-- Run `hl2sb_pphud_probe` in the console.  For 5 seconds the HUD draws, with
-- the tarkov addon's own API sequence, four reference elements stacked down
-- the left edge of the screen:
--
--   y= 20  red rect            (surface.DrawRect - control, always worked)
--   y=100  cursor_hand.png     (Material("Tarkov HUD/...") + surface.SetMaterial
--                               + surface.DrawTexturedRect - the addon's quad path)
--   y=280  "MBender" 39        (the addon's own font name/size via draw.SimpleText)
--   y=340  "Arial" 30 + timer  (a font every machine has - text control)
--
-- Reading the result:
--   rect visible, image missing        -> image-material draw path bug (engine)
--   MBender missing, Arial visible     -> surface.CreateFont font resolution bug
--   everything visible                 -> the addon itself is fine here and its
--                                         panels are hidden by its own autohide
--                                         timers (they only show ~3s after
--                                         damage / movement / stance change)
--
-- The console command also prints the material IsError state and the HFont
-- handles so the answer is visible even without looking at the screen.
-----------------------------------------------------------------------------

if ( not CLIENT ) then return end

surface.CreateFont( "hl2sb_pphud_probe_mbender", {
	font = "MBender",
	size = 39,
	weight = 500,
	antialias = true,
} )

surface.CreateFont( "hl2sb_pphud_probe_arial", {
	font = "Arial",
	size = 30,
	weight = 500,
	antialias = true,
} )

local flProbeUntil = nil

hook.Add( "HUDPaint", "hl2sb_pphud_probe", function()

	if ( flProbeUntil == nil ) then return end

	local flLeft = flProbeUntil - CurTime()
	if ( flLeft <= 0 ) then
		flProbeUntil = nil
		return
	end

	-- 1. control rect (pure geometry, no material)
	surface.SetDrawColor( 255, 0, 0, 255 )
	surface.DrawRect( 20, 20, 120, 60 )

	-- 2. the addon's exact quad path: image material + DrawTexturedRect
	local mat = Material( "Tarkov HUD/icons/cursor_hand.png", "tarkovMaterial" )
	surface.SetDrawColor( 255, 255, 255, 255 )
	surface.SetMaterial( mat )
	surface.DrawTexturedRect( 20, 100, 152, 152 )

	-- 3. the addon's own font (MBender 39)
	draw.SimpleText( "MBender39 " .. math.max( 0, math.floor( flLeft ) ), "hl2sb_pphud_probe_mbender", 20, 280, Color( 255, 255, 0, 255 ) )

	-- 4. a font every machine has (Arial 30)
	draw.SimpleText( "Arial30", "hl2sb_pphud_probe_arial", 20, 340, Color( 0, 255, 0, 255 ) )

end )

concommand.Add( "hl2sb_pphud_probe", function()

	flProbeUntil = CurTime() + 5

	local mat = Material( "Tarkov HUD/icons/cursor_hand.png", "tarkovMaterial" )
	local bError = true
	if ( mat ~= nil and mat.IsError ~= nil ) then
		bError = mat:IsError()
	end
	print( "[pphud_probe] material IsError = " .. tostring( bError ) )

	print( "[pphud_probe] MBender font handle = " .. tostring( surface.SetFont( "hl2sb_pphud_probe_mbender" ) ) )
	print( "[pphud_probe] Arial font handle   = " .. tostring( surface.SetFont( "hl2sb_pphud_probe_arial" ) ) )

	local w, h = surface.GetTextSize( surface.SetFont( "hl2sb_pphud_probe_mbender" ), "MBENDER" )
	print( "[pphud_probe] MBender GetTextSize(MBENDER) = " .. tostring( w ) .. " x " .. tostring( h ) )

	print( "[pphud_probe] overlay runs for 5s - watch the top-left stack" )

end, nil, "Draw the HUD 2D probe stack (rect / tarkov png / MBender / Arial) for 5 seconds." )
