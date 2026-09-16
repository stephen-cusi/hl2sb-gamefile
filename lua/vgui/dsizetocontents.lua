--[[ DSizeToContents -- a panel that resizes itself to its children.

	"A helper panel that will automatically resize itself to fit all its children
	using Panel:SizeToChildren."
		https://wiki.facepunch.com/gmod/DSizeToContents

	The engine half already exists here: Panel:SizeToChildren( sizeWide, sizeTall ) is
	bound in public/lua/vgui_controls/lPanel.cpp:1619, and the fork's vgui_controls
	implementation lays the children out depth-first before measuring them
	(public/vgui_controls/Panel.h:758 - SizeToChildren( bool, bool )).

	Wiki methods: SetSizeX( b ) / GetSizeX() / SetSizeY( b ) / GetSizeY().
--]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )

	-- GMod's control sizes to contents in BOTH directions unless told otherwise.
	self.m_bSizeX = true
	self.m_bSizeY = true
end

function PANEL:SetSizeX( b )
	self.m_bSizeX = ( b ~= false )
	self:InvalidateLayout( true )
end

function PANEL:GetSizeX()
	return self.m_bSizeX
end

function PANEL:SetSizeY( b )
	self.m_bSizeY = ( b ~= false )
	self:InvalidateLayout( true )
end

function PANEL:GetSizeY()
	return self.m_bSizeY
end

function PANEL:PerformLayout( w, h )
	if ( self.m_bSizeX or self.m_bSizeY ) then
		self:SizeToChildren( self.m_bSizeX, self.m_bSizeY )
	end
end

derma.DefineControl( "DSizeToContents", "HL2SB size-to-contents panel", PANEL, "DPanel" )
