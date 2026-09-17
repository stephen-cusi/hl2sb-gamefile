--[[ DHorizontalDividerBar -- the drag handle of a DHorizontalDivider (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DHorizontalDividerBar
	  Parent: DPanel.  GMod keeps the divider's whole input surface in this tiny
	  child: it changes the cursor and hands the press to its parent's StartGrab.

	Ported verbatim from GMod's lua/vgui/dhorizontaldivider.lua:2-19.
	This fork's DHorizontalDivider used to be grabbed by its own OnMousePressed
	(`IsOverBar`); it now creates this bar as a child (children are hit-tested
	before their parent, vgui2 Panel::IsWithinTraverse), which is what gives the
	divider its sizewe cursor in GMod.
--]]

local PANEL = {}

function PANEL:Init()

	self:SetCursor( "sizewe" )
	self:SetPaintBackground( false )

end

function PANEL:OnMousePressed( mcode )

	if ( mcode == MOUSE_LEFT ) then
		self:GetParent():StartGrab()
	end

end

derma.DefineControl( "DHorizontalDividerBar", "", PANEL, "DPanel" )
