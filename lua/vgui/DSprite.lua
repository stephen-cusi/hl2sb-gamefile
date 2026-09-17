--[[ DSprite -- a 2D sprite panel (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DSprite
	  "A panel that draws a sprite on the player's HUD with the given IMaterial,
	  Color and rotation."  Parent: DPanel.
	  GetColor/SetColor, GetHandle/SetHandle (deprecated, does nothing),
	  GetMaterial/SetMaterial, GetRotation/SetRotation.

	Ported from GMod's lua/vgui/dsprite.lua (55 lines).  The engine substitution is
	none - the drawing already goes through surface.DrawTexturedRectRotated, which
	this fork binds with GMod's own semantics (x, y is the rect's CENTRE and rot is
	degrees anticlockwise, see AGENTS.md 5.4) - so Paint is verbatim, including
	GMod's `local x, y = 0, 0`, which centres the sprite on the panel's origin.

	Global.CreateSprite( material ) is defined at the end, exactly like GMod's.

	Deliberate deviation: GMod calls self:NoClipping( true ) in Init.  That method
	exists here as well now (lua/includes/init.lua aliases it), but this engine
	binds no clipping switch, so the call is guarded - see the DSprite note there.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_Material", "Material" )
AccessorFunc( PANEL, "m_Color", "Color" )
AccessorFunc( PANEL, "m_Rotation", "Rotation" )
AccessorFunc( PANEL, "m_Handle", "Handle" )

function PANEL:Init()
	self:SetColor( color_white )
	self:SetRotation( 0 )
	self:SetHandle( Vector( 0.5, 0.5, 0 ) )

	self:SetMouseInputEnabled( false )
	self:SetKeyboardInputEnabled( false )

	if ( self.NoClipping ) then
		self:NoClipping( true )
	end
end

function PANEL:Paint()
	local Mat = self.m_Material
	if ( !Mat ) then return true end

	surface.SetMaterial( Mat )
	surface.SetDrawColor( self.m_Color.r, self.m_Color.g, self.m_Color.b, self.m_Color.a )

	local w, h = self:GetSize()
	local x, y = 0, 0
	surface.DrawTexturedRectRotated( x, y, w, h, self.m_Rotation )

	return true
end

function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )
	ctrl:SetMaterial( Material( "brick/brick_model" ) )
	ctrl:SetSize( 200, 200 )

	PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
end

derma.DefineControl( "DSprite", "A sprite", PANEL, "DPanel" )

-- Convenience function
function CreateSprite( mat )
	local sprite = vgui.Create( "DSprite" )
	sprite:SetMaterial( mat )
	return sprite
end
