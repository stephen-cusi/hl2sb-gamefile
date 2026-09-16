--[[ DListLayout -- vertical list container (original implementation).

	The wiki says it plainly: "Child panels' widths are set to the width of the
	DListLayout, and it resizes vertically to accommodate the heights of all children.
	You can place this inside a DScrollPanel when adding many panels."

	That is exactly what a spawnmenu sidebar needs, and doing it in a container means
	the menu never positions a row itself.

	Wiki: https://wiki.facepunch.com/gmod/DListLayout

	⚠️ Documented gap: GMod's DListLayout derives from DDragBase and gains the drag &
	drop rearrangement (MakeDroppable).  This fork has no DDragBase, so MakeDroppable
	exists but only records the identifier - nothing can be dragged yet.  Everything
	else (Add, Layout, PerformLayout, OnChildAdded/Removed) behaves as documented.
--]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )

	self.m_bPaintBackground = false
	self.m_strDroppableName = nil
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

--- declared-but-inert without DDragBase - see the note in the header
function PANEL:MakeDroppable( strName )
	self.m_strDroppableName = strName
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

derma.DefineControl( "DListLayout", "HL2SB vertical list layout", PANEL, "DPanel" )
