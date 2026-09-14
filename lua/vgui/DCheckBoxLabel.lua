--[[ DCheckBoxLabel -- a check box with its caption next to it.

	Wiki: DCheckBoxLabel -- "a DCheckBox with a DLabel next to it".  Here the
	box and the caption are both painted by the skin (SKIN:PaintCheck), so this
	control is the label-shaped API on top of DCheckBox:

		SetValue / Toggle / SetIndent / GetIndent / SetDark / SetBright /
		SetFont / SetTextColor / SizeToContents / OnChange

	Inherited through the DCheckBox base: SetText / GetText, SetChecked /
	GetChecked / IsChecked, Toggle, OnChange, and the whole Panel:SetConVar
	family (installed onto DCheckBox by derma/init.lua through
	derma.InstallConVarLink).

	SizeToContents is the box + the caption in the panel's font, taken from the
	same geometry the skin paints with (DCheckBox.m_iBoxX / m_iBoxSize /
	m_iTextGap via GetCaptionX), so the two cannot drift apart.

	⚠️ Documented deviation: the wiki says SetChecked does not notify while
	SetValue does.  Here they are equivalent -- the convar write hangs off
	OnCheckButtonChecked, which any state change goes through.  SetValue
	therefore also writes the convar, which is what the wiki example relies on.
--]]

local PANEL = {}

function PANEL:Init()
	self.m_iIndent = 0
	self.m_bDark = false
end

--- GMod: AccessorFunc -- X offset of the caption (added to GetCaptionX).
function PANEL:GetIndent()
	return self.m_iIndent or 0
end

function PANEL:SetIndent( iIndent )
	self.m_iIndent = tonumber( iIndent ) or 0
	self:InvalidateLayout( true )
end

--- GMod: sets the checked state AND notifies (OnChange + the convar write).
function PANEL:SetValue( bChecked )
	self:SetChecked( bChecked and true or false )
end

function PANEL:Toggle()
	self:SetValue( not self:GetChecked() )
end

--- GMod: SetFont( name ) -- a font NAME.  The skin reads pnl.m_strDermaFont, so
--- this really does change the caption's font.
function PANEL:SetFont( strFont )
	self.m_strDermaFont = strFont
	self:InvalidateLayout( true )
end

--- GMod: SetTextColor( color ).  The skin's text helper prefers a per-panel
--- colour when one is set (see SKIN:PaintCheck / drawText).
function PANEL:SetTextColor( clr )
	self.m_colText = clr
end

--- GMod: "sets the text of the DCheckBoxLabel to be dark colored in accordance
--- with the currently active Derma skin".  This fork's built-in skin does not
--- define DCheckBoxLabel text colours yet, so these two are what paints.
function PANEL:SetDark( bDark )
	self.m_bDark = bDark and true or false

	self:SetTextColor( self.m_bDark and Color( 60, 60, 60, 255 ) or Color( 255, 255, 255, 255 ) )
end

function PANEL:SetBright( bBright )
	self:SetDark( not bBright )
end

--- GMod: "sizes the panel to the size of the internal DLabel and DButton".
--- box (GetCaptionX) + caption + a 2px right pad, and tall enough for the box.
function PANEL:SizeToContents()
	local w, h = derma.GetTextSize( self.m_strDermaFont or derma.DefaultFont, self:GetText() or "" )

	local boxTall = ( self.m_iBoxSize or 16 ) + 4
	self:SetSize( self:GetCaptionX() + w + 2, math.max( boxTall, h + 4 ) )
end

derma.DefineControl( "DCheckBoxLabel", "HL2SB check box with label", PANEL, "DCheckBox" )
