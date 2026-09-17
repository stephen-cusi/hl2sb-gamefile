--[[ DColumnSheet -- a sheet whose tabs run down a column (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DColumnSheet
	  Parent: Panel.  AddSheet( label, panel, material ), SetActiveButton(
	  button ), UseButtonOnlyStyle(), GetActiveButton(), and the Navigation /
	  Content / Items members it builds.

	Ported from GMod's lua/vgui/dcolumnsheet.lua (85 lines).  The tabs are normal
	DButtons docked down a DScrollPanel on the left; DImageButton is used instead
	when UseButtonOnlyStyle() was called.

	Notes for this fork:
	  * `Sheet.Button:SetImage( material )` is guarded: GMod calls it on a plain
	    DButton (which reaches its DLabel base), while this fork's DButton has no
	    SetImage - DImageButton is the control that owns one.
	  * SetToggle is used the way GMod does (the active tab stays "held"); this
	    fork's DButton has SetToggle/GetToggle and tints a toggled button, so the
	    highlight is visible.
--]]

local PANEL = {}

AccessorFunc( PANEL, "ActiveButton", "ActiveButton" )

function PANEL:Init()
	self.Navigation = vgui.Create( "DScrollPanel", self )
	self.Navigation:Dock( LEFT )
	self.Navigation:SetWidth( 100 )
	self.Navigation:DockMargin( 10, 10, 10, 0 )

	self.Content = vgui.Create( "Panel", self )
	self.Content:Dock( FILL )

	self.Items = {}
end

function PANEL:UseButtonOnlyStyle()
	self.ButtonOnly = true
end

function PANEL:AddSheet( label, panel, material )
	if ( !IsValid( panel ) ) then return end

	local Sheet = {}

	if ( self.ButtonOnly ) then
		Sheet.Button = vgui.Create( "DImageButton", self.Navigation )
	else
		Sheet.Button = vgui.Create( "DButton", self.Navigation )
	end

	if ( Sheet.Button.SetImage ) then
		Sheet.Button:SetImage( material )
	end

	Sheet.Button.Target = panel
	Sheet.Button:Dock( TOP )
	Sheet.Button:SetText( label )
	Sheet.Button:DockMargin( 0, 1, 0, 0 )

	Sheet.Button.DoClick = function()
		self:SetActiveButton( Sheet.Button )
	end

	Sheet.Panel = panel
	Sheet.Panel:SetParent( self.Content )
	Sheet.Panel:SetVisible( false )

	if ( self.ButtonOnly and Sheet.Button.SizeToContents ) then
		Sheet.Button:SizeToContents()
	end

	table.insert( self.Items, Sheet )

	if ( !IsValid( self.ActiveButton ) ) then
		self:SetActiveButton( Sheet.Button )
	end

	return Sheet
end

function PANEL:SetActiveButton( active )
	if ( self.ActiveButton == active ) then return end

	if ( self.ActiveButton and self.ActiveButton.Target ) then
		self.ActiveButton.Target:SetVisible( false )

		if ( self.ActiveButton.SetSelected ) then self.ActiveButton:SetSelected( false ) end
		if ( self.ActiveButton.SetToggle ) then self.ActiveButton:SetToggle( false ) end
	end

	self.ActiveButton = active
	active.Target:SetVisible( true )

	if ( active.SetSelected ) then active:SetSelected( true ) end
	if ( active.SetToggle ) then active:SetToggle( true ) end

	self.Content:InvalidateLayout()
end

derma.DefineControl( "DColumnSheet", "A column of tabs", PANEL, "Panel" )
