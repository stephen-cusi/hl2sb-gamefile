--[[ DPanel -- HL2SB derma base container (original implementation). --]]

local PANEL = {}

function PANEL:Init()
	self:SetMouseInputEnabled( false )
	self:SetKeyBoardInputEnabled( false )
	self.m_bDrawBackground = true
end

function PANEL:SetDrawBackground( b )
	self.m_bDrawBackground = b
end

function PANEL:GetDrawBackground()
	return self.m_bDrawBackground
end

--- GMod's SetBackgroundColor / GetBackgroundColor map onto the engine's
--- background colour field (SetBgColor is engine-bound).
function PANEL:SetBackgroundColor( clr )
	if ( self.SetBgColor ) then self:SetBgColor( clr ) end
end

function PANEL:GetBackgroundColor()
	if ( self.GetBgColor ) then return self:GetBgColor() end
end

function PANEL:Paint( w, h )
	if ( not self.m_bDrawBackground ) then return end

	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Panel", self, w, h )
end

derma.DefineControl( "DPanel", "HL2SB base container panel", PANEL, "Panel" )
