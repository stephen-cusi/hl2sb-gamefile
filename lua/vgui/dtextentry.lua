--[[ DTextEntry -- single/multi-line text field (original implementation).

	Based on the engine's scripted TextEntry: typed-character handling, the caret
	and selection all live in vgui2's stock control.  What this Lua layer adds
	is the GMod surface: SetValue/GetValue aliases, the OnTextChanged / OnEnter
	hooks (dispatched by scripted_controls/lTextEntry.h), placeholder text, and
	skin painting behind the native text. --]]

local PANEL = {}

-- The engine's SetText lives on the TextEntry metatable; a class override here
-- would hide it, so capture it first.
local TextEntryMeta = FindMetaTable( "TextEntry" )
local EngineSetText = TextEntryMeta and TextEntryMeta.SetText

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( true )

	self.m_strPlaceholder = ""
	self.m_strFont = "DermaDefault"

	-- the native control paints the text buffer itself; our skin paints the
	-- field chrome around it, so native text rendering stays on
end

function PANEL:SetText( strText )
	if ( EngineSetText ) then EngineSetText( self, strText ) end
	self:OnTextChanged()
end

--- GMod's SetText/GetText/SetValue/GetValue/SetReadOnly/SetMultiline are bound
--- engine-side (public/lua/vgui_controls/lTextEntry.cpp + the SetValue /
--- SetReadOnly aliases added with this framework); nothing to shim here.

function PANEL:SetPlaceholderText( strText )
	self.m_strPlaceholder = strText or ""
end

function PANEL:GetPlaceholderText()
	return self.m_strPlaceholder or ""
end

--- GMod idiom: replace the OnEnter field with a callable.
function PANEL:OnEnter( strText )
	if ( self.OnValueChange ) then
		self:OnValueChange( self:GetValue() )
	end
end

--- Stage-1 engine dispatch calls this with no arguments; add the GMod value
--- argument for convenience.
function PANEL:OnTextChanged()
	if ( self.m_bNotifying ~= false and self.OnValueChange ) then
		self:OnValueChange( self:GetValue() )
	end
end

function PANEL:SetNotified( b )
	self.m_bNotifying = b
end

function PANEL:OnMousePressed( code )
	self:RequestFocus()	-- engine Panel binding, resolved through the metatable chain
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "TextEntry", self, w, h )

	-- placeholder while empty
	local cur = self:GetValue()
	if ( ( not cur or cur == "" ) and self.m_strPlaceholder ~= "" and not self:HasFocus() ) then
		local _, th = derma.GetTextSize( self.m_strFont, "Xg" )
		derma.DrawText( self.m_strFont, 6, math.floor( ( h - th ) / 2 ),
			self.m_strPlaceholder, Color( 130, 130, 130, 255 ) )
	end
end

derma.DefineControl( "DTextEntry", "HL2SB text field", PANEL, "TextEntry" )
