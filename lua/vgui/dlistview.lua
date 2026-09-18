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

--- GMod: DListView:AddColumn( strName ) returns the column, whose `.Header` is the
--- header panel ("self.FileHeader = self.Files:AddColumn( "Files" ).Header" in
--- lua/vgui/DFileBrowser.lua:180).  Here the header cell is created once per column
--- and reused, so that reference stays valid across layouts.
function PANEL:AddColumn( strName )
	local col = { name = tostring( strName or "" ), i = #self.m_tColumns + 1 }
	self.m_tColumns[ col.i ] = col
	self:RebuildHeader()
	col.Header = self.m_tHeaderCells and self.m_tHeaderCells[ col.i ]
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

--- GMod: DListView:GetColumnWidth( i ) -- the GMod spelling of ColumnWidth.
function PANEL:GetColumnWidth( i )
	return self:ColumnWidth( i )
end

--- GMod: DListView:GetHeaderHeight() -- what DListView_Column:PerformLayout asks for.
function PANEL:GetHeaderHeight()
	return HEADER_H
end

--- GMod: DListView:SetDataHeight( h ) -- row height.  This fork used a fixed
--- ROW_H; honour the override (the minecraft menu sets 16).
function PANEL:SetDataHeight( h )
	self.m_iDataHeight = math.max( 8, tonumber( h ) or ROW_H )
	self:RelayoutRows()
end

function PANEL:GetDataHeight()
	return self.m_iDataHeight or ROW_H
end

--- GMod: DListView:SetMultiSelect( b ) / GetMultiSelect().  This fork's list keeps a
--- single selection (the row itself decides), so the flag is recorded and documented
--- rather than implemented; DFileBrowser sets it to false, which is the behaviour here.
function PANEL:SetMultiSelect( b )
	self.m_bMultiSelect = ( b ~= false )
end

function PANEL:GetMultiSelect()
	return self.m_bMultiSelect == true
end

--- GMod: DListView:SetManual( b ) -- "don't lay the columns out automatically".
--- This fork rebuilds its header whenever the columns change, so the flag is recorded.
function PANEL:SetManual( b )
	self.m_bManual = ( b ~= false )
end

function PANEL:GetManual()
	return self.m_bManual == true
end

--- GMod: DListView:SetDirty( b ) -- re-layout the rows on the next paint.  Here rows
--- are laid out immediately, so this is the same call.
function PANEL:SetDirty( b )
	self:RelayoutRows()
end

--- GMod: DListView:SortByColumn( iColumn, bDescending ).  GMod sorts by the line's
--- sort value when one was set (DListViewLine:SetSortValue), else by the caption.
function PANEL:SortByColumn( iColumn, bDescending )
	table.sort( self.m_tRows, function( a, b )
		local av = a.GetSortValue and a:GetSortValue( iColumn )
		local bv = b.GetSortValue and b:GetSortValue( iColumn )

		if ( av == nil ) then av = a:GetColumnText( iColumn ) end
		if ( bv == nil ) then bv = b:GetColumnText( iColumn ) end

		if ( av == bv ) then return false end
		if ( bDescending ) then return tostring( av ) > tostring( bv ) end

		return tostring( av ) < tostring( bv )
	end )

	for j, row in ipairs( self.m_tRows ) do
		row.m_iIndex = j
	end

	self:RelayoutRows()
end

--- GMod: DListView:AddLine( ... ) -- the same row builder as AddRow here
--- (DFileBrowser calls it with a single file name for its one column).  Aliased after
--- AddRow is defined, below.

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

--- GMod: DListView:AddLine( ... ) -- the same builder under GMod's name.
PANEL.AddLine = PANEL.AddRow

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
	local rowH = self.m_iDataHeight or ROW_H

	local colW = {}
	for i = 1, #self.m_tColumns do
		colW[ i ] = self:ColumnWidth( i )
	end

	local totalH = 0
	for j, row in ipairs( self.m_tRows ) do
		row:SetSize( self:GetWide(), rowH )
		row:SetPos( 0, ( j - 1 ) * rowH )
		row:SetColumnWidths( colW )
		totalH = j * rowH
	end

	self.m_pScroll:SetContentHeight( totalH )
end

--- The header cells are created once per column and re-used (repositioned/resized)
--- so that a column's `.Header` reference - what GMod addons hold, see AddColumn -
--- stays valid across layouts.
function PANEL:RebuildHeader()
	self.m_tHeaderCells = self.m_tHeaderCells or {}

	for i, col in ipairs( self.m_tColumns ) do
		if ( !IsValid( self.m_tHeaderCells[ i ] ) ) then
			local cell = vgui.Create( "DButton", self.m_pHeader, "ColHead" .. i )
			cell:SetText( col.name )
			self.m_tHeaderCells[ i ] = cell
		end

		self.m_tHeaderCells[ i ]:SetText( col.name )
		col.Header = self.m_tHeaderCells[ i ]
	end

	-- columns that went away (Clear + AddColumn) leave their cells behind
	for i = #self.m_tColumns + 1, #self.m_tHeaderCells do
		if ( IsValid( self.m_tHeaderCells[ i ] ) ) then self.m_tHeaderCells[ i ]:Remove() end
		self.m_tHeaderCells[ i ] = nil
	end

	local x = 0
	for i = 1, #self.m_tColumns do
		self.m_tHeaderCells[ i ]:SetPos( x, 0 )
		self.m_tHeaderCells[ i ]:SetSize( self:ColumnWidth( i ), HEADER_H )
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
