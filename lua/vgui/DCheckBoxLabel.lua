--[[ DCheckBoxLabel -- a check box with its caption next to it.

	Wiki: DCheckBoxLabel -- "a DCheckBox with a DLabel next to it".  This fork's
	DCheckBox IS the engine's vgui::CheckButton, which already paints the tick
	box and (being a vgui::Label) the caption beside it, so this control only
	adds the label-shaped API the wiki page documents:

		SetValue / Toggle / SetIndent / GetIndent / SetDark / SetBright /
		SetFont / SetTextColor / SizeToContents / OnChange

	Inherited through the DCheckBox base: SetText / GetText,
	SetChecked / GetChecked / IsChecked, OnChange, and the whole
	Panel:SetConVar family (installed onto DCheckBox by derma/init.lua through
	derma.InstallConVarLink).

	SizeToContents is NOT hand-rolled: the engine's Label::SizeToContents already
	computes "the size of the content" -- check image + caption + insets -- from
	the live fonts, so there is no magic number to keep in sync.  The engine
	publishes it (and GetContentSize / GetTextInset / SetTextInset) on the
	CheckButton metatable, because Label's own bindings cannot be called with a
	checkbox panel (luaL_checklabel rejects it by metatable name).

	⚠️ Documented deviation: the wiki says SetChecked does not notify while
	SetValue does.  Here they are equivalent -- lCheckButton.cpp's SetSelected
	override dispatches OnCheckButtonChecked for programmatic changes as well as
	clicks, and that is the hook the convar write hangs off.  SetValue therefore
	also writes the convar, which is what the wiki example relies on.
--]]

local PANEL = {}

local CheckButtonMeta = FindMetaTable( "CheckButton" )

local EngineSizeToContents = CheckButtonMeta and CheckButtonMeta.SizeToContents
local EngineGetTextInset = CheckButtonMeta and CheckButtonMeta.GetTextInset
local EngineSetTextInset = CheckButtonMeta and CheckButtonMeta.SetTextInset

function PANEL:Init()
	self.m_iIndent = 0
	self.m_bDark = false

	-- The engine puts the caption at its own inset (CHECK_INSET + the gap after
	-- the check image).  Remember it: the indent is added to THAT, so GetIndent
	-- stays 0 by default and nothing moves unless the caller asks.
	if ( EngineGetTextInset ) then
		local xInset, yInset = EngineGetTextInset( self )
		self.m_iBaseInsetX, self.m_iBaseInsetY = xInset or 0, yInset or 0
	end
end

--- GMod: AccessorFunc -- X offset of the caption.
function PANEL:GetIndent()
	return self.m_iIndent or 0
end

function PANEL:SetIndent( iIndent )
	self.m_iIndent = tonumber( iIndent ) or 0

	if ( EngineSetTextInset ) then
		EngineSetTextInset( self, ( self.m_iBaseInsetX or 0 ) + self.m_iIndent, self.m_iBaseInsetY or 0 )
	end

	self:InvalidateLayout( true )
end

--- GMod: sets the checked state AND notifies (OnChange + the convar write).
function PANEL:SetValue( bChecked )
	self:SetChecked( bChecked and true or false )
end

function PANEL:Toggle()
	self:SetValue( not self:GetChecked() )
end

--- GMod: SetFont( name ) -- a font NAME.  The engine's caption font comes from
--- the scheme (CheckButton::ApplySchemeSettings picks it and paints the check
--- glyph with it too), so overriding it per panel needs a Label:SetFont(HFont)
--- forwarder on the CheckButton metatable that this fork does not publish yet.
--- Recorded so GetFont/skins can see it; say so rather than pretend.
function PANEL:SetFont( strFont )
	self.m_strDermaFont = strFont
	self:InvalidateLayout( true )
end

function PANEL:SetTextColor( clr )
	self.m_colText = clr
	if ( self.SetFgColor ) then self:SetFgColor( clr ) end
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
--- Label::SizeToContents does exactly that natively (check image + caption +
--- the insets above), so this is a passthrough -- and it follows the checkbox
--- font, which a hard-coded "22 + text" could not.
function PANEL:SizeToContents()
	if ( EngineSizeToContents ) then EngineSizeToContents( self ) end
end

derma.DefineControl( "DCheckBoxLabel", "HL2SB check box with label", PANEL, "DCheckBox" )
