--[[ DCategoryList -- a list of collapsible categories (original implementation).

	The spawn menu's tool/content lists are built on this: AddCategory( name,
	icon, help, opencat ) -> category, each category holds a DCollapsibleCategory
	head plus a wrap panel where controls are added. --]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )
	self.m_tCategories = {}
	self.m_strFilter = ""

	self.m_pList = vgui.Create( "DScroller", self, "List" )
	self.m_pList:SetDrawBackground( false )

end

function PANEL:AddCategory( strName, strIcon, bOpen, iSortNum )
	local pnl = vgui.Create( "DPanel", self.m_pList:GetCanvas(), "Category" )
	pnl:SetDrawBackground( false )

	local cat = vgui.Create( "DCollapsibleCategory", pnl, "Collapse" )
	cat:SetLabel( strName )

	local contents = vgui.Create( "DPanel", pnl, "Contents" )
	contents:SetDrawBackground( false )
	cat:SetContents( contents )
	cat.m_bCollapsed = not ( bOpen ~= false )
	cat.m_pBody:SetVisible( bOpen ~= false )

	local entry = { name = strName, pnl = pnl, cat = cat, contents = contents, iSort = iSortNum or 0 }
	table.insert( self.m_tCategories, entry )
	self:Sort()
	return entry
end

--- GMod: DCategoryList:Add( name, icon, help, opencat, table ) -- the wiki's
--- entry point: returns a real DCollapsibleCategory whose SetContents/Add receive
--- the row content (dcategorylist.lua:18-28 wraps AddCategory).  AddCategory stays
--- as the fork's richer internal path; this adapter returns the category PANEL so
--- `cat:SetContents( pnl )` / `cat:Add( ... )` behave like GMod's.
function PANEL:Add( strName, strIcon, strHelp, bOpen, tHookTable )
	local entry = self:AddCategory( strName, strIcon, bOpen )
	if ( not entry ) then return end

	entry.cat.Unwrap = entry.contents
	return entry.cat
end

--- GMod: DCategoryList:AddItem( pnl, name ) -- a wrapped item panel
--- (dcategorylist.lua:10-16): folds the panel into a new category's contents.
function PANEL:AddItem( pnl, strName )
	local cat = self:Add( strName or ( pnl.GetName and pnl:GetName() ) or "Category" )
	if ( not cat ) then return end

	cat:SetContents( pnl )
	return cat
end

--- GMod: DCategoryList:UnselectAll() -- collapse-independent row de-selection
--- used by the spawnmenu's selection machinery (dcategorylist.lua:37-47).
function PANEL:UnselectAll()
	for _, e in ipairs( self.m_tCategories ) do
		if ( IsValid( e.cat ) and e.cat.UnselectAll ) then e.cat:UnselectAll() end
	end
end

function PANEL:GetCategory( strName )
	for _, e in ipairs( self.m_tCategories ) do
		if ( e.name == strName ) then return e end
	end
end

function PANEL:Sort()
	table.sort( self.m_tCategories, function( a, b ) return a.iSort < b.iSort end )

	local y = 0
	for _, e in ipairs( self.m_tCategories ) do
		e.pnl:SetPos( 0, y )
		e.pnl:SetSize( self:GetWide(), 0 )

		-- HL2SB (2026-10-16): a DCollapsibleCategory laid out inside this
		-- wrapper needs its WIDTH set before it can size its rows, and the
		-- wrapper height is measured from the category panel (GMod does the
		-- same through DScrollPanel auto-size).  GetBodyHeight() is the
		-- category's published header + body height, so the measurement does
		-- not depend on PerformLayout having run yet.
		if ( IsValid( e.cat ) and e.cat.GetBodyHeight ) then
			e.cat:SetSize( self:GetWide(), e.cat:GetHeaderHeight() + e.cat:GetBodyHeight() )
		end

		local _, h = e.pnl:GetChildrenSize()
		h = math.max( 24, h or 24 )
		e.pnl:SetTall( h )
		y = y + h + 4
	end

	self.m_pList:RecomputeHeight()
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	self.m_pList:SetPos( 0, 0 )
	self.m_pList:SetSize( w, h )
	self:Sort()
end

--- GMod resolves both of these through the DScrollPanel base
--- (lua/vgui/dscrollpanel.lua:69 Rebuild / :139 Clear), which every GMod
--- DCategoryList inherits.  This fork's DCategoryList is built on a DScroller
--- child instead, so the two methods are provided here: the C context menu's
--- Open() calls `self.Canvas:Clear()` and `self.Canvas:Rebuild()`
--- (gamemodes/sandbox/gamemode/spawnmenu/contextmenu.lua:52-54) whenever an
--- active tool control panel is docked, and without them that call chain died
--- with "attempt to call a nil value (method 'Clear')".
function PANEL:Clear()
	for _, e in ipairs( self.m_tCategories ) do
		if ( IsValid( e.pnl ) ) then e.pnl:Remove() end
	end

	self.m_tCategories = {}
end

function PANEL:Rebuild()
	self:Sort()
	self:InvalidateLayout( true )
end

derma.DefineControl( "DCategoryList", "HL2SB category list", PANEL, "DPanel" )
