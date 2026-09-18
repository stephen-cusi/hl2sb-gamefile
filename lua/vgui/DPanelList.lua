--[[ DPanelList -- a scrollable list of panels (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DPanelList
	  "Displays elements in a horizontal or vertical list. A scrollbar is automatically
	   shown if necessary.  You can get its vertical bar via DPanelList.VBar."
	  Deprecated since version 13 ("use DIconLayout / DListLayout / DScrollPanel"), but
	  still shipped and still used - the Horror Maps gamemode builds its body-control
	  page out of one (`bdcontrols:Add( "DPanelList" )`, `:EnableVerticalScrollbar(true)`,
	  `:Clear()`, `:AddItem(pnl)`).
	  Methods: AddItem / CleanList / Clear( remove ) / EnableVerticalScrollbar /
	           GetItems / GetPadding / SetPadding / GetSpacing / SetSpacing /
	           InsertAtTop / Rebuild / SetAutoSize
	  GMod also ships InsertBefore/InsertAfter/RemoveItem/ScrollToChild/SortByMember/
	  SizeToContents/EnableHorizontal and the StretchHorizontally/NoSizing/Sortable/
	  AnimTime/DraggableName accessors - all of them are here too.

	⚠️ Base class: GMod derives it from DPanel and owns a scrollbar + canvas itself; this
	fork already has a working scroll container (lua/vgui/DScrollPanel.lua), so DPanelList
	is built on top of THAT and inherits its canvas, bar, wheel handling and clipping.
	The wiki's API is unchanged, and `DPanelList.VBar` is published as a field so the
	older scripts that poke the bar keep working.
--]]

local PANEL = {}

-- The base implementation this file's layout chains to.  ⚠️ Deliberately NOT
-- `self.BaseClass`: for a derived control (DPanelSelect, DModelSelect...) that proxy
-- resolves from the *parent* class, so after this file defines PerformLayout,
-- self.BaseClass.PerformLayout would be this very function and the call below would
-- recurse until the stack blows.
DEFINE_BASECLASS( "DScrollPanel" )

AccessorFunc( PANEL, "m_bAutoSize", "AutoSize", FORCE_BOOL )
AccessorFunc( PANEL, "m_bStretchHorizontally", "StretchHorizontally", FORCE_BOOL )
AccessorFunc( PANEL, "m_bNoSizing", "NoSizing", FORCE_BOOL )
AccessorFunc( PANEL, "m_bSortable", "Sortable", FORCE_BOOL )
AccessorFunc( PANEL, "m_fAnimTime", "AnimTime", FORCE_NUMBER )
AccessorFunc( PANEL, "m_fAnimEase", "AnimEase", FORCE_NUMBER )
AccessorFunc( PANEL, "m_strDraggableName", "DraggableName" )

function PANEL:Init()
	-- DScrollPanel:Init already ran (the derma framework calls the chain's Inits
	-- root-most first), so the canvas and the bar exist by now.
	self.m_tItems = {}
	self.m_iSpacing = 4
	self.m_bAutoSize = false
	self.m_bSortable = false

	-- GMod's own field names: its dpanellist.lua uses AccessorFunc on `Items`,
	-- `Padding` and `Spacing`, and ported GMod code reads them directly
	-- (`dlistbox.lua:107 for k, panel in pairs( self.Items )`, `:106 self.Padding`,
	-- `:115 self.Spacing`).  They are aliases of this fork's m_t*/m_i* fields.
	self.Items = self.m_tItems
	self.Padding = 0
	self.Spacing = self.m_iSpacing

	if ( self.m_iPadding == nil ) then self.m_iPadding = 0 end

	-- the name the wiki promises
	self.VBar = self:GetVBar()
end

-------------------------------------------------------------------------------
-- items
-------------------------------------------------------------------------------
function PANEL:GetItems()
	return self.m_tItems
end

--- Wiki: "Adds a existing panel to the end of DPanelList."
function PANEL:AddItem( pnl, strLineState )
	if ( not IsValid( pnl ) ) then return end

	pnl:SetParent( self:GetCanvas() )
	pnl:SetVisible( true )

	if ( strLineState and pnl.SetLineState ) then
		pcall( pnl.SetLineState, pnl, strLineState )
	end

	self.m_tItems[ #self.m_tItems + 1 ] = pnl

	self:Rebuild()

	return pnl
end

--- Wiki: "Insert given panel at the top of the list."
function PANEL:InsertAtTop( insert, strLineState )
	if ( not IsValid( insert ) ) then return end

	table.insert( self.m_tItems, 1, insert )
	insert:SetParent( self:GetCanvas() )

	self:Rebuild()

	return insert
end

--- GMod's name for the same idea, with an explicit neighbour.
function PANEL:InsertBefore( before, insert, strLineState )
	local idx = self:FindItem( before )

	if ( idx == nil ) then return self:InsertAtTop( insert, strLineState ) end

	table.insert( self.m_tItems, idx, insert )
	insert:SetParent( self:GetCanvas() )
	self:Rebuild()

	return insert
end

function PANEL:InsertAfter( before, insert, strLineState )
	local idx = self:FindItem( before )

	if ( idx == nil ) then return self:InsertAtTop( insert, strLineState ) end

	table.insert( self.m_tItems, idx + 1, insert )
	insert:SetParent( self:GetCanvas() )
	self:Rebuild()

	return insert
end

function PANEL:FindItem( pnl )
	for i, item in ipairs( self.m_tItems ) do
		if ( item == pnl ) then return i end
	end

	return nil
end

function PANEL:RemoveItem( pnl, bDontDelete )
	local idx = self:FindItem( pnl )

	if ( idx == nil ) then return end

	table.remove( self.m_tItems, idx )

	if ( not bDontDelete and IsValid( pnl ) ) then pnl:Remove() end

	self:Rebuild()
end

--- Wiki: "Hides all child panels, and optionally deletes them."
function PANEL:Clear( remove )
	for i = #self.m_tItems, 1, -1 do
		local item = self.m_tItems[ i ]

		if ( IsValid( item ) ) then
			item:SetVisible( false )

			if ( remove ) then item:Remove() end
		end

		if ( remove ) then table.remove( self.m_tItems, i ) end
	end

	self:Rebuild()
end

--- Wiki: "Removes all items."
function PANEL:CleanList()
	for i = #self.m_tItems, 1, -1 do
		local item = self.m_tItems[ i ]

		if ( IsValid( item ) ) then item:Remove() end

		table.remove( self.m_tItems, i )
	end

	self:Rebuild()
end

-------------------------------------------------------------------------------
-- metrics
-------------------------------------------------------------------------------
function PANEL:SetPadding( n )
	self.m_iPadding = math.max( 0, math.floor( tonumber( n ) or 0 ) )
	self.Padding = self.m_iPadding			-- GMod's field name (see Init)

	self:Rebuild()
end

function PANEL:GetPadding()
	return self.m_iPadding or 0
end

function PANEL:SetSpacing( n )
	self.m_iSpacing = math.max( 0, math.floor( tonumber( n ) or 0 ) )
	self.Spacing = self.m_iSpacing			-- GMod's field name (see Init)

	self:Rebuild()
end

function PANEL:GetSpacing()
	return self.m_iSpacing or 0
end

--- Wiki: "Enables/creates the vertical scroll bar so that the panel list can be scrolled
--- through."  (The fork's DScrollPanel always owns the bar; this forces it on.)
function PANEL:EnableVerticalScrollbar( bEnable )
	local bar = self:GetVBar()

	if ( IsValid( bar ) ) then
		bar:SetEnabled( bEnable ~= false )
	end
end

--- GMod's pair for the horizontal case: this fork's DScrollPanel is vertical only, so
--- the flag is recorded and nothing else happens (documented, not silent).
function PANEL:EnableHorizontal( bHoriz )
	self.m_bHorizontal = bHoriz and true or false
end

function PANEL:SizeToContents()
	-- arrange now: Rebuild() only defers (see below), and the height is read right here
	local h = self:ArrangeItems()

	self:SetContentHeight( h )

	if ( self:GetParent() and self:GetParent().ContentSizeChanged ) then
		self:GetParent():ContentSizeChanged( self:GetWide(), h )
	end

	self:SetTall( math.max( h, 1 ) )
end

function PANEL:SortByMember( key, desc )
	-- GMod sorts unconditionally here (lua/vgui/dpanellist.lua:SortByMember has no
	-- gate); this fork used to return early unless SetSortable( true ) had been
	-- called, which silently turned DModelSelect's `SortByMember( "Model" )` into a
	-- no-op (its thumbnails came out in `pairs()` order).  Sortable is kept as an
	-- accessor, it just no longer gates the sort.
	if ( desc == nil ) then desc = true end

	table.sort( self.m_tItems, function( a, b )
		if ( desc ) then
			local t = a
			a = b
			b = t
		end

		if ( a[ key ] == nil ) then return false end
		if ( b[ key ] == nil ) then return true end

		return a[ key ] > b[ key ]
	end )

	self:Rebuild()
end

function PANEL:ScrollToChild( pnl )
	local _, y = pnl:GetPos()

	self:SetValue( math.max( 0, ( y or 0 ) - ( self:GetTall() / 2 ) ) )
end

-------------------------------------------------------------------------------
-- layout
-------------------------------------------------------------------------------
--- Place every visible item and return the content height.
---
--- ⚠️ This is GMod's PerformLayout body, and it MUST run after the canvas has its real
--- width - see PANEL:PerformLayout below for the bug that taught us that.
function PANEL:ArrangeItems()
	local canvas = self:GetCanvas()
	if ( not IsValid( canvas ) ) then return 0 end

	local pad = self:GetPadding()
	local spacing = self:GetSpacing()
	local w = canvas:GetWide()
	local contentH = 0

	if ( self.m_bHorizontal ) then
		-- GMod: dpanellist.lua Rebuild(), the Horizontal branch.  Items sit
		-- left-to-right and wrap to the next row when they run out of width;
		-- DPanelSelect calls EnableHorizontal( true ) for its icon grid.
		--
		-- `lineState == "ownline"` (the category headers in GMod's player model
		-- selector) both starts a new row AND ends one - GMod:
		--     if ( x > self.Padding && ( x + w > self:GetWide() || OwnLine ) ) then
		--         x = self.Padding  y = y + prevH + self.Spacing  end
		--     ... place ...
		--     if ( OwnLine ) then x = self.Padding  y = y + h + self.Spacing  end
		-- Without the second half the first icon would sit next to the header.
		--
		-- Only VISIBLE items take space: the Quick Filter hides icons and then calls
		-- InvalidateLayout, and the grid has to close the gap they leave.
		local x = pad
		local y = pad
		local rowH = 0

		for _, item in ipairs( self.m_tItems ) do
			if ( IsValid( item ) and item:IsVisible() ) then
				local itemW = item:GetWide()
				local itemH = item:GetTall()
				local bOwnLine = ( item.m_strLineState == "ownline" )

				-- wrap (and a section header always gets a fresh row)
				if ( x > pad and ( x + itemW > w - pad or bOwnLine ) ) then
					x = pad
					y = y + rowH + spacing
					rowH = 0
				end

				item:SetPos( x, y )
				x = x + itemW + spacing

				if ( itemH > rowH ) then rowH = itemH end

				if ( bOwnLine ) then
					x = pad
					y = y + rowH + spacing
					rowH = 0
				end
			end
		end

		contentH = y + rowH + pad
	else
		-- vertical stack (original behaviour)
		local y = pad

		for _, item in ipairs( self.m_tItems ) do
			if ( IsValid( item ) and item:IsVisible() ) then
				item:SetPos( pad, y )

				local itemW = w - pad * 2
				if ( itemW > 0 ) then item:SetWide( itemW ) end

				y = y + item:GetTall() + spacing
			end
		end

		contentH = y + pad
	end

	self.m_iContentHeight = contentH

	return contentH
end

--- Set the scrollbar range from a content height.  Deliberately does NOT go through
--- DScrollPanel:SetContentHeight(): that one calls InvalidateLayout( true ), and vgui2's
--- Panel::InvalidateLayout( true ) performs the layout *immediately*
--- (vgui2/vgui_controls/Panel.cpp), so calling it from inside PerformLayout would
--- recurse for ever.
function PANEL:ApplyContentHeight( h )
	local canvas = self:GetCanvas()
	local bar = self:GetVBar()

	h = h or 0

	self.m_iContentHeight = h
	self.m_iRange = math.max( 0, h - canvas:GetTall() )
	bar:SetEnabled( self.m_iRange > 0 )

	-- re-clamp the pixel offset against the range above
	self:SetValue( self:GetValue() )

	if ( self.m_bAutoSize and self:GetTall() != math.max( h, 1 ) ) then
		self:SetTall( math.max( h, 1 ) )
	end
end

--- Wiki: "Used internally to rebuild the child panel positions."
function PANEL:Rebuild()
	-- ⚠️ 2026-09-17 - the reason the icon grid came out as ONE COLUMN: this used to run
	-- the whole arrangement from here, and the only callers are AddItem / Clear /
	-- SetSpacing / ... i.e. while the list is still being built.  Back then the canvas
	-- was 1 px wide (DScrollPanel sizes it in PerformLayout, which had not run yet), so
	-- every icon satisfied `x + itemW > canvasW` and wrapped onto its own row, and
	-- nothing re-ran the arithmetic once the canvas reached its real width.
	-- Deferring to the layout pass is what fixes it: PerformLayout is where the canvas
	-- gets its size, and it arranges from there.
	self:InvalidateLayout( false )
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	-- The base (DScrollPanel) sizes the canvas and the bar.  The bar only claims its
	-- width while it is ENABLED, so a bar that just turned visible narrows the canvas
	-- and can push one more item onto the next row - measure twice when that happened.
	local function LayoutCanvas()
		if ( BaseClass and isfunction( BaseClass.PerformLayout ) ) then
			BaseClass.PerformLayout( self, w, h )
			return
		end

		-- Insurance: if the base class cannot be resolved (baseclass.Get is the only
		-- route to it) the canvas would stay 1 px wide and the grid would silently
		-- collapse back into the single column this file exists to fix.  Size the canvas
		-- and the bar exactly like DScrollPanel:PerformLayout does.
		local pad = self.m_iPadding or 0
		local bar = self:GetVBar()
		local canvas = self:GetCanvas()
		local barW = bar:Enabled() and 14 or 0

		canvas:SetPos( pad, pad )
		canvas:SetSize( math.max( 1, w - barW - 2 * pad ), math.max( 1, h - 2 * pad ) )
		bar:SetPos( w - 14, 0 )
		bar:SetSize( 14, h )
	end

	local function Pass()
		LayoutCanvas()

		local contentH = self:ArrangeItems()
		local canvas = self:GetCanvas()
		local bar = self:GetVBar()
		local bWanted = ( contentH > canvas:GetTall() )
		local bChanged = ( bar:Enabled() ~= bWanted )

		self:ApplyContentHeight( contentH )

		return bChanged
	end

	if ( Pass() ) then Pass() end
end

--- GMod raises this when the list scrolls; kept as an overridable event.
function PANEL:OnVScroll( iOffset )
	self:SetValue( iOffset or 0 )
end

function PANEL:Paint( w, h )
	if ( not self.m_bDrawBackground ) then return end

	derma.SkinHook( "Paint", "Panel", self, w or self:GetWide(), h or self:GetTall() )
end

function PANEL:OnChildRemoved()
	self:Rebuild()
end

derma.DefineControl( "DPanelList", "A scrollable list of panels", PANEL, "DScrollPanel" )
