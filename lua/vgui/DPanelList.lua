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
	self:Rebuild()

	local h = self.m_iContentHeight or 0

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
--- Wiki: "Used internally to rebuild the child panel positions."
function PANEL:Rebuild()
	local canvas = self:GetCanvas()
	if ( not IsValid( canvas ) ) then return end

	local pad = self:GetPadding()
	local spacing = self:GetSpacing()
	local w = canvas:GetWide()
	local y = pad

	for _, item in ipairs( self.m_tItems ) do
		if ( IsValid( item ) ) then
			item:SetPos( pad, y )

			local itemW = w - pad * 2
			if ( itemW > 0 ) then item:SetWide( itemW ) end

			y = y + item:GetTall() + spacing
		end
	end

	self.m_iContentHeight = y + pad

	-- DScrollPanel owns the canvas size + the bar range
	self:SetContentHeight( self.m_iContentHeight )

	if ( self.m_bAutoSize ) then self:SetTall( math.max( self.m_iContentHeight, 1 ) ) end
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
