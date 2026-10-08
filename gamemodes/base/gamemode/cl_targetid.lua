--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/cl_targetid.lua

    GMod base gamemode cl_targetid.lua, ported for HL2SB (2026-10-08).
    Client realm, driven from GM:HUDPaint via hook.Run( "HUDDrawTargetID" ).

    Deviation: input.GetCursorPos and vgui.CursorVisible have no bindings in
    this fork yet - both probes fall back to "no cursor" behaviour (aim at
    screen centre) instead of erroring, and pick the real cursor up as soon
    as the bindings land.
--------------------------------------------------------------------------]]--


--[[---------------------------------------------------------
   Name: gamemode:HUDDrawTargetID( )
   Desc: Draw the target id (the name of the player you're currently looking at)
-----------------------------------------------------------]]
function GM:HUDDrawTargetID()

	local trace = LocalPlayer():GetEyeTrace()
	if ( !trace.Hit ) then return end
	if ( !trace.HitNonWorld ) then return end

	local text = "ERROR"
	local font = "TargetID"

	if ( trace.Entity:IsPlayer() ) then
		text = trace.Entity:Nick()
	else
		--text = trace.Entity:GetClass()
		return
	end

	surface.SetFont( font )
	local w, h = surface.GetTextSize( text )

	local MouseX, MouseY = 0, 0
	if ( input.GetCursorPos ~= nil ) then
		MouseX, MouseY = input.GetCursorPos()
	end

	local bCursorVisible = ( vgui.CursorVisible ~= nil and vgui.CursorVisible() ) or false
	if ( ( MouseX == 0 && MouseY == 0 ) || !bCursorVisible ) then

		MouseX = ScrW() / 2
		MouseY = ScrH() / 2

	end

	local x = MouseX
	local y = MouseY

	x = x - w / 2
	y = y + 30

	-- The fonts internal drop shadow looks lousy with AA on
	draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, 120 ) )
	draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 50 ) )
	draw.SimpleText( text, font, x, y, self:GetTeamColor( trace.Entity ) )

	y = y + h + 5

	-- Draw the health
	text = trace.Entity:Health() .. "%"
	font = "TargetIDSmall"

	surface.SetFont( font )
	w, h = surface.GetTextSize( text )
	x = MouseX - w / 2

	draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, 120 ) )
	draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 50 ) )
	draw.SimpleText( text, font, x, y, self:GetTeamColor( trace.Entity ) )

end
