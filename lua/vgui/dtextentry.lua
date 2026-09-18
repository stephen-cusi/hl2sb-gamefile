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
-- ... and the same for SetFont: the engine control is the one that draws the text, so the
-- Derma font has to reach IT.  GMod splits this in two (`SetFont` = the Lua accessor,
-- `SetFontInternal` = the engine setter); here the accessor below forwards to the binding.
local EngineSetFont = TextEntryMeta and TextEntryMeta.SetFont

--[[ The focus pair, GMod's OnGetFocus / OnLoseFocus.

	GMod's engine TextEntry dispatches both from the panel's focus messages.  This
	fork's LTextEntry used to forward only ApplySchemeSettings / OnMousePressed /
	OnTextChanged / OnEnter, so `self.OnLoseFocus = function() ... end` never ran -
	which is what DLabelEditable and every GMod addon text entry expects to end an
	edit with, and DComboBox/DNumberWang build on it too.

	⚠️ The engine now dispatches the whole surface itself (Paint / PerformLayout /
	OnThink / OnSetFocus+OnGetFocus / OnKillFocus+OnLoseFocus / mouse / cursor / keys;
	game/client/lua/scripted_controls/lTextEntry.h), and it announces that with the
	global HL2SB_TEXTENTRY_DISPATCH, set while the TextEntry Lua library is opened.
	When it is present the poller below is NOT installed: otherwise every focus change
	would fire OnGetFocus / OnLoseFocus a second time, one frame late.

	The poller stays as the fallback for an older client.dll (it is harmless there:
	the callbacks simply would not run at all without it).  --]]
local HL2SB_ENGINE_DISPATCHES_TEXTENTRY = ( HL2SB_TEXTENTRY_DISPATCH == true )

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

	-- GMod: dtextentry.lua:Init -- the engine's own chrome is switched off ("We're going to
	-- draw these ourselves in the skin system - so disable them here.  This will leave it
	-- only drawing text") and the control is given a Derma font:
	--
	--     self:SetPaintBorderEnabled( false )
	--     self:SetPaintBackgroundEnabled( false )
	--     self:SetFont( "DermaDefault" )
	--
	-- ⚠️ The *background* one cannot be copied here.  In this tree the engine's TextEntry
	-- draws the text ITSELF, inside PaintBackground() (vgui2/vgui_controls/TextEntry.cpp:638
	-- - its opaque fill is commented out at :657), and Panel::PaintTraverse only calls
	-- PaintBackground() while PAINT_BACKGROUND_ENABLED is set
	-- (vgui2/vgui_controls/Panel.cpp:1217).  GMod's engine fork had moved the text out of
	-- there; this one has not, so switching it off would leave an empty box.
	-- What we can do is make that fill invisible, because it is `GetBgColor()`
	-- (TextEntry.cpp:646): that is the black rectangle that sat behind the value, and the
	-- scheme's default font is the huge one - both fixed here (2026-09-17).
	self:SetPaintBorderEnabled( false )
	if ( self.SetBGColor ) then self:SetBGColor( 0, 0, 0, 0 ) end	-- GMod form: r, g, b, a
	self:SetFont( self.m_strFont )

	-- the native control paints the text buffer itself; our skin paints the
	-- field chrome around it, so native text rendering stays on

	-- only when the engine does NOT dispatch the focus pair itself (see above)
	if ( not HL2SB_ENGINE_DISPATCHES_TEXTENTRY ) then
		FocusWatchers[ self ] = self:HasFocus() == true
		hook.Add( "Think", FOCUS_HOOK, FocusThink )
	end
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

--- GMod: DTextEntry:SetFont( name ) / GetFont() -- GMod's pair is an AccessorFunc on
--- m_FontName plus `SetFontInternal` in the scheme pass (dtextentry.lua:37/105).  Here the
--- engine binding already takes the NAME (game/client/lua/scripted_controls/lTextEntry.cpp:322
--- -> luaL_checkfont resolves it), so this stores it and hands it over: the engine control
--- is what actually draws the text, and without this it kept the scheme's font - which is
--- how the value box of a DNumSlider ended up with a huge number in it (2026-09-17).
function PANEL:SetFont( strFont )
	self.m_strFont = tostring( strFont or "DermaDefault" )

	if ( EngineSetFont ) then EngineSetFont( self, self.m_strFont ) end
end

function PANEL:GetFont()
	return self.m_strFont
end

--- GMod: DTextEntry:ApplySchemeSettings() -- `self:SetFontInternal( self.m_FontName )` +
--- the skin hook.  LTextEntry runs the ENGINE's pass first and then this hook
--- (game/client/lua/scripted_controls/lTextEntry.h), and that engine pass resets both the
--- font and the background colour from the scheme (vgui2/vgui_controls/TextEntry.cpp:136),
--- so both are re-applied here.
function PANEL:ApplySchemeSettings()
	self:SetFont( self.m_strFont )
	if ( self.SetBGColor ) then self:SetBGColor( 0, 0, 0, 0 ) end

	-- GMod takes the selection/cursor colours from its skin too
	-- (colTextEntryTextHighlight / colTextEntryTextCursor); this engine paints them
	-- from ITS scheme, which is the last "Source" tell left inside a Derma text field.
	-- The derma skin here is dark, so a light cursor and a blue selection.
	if ( self.SetSelectionTextColor ) then self:SetSelectionTextColor( Color( 255, 255, 255, 255 ) ) end
	if ( self.SetSelectionBackgroundColor ) then self:SetSelectionBackgroundColor( Color( 60, 120, 200, 255 ) ) end
	if ( self.SetSelectionUnfocusedBackgroundColor ) then
		self:SetSelectionUnfocusedBackgroundColor( Color( 90, 90, 90, 160 ) )
	end
end

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
