--[[ DColorCube -- 2-D saturation/value picker (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DColorCube
	  "The DColorCube allows a user to select saturation and value but not hue."
	  Parent: DSlider.
	  Event: DColorCube:OnUserChanged( color )   -- override me
	  Methods: GetBaseRGB / SetBaseRGB / GetDefaultColor / SetDefaultColor /
	           GetRGB / SetRGB / GetHue / SetHue (deprecated) /
	           SetColor / ResetToDefaultValue / TranslateValues / UpdateColor /
	           DoRightClick

	The maths is GMod's, verbatim in meaning:
	    value      = 1 - slideY
	    saturation = 1 - slideX
	    hue        = ColorToHSV( baseRGB )
	    outRGB     = HSVToColor( hue, saturation, value )
	so the drawn square is the base hue fading to white along X and to black along Y.

	⚠️ GMod builds that square out of two DImage children
	(`vgui/gradient-r`, `vgui/gradient-d`); this version paints the same two gradients
	directly, because the gradients are two nested loops of coloured strips and doing it
	here means the control does not depend on those two materials being mounted.
	Everything the wiki documents behaves the same, including SetColor() moving the
	slider, SetBaseRGB() only recolouring the square, and the middle/right mouse
	shortcuts on the grip.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_Hue", "Hue" )
AccessorFunc( PANEL, "m_BaseRGB", "BaseRGB" )
AccessorFunc( PANEL, "m_OutRGB", "RGB" )
AccessorFunc( PANEL, "m_DefaultColor", "DefaultColor" )

function PANEL:Init()
	-- GMod: both axes are live (the cube is a 2-D slider)
	self:SetLockX( nil )
	self:SetLockY( nil )

	self.m_BaseRGB = Color( 255, 0, 0, 255 )
	self.m_OutRGB = Color( 255, 0, 0, 255 )
	self.m_DefaultColor = color_white

	if ( self.SetDrawBackground ) then self:SetDrawBackground( false ) end

	self:SetColor( Color( 255, 0, 0, 255 ) )
end

--- Wiki: "Updates the color cube RGB based on the given x and y position"
function PANEL:UpdateColor( x, y )
	x = x or self:GetSlideX()
	y = y or self:GetSlideY()

	local value = 1 - y
	local saturation = 1 - x

	local h = ColorToHSV( self.m_BaseRGB )
	local col = HSVToColor( h, saturation, value )

	col.a = 255
	self:SetRGB( col )
end

--- Wiki: "Similar to UpdateColor" - same work, plus the user event.
function PANEL:TranslateValues( x, y )
	self:UpdateColor( x, y )
	self:OnUserChanged( self.m_OutRGB )

	return x, y
end

--- Wiki: "Function which is called when the color cube slider is moved (through user
--- input). Meant to be overridden."
function PANEL:OnUserChanged( col )
end

--- Wiki: "Sets the base color of the color cube and updates the slider position."
function PANEL:SetColor( col )
	col = col or color_white

	local h, s, v = ColorToHSV( col )

	self:SetBaseRGB( HSVToColor( h, 1, 1 ) )

	self:SetSlideY( 1 - v )
	self:SetSlideX( 1 - s )

	self:UpdateColor()
end

--- Wiki: "sets the base color and the color used to draw the color cube panel itself".
--- (Note the wiki's warning: a base colour that is not fully saturated/valued makes the
--- drawn square disagree with GetRGB - use SetColor instead.  That is GMod's behaviour,
--- kept.)
function PANEL:SetBaseRGB( col )
	self.m_BaseRGB = col or color_white
	self:UpdateColor()
end

--- Wiki: "Sets the color to whatever GetDefaultColor returns"
function PANEL:ResetToDefaultValue()
	self:SetColor( self:GetDefaultColor() )
	self:OnUserChanged( self.m_OutRGB )
end

function PANEL:DoRightClick()
	if ( not DermaMenu ) then return end

	local menu = DermaMenu()
	if ( not menu or not menu.AddOption ) then return end

	menu:AddOption( "Reset to default", function() self:ResetToDefaultValue() end )
	menu:AddOption( "Copy colour", function()
		local c = self.m_OutRGB

		if ( SetClipboardText ) then
			SetClipboardText( string.format( "%d %d %d", c.r, c.g, c.b ) )
		end
	end )
end

function PANEL:OnMousePressed( btnId )
	if ( btnId == MOUSE_MIDDLE ) then
		self:ResetToDefaultValue()
		return
	end

	if ( btnId == MOUSE_RIGHT ) then
		self:DoRightClick()
		return
	end

	-- left: the DSlider drag (which is what moves the grip).  `self.BaseClass` is the
	-- derma framework's inheritance proxy (hl2sb_derma.lua:attachBaseClass), so this
	-- resolves to DSlider.OnMousePressed.
	self.BaseClass.OnMousePressed( self, btnId )
end

--- The drag: DSlider calls OnValueChanged on every move; the cube turns that into a
--- colour and raises OnUserChanged.
function PANEL:OnValueChanged( flValue )
	if ( self.m_bInUpdate ) then return end

	-- DSlider calls this once per axis; doing the work here keeps a single code path
	self.m_bInUpdate = true
	self:UpdateColor()
	self.m_bInUpdate = false

	self:OnUserChanged( self.m_OutRGB )
end

-------------------------------------------------------------------------------
-- paint: hue fading to white along X, then to black along Y
-------------------------------------------------------------------------------
function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local base = self.m_BaseRGB or Color( 255, 0, 0 )

	-- the square is the base hue
	surface.DrawSetColor( base.r, base.g, base.b, 255 )
	surface.DrawFilledRect( 0, 0, w, h )

	-- saturation: the base hue at x = 0 -> white at x = w
	--
	-- ⚠️ 2026-09-17: this used to be drawn the OTHER WAY ROUND (white at x = 0), while
	-- UpdateColor() maps the pixel to `saturation = 1 - x` and SetColor() parks the grip at
	-- `1 - s` - both taken verbatim from GMod's dcolorcube.lua.  The square therefore showed
	-- the *opposite* of the colour the grip actually selected: the player model selector's
	-- colour mixer looked "inverted" (drag to the left, where the square is white, and the
	-- colour comes out fully saturated).  The DSlider below maps slideX = 0 to the left edge
	-- (lua/vgui/DSlider.lua:131), which is what settles the direction.
	local steps = math.max( 2, math.min( w, 64 ) )
	local stepW = w / steps

	for i = 0, steps - 1 do
		local t = i / ( steps - 1 )				-- 0 = hue, 1 = white
		local alpha = 255 * t

		surface.DrawSetColor( 255, 255, 255, alpha )
		surface.DrawFilledRect( math.floor( i * stepW ), 0,
			math.ceil( ( i + 1 ) * stepW ), h )
	end

	-- value: transparent at y = 0 -> black at y = h
	local vsteps = math.max( 2, math.min( h, 64 ) )
	local stepH = h / vsteps

	for i = 0, vsteps - 1 do
		local alpha = 255 * ( i / ( vsteps - 1 ) )

		surface.DrawSetColor( 0, 0, 0, alpha )
		surface.DrawFilledRect( 0, math.floor( i * stepH ), w, math.ceil( ( i + 1 ) * stepH ) )
	end

	-- the 2-D grip (a box), not DSlider's 1-D groove+grip: both axes of a cube mean
	-- something (saturation on X, value on Y).  See DSlider:DrawBoxGrip.
	self:DrawBoxGrip( w, h )
end

--- Wiki: "Panel:PaintOver" (GMod's DColorCube draws the frame here).
function PANEL:PaintOver( w, h )
	surface.DrawSetColor( 0, 0, 0, 250 )
	surface.DrawOutlinedRect( 0, 0, w or self:GetWide(), h or self:GetTall() )
end

function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )

	ctrl:SetSize( Width or 155, Height or 155 )
	ctrl:SetBaseRGB( Color( 0, 255, 0 ) )

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DColorCube", "2-D saturation/value picker", PANEL, "DSlider" )
