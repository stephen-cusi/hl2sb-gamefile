--[[ DScrollBar -- vertical/horizontal scroll bar (original, pure Lua).

	There is no native ScrollBar bound to Lua in this engine, and GMod's own
	DScrollBar is a Lua control too, so this is drawn and driven entirely here:
	grip dragging via mouse capture, wheel support via OnMouseWheeled, and the
	value contract GMod's containers expect (Enable / SetValue / GetValue /
	SetScrollParent). --]]

local PANEL = {}

local GRIP_MIN = 16

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetDrawBackground( false )

	self.m_bEnabled = false
	self.m_bVertical = true
	self.m_flValue = 0			-- 0..1 fraction of the scrollable range
	self.m_flBarSize = 1		-- viewport / content fraction
	self.m_pParentPanel = nil
	self.m_bHeld = false
	self.m_nGrabOff = 0
end

function PANEL:SetVertical( b )
	self.m_bVertical = b
end

function PANEL:SetParentPanel( pnl )
	self.m_pParentPanel = pnl
end

function PANEL:SetEnabled( b )
	self.m_bEnabled = b
	self:SetVisible( b )
end

function PANEL:Enabled()
	return self.m_bEnabled
end

function PANEL:SetScrollRange( range )
	self.m_flRange = math.max( 1, range )
end

--- Value in [0,1].
function PANEL:SetValue( flVal )
	self.m_flValue = math.Clamp( flVal or 0, 0, 1 )
	self:InvalidateLayout( true )
end

function PANEL:GetValue()
	return self.m_flValue
end

--- GMod's DVScrollBar spellings (wiki.facepunch.com/gmod/DVScrollBar):
--- SetScroll/GetScroll carry the same 0..1 fraction this bar stores, AddScroll
--- nudges the value by a fraction, and SetScrollParent/GetScrollParent are the
--- container back-reference this bar already keeps in m_pParentPanel.
function PANEL:SetScroll( scr )
	self:SetValue( scr )
end

function PANEL:GetScroll()
	return self.m_flValue
end

function PANEL:AddScroll( delta )
	local old = self.m_flValue
	self:SetValue( self.m_flValue + delta )
	return self.m_flValue ~= old
end

function PANEL:SetScrollParent( pnl )
	self.m_pParentPanel = pnl
end

function PANEL:GetScrollParent()
	return self.m_pParentPanel
end

--- GMod's DVScrollBar container contract (wiki.facepunch.com/gmod/DVScrollBar) --
--- the spellings addon code uses on a DScrollPanel's GetVBar().  SetUp stores the
--- viewport/content fraction this bar's grip already renders (m_flBarSize) plus the
--- canvas size GetOffset needs; both in GMod pixels.
function PANEL:SetUp( barsize, canvassize )
	barsize = math.max( 1, tonumber( barsize ) or 1 )
	canvassize = math.max( 1, tonumber( canvassize ) or 1 )

	self.m_iCanvasSize = canvassize
	self.m_flBarSize = math.Clamp( barsize / canvassize, 0.02, 1 )
	self:SetEnabled( canvassize > barsize + 1 )
end

--- GMod: GetOffset() -- the canvas pixel offset for the current scroll fraction.
function PANEL:GetOffset()
	if ( self.m_bEnabled == false or self.m_iCanvasSize == nil ) then return 0 end

	local scrollable = math.max( 0, self.m_iCanvasSize - ( self.m_iBarsizePixels or self.m_iCanvasSize ) )
	return self.m_flValue * scrollable
end

--- GMod: AnimateTo( scrll, length, delay, ease ) -- tween the value through the
--- panel animation extension (anim.Think contract, lua/includes/extensions/client/
--- panel/animation.lua).
function PANEL:AnimateTo( scrll, length, delay, ease )
	if ( self.AnimTo ) then self.AnimTo:Stop() end

	local anim = self:NewAnimation( length or 0, delay or 0, ease )
	self.AnimTo = anim

	anim.Think = function( anm, pnl, fraction )
		local target = anm.TargetValue
		if ( target == nil ) then return end
		pnl:SetValue( anm.StartValue + ( target - anm.StartValue ) * fraction )
	end

	anim.StartValue = self.m_flValue
	anim.TargetValue = tonumber( scrll ) or 0
