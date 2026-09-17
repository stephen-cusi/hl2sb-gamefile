--[[ DGrid -- a really simple grid layout panel (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DGrid
	  "This panel will set its size automatically based on set column count."
	  Parent: Panel.
	  Methods: AddItem / RemoveItem / GetItems / SetCols / GetCols / SetColWide /
	           GetColWide / SetRowHeight / GetRowHeight / SortByMember / Clear.

	Layout rule (GMod's vgui/dgrid.lua:61-84): every VISIBLE item gets
	`x = ( i % cols ) * colWide`, `y = floor( i / cols ) * rowHeight`, and the grid then
	sizes itself to `cols * colWide` x `rows * rowHeight`.  The wiki warns that this
	fights Panel:Dock and re-runs PerformLayout every frame - kept, because addons
	position themselves against exactly that behaviour (GMod's own spawnmenu/tool
	panels call AddItem and never position the cells themselves).

	Items are children of the grid, so they must be created parentless (`vgui.Create(
	"DButton" )`) or the parent gets overwritten by AddItem - that is GMod's contract
	too (`item:SetParent( self )`).
--]]

local PANEL = {}

function PANEL:Init()
	self.Items = {}

	self.m_iCols = 4
	self.m_iColWide = 32
	self.m_iRowHeight = 32

	-- a container: it must accept mouse input or its children can never be
	-- clicked (see the note in lua/vgui/DPanel.lua)
	self:SetMouseInputEnabled( true )
end

-------------------------------------------------------------------------------
-- columns / cell metrics
-------------------------------------------------------------------------------
function PANEL:SetCols( n )
	self.m_iCols = math.max( 1, math.floor( tonumber( n ) or 1 ) )
	self:InvalidateLayout( true )
end

function PANEL:GetCols()
	return self.m_iCols
end

function PANEL:SetColWide( n )
	self.m_iColWide = math.floor( tonumber( n ) or 0 )
	self:InvalidateLayout( true )
end

function PANEL:GetColWide()
	return self.m_iColWide
end

function PANEL:SetRowHeight( n )
	self.m_iRowHeight = math.floor( tonumber( n ) or 0 )
	self:InvalidateLayout( true )
end

function PANEL:GetRowHeight()
	return self.m_iRowHeight
end

-------------------------------------------------------------------------------
-- items
-------------------------------------------------------------------------------
function PANEL:GetItems()
	return self.Items
end

function PANEL:AddItem( item )
	if ( not IsValid( item ) ) then return end

	item:SetVisible( true )
	item:SetParent( self )

	self.Items[ #self.Items + 1 ] = item

	self:InvalidateLayout( true )
end

function PANEL:RemoveItem( item, bDontDelete )
	for i = #self.Items, 1, -1 do
		if ( self.Items[ i ] == item ) then
			table.remove( self.Items, i )

			if ( not bDontDelete and IsValid( item ) ) then
				item:Remove()
			end

			self:InvalidateLayout( true )
		end
	end
end

function PANEL:Clear()
	for i = #self.Items, 1, -1 do
		local item = self.Items[ i ]

		if ( IsValid( item ) ) then item:Remove() end
	end

	self.Items = {}
	self:InvalidateLayout( true )
end

--- Wiki: "Sorts the items in the grid. Does not visually update the grid, use
--- Panel:InvalidateLayout for that."  desc defaults to TRUE (descending).
function PANEL:SortByMember( key, desc )
	if ( desc == nil ) then desc = true end

	table.sort( self.Items, function( a, b )
		if ( desc ) then
			local t = a
			a = b
			b = t
		end

		if ( a[ key ] == nil ) then return false end
		if ( b[ key ] == nil ) then return true end

		return a[ key ] > b[ key ]
	end )
end

-------------------------------------------------------------------------------
-- layout
-------------------------------------------------------------------------------
function PANEL:PerformLayout( w, h )
	local cols = self.m_iCols
	local colW = self.m_iColWide
	local rowH = self.m_iRowHeight

	local i = 0

	for _, item in ipairs( self.Items ) do
		if ( IsValid( item ) and item:IsVisible() ) then
			item:SetPos( ( i % cols ) * colW, math.floor( i / cols ) * rowH )
			i = i + 1
		end
	end

	-- self-sizing (see the header).  Only written when it actually changes: setting a
	-- size invalidates the layout, and doing that unconditionally inside
	-- PerformLayout is how a grid turns into a per-frame relayout loop.
	local wantW = cols * colW
	local wantH = math.ceil( i / cols ) * rowH

	if ( self:GetWide() ~= wantW ) then self:SetWide( wantW ) end
	if ( self:GetTall() ~= wantH ) then self:SetTall( wantH ) end
end

derma.DefineControl( "DGrid", "A really simple grid layout panel", PANEL, "Panel" )
