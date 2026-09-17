--[[ DVerticalDividerBar -- the drag handle of a DVerticalDivider (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DVerticalDividerBar
	  Parent: DPanel.  The vertical twin of DHorizontalDividerBar: it sets the
	  sizens cursor and hands the press to its parent's StartGrab.

	Ported verbatim from GMod's lua/vgui/dverticaldivider.lua:2-19.  See the note in
	lua/vgui/DVerticalDividerBar.lua's sibling file about this fork's divider
	creating it as a child.
--]]

local PANEL = {}

function PANEL:Init()

	self:SetCursor( "sizens" )
	self:SetPaintBackground( false )

end

function PANEL:OnMousePressed( mcode )

	if ( mcode == MOUSE_LEFT ) then
		self:GetParent():StartGrab()
	end

end

derma.DefineControl( "DVerticalDividerBar", "", PANEL, "DPanel" )
