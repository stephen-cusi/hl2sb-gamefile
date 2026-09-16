--[[ DListView -- column list / table (original implementation).

	Rows are DListView_Line controls (own file), which draw their own cells --
	no per-cell child panels, so a 500-row list costs 500 panels, not 500 * N. --]]

local PANEL = {}

local ROW_H = 18
local HEADER_H = 20

function PANEL:Init()
	self:SetDrawBackground( false )

	self.m_tColumns = {}
	self.m_tRows = {}
	self.m_pSelected = nil

	self.m_pHeader = vgui.Create( "DPanel", self, "Header" )
	self.m_pHeader:SetDrawBackground( false )

	self.m_pScroll = vgui.Create( "DScrollPanel", self, "Scroll" )
	self.m_pScroll:SetDrawBackground( false )
end

function PANEL:AddColumn( strName )
	local col = { name = tostring( strName or "" ), i = #self.m_tColumns + 1 }
	self.m_tColumns[ col.i ] = col
	self:RebuildHeader()
	return col
end

function PANEL:GetColumnCount()
	return #self.m_tColumns
end

function PANEL:ColumnWidth( i )
	local n = #self.m_tColumns
	if ( n == 0 ) then return self:GetWide() end
	return math.floor( self:GetWide() / n )
end

function PANEL:AddRow( ... )
	local vargs = { ... }

	local row = vgui.Create( "DListView_Line", self.m_pScroll:GetCanvas(), "Row" )
	row.m_pList = self
	row.m_iIndex = #self.m_tRows + 1
	row:SetColumnCount( #self.m_tColumns )

	for i = 1, #self.m_tColumns do
		row:SetColumnText( i, vargs[ i ] )
	end

	table.insert( self.m_tRows, row )
	self:RelayoutRows()
	return row
end

function PANEL:GetLine( i )
	return self.m_tRows[ i ]
end

function PANEL:GetLines()
	return self.m_tRows
end

function PANEL:RemoveLine( i )
	local row = table.remove( self.m_tRows, i )
	if ( IsValid( row ) ) then row:Remove() end

	for j, r in ipairs( self.m_tRows ) do
		r.m_iIndex = j
	end

	if ( self.m_pSelected == row ) then self.m_pSelected = nil end
	self:RelayoutRows()
end

function PANEL:Clear()
	for _, row in ipairs( self.m_tRows ) do
		if ( IsValid( row ) ) then row:Remove() end
	end
	self.m_tRows = {}
	self.m_pSelected = nil
	self:RelayoutRows()
end

--- Called by DListView_Line:DoClick.
function PANEL:OnClickLine( line, bRight )
	if ( self.m_pSelected and IsValid( self.m_pSelected ) ) then
		self.m_pSelected:SetSelected( false )
	end

	self.m_pSelected = line
	line:SetSelected( true )

	if ( self.OnRowSelected ) then
		local ok, err = pcall( self.OnRowSelected, self, line.m_iIndex, line )
		if ( not ok ) then Warning( "DListView:OnRowSelected failed: " .. tostring( err ) .. "\n" ) end
	end
end

function PANEL:GetSelectedLine()
	return self.m_pSelected
end

function PANEL:GetSelected()
	if ( self.m_pSelected ) then return { self.m_pSelected } end
	return {}
end

function PANEL:RelayoutRows()
	local colW = {}
	for i = 1, #self.m_tColumns do
		colW[ i ] = self:ColumnWidth( i )
	end

	local totalH = 0
	for j, row in ipairs( self.m_tRows ) do
		row:SetSize( self:GetWide(), ROW_H )
		row:SetPos( 0, ( j - 1 ) * ROW_H )
		row:SetColumnWidths( colW )
		totalH = j * ROW_H
	end

	self.m_pScroll:SetContentHeight( totalH )
end

function PANEL:RebuildHeader()
	for _, c in ipairs( self.m_tHeaderCells or {} ) do
		if ( IsValid( c ) ) then c:Remove() end
	end
	self.m_tHeaderCells = {}

	local x = 0
	for i, col in ipairs( self.m_tColumns ) do
		local cell = vgui.Create( "DButton", self.m_pHeader, "ColHead" .. i )
		cell:SetText( col.name )
		cell:SetPos( x, 0 )
		cell:SetSize( self:ColumnWidth( i ), HEADER_H )
		table.insert( self.m_tHeaderCells, cell )
		x = x + self:ColumnWidth( i )
	end
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	self.m_pHeader:SetPos( 0, 0 )
	self.m_pHeader:SetSize( w, HEADER_H )

	self.m_pScroll:SetPos( 0, HEADER_H )
	self.m_pScroll:SetSize( w, math.max( 0, h - HEADER_H ) )

	self:RebuildHeader()
	self:RelayoutRows()
end

function PANEL:Paint( w, h )
	derma.SkinHook( "Paint", "ListView", self, w or self:GetWide(), h or self:GetTall() )
end

derma.DefineControl( "DListView", "HL2SB column list", PANEL, "DPanel" )
