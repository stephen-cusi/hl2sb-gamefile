--[[ DRGBPicker -- a vertical hue picker (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DRGBPicker
	  "DRGBPicker is an interactive panel which can be used to select a color hue."
	  Parent: DPanel.
	  Methods: GetRGB / SetRGB( color ) / GetPosColor( x, y )
	  Event:   DRGBPicker:OnChange( col )   -- override me

	The selection line is drawn at the last picked y (GMod keeps `LastX/LastY`), and
	`SetRGB` deliberately does NOT move it or call OnChange - the wiki says so.

	⚠️ GMod paints a `gui/colors.png` material and reads the hue back with
	`IMaterial:GetColor( x, y )`.  This fork can do that too, but a hard dependency on
	one GMod texture would leave the picker blank (and GetPosColor nil) whenever that
	file is not mounted, so the hue ramp is computed instead: the same 0..360 ramp
	(`HSVToColor( h, 1, 1 )`), sampled by the same maths from the cursor position.
	Everything the wiki documents still answers identically.
--]]

local PANEL = {}

function PANEL:Init()
	self.m_RGB = color_white

	-- GMod starts the indicator off-screen until the first pick
	self.LastX = -100
	self.LastY = -100

	self.m_bDown = false

	self:SetMouseInputEnabled( true )

	if ( self.SetDrawBackground ) then self:SetDrawBackground( false ) end
end

-------------------------------------------------------------------------------
-- accessors
-------------------------------------------------------------------------------
function PANEL:SetRGB( col )
	self.m_RGB = col or color_white
end

function PANEL:GetRGB()
	return self.m_RGB or color_white
end

--- Wiki: "Returns the color at given position on the internal texture."
--- x is unused (the ramp is vertical), which is why GMod returns it back to the caller.
function PANEL:GetPosColor( x, y )
	local w = math.max( 1, self:GetWide() )
	local h = math.max( 1, self:GetTall() )

	local conX = math.Clamp( ( x or 0 ) / w, 0, 1 )
	local conY = math.Clamp( ( y or 0 ) / h, 0, 1 )

	local hue = conY * 360

	return HSVToColor( hue, 1, 1 ), conX * ( w - 1 ), conY * ( h - 1 )
end

--- Wiki: "Function which is called when the cursor is clicked and/or moved on the
--- color picker. Meant to be overridden."
function PANEL:OnChange( col )
end

-------------------------------------------------------------------------------
-- interaction
-------------------------------------------------------------------------------
--- GMod's `Panel:CursorPos()` (mapped to GetLocalCursorPosition in this fork), with a
--- screen-space fallback; declared before its callers on purpose.
local function LocalCursor( pnl )
	local x, y = pnl:CursorPos()

	if ( y == nil ) then
		x, y = pnl:ScreenToLocal( gui.MouseX(), gui.MouseY() )
	end

	return x or 0, y or 0
end

function PANEL:UpdateFromCursor()
	local x, y = LocalCursor( self )

	local col = self:GetPosColor( x, y )

	if ( col ) then
		self.m_RGB = col
		self.m_RGB.a = 255

		self:OnChange( self.m_RGB )
	end

	self.LastX = x
	self.LastY = y
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
function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( derma.SkinHook( "Paint", "RGBPicker", self, w, h ) ) then return end

	-- the hue ramp, one strip per degree (capped so a tall picker stays cheap)
	local steps = math.max( 2, math.min( h, 360 ) )
	local stepH = h / steps

	for i = 0, steps - 1 do
		local col = HSVToColor( ( i / steps ) * 360, 1, 1 )

		surface.DrawSetColor( col.r, col.g, col.b, 255 )
		surface.DrawFilledRect( 0, math.floor( i * stepH ), w, math.ceil( ( i + 1 ) * stepH ) )
	end

	surface.DrawSetColor( 0, 0, 0, 250 )
	surface.DrawOutlinedRect( 0, 0, w, h )

	if ( self.LastY and self.LastY >= 0 ) then
		local y = math.floor( self.LastY )

		surface.DrawSetColor( 0, 0, 0, 250 )
		surface.DrawFilledRect( 0, y - 2, w, y + 1 )

		surface.DrawSetColor( 255, 255, 255, 250 )
		surface.DrawFilledRect( 0, y - 1, w, y )
	end
end

derma.DefineControl( "DRGBPicker", "Vertical hue picker", PANEL, "DPanel" )
