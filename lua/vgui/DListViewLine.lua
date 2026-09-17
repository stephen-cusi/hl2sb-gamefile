--[[ DListViewLine / DListViewLabel -- one row of a DListView (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DListViewLine
	  A row holds one DListViewLabel per column (https://wiki.facepunch.com/gmod/DListViewLabel):
	  SetColumnText( i, text ) / GetColumnText( i ) (aliases SetValue / GetValue),
	  SetSortValue / GetSortValue for sorting by something other than the text,
	  DataLayout( listview ) positions the labels from the list view's column widths,
	  and SetSelected / IsLineSelected drive the caption colours.

	Ported from GMod's lua/vgui/dlistview_line.lua (188 lines, both controls).

	Notes for this fork:
	  * ⚠️ GMod registers this class TWICE - "DListViewLine" and the legacy alias
	    "DListView_Line" (its line 188).  This fork already has its own
	    lua/vgui/DListView_Line.lua, and lua/vgui/DListView.lua:45 creates exactly
	    that name for its rows, so registering the alias here would replace the row
	    class this fork's list view is built on.  Only "DListViewLine" is registered.
	  * The line's Paint / ApplySchemeSettings / PerformLayout go through the skin in
	    GMod (Derma_Hook "ListViewLine"); this fork's skin has none of those hooks, so
	    each asks the hook first and then does the work itself (row background,
	    DataLayout, and letting each label apply its own scheme).
	  * `type( strText ) == "Panel"` is GMod's own userdata type; IsPanel() below is
	    the same test for this fork, where a panel can be userdata (game) or a table
	    (offline harness).
	  * DListViewLabel:UpdateColours needs Skin.Colours.Label.Bright / .Dark, which
	    this fork's skin did not carry - added with this port.
--]]

local PANEL = {}

function PANEL:Init()

	self:SetTextInset( 5, 0 )

end

--- GMod's DLabel:ApplySchemeSettings calls UpdateColours; this fork's DLabel had no
--- scheme pass at all, so it was added to lua/vgui/DLabel.lua with this port.
function PANEL:UpdateColours( skin )

	local parent = self:GetParent()

	-- guard: a label can be created on its own (offline harness / addon code)
	if ( IsValid( parent ) and parent.IsLineSelected and parent:IsLineSelected() ) then
		return self:SetTextStyleColor( skin.Colours.Label.Bright )
	end

	return self:SetTextStyleColor( skin.Colours.Label.Dark )

end

function PANEL:GenerateExample()

	-- Do nothing!

end

derma.DefineControl( "DListViewLabel", "", PANEL, "DLabel" )

--[[---------------------------------------------------------
	DListViewLine
-----------------------------------------------------------]]

--- GMod: type( v ) == "Panel"; this fork's panels are userdata in game and tables in
--- the offline harness, so test for the panel interface instead.
local function IsPanel( v )
	if ( ispanel ~= nil ) then return ispanel( v ) end
	if ( istable( v ) and v.SetParent ~= nil ) then return true end

	return type( v ) == "userdata" and v.SetParent ~= nil
end

local PANEL = {}

AccessorFunc( PANEL, "m_iID", "ID" )
AccessorFunc( PANEL, "m_pListView", "ListView" )
AccessorFunc( PANEL, "m_bAlt", "AltLine" )

function PANEL:Init()

	self:SetSelectable( true )
	self:SetMouseInputEnabled( true )

	self.Columns = {}
	self.Data = {}

end

function PANEL:OnSelect()

	-- For override

end

function PANEL:OnRightClick()

	-- For override

end

function PANEL:OnMousePressed( mcode )

	if ( mcode == MOUSE_RIGHT ) then

		-- This is probably the expected behaviour..
		if ( !self:IsLineSelected() ) then

			self:GetListView():OnClickLine( self, true )
			self:OnSelect()

		end

		-- guard: OnRowRightClick is an override point on GMod's list view
		local view = self:GetListView()

		if ( IsValid( view ) and view.OnRowRightClick ) then
			view:OnRowRightClick( self:GetID(), self )
		end

		self:OnRightClick()

		return

	end

	self:GetListView():OnClickLine( self, true )
	self:OnSelect()

end

function PANEL:OnCursorMoved()

	if ( input.IsMouseDown( MOUSE_LEFT ) ) then
		self:GetListView():OnClickLine( self )
	end

end

function PANEL:SetSelected( b )

	self.m_bSelected = b

	-- Update colors of the lines
	for id, column in pairs( self.Columns ) do
		column:ApplySchemeSettings()
	end

end

function PANEL:IsLineSelected()

	return self.m_bSelected

end

function PANEL:SetColumnText( i, strText )

	if ( IsPanel( strText ) ) then

		if ( IsValid( self.Columns[ i ] ) ) then self.Columns[ i ]:Remove() end

		strText:SetParent( self )
		self.Columns[ i ] = strText
		self.Columns[ i ].Value = strText
		return

	end

	if ( !IsValid( self.Columns[ i ] ) ) then

		self.Columns[ i ] = vgui.Create( "DListViewLabel", self )
		self.Columns[ i ]:SetMouseInputEnabled( false )

		-- Disable autostretch behavior since we are not using it anyway, it gets expensive fast
		self.Columns[ i ].Think = nil

	end

	self.Columns[ i ]:SetText( tostring( strText ) )
	self.Columns[ i ].Value = strText
	return self.Columns[ i ]

end
PANEL.SetValue = PANEL.SetColumnText

function PANEL:GetColumnText( i )

	if ( !self.Columns[ i ] ) then return "" end

	return self.Columns[ i ].Value

end

PANEL.GetValue = PANEL.GetColumnText

--[[---------------------------------------------------------
	Allows you to store data per column

	Used in the SortByColumn function for incase you want to
	sort with something else than the text
-----------------------------------------------------------]]
function PANEL:SetSortValue( i, data )

	self.Data[ i ] = data

end

function PANEL:GetSortValue( i )

	return self.Data[ i ]

end

function PANEL:DataLayout( ListView )

	self:ApplySchemeSettings()

	local height = self:GetTall()

	local x = 0
	for k, Column in pairs( self.Columns ) do

		local w = ListView:ColumnWidth( k )
		Column:SetPos( x, 0 )
		Column:SetSize( w, height )
		x = x + w

	end

end

--- Paint / ApplySchemeSettings / PerformLayout are skin hooks in GMod (see the
--- header).  The fallbacks: a row background the labels paint on top of, the labels'
--- own scheme pass, and the column layout.
function PANEL:Paint( w, h )

	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( derma.SkinHook( "Paint", "ListViewLine", self, w, h ) ) then return end

	local col

	if ( self:IsLineSelected() ) then
		col = Color( 52, 108, 190, 200 )
	elseif ( self:GetAltLine() ) then
		col = Color( 70, 75, 83, 120 )
	end

	if ( col ) then
		surface.DrawSetColor( col.r, col.g, col.b, col.a )
		surface.DrawFilledRect( 0, 0, w, h )
	end

end

function PANEL:ApplySchemeSettings()

	if ( derma.SkinHook( "Scheme", "ListViewLine", self ) ) then return end

	for id, column in pairs( self.Columns ) do
		if ( column.ApplySchemeSettings ) then column:ApplySchemeSettings() end
	end

end

function PANEL:PerformLayout()

	if ( derma.SkinHook( "Layout", "ListViewLine", self ) ) then return end

	local view = self:GetListView()

	if ( IsValid( view ) and view.ColumnWidth ) then
		self:DataLayout( view )
	end

end

-- GMod registers this class under the name "DListViewLine" and then again under the
-- legacy alias "DListView_Line"; this fork must NOT register that alias (its own row
-- class owns the name - see the header).
derma.DefineControl( "DListViewLine", "A line from the List View", PANEL, "Panel" )
