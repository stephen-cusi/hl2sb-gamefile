--[[ DScrollPanel -- a container that scrolls (GMod port).

	Ported from GMod's lua/vgui/dscrollpanel.lua onto this fork's DVScrollBar
	(GMod's pixel scrollbar, lua/vgui/DVScrollBar.lua).  The whole GMod
	architecture is in place:

	  * pnlCanvas.PerformLayout drives the measure loop.  Every canvas relayout
	    re-runs PerformLayoutInternal, which measures the children
	    (Rebuild -> canvas:SizeToChildren( false, true )) and feeds the result
	    to VBar:SetUp( panelTall, canvasTall ).  A Dock(TOP) child invalidates
	    its parent (Panel::SetDock -> InvalidateParentLayout), so rows added to
	    the canvas grow it on the next layout pass and the bar enables itself
	    exactly when the content outgrows the panel.  The canvas PANEL must
	    grow: this engine clips child painting to the canvas bounds, so a
	    viewport-sized canvas hides everything laid out below it.

	  * The scroll offset is GMod's: DVScrollBar:SetScroll calls back into
	    OnVScroll( offset ) which moves the canvas, and PerformLayoutInternal
	    re-applies the same offset on every layout pass.  The previous fork
	    scheme kept a private m_iPos pixel value and shifted the canvas in
	    Paint while the canvas itself stayed viewport-sized forever - children
	    beyond the visible rect never grew it, the bar stayed disabled, and
	    plain DScrollPanels (the player-model menu's Model list) could not
	    scroll at all.

	Deviations from GMod's file, all forced by this fork (marked at their site):
	  * The bar is positioned manually in PerformLayoutInternal instead of
	    Dock(RIGHT) - the same strip GMod's dvscrollbar.lua usage note and
	    dpanellist.lua PerformLayout reserve, without leaning on the dock pass.
	  * PANEL:Add keeps the fork's string/table forms (DProperties relies on
	    them).  GMod's OnChildAdded -> AddItem re-parenting is NOT ported: this
	    engine fires OnChildAdded during vgui.Create, before self.pnlCanvas is
	    assigned, so the hook would re-parent (detach) the canvas on creation -
	    the same crash class the Panel:SetParent(nil) fix removed
	    (public/lua/vgui_controls/lPanel.cpp, Panel_SetParent).
	  * GMod's InvalidateParent() runs under its bound name
	    InvalidateParentLayout().
	  * SetPadding() is actually applied in the layout (GMod stores the value
	    and never uses it); DForm-era consumers were built against the fork
	    behaviour.
--]]

local PANEL = {}

AccessorFunc( PANEL, "Padding", "Padding" )

-- Touch-friendly metrics (strip width): default follows system.IsAndroid()
-- (never IsLinux); hl2sb_touch_ui overrides.  Same convar as DVScrollBar.
CreateClientConVar( "hl2sb_touch_ui", system.IsAndroid() and "1" or "0", true, false )

local function TouchUI()
	local cv = GetConVar( "hl2sb_touch_ui" )
	return cv and cv:GetInt() == 1
end

local function BarWidth()
	return TouchUI() and 24 or 15		-- GMod's DVScrollBar is 15px wide
end

function PANEL:Init()
	self.pnlCanvas = vgui.Create( "DPanel", self, "ContentContainer" )
	self.pnlCanvas:SetDrawBackground( false )
	self.pnlCanvas:SetMouseInputEnabled( true )

	-- GMod: the canvas hands presses back to the scroll panel
	-- (dscrollpanel.lua:10) so the empty canvas area still scrolls/drags.
	self.pnlCanvas.OnMousePressed = function( slf, code )
		slf:GetParent():OnMousePressed( code )
	end

	-- GMod: the canvas' own layout pass drives the whole measure
	-- (dscrollpanel.lua:12-17).  This is what keeps the canvas sized to its
	-- children no matter how they were added.
	self.pnlCanvas.PerformLayout = function( pnl )
		self:PerformLayoutInternal()
		self:InvalidateParentLayout()
	end

	self.VBar = vgui.Create( "DVScrollBar", self, "VBar" )

	self:SetPadding( 0 )
	self:SetMouseInputEnabled( true )
	self:SetPaintBackgroundEnabled( false )
	self:SetPaintBorderEnabled( false )
	self:SetDrawBackground( false )

	self.m_bHorizontalScroll = false

	-- Previous fork spellings of the same two children.  GMod's documented
	-- member names are pnlCanvas / VBar (its own files read scroll.pnlCanvas
	-- and scroll.VBar all over); DScroller reads m_pInner.m_pVBar and
	-- derma_lib_test checks pnlCanvas / pnlVBar, so all of them stay valid.
	self.m_pCanvas = self.pnlCanvas
	self.m_pVBar = self.VBar
	self.pnlVBar = self.VBar
end

--- GMod: DScrollPanel:AddItem( pnl ) - "Adds a panel to the scroll panel".
function PANEL:AddItem( pnl )
	if ( IsValid( pnl ) ) then
		pnl:SetParent( self:GetCanvas() )
	end

	return pnl
end

--- The fork's wider Add contract (DProperties passes anonymous tables, other
--- code passes class names).  Panel instances go to the canvas like AddItem;
--- the string/table forms build the control on the canvas.
function PANEL:Add( pnl )
	if ( isstring( pnl ) or istable( pnl ) ) then
		return vgui.Create( pnl, self:GetCanvas() )
	end

	return self:AddItem( pnl )
end

