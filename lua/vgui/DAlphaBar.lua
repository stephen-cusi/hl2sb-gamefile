--[[ DAlphaBar -- vertical alpha (opacity) picker (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DAlphaBar
	  "A bar to select the opacity (alpha level) of a color."
	  Parent: DPanel.
	  Methods: GetValue / SetValue( alpha ) / GetBarColor / SetBarColor( clr )
	  Event:   DAlphaBar:OnChange( alpha )   -- override me

	The bar is drawn top = opaque, bottom = transparent, and `GetValue` is the 0..1
	alpha the caller should apply (GMod's OnCursorMoved does `1 - y / GetTall()`).

	⚠️ GMod reads `input.IsMouseDown( MOUSE_LEFT )` inside OnCursorMoved; this fork has
	no such binding, so the press state is tracked from OnMousePressed/OnMouseReleased
	(which is also what makes the drag survive the cursor leaving the bar).

	The two textures GMod uses (`gui/alpha_grid.png` for the checkerboard and
	`vgui/gradient-u` for the ramp) are drawn procedurally when they are not mounted -
	a picker that paints nothing would be unusable, and the procedural versions are
	the same picture.
--]]

local PANEL = {}

--- GMod's `Panel:CursorPos()`, which this fork maps to GetLocalCursorPosition.  The
--- fallback keeps the control working if that binding ever answers one value only.
--- Declared before it is used: a `local function` below its caller would not be in
--- scope there (the same trap as a local variable used above its declaration).
local function LocalCursorY( pnl )
	local _, y = pnl:CursorPos()

	if ( y == nil ) then
		local gx, gy = gui.MouseX(), gui.MouseY()
		_, y = pnl:ScreenToLocal( gx, gy )
	end

	return y or 0
end

function PANEL:Init()
	self.m_Value = 1
	self.m_BarColor = color_white

	self.m_bDown = false

	self:SetMouseInputEnabled( true )
	self:SetSize( 26, 26 )

	if ( self.SetDrawBackground ) then self:SetDrawBackground( false ) end
end

-------------------------------------------------------------------------------
-- accessors (GMod: AccessorFunc for both)
-------------------------------------------------------------------------------
function PANEL:SetValue( f )
	self.m_Value = math.Clamp( tonumber( f ) or 0, 0, 1 )
end

function PANEL:GetValue()
	return self.m_Value
end

function PANEL:SetBarColor( col )
	self.m_BarColor = col or color_white
end

function PANEL:GetBarColor()
	return self.m_BarColor
end

--- Wiki: "Called when user changes the desired alpha value ... meant to be overridden."
function PANEL:OnChange( fAlpha )
end

-------------------------------------------------------------------------------
-- interaction
-------------------------------------------------------------------------------
function PANEL:UpdateFromCursor()
	local y = LocalCursorY( self )

	y = math.Clamp( y / math.max( 1, self:GetTall() ), 0, 1 )

	-- top of the bar is alpha 1 (GMod's `1 - fHeight`)
	local f = 1 - y

	if ( f ~= self.m_Value ) then
		self:SetValue( f )
	end

	self:OnChange( self.m_Value )
end

function PANEL:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end

	self.m_bDown = true
	self:MouseCapture( true )
	self:UpdateFromCursor()
end

function PANEL:OnMouseReleased( code )
	if ( not self.m_bDown ) then return end

	self.m_bDown = false
	self:MouseCapture( false )
	self:UpdateFromCursor()
end

function PANEL:OnMouseCaptureLost()
	self.m_bDown = false
end

function PANEL:OnCursorMoved( x, y )
	if ( self.m_bDown ) then self:UpdateFromCursor() end
end

function PANEL:OnThink()
	if ( self.m_bDown ) then self:UpdateFromCursor() end
end

-------------------------------------------------------------------------------
-- paint
-------------------------------------------------------------------------------
--- the GMod alpha checkerboard, procedurally: no material needed
local function PaintChecker( w, h, size )
	local light, dark = 120, 90

	for y = 0, h - 1, size do
		for x = 0, w - 1, size do
			local odd = ( ( math.floor( x / size ) + math.floor( y / size ) ) % 2 ) == 1
			local c = odd and dark or light

			surface.DrawSetColor( c, c, c, 255 )
			surface.DrawFilledRect( x, y, math.min( x + size, w ), math.min( y + size, h ) )
		end
	end
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( derma.SkinHook( "Paint", "AlphaBar", self, w, h ) ) then return end

	PaintChecker( w, h, 8 )

	-- the ramp: the bar colour fading in towards the top
	local c = self:GetBarColor()
	local steps = math.max( 2, math.min( h, 64 ) )
	local stepH = h / steps

	for i = 0, steps - 1 do
		local alpha = 255 * ( ( i + 1 ) / steps )

		surface.DrawSetColor( c.r or 255, c.g or 255, c.b or 255, alpha )
		surface.DrawFilledRect( 0, math.floor( i * stepH ), w, math.ceil( ( i + 1 ) * stepH ) )
	end

	surface.DrawSetColor( 0, 0, 0, 250 )
	surface.DrawOutlinedRect( 0, 0, w, h )

	-- the value line (GMod draws a 3px black line + a 1px white highlight on it)
	local y = math.floor( ( 1 - self.m_Value ) * h )

	surface.DrawSetColor( 0, 0, 0, 250 )
	surface.DrawFilledRect( 0, y - 2, w, y + 1 )

	surface.DrawSetColor( 255, 255, 255, 250 )
	surface.DrawFilledRect( 0, y - 1, w, y )
end

derma.DefineControl( "DAlphaBar", "Vertical alpha picker", PANEL, "DPanel" )
