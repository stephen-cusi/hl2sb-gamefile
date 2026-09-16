--[[ DPropertySheet -- tabbed container (original implementation). --]]

local PANEL = {}

local TAB_H = 22

function PANEL:Init()
	self:SetDrawBackground( false )
	self.m_tTabs = {}
	self.m_pActive = nil

	self.m_pTabBar = vgui.Create( "DPanel", self, "TabStrip" )
	self.m_pTabBar:SetDrawBackground( false )

	self.m_pScroller = vgui.Create( "DScroller", self, "Scroller" )
	self.m_pScroller:SetDrawBackground( false )
end

function PANEL:AddSheet( strLabel, pnl, strIcon, bStretch, bDoScroll )
	local tab = vgui.Create( "DButton", self.m_pTabBar, "Tab" )
	tab:SetText( strLabel )
	tab.m_pSheetPanel = pnl

	pnl:SetParent( self.m_pScroller )
	pnl:SetVisible( false )

	local entry = { tab = tab, pnl = pnl, label = strLabel }
	table.insert( self.m_tTabs, entry )

	tab.DoClick = function() self:Activate( entry ) end

	if ( #self.m_tTabs == 1 ) then self:Activate( entry ) end
	self:InvalidateLayout( true )
	return entry
end

function PANEL:Activate( entry )
	for _, e in ipairs( self.m_tTabs ) do
		e.pnl:SetVisible( e == entry )
		e.tab.m_bDepressed = ( e == entry )
	end
	self.m_pActive = entry
end

function PANEL:GetActiveTab()
	return self.m_pActive
end

function PANEL:GetPanel( i )
	local e = self.m_tTabs[ i ]
	return e and e.pnl
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	self.m_pTabBar:SetPos( 0, 0 )
	self.m_pTabBar:SetSize( w, TAB_H )

	local x = 0
	for _, e in ipairs( self.m_tTabs ) do
		e.tab:SetPos( x, 0 )
		e.tab:SetSize( 90, TAB_H )
		x = x + 92
	end

	self.m_pScroller:SetPos( 0, TAB_H + 2 )
	self.m_pScroller:SetSize( w, math.max( 0, h - TAB_H - 2 ) )
end

derma.DefineControl( "DPropertySheet", "HL2SB tab container", PANEL, "DPanel" )
