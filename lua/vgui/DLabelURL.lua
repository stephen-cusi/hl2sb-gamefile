--[[ DLabelURL -- a label that opens a URL when clicked (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DLabelURL
	  Parent: URLLabel.  SetURL / GetURL, SetTextColor / GetColor (alias SetColor),
	  SetTextStyleColor, and the hover colour change.

	Ported from GMod's lua/vgui/dlabelurl.lua (63 lines), including the
	OnCursorEntered / OnCursorExited pair that brightens the text while hovering.

	Notes for this fork:
	  * GMod derives from the engine's URLLabel.  This fork's Lua vgui factory only
	    binds Panel / Frame / Label / TextEntry / Button / CheckButton / ModelPanel /
	    PropertyDialog / PropertyPage (public/lua/vgui_controls/), so there is no
	    scripted URLLabel to derive from; the control is built on DLabel instead and
	    the click opens the URL through gui.OpenURL, which was added to the gui
	    table together with this port (public/lua/vgui/LISurface.cpp ->
	    ISystem::ShellExecute("open", url)).  SetURL / GetURL / DoClick are the same
	    methods GMod's URLLabel gives the control.
	  * Label:SetFGColor does not exist here (public/lua/vgui_controls/lLabel.cpp
	    has no such binding), so UpdateFGColor goes through DLabel:SetTextColor /
	    DLabel:SetTextStyleColor, which is the same colour this fork's Paint reads.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_colTextStyle", "TextStyleColor" )

AccessorFunc( PANEL, "m_bAutoStretchVertical", "AutoStretchVertical" )

--[[ Colour precedence, GMod's rule (dlabelurl.lua:28-40): an explicit SetTextColor
	wins over the style colour, so

		GetColor() = m_colText or m_colTextStyle

	In GMod both end up in the engine Label's FGColor, which is what paints.  This
	fork's DLabel paints its own `m_colText` field in Lua, so the resolved colour is
	written there by UpdateFGColor and the two GMod fields are kept for precedence
	(an AccessorFunc for m_colText would otherwise clobber SetTextColor).  --]]

function PANEL:SetTextColor( clr )

	self.m_colText = clr
	self:UpdateFGColor()

end
PANEL.SetColor = PANEL.SetTextColor

function PANEL:GetColor()

	return self.m_colText or self.m_colTextStyle

end

--- GMod's SetTextStyleColor is the AccessorFunc above in its own file too; here it
--- also has to repaint, because the style colour is not an engine Label style.
function PANEL:SetTextStyleColor( col )
	self.m_colTextStyle = col
	self:UpdateFGColor()
end

function PANEL:GetTextStyleColor()
	return self.m_colTextStyle
end

function PANEL:Init()

	self:SetURL( "" )

	-- DLabel:Init seeds m_colText with the default label colour; GMod's URLLabel has
	-- no such default (its colour stays nil until SetTextColor), and GetColor's
	-- precedence rule wants nil there so the style colour applies.
	self.m_colText = nil
	self:SetTextStyleColor( Color( 0, 0, 255 ) )

	-- DLabel:Init turns mouse input off (GMod's dlabel.lua:28 does the same), and
	-- GMod's URLLabel is an engine control that draws its own text with the mouse
	-- left on - so a link has to take it back.
	self:SetMouseInputEnabled( true )

	-- Nicer default height
	self:SetTall( 20 )

	-- This turns off the engine drawing
	self:SetPaintBackgroundEnabled( false )
	self:SetPaintBorderEnabled( false )

end

--- GMod's URLLabel:SetURL / GetURL - the address DoClick opens.
function PANEL:SetURL( strURL )
	self.m_strURL = strURL or ""
end

function PANEL:GetURL()
	return self.m_strURL or ""
end

function PANEL:ApplySchemeSettings()

	self:UpdateFGColor()

end

function PANEL:SetTextColor( clr )

	self.m_colText = clr
	self:UpdateFGColor()

end
PANEL.SetColor = PANEL.SetTextColor

function PANEL:GetColor()

	return self.m_colText or self.m_colTextStyle

end

function PANEL:OnCursorEntered()

	self:SetTextStyleColor( Color( 0, 50, 255 ) )
	self:UpdateFGColor()

end

function PANEL:OnCursorExited()

	self:SetTextStyleColor( Color( 0, 0, 255 ) )
	self:UpdateFGColor()

end

--- GMod's UpdateFGColor hands the resolved colour to the engine Label's FGColor.
--- This fork's DLabel paints self.m_colText itself, so the colour is resolved for
--- the paint only (Paint below): writing it into m_colText here would make GetColor
--- answer the paint colour instead of the style colour, and the hover colour would
--- stop applying.
function PANEL:UpdateFGColor()
end

--- DLabel.Paint reads self.m_colText; resolve GMod's precedence rule around it.
function PANEL:Paint( w, h )
	local saved = self.m_colText
	self.m_colText = self:GetColor()

	DLabel.Paint( self, w, h )

	self.m_colText = saved
end

--- GMod's URLLabel does this in C++ (it is a vgui control); DLabel has no click
--- handling of its own, so the click lands here.
function PANEL:DoClick()

	local url = self:GetURL()
	if ( url == "" ) then return end

	if ( gui and gui.OpenURL ) then
		gui.OpenURL( url )
	end

end

--- DLabel draws its text with the engine Label; a URL needs the hand cursor.
function PANEL:OnCursorMoved( x, y )
	self:SetCursor( "hand" )
end

derma.DefineControl( "DLabelURL", "A Label that opens a URL", PANEL, "DLabel" )
