--[[ DCheckBoxLabel -- a check box with its caption next to it.

	Wiki: DCheckBoxLabel -- "a DCheckBox with a DLabel next to it".  GMod builds
	it as a DPanel holding both; this fork's DCheckBox is already box + caption
	(see its header), so this control is that, plus the label-shaped API the page
	documents:

		SetValue / Toggle / SetIndent / GetIndent / SetDark / SetBright /
		SetFont / SetTextColor / SizeToContents / OnChange

	Inherited through the DCheckBox base, which is what the wiki promises too:
		SetText / GetText, SetChecked / GetChecked / IsChecked, OnChange,
		and the whole Panel:SetConVar family (installed onto DCheckBox by
		derma/init.lua -- see derma.InstallConVarLink).

	Init does NOT chain to DCheckBox:Init by hand: vgui.Create runs Init for
	every link of the chain, root-most first (hl2sb_derma.lua), so the box and
	its DLabel are built before this one runs.

	⚠️ Documented deviation: the wiki says SetChecked does not notify while
	SetValue does.  Here they are equivalent -- lCheckButton.cpp's SetSelected
	override dispatches OnCheckButtonChecked for programmatic changes as well as
	clicks, and that is the hook the convar write hangs off.  SetValue therefore
	also writes the convar, which is exactly what the wiki example relies on
	(SetConVar + SetValue( true ) to push the initial state). --]]

local PANEL = {}

function PANEL:Init()
	self.m_iIndent = 0
	self.m_bDark = false
end

--- GMod: AccessorFunc -- X offset of the caption relative to the tick box.
function PANEL:GetIndent()
	return self.m_iIndent or 0
end

function PANEL:SetIndent( iIndent )
	self.m_iIndent = tonumber( iIndent ) or 0
	self:LayoutLabel()
end

--- GMod: sets the checked state AND notifies (OnChange + the convar write).
function PANEL:SetValue( bChecked )
	self:SetChecked( bChecked and true or false )
end

function PANEL:Toggle()
	self:SetValue( not self:GetChecked() )
end

function PANEL:SetFont( strFont )
	if ( self.m_Label and self.m_Label.SetFont ) then
		self.m_Label:SetFont( strFont )
		self:LayoutLabel()
	end
end

function PANEL:SetTextColor( clr )
	self.m_colText = clr
	if ( self.m_Label and self.m_Label.SetTextColor ) then
		self.m_Label:SetTextColor( clr )
	end
end

--- GMod: "sets the text of the DCheckBoxLabel to be dark colored in accordance
--- with the currently active Derma skin".  This fork's built-in skin does not
--- define DCheckBoxLabel text colours yet, so the two values below are what
--- actually paints; they are the ones this control is verified with.
function PANEL:SetDark( bDark )
	self.m_bDark = bDark and true or false

	local col = self.m_bDark and Color( 60, 60, 60, 255 ) or Color( 255, 255, 255, 255 )
	self:SetTextColor( col )
end

function PANEL:SetBright( bBright )
	self:SetDark( not bBright )
end

--- GMod: "sizes the panel to the size of the internal DLabel and DButton".
--- Tick box is 16 wide plus a 6px gap (the caption's x in DCheckBox), then the
--- text, then the indent.
function PANEL:SizeToContents()
	local strFont = ( self.m_Label and self.m_Label:GetFont() ) or derma.DefaultFont
	local w, h = derma.GetTextSize( strFont, self:GetText() or "" )

	self:SetSize( self:GetIndent() + 22 + w + 2, math.max( h + 4, 16 ) )
	self:LayoutLabel()
end

--- Caption to the right of the tick box, vertically centred, shifted by indent.
function PANEL:LayoutLabel()
	if ( not self.m_Label ) then return end

	self.m_Label:SetPos( self:GetIndent() + 22, math.floor( ( self:GetTall() - 14 ) / 2 ) )
	self.m_Label:SizeToContents()
end

derma.DefineControl( "DCheckBoxLabel", "HL2SB check box with label", PANEL, "DCheckBox" )
