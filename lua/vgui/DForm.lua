--[[ DForm -- the "quick form" panel (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DForm
	  "A panel with quick methods to create basic user inputs."  Parent:
	  DCollapsibleCategory.  One method per input type - TextEntry, ComboBox,
	  NumberWang, NumSlider, CheckBox, Button, PropSelect, PanelSelect, ListBox,
	  Help, ControlHelp - plus Clear, AddItem, SetName, Rebuild, and the Items /
	  Padding / Spacing members.

	Ported from GMod's lua/vgui/dform.lua (312 lines) onto this fork's
	DCollapsibleCategory, DSizeToContents, DPanelList, DComboBox, DNumberWang,
	DNumSlider, DCheckBoxLabel and PropSelect - every one of which now exists.

	Notes for this fork:
	  * `SetConsoleCommand` on a DButton (used by DForm:Button) is not a GMod
	    method either; the button gets a DoClick that runs the command, which is
	    what GMod's does (see DForm:Button).
	  * `SetAutoStretchVertical` on a label is now real in DLabel (word wrap), which
	    is what Help/ControlHelp rely on.
	  * DForm:ListBox creates a "DListBox", which this fork does not have (it is not
	    on the wiki's control list either); the method returns a DListView-based
	    list instead and says so.
--]]

local PANEL = {}

DEFINE_BASECLASS( "DCollapsibleCategory" )

AccessorFunc( PANEL, "m_bSizeToContents", "AutoSize", FORCE_BOOL )
AccessorFunc( PANEL, "m_iSpacing", "Spacing" )
AccessorFunc( PANEL, "m_Padding", "Padding" )

function PANEL:Init()

	self.Items = {}

	self:SetSpacing( 4 )
	self:SetPadding( 10 )

	if ( self.SetPaintBackground ) then self:SetPaintBackground( true ) end

	self:SetMouseInputEnabled( true )
	self:SetKeyboardInputEnabled( true )

end

function PANEL:SetName( name )

	if ( self.SetLabel ) then self:SetLabel( name ) end

end

function PANEL:Clear()

	for k, v in pairs( self.Items ) do

		if ( IsValid( v ) ) then v:Remove() end

	end

	self.Items = {}

end

function PANEL:AddItem( left, right )

	self:InvalidateLayout()

	local Panel = vgui.Create( "DSizeToContents", self )
	Panel:SetSizeX( false )

	if ( Panel.Dock ) then Panel:Dock( TOP ) end

	Panel:DockPadding( 10, 10, 10, 0 )
	Panel:InvalidateLayout()

	if ( IsValid( right ) ) then

		left:SetParent( Panel )
		left:Dock( LEFT )
		left:InvalidateLayout( true )
		left:SetSize( 100, 20 )

		right:SetParent( Panel )
		right:SetPos( 110, 0 )
		right:InvalidateLayout( true )

	elseif ( IsValid( left ) ) then

		left:SetParent( Panel )
		left:Dock( TOP )

	end

	table.insert( self.Items, Panel )

end

function PANEL:TextEntry( strLabel, strConVar )

	local left = vgui.Create( "DLabel", self )
	left:SetText( strLabel )
	left:SetDark( true )

	local right = vgui.Create( "DTextEntry", self )
	right:SetConVar( strConVar )
	right:Dock( TOP )

	self:AddItem( left, right )

	return right, left

end

function PANEL:PropSelect( label, convar, models, height )

	local props = vgui.Create( "PropSelect", self )

	props:SetConVar( convar or "" )
	props.Label:SetText( label or "" )

	props.Height = height or 2

	local firstKey, firstVal = next( models )
	if ( firstVal.model == nil ) then

		-- Lowercase model names for sorting purposes
		local models_lower = table.LowerKeyNames( models )

		-- list.Get where key is the model and value is the cvars to set when that model is selected
		for k, v in SortedPairs( models_lower ) do
			props:AddModel( k, v )
		end

	else

		local tmp = {} -- HACK: Order by skin too
		for k, v in SortedPairsByMemberValue( models, "model" ) do
			tmp[ k ] = v.model:lower() .. ( v.skin or 0 )
		end

		for k, v in SortedPairsByValue( tmp ) do
			v = models[ k ]
			local icon = props:AddModelEx( k, v.model, v.skin or 0 )
			if ( v.tooltip ) then icon:SetTooltip( v.tooltip ) end
		end

	end

	props:InvalidateLayout( true )

	-- GMod calls self:AddPanel( props ) here, but its own DCollapsibleCategory
	-- (gmod/vgui/dcategorycollapse.lua) defines no AddPanel - only DMenu,
	-- DHorizontalScroller, DPanelSelect and DTree_Node do - so that call could only
	-- throw.  The form's own row adder is used instead, which is how every other
	-- DForm control is added.
	self:AddItem( props, nil )

	return props

end

function PANEL:ComboBox( strLabel, strConVar )

	local left = vgui.Create( "DLabel", self )
	left:SetText( strLabel )
	left:SetDark( true )

	local right = vgui.Create( "DComboBox", self )
	right:SetConVar( strConVar )
	right:Dock( FILL )
	function right:OnSelect( index, value, data )
		if ( !self.m_strConVar ) then return end
		RunConsoleCommand( self.m_strConVar, tostring( data or value ) )
	end

	self:AddItem( left, right )

	return right, left

end

function PANEL:NumberWang( strLabel, strConVar, numMin, numMax, numDecimals )

	local left = vgui.Create( "DLabel", self )
	left:SetText( strLabel )
	left:SetDark( true )

	local right = vgui.Create( "DNumberWang", self )
	right:SetMinMax( numMin, numMax )

	if ( numDecimals != nil ) then right:SetDecimals( numDecimals ) end

	right:SetConVar( strConVar )
	right:SizeToContents()

	self:AddItem( left, right )

	return right, left

end

function PANEL:NumSlider( strLabel, strConVar, numMin, numMax, numDecimals )

	local left = vgui.Create( "DNumSlider", self )
	left:SetText( strLabel )
	left:SetMinMax( numMin, numMax )
	left:SetDark( true )

	if ( numDecimals != nil ) then left:SetDecimals( numDecimals ) end

	left:SetConVar( strConVar )
	if ( left.SizeToContents ) then left:SizeToContents() end

	if ( strConVar ) then
		local cvar = GetConVar( strConVar )
		if ( cvar ) then
			local defaultValue = tonumber( cvar:GetDefault() )
			if ( defaultValue && left.SetDefaultValue ) then left:SetDefaultValue( defaultValue ) end
		end
	end

	self:AddItem( left, nil )

	return left

end

function PANEL:CheckBox( strLabel, strConVar )

	local left = vgui.Create( "DCheckBoxLabel", self )
	left:SetText( strLabel )
	left:SetDark( true )
	left:SetConVar( strConVar )

	self:AddItem( left, nil )

	return left

end

function PANEL:Help( strHelp )

	local left = vgui.Create( "DLabel", self )

	left:SetDark( true )
	left:SetWrap( true )
	left:SetTextInset( 0, 0 )
	left:SetText( strHelp )
	left:SetContentAlignment( 7 )
	left:SetAutoStretchVertical( true )
	left:DockMargin( 8, 0, 8, 8 )

	self:AddItem( left, nil )

	left:InvalidateLayout( true )

	return left

end

function PANEL:ControlHelp( strHelp )

	local Panel = vgui.Create( "DSizeToContents", self )
	Panel:SetSizeX( false )
	Panel:Dock( TOP )
	Panel:InvalidateLayout()

	local left = vgui.Create( "DLabel", Panel )
	left:SetDark( true )
	left:SetWrap( true )
	left:SetTextInset( 0, 0 )
	left:SetText( strHelp )
	left:SetContentAlignment( 5 )
	left:SetAutoStretchVertical( true )
	left:DockMargin( 32, 0, 32, 8 )
	left:Dock( TOP )

	local skin = self:GetSkin()
	if ( skin and skin.Colours and skin.Colours.Tree ) then
		left:SetTextColor( skin.Colours.Tree.Hover )
	end

	table.insert( self.Items, Panel )

	return left

end

--[[---------------------------------------------------------
	Note: If you're running a console command like "maxplayers 10" you
	need to add the "10" to the arguments, like so
	Button( "LabelName", "maxplayers", "10" )
-----------------------------------------------------------]]
function PANEL:Button( strName, strConCommand, ... --[[ console command args!! --]] )

	local left = vgui.Create( "DButton", self )

	if ( strConCommand ) then
		local args = { ... }

		if ( left.SetConsoleCommand ) then
			left:SetConsoleCommand( strConCommand, ... )
		else
			-- GMod's SetConsoleCommand binds the click to the command (and the
			-- arguments); this is the same behaviour without the method.
			left.DoClick = function()
				RunConsoleCommand( strConCommand, unpack( args ) )
			end
		end
	end

	left:SetText( strName )
	self:AddItem( left, nil )

	return left

end

function PANEL:PanelSelect()

	local left = vgui.Create( "DPanelSelect", self )
	self:AddItem( left, nil )
	return left

end

function PANEL:ListBox( strLabel )

	local left = nil
	if ( strLabel ) then
		left = vgui.Create( "DLabel", self )
		left:SetText( strLabel )
		self:AddItem( left )
		left:SetDark( true )
	end

	-- GMod creates a "DListBox" here; this fork has no such control (it is not on
	-- the wiki's VGUI element list either), so the closest equivalent - a
	-- DListView - is used so the method still returns something usable.
	local right = vgui.Create( "DListView", self )
	right.Stretch = true

	self:AddItem( right )

	return right, left

end

function PANEL:Rebuild()
end

-- No example for this control
function PANEL:GenerateExample( class, tabs, w, h )
end

derma.DefineControl( "DForm", "A panel with quick methods to create basic user inputs.", PANEL, "DCollapsibleCategory" )
