--[[ DHScrollBar -- a horizontal scrollbar (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DHScrollBar
	  Parent: Panel.  GetScroll / SetScroll, GetOffset, AddScroll, SetUp,
	  GetHideButtons / SetHideButtons, BarScale, Grip, AnimateTo - the horizontal
	  twin of DVScrollBar, and what DHorizontalScroller and DFileBrowser scroll with.

	Ported from GMod's lua/vgui/dhscrollbar.lua (257 lines); this fork already had
	the vertical one (lua/vgui/DVScrollBar.lua) written against the same layout.

	Notes for this fork:
	  * GMod's two arrow buttons paint with a bare `derma.SkinHook( "Paint",
	    "ButtonLeft"/"ButtonRight" )`, and the arrow direction comes from the skin's
	    GWEN texture.  This fork's skin has no such hooks, so the buttons would be
	    invisible; PaintArrow below is the same fallback lua/vgui/DVScrollBar.lua:33
	    uses for its up/down pair.
	  * PANEL:Paint likewise asks the skin first and fills the track itself when
	    nothing handled it.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_HideButtons", "HideButtons" )

--- The arrows GMod's skin would paint; see the header.  bRight mirrors DVScrollBar's
--- bDown (both point at the end the scroll moves toward).
local function PaintArrow( pnl, w, h, bRight )
	w = w or pnl:GetWide()
	h = h or pnl:GetTall()

	if ( derma.SkinHook( "Paint", bRight and "ButtonRight" or "ButtonLeft", pnl, w, h ) ) then return end

	local bright = 200
	if ( pnl.m_bDepressed ) then bright = 255
	elseif ( pnl.m_bHover ) then bright = 235 end

	surface.DrawSetColor( 70, 70, 70, 255 )
	surface.DrawFilledRect( 0, 0, w, h )

	surface.DrawSetColor( bright, bright, bright, 255 )

	local half = ( w - 1 ) * 0.5
	if ( half <= 0 ) then half = 1 end

	for x = 0, w - 1 do
		local f = 1 - math.abs( x - half ) / half			-- 1 in the middle column
		local len = math.max( 1, math.floor( ( h - 6 ) * f ) )

		if ( bRight ) then
			surface.DrawFilledRect( w - 1 - x, math.floor( h * 0.5 ) - math.floor( len * 0.5 ),
				w - x, math.floor( h * 0.5 ) + math.ceil( len * 0.5 ) )
		else
			surface.DrawFilledRect( x, math.floor( h * 0.5 ) - math.floor( len * 0.5 ),
				x + 1, math.floor( h * 0.5 ) + math.ceil( len * 0.5 ) )
		end
	end
end

function PANEL:Init()

	self.Offset = 0
	self.Scroll = 0
	self.CanvasSize = 1
	self.BarSize = 1

	self.btnLeft = vgui.Create( "DButton", self )
	self.btnLeft:SetText( "" )
	self.btnLeft.DoClick = function( s ) s:GetParent():AddScroll( -1 ) end
	self.btnLeft.Paint = function( panel, w, h ) PaintArrow( panel, w, h, false ) end

	self.btnRight = vgui.Create( "DButton", self )
	self.btnRight:SetText( "" )
	self.btnRight.DoClick = function( s ) s:GetParent():AddScroll( 1 ) end
	self.btnRight.Paint = function( panel, w, h ) PaintArrow( panel, w, h, true ) end

	self.btnGrip = vgui.Create( "DScrollBarGrip", self )

	self:SetSize( 15, 15 )
	self:SetHideButtons( false )

end

function PANEL:SetEnabled( b )

	if ( !b ) then

		self.Offset = 0
		self:SetScroll( 0 )
		self.HasChanged = true

	end

	self:SetMouseInputEnabled( b )
	self:SetVisible( b )

	-- We're probably changing the width of something in our parent
	-- by appearing or hiding, so tell them to re-do their layout.
	if ( self.Enabled != b ) then

		self:GetParent():InvalidateLayout()

		if ( self:GetParent().OnScrollbarAppear ) then
			self:GetParent():OnScrollbarAppear()
		end

	end

	self.Enabled = b

end

function PANEL:BarScale()

	if ( self.BarSize == 0 ) then return 1 end

	return self.BarSize / ( self.CanvasSize + self.BarSize )

end

function PANEL:SetUp( _barsize_, _canvassize_ )

	self.BarSize = _barsize_
	self.CanvasSize = math.max( _canvassize_ - _barsize_, 1 )
	self.Scroll = math.Clamp( self:GetScroll(), 0, self.CanvasSize )

	self:SetEnabled( _canvassize_ > _barsize_ )

	self:InvalidateLayout()

end

function PANEL:OnMouseWheeled( dlta )

	if ( !self:IsVisible() ) then return false end

	-- We return true if the scrollbar changed.
	-- If it didn't, we feed the mousehweeling to the parent panel

	return self:AddScroll( dlta * -2 )

end

function PANEL:AddScroll( dlta )

	local OldScroll = self:GetScroll()

	dlta = dlta * 25
	self:SetScroll( self:GetScroll() + dlta )

	return OldScroll != self:GetScroll()

end

function PANEL:SetScroll( scrll )

	if ( !self.Enabled ) then self.Scroll = 0 return end

	self.Scroll = math.Clamp( scrll, 0, self.CanvasSize )

	self:InvalidateLayout()

	-- If our parent has a OnHScroll function use that, if
	-- not then invalidate layout (which can be pretty slow)

	local func = self:GetParent().OnHScroll
	if ( func ) then

		func( self:GetParent(), self:GetOffset() )

	else

		self:GetParent():InvalidateLayout()

	end

end

function PANEL:AnimateTo( scrll, length, delay, ease )

	local anim = self:NewAnimation( length, delay, ease )
	anim.StartPos = self.Scroll
	anim.TargetPos = scrll
	anim.Think = function( anm, pnl, fraction )

		pnl:SetScroll( Lerp( fraction, anm.StartPos, anm.TargetPos ) )

	end

end

function PANEL:GetScroll()

	if ( !self.Enabled ) then self.Scroll = 0 end
	return self.Scroll

end

function PANEL:GetOffset()

	if ( !self.Enabled ) then return 0 end
	return self.Scroll * -1

end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	-- GMod's version is only this hook (its skin draws the track); this fork's skin
	-- has no HScrollBar hook, so fill the track when nothing handled it.
	if ( derma.SkinHook( "Paint", "HScrollBar", self, w, h ) ) then return true end

	surface.DrawSetColor( 52, 56, 63, 255 )
	surface.DrawFilledRect( 0, 0, w, h )

	return true
end

function PANEL:OnMousePressed()

	local x, y = self:CursorPos()

	local PageSize = self.BarSize

	if ( x > self.btnGrip.x ) then
		self:SetScroll( self:GetScroll() + PageSize )
	else
		self:SetScroll( self:GetScroll() - PageSize )
	end

end

function PANEL:OnMouseReleased()

	self.Dragging = false
	self.DraggingCanvas = nil
	self:MouseCapture( false )

	self.btnGrip.Depressed = false

end

function PANEL:OnCursorMoved( lx, ly )

	if ( !self.Enabled ) then return end
	if ( !self.Dragging ) then return end

	local x, y = self:ScreenToLocal( gui.MouseX(), 0 )

	-- Uck.
	x = x - self.btnLeft:GetWide()
	x = x - self.HoldPos

	local BtnWidth = self:GetTall()
	if ( self:GetHideButtons() ) then BtnWidth = 0 end

	local TrackSize = self:GetWide() - BtnWidth * 2 - self.btnGrip:GetWide()

	x = x / TrackSize

	self:SetScroll( x * self.CanvasSize )

end

function PANEL:Grip()

	if ( !self.Enabled ) then return end
	if ( self.BarSize == 0 ) then return end

	self:MouseCapture( true )
	self.Dragging = true

	local x, y = self.btnGrip:ScreenToLocal( gui.MouseX(), 0 )
	self.HoldPos = x

	self.btnGrip.Depressed = true

end

function PANEL:PerformLayout()

	local Tall = self:GetTall()
	local BtnWidth = Tall
	if ( self:GetHideButtons() ) then BtnWidth = 0 end
	local Scroll = self:GetScroll() / self.CanvasSize
	local BarSize = math.max( self:BarScale() * ( self:GetWide() - ( BtnWidth * 2 ) ), 10 )
	local Track = self:GetWide() - ( BtnWidth * 2 ) - BarSize
	Track = Track + 1

	Scroll = Scroll * Track

	self.btnGrip:SetPos( BtnWidth + Scroll, 0 )
	self.btnGrip:SetSize( BarSize, Tall )

	if ( BtnWidth > 0 ) then
		self.btnLeft:SetPos( 0, 0 )
		self.btnLeft:SetSize( BtnWidth, Tall )

		self.btnRight:SetPos( self:GetWide() - BtnWidth, 0 )
		self.btnRight:SetSize( BtnWidth, Tall )

		self.btnLeft:SetVisible( true )
		self.btnRight:SetVisible( true )
	else
		self.btnLeft:SetVisible( false )
		self.btnRight:SetVisible( false )
		self.btnRight:SetSize( BtnWidth, Tall )
		self.btnLeft:SetSize( BtnWidth, Tall )
	end

end

derma.DefineControl( "DHScrollBar", "A Horizontal Scrollbar", PANEL, "Panel" )
