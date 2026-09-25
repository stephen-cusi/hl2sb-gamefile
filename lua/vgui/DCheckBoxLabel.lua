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
--- this really does change the caption's font.  GMod's SetText/SetFont both
--- resize the control afterwards (dcheckbox.lua:149-161) -- without the resize
--- the default-size panel clipped every longer caption.
function PANEL:SetFont( strFont )
	self.m_strDermaFont = strFont
	self:InvalidateLayout( true )
	self:SizeToContents()
end

--- GMod: DCheckBoxLabel:SetText( text ) -- caption update + resize (the base
--- DCheckBox version only stores the text).
function PANEL:SetText( strText )
	self.m_strText = tostring( strText or "" )
	self:InvalidateLayout( true )
	self:SizeToContents()
end

--- GMod: SetTextColor( color ).  The skin's text helper prefers a per-panel
--- colour when one is set (see SKIN:PaintCheck / drawText).
function PANEL:SetTextColor( clr )
	self.m_colText = clr
end

--- GMod: "sets the text of the DCheckBoxLabel to be dark colored in accordance
--- with the currently active Derma skin".  The old pair hardcoded Color(60,60,60)
--- for dark -- near-invisible on this fork's dark skin.  Resolve the skin's
--- Colours.Label.Dark like DLabel does (fallback keeps the old colour).
function PANEL:SetDark( bDark )
	self.m_bDark = bDark and true or false

	local clr = Color( 60, 60, 60, 255 )

	if ( derma.GetSkinTable ~= nil ) then
		local ok, skin = pcall( derma.GetSkinTable )
		if ( ok and skin and skin.Colours and skin.Colours.Label and skin.Colours.Label.Dark ) then
			clr = skin.Colours.Label.Dark
		end
	end

	self:SetTextColor( self.m_bDark and clr or Color( 255, 255, 255, 255 ) )
end

function PANEL:SetBright( bBright )
	self.m_bBright = bBright and true or false

	if ( bBright ) then
		self:SetDark( false )
	end
end

--- GMod: "sizes the panel to the size of the internal DLabel and DButton".
--- box (GetCaptionX) + caption + a 2px right pad, and tall enough for the box.
function PANEL:SizeToContents()
	local w, h = derma.GetTextSize( self.m_strDermaFont or derma.DefaultFont, self:GetText() or "" )

	local boxTall = ( self.m_iBoxSize or 16 ) + 4
	self:SetSize( self:GetCaptionX() + w + 2, math.max( boxTall, h + 4 ) )
end

derma.DefineControl( "DCheckBoxLabel", "HL2SB check box with label", PANEL, "DCheckBox" )
