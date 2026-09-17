--[[ DScrollBarGrip -- the draggable grip of a DVScrollBar (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DScrollBarGrip
	  DScrollBarGrip is the handle inside DVScrollBar.  Parent: DPanel.
	  GMod's file is 20 lines: OnMousePressed hands the drag to the parent
	  scrollbar, and Paint is the skin's PaintScrollBarGrip hook.

	Ported from GMod's lua/vgui/dscrollbargrip.lua.  DVScrollBar (this fork's new
	lua/vgui/DVScrollBar.lua) creates one, which is what makes that control
	complete: DVScrollBar:PerformLayout positions it, DVScrollBar:Grip() starts the
	drag from it, and DVScrollBar:OnCursorMoved moves the scroll from there.

	Deliberate deviation: this fork's skin implements PaintScrollBar (the track)
	but not PaintScrollBarGrip, so a skin hook that returns false would leave the
	grip invisible - the built-in fill below is the fallback, and it reads
	GMod's `Depressed` field, which DVScrollBar:Grip() sets.
--]]

local PANEL = {}

function PANEL:Init()
end

function PANEL:OnMousePressed()
	self:GetParent():Grip( 1 )
end

function PANEL:Paint( w, h )
	if ( derma.SkinHook( "Paint", "ScrollBarGrip", self, w, h ) ) then return true end

	w = w or self:GetWide()
	h = h or self:GetTall()

	local shade = 90
	if ( self.Depressed ) then shade = 130 end

	surface.DrawSetColor( shade, shade, shade, 255 )
	-- corner rect: this engine's DrawFilledRect takes ( x0, y0, x1, y1 )
	surface.DrawFilledRect( 0, 1, w, h - 1 )

	return true
end

derma.DefineControl( "DScrollBarGrip", "A Scrollbar Grip", PANEL, "DPanel" )
