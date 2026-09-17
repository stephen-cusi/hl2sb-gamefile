--[[ DVerticalDivider -- a draggable horizontal divider between two panels (original).

	Wiki: https://wiki.facepunch.com/gmod/DVerticalDivider
	  "Vertical version of DHorizontalDivider."  Parent: DPanel.

	  SetTop / GetTop / SetBottom / GetBottom / SetMiddle / GetMiddle
	  SetTopHeight / GetTopHeight / SetTopMin / GetTopMin / SetTopMax / GetTopMax
	  SetBottomMin / GetBottomMin
	  SetDividerHeight / GetDividerHeight
	  SetDragging / GetDragging / SetHoldPos / GetHoldPos / DoConstraints / StartGrab

	Layout: the top panel gets `topHeight` starting at y = 0, the optional middle sits
	ON the bar, and the bottom panel takes what is left - so `SetTopHeight` is the only
	height a caller has to set (the bottom is derived, exactly as the wiki describes).

	⚠️ Same drag caveat as DHorizontalDivider: this fork dispatches OnCursorMoved /
	OnMousePressed / OnMouseReleased, not GMod's OnMouseDragged, so the movement is
	applied from OnCursorMoved and from the per-frame OnThink while held.
--]]

local PANEL = {}

function PANEL:Init()
	self.m_iDividerHeight = 8
	self.m_iTopHeight = 0
	self.m_iTopMin = 0
	self.m_iTopMax = 0			-- 0 = no maximum
	self.m_iBottomMin = 0

	self.m_bDragging = false
	self.m_iHoldPos = 0

	self:SetMouseInputEnabled( true )

	-- GMod's drag handle (dverticaldivider.lua:2-19); see the note in
	-- lua/vgui/DHorizontalDividerBar.lua.
	self.m_pBar = vgui.Create( "DVerticalDividerBar", self )

	if ( self.SetDrawBackground ) then self:SetDrawBackground( false ) end
end

-------------------------------------------------------------------------------
-- content panels
-------------------------------------------------------------------------------
local function Adopt( self, key, pnl )
	local old = self[ key ]

	if ( IsValid( old ) and old ~= pnl ) then old:SetVisible( false ) end

	self[ key ] = pnl

	if ( IsValid( pnl ) ) then
		pnl:SetParent( self )
		pnl:SetVisible( true )
	end

	self:InvalidateLayout( true )
end

function PANEL:SetTop( pnl )		Adopt( self, "m_pTop", pnl ) end
function PANEL:SetBottom( pnl )		Adopt( self, "m_pBottom", pnl ) end
function PANEL:SetMiddle( pnl )		Adopt( self, "m_pMiddle", pnl ) end

function PANEL:GetTop()			return self.m_pTop end
function PANEL:GetBottom()		return self.m_pBottom end
function PANEL:GetMiddle()		return self.m_pMiddle end

-------------------------------------------------------------------------------
-- metrics
-------------------------------------------------------------------------------
function PANEL:SetDividerHeight( h )
	h = math.floor( tonumber( h ) or 0 )
	if ( h < 0 ) then h = 0 end

	self.m_iDividerHeight = h
	self:InvalidateLayout( true )
end

function PANEL:GetDividerHeight()
	return self.m_iDividerHeight
end

function PANEL:SetTopMin( h )
	self.m_iTopMin = math.max( 0, math.floor( tonumber( h ) or 0 ) )
	self:InvalidateLayout( true )
end

function PANEL:GetTopMin()
	return self.m_iTopMin
end

function PANEL:SetTopMax( h )
	self.m_iTopMax = math.max( 0, math.floor( tonumber( h ) or 0 ) )
	self:InvalidateLayout( true )
end

function PANEL:GetTopMax()
	return self.m_iTopMax
end

function PANEL:SetBottomMin( h )
	self.m_iBottomMin = math.max( 0, math.floor( tonumber( h ) or 0 ) )
	self:InvalidateLayout( true )
end

function PANEL:GetBottomMin()
	return self.m_iBottomMin
end

function PANEL:SetTopHeight( h )
	self.m_iTopHeight = math.floor( tonumber( h ) or 0 )
	self:InvalidateLayout( true )
end

function PANEL:GetTopHeight()
	return self.m_iTopHeight
end

function PANEL:SetDragging( b )	self.m_bDragging = b and true or false end
function PANEL:GetDragging()	return self.m_bDragging end

function PANEL:SetHoldPos( y )	self.m_iHoldPos = y end
function PANEL:GetHoldPos()	return self.m_iHoldPos end

