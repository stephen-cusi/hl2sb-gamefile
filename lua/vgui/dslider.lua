--[[ DSlider -- float slider, now with GMod's two-axis API (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DSlider
	  "A multidirectional slider than has the ability to be locked to X or y axis."
	  Parent: DPanel.
	  Methods: SetSlideX / GetSlideX / SetSlideY / GetSlideY /
	           SetLockX / GetLockX / SetLockY / GetLockY /
	           SetDragging / GetDragging / OnValueChanged( slider )

	⚠️ History: this fork's slider was written as a 1-D "float 0..1" control with
	`SetValue`/`GetValue`/`SetXPos`, and DNumSlider is built on those.  GMod's DSlider is
	2-D (slide X *and* Y, both 0..1, with the classic "smooth" grip), and DColorCube
	derives from it - so the two-axis API is added here while the old names keep working:
	`SetValue`/`GetValue` are SlideX, and `OnValueChanged` is still called as
	`( slider, value )` because that is what the in-tree callers expect (a GMod script
	that writes `function slider:OnValueChanged()` still works - trailing arguments are
	ignored in Lua).

	The grip is drawn by the skin when it knows how (PaintSlider / PaintNumberSlider);
	otherwise a plain grip is drawn so the control is always visible.
--]]

local PANEL = {}

local GRIP_W = 12

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetDrawBackground( false )

	self.m_flSlideX = 0
	self.m_flSlideY = 0
	self.m_bHeld = false

	-- GMod: nil = free on that axis
	self.m_bLockX = nil
	self.m_bLockY = nil
end

-------------------------------------------------------------------------------
-- axis accessors
-------------------------------------------------------------------------------
function PANEL:SetSlideX( f )
	if ( self.m_bLockX ~= nil and self.m_bLockX ~= false ) then return end

	f = math.Clamp( tonumber( f ) or 0, 0, 1 )
	if ( f == self.m_flSlideX ) then return end

	self.m_flSlideX = f
	self:OnValueChanged( f )
end

function PANEL:GetSlideX()
	return self.m_flSlideX
end

function PANEL:SetSlideY( f )
	if ( self.m_bLockY ~= nil and self.m_bLockY ~= false ) then return end

	f = math.Clamp( tonumber( f ) or 0, 0, 1 )
	if ( f == self.m_flSlideY ) then return end

	self.m_flSlideY = f
	self:OnValueChanged( f )
end

function PANEL:GetSlideY()
	return self.m_flSlideY
end

function PANEL:SetLockX( b ) self.m_bLockX = b end
function PANEL:GetLockX() return self.m_bLockX end
function PANEL:SetLockY( b ) self.m_bLockY = b end
function PANEL:GetLockY() return self.m_bLockY end

function PANEL:SetDragging( b ) self.m_bHeld = b and true or false end
function PANEL:GetDragging() return self.m_bHeld end

--- GMod: DSlider:SetNotches( n ) / SetNotchColor( col ) -- the little tick marks along the
--- groove ("How many notches to draw on the slider").  DNumSlider calls SetNotches for every
--- integer step, which is what makes its rows look like GMod's instead of a bare bar.
function PANEL:SetNotches( n ) self.m_iNotches = tonumber( n ) end
function PANEL:GetNotches() return self.m_iNotches end
function PANEL:SetNotchColor( col ) self.m_colNotch = col end
function PANEL:GetNotchColor() return self.m_colNotch end

--- GMod: DSlider:IsEditing() -- "Returns whether the slider is being dragged"
--- (its dslider.lua:50 is `return self.Dragging || self.Knob.Depressed`).  The
--- DNumSlider editor and DProperty_Float's row painter both read it.
function PANEL:IsEditing()
	return self.m_bHeld == true
end

--- GMod's event: called whenever either axis changes.  Overridable; the default keeps
--- the old DNumSlider contract alive by passing the new value as the second argument.
function PANEL:OnValueChanged( flValue )
end

-------------------------------------------------------------------------------
-- the 1-D names the fork already had (kept: DNumSlider is written against them)
-------------------------------------------------------------------------------
function PANEL:SetValue( flVal )
	flVal = math.Clamp( tonumber( flVal ) or 0, 0, 1 )
	if ( flVal == self.m_flSlideX ) then return end

	self.m_flSlideX = flVal
	self:OnValueChanged( flVal )
end

function PANEL:GetValue()
	return self.m_flSlideX
end

--- the old "x pixels -> value" helper, now also moving the grip visually
function PANEL:SetXPos( x )
	self:SetValue( ( ( x or 0 ) - GRIP_W / 2 ) / math.max( 1, self:GetWide() - GRIP_W ) )
end

-------------------------------------------------------------------------------
-- interaction
-------------------------------------------------------------------------------
--- Local cursor position, with the ScreenToLocal fallback (Panel:CursorPos may answer
--- only one value - see the note in DAlphaBar).
local function CursorPos( pnl )
	local x, y = pnl:CursorPos()

	if ( y == nil ) then
		x, y = pnl:ScreenToLocal( gui.MouseX(), gui.MouseY() )
	end

	return x or 0, y or 0
