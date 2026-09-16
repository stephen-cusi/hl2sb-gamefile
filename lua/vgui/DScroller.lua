--[[ DScroller -- DScrollPanel + auto-sizing canvas (original implementation).

	GMod's DScroller scrolls both axes and resizes its canvas to its content.
	This version keeps the contract (Add / GetCanvas / SetSizeToContentsOfPanel-
	ish behaviour) on top of DScrollPanel's vertical scrolling. --]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )
	self.m_pInner = vgui.Create( "DScrollPanel", self, "Inner" )
	self.m_pInner:SetDrawBackground( false )
end

function PANEL:GetCanvas()
	return self.m_pInner:GetCanvas()
end

function PANEL:GetVBar()
	return self.m_pInner.m_pVBar
end

function PANEL:GetHBar()
	return nil
end

function PANEL:Add( pnl )
	return self.m_pInner:Add( pnl )
end

function PANEL:SetSizeToContents( b )
	self.m_bAutoHeight = b
end

--- Recompute the content height from the canvas children (called on layout).
function PANEL:RecomputeHeight()
	local canvas = self:GetCanvas()
	local maxBottom = 0
	for i = 0, canvas:GetChildCount() - 1 do
		local c = canvas:GetChild( i )
		if ( IsValid( c ) ) then
			local _, cy = c:GetPos()
			maxBottom = math.max( maxBottom, cy + c:GetTall() )
		end
	end
	self.m_pInner:SetContentHeight( maxBottom + 4 )
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	self.m_pInner:SetSize( w, h )
	self:RecomputeHeight()
end

derma.DefineControl( "DScroller", "HL2SB auto-height scroller", PANEL, "DPanel" )
