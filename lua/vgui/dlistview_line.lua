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

--- GMod: DListViewLine:GetID() -- the 1-based row index.  The minecraft SWEP
--- reads it right after AddLine (cl_init.lua:82).
function PANEL:GetID()
	return self.m_iIndex or self.m_iRow or 0
end

function PANEL:SetSelected( b )
	self.m_bSelected = b
end

function PANEL:IsSelected()
	return self.m_bSelected
end

--- GMod: DListViewLine:IsLineSelected() (its own spelling, used by the ported
--- GMod code and by DListViewLabel's UpdateColours).  Same state as IsSelected().
function PANEL:IsLineSelected()
	return self.m_bSelected
end

--- GMod: DListViewLine:SetSortValue( i, data ) / GetSortValue( i ) -- what
--- DListView:SortByColumn sorts by when the caption is not the right key.
function PANEL:SetSortValue( iCol, data )
	self.m_tSortValues = self.m_tSortValues or {}
	self.m_tSortValues[ iCol ] = data
end

function PANEL:GetSortValue( iCol )
	return self.m_tSortValues and self.m_tSortValues[ iCol ]
end

function PANEL:DoClick()
	if ( self.m_pList ) then
		self.m_pList:OnClickLine( self )
	end
end

function PANEL:DoRightClick()
	if ( self.m_pList ) then
		self.m_pList:OnClickLine( self, true )

		-- GMod: DListViewLine:OnMousePressed calls
		-- self:GetListView():OnRowRightClick( self:GetID(), self )
		if ( self.m_pList.OnRowRightClick ) then
			self.m_pList:OnRowRightClick( self.m_iIndex, self )
		end
	end
end

--- GMod's list view answers DoDoubleClick( id, line ); DFileBrowser overrides it to
--- open a file.  The engine dispatches OnMouseDoublePressed for a panel (see DLabel),
--- and GMod's own call is `self:DoDoubleClick( Line:GetID(), Line )` - i.e. with the
--- method syntax, so the override sees ( self, id, line ).
function PANEL:OnMouseDoublePressed( mousecode )
	if ( self.m_pList and self.m_pList.DoDoubleClick ) then
		self.m_pList:DoDoubleClick( self.m_iIndex, self )
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
