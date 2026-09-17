--[[ ImageCheckBox -- a checkbox whose checked state is an image (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/ImageCheckBox
	  "A checkbox panel similar to DCheckBox and DImageButton with customizable
	  checked state image.  Uses the Material panel internally.  Can't have a
	  label."  Parent: Button.
	  GetChecked(), Set( OnOff ), SetChecked( bOn ), SetMaterial( string mat ) --
	  "Sets the material that will be visible when the ImageCheckBox is checked.
	  Internally calls Material:SetMaterial."
	  The wiki example ("Check list") is reproduced by hl2sb_derma_wiki ImageCheckBox.

	Ported from GMod's lua/vgui/imagecheckbox.lua (67 lines).  The image is a
	lua/vgui/Material.lua panel, which is why that control had to be ported first.

	Deliberate deviation: base is DButton, not the engine's "Button" (GMod registers
	it on Button).  This fork's C Button fires DoClick in C++ and ignores a Lua
	DoClick field, so the toggle below would never run on it -- the same reason
	lua/vgui/DButton.lua exists at all.
--]]

local PANEL = {}

function PANEL:SetMaterial( On )
	if ( self.MatOn ) then
		self.MatOn:Remove()
	end

	self.MatOn = vgui.Create( "Material", self )
	self.MatOn:SetSize( 16, 16 )
	self.MatOn:SetMaterial( On )

	self:InvalidateLayout( true )
end

function PANEL:SetChecked( bOn )
	if ( self.State == bOn ) then return end
	self.MatOn:SetVisible( bOn )
	self.State = bOn
end

function PANEL:GetChecked()
	return self.State
end

function PANEL:Set( bOn )
	self:SetChecked( bOn )
end

function PANEL:DoClick()
	self:SetChecked( !self.State )
end

function PANEL:SizeToContents()
	if ( self.MatOn ) then
		self:SetSize( self.MatOn:GetWide(), self.MatOn:GetTall() )
	end

	self:InvalidateLayout()
end

function PANEL:Paint()
	draw.RoundedBox( 4, 0, 0, self:GetWide(), self:GetTall(), Color( 0, 0, 0, 50 ) )
	return true
end

function PANEL:PerformLayout()
	if ( !self.MatOn ) then return end

	self.MatOn:SetPos( ( self:GetWide() - self.MatOn:GetWide() ) / 2, ( self:GetTall() - self.MatOn:GetTall() ) / 2 )
end

derma.DefineControl( "ImageCheckBox", "A checkbox with an image for the checked state", PANEL, "DButton" )
