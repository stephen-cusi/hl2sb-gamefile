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

derma.DefineControl( "DCategoryList", "HL2SB category list", PANEL, "DPanel" )