end

function PANEL:UpdateFromCursor()
	local x, y = CursorPos( self )
	local w, h = self:GetSize()

	if ( self.m_bLockX == nil or self.m_bLockX == false ) then
		self:SetSlideX( ( x - GRIP_W / 2 ) / math.max( 1, w - GRIP_W ) )
	end

	if ( self.m_bLockY == nil or self.m_bLockY == false ) then
		self:SetSlideY( y / math.max( 1, h ) )
	end
end

function PANEL:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end

	self.m_bHeld = true
	self:MouseCapture( true )
	self:UpdateFromCursor()
end

function PANEL:OnCursorMoved( x, y )
	if ( self.m_bHeld ) then self:UpdateFromCursor() end
end

function PANEL:OnMouseReleased( code )
	self.m_bHeld = false
	self:MouseCapture( false )
end

function PANEL:OnMouseCaptureLost()
	self.m_bHeld = false
end

function PANEL:OnThink()
	if ( self.m_bHeld ) then self:UpdateFromCursor() end
end

-------------------------------------------------------------------------------
-- paint
-------------------------------------------------------------------------------
function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	-- a skin that implements PaintSlider owns the look; else the built-in grip below
	if ( derma.SkinHook( "Paint", "Slider", self, w, h ) ) then
		self:DrawGrip( w, h )
		return
	end

	self:DrawGrip( w, h )
end

--- The grip of a normal slider: a groove across the panel with a 12px grip on it.
---
--- ⚠️ 2026-09-17: this used to choose between this bar and the 2-D box below with
--- `m_bLockX == nil and m_bLockY == nil` - i.e. "free on both axes".  That is the DEFAULT
--- of every DSlider (Init sets both to nil), so it was true for every slider in the tree,
--- and DNumSlider's slider was drawn as the box: a 12x12 square with no groove
--- (seen in the player model selector's Bodygroups tab - "the slider looks broken").
--- GMod's own DNumSlider locks the Y axis (`self.Slider:SetLockY( 0.5 )`,
--- dnumslider.lua:Init) and its DSlider is always drawn as a track with a knob, so the
--- box is now an explicit opt-in used only by DColorCube (DrawBoxGrip below).
function PANEL:DrawGrip( w, h )
	local gx = math.floor( self.m_flSlideX * ( w - GRIP_W ) )
	local cy = math.floor( h / 2 )

	surface.DrawSetColor( 70, 70, 70, 255 )
	surface.DrawFilledRect( 0, cy - 2, w, cy + 2 )

	-- GMod's notches (its skin's Colours.NumSliderNotch is Color( 0, 0, 0, 100 ))
	if ( self.m_iNotches and self.m_iNotches >= 1 ) then
		local col = self.m_colNotch or Color( 0, 0, 0, 100 )

		surface.DrawSetColor( col.r or 0, col.g or 0, col.b or 0, col.a or 100 )

		for i = 0, math.floor( self.m_iNotches ) do
			local x = math.floor( ( i / self.m_iNotches ) * ( w - 1 ) )

			surface.DrawFilledRect( x, cy - 4, x + 1, cy + 4 )
		end
	end

	surface.DrawSetColor( 200, 200, 200, 255 )
	surface.DrawFilledRect( gx, 0, gx + GRIP_W, h )
end

--- The 2-D grip: a small circle outline, for a picker where both axes mean something
--- (DColorCube: saturation on X, value on Y).  GMod's DColorCube uses the
--- "vgui/minixhair" image for its knob - a circle - and this fork kept drawing a square.
--- There is no surface.DrawCircle binding here, so the ring is dotted in with small
--- squares; at 12 px the two are indistinguishable.
function PANEL:DrawBoxGrip( w, h )
	local cx = self.m_flSlideX * ( w - GRIP_W ) + GRIP_W * 0.5
	local cy = math.Clamp( self.m_flSlideY * h, GRIP_W * 0.5, h - GRIP_W * 0.5 )
	local radius = GRIP_W * 0.5
	local steps = 24

	for pass = 1, 2 do
		local col = ( pass == 1 ) and Color( 0, 0, 0, 220 ) or Color( 255, 255, 255, 255 )
		local r = ( pass == 1 ) and radius or ( radius - 1 )

		surface.DrawSetColor( col.r, col.g, col.b, col.a )

		for i = 0, steps - 1 do
			local angle = ( i / steps ) * math.pi * 2
			local px = math.floor( cx + math.cos( angle ) * r )
			local py = math.floor( cy + math.sin( angle ) * r )

			surface.DrawFilledRect( px, py, px + 1, py + 1 )
		end
	end
end

derma.DefineControl( "DSlider", "HL2SB two-axis slider", PANEL, "DPanel" )
