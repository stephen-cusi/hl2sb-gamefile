--[[ MatSelect -- a grid of material thumbnails (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/MatSelect
	  Parent: ContextBase.  AddMaterial( label, value ), AddMaterialEx( label,
	  material, value, convars ), SelectMaterial( mat ), FindMaterialByValue,
	  FindAndSelectMaterial, Clear, SetItemSize, SetItemWidth / SetItemHeight,
	  NumRows (the `Height` field), AutoHeight, OnSelect / OnRightClick overrides.

	Ported from GMod's lua/vgui/matselect.lua (274 lines).  It is the material
	picker of the Material/Lamp/Colour tools: a DPanelList of DImageButtons, with the
	selected one wearing a hover-frame PaintOver.

	Notes for this fork:
	  * GWEN is absent here, so the `GWEN.CreateTextureBorder` hover frame is guarded
	    exactly like lua/vgui/PropSelect.lua:33-50 does it - ask GWEN first, otherwise
	    draw the same frame with surface.DrawOutlinedRect.
	  * GMod reads `self.List.VBar.Enabled` as a boolean field (its DVScrollBar keeps
	    one); this fork's DScrollBar answers Enabled() as a method, so VBarVisible()
	    below takes both.
	  * GMod registers this control with vgui.Register (no derma metadata, and no
	    global); this fork's derma.DefineControl is used instead so MatSelect lands in
	    the same registry as every other control (and gets published as a global like
	    the rest - see AGENTS.md 5.0.8).
	  * `self.BaseClass.ControlValues( self, kv )` is the framework's parent-class
	    proxy, the same call PropSelect makes.
--]]

local PANEL = {}

AccessorFunc( PANEL, "ItemWidth", "ItemWidth", FORCE_NUMBER )
AccessorFunc( PANEL, "ItemHeight", "ItemHeight", FORCE_NUMBER )
AccessorFunc( PANEL, "Height", "NumRows", FORCE_NUMBER )
AccessorFunc( PANEL, "m_bSizeToContent", "AutoHeight", FORCE_BOOL )

local border = 0
local border_w = 8
local matHover = Material( "gui/ps_hover.png", "nocull" )

-- GMod: GWEN.CreateTextureBorder( ... ).  No GWEN in this fork - see the header.
local boxHover = nil

if ( GWEN and GWEN.CreateTextureBorder and matHover ) then
	boxHover = GWEN.CreateTextureBorder( border, border, 64 - border * 2, 64 - border * 2,
		border_w, border_w, border_w, border_w, matHover )
end

--- this fork's DScrollBar answers Enabled() as a method, GMod's DVScrollBar has the
--- field (see the header)
local function VBarVisible( list )
	local bar = list and list.VBar

	if ( !IsValid( bar ) ) then return false end
	if ( isfunction( bar.Enabled ) ) then return bar:Enabled() and true or false end

	return bar.Enabled == true
end

-- This function is used as the paint function for selected buttons
function PANEL:SelectedItemPaintOver( w, h )

	-- self in this context would be the selected item!
	if ( boxHover ) then
		boxHover( 0, 0, w, h, color_white )
		return
	end

	surface.DrawSetColor( 255, 255, 255, 255 )

	for i = 0, border_w - 1 do
		surface.DrawOutlinedRect( i, i, w - i, h - i )
	end

end

function PANEL:Init()

	-- A panellist is a panel that you shove other panels
	-- into and it makes a nice organised frame.
	self.List = vgui.Create( "DPanelList", self )
	self.List:EnableHorizontal( true )
	self.List:EnableVerticalScrollbar()
	self.List:SetSpacing( 1 )
	self.List:SetPadding( 3 )

	self.Controls = {}
	self.Height = 2

	self:SetItemWidth( 128 )
	self:SetItemHeight( 128 )

end

function PANEL:SetAutoHeight( bAutoHeight )

	self.m_bSizeToContent = bAutoHeight
	self.List:SetAutoSize( bAutoHeight )

	self:InvalidateLayout()

end

function PANEL:AddMaterial( label, value )

	local Mat = vgui.Create( "DImageButton", self )
	Mat:SetOnViewMaterial( value, "models/wireframe" )
	Mat:SetTooltip( label )
	Mat.AutoSize = false
	Mat.Value = value
	self:SetItemSize( Mat )

	Mat.DoClick = function( button )
		-- Select the material
		self:SelectMaterial( button )

		self:OnSelect( button.Value, button )

		-- Update the convar
		if ( self:ConVar() ) then RunConsoleCommand( self:ConVar(), value ) end
	end

	Mat.DoRightClick = function( button )
		self:OnRightClick( button )
	end

	-- Add the icon to ourselves
	self.List:AddItem( Mat )
	table.insert( self.Controls, Mat )

	self:InvalidateLayout()

	return Mat

end

function PANEL:AddMaterialEx( label, material, value, convars )

	local Mat = vgui.Create( "DImageButton", self )
	Mat:SetImage( material )
	Mat:SetTooltip( label )
	Mat.AutoSize = false
	Mat.Value = value
	Mat.ConVars = convars
	self:SetItemSize( Mat )

	Mat.DoClick = function ( button )
		-- Can't do this due to faceposer
		-- self:SelectMaterial( button )

		self:OnSelect( button.Value, button )

		-- Update the convars
		for cvar, val in pairs( convars ) do RunConsoleCommand( cvar, val ) end
	end

	Mat.DoRightClick = function( button )
		self:OnRightClick( button )
	end

	-- Add the icon to ourselves
	self.List:AddItem( Mat )
	table.insert( self.Controls, Mat )

	self:InvalidateLayout()

	return Mat

end

function PANEL:SelectMaterial( mat )

	-- Restore the current overlay
	if ( self.SelectedMaterial ) then
		self.SelectedMaterial.PaintOver = self.OldSelectedPaintOver
	end

	-- Add the overlay to this button
	self.OldSelectedPaintOver = mat.PaintOver
	mat.PaintOver = self.SelectedItemPaintOver

	-- Set our selected values
	self.SelectedMaterial = mat
	self.CurrentValue = mat.Value

end

function PANEL:Clear()

	for k, Mat in pairs( self.Controls ) do
		Mat:Remove()
		self.Controls[k] = nil
	end

	self.List:CleanList()
	self.SelectedMaterial = nil
	self.OldSelectedPaintOver = nil

end

function PANEL:FindMaterialByValue( value )

	for k, Mat in pairs( self.Controls ) do
		if ( Mat.Value == value ) then return Mat end
	end

end

function PANEL:SetItemSize( pnl )

	local maxW = self:GetWide()
	if ( VBarVisible( self.List ) ) then maxW = maxW - self.List.VBar:GetWide() end

	local w = self.ItemWidth
	if ( w < 1 ) then
		local numIcons = math.floor( 1 / w )
		w = math.floor( ( maxW - self.List:GetPadding() * 2 - self.List:GetSpacing() * ( numIcons - 1 ) ) / numIcons )
	end

	local h = self.ItemHeight
	if ( h < 1 ) then
		local numIcons = math.floor( 1 / h )
		h = math.floor( ( maxW - self.List:GetPadding() * 2 - self.List:GetSpacing() * ( numIcons - 1 ) ) / numIcons )
	end

	pnl:SetSize( w, h )

end

function PANEL:ControlValues( kv )

	self.BaseClass.ControlValues( self, kv )

	self.Height = kv.height or 2

	-- Load the list of models from our keyvalues file
	if ( kv.options ) then

		for k, v in pairs( kv.options ) do
			self:AddMaterial( k, v )
		end

	end

	self.ItemWidth = kv.itemwidth or 32
	self.ItemHeight = kv.itemheight or 32

	for k, v in pairs( self.Controls ) do
		v:SetSize( self.ItemWidth, self.ItemHeight )
	end

	self:InvalidateLayout()

end

function PANEL:PerformLayout()

	self.List:SetPos( 0, 0 )

	for k, v in pairs( self.List:GetItems() ) do
		self:SetItemSize( v )
	end

	if ( self.m_bSizeToContent ) then
		self.List:SetWide( self:GetWide() )
		self.List:InvalidateLayout( true )
		self:SetTall( self.List:GetTall() + 5 )

		return
	end

	self.List:InvalidateLayout( true ) -- Rebuild

	local maxW = self:GetWide()
	if ( VBarVisible( self.List ) ) then maxW = maxW - self.List.VBar:GetWide() end

	local h = self.ItemHeight
	if ( h < 1 ) then
		local numIcons = math.floor( 1 / h )
		h = math.floor( ( maxW - self.List:GetPadding() * 2 - self.List:GetSpacing() * ( numIcons - 1 ) ) / numIcons )
	end

	local Height = ( h * self.Height ) + ( self.List:GetPadding() * 2 ) + self.List:GetSpacing() * ( self.Height - 1 )

	self.List:SetSize( self:GetWide(), Height )
	self:SetTall( Height + 5 )

end

function PANEL:FindAndSelectMaterial( value )

	self.CurrentValue = value
	local mat = self:FindMaterialByValue( value )
	if ( !mat ) then return end

	self:SelectMaterial( mat )

end

function PANEL:TestForChanges()

	local cvar = self:ConVar()
	if ( !cvar ) then return end

	local value = GetConVarString( cvar )
	if ( value == self.CurrentValue ) then return end

	self:FindAndSelectMaterial( value )

end

function PANEL:OnSelect( material, pnl )

	-- For override

end

function PANEL:OnRightClick( button )

	-- For override

	local menu = DermaMenu()
	menu:AddOption( "#spawnmenu.menu.copy", function() SetClipboardText( button.Value ) end ):SetIcon( "icon16/page_copy.png" )
	menu:Open()

end

-- GMod registers this control through vgui.Register (no derma metadata, and no
-- global); this fork's derma.DefineControl is used instead so MatSelect lands in the
-- same registry as every other control.  See the header note.
derma.DefineControl( "MatSelect", "A grid of material thumbnails", PANEL, "ContextBase" )
