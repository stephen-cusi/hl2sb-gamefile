--[[ DListView column controls -- DListViewHeaderLabel, DListView_DraggerBar,
	DListView_Column and DListView_ColumnPlain (GMod port, one GMod file).

	Wiki: https://wiki.facepunch.com/gmod/DListView_Column
	  A column is a Panel holding a header button (the caption + click to sort) and a
	  DListView_DraggerBar on its right edge (drag to resize).  [Right-click on a
	  header offers a column list in GMod; DoRightClick here is the override point.]

	Ported from GMod's lua/vgui/dlistview_column.lua (160 lines, all four controls).

	Notes for this fork:
	  * Three of these controls route Paint / ApplySchemeSettings / PerformLayout
	    straight into the skin (Derma_Hook "ListViewColumn" / "ListViewHeaderLabel"),
	    which is where GMod's skin both draws the header and lays the child buttons
	    out.  This fork's skin has none of those hooks, so each one asks the hook
	    first and then does the same work itself (otherwise the header caption would
	    never be drawn or positioned).
	  * `self.Depressed` on the dragger bar is GMod's field; this fork's DButton keeps
	    the same state in m_bDepressed and answers IsDown(), so both are accepted.
	  * Two guards GMod does not need: the column asks its parent for the header
	    height and for SortByColumn, and a column can now be created (and painted)
	    on its own, which the offline harness does for every control.
--]]

local PANEL = {}

--- GMod: Derma_Hook( PANEL, "Paint", "Paint", "ListViewHeaderLabel" ) etc.
function PANEL:Paint( w, h )
	if ( derma.SkinHook( "Paint", "ListViewHeaderLabel", self, w, h ) ) then return true end

	-- fallback: the caption (+ the sort arrow when the column above told us)
	w = w or self:GetWide()
	h = h or self:GetTall()

	local text = self:GetText() or ""
	if ( text == "" ) then return true end

	local font = self:GetFont() or "DermaDefault"
	local tw, th = derma.GetTextSize( font, text )

	derma.DrawText( font, math.floor( ( w - tw ) * 0.5 ), math.floor( ( h - th ) * 0.5 ),
		text, Color( 228, 228, 228, 255 ) )

	return true
end

function PANEL:ApplySchemeSettings()
	derma.SkinHook( "Scheme", "ListViewHeaderLabel", self )
end

function PANEL:PerformLayout( w, h )
	derma.SkinHook( "Layout", "ListViewHeaderLabel", self )
end

function PANEL:Init()
end

-- No example for this control. Why do we have this control?
function PANEL:GenerateExample( class, tabs, w, h )
end

derma.DefineControl( "DListViewHeaderLabel", "", PANEL, "DLabel" )

--[[---------------------------------------------------------
	DListView_DraggerBar
-----------------------------------------------------------]]

local PANEL = {}

function PANEL:Init()

	self:SetCursor( "sizewe" )

end

function PANEL:Paint()

	return true

end

function PANEL:OnCursorMoved()

	-- GMod: if ( self.Depressed ) then ... ; this fork's DButton answers IsDown()
	local bDown = self.Depressed == true or ( self.IsDown ~= nil and self:IsDown() == true )

	if ( bDown ) then

		local x, y = self:GetParent():CursorPos()

		self:GetParent():ResizeColumn( x )
	end

end

-- No example for this control
function PANEL:GenerateExample( class, tabs, w, h )
end

derma.DefineControl( "DListView_DraggerBar", "", PANEL, "DButton" )

--[[---------------------------------------------------------
	DListView_Column
-----------------------------------------------------------]]

local PANEL = {}

AccessorFunc( PANEL, "m_iMinWidth", "MinWidth" )
AccessorFunc( PANEL, "m_iMaxWidth", "MaxWidth" )

AccessorFunc( PANEL, "m_iTextAlign", "TextAlign" )

AccessorFunc( PANEL, "m_bFixedWidth", "FixedWidth" )
AccessorFunc( PANEL, "m_bDesc", "Descending" )
AccessorFunc( PANEL, "m_iColumnID", "ColumnID" )

function PANEL:Init()

	self.Header = vgui.Create( "DButton", self )
	self.Header.DoClick = function() self:DoClick() end
	self.Header.DoRightClick = function() self:DoRightClick() end

	self.DraggerBar = vgui.Create( "DListView_DraggerBar", self )

	self:SetMinWidth( 10 )
	self:SetMaxWidth( 19200 )

end

function PANEL:SetFixedWidth( iSize )

	self:SetMinWidth( iSize )
	self:SetMaxWidth( iSize )
	self:SetWide( iSize )

end

function PANEL:DoClick()

	-- guard: a column can be created on its own (see the header)
	local parent = self:GetParent()

	if ( IsValid( parent ) and parent.SortByColumn ) then
		parent:SortByColumn( self:GetColumnID(), self:GetDescending() )
	end

	self:SetDescending( !self:GetDescending() )

end

function PANEL:DoRightClick()

end

function PANEL:SetName( strName )

	self.Header:SetText( strName )

end

function PANEL:Paint()
	if ( derma.SkinHook( "Paint", "ListViewColumn", self, self:GetWide(), self:GetTall() ) ) then return true end

	-- fallback: nothing to draw - the header button and the dragger paint themselves
	return true
end

function PANEL:ApplySchemeSettings()
	derma.SkinHook( "Scheme", "ListViewColumn", self )
end

--- GMod routes this through the skin too ("Layout" / ListViewColumn); the same work
--- happens here when the skin does not handle it.
function PANEL:PerformLayout()

	if ( derma.SkinHook( "Layout", "ListViewColumn", self ) ) then return end

	if ( self:GetTextAlign() ) then
		self.Header:SetContentAlignment( self:GetTextAlign() )
	end

	local parent = self:GetParent()
	local headerH = ( IsValid( parent ) and parent.GetHeaderHeight ) and parent:GetHeaderHeight() or ( self:GetTall() or 0 )

	self.Header:SetPos( 0, 0 )
	self.Header:SetSize( self:GetWide(), headerH )

	self.DraggerBar:SetPos( math.max( 0, self:GetWide() - 4 ), 0 )
	self.DraggerBar:SetSize( 4, headerH )

end

function PANEL:ResizeColumn( iSize )

	local parent = self:GetParent()

	if ( IsValid( parent ) and parent.OnRequestResize ) then
		parent:OnRequestResize( self, iSize )
	end

end

function PANEL:SetWidth( iSize )

	iSize = math.Clamp( iSize, self:GetMinWidth(), math.max( self:GetMaxWidth(), 0 ) )
	iSize = math.ceil( iSize )

	-- If the column changes size we need to lay the data out too
	if ( iSize != math.ceil( self:GetWide() ) ) then
		local parent = self:GetParent()

		if ( IsValid( parent ) and parent.SetDirty ) then
			parent:SetDirty( true )
		end
	end

	self:SetWide( iSize )
	return iSize

end

derma.DefineControl( "DListView_Column", "Sortable DListView Column", PANEL, "Panel" )

--[[---------------------------------------------------------
	DListView_ColumnPlain
-----------------------------------------------------------]]

local PANEL = {}

function PANEL:DoClick()
end

derma.DefineControl( "DListView_ColumnPlain", "Non sortable DListView Column", PANEL, "DListView_Column" )
