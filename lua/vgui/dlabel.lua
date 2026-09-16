--[[ DLabel -- a transparent text label (original implementation).

	Draws through the framework's font/skin helpers rather than the engine's
	Label control: this fork's C Label re-applies the scheme font after every
	Lua hook (see scripted_controls/lLabel.h), which is why the copied GMod
	DLabel always rendered at the wrong size.  Text drawn in Lua from Paint
	cannot be clobbered. --]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )	-- DPanel heritage: labels are transparent
	self:SetText( "" )
	self:SetMouseInputEnabled( false )
	self:SetKeyBoardInputEnabled( false )
	self.m_strFont = "DermaDefault"
	self.m_colText = Color( 228, 228, 228, 255 )
	self.m_bWrap = false
	self.m_iAlign = 0	-- 0 left, 1 center, 2 right
end

function PANEL:SetText( strText )
	self.m_strText = tostring( strText or "" )
	if ( self.m_bAutoWide ) then self:SizeToContents() end
end

function PANEL:GetText()
	return self.m_strText or ""
end

function PANEL:SetFont( strFont )
	self.m_strFont = strFont
end

function PANEL:GetFont()
	return self.m_strFont
end

function PANEL:SetTextColor( clr )
	self.m_colText = clr or self.m_colText
end

function PANEL:GetTextColor()
	return self.m_colText
end

function PANEL:SetWrap( b )
	self.m_bWrap = b
end

function PANEL:SetContentAlignment( iAlign )
	self.m_iAlign = iAlign
end

function PANEL:SizeToContents()
	local w, h = derma.GetTextSize( self.m_strFont, self.m_strText or "" )
	self:SetSize( w + 2, h + 2 )
end

--- GMod idiom: widen to the text and let the parent's layout place it.
function PANEL:DockToWindowPosition( x, y )
	self:SetPos( x, y )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local text = self.m_strText or ""
	if ( text == "" ) then return end

	local tw, th = derma.GetTextSize( self.m_strFont, text )
	local x = 0
	if ( self.m_iAlign == 1 ) then x = math.floor( ( w - tw ) / 2 )
	elseif ( self.m_iAlign == 2 ) then x = w - tw end
	local y = math.floor( ( h - th ) / 2 )

	derma.DrawText( self.m_strFont, x, y, text, self.m_colText )
end

derma.DefineControl( "DLabel", "HL2SB text label", PANEL, "DPanel" )
