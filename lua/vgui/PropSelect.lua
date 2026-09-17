--[[ PropSelect -- a grid of model thumbnails that sets a convar (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/PropSelect
	  Parent: ContextBase.  AddModel( model, conVars ), AddModelEx( value, model,
	  skin ), Clear, FindModelByValue, SelectModel, FindAndSelectButton,
	  TestForChanges, OnSelect / OnRightClick (overrides), ControlValues( kv ),
	  and the List / Controls / Height members.

	Ported from GMod's lua/vgui/propselect.lua (231 lines).  It is what DForm's
	PropSelect row and the spawnmenu's model panels build, and its base -
	ContextBase - was ported two rounds ago.

	Substitutions this fork needs:
	  * The hover highlight is GMod's `GWEN.CreateTextureBorder` over
	    materials/gui/ps_hover.png; there is no GWEN here, so the same white frame
	    is drawn with surface.* (the SpawnIcon port documents the same swap).
	  * `LocalPlayer():ConCommand( ... )` (the Player method) does not exist in this
	    fork; RunConsoleCommand does the same job for the local player, so it is
	    used when ConCommand is missing.
--]]

local PANEL = {}

local border = 0
local border_w = 8
local matHover = Material( "gui/ps_hover.png", "nocull" )

-- GMod: GWEN.CreateTextureBorder( ... ).  No GWEN in this fork - see the header.
local boxHover = nil

if ( GWEN and GWEN.CreateTextureBorder and matHover ) then
	boxHover = GWEN.CreateTextureBorder( border, border, 64 - border * 2, 64 - border * 2,
		border_w, border_w, border_w, border_w, matHover )
end

-- This function is used as the paint function for selected buttons.
local function HighlightedButtonPaint( self, w, h )

	if ( boxHover ) then
		boxHover( 0, 0, w, h, color_white )
		return
	end

	surface.SetDrawColor( 255, 255, 255, 255 )

	for i = 0, border_w - 1 do
		surface.DrawOutlinedRect( i, i, w - i, h - i )
	end

end

--- GMod: LocalPlayer():ConCommand( str ) -- absent here, RunConsoleCommand is the
--- local player's console.
local function RunCommand( strCmd )
	local ply = LocalPlayer()

	if ( IsValid( ply ) and ply.ConCommand ) then
		ply:ConCommand( strCmd )
	else
		RunConsoleCommand( string.Trim( strCmd ) )
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

	Derma_Hook( self.List, "Paint", "Paint", "Panel" )

	self.Controls = {}
	self.Height = 2

end

function PANEL:AddModel( model, ConVars )
	if ( ConVars && !istable( ConVars ) ) then
		ErrorNoHaltWithStack( "bad argument #2 to 'PropSelect.AddModel' (table expected, got " .. type( ConVars ) .. ")" )
		ConVars = nil
	end

	-- Creeate a spawnicon and set the model
	local Icon = vgui.Create( "SpawnIcon", self )
	Icon:SetModel( model )
	Icon:SetTooltip( model )
	Icon.Model = model
	Icon.Value = model
	Icon.ConVars = ConVars || {}

	local ConVarName = self:ConVar()

	-- Run a console command when the Icon is clicked
	Icon.DoClick = function( pnl )
		self:SelectModel( pnl )

		self:OnSelect( pnl.Model, pnl )

		for k, v in pairs( pnl.ConVars ) do
			RunCommand( string.format( "%s \"%s\"\n", k, v ) )
		end

		-- Note: We run this command after all the optional stuff
		if ( ConVarName ) then RunCommand( string.format( "%s \"%s\"\n", ConVarName, model ) ) end
	end
	Icon.OpenMenu = function( button )
		self:OnRightClick( button )
	end

	-- Add the Icon us
	self.List:AddItem( Icon )
	table.insert( self.Controls, Icon )

	return Icon
end

function PANEL:AddModelEx( value, model, skin )
	-- Creeate a spawnicon and set the model
	local icon = vgui.Create( "SpawnIcon", self )
	icon:SetModel( model, skin )
	icon:SetTooltip( model )
	icon.Model = model
	icon.Value = value
	icon.ConVars = {}

	local ConVarName = self:ConVar()

	-- Run a console command when the Icon is clicked
	icon.DoClick = function( pnl )
		self:SelectModel( pnl )

		self:OnSelect( pnl.Model, pnl )

		if ( ConVarName ) then RunCommand( string.format( "%s \"%s\"\n", ConVarName, icon.Value ) ) end
	end
	icon.OpenMenu = function( button )
		self:OnRightClick( button )
	end

	-- Add the Icon us
	self.List:AddItem( icon )
	table.insert( self.Controls, icon )

	return icon
end

function PANEL:Clear()

	for k, icon in pairs( self.Controls ) do
		icon:Remove()
		self.Controls[k] = nil
	end

	self.List:CleanList()
	self.SelectedIcon = nil
	self.OldSelectedPaintOver = nil

end

function PANEL:ControlValues( kv )

	self.BaseClass.ControlValues( self, kv )

	self.Height = kv.height || 2

	-- Load the list of models from our keyvalues file
	-- This is the old way

	if ( kv.models ) then
		for k, v in SortedPairs( kv.models ) do
			self:AddModel( k, v )
		end
	end

	--
	-- Passing in modelstable is the new way
	--
	if ( kv.modelstable ) then
		local tmp = {} -- HACK: Order by skin too.
		for k, v in SortedPairsByMemberValue( kv.modelstable, "model" ) do
			tmp[ k ] = v.model:lower() .. ( v.skin || 0 )
		end

		for k, v in SortedPairsByValue( tmp ) do
			v = kv.modelstable[ k ]
			self:AddModelEx( k, v.model, v.skin || 0 )
		end
	end

	self:InvalidateLayout( true )

end

function PANEL:PerformLayout( w, h )

	local y = self.BaseClass.PerformLayout( self, w, h )

	if ( self.Height >= 1 ) then
		local Height = ( 64 + self.List:GetSpacing() ) * math.max( self.Height, 1 ) + self.List:GetPadding() * 2 - self.List:GetSpacing()

		self.List:SetPos( 0, y )
		self.List:SetSize( self:GetWide(), Height )

		y = y + Height

		self:SetTall( y + 5 )
	else -- Height is set to 0 or less, auto stretch
		self.List:SetWide( self:GetWide() )
		self.List:SizeToChildren( false, true )
		self:SetTall( self.List:GetTall() + 5 )
	end

end

function PANEL:FindModelByValue( value )

	for k, icon in pairs( self.Controls ) do
		if ( icon.Model == value || icon.Value == value ) then return icon end
	end

end

function PANEL:SelectModel( icon )

	-- Remove the old overlay
	if ( self.SelectedIcon ) then
		self.SelectedIcon.PaintOver = self.OldSelectedPaintOver
	end

	-- Add the overlay to this button
	self.OldSelectedPaintOver = icon.PaintOver
	icon.PaintOver = HighlightedButtonPaint
	self.SelectedIcon = icon
	self.CurrentValue = icon.Value

end

function PANEL:FindAndSelectButton( value )

	local icon = self:FindModelByValue( value )
	if ( !icon ) then return end

	self:SelectModel( icon )

end

function PANEL:TestForChanges()

	local cvar = self:ConVar()
	if ( !cvar ) then return end

	local value = GetConVarString( cvar )
	if ( value == self.CurrentValue ) then return end

	self:FindAndSelectButton( value )

end

function PANEL:OnSelect( material, pnl )

	-- For override

end

function PANEL:OnRightClick( button )

	-- For override

	local menu = DermaMenu()
	menu:AddOption( "#spawnmenu.menu.copy", function() SetClipboardText( button.Model ) end ):SetIcon( "icon16/page_copy.png" )
	menu:Open()

end

derma.DefineControl( "PropSelect", "A grid of model thumbnails that sets a convar", PANEL, "ContextBase" )
