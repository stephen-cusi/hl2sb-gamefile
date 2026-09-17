--[[ DPropertySheet -- tabbed container (original implementation, GMod-aligned API).

	Wiki: https://wiki.facepunch.com/gmod/DPropertySheet
	  AddSheet( label, panel, material ), SetActiveTab( tab ) / GetActiveTab(),
	  GetPanel( i ), Items, SetupCloseButton( func ), OnActiveTabChanged - and the
	  tabs themselves are lua/vgui/DTab.lua.

	This fork's sheet is its own implementation (a DPanel holding a tab strip and a
	DScroller), but the parts GMod code and addons reach for are the same:

	  * `Items` -- the list of { Name, Tab, Panel } entries AddSheet returns.
	  * `GetActiveTab()` returns the active *tab control* (GMod), not the entry;
	    `m_pActive` keeps this fork's entry for its own layout code.
	  * `tabScroller` is an alias of the tab strip, and answers AddPanel /
	    ScrollToChild the way GMod's DHorizontalScroller does.
	  * The pages are sized by this control's own PerformLayout, exactly like GMod's
	    (dpropertysheet.lua:337-352): the page fills the area under the tab strip minus
	    the padding, or keeps its size when AddSheet was given NoStretchX/NoStretchY
	    (the 4th/5th arguments - GMod passes `true, true` in every GenerateExample).

	⚠️ Tabs are positioned but NOT scrolled: GMod's tab strip is a
	DHorizontalScroller, so a long tab list pans.  Here the tabs simply run off the
	right-hand edge (the same before this change); ScrollToChild invalidates the
	layout and does nothing else.  Worth doing when a real DHorizontalScroller tab
	strip is wanted.
--]]

local PANEL = {}

