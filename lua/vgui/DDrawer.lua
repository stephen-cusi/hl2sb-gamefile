--[[ DDrawer -- a panel that slides out of the bottom of its parent (original).

	Wiki: https://wiki.facepunch.com/gmod/DDrawer
	  "A simple Derma Drawer"
	  Parent: DPanel.
	  Methods: Open / Close / Toggle / SetOpenSize / GetOpenSize / SetOpenTime / GetOpenTime
	  The example docks a child DPanel FILL inside it and opens it.

	GMod's file, kept as-is where this fork allows it: the drawer parks itself at
	`y = parentTall - tall`, spans the parent's width, animates its own height towards
	`OpenSize` (or 0) over `OpenTime`, and owns a small toggle button that rides just
	above the drawer.

	⚠️ Two substitutions, both because the binding does not exist in this fork
	(`Panel:SizeTo` and `Panel:SetIcon` are not bound - only MoveToFront/CenterHorizontal
	are):
	  * the height animation runs in OnThink (the height approaches the target at
	    OpenSize/OpenTime units per second) instead of Panel:SizeTo;
	  * the toggle button draws its own up/down arrow in Paint instead of SetIcon
	    (an image would need `icon16/bullet_arrow_*.png`, which may or may not be mounted).
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_iOpenSize", "OpenSize", FORCE_NUMBER )
AccessorFunc( PANEL, "m_fOpenTime", "OpenTime", FORCE_NUMBER )

function PANEL:Init()
	self.m_bOpened = false
	self.m_flCurrent = 0

	self:SetOpenSize( 100 )
	self:SetOpenTime( 0.3 )

	if ( self.SetPaintBackground ) then
		self:SetPaintBackground( false )
	elseif ( self.SetDrawBackground ) then
		self:SetDrawBackground( false )
	end

	self:SetSize( 0, 0 )

	-- GMod parents the toggle button to the drawer's PARENT (it floats above the drawer)
	self.ToggleButton = vgui.Create( "DButton", self:GetParent() )

	if ( IsValid( self.ToggleButton ) ) then
		self.ToggleButton:SetSize( 18, 18 )
		self.ToggleButton:SetText( "" )
		self.ToggleButton.DoClick = function() self:Toggle() end

		-- the arrow: drawn, not an icon (see the header)
		self.ToggleButton.Paint = function( pnl, w, h )
			surface.DrawSetColor( 60, 60, 60, 220 )
			surface.DrawFilledRect( 0, 0, w, h )

			surface.DrawSetColor( 220, 220, 220, 255 )
			local cx = math.floor( w / 2 )
			local cy = math.floor( h / 2 )

			if ( self.m_bOpened ) then
				-- down: two strokes forming a chevron
				surface.DrawFilledRect( cx - 4, cy - 3, cx - 3, cy - 2 )
				surface.DrawFilledRect( cx - 3, cy - 2, cx - 2, cy - 1 )
				surface.DrawFilledRect( cx - 2, cy - 1, cx + 2, cy )
				surface.DrawFilledRect( cx + 2, cy - 2, cx + 3, cy - 1 )
				surface.DrawFilledRect( cx + 3, cy - 3, cx + 4, cy - 2 )
			else
				surface.DrawFilledRect( cx - 4, cy + 2, cx - 3, cy + 3 )
				surface.DrawFilledRect( cx - 3, cy + 1, cx - 2, cy + 2 )
				surface.DrawFilledRect( cx - 2, cy, cx + 2, cy + 1 )
				surface.DrawFilledRect( cx + 2, cy + 1, cx + 3, cy + 2 )
				surface.DrawFilledRect( cx + 3, cy + 2, cx + 4, cy + 3 )
			end
		end

		self.ToggleButton.OnThink = function()
			if ( IsValid( self ) ) then self:PlaceToggleButton() end
		end
	end
end

--- The toggle button rides just above the drawer (GMod sets `ToggleButton.y` by hand,
--- which works because the engine syncs the x/y/w/h fields - see lua/vgui/DPanel.lua).
function PANEL:PlaceToggleButton()
	if ( not IsValid( self.ToggleButton ) ) then return end

	self.ToggleButton:CenterHorizontal()

	local y = ( self.y or 0 ) - 8
	self.ToggleButton.y = y
	self.ToggleButton:SetPos( self.ToggleButton.x or 0, y )
end

function PANEL:OnRemove()
	if ( IsValid( self.ToggleButton ) ) then self.ToggleButton:Remove() end
end

-------------------------------------------------------------------------------
-- open / close
-------------------------------------------------------------------------------
function PANEL:Toggle()
	if ( self.m_bOpened ) then
		self:Close()
	else
		self:Open()
	end
end

--- Wiki: "Opens the DDrawer."
function PANEL:Open()
	if ( self.m_bOpened == true ) then return end

	self.m_bOpened = true

	if ( IsValid( self.ToggleButton ) ) then self.ToggleButton:MoveToFront() end
end

--- Wiki: "Closes the DDrawer."
function PANEL:Close()
	if ( self.m_bOpened == false ) then return end

	self.m_bOpened = false

	if ( IsValid( self.ToggleButton ) ) then self.ToggleButton:MoveToFront() end
end

-------------------------------------------------------------------------------
-- per-frame: park + animate (Panel:SizeTo does not exist here, see the header)
-------------------------------------------------------------------------------
function PANEL:OnThink()
	local parent = self:GetParent()

	if ( IsValid( parent ) ) then
		local w, h = parent:GetSize()

		self:SetPos( 0, h - self:GetTall() )
		self:SetWide( w )
	end

	local openSize = self.m_iOpenSize or 100
	local target = self.m_bOpened and openSize or 0
	local cur = self.m_flCurrent or 0

	if ( cur ~= target ) then
		local time = math.max( 0.01, self.m_fOpenTime or 0.3 )
		local step = ( openSize / time ) * ( FrameTime() or 0.015 )

		if ( cur < target ) then
			cur = math.min( target, cur + step )
		else
			cur = math.max( target, cur - step )
		end

		self.m_flCurrent = cur
		self:SetTall( cur )
	end

	self:PlaceToggleButton()
end

--- GMod spells it Panel:Think; this fork dispatches OnThink.
function PANEL:Think()
	self:OnThink()
end

function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )

	ctrl:SetOpenSize( 75 )
	ctrl:SetOpenTime( 0.2 )
	ctrl:Open()

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DDrawer", "A drawer that slides out of its parent", PANEL, "DPanel" )
