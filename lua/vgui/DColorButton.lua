--[[ DColorButton -- a button that is a colour (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DColorButton
	  "Colorful buttons. Used internally by DColorPalette."
	  Parent: DLabel.
	  Methods: SetColor( color, noTooltip ) / GetColor / SetID / GetID /
	           SetDrawBorder / GetDrawBorder (does nothing) / GetSelected / IsDown

	⚠️ Base class: the wiki says DLabel, because GMod's DLabel is a *clickable* label
	(its DColorButton inherits DoClick from it).  This fork's DLabel is a non-interactive
	text panel with mouse input switched off, so a DColorButton built on it could not be
	clicked at all - the control derives from DButton here instead, which is the same
	thing behaviourally (SetText / GetText / DoClick / hover / depress) and keeps
	`GetSelected` / `IsDown` meaningful.

	The colour is painted by the skin when it knows how (GMod: PaintColorButton);
	otherwise the built-in fill + border below draws it.
--]]

local PANEL = {}

-- NOTE: no AccessorFunc for m_Color - SetColor/GetColor are written out below,
-- because SetColor also feeds the tooltip (see the wiki).
AccessorFunc( PANEL, "m_ID", "ID" )
AccessorFunc( PANEL, "m_DrawBorder", "DrawBorder", FORCE_BOOL )

function PANEL:Init()
	self.m_Color = color_white
	self.m_ID = 0
	self.m_DrawBorder = true

	self:SetText( "" )
end

--- Wiki: `SetColor( color, noTooltip = false )` - a tooltip with the colour is shown
--- unless noTooltip is set.
function PANEL:SetColor( col, noTooltip )
	self.m_Color = col or color_white

	if ( not noTooltip and self.SetTooltip ) then
		local c = self.m_Color
		self:SetTooltip( string.format( "Color( %d, %d, %d, %d )",
			c.r or 255, c.g or 255, c.b or 255, c.a or 255 ) )
	end
end

function PANEL:GetColor()
	return self.m_Color or color_white
end

--- Wiki: "Deprecated ... does absolutely nothing at all."
function PANEL:SetDrawBorder( b )
	self.m_DrawBorder = b and true or false
end

--- Wiki: "an alias of Panel:IsSelected".
function PANEL:GetSelected()
	if ( self.IsSelected ) then return self:IsSelected() end
	return self.m_bSelected == true
end

--- Wiki: "whether the DColorButton is currently being pressed".
function PANEL:IsDown()
	return self.m_bDepressed == true
end

--- The colour under the cursor, for the panel's own use and for scripts.
function PANEL:GetTextColor()
	return self:GetColor()
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( derma.SkinHook( "Paint", "ColorButton", self, w, h ) ) then return end

	local c = self:GetColor()

	surface.DrawSetColor( c.r or 255, c.g or 255, c.b or 255, 255 )
	surface.DrawFilledRect( 0, 0, w, h )

	if ( self.m_DrawBorder ) then
		local br = 0

		if ( self.m_bDepressed ) then
			br = 255
		elseif ( self.m_bHover ) then
			br = 160
		end

		surface.DrawSetColor( br, br, br, 255 )
		surface.DrawOutlinedRect( 0, 0, w, h )
	end
end

--- The wiki example paints the button with an explicit size; that is what this is for.
function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )

	ctrl:SetSize( Width or 100, Height or 30 )
	ctrl:SetText( "DColorButton" )
	ctrl:SetColor( Color( 0, 110, 160 ) )

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DColorButton", "A button that is a colour", PANEL, "DButton" )
