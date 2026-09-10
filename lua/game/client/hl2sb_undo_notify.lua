--[[---------------------------------------------------------------------------
    HL2SB undo notification (client side) - GMod style.

    Signal:  net.Receive("UndoNotify", name, count)  (from the server undo hook)
    Draw:    HudViewportPaint, once per frame.

    Reproduces GMod's sandbox gamemode undo notification:
      * GM:OnUndo -> notification.AddLegacy(text, NOTIFY_UNDO, 2)
      * a bar slides IN from the right edge, anchored at 80% screen height,
        right-aligned with a small gap, using the spring/ease math from
        GMod's notification.lua (UpdateNotice).
      * holds ~2s, then slides back off the right edge.
      * clicks the GMod undo sound: surface.PlaySound("buttons/button15.wav")

    Drawn with raw surface calls (HL2SB's vgui bindings are too weak for the
    DNotify controls).  The undo icon material (vgui/notices/undo) is drawn as a
    small accent square since that material is not available in HL2SB.

    Loaded every level from lua/game/client/.
-----------------------------------------------------------------------------]]

require( "hook" )
require( "net" )

local surface  = surface
local ScrW     = ScrW
local ScrH     = ScrH
local RealTime = RealTime
local FrameTime = FrameTime

-- Config (GMod notification defaults).
local NOTIF_START_X   = 200     -- px off the right edge to start
local NOTIF_GAP_X     = 0.015   -- right gap (% of screen)
local NOTIF_CHARGE_X  = 0.04    -- "about to leave" nudge (% of screen)
local NOTIF_ANCHOR_Y  = 0.8     -- anchor height (% of screen)
local NOTIF_LIFETIME  = 2.0     -- seconds visible (GMod uses 2)
local NOTIF_HEIGHT    = 26
local NOTIF_TEXT_H    = 12

-- Queue of active notices.
local Notices = {}

-- Font.
local hFont
local function EnsureFont()
	if hFont then return hFont end
	hFont = surface.SetFont( "Default" )
	if not hFont or hFont == 0 then
		hFont = surface.SetFont( "DefaultSmall" )
	end
	return hFont
end

-- GMod undo sound.
local function NotifySound()
	if surface.PlaySound then
		pcall( surface.PlaySound, "buttons/button15.wav" )
	end
end

local function TextWidth( str )
	return #str * 6.2
end

-- GMod undo icon material (materials/vgui/notices/undo), lazy-loaded.
local iUndoTex = -1
local ICON_SIZE = 14
local function UndoIcon()
	if iUndoTex == -1 then
		iUndoTex = surface.CreateNewTextureID()
		surface.DrawSetTextureFile( iUndoTex, "vgui/notices/undo", 1, false )
	end
	return iUndoTex
end

local function AddNotify( name, count )
	local text = "Undone: " .. tostring( name )
	if count and count > 1 then
		text = text .. " (" .. count .. " ents)"
	end

	local w = TextWidth( text ) + 12 + 12 + ICON_SIZE + 6   -- icon + padding
	local entry = {
		text   = text,
		w      = w,
		start  = RealTime(),
		x      = ScrW() + NOTIF_START_X,
		y      = ScrH(),
		vx     = -5,
		vy     = 0,
		removed = false,
	}
	table.insert( Notices, entry )
	NotifySound()
end

net.Receive( "UndoNotify", function( len, client )
	local name  = net.ReadString()
	local count = net.ReadInt()
	AddNotify( name, count )
end )

-- Spring / ease update from GMod's notification.lua UpdateNotice.
local function UpdateNotice( entry, total_h )
	local scrW = ScrW()
	local scrH = ScrH()

	local w = entry.w
	local h = NOTIF_HEIGHT

	local ideal_y = scrH * NOTIF_ANCHOR_Y - h - total_h
	local ideal_x = scrW - w - ( scrW * NOTIF_GAP_X )

	local age = RealTime() - entry.start
	local timeleft = NOTIF_LIFETIME - age

	if timeleft < 0.7 then
		ideal_x = ideal_x - ( scrW * NOTIF_CHARGE_X )
	end
	if timeleft < 0.2 then
		ideal_x = ideal_x + w * 2
	end
	-- Once the lifetime is over, drive it fully off the right edge so the
	-- spring can never leave it parked on-screen (which caused stale notices
	-- to linger and overlap the HUD).
	if timeleft <= 0 then
		ideal_x = scrW + w + NOTIF_START_X + 40
	end

	local spd = FrameTime() * 15

	entry.y = entry.y + entry.vy * spd
	entry.x = entry.x + entry.vx * spd

	local dist_y = ideal_y - entry.y
	entry.vy = entry.vy + dist_y * spd
	if math.abs( dist_y ) < 2 and math.abs( entry.vy ) < 0.1 then entry.vy = 0 end

	local dist_x = ideal_x - entry.x
	entry.vx = entry.vx + dist_x * spd
	if math.abs( dist_x ) < 2 and math.abs( entry.vx ) < 0.1 then entry.vx = 0 end

	entry.vx = entry.vx * ( 0.95 - FrameTime() * 8 )
	entry.vy = entry.vy * ( 0.95 - FrameTime() * 8 )

	-- Remove once the lifetime is over AND the bar has actually left the screen
	-- (or after a hard grace period so a stuck spring can never linger forever).
	if timeleft < 0 and ( entry.x > scrW or age > NOTIF_LIFETIME + 2.0 ) then
		entry.removed = true
	end

	return total_h + h
end

-- Draw the active notices each frame.
hook.add( "HudViewportPaint", "hl2sb_undo_notify", function()
	if #Notices == 0 then return end

	local font = EnsureFont()
	local total_h = 0

	-- Determine which notices are done this frame, then remove them all at once
	-- (removing inside the loop with `break` left stale entries on screen).
	local removeIdx = {}
	for i = 1, #Notices do
		local entry = Notices[i]
		total_h = UpdateNotice( entry, total_h )
		if entry.removed then
			removeIdx[#removeIdx + 1] = i
		end
	end
	for i = #removeIdx, 1, -1 do
		table.remove( Notices, removeIdx[i] )
	end

	-- Draw the remaining notices from the top of the stack downward.
	local draw_indent = 0
	for i = 1, #Notices do
		local entry = Notices[i]
		if not entry.removed then
			local scrW = ScrW()
			local w = entry.w
			local x = entry.x
			local y = entry.y
			if y > -scrW and y < ScrH() + 200 and x > -w and x < scrW + w + NOTIF_START_X then
				-- Background bar (GMod: Color(20,20,20, 255*0.6)).
				surface.DrawSetColor( 20, 20, 20, 153 )
				surface.DrawFilledRect( x, y, x + w, y + NOTIF_HEIGHT )

				-- Undo icon (GMod vgui/notices/undo material).
				local iy = y + ( NOTIF_HEIGHT - ICON_SIZE ) / 2
				surface.DrawSetTexture( UndoIcon() )
				surface.DrawSetColor( 255, 200, 120, 255 )
				surface.DrawTexturedRect( x + 8, iy, x + 8 + ICON_SIZE, iy + ICON_SIZE )

				-- Text, white, to the right of the icon.
				surface.DrawSetTextFont( font )
				surface.DrawSetTextPos( x + 8 + ICON_SIZE + 8, y + ( NOTIF_HEIGHT - NOTIF_TEXT_H ) / 2 )
				surface.DrawSetTextColor( 255, 255, 255, 255 )
				surface.DrawPrintText( entry.text )
				surface.DrawFlushText()
			end
		end
	end
end )

print( "[HL2SB] undo notify client loaded (GMod style)" )
