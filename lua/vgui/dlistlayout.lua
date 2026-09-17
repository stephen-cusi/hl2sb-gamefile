--[[ DListLayout -- vertical list container (original implementation).

	The wiki says it plainly: "Child panels' widths are set to the width of the
	DListLayout, and it resizes vertically to accommodate the heights of all children.
	You can place this inside a DScrollPanel when adding many panels."

	That is exactly what a spawnmenu sidebar needs, and doing it in a container means
	the menu never positions a row itself.

	Wiki: https://wiki.facepunch.com/gmod/DListLayout

	GMod's DListLayout derives from DDragBase; this one did not, because DDragBase
	did not exist here when it was written.  DDragBase has since been ported
	(lua/vgui/DDragBase.lua) and this control is re-based onto it, which is what
	gives the tree's child containers (lua/vgui/DTree_Node.lua creates a DListLayout
	and calls SetDropPos / MakeDroppable / InsertBefore on it) their drag & drop.
	The fork's own layout pass below is unchanged: it stretches each child to this
	layout's width and stacks them, exactly as the wiki describes.
--]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )

	-- GMod's DListLayout:Init is just this line (its children dock TOP there; this
	-- fork stacks them in PerformLayout instead, see below).
	self:SetDropPos( "82" )

	self.m_bPaintBackground = false
	self.m_iContentHeight = 0
end

--- GMod: SetPaintBackground( b ).  Kept as our own flag so the skin hook is what
--- actually paints (lua/derma/hl2sb_skin.lua SKIN:PaintPanel).
function PANEL:SetPaintBackground( b )
	self.m_bPaintBackground = ( b ~= false )
end

function PANEL:GetPaintBackground()
	return self.m_bPaintBackground
end

--- GMod: Add( panel ).  The child is stretched to this layout's width by
--- PerformLayout, not here, so a later resize keeps working.
function PANEL:Add( pnl )
	pnl:SetParent( self )
	self:InvalidateLayout( true )
	return pnl
end

function PANEL:Layout()
	self:InvalidateLayout( true )
end

function PANEL:OnChildAdded()
	self:InvalidateLayout( true )
end

function PANEL:OnChildRemoved()
	self:InvalidateLayout( true )
end

--- The height every child together takes, for callers that size something around it.
function PANEL:GetContentHeight()
	return self.m_iContentHeight or 0
end

--- GMod: `Panel:SizeToContents()`.  GMod's DListLayout has no own implementation - its
--- PerformLayout calls the engine `SizeToChildren( false, true )` (dlistlayout.lua:24),
--- and Panel:SizeToContents() itself is documented as doing nothing outside
--- Label-derived panels - so on a DListLayout it was effectively "make my tall fit my
--- children", which is what the engine pass did anyway.  Here PerformLayout records
--- that height (GetContentHeight) and this returns it, so DTree_Node:PerformLayout
--- (`self.ChildNodes:SizeToContents(); self:SetTall( LineHeight + self.ChildNodes:GetTall() )`)
--- gets the number it expects.  See the header note about GMod's own engine call.
function PANEL:SizeToContents()
	if ( not self.m_iContentHeight or self.m_iContentHeight == 0 ) then
		-- no layout pass has run yet: sum the children the same way PerformLayout does
		local y = 0

		for _, child in ipairs( self:GetChildren() ) do
			local ch = child:GetTall()
			if ( ch > 0 ) then y = y + ch end
		end

		self.m_iContentHeight = y
	end

	self:SetTall( self.m_iContentHeight )
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()

	local y = 0

	for _, child in ipairs( self:GetChildren() ) do
		local ch = child:GetTall()

		if ( ch > 0 ) then
			child:SetPos( 0, y )
			child:SetSize( w, ch )		-- "widths are set to the width of the DListLayout"
			y = y + ch
		end
	end

	self.m_iContentHeight = y
end

function PANEL:Paint( w, h )
	if ( self.m_bPaintBackground ) then
		derma.SkinHook( "Paint", "Panel", self, w, h )
	end
end

derma.DefineControl( "DListLayout", "HL2SB vertical list layout", PANEL, "DDragBase" )
