--[[ DBubbleContainer -- a rounded container with a speech-bubble tail (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DBubbleContainer
	  (no standalone description on the page index; the control is GMod's
	  lua/vgui/dbubblecontainer.lua, and the wiki documents its
	  DBubbleContainer:SetBackgroundColor inherited accessor.)
	  Parent: DPanel.  Members: OpenForPos( x, y, w, h ), the m_bgColor field.

	Ported from GMod's lua/vgui/dbubblecontainer.lua (49 lines).

	Deliberate deviations:
	  * GMod tail: surface.SetMaterial( self.matPoint ) +
	    surface.DrawTexturedRect(...).  `gui/point.png` ships inside GMod's own
	    content VPK, which this fork mounts (gameinfo.txt, "game+mod ...
	    garrysmod/garrysmod_*.vpk"), so the material is used when it can be loaded;
	    if it cannot, the same 64x32 triangle is drawn with plain rectangles so the
	    bubble never loses its tail.
	  * SetMaterial is called BEFORE SetDrawColor: this fork's
	    surface.SetMaterial binds the texture through DrawSetTextureFile, and the
	    draw colour has to be set after that to modulate it (the same ordering
	    mistake that made draw.RoundedBox come out white, AGENTS.md 5.4).
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_bgColor", "BackgroundColor" )

function PANEL:Init()
	self.matPoint = Material( "gui/point.png" )
	self:DockPadding( 0, 0, 0, 32 )
	self:SetBackgroundColor( Color( 190, 190, 190, 230 ) )
end

function PANEL:OpenForPos( x, y, w, h )
	local center = x

	x = x - w * 0.5
	if ( x < 10 ) then x = 10 end

	y = y - h - 64
	if ( y < 10 ) then y = 10 end

	self:SetPos( x, y )
	self:SetSize( w, h )

	self.Center = center - x
end

function PANEL:PerformLayout()
end

--- The fallback tail: a 64x32 triangle pointing down, from the tip position.
local function DrawTail( x, top, w, h )
	for i = 0, h - 1 do
		-- widest at the top, converging to a point at the bottom
		local half = math.floor( ( w * 0.5 ) * ( 1 - i / h ) )
		if ( half > 0 ) then
			surface.DrawRect( x + ( w * 0.5 ) - half, top + i, half * 2, 1 )
		end
	end
end

function PANEL:Paint( w, h )
	local top = h - 32
	draw.RoundedBox( 8, 0, 0, w, top, self.m_bgColor )

	local center = self.Center or ( w * 0.5 )
	local tipx = center - 32
	if ( tipx < 8 ) then tipx = 8 end
	if ( tipx > w - 64 - 8 ) then tipx = w - 64 - 8 end

	local col = self.m_bgColor

	if ( self.matPoint and surface.SetMaterial ) then
		surface.SetMaterial( self.matPoint )
		surface.SetDrawColor( col.r, col.g, col.b, col.a )
		surface.DrawTexturedRect( center - 32, top, 64, 32 )
	else
		surface.SetDrawColor( col.r, col.g, col.b, col.a )
		DrawTail( tipx, top, 64, 32 )
	end
end

derma.DefineControl( "DBubbleContainer", "A speech-bubble container", PANEL, "DPanel" )
