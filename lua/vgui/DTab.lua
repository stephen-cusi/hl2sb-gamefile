--[[ DTab -- one tab of a DPropertySheet (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DTab
	  Parent: DButton.  A tab is created by DPropertySheet:AddSheet, carries the page
	  it shows (Setup( label, sheet, panel, material )), reports IsActive() and
	  activates itself on click.  Its caption colour comes from Skin.Colours.Tab.

	Ported from GMod's lua/vgui/dpropertysheet.lua:1-141 (the DTab half of that file;
	GMod defines the tab and the sheet in one file, this fork keeps one control per
	file).

	Notes for this fork:
	  * GMod's tab calls DLabel.ApplySchemeSettings( self ) at the end of its own
	    ApplySchemeSettings, because a DButton *is* a DLabel there.  This fork's
	    DButton derives from DPanel, whose ApplySchemeSettings is the one that runs
	    UpdateColours - so that is what is called here (same effect: the tab's
	    update of Skin.Colours.Tab.* climbs in).
	  * GetContentSize / SizeToContents are DLabel methods in GMod and were missing
	    from this fork's DButton; they were added to lua/vgui/DButton.lua with this
	    port, which is what lets a tab size itself from its caption.
	  * GMod's tab routes Paint through Derma_Hook( "Paint", "Tab" ) and its skin
	    draws the strip.  This fork's skin has no PaintTab, so Paint below asks that
	    hook first and then paints the same strip every other button gets, plus the
	    caption and an active-tab tint.
	  * DPropertySheet:SetActiveTab / GetActiveTab / Items are what IsActive and
	    DoClick talk to; they were added to this fork's sheet with this port.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_pPropertySheet", "PropertySheet" )
AccessorFunc( PANEL, "m_pPanel", "Panel" )

-- GMod's line here is:  Derma_Hook( PANEL, "Paint", "Paint", "Tab" )
-- i.e. "route Paint through the skin's Tab hook, and nothing else".  This fork's skin
-- has no PaintTab, so that would leave an invisible tab; the explicit PANEL:Paint at
-- the bottom of this file asks the same hook first and then paints the fallback strip.

function PANEL:Init()

	self:SetMouseInputEnabled( true )
	self:SetContentAlignment( 7 )
	self:SetTextInset( 0, 4 )

end

function PANEL:Setup( label, pPropertySheet, pPanel, strMaterial )

	self:SetText( label )
	self:SetPropertySheet( pPropertySheet )
	self:SetPanel( pPanel )

	if ( strMaterial ) then

		self.Image = vgui.Create( "DImage", self )
		self.Image:SetImage( strMaterial )
		self.Image:SizeToContents()
		self:InvalidateLayout()

	end

end

function PANEL:IsActive()
	-- this fork's guard: the harness (and any addon) can create a bare DTab with no
	-- sheet yet, and GMod's unguarded version would index nil there
	local sheet = self:GetPropertySheet()

	if ( !IsValid( sheet ) or sheet.GetActiveTab == nil ) then return false end

	return sheet:GetActiveTab() == self
end

function PANEL:DoClick()

	self:GetPropertySheet():SetActiveTab( self )

end

function PANEL:PerformLayout()

	self:ApplySchemeSettings()

	if ( !self.Image ) then return end

	self.Image:SetPos( 7, 3 )

	if ( !self:IsActive() ) then
		self.Image:SetImageColor( Color( 255, 255, 255, 155 ) )
	else
		self.Image:SetImageColor( color_white )
	end

end

function PANEL:UpdateColours( skin )

	if ( self:IsActive() ) then

		if ( !self:IsEnabled() ) then return self:SetTextStyleColor( skin.Colours.Tab.Active.Disabled ) end
		if ( self:IsDown() ) then return self:SetTextStyleColor( skin.Colours.Tab.Active.Down ) end
		if ( self.Hovered ) then return self:SetTextStyleColor( skin.Colours.Tab.Active.Hover ) end

		return self:SetTextStyleColor( skin.Colours.Tab.Active.Normal )

	end

	if ( !self:IsEnabled() ) then return self:SetTextStyleColor( skin.Colours.Tab.Inactive.Disabled ) end
	if ( self:IsDown() ) then return self:SetTextStyleColor( skin.Colours.Tab.Inactive.Down ) end
	if ( self.Hovered ) then return self:SetTextStyleColor( skin.Colours.Tab.Inactive.Hover ) end

	return self:SetTextStyleColor( skin.Colours.Tab.Inactive.Normal )

end

function PANEL:GetTabHeight()

	if ( self:IsActive() ) then
		return 28
	else
		return 20
	end

end

function PANEL:ApplySchemeSettings()

	local ExtraInset = 10

	if ( self.Image ) then
		ExtraInset = ExtraInset + self.Image:GetWide()
	end

	self:SetTextInset( ExtraInset, 4 )

	-- GMod: local w, h = self:GetContentSize(); h = self:GetTabHeight()
	--       self:SetSize( w + 10, h ); DLabel.ApplySchemeSettings( self )
	local w, h = self:GetContentSize()
	h = self:GetTabHeight()

	self:SetSize( w + 10, h )

	DButton.ApplySchemeSettings( self )

end

--
-- DragHoverClick
--
function PANEL:DragHoverClick( HoverTime )

	self:DoClick()

end

function PANEL:GenerateExample()

	-- Do nothing!

end

function PANEL:DoRightClick()

	if ( !IsValid( self:GetPropertySheet() ) ) then return end

	local tabs = DermaMenu()
	for k, v in pairs( self:GetPropertySheet().Items ) do
		if ( !v || !IsValid( v.Tab ) || !v.Tab:IsVisible() ) then continue end
		local option = tabs:AddOption( v.Tab:GetText(), function()
			if ( !v || !IsValid( v.Tab ) || !IsValid( self:GetPropertySheet() ) || !IsValid( self:GetPropertySheet().tabScroller ) ) then return end
			v.Tab:DoClick()
			self:GetPropertySheet().tabScroller:ScrollToChild( v.Tab )
		end )
		if ( IsValid( v.Tab.Image ) ) then option:SetIcon( v.Tab.Image:GetImage() ) end
	end
	tabs:Open()

end

--- GMod's tab paints through Derma_Hook( "Paint", "Tab" ); this fork's skin has no
--- PaintTab, so this is the same hook call plus the fallback strip and caption.
function PANEL:Paint( w, h )

	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( derma.SkinHook( "Paint", "Tab", self, w, h ) ) then return end

	derma.SkinHook( "Paint", "Button", self, w, h )

	if ( self:IsActive() ) then
		-- the active tab is the tall one; the tint makes it read at a glance
		surface.DrawSetColor( 52, 108, 190, 90 )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	local text = self.m_strText or ""
	if ( text == "" ) then return end

	local font = self.m_strFont or "DermaDefault"
	local tw, th = derma.GetTextSize( font, text )

	-- ⚠️ The caption is centred in the box that is LEFT of the text inset, not in the
	-- whole tab: vgui2's Label::Paint draws inside `_textInset` (ContentAlignment 7 =
	-- south, i.e. the horizontal centre of the inset region).  GMod's tab sizes itself
	-- as "caption + inset + 10", so centring across the full width slides the caption
	-- left, under the icon -- that is what the icon tab looked like in game on
	-- 2026-09-17 (the "t" of "third" was behind the page icon).
	local insetX, insetY = self:GetTextInset()
	insetX, insetY = insetX or 0, insetY or 0

	derma.DrawText( font,
		insetX + math.floor( ( ( w - insetX ) - tw ) * 0.5 ),
		insetY + math.floor( ( ( h - insetY ) - th ) * 0.5 ),
		text, self:GetTextStyleColor() or Color( 228, 228, 228, 255 ) )

end

derma.DefineControl( "DTab", "A Tab for use on the PropertySheet", PANEL, "DButton" )
