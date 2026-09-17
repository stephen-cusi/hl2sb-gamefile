--[[ DHorizontalScroller -- a horizontally scrolling row of panels (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DHorizontalScroller
	  "A panel that allows you to horizontally scroll through panels.  Each panel
	  should be sized appropriately."  Parent: Panel.
	  AddPanel / GetCanvas / SetOverlap / GetOverlap / SetScroll / ScrollToChild /
	  MakeDroppable / SetUseLiveDrag / SetShowDropTargets + the btnLeft / btnRight
	  arrow buttons - all present here.

	Ported from GMod's lua/vgui/dhorizontalscroller.lua (217 lines).  The scrolling
	is a live-layout trick: the canvas is a DDragBase whose children are positioned
	in PerformLayout, and the canvas is then moved left by OffsetX, so no clipping
	panel and no scrollbar are involved.

	Deliberate deviations from GMod:
	  * GMod assigns `self.pnlCanvas.x = -OffsetX` directly.  In this fork only the
	    geometry bindings keep the Lua x/y fields in sync
	    (public/lua/vgui_controls/lPanel.cpp:1109 Panel_SyncLuaGeometry is called
	    from SetPos/SetSize), so a raw field write would not move anything - the
	    port calls SetPos( -OffsetX, 0 ) instead.
	  * GMod calls DDragBase.UpdateDropTarget(...) as if DDragBase were a global
	    (it is not, upstream either); the port captures the canvas's own base
	    method before overriding it.
	  * The left/right buttons ask the skin first (derma.SkinHook "ButtonLeft" /
	    "ButtonRight"); this fork's skin implements neither, so the built-in
	    arrows below draw the GMod arrows with plain rectangles.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_iOverlap", "Overlap" )
AccessorFunc( PANEL, "m_bShowDropTargets", "ShowDropTargets", FORCE_BOOL )

--- GMod's skin draws the arrows; this fork's skin has no ButtonLeft/ButtonRight,
--- so fall back to a 15x15 button with a rectangle-triangle arrow.
local function PaintArrow( pnl, w, h, bRight )
	w = w or pnl:GetWide()
	h = h or pnl:GetTall()

	if ( derma.SkinHook( "Paint", bRight and "ButtonRight" or "ButtonLeft", pnl, w, h ) ) then return end

	local bright = 200
	if ( pnl.m_bDepressed ) then bright = 255
	elseif ( pnl.m_bHover ) then bright = 235 end

	surface.DrawSetColor( 60, 60, 60, 255 )
	surface.DrawRect( 0, 0, w, h )

	surface.DrawSetColor( bright, bright, bright, 255 )

	local half = ( h - 1 ) * 0.5
	if ( half <= 0 ) then half = 1 end

	for y = 0, h - 1 do
		local f = 1 - math.abs( y - half ) / half			-- 1 on the middle row
		local len = math.max( 1, math.floor( ( w - 4 ) * f ) )

		if ( bRight ) then
			surface.DrawRect( 2, y, len, 1 )
		else
			surface.DrawRect( w - 2 - len, y, len, 1 )
		end
	end
end

function PANEL:Init()
	self.Panels = {}
	self.OffsetX = 0
	self.FrameTime = 0

	self.pnlCanvas = vgui.Create( "DDragBase", self )
	self.pnlCanvas:SetDropPos( "6" )
	self.pnlCanvas:SetUseLiveDrag( false )
	self.pnlCanvas.OnModified = function() self:OnDragModified() end

	local baseUpdateDropTarget = self.pnlCanvas.UpdateDropTarget

	self.pnlCanvas.UpdateDropTarget = function( Canvas, drop, pnl )
		if ( !self:GetShowDropTargets() ) then return end
		baseUpdateDropTarget( Canvas, drop, pnl )
	end

	self.pnlCanvas.OnChildAdded = function( Canvas, child )
		local dn = Canvas:GetDnD()
		if ( dn ) then
			child:Droppable( dn )
			child.OnDrop = function()
				local x, y = Canvas:LocalCursorPos()
				local closest, id = self.pnlCanvas:GetClosestChild( x, Canvas:GetTall() / 2 ), 0

				for k, v in pairs( self.Panels ) do
					if ( v == closest ) then id = k break end
				end

				table.RemoveByValue( self.Panels, child )
				table.insert( self.Panels, id, child )

				self:InvalidateLayout()

				return child
			end
		end
	end

	self:SetOverlap( 0 )

	self.btnLeft = vgui.Create( "DButton", self )
	self.btnLeft:SetText( "" )
	self.btnLeft.Paint = function( panel, w, h ) PaintArrow( panel, w, h, false ) end

	self.btnRight = vgui.Create( "DButton", self )
	self.btnRight:SetText( "" )
	self.btnRight.Paint = function( panel, w, h ) PaintArrow( panel, w, h, true ) end
end

function PANEL:GetCanvas()
	return self.pnlCanvas
end

function PANEL:ScrollToChild( panel )
	-- make sure our size is all good
	self:InvalidateLayout( true )

	local x, y = self.pnlCanvas:GetChildPosition( panel )
	local w, h = panel:GetSize()

	x = x + w * 0.5
	x = x - self:GetWide() * 0.5

	self:SetScroll( x )
end

function PANEL:SetScroll( x )
	self.OffsetX = x
	self:InvalidateLayout( true )
end

function PANEL:SetUseLiveDrag( bool )
	self.pnlCanvas:SetUseLiveDrag( bool )
end

function PANEL:MakeDroppable( name, allowCopy )
	self.pnlCanvas:MakeDroppable( name, allowCopy )
end

function PANEL:AddPanel( pnl )
	table.insert( self.Panels, pnl )

	pnl:SetParent( self.pnlCanvas )
	self:InvalidateLayout( true )
end

function PANEL:Clear()
	self.pnlCanvas:Clear()
	self.Panels = {}
end

function PANEL:OnMouseWheeled( dlta )
	self.OffsetX = self.OffsetX + dlta * -30
	self:InvalidateLayout( true )

	return true
end

--- ⚠️ GMod spells this Panel:Think; this fork's engine only dispatches the Lua
--- field OnThink (game/client/lua/scripted_controls/lPanel.cpp:181 LPanel::OnThink
--- -> BEGIN_LUA_CALL_PANEL_METHOD( "OnThink" )), so the body lives here and Think
--- forwards to it - same shape as the other ported controls (DDrawer/DColorMixer).
function PANEL:OnThink()
	-- Hmm.. This needs to really just be done in one place
	-- and made available to everyone.
	local FrameRate = SysTime() - self.FrameTime
	self.FrameTime = SysTime()

	if ( self.btnRight:IsDown() ) then
		self.OffsetX = self.OffsetX + ( 500 * FrameRate )
		self:InvalidateLayout( true )
	end

	if ( self.btnLeft:IsDown() ) then
		self.OffsetX = self.OffsetX - ( 500 * FrameRate )
		self:InvalidateLayout( true )
	end

	if ( dragndrop.IsDragging() ) then
		local x, y = self:LocalCursorPos()

		if ( x < 30 ) then
			self.OffsetX = self.OffsetX - ( 350 * FrameRate )
		elseif ( x > self:GetWide() - 30 ) then
			self.OffsetX = self.OffsetX + ( 350 * FrameRate )
		end

		self:InvalidateLayout( true )
	end
end

--- GMod's name for the tick above; scripts that call pnl:Think() themselves.
function PANEL:Think()
	self:OnThink()
end

function PANEL:PerformLayout()
	local w, h = self:GetSize()

	self.pnlCanvas:SetTall( h )

	local x = 0

	for k, v in pairs( self.Panels ) do
		if ( !IsValid( v ) ) then continue end
		if ( !v:IsVisible() ) then continue end

		v:SetPos( x, 0 )
		v:SetTall( h )
		if ( v.ApplySchemeSettings ) then v:ApplySchemeSettings() end

		x = x + v:GetWide() - self.m_iOverlap
	end

	self.pnlCanvas:SetWide( x + self.m_iOverlap )

	if ( w < self.pnlCanvas:GetWide() ) then
		self.OffsetX = math.Clamp( self.OffsetX, 0, self.pnlCanvas:GetWide() - self:GetWide() )
	else
		self.OffsetX = 0
	end

	-- GMod: self.pnlCanvas.x = self.OffsetX * -1  (a raw field write; see header)
	self.pnlCanvas:SetPos( self.OffsetX * -1, 0 )

	self.btnLeft:SetSize( 15, 15 )
	self.btnLeft:AlignLeft( 4 )
	self.btnLeft:AlignBottom( 5 )

	self.btnRight:SetSize( 15, 15 )
	self.btnRight:AlignRight( 4 )
	self.btnRight:AlignBottom( 5 )

	self.btnLeft:SetVisible( self.pnlCanvas.x < 0 )
	self.btnRight:SetVisible( self.pnlCanvas.x + self.pnlCanvas:GetWide() > self:GetWide() )
end

function PANEL:OnDragModified()
	-- Override me
end

function PANEL:GenerateExample( classname, sheet, w, h )
	local scroller = vgui.Create( "DHorizontalScroller" )
	scroller:Dock( TOP )
	scroller:SetHeight( 64 )
	scroller:DockMargin( 5, 50, 5, 50 )
	scroller:SetOverlap( -4 )

	for i = 0, 16 do
		local img = vgui.Create( "DImage", scroller )
		img:SetImage( "scripted/breen_fakemonitor_1" )
		scroller:AddPanel( img )
	end

	sheet:AddSheet( classname, scroller, nil, true, true )
end

derma.DefineControl( "DHorizontalScroller", "A panel that allows you to horizontally scroll through panels", PANEL, "Panel" )
