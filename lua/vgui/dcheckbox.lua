--[[ DCheckBox -- GMod-style check box (original implementation).

	NOT the engine's vgui::CheckButton.  GMod's DCheckBox/DCheckBoxLabel is a
	plain panel whose box is painted by the Derma skin (the wiki says
	DCheckBoxLabel "derives from DPanel"), and it has to be that here too:

	  * vgui::CheckButton draws a scheme-font check glyph through its CheckImage
	    child (26px in this scheme) and paints its caption in the panel's scheme
	    font -- so it always looks like a big Source checkbox and ignores the
	    Derma skin completely.  That is exactly what the first version of this
	    control produced: twice GMod's size, with a big official-looking tick.
	  * the fork's skin ALREADY has SKIN:PaintCheck (lua/skins/hl2sb_default.lua)
	    doing the GMod look -- 16px box, thin tick, caption in DermaDefault --
	    and nothing was calling it.

	So this is a DPanel: the skin paints it, Lua handles the click, and the
	geometry below is the single source of truth for both the skin and
	SizeToContents (they cannot drift apart).

	Mouse/click: LPanel's Lua dispatch delivers OnMousePressed to this class, so
	the toggle is ours -- there is no engine CheckButton underneath to do it.
--]]

local PANEL = {}

-- Geometry (read by SKIN:PaintCheck as pnl.m_iBoxX / pnl.m_iBoxSize / ...).
PANEL.m_iBoxX    = 2			-- box origin inside the panel
PANEL.m_iBoxSize = 16			-- GMod's checkbox is 16x16
PANEL.m_iTextGap = 6			-- gap between box and caption

function PANEL:Init()
	self.m_bChecked = false
	self.m_bHover   = false

	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )

	if ( self.SetCursor ) then self:SetCursor( "hand" ) end
end

-------------------------------------------------------------------------------
-- Caption.  Painted by the skin from m_strText -- deliberately NOT a child
-- DLabel: a second caption on top of the skin's is exactly the double-paint
-- bug this control went through.
-------------------------------------------------------------------------------
function PANEL:SetText( strText )
	self.m_strText = tostring( strText or "" )
	self:InvalidateLayout( true )
end

function PANEL:GetText()
	return self.m_strText or ""
end

function PANEL:GetCaptionX()
	return ( self.m_iBoxX or 2 ) + ( self.m_iBoxSize or 16 ) + ( self.m_iTextGap or 6 ) + ( self:GetIndent() or 0 )
end

-------------------------------------------------------------------------------
-- State.  SetChecked notifies (see derma/init.lua's convar wiring: it wraps
-- OnCheckButtonChecked, which is what writes the convar back).
-------------------------------------------------------------------------------
function PANEL:SetChecked( b )
	b = b and true or false
	if ( self.m_bChecked == b ) then return end

	self.m_bChecked = b
	self:OnCheckButtonChecked()
end

function PANEL:GetChecked()
	return self.m_bChecked and true or false
end

function PANEL:IsChecked()
	return self:GetChecked()
end

function PANEL:SetValue( b )
	self:SetChecked( b )
end

function PANEL:Toggle()
	self:SetChecked( not self:GetChecked() )
end

--- The hook the convar wiring hangs off (hl2sb derma/init.lua
--- InstallConVar( "DCheckBox", { name = "OnCheckButtonChecked", ... } )).
function PANEL:OnCheckButtonChecked()
	if ( self.OnChange ) then
		local ok, err = pcall( self.OnChange, self, self:GetChecked() )
		if ( not ok ) then Warning( "DCheckBox:OnChange failed: " .. tostring( err ) .. "\n" ) end
	end
end

-------------------------------------------------------------------------------
-- Input
-------------------------------------------------------------------------------
function PANEL:OnMousePressed( iMouseCode )
	-- MOUSE_LEFT is 107 (Source's BUTTON_CODE); if the global is missing, accept
	-- any button rather than making the box dead.
	if ( MOUSE_LEFT ~= nil and iMouseCode ~= MOUSE_LEFT ) then return end
	if ( self.IsEnabled and not self:IsEnabled() ) then return end

	self:Toggle()
end

function PANEL:OnCursorEntered() self.m_bHover = true end
function PANEL:OnCursorExited() self.m_bHover = false end

-------------------------------------------------------------------------------
-- Paint: the skin owns the look (GMod's split, and this fork's skin has the
-- implementation already).
-------------------------------------------------------------------------------
function PANEL:Paint( w, h )
	derma.SkinHook( "Paint", "Check", self, w or self:GetWide(), h or self:GetTall() )
end

derma.DefineControl( "DCheckBox", "HL2SB check box", PANEL, "DPanel" )