local TAB_H = 22			-- inactive tab height (GMod's DTab:GetTabHeight)
local TABBAR_H = 28		-- the active tab is the tall one, so the strip is 28
local TAB_GAP = 2
local PADDING = 8		-- GMod: self:SetPadding( 8 ) in Init

function PANEL:Init()
	self:SetDrawBackground( false )

	-- GMod's name for the list; m_tTabs is this fork's older name for the same table
	self.Items = {}
	self.m_tTabs = self.Items
	self.m_pActive = nil
	self.m_pActiveTab = nil
	self.m_iPadding = PADDING

	self.m_pTabBar = vgui.Create( "DPanel", self, "TabStrip" )
	self.m_pTabBar:SetDrawBackground( false )

	-- GMod: self.tabScroller = vgui.Create( "DHorizontalScroller", self )
	-- (see the header note about scrolling)
	self.tabScroller = self.m_pTabBar

	self.m_pTabBar.AddPanel = function( bar, pnl )
		pnl:SetParent( bar )
		return pnl
	end

	self.m_pTabBar.ScrollToChild = function( bar, pnl )
		bar:InvalidateLayout( true )
	end

	self.m_pScroller = vgui.Create( "DScroller", self, "Scroller" )
	self.m_pScroller:SetDrawBackground( false )
end

--- GMod: DPropertySheet:AddSheet( label, panel, material, NoStretchX, NoStretchY ) ->
--- the sheet entry.  ⚠️ The 4th/5th arguments mean "do NOT stretch this axis" in
--- GMod (every GenerateExample in GMod passes `true, true`), not "stretch".
function PANEL:AddSheet( strLabel, pnl, strIcon, bNoStretchX, bNoStretchY )
	local tab = vgui.Create( "DTab", self.m_pTabBar, "Tab" )
	tab:Setup( strLabel, self, pnl, strIcon )

	pnl:SetParent( self.m_pScroller )
	pnl:SetVisible( false )
	pnl.NoStretchX = bNoStretchX
	pnl.NoStretchY = bNoStretchY

	-- both naming schemes, so GMod code (entry.Name/.Tab/.Panel) and this fork's
	-- own layout code (entry.label/.tab/.pnl) read the same entry
	local entry = {
		Name = strLabel,	Tab = tab,		Panel = pnl,
		label = strLabel,	tab = tab,		pnl = pnl,
	}
	table.insert( self.m_tTabs, entry )

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
	self.m_pActiveTab = entry and entry.tab or nil

	-- GMod: SetActiveTab ends with self:InvalidateLayout().  The tabs' heights are only
	-- settled in PerformLayout (it re-runs each tab's scheme), so without this the strip
	-- keeps the old tall/shallow pair after a switch.
	self:InvalidateLayout( true )
end

--- GMod: DPropertySheet:GetActiveTab() -> the active DTab.
function PANEL:GetActiveTab()
	return self.m_pActiveTab
end

--- GMod: DPropertySheet:SetActiveTab( tab ) -- what DTab:DoClick calls.
function PANEL:SetActiveTab( tab )
	if ( !IsValid( tab ) ) then return end
	if ( self.m_pActiveTab == tab ) then return end

	local entry

	for _, e in ipairs( self.m_tTabs ) do
		if ( e.tab == tab ) then entry = e break end
	end

	if ( !entry ) then return end

	local old = self.m_pActiveTab
	self:Activate( entry )

	if ( IsValid( old ) ) then
		self:OnActiveTabChanged( old, tab )
	end
end

--- GMod: overridable callback, only run when a tab is actually switched.
function PANEL:OnActiveTabChanged( old, new )
end

function PANEL:GetPanel( i )
	local e = self.m_tTabs[ i ]
	return e and e.pnl
end

--- GMod: DPropertySheet:SetPadding / GetPadding (AccessorFunc m_iPadding).  Used as the
--- border between the page and the sheet, and to inset the pages from the tab strip.
function PANEL:SetPadding( i ) self.m_iPadding = i end
function PANEL:GetPadding() return self.m_iPadding or PADDING end

--- GMod: DPropertySheet:SetupCloseButton( func ) -- "Adds a close button to the
--- right side of the tab bar" (its dpropertysheet.lua:391).  DColorCombo inherits
--- it, and prop_vectorcolor uses it to put a close button on the colour popup.
--- GMod docks the button in `self.tabScroller`; this fork's sheet has no scroller,
--- so it is docked into the tab bar itself.
function PANEL:SetupCloseButton( func )
	if ( IsValid( self.CloseButton ) ) then self.CloseButton:Remove() end

	local parent = self.m_pTabBar or self

	self.CloseButton = vgui.Create( "DImageButton", parent )
	self.CloseButton:SetImage( "icon16/circlecross.png" )
	self.CloseButton:SetColor( Color( 10, 10, 10, 200 ) )
	self.CloseButton:DockMargin( 1, 1, 1, 9 )
	self.CloseButton:SetWide( 18 )
	self.CloseButton:Dock( RIGHT )
	self.CloseButton.DoClick = function()
		if ( func ) then func() end
	end
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	self.m_pTabBar:SetPos( 0, 0 )
	self.m_pTabBar:SetSize( w, TABBAR_H )

	-- DTab sizes itself (its ApplySchemeSettings runs PerformLayout), so only the
	-- x matters here, and the active (taller) tab sits on the strip's bottom edge.
	-- ⚠️ GMod re-runs every tab's scheme in this very loop (dpropertysheet.lua:333) --
	-- that is what re-measures the tabs after the active one changed, so the tab that
	-- just became active grows to 28 and the one that stopped being active shrinks to
	-- 20.  Without it the previously active tab keeps its height: in game the strip
	-- showed two tall tabs (2026-09-17).
	local x = 0
	for _, e in ipairs( self.m_tTabs ) do
		e.tab:ApplySchemeSettings()

		local tw = e.tab:GetWide()
		local th = e.tab:GetTall()

		if ( tw <= 0 ) then tw = 90 end
		if ( th <= 0 ) then th = TAB_H end

		e.tab:SetPos( x, math.max( 0, TABBAR_H - th ) )
		x = x + tw + TAB_GAP
	end

	self.m_pScroller:SetPos( 0, TABBAR_H + 2 )
	self.m_pScroller:SetSize( w, math.max( 0, h - TABBAR_H - 2 ) )

	-- GMod sizes the pages in the sheet's own PerformLayout (dpropertysheet.lua:337-352):
	-- the page fills the area under the tab strip minus the padding, unless the sheet was
	-- told not to stretch that axis (then it is centred instead).  It does this for every
	-- page, visible or not.
	-- ⚠️ Without this the page keeps the engine's default panel size and every child is
	-- clipped to it: in game on 2026-09-17 the demo's page label came out as "this is the
	-- tl" - a 64px-wide page cutting a 330px captioned label, not a label bug.
	local pad = self:GetPadding()
	local sw, sh = self.m_pScroller:GetWide(), self.m_pScroller:GetTall()

	for _, e in ipairs( self.m_tTabs ) do
		local page = e.pnl

		if ( IsValid( page ) ) then
			local pw, ph = math.max( 0, sw - pad * 2 ), math.max( 0, sh - pad * 2 )
			local px, py = pad, pad

			if ( page.NoStretchX ) then
				pw = page:GetWide()
				px = math.max( 0, math.floor( ( sw - pw ) * 0.5 ) )
			end

			if ( page.NoStretchY ) then
				ph = page:GetTall()
				py = math.max( 0, math.floor( ( sh - ph ) * 0.5 ) )
			end

			page:SetPos( px, py )
			page:SetSize( pw, ph )
		end
	end
end

derma.DefineControl( "DPropertySheet", "HL2SB tab container", PANEL, "DPanel" )
