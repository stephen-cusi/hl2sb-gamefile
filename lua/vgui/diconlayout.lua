--[[ DIconLayout -- automatic icon grid (original implementation).

	GMod's container for icon lists: children are placed left to right, wrapped into
	rows, with SetSpaceX/SetSpaceY between them and SetBorder around the edge.  This is
	what the spawnmenu's grid is built on, and using it means the menu never has to
	compute a cell's position itself.

	Wiki contract: https://wiki.facepunch.com/gmod/DIconLayout
		SetSpaceX / GetSpaceX / SetSpaceY / GetSpaceY
		SetBorder / GetBorder
		SetLayoutDir / GetLayoutDir        (TOP lays rows down, LEFT fills columns)
		SetStretchWidth / GetStretchWidth  (children stretched to the layout's width)
		SetStretchHeight / GetStretchHeight
		Layout()                           (force a re-layout)

	Layout runs through PerformLayout, which the scripted panel dispatches
	(scripted_controls/lPanel.cpp: the engine's hook names are Paint, PerformLayout,
	OnThink, OnMouse*, ...).  Children are read through Panel:GetChildren(), which
	returns a 1-based table (public/lua/vgui_controls/lPanel.cpp, Panel_GetChildren).
--]]

local PANEL = {}

-- GMod's LAYOUT_TOP / LAYOUT_LEFT
LAYOUT_TOP = LAYOUT_TOP or 1
LAYOUT_LEFT = LAYOUT_LEFT or 2

function PANEL:Init()
	self:SetDrawBackground( false )

	self.m_iSpaceX = 0
	self.m_iSpaceY = 0
	self.m_iBorder = 0
	self.m_iLayoutDir = LAYOUT_TOP
	self.m_bStretchWidth = false
	self.m_bStretchHeight = false
end

function PANEL:SetSpaceX( n ) self.m_iSpaceX = math.max( 0, math.floor( n or 0 ) ) end
function PANEL:GetSpaceX() return self.m_iSpaceX end

function PANEL:SetSpaceY( n ) self.m_iSpaceY = math.max( 0, math.floor( n or 0 ) ) end
function PANEL:GetSpaceY() return self.m_iSpaceY end

function PANEL:SetBorder( n ) self.m_iBorder = math.max( 0, math.floor( n or 0 ) ) end
function PANEL:GetBorder() return self.m_iBorder end

function PANEL:SetLayoutDir( n )
	self.m_iLayoutDir = ( n == LAYOUT_LEFT ) and LAYOUT_LEFT or LAYOUT_TOP
end

function PANEL:GetLayoutDir() return self.m_iLayoutDir end

function PANEL:SetStretchWidth( b ) self.m_bStretchWidth = ( b == true ) end
function PANEL:GetStretchWidth() return self.m_bStretchWidth end

function PANEL:SetStretchHeight( b ) self.m_bStretchHeight = ( b == true ) end
function PANEL:GetStretchHeight() return self.m_bStretchHeight end

--- GMod's Add: child + re-layout.
function PANEL:Add( pnl )
	pnl:SetParent( self )
	self:InvalidateLayout( true )
	return pnl
end

function PANEL:Layout()
	self:InvalidateLayout( true )
end

--- GMod's OnModified runs after a child was added/changed.
function PANEL:OnModified()
	self:InvalidateLayout( true )
end

local function LayoutTop( self, w, h )
	local border, sx, sy = self.m_iBorder, self.m_iSpaceX, self.m_iSpaceY

	local x, y = border, border
	local rowTall = 0
	local availW = math.max( 1, w - border )

	for _, child in ipairs( self:GetChildren() ) do
		local cw, ch = child:GetSize()

		if ( x > border and x + cw > availW ) then
			x = border
			y = y + rowTall + sy
			rowTall = 0
		end

		child:SetPos( x, y )
		x = x + cw + sx

		if ( ch > rowTall ) then rowTall = ch end
	end
end

local function LayoutLeft( self, w, h )
	local border, sx, sy = self.m_iBorder, self.m_iSpaceX, self.m_iSpaceY

	local x, y = border, border
	local colWide = 0
	local availH = math.max( 1, h - border )

	for _, child in ipairs( self:GetChildren() ) do
		local cw, ch = child:GetSize()

		if ( y > border and y + ch > availH ) then
			y = border
			x = x + colWide + sx
			colWide = 0
		end

		child:SetPos( x, y )
		y = y + ch + sy

		if ( cw > colWide ) then colWide = cw end
	end
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( self.m_bStretchWidth ) then
		for _, child in ipairs( self:GetChildren() ) do
			local _, ch = child:GetSize()
			child:SetSize( math.max( 1, w - 2 * self.m_iBorder ), ch )
		end
	end

	if ( self.m_bStretchHeight ) then
		for _, child in ipairs( self:GetChildren() ) do
			local cw = child:GetWide()
			child:SetSize( cw, math.max( 1, h - 2 * self.m_iBorder ) )
		end
	end

	if ( self.m_iLayoutDir == LAYOUT_LEFT ) then
		LayoutLeft( self, w, h )
	else
		LayoutTop( self, w, h )
	end
end

derma.DefineControl( "DIconLayout", "HL2SB automatic icon grid", PANEL, "DPanel" )