end

-- OnThink, not Think - see the note in DScrollPanel.lua (scripted_controls/lPanel.cpp
-- dispatches the per-frame hook under the OnThink name only).
function PANEL:OnThink()
	-- grip geometry refreshes through SetEnabled / the parent's SetValue calls;
	-- nothing to poll here
end

function PANEL:GripGeometry()
	local w, h = self:GetSize()
	local trackLen = self.m_bVertical and h or w

	local barLen = trackLen * math.Clamp( self.m_flBarSize or 1, 0.02, 1 )
	if ( barLen < GRIP_MIN ) then barLen = GRIP_MIN end
	if ( barLen > trackLen ) then barLen = trackLen end

	local maxTravel = trackLen - barLen
	local pos = maxTravel * self.m_flValue

	return pos, barLen
end

function PANEL:PerformLayout( w, h )
	-- nothing absolute to place; geometry happens in Paint
end

function PANEL:PosToValue( x, y )
	local _, barLen = self:GripGeometry()
	local trackLen = self.m_bVertical and self:GetTall() or self:GetWide()
	local maxTravel = math.max( 1, trackLen - barLen )

	local p = self.m_bVertical and y or x
	p = p - barLen / 2

	self:SetValue( p / maxTravel )
end

function PANEL:OnMousePressed( code )
	if ( not self.m_bEnabled ) then return end
	if ( code ~= MOUSE_LEFT ) then return end

	self.m_bHeld = true
	self:MouseCapture( true )

	local x, y = derma.CursorPos( self )
	self:PosToValue( x, y )
end

function PANEL:OnCursorMoved( x, y )
	if ( not self.m_bHeld ) then return end
	self:PosToValue( x, y )
end

function PANEL:OnMouseReleased( code )
	self.m_bHeld = false
	self:MouseCapture( false )
end

function PANEL:TranslateMouseDelta( delta )
	if ( not self.m_bEnabled ) then return end

	local trackLen = self.m_bVertical and self:GetTall() or self:GetWide()
	local _, barLen = self:GripGeometry()
	local maxTravel = math.max( 1, trackLen - barLen )

	-- wheel steps move by a viewport-fraction, GMod style
	self:SetValue( self.m_flValue - delta * ( 48 / ( maxTravel * ( self.m_flRange or 1 ) ) ) )
end

function PANEL:OnMouseWheeled( delta )
	self:TranslateMouseDelta( delta )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( not self.m_bEnabled ) then return end

	derma.SkinHook( "Paint", "ScrollBar", self, w, h )

	-- HL2SB: a visible TRACK behind the grip.  Without one the bar was a 12px grip
	-- floating in the panel's own background, which reads as "there is no scrollbar
	-- here" - and the bar is the only thing that tells the user a list continues past
	-- the bottom edge.
	surface.DrawSetColor( 40, 44, 50, 150 )
	surface.DrawFilledRect( 0, 0, w, h )

	local pos, barLen = self:GripGeometry()

	if ( self.m_bVertical ) then
		local gripW = math.min( w, 12 )
		self.m_nGripX = w - gripW
		self.m_nGripY = pos
		self.m_nGripW = gripW
		self.m_nGripH = barLen
	else
		self.m_nGripX = pos
		self.m_nGripY = 0
		self.m_nGripW = barLen
		self.m_nGripH = math.min( h, 12 )
	end

	-- The grip is drawn at its own position inside the bar; surface.* has no
	-- translate, so the positioned rect is painted directly here.  Hover state
	-- comes from the bar's own cursor enter/exit (whole-bar granularity).
	local c = ( self.m_bHover or self.m_bHeld ) and Color( 130, 138, 150, 255 ) or Color( 108, 115, 126, 255 )
	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawFilledRect( self.m_nGripX, self.m_nGripY, self.m_nGripW, self.m_nGripH )
end

function PANEL:OnCursorEntered()
	self.m_bHover = true
end

function PANEL:OnCursorExited()
	self.m_bHover = false
end

derma.DefineControl( "DScrollBar", "HL2SB scroll bar", PANEL, "DPanel" )
