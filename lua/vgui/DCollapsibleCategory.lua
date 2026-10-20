--[[ DCollapsibleCategory -- a fold-away group (original implementation). --]]

local PANEL = {}

local HEAD_H = 22

-- HL2SB (2026-10-16): row height for the GMod CategoryList rows created by
-- PANEL:Add below (GMod dcategorycollapse.lua:102 `button:SetHeight( 17 )`).
local ROW_H = 17

function PANEL:Init()
	self:SetDrawBackground( false )
	self.m_bCollapsed = false
	self.m_pContents = nil

	self.m_pHeader = vgui.Create( "DButton", self, "Header" )
	self.m_pHeader:SetDrawBackground( false )
	self.m_pHeader.DoClick = function() self:Toggle() end
	self.m_pHeader.Paint = function( pnl, w, h )
		derma.SkinHook( "Paint", "CategoryHead", self, w, h )
		derma.DrawText( "DermaDefaultBold", 20, math.floor( ( h - 13 ) / 2 ), self.m_strLabel or "",
			Color( 230, 230, 230, 255 ) )
		-- expand/collapse chevron
		local col = Color( 200, 200, 200, 255 )
		surface.DrawSetColor( col.r, col.g, col.b, col.a )
		if ( self.m_bCollapsed ) then
			surface.DrawLine( 6, h / 2 - 3, 10, h / 2 )
			surface.DrawLine( 10, h / 2, 6, h / 2 + 3 )
		else
			surface.DrawLine( 5, h / 2 - 2, 11, h / 2 - 2 )
			surface.DrawLine( 11, h / 2 - 2, 8, h / 2 + 3 )
			surface.DrawLine( 8, h / 2 + 3, 5, h / 2 - 2 )
		end
	end

	self.m_pBody = vgui.Create( "DPanel", self, "Body" )
	self.m_pBody:SetDrawBackground( false )
end

function PANEL:SetLabel( strLabel )
	self.m_strLabel = strLabel
	self.m_pHeader:SetText( "" )
end

function PANEL:SetContents( pnl, bDelete )
	pnl:SetParent( self.m_pBody )
	self.m_pContents = pnl
	self:InvalidateLayout( true )
	if ( IsValid( self:GetParent() ) ) then self:GetParent():InvalidateLayout( true ) end
end

function PANEL:Toggle()
	self:SetExpanded( self.m_bCollapsed )
end

--- GMod: DCollapsibleCategory:OnToggle( expanded ) -- the developer hook Toggle
--- fires (dcategorycollapse.lua:209-231).
function PANEL:OnToggle( expanded )
end

--- GMod: DCollapsibleCategory:DoExpansion( b ) -- programmatic expand/collapse
--- without the OnToggle callback (dcategorycollapse.lua:233-238).
function PANEL:DoExpansion( b )
	self:SetExpanded( b )
end

--- GMod: DCollapsibleCategory:GetExpanded() / SetExpanded( expanded ) -- its
--- AccessorFunc pair plus DoExpansion (gmod/vgui/dcategorycollapse.lua:48/198-233).
--- This fork stores the state inverted in m_bCollapsed, and DCategoryHeader
--- (lua/vgui/DCategoryHeader.lua, ported later) is what made the gap visible:
--- its UpdateColours asks `self:GetParent():GetExpanded()`.
function PANEL:GetExpanded()
	return not self.m_bCollapsed
end

function PANEL:SetExpanded( bExpanded )
	local bWas = self:GetExpanded()

	self.m_bCollapsed = not bExpanded

	if ( IsValid( self.m_pBody ) ) then
		self.m_pBody:SetVisible( not self.m_bCollapsed )
	end

	self:InvalidateLayout( true )

	-- GMod fires the developer hook when Toggle changed the state
	-- (dcategorycollapse.lua:226-230)
	if ( bWas ~= self:GetExpanded() ) then
		self:OnToggle( self:GetExpanded() )
	end
end

--- GMod: DCollapsibleCategory:SetHeaderHeight( h ) / GetHeaderHeight()
--- (dcategorycollapse.lua:156-166).  The fork used a fixed HEAD_H; honour an
--- override.
AccessorFunc( PANEL, "m_iHeaderHeight", "HeaderHeight", FORCE_NUMBER )

function PANEL:GetHeaderHeight()
	return self.m_iHeaderHeight or HEAD_H
end

function PANEL:IsExpanded()
	return not self.m_bCollapsed
end

function PANEL:GetContents()
	return self.m_pContents
end

