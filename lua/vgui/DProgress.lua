--[[ DProgress -- a progress bar 0..1 (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DProgress
	  "A progressbar, works with a fraction between 0 and 1 where 0 is 0% and 1 is 100%"
	  Parent: Panel.  Methods: DProgress:GetFraction / DProgress:SetFraction.

	Everything worth knowing is GMod's skin's PaintProgress hook
	(`Derma_Hook( PANEL, "Paint", "Paint", "Progress" )` in GMod's vgui/dprogress.lua),
	so the skin is asked first and the built-in bar below is the fallback - a control
	that never painted would be worse than one that paints in the wrong style, and
	derma.SkinHook returns false when no skin implements the hook.
--]]

local PANEL = {}

function PANEL:Init()
	-- nothing here reacts to the mouse (GMod does the same)
	self:SetMouseInputEnabled( false )
	self:SetKeyBoardInputEnabled( false )

	self.m_fFraction = 0
end

function PANEL:SetFraction( f )
	self.m_fFraction = tonumber( f ) or 0
end

function PANEL:GetFraction()
	return self.m_fFraction or 0
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( derma.SkinHook( "Paint", "Progress", self, w, h ) ) then return end

	local f = self:GetFraction()

	-- clamped for DRAWING only: GetFraction hands back what was set, like GMod
	if ( f < 0 ) then f = 0 elseif ( f > 1 ) then f = 1 end

	surface.DrawSetColor( 55, 55, 55, 255 )
	surface.DrawFilledRect( 0, 0, w, h )

	local fillW = math.floor( ( w - 2 ) * f )
	if ( fillW > 0 ) then
		surface.DrawSetColor( 90, 140, 220, 255 )
		surface.DrawFilledRect( 1, 1, 1 + fillW, h - 1 )
	end

	surface.DrawSetColor( 0, 0, 0, 255 )
	-- ⚠️ the engine's DrawOutlinedRect takes two CORNERS (x0, y0, x1, y1), unlike
	-- GMod's surface.DrawOutlinedRect( x, y, w, h ) - so ( 0, 0, w, h ) is right here.
	surface.DrawOutlinedRect( 0, 0, w, h )
end

--- The wiki example and GMod's own property-sheet pages create one like this.
function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )
	ctrl:SetFraction( 0.6 )
	ctrl:SetSize( Width or 300, Height or 20 )

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DProgress", "A progress bar (0..1)", PANEL, "Panel" )
