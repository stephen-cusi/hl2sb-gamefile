--[[ DTooltip -- hover text bubble (original implementation). --]]

local PANEL = {}

function PANEL:Init()
	self:SetVisible( false )
	self:SetMouseInputEnabled( false )
	self:SetDrawBackground( false )

	self.m_pLabel = vgui.Create( "DLabel", self, "Text" )
	self.m_pLabel:SetMouseInputEnabled( false )
end

function PANEL:ShowFor( pnl, strText, iDelay )
	if ( self.m_pTimer ) then timer.Remove( self.m_pTimer ) end

	self.m_pTarget = pnl
	self:SetText( strText )

	self.m_pTimer = "tt_" .. tostring( CurTime() )
	timer.Create( self.m_pTimer, iDelay or 0.4, 1, function()
		if ( not IsValid( pnl ) ) then return end
		if ( gui and gui.MouseX and gui.MouseY ) then
			self:SetPos( gui.MouseX() + 12, gui.MouseY() + 12 )
		end
		self:SetVisible( true )
	end )
end

function PANEL:Hide()
	if ( self.m_pTimer ) then timer.Remove( self.m_pTimer ) end
	self:SetVisible( false )
end

function PANEL:SetText( strText )
	self.m_pLabel:SetText( strText )
	self.m_pLabel:SizeToContents()
	local w, h = self.m_pLabel:GetSize()
	self:SetSize( w + 10, h + 8 )
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	self.m_pLabel:SetPos( 5, 4 )
end

function PANEL:Paint( w, h )
	derma.SkinHook( "Paint", "Tooltip", self, w or self:GetWide(), h or self:GetTall() )
end

derma.DefineControl( "DTooltip", "HL2SB tooltip", PANEL, "DPanel" )