--- HL2SB (2026-10-16): the body height now also answers for rows added through
--- PANEL:Add (GMod DCollapsibleCategory:Add, reference
--- dcategorycollapse.lua:75) and for a SetContents panel that sizes itself from
--- its own children -- a category inside a DCategoryList is measured with
--- Panel:GetChildrenSize(), so a category that never publishes a height keeps
--- the whole group at the list's 24px minimum and its rows are never laid out.
function PANEL:GetBodyHeight()

	if ( self.m_bCollapsed ) then return 0 end

	local bodyH = ( self.m_iRowCount or 0 ) * ROW_H

	if ( IsValid( self.m_pContents ) ) then
		local _, ch = self.m_pContents:GetChildrenSize()
		bodyH = math.max( bodyH, self.m_pContents:GetTall(), ch or 0 )
	end

	return bodyH

end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()

	local headH = self:GetHeaderHeight()
	local bodyH = self:GetBodyHeight()

	self.m_pHeader:SetPos( 0, 0 )
	self.m_pHeader:SetSize( w, headH )

	if ( IsValid( self.m_pContents ) ) then
		self.m_pContents:SetPos( 0, 0 )
		self.m_pContents:SetSize( w, bodyH )
	end

	self.m_pBody:SetPos( 0, headH )
	self.m_pBody:SetSize( w, bodyH )

	if ( self:GetTall() != headH + bodyH ) then self:SetTall( headH + bodyH ) end
end

--- GMod: DCollapsibleCategory:Add( strName ) -- the row entry point that
--- gamemodes/sandbox/gamemode/spawnmenu/toolpanel.lua:250 uses for every tool
--- name (reference dcategorycollapse.lua:75-122).  Rows live in the contents
--- panel when one was SetContents() (that is what DCategoryList:AddCategory
--- installs) and in the body otherwise; the fork's body/contents panels are
--- plain DPanels, so a docked DButton is the row.  The returned button is the
--- exact surface toolpanel.lua drives: DoClick / DoRightClick / SetEnabled /
--- IsEnabled / SetSelected / SetTooltip / .Name / .Text / .ConVar.
function PANEL:Add( strName )

	local body = self.m_pContents
	if ( !IsValid( body ) ) then body = self.m_pBody end
	if ( !IsValid( body ) ) then return nil end

	local button = vgui.Create( "DButton", body )
	button:Dock( TOP )
	button:SetTall( ROW_H )
	button:SetContentAlignment( 4 )
	button:SetText( strName or "" )
	button.DoClickInternal = function()

		if ( self:GetList() ) then
			self:GetList():UnselectAll()
		else
			self:UnselectAll()
		end

		if ( button.SetSelected ) then button:SetSelected( true ) end

	end

	self.m_iRowCount = ( self.m_iRowCount or 0 ) + 1
	self:UpdateAltLines()
	self:InvalidateLayout( true )

	return button

end

--- GMod: DCollapsibleCategory:UnselectAll() (reference dcategorycollapse.lua:124).
function PANEL:UnselectAll()

	for _, v in ipairs( self:GetChildren() ) do
		if ( v.SetSelected ) then v:SetSelected( false ) end
	end

	for _, v in ipairs( self.m_pBody:GetChildren() ) do
		if ( v.SetSelected ) then v:SetSelected( false ) end
	end

	if ( IsValid( self.m_pContents ) ) then
		for _, v in ipairs( self.m_pContents:GetChildren() ) do
			if ( v.SetSelected ) then v:SetSelected( false ) end
		end
	end

end

--- GMod: DCollapsibleCategory:UpdateAltLines() (reference dcategorycollapse.lua:136).
function PANEL:UpdateAltLines()

	local n = 0
	for _, v in ipairs( self.m_pBody:GetChildren() ) do
		n = n + 1
		v.AltLine = ( n % 2 ) != 1
	end
	if ( IsValid( self.m_pContents ) ) then
		for _, v in ipairs( self.m_pContents:GetChildren() ) do
			n = n + 1
			v.AltLine = ( n % 2 ) != 1
		end
	end

end

--- GMod: AccessorFunc( PANEL, "m_pList", "List" ) (reference
--- dcategorycollapse.lua:54) -- DCategoryList:Add attaches the owning list so a
--- row click can clear the list's selection.
function PANEL:SetList( list )
	self.m_pList = list
end

function PANEL:GetList()
	return self.m_pList
end

derma.DefineControl( "DCollapsibleCategory", "HL2SB collapsible group", PANEL, "DPanel" )