--- GMod: DScrollPanel:Clear() - "Removes all panels from the canvas".
function PANEL:Clear()
	return self.pnlCanvas:Clear()
end

--- GMod: DScrollPanel:SizeToContents() - sizes the panel to its canvas
--- (dscrollpanel.lua:45-49).
function PANEL:SizeToContents()
	self:SetSize( self.pnlCanvas:GetSize() )
end

function PANEL:GetVBar()
	return self.VBar
end

function PANEL:GetCanvas()
	return self.pnlCanvas
end

function PANEL:InnerWidth()
	return self:GetCanvas():GetWide()
end

--- GMod: DScrollPanel:Rebuild() - "Recalculates the height of the canvas"
--- (dscrollpanel.lua:69-80): size the canvas to its children.  The vertical
--- centring branch is GMod's, kept verbatim (m_bNoSizing is normally unset).
function PANEL:Rebuild()
	self:GetCanvas():SizeToChildren( false, true )

	-- Although this behaviour isn't exactly implied, center vertically too
	if ( self.m_bNoSizing && self:GetCanvas():GetTall() < self:GetTall() ) then
		self:GetCanvas():SetPos( 0, ( self:GetTall() - self:GetCanvas():GetTall() ) * 0.5 )
	end
end

function PANEL:OnMouseWheeled( dlta )
	return self.VBar:OnMouseWheeled( dlta )
end

--- GMod: the bar pushes its offset here (DVScrollBar:SetScroll -> the parent's
--- OnVScroll); the canvas moves and PerformLayoutInternal keeps the position
--- on later layout passes.
function PANEL:OnVScroll( iOffset )
	self.pnlCanvas:SetPos( self:GetPadding(), ( iOffset or 0 ) + self:GetPadding() )
end

--- GMod: DScrollPanel:ScrollToChild( panel ) - centres the child with a short
--- animated scroll (dscrollpanel.lua:94-106).  GetChildPosition is the panel
--- extension of the same name (includes/extensions/client/panel.lua).
function PANEL:ScrollToChild( panel )
	self:InvalidateLayout( true )

	local x, y = self.pnlCanvas:GetChildPosition( panel )
	local w, h = panel:GetSize()

	y = y + h * 0.5
	y = y - self:GetTall() * 0.5

	self.VBar:AnimateTo( y, 0.5, 0, 0.5 )
end

--- GMod: PerformLayoutInternal (dscrollpanel.lua:109-131) - the measure loop.
--- "Avoid an infinite loop": call this from the canvas' PerformLayout hook or
--- the panel's PerformLayout, never from itself through a layout invalidation.
--- VPanel::SetSize early-returns when the size did not change, so the
--- SizeToChildren -> SetSize -> relayout cycle settles after one extra pass.
function PANEL:PerformLayoutInternal()
	if ( not IsValid( self.pnlCanvas ) or not IsValid( self.VBar ) ) then return end

	local Tall = self.pnlCanvas:GetTall()
	local pad = self:GetPadding() or 0
	local Wide = self:GetWide() - pad * 2
	local YPos = 0

	-- Reserve the bar strip (GMod's DVScrollBar width, 24px on touch) instead
	-- of Dock(RIGHT).
	local barW = BarWidth()
	self.VBar:SetPos( self:GetWide() - barW, 0 )
	self.VBar:SetSize( barW, self:GetTall() )

	self:Rebuild()

	self.VBar:SetUp( self:GetTall(), self.pnlCanvas:GetTall() )
	YPos = self.VBar:GetOffset()

	if ( self.VBar.Enabled ) then Wide = Wide - barW end

	self.pnlCanvas:SetPos( pad, YPos + pad )
	self.pnlCanvas:SetWide( Wide )

	self:Rebuild()

	if ( Tall ~= self.pnlCanvas:GetTall() ) then
		self.VBar:SetScroll( self.VBar:GetScroll() ) -- Make sure we are not too far down!
	end
end

function PANEL:PerformLayout()
	self:PerformLayoutInternal()
end

--------------------------------------------------------------------------------
-- Previous fork API, kept for in-tree consumers (DListView, DScroller,
-- DPanelList:SizeToContents, gameui/addonsdialog.lua, hl2sb_lua_errors.lua).
-- Under the GMod architecture "the content is iH tall" means exactly "the
-- canvas is iH tall"; the measure loop turns that into the bar range on the
-- next layout pass.
--------------------------------------------------------------------------------

function PANEL:SetContentHeight( iH )
	self.pnlCanvas:SetTall( iH or 0 )
	self:InvalidateLayout()
end

function PANEL:ContentSizeChanged( w, h )
	self:SetContentHeight( h )
end

function PANEL:InvalidateContentSize( b )
	local _, h = self.pnlCanvas:GetChildrenSize()
	self:SetContentHeight( h or 0 )
end

function PANEL:SetVScrollRange( iMin, iMax )
	self:SetContentHeight( iMax )
end

--- Pixel scroll value = the bar's pixel scroll (DVScrollBar stores pixels).
function PANEL:SetValue( iVal )
	self.VBar:SetScroll( tonumber( iVal ) or 0 )
end

function PANEL:GetValue()
	return self.VBar:GetScroll()
end

function PANEL:GetVScrollPos()
	return self:GetValue()
end

function PANEL:SetScrollY( pixels )
	self:SetValue( pixels )
end

--- Vertical only: the value is recorded, no horizontal bar drives it yet.
function PANEL:SetScrollX( pixels )
	self.m_iScrollX = tonumber( pixels ) or 0
end

derma.DefineControl( "DScrollPanel", "A scrollable panel", PANEL, "DPanel" )
