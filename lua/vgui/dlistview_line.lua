--[[ DListView_Line -- one selectable row inside a DListView (original). --]]

local PANEL = {}

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetDrawBackground( false )
	self.m_tColumns = {}
	self.m_iRow = 0
	self.m_bSelected = false
	self.m_pList = nil
end

function PANEL:SetList( pnlList )
	self.m_pList = pnlList
end

function PANEL:SetColumnWidths( tWidths )
	self.m_tWidths = tWidths
end

function PANEL:SetColumnCount( i )
	self.m_iColumnCount = i
end

function PANEL:SetColumnText( iCol, strText )
	self.m_tColumns[ iCol ] = tostring( strText or "" )
end

function PANEL:GetColumnText( iCol )
	return self.m_tColumns[ iCol ] or ""
end

function PANEL:SetSelected( b )
	self.m_bSelected = b
end

function PANEL:IsSelected()
	return self.m_bSelected
end

function PANEL:DoClick()
	if ( self.m_pList ) then
		self.m_pList:OnClickLine( self )
	end
end

function PANEL:DoRightClick()
	if ( self.m_pList ) then
		self.m_pList:OnClickLine( self, true )
	end
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "ListViewLine", self, w, h )

	local x = 4
	for iCol, strText in ipairs( self.m_tColumns ) do
		local colW = ( self.m_tWidths and self.m_tWidths[ iCol ] ) or 80
		if ( strText ~= "" ) then
			derma.DrawText( "DermaDefault", x, math.floor( ( h - 13 ) / 2 ), strText,
				self.m_bSelected and Color( 255, 255, 255, 255 ) or Color( 210, 210, 210, 255 ) )
		end
		x = x + colW
	end
end

derma.DefineControl( "DListView_Line", "HL2SB list row", PANEL, "DPanel" )
