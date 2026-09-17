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

--[[ The focus pair, GMod's OnGetFocus / OnLoseFocus.

	GMod's engine TextEntry dispatches both from the panel's focus messages; this
	fork's LTextEntry dispatches only ApplySchemeSettings / OnMousePressed /
	OnTextChanged / OnEnter (game/client/lua/scripted_controls/lTextEntry.h), so
	`self.OnLoseFocus = function() ... end` never ran.  That is what
	DLabelEditable (lua/vgui/DLabelEditable.lua) and every GMod addon text entry
	expects to end an edit with, and DComboBox/DNumberWang build on it too.

	The signal is the same one the engine uses: HasFocus().  One frame hook feeds
	the two callbacks, and it only exists while some DTextEntry is alive.  (The
	clean engine fix is an OnThink + OnSetFocus/OnKillFocus dispatch in LTextEntry,
	which needs a header edit - noted in AGENTS.md.)  --]]
local FocusWatchers = setmetatable( {}, { __mode = "k" } )
local FOCUS_HOOK = "HL2SB_DTextEntry_Focus"

local function FocusThink()
	local alive = false

	for pnl, bHadFocus in pairs( FocusWatchers ) do
		if ( not IsValid( pnl ) ) then
			FocusWatchers[ pnl ] = nil
		else
			alive = true

			local bHasFocus = pnl:HasFocus() == true

			if ( bHasFocus != bHadFocus ) then
				FocusWatchers[ pnl ] = bHasFocus

				if ( bHasFocus ) then
					pnl:OnGetFocus()
				else
					pnl:OnLoseFocus()
				end
			end
		end
	end

	if ( not alive and hook and hook.Remove ) then
		hook.Remove( "Think", FOCUS_HOOK )
	end
end

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( true )

	self.m_strPlaceholder = ""
	self.m_strFont = "DermaDefault"

	-- the native control paints the text buffer itself; our skin paints the
	-- field chrome around it, so native text rendering stays on

	FocusWatchers[ self ] = self:HasFocus() == true
	hook.Add( "Think", FOCUS_HOOK, FocusThink )
end

--- GMod: overridable no-ops, so DLabelEditable's explicit `TextEdit:OnGetFocus()`
--- and the frame hook above can always call them.
function PANEL:OnGetFocus()
end

function PANEL:OnLoseFocus()
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
	if ( self.OnChange ) then self:OnChange( self ) end

	if ( self.OnValueChange ) then
		self:OnValueChange( self:GetValue() )
	end
end

--- GMod: DTextEntry:SetNumeric( b ) -- "Sets whether or not the text entry will
--- only allow numbers".  The engine's TextEntry has no such filter, so the text
--- is cleaned here and written back (m_bFiltering stops the write-back from
--- re-entering this function).
function PANEL:SetNumeric( b )
	self.m_bNumeric = b and true or false
end

function PANEL:GetNumeric()
	return self.m_bNumeric == true
end

--- GMod: DTextEntry:SetUpdateOnType( b ) -- whether typing commits a value.
--- GMod's default is false (the value is committed on Enter / focus loss); the
--- wiki and DNumberWang call SetUpdateOnType( true ) to get the live behaviour
--- this fork always had, so an unset flag keeps it.
function PANEL:SetUpdateOnType( b )
	self.m_bUpdateOnType = b and true or false
end

function PANEL:GetUpdateOnType()
	return self.m_bUpdateOnType ~= false
end

--- Stage-1 engine dispatch calls this with no arguments; add the GMod value
--- argument for convenience.
function PANEL:OnTextChanged()
	if ( self.m_bNotifying == false ) then return end

	if ( self.m_bNumeric and not self.m_bFiltering ) then
		local txt = self:GetValue() or ""
		local clean = string.gsub( txt, "[^%d%.%-]", "" )

		if ( clean ~= txt ) then
			self.m_bFiltering = true
			self:SetText( clean )
			self.m_bFiltering = false
		end
	end

	-- "the text changed" in GMod's spelling; DNumberWang assigns self.OnChange
	-- (its wiki page: `self.OnChange = function() ... end`).
	if ( self.OnChange ) then
		self:OnChange( self )
	end

	if ( self.m_bUpdateOnType ~= false and self.OnValueChange ) then
		self:OnValueChange( self:GetValue() )
	end
end

function PANEL:SetNotified( b )
	self.m_bNotifying = b
end

--- GMod: DTextEntry:IsEditing() -- "Returns whether the text entry is currently
--- being edited".  GMod compares against vgui.GetKeyboardFocus(); that binding
--- only exists in the gmod_compatibility shim this fork never loads, so the
--- engine's own HasFocus is used, which is the same question.
function PANEL:IsEditing()
	return self:HasFocus() == true
end

--- GMod: DTextEntry:SetPaintBackground( b ) -- DProperty_Generic and friends call
--- it with false to drop the field's chrome.  This fork paints through the skin's
--- PaintTextEntry hook, so the flag gates that hook.
function PANEL:SetPaintBackground( b )
	self.m_bPaintBackground = b and true or false
end

function PANEL:GetPaintBackground()
	return self.m_bPaintBackground ~= false
end

function PANEL:OnMousePressed( code )
	self:RequestFocus()	-- engine Panel binding, resolved through the metatable chain
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	-- DProperty_Generic:Setup calls SetPaintBackground( false ) so the property
	-- editor's text box has no chrome of its own
	if ( self.m_bPaintBackground ~= false ) then
		derma.SkinHook( "Paint", "TextEntry", self, w, h )
	end

	-- placeholder while empty
	local cur = self:GetValue()
	if ( ( not cur or cur == "" ) and self.m_strPlaceholder ~= "" and not self:HasFocus() ) then
		local _, th = derma.GetTextSize( self.m_strFont, "Xg" )
		derma.DrawText( self.m_strFont, 6, math.floor( ( h - th ) / 2 ),
			self.m_strPlaceholder, Color( 130, 130, 130, 255 ) )
	end
end

derma.DefineControl( "DTextEntry", "HL2SB text field", PANEL, "TextEntry" )
