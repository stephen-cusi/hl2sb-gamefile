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
---
--- The returned table also carries GMod's DListView_Column setter/getter surface
--- (SetFixedWidth / SetDescending / SetTextAlign / SetSortable / ...) as plain
--- fields: addons drive those on the object AddColumn returned, and without them
--- every such call died with "attempt to call a nil value".  The per-column width
--- (col.iWidth) feeds ColumnWidth below, which is what makes OnRequestResize and
--- SetFixedWidth stick across PerformLayouts.
function PANEL:AddColumn( strName )
	local col = { name = tostring( strName or "" ), i = #self.m_tColumns + 1 }
	self.m_tColumns[ col.i ] = col
	self:RebuildHeader()
	col.Header = self.m_tHeaderCells and self.m_tHeaderCells[ col.i ]

	--- GMod: DListView_Column:SetFixedWidth( iSize ) -- fix the width and drop the
	--- resize behaviour; here that is one stored width.
	function col:SetFixedWidth( iSize )
		iSize = math.max( 4, tonumber( iSize ) or 16 )
		self.iWidth = iSize
		local list = self.list
		if ( list ~= nil ) then
			list.m_bManual = true
			list:RebuildHeader()
			list:RelayoutRows()
		end
	end

	function col:SetWidth( iSize )
		self:SetFixedWidth( iSize )
	end

	function col:GetWidth()
		return self.iWidth
	end

	function col:SetText( strName )
		self.name = tostring( strName or "" )
		local list = self.list
		if ( IsValid( list ) and list.RebuildHeader ) then
			if ( IsValid( self.Header ) ) then self.Header:SetText( self.name ) end
		end
	end

	--- GMod: sortable flag -- recorded; SortByColumn always works here (the fork's
	--- header click route carries no "non sortable" notion for plain tables).
	function col:SetSortable( b )
		self.bSortable = ( b ~= false )
	end

	function col:GetSortable()
		return self.bSortable ~= false
	end

	function col:SetDescending( b )
		self.bDesc = ( b == true )
	end

	function col:GetDescending()
		return self.bDesc == true
	end

	function col:SetTextAlign( align )
		self.iTextAlign = align
	end

	function col:GetTextAlign()
		return self.iTextAlign
	end

	function col:SetMinWidth( iSize )
		self.iMinWidth = tonumber( iSize )
	end

	function col:GetMinWidth()
		return self.iMinWidth
	end

	function col:SetMaxWidth( iSize )
		self.iMaxWidth = tonumber( iSize )
	end

	function col:GetMaxWidth()
		return self.iMaxWidth
	end

	col.list = self

	return col
end

function PANEL:GetColumnCount()
	return #self.m_tColumns
end

--- Fixed widths (col.iWidth, set through the column surface above) win over the
--- even split; the remaining columns share what is left.
function PANEL:ColumnWidth( i )
	local n = #self.m_tColumns
	if ( n == 0 ) then return self:GetWide() end

	local col = self.m_tColumns[ i ]
	if ( col ~= nil and col.iWidth ~= nil ) then return col.iWidth end

	local nFree = 0
	local wFree = self:GetWide()
	for _, c in ipairs( self.m_tColumns ) do
		if ( c.iWidth ~= nil ) then
			wFree = wFree - c.iWidth
		else
			nFree = nFree + 1
		end
	end

	if ( nFree == 0 ) then return 0 end
	return math.floor( math.max( 0, wFree ) / nFree )
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

--- GMod: DListView:OnRequestResize( SizingColumn, iSize ) -- a column drag (or an
--- addon) asks for the sizing column to become iSize wide; the column to its right
--- absorbs the difference (gmod/vgui/dlistview.lua:246).  SizingColumn arrives as a
--- header cell, a column table from AddColumn, or a plain 1-based index.
function PANEL:OnRequestResize( SizingColumn, iSize )
	iSize = math.max( 4, math.floor( tonumber( iSize ) or 0 ) )

	local idx
	if ( isnumber( SizingColumn ) ) then
		idx = SizingColumn
	else
		for i, c in ipairs( self.m_tColumns ) do
			if ( c == SizingColumn or c.Header == SizingColumn ) then idx = i break end
		end
	end
	if ( idx == nil ) then return end

	local sizing = self.m_tColumns[ idx ]

	-- Find the column to the right of this one
	local right = nil
	for i = idx + 1, #self.m_tColumns do
		if ( self.m_tColumns[ i ].iWidth == nil ) then
			right = self.m_tColumns[ i ]
			break
		end
	end

	local total = self:GetWide()
	local fixed = 0
	for _, c in ipairs( self.m_tColumns ) do
		if ( c ~= sizing and c.iWidth ~= nil ) then fixed = fixed + c.iWidth end
	end

	-- Alter the size of the column on the right too, slightly
	if ( right ~= nil ) then
		local sizeChange = self:ColumnWidth( idx ) - iSize
		right.iWidth = math.max( 4, self:ColumnWidth( right.i ) + sizeChange )
		fixed = fixed + right.iWidth
	end

	sizing.iWidth = math.max( 4, math.min( iSize, total - fixed ) )
	self.m_bManual = true

	-- Invalidating will munge all the columns about and make it right
	self:InvalidateLayout()
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
