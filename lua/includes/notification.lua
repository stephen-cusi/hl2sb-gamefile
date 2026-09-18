--[[----------------------------------------------------------------------------
	lua/includes/notification.lua  --  HL2SB's notification stack.

	Modelled on Garry's Mod's own lua/includes/modules/notification.lua (read
	from the local GMod install, D:\games\garrysmod): same geometry, same
	colours, same animation numbers.  Rewritten rather than copied, because the
	engine side differs:

	  * GMod creates its icon as a DImage + Material( "vgui/notices/..." ) and
	    calls DImage:SetMaterial / PaintAt.  This fork has no DImage control and
	    its surface.SetMaterial is the raw engine binding ( luaL_checkmaterial:
	    a Lua Material() proxy table is rejected ), so the icon is drawn from a
	    texture id -- the path this tree already proves.
	  * GMod's label uses Label:SetExpensiveShadow.  This fork's DLabel draws in
	    Lua and has no shadow binding, so the 1px black shadow is drawn here.
	  * GMod's panel is a DPanel whose background it sets with
	    SetBackgroundColor( Color( 20, 20, 20, 255 * 0.6 ) ); here the skin's
	    PaintNotify paints exactly that.

	Numbers taken from GMod's file (do not "improve" them):
		textH  = max( 12, ceil( ScreenScaleH( 9 ) ) )    font "GModNotify", Arial,
		iconH  = ceil( textH * 1.25 )                     weight 500, extended
		NOTIF_START_X  = 200      pixels off screen to start
		NOTIF_CHARGE_X = 0.04     of screen width: the "about to go" pull-back
		NOTIF_GAP_X    = 0.015    of screen width: right margin
		NOTIF_ANCHOR_Y = 0.8      of screen height: the stack anchor

	The exit is NOT a kick: GMod moves the *target* x.  With less than 0.7s left
	the target pulls LEFT by 4% of the screen (the cartoon wind-up), and with
	less than 0.2s left it jumps RIGHT by twice the panel width (gone), the
	spring doing the rest.  An earlier version of this file skipped straight to
	a hard velocity kick, which read as "it just shoots off".

	Public surface (unchanged): notification.AddLegacy / AddProgress / Kill,
	the NOTIFY_* constants, and the Notify() global.
----------------------------------------------------------------------------]]--

if ( not ( CLIENT or _GAMEUI ) ) then return end

local textH = math.max( 12, math.ceil( ( ScreenScaleH and ScreenScaleH( 9 ) ) or 9 ) )
local iconH = math.ceil( textH * 1.25 )

-- HL2SB: CJK-capable face (Arial has no CJK glyphs; notifications show
-- localised text).
surface.CreateFont( "GModNotify", {
	font		= "Microsoft YaHei",
	size		= textH,
	weight		= 500,
	extended	= true
} )

NOTIFY_GENERIC	= 0
NOTIFY_ERROR	= 1
NOTIFY_UNDO		= 2
NOTIFY_HINT		= 3
NOTIFY_CLEANUP	= 4

notification = notification or {}