-------------------------------------------------------------------------------
-- layout
-------------------------------------------------------------------------------
--- Wiki: "Used internally to clamp the vertical divider to GetTopMin and
--- GetBottomMin."  (The maximum is honoured too - it is ignored when it would push the
--- bottom panel under its own minimum, which is what the wiki says about SetTopMax.)
function PANEL:DoConstraints()
	local h = self:GetTall()
	local divH = self.m_iDividerHeight

	local topH = self.m_iTopHeight
	local bottomH = h - divH - topH

	if ( topH < self.m_iTopMin ) then
		topH = self.m_iTopMin
		bottomH = h - divH - topH
	end

	if ( self.m_iTopMax > 0 and topH > self.m_iTopMax and
		( h - divH - self.m_iTopMax ) >= self.m_iBottomMin ) then
		topH = self.m_iTopMax
		bottomH = h - divH - topH
	end

	if ( bottomH < self.m_iBottomMin ) then
		bottomH = self.m_iBottomMin
		topH = h - divH - bottomH
	end

	if ( topH < 0 ) then topH = 0 end
	if ( bottomH < 0 ) then bottomH = 0 end

	self.m_iTopHeight = topH

	return topH, bottomH
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local topH, bottomH = self:DoConstraints()
	local divH = self.m_iDividerHeight

	if ( IsValid( self.m_pTop ) ) then
		self.m_pTop:SetPos( 0, 0 )
		self.m_pTop:SetSize( w, topH )
	end

	if ( IsValid( self.m_pMiddle ) ) then
		self.m_pMiddle:SetPos( 0, topH )
		self.m_pMiddle:SetSize( w, divH )
	end

	if ( IsValid( self.m_pBar ) ) then
		self.m_pBar:SetPos( 0, topH )
		self.m_pBar:SetSize( w, divH )
	end

	if ( IsValid( self.m_pBottom ) ) then
		self.m_pBottom:SetPos( 0, topH + divH )
		self.m_pBottom:SetSize( w, bottomH )
	end
end

-------------------------------------------------------------------------------
-- dragging
-------------------------------------------------------------------------------
function PANEL:LocalMouseY()
	local _, y = self:ScreenToLocal( gui.MouseX(), gui.MouseY() )
	return y or 0
end

function PANEL:IsOverBar( y )
	return y >= self.m_iTopHeight and y <= self.m_iTopHeight + self.m_iDividerHeight
end

--- Wiki: "Causes the user to start dragging the divider."
function PANEL:StartGrab()
	self.m_bDragging = true
	self.m_iHoldPos = self:LocalMouseY() - self.m_iTopHeight
	self:MouseCapture( true )
end

function PANEL:StopGrab()
	self.m_bDragging = false
	self:MouseCapture( false )
end

function PANEL:OnMouseDragged()
end

function PANEL:ApplyDrag()
	if ( not self.m_bDragging ) then return end

	local h = self:GetTall()
	local y = self:LocalMouseY()

	local topH = y - self.m_iHoldPos

	local maxTop = h - self.m_iDividerHeight - self.m_iBottomMin
	if ( topH < self.m_iTopMin ) then topH = self.m_iTopMin end
	if ( topH > maxTop ) then topH = maxTop end
	if ( self.m_iTopMax > 0 and topH > self.m_iTopMax and
		( h - self.m_iDividerHeight - self.m_iTopMax ) >= self.m_iBottomMin ) then
		topH = self.m_iTopMax
	end

	if ( topH ~= self.m_iTopHeight ) then
		self.m_iTopHeight = topH
		self:InvalidateLayout( true )
	end
end

function PANEL:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end
	if ( not self:IsOverBar( self:LocalMouseY() ) ) then return end

	self:StartGrab()
end

function PANEL:OnMouseReleased( code )
	if ( self.m_bDragging ) then self:StopGrab() end
end

function PANEL:OnMouseCaptureLost()
	self.m_bDragging = false
end

function PANEL:OnCursorMoved( x, y )
	if ( self.m_bDragging ) then
		self:ApplyDrag()
		self:OnMouseDragged()
	elseif ( self:IsOverBar( self:LocalMouseY() ) ) then
		self:SetCursor( "sizens" )
	else
		self:SetCursor( "arrow" )
	end
end

function PANEL:OnCursorExited()
	if ( not self.m_bDragging ) then self:SetCursor( "arrow" ) end
end

function PANEL:OnThink()
	if ( self.m_bDragging ) then
		self:ApplyDrag()
		self:OnMouseDragged()
	end
end

derma.DefineControl( "DVerticalDivider", "A draggable horizontal divider", PANEL, "DPanel" )
