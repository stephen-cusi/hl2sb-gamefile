--[[ DCollapsibleCategory -- a fold-away group (original implementation). --]]

local PANEL = {}

local HEAD_H = 22

function PANEL:Init()
	self:SetDrawBackground( false )
	self.m_bCollapsed = false
	self.m_pContents = nil

	self.m_pHeader = vgui.Create( "DButton", self, "Header" )
	self.m_pHeader:SetDrawBackground( false )
	self.m_pHeader.DoClick = function() self:Toggle() end
	self.m_pHeader.Paint = function( pnl, w, h )
		derma.SkinHook( "Paint", "CategoryHead", self, w, h )
		derma.DrawText( "DermaDefaultBold", 20, math.floor( ( h - 13 ) / 2 ), self.m_strLabel or "",
			Color( 230, 230, 230, 255 ) )
		-- expand/collapse chevron
		local col = Color( 200, 200, 200, 255 )
		surface.DrawSetColor( col.r, col.g, col.b, col.a )
		if ( self.m_bCollapsed ) then
			surface.DrawLine( 6, h / 2 - 3, 10, h / 2 )
			surface.DrawLine( 10, h / 2, 6, h / 2 + 3 )
		else
			surface.DrawLine( 5, h / 2 - 2, 11, h / 2 - 2 )
			surface.DrawLine( 11, h / 2 - 2, 8, h / 2 + 3 )
			surface.DrawLine( 8, h / 2 + 3, 5, h / 2 - 2 )
		end
	end

	self.m_pBody = vgui.Create( "DPanel", self, "Body" )
	self.m_pBody:SetDrawBackground( false )
end

function PANEL:SetLabel( strLabel )
	self.m_strLabel = strLabel
	self.m_pHeader:SetText( "" )
end

function PANEL:SetContents( pnl, bDelete )
	pnl:SetParent( self.m_pBody )
	self.m_pContents = pnl
	self:InvalidateLayout( true )
end

function PANEL:Toggle()
	self.m_bCollapsed = not self.m_bCollapsed
	self.m_pBody:SetVisible( not self.m_bCollapsed )
	self:InvalidateLayout( true )
end

function PANEL:GetContents()
	return self.m_pContents
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()

	self.m_pHeader:SetPos( 0, 0 )
	self.m_pHeader:SetSize( w, HEAD_H )

	self.m_pBody:SetPos( 0, HEAD_H )
	self.m_pBody:SetSize( w, self.m_bCollapsed and 0 or ( self.m_pContents and self.m_pContents:GetTall() or 0 ) )
end

derma.DefineControl( "DCollapsibleCategory", "HL2SB collapsible group", PANEL, "DPanel" )
