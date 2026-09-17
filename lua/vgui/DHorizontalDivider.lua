--[[ DHorizontalDivider -- a draggable vertical divider between two panels (original).

	Wiki: https://wiki.facepunch.com/gmod/DHorizontalDivider
	  "Creates an invisible vertical divider between two GUI elements."
	  Parent: DPanel.

	  SetLeft / GetLeft / SetRight / GetRight / SetMiddle / GetMiddle
	  SetLeftWidth / GetLeftWidth          -- the left side's current width
	  SetLeftMin / GetLeftMin              -- minimum width of the left side
	  SetRightMin / GetRightMin            -- minimum width of the right side
	  SetDividerWidth / GetDividerWidth    -- width of the bar (default 8)
	  SetDragging / GetDragging / SetHoldPos / GetHoldPos / StartGrab   (internal)

	Layout (GMod's vgui/dhorizontaldivider.lua): the left panel is
	`leftWidth x h` at (0,0), the right panel is everything after the bar, and the
	optional middle panel sits ON TOP of the bar - which is why the middle is the place
	to put a grip/grip texture.

	⚠️ This fork has no `OnMouseDragged` panel dispatch (checked: the scripted LPanel
	dispatches OnCursorMoved / OnMousePressed / OnMouseReleased / OnMouseWheeled only),
	so the drag is driven by OnCursorMoved plus a per-frame OnThink while the bar is
	held.  `OnMouseDragged` is still defined - addons override it the GMod way and it
	runs - it just is not the thing that moves the divider.
--]]

local PANEL = {}

function PANEL:Init()
	self.m_iDividerWidth = 8
	self.m_iLeftWidth = 0
	self.m_iLeftMin = 0
	self.m_iRightMin = 0

	self.m_bDragging = false
	self.m_iHoldPos = 0

	-- the whole area takes the mouse so the bar can be grabbed anywhere along it
	self:SetMouseInputEnabled( true )

	-- GMod puts the drag handle in its own child (dhorizontaldivider.lua:2-19): the
	-- bar takes the press (a child is hit-tested before its parent) and calls
	-- StartGrab here.  This fork's own OnMousePressed/IsOverBar path below stays as
	-- the fallback for a grab that starts outside the bar.
	self.m_pBar = vgui.Create( "DHorizontalDividerBar", self )

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

function PANEL:SetLeft( pnl )	Adopt( self, "m_pLeft", pnl ) end
function PANEL:SetRight( pnl )	Adopt( self, "m_pRight", pnl ) end
function PANEL:SetMiddle( pnl )	Adopt( self, "m_pMiddle", pnl ) end

function PANEL:GetLeft()	return self.m_pLeft end
function PANEL:GetRight()	return self.m_pRight end
function PANEL:GetMiddle()	return self.m_pMiddle end

-------------------------------------------------------------------------------
-- metrics
-------------------------------------------------------------------------------
function PANEL:SetDividerWidth( w )
	w = math.floor( tonumber( w ) or 0 )
	if ( w < 0 ) then w = 0 end

	self.m_iDividerWidth = w
	self:InvalidateLayout( true )
end

function PANEL:GetDividerWidth()
	return self.m_iDividerWidth
end

function PANEL:SetLeftMin( w )
	self.m_iLeftMin = math.max( 0, math.floor( tonumber( w ) or 0 ) )
	self:InvalidateLayout( true )
end

function PANEL:GetLeftMin()
	return self.m_iLeftMin
end

function PANEL:SetRightMin( w )
	self.m_iRightMin = math.max( 0, math.floor( tonumber( w ) or 0 ) )
	self:InvalidateLayout( true )
end

function PANEL:GetRightMin()
	return self.m_iRightMin
end

function PANEL:SetLeftWidth( w )
	self.m_iLeftWidth = math.floor( tonumber( w ) or 0 )
	self:InvalidateLayout( true )
end

function PANEL:GetLeftWidth()
	return self.m_iLeftWidth
end

function PANEL:SetDragging( b )	self.m_bDragging = b and true or false end
function PANEL:GetDragging()	return self.m_bDragging end

function PANEL:SetHoldPos( x )	self.m_iHoldPos = x end
function PANEL:GetHoldPos()	return self.m_iHoldPos end

-------------------------------------------------------------------------------
-- layout
-------------------------------------------------------------------------------
--- Clamp the requested left width against both minimums.  Returns leftW, rightW.
function PANEL:GetClampedWidths()
	local w = self:GetWide()

	local leftW = self.m_iLeftWidth
	local divW = self.m_iDividerWidth
	local rightW = w - divW - leftW

	if ( leftW < self.m_iLeftMin ) then
		leftW = self.m_iLeftMin
		rightW = w - divW - leftW
	end

	if ( rightW < self.m_iRightMin ) then
		rightW = self.m_iRightMin
		leftW = w - divW - rightW
	end

	-- a divider narrower than the two minimums cannot satisfy both: the left side wins
	if ( leftW < 0 ) then leftW = 0 end
	if ( rightW < 0 ) then rightW = 0 end

	self.m_iLeftWidth = leftW

	return leftW, rightW
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local leftW, rightW = self:GetClampedWidths()
	local divW = self.m_iDividerWidth

	if ( IsValid( self.m_pLeft ) ) then
		self.m_pLeft:SetPos( 0, 0 )
		self.m_pLeft:SetSize( leftW, h )
	end

	if ( IsValid( self.m_pRight ) ) then
		self.m_pRight:SetPos( leftW + divW, 0 )
		self.m_pRight:SetSize( rightW, h )
	end

	if ( IsValid( self.m_pMiddle ) ) then
		self.m_pMiddle:SetPos( leftW, 0 )
		self.m_pMiddle:SetSize( divW, h )
	end

	if ( IsValid( self.m_pBar ) ) then
		self.m_pBar:SetPos( leftW, 0 )
		self.m_pBar:SetSize( divW, h )
	end
end

-------------------------------------------------------------------------------
-- dragging
-------------------------------------------------------------------------------
--- local x of the cursor
function PANEL:LocalMouseX()
	local x = self:ScreenToLocal( gui.MouseX(), gui.MouseY() )
	return x or 0
end

function PANEL:IsOverBar( x )
	return x >= self.m_iLeftWidth and x <= self.m_iLeftWidth + self.m_iDividerWidth
end

--- Wiki: "Causes the user to start dragging the divider."
function PANEL:StartGrab()
	self.m_bDragging = true
	self.m_iHoldPos = self:LocalMouseX() - self.m_iLeftWidth
	self:MouseCapture( true )
end

function PANEL:StopGrab()
	self.m_bDragging = false
	self:MouseCapture( false )
end

--- GMod's drag callback.  Kept because addons hook it; the movement itself is
--- applied by ApplyDrag() below (this fork has no OnMouseDragged dispatch).
function PANEL:OnMouseDragged()
end

function PANEL:ApplyDrag()
	if ( not self.m_bDragging ) then return end

	local w = self:GetWide()
	local x = self:LocalMouseX()

	local leftW = x - self.m_iHoldPos

	-- constraints, same rule as the layout so the bar cannot be dragged past a minimum
	local maxLeft = w - self.m_iDividerWidth - self.m_iRightMin
	if ( leftW < self.m_iLeftMin ) then leftW = self.m_iLeftMin end
	if ( leftW > maxLeft ) then leftW = maxLeft end

	if ( leftW ~= self.m_iLeftWidth ) then
		self.m_iLeftWidth = leftW
		self:InvalidateLayout( true )
	end
end

function PANEL:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end
	if ( not self:IsOverBar( self:LocalMouseX() ) ) then return end

	self:StartGrab()
end

function PANEL:OnMouseReleased( code )
	if ( self.m_bDragging ) then self:StopGrab() end
end

function PANEL:OnMouseCaptureLost()
	self.m_bDragging = false
end

function PANEL:OnCursorMoved( x, y )
	-- cursor feedback for the bar (GMod does this too)
	if ( self.m_bDragging ) then
		self:ApplyDrag()
		self:OnMouseDragged()
	elseif ( self:IsOverBar( self:LocalMouseX() ) ) then
		self:SetCursor( "sizewe" )
	else
		self:SetCursor( "arrow" )
	end
end

function PANEL:OnCursorExited()
	if ( not self.m_bDragging ) then self:SetCursor( "arrow" ) end
end

function PANEL:OnThink()
	-- OnCursorMoved stops arriving when the engine routes the cursor elsewhere while
	-- the button is held; while capturing, this keeps the bar under the cursor.
	if ( self.m_bDragging ) then
		self:ApplyDrag()
		self:OnMouseDragged()
	end
end

derma.DefineControl( "DHorizontalDivider", "A draggable vertical divider", PANEL, "DPanel" )