-- GMod: NoticeMaterial[ type ] = Material( "vgui/notices/<name>" ).  Texture ids
-- here (see the header).  materials/vgui/notices/*.vmt ship with this mod.
local NOTICE_ICONS = {
	[ NOTIFY_GENERIC ]	= "vgui/notices/generic",
	[ NOTIFY_ERROR ]	= "vgui/notices/error",
	[ NOTIFY_UNDO ]		= "vgui/notices/undo",
	[ NOTIFY_HINT ]		= "vgui/notices/hint",
	[ NOTIFY_CLEANUP ]	= "vgui/notices/cleanup",
}

local IconIDs = {}

local function GetIconID( iType )
	local strPath = NOTICE_ICONS[ iType ] or NOTICE_ICONS[ NOTIFY_GENERIC ]

	if ( IconIDs[ strPath ] == nil ) then
		IconIDs[ strPath ] = ( surface.GetTextureID and surface.GetTextureID( strPath ) ) or false
	end

	return IconIDs[ strPath ] or nil
end

--- Draw a notice icon.  surface.DrawTexturedRect is the GMod ( x, y, w, h ) shim
--- from gmod_surface.lua; the corner form is what the engine binding itself
--- guarantees, so prefer it when the shim kept it around.
---
--- ⚠️ The draw colour is set here on purpose.  Textured draws use the CURRENT
--- DrawSetColor, so an icon drawn after a skin hook that left a transparent
--- colour behind comes out invisible -- measured 2026-09-15: the notice body and
--- the icon disappeared together for exactly that reason (the caption survived
--- only because derma.DrawText sets its own colour).
local function DrawIcon( id, x, y, wide, tall )
	if ( surface.DrawSetColor ) then surface.DrawSetColor( 255, 255, 255, 255 ) end
	if ( surface.SetTexture ) then surface.SetTexture( id ) end

	local fnCorner = surface.__hl2sb_cornerRect
	if ( fnCorner ) then
		fnCorner( x, y, x + wide, y + tall )
	else
		surface.DrawTexturedRect( x, y, wide, tall )
	end
end

local NOTIF_START_X		= 200		-- pixels
local NOTIF_CHARGE_X	= 0.04		-- percent of screen size
local NOTIF_GAP_X		= 0.015
local NOTIF_ANCHOR_Y	= 0.8

local Notices = {}

local hookAdd = ( hook and ( hook.Add or hook.add ) ) or function() end

-- TODO(remove): off unless hl2sb_hud_debug is on; one line per notice.
local function NoticeDebug( ... )
	if ( GetConVarNumber and GetConVarNumber( "hl2sb_hud_debug" ) ~= 0 ) then
		Msg( "[HL2SB] notice: " .. table.concat( { ... }, " " ) .. "\n" )
	end
end

--[[---------------------------------------------------------------------------
	NoticePanel -- GMod's notice: icon + white text on a dark translucent box.
---------------------------------------------------------------------------]]
local PANEL = {}

function PANEL:Init()
	self.m_iType = NOTIFY_GENERIC
	self.m_strText = ""
	self.m_bProgress = false
	self.m_flProgress = 0

	-- GMod: self:SetBackgroundColor( Color( 20, 20, 20, 255 * 0.6 ) ).
	--
	-- ⚠️ Measured 2026-09-15: the engine's SetBgColor does not survive here --
	-- GetBgColor() comes back fully transparent -- and since the notice body is
	-- painted from this colour (and the icon inherits the current draw colour),
	-- a transparent body took the icon with it.  The colour is therefore owned by
	-- the panel (m_colBody, read by SKIN:PaintNotify); SetBgColor is still called
	-- for GMod parity, but nothing depends on it.
	self.m_colBody = Color( 20, 20, 20, 255 * 0.6 )
	if ( self.SetBgColor ) then pcall( self.SetBgColor, self, self.m_colBody ) end

	self:SizeToContents()
end

function PANEL:SetText( strText )
	self.m_strText = tostring( strText or "" )
	self:SizeToContents()
end

function PANEL:GetText()
	return self.m_strText or ""
end

function PANEL:SetLegacyType( iType )
	self.m_iType = iType or NOTIFY_GENERIC
	self:SizeToContents()
end

-- our framework's spelling, kept alongside GMod's
PANEL.SetType = PANEL.SetLegacyType

function PANEL:SetProgress( frac )
	self.m_bProgress = true
	self.m_flProgress = math.Clamp( frac or 0, 0, 1 )
	self:SizeToContents()
end

--- GMod's SizeToContents: the text plus its padding, widened by the icon and
--- its gaps, and 10px taller when a progress bar is present.
function PANEL:SizeToContents()
	local textW, textTall = derma.GetTextSize( "GModNotify", self.m_strText or "" )

	local iconGap = math.ceil( iconH * 0.1 )

	local tall = textTall + math.ceil( textH * 0.25 )
	local wide = textW + math.ceil( textH * 0.75 )

	wide = wide + iconH + ( iconGap * 2 )
	tall = math.max( tall, iconH + ( iconGap * 2 ) )

	if ( self.m_bProgress ) then tall = tall + 10 end

	-- our own padding (GMod: DockPadding 3 + the label's dock margins)
	self:SetSize( wide + 6, tall + 6 )

	self.m_iIconGap = iconGap
	self:InvalidateLayout( true )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	-- body: the skin paints the flat translucent dark box GMod uses
	derma.SkinHook( "Paint", "Notify", self, w, h )

	local iconGap = self.m_iIconGap or 3
	local iconY = math.floor( ( h - iconH ) / 2 )

	local id = GetIconID( self.m_iType )
	if ( id ) then
		DrawIcon( id, 3 + iconGap, iconY, iconH, iconH )
	end

	-- caption.  GMod uses a DLabel with SetExpensiveShadow( 1, Color(0,0,0,200) );
	-- this fork's DLabel draws in Lua with no shadow binding, so the shadow is
	-- the same text one pixel down-right.
	local textX = 3 + iconH + ( iconGap * 2 )
	local _, textTall = derma.GetTextSize( "GModNotify", self.m_strText or "" )
	local textY = math.floor( ( h - textTall ) / 2 )

	derma.DrawText( "GModNotify", textX + 1, textY + 1, self.m_strText or "", Color( 0, 0, 0, 200 ) )
	derma.DrawText( "GModNotify", textX, textY, self.m_strText or "", Color( 255, 255, 255, 255 ) )

	if ( not self.m_bProgress ) then return end

	-- GMod's progress bar geometry
	local boxX, boxY = 10, h - 13
	local boxW, boxH = w - 20, 5
	local boxInnerW = boxW - 2

	surface.DrawSetColor( 0, 100, 0, 150 )
	surface.DrawFilledRect( boxX, boxY, boxX + boxW, boxY + boxH )

	surface.DrawSetColor( 0, 50, 0, 255 )
	surface.DrawFilledRect( boxX + 1, boxY + 1, boxX + boxW - 1, boxY + boxH - 1 )

	local barW = math.ceil( boxInnerW * 0.25 )
	local x = math.fmod( math.floor( ( SysTime and SysTime() or CurTime() ) * 200 ), boxInnerW + barW ) - barW

	if ( self.m_flProgress and self.m_flProgress > 0 ) then
		x = 0
		barW = math.ceil( boxInnerW * self.m_flProgress )
	end

	if ( ( x + barW ) > boxInnerW ) then barW = math.ceil( boxInnerW - x ) end
	if ( x < 0 ) then barW = barW + x; x = 0 end

	surface.DrawSetColor( 0, 255, 0, 255 )
	surface.DrawFilledRect( boxX + 1 + x, boxY + 1, boxX + 1 + x + barW, boxY + boxH - 1 )
end

function PANEL:KillSelf()
	-- infinite length (progress notices)
	if ( self.Length == nil or self.Length < 0 ) then return false end

	if ( ( self.StartTime + self.Length ) < ( SysTime and SysTime() or CurTime() ) ) then
		self:Remove()
		return true
	end

	return false
end

vgui.Register( "NoticePanel", PANEL, "DPanel" )

--[[---------------------------------------------------------------------------
	GMod's UpdateNotice -- the spring, the wind-up and the exit.

	"Cartoon style about to go thing": with < 0.7s left the target pulls LEFT by
	4% of the screen; with < 0.2s left it jumps RIGHT by twice the panel width.
	The spring below does the actual movement, so the panel visibly charges
	outward, then whips off the right edge.
---------------------------------------------------------------------------]]
local function UpdateNotice( pnl, totalH )
	local x, y = pnl.fx, pnl.fy
	local w = pnl:GetWide()
	local h = pnl:GetTall() + math.ceil( textH * 0.2 )

	local flNow = SysTime and SysTime() or CurTime()

	local idealY = ScrH() * NOTIF_ANCHOR_Y - h - totalH
	local idealX = ScrW() - w - ( ScrW() * NOTIF_GAP_X )

	local timeleft = pnl.StartTime - ( flNow - pnl.Length )
	if ( pnl.Length < 0 ) then timeleft = 1 end

	-- about to go
	if ( timeleft < 0.7 ) then
		idealX = idealX - ( ScrW() * NOTIF_CHARGE_X )
	end

	-- gone
	if ( timeleft < 0.2 ) then
		idealX = idealX + ( w * 2 )
	end

	local spd = ( RealFrameTime and RealFrameTime() or FrameTime() ) * 15

	y = y + pnl.VelY * spd
	x = x + pnl.VelX * spd

	local dist = idealY - y
	pnl.VelY = pnl.VelY + dist * spd
	if ( math.abs( dist ) < 2 and math.abs( pnl.VelY ) < 0.1 ) then pnl.VelY = 0 end

	dist = idealX - x
	pnl.VelX = pnl.VelX + dist * spd
	if ( math.abs( dist ) < 2 and math.abs( pnl.VelX ) < 0.1 ) then pnl.VelX = 0 end

	-- friction, roughly frame-independent (GMod's numbers)
	local flFrame = RealFrameTime and RealFrameTime() or FrameTime()
	pnl.VelX = pnl.VelX * ( 0.95 - flFrame * 8 )
	pnl.VelY = pnl.VelY * ( 0.95 - flFrame * 8 )

	pnl.fx = x
	pnl.fy = y

	-- panels parked far above the screen are left alone: updating them lags
	if ( idealY > -ScrH() ) then
		pnl:SetPos( math.floor( pnl.fx ), math.floor( pnl.fy ) )
	end

	return totalH + h
end

hookAdd( "Think", "hl2sb_notification", function()
	local totalH = 0

	for _, pnl in pairs( Notices ) do
		if ( IsValid( pnl ) ) then
			totalH = UpdateNotice( pnl, totalH )
		end
	end

	for k, pnl in pairs( Notices ) do
		if ( not IsValid( pnl ) or pnl:KillSelf() ) then
			Notices[ k ] = nil
		end
	end
end )

--[[---------------------------------------------------------------------------
	Public API -- GMod's shape, including the starting velocities.
---------------------------------------------------------------------------]]

local function NewNotice( iType, strText )
	local parent = nil
	if ( GetOverlayPanel ) then parent = GetOverlayPanel() end

	local pnl = vgui.Create( "NoticePanel", parent )
	pnl.StartTime = SysTime and SysTime() or CurTime()
	pnl.VelX = -5
	pnl.VelY = 0
	pnl.fx = ScrW() + NOTIF_START_X
	pnl.fy = ScrH()
	if ( pnl.SetAlpha ) then pnl:SetAlpha( 255 ) end
	pnl:SetText( strText )
	pnl:SetLegacyType( iType or NOTIFY_GENERIC )
	pnl:SetPos( pnl.fx, pnl.fy )

	NoticeDebug( "type=" .. tostring( iType ), "text=[" .. tostring( strText ) .. "]",
		"size=" .. tostring( pnl:GetWide() ) .. "x" .. tostring( pnl:GetTall() ),
		"textH=" .. tostring( textH ), "iconH=" .. tostring( iconH ),
		"icon=" .. tostring( GetIconID( iType or NOTIFY_GENERIC ) ),
		"cornerRect=" .. tostring( surface.__hl2sb_cornerRect ~= nil ),
		"getTexID=" .. tostring( surface.GetTextureID ~= nil ) )

	return pnl
end

function notification.AddProgress( uid, strText, frac )
	if ( IsValid( Notices[ uid ] ) ) then
		Notices[ uid ].StartTime = SysTime and SysTime() or CurTime()
		Notices[ uid ].Length = -1
		Notices[ uid ]:SetText( strText )
		Notices[ uid ]:SetProgress( frac )
		return
	end

	local pnl = NewNotice( NOTIFY_GENERIC, strText )
	pnl.Length = -1
	pnl:SetProgress( frac )

	Notices[ uid ] = pnl
end

function notification.Kill( uid )
	if ( not IsValid( Notices[ uid ] ) ) then return end

	Notices[ uid ].StartTime = SysTime and SysTime() or CurTime()
	Notices[ uid ].Length = 0.8
	Notices[ uid ] = nil			-- GMod drops the reference too
end

function notification.AddLegacy( strText, iType, iLength )
	local pnl = NewNotice( iType, strText )
	pnl.Length = math.max( iLength or 5, 0 )

	table.insert( Notices, pnl )
	return pnl
end

--- GMod's Notify( text, type, length ) global forwards to the legacy path.
if ( not Notify ) then
	function Notify( strText, iType, iLength )
		notification.AddLegacy( strText, iType or NOTIFY_GENERIC, iLength or 5 )
	end
end
