--[[ DExpandButton -- the little +/- button (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DExpandButton
	  "The little '+' button used by DProperties and DTree_Node."
	  Parent: DButton.
	  Methods: SetExpanded / GetExpanded   ("Only changes appearance.")

	GMod's file is four lines: an AccessorFunc, `Derma_Hook( PANEL, "Paint", "Paint",
	"ExpandButton" )` and a 15x15 size - the drawing is the skin's.  This fork's skin has
	no PaintExpandButton, so the built-in glyph below draws the same thing (a box with a
	plus, minus when expanded) and the skin is still asked first.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_bExpanded", "Expanded", FORCE_BOOL )

function PANEL:Init()
	self:SetSize( 15, 15 )
	self:SetText( "" )
end

--- Wiki: "Sets whether this DExpandButton should be expanded or not. Only changes
--- appearance."
function PANEL:SetExpanded( bExpanded )
	self.m_bExpanded = bExpanded and true or false
end

function PANEL:GetExpanded()
	return self.m_bExpanded == true
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( derma.SkinHook( "Paint", "ExpandButton", self, w, h ) ) then return end

	local bright = 200

	if ( self.m_bDepressed ) then bright = 255
	elseif ( self.m_bHover ) then bright = 235 end

	surface.DrawSetColor( bright, bright, bright, 255 )

	-- ⚠️ DrawFilledRect takes two CORNERS (x0, y0, x1, y1) in this engine
	surface.DrawOutlinedRect( 0, 0, w, h )

	local cx = math.floor( w / 2 )
	local cy = math.floor( h / 2 )

	surface.DrawFilledRect( 3, cy, w - 3, cy + 1 )

	if ( not self:GetExpanded() ) then
		surface.DrawFilledRect( cx, 3, cx + 1, h - 3 )
	end
end

--- GMod has no example for this control; the same empty stub is kept so a property
--- sheet can still ask for one.
function PANEL:GenerateExample( class, tabs, w, h )
end

derma.DefineControl( "DExpandButton", "A small expand/collapse button", PANEL, "DButton" )
