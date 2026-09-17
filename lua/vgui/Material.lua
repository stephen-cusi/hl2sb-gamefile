--[[ Material -- a panel that renders a VMT material (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/Material
	  "Material is a VGUI element that renders a VMT material."  Parent: Button.
	  Material:SetAlpha( number ), Material:SetMaterial( string matname ).
	  The wiki notes the `AutoSize` field directly: "If the material is not showing
	  up as the correct size, try setting the Material panel's AutoSize to false".

	Ported from GMod's lua/vgui/material.lua (60 lines).  ImageCheckBox is built on
	this control (lua/vgui/ImageCheckBox.lua creates one per checkbox).

	Deliberate deviations:
	  * Base is DButton, not the engine's "Button".  GMod's own material.lua
	    registers the control on the engine's Button, but this fork's C Button
	    fires DoClick in C++ and never consults a Lua field / Lua Paint, so a
	    Material panel based on it would not paint from Lua at all
	    (lua/vgui/DButton.lua header explains this).  DButton is a DPanel with the
	    same mouse contract, so the two documented methods behave identically.
	  * SetMaterial asks the material proxy for `$basetexture` only when the proxy
	    exposes GetTexture: this fork's Material() is a Lua wrapper
	    (lua/includes/extensions/gmod_surface.lua:168) whose job is to never throw
	    on a missing file, so the size falls back to GMod's own 32x32.
--]]

local PANEL = {}

function PANEL:Init()
	self.Material = nil
	self.AutoSize = true
	self:SetAlpha( 255 )

	self:SetMouseInputEnabled( false )
	self:SetKeyboardInputEnabled( false )
end

function PANEL:Paint()
	if ( !self.Material ) then return true end

	surface.SetMaterial( self.Material )
	surface.SetDrawColor( 255, 255, 255, self.Alpha )
	surface.DrawTexturedRect( 0, 0, self:GetSize() )

	return true
end

--- GMod: Material:SetAlpha( alpha ).  GMod overrides the engine's SetAlpha with a
--- plain field of its own -- kept, because Paint above reads it.
function PANEL:SetAlpha( alpha )
	self.Alpha = alpha
end

function PANEL:GetAlpha()
	return self.Alpha or 255
end

--- Wiki: "Sets the material used by the panel."
function PANEL:SetMaterial( matname )
	self.Material = Material( matname )

	if ( self.Material and self.Material.GetTexture ) then
		local ok, Texture = pcall( self.Material.GetTexture, self.Material, "$basetexture" )

		if ( ok and Texture and Texture.Width and Texture.Height ) then
			self.Width = Texture:Width()
			self.Height = Texture:Height()
		end
	end

	if ( not self.Width or self.Width < 1 ) then self.Width = 32 end
	if ( not self.Height or self.Height < 1 ) then self.Height = 32 end

	self:InvalidateLayout()
end

function PANEL:GetMaterial()
	return self.Material
end

function PANEL:PerformLayout()
	if ( !self.Material ) then return end
	if ( !self.AutoSize ) then return end

	self:SetSize( self.Width, self.Height )
end

derma.DefineControl( "Material", "A VMT material panel", PANEL, "DButton" )
