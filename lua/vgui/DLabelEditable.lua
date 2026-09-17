--[[ DLabelEditable -- a label that becomes editable on double click (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DLabelEditable
	  Parent: DLabel.  SizeToContents, GetContentSize, IsEditing,
	  SetAutoStretch / GetAutoStretch, OnLabelTextChanged (override).

	Ported from GMod's lua/vgui/dlabeleditable.lua (88 lines).  Double clicking
	replaces the label with a DTextEntry for as long as it has focus; Enter (or
	losing focus) commits the text through OnLabelTextChanged.

	Notes for this fork:
	  * DLabel.GetContentSize( self ) is called the way GMod calls it (a plain
	    function, not a method), and the size it answers comes from this fork's
	    DLabel:GetContentSize.
	  * This fork's surface.GetTextSize is the two-argument engine binding
	    (lua/game/client/font.lua redefines the one-argument GMod form), so the
	    auto-stretch measurement goes through derma.GetTextSize( font, text ) - the
	    same helper DLabel:GetContentSize uses.
	  * The editing entry's OnLoseFocus comes from the frame-driven focus dispatch
	    in lua/vgui/DTextEntry.lua: LTextEntry (scripted_controls/lTextEntry.h)
	    dispatches OnTextChanged / OnEnter but not OnGetFocus / OnLoseFocus.
	  * DTextEntry:SelectAllText( b ) is the engine binding
	    (scripted_controls/lTextEntry.cpp:543) and :OnGetFocus() is the no-op hook
	    DTextEntry defines, so both calls below are GMod's.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_bStretch", "AutoStretch", FORCE_BOOL )

function PANEL:Init()

	self:SetAutoStretch( false )

	-- DLabel:Init turns mouse input off (GMod's dlabel.lua:28 does the same); a
	-- label you double-click has to take the mouse back.
	self:SetMouseInputEnabled( true )

end

function PANEL:SizeToContents()

	local w, h = self:GetContentSize()
	self:SetSize( w + 16, h ) -- Add a bit more room so it looks nice as a textbox :)

end

function PANEL:GetContentSize()

	local w, h = DLabel.GetContentSize( self )

	-- Expand the label to fit our text
	if ( self:IsEditing() && self:GetAutoStretch() ) then
		-- this fork: derma.GetTextSize( font, text ) is the text measuring helper
		w, h = derma.GetTextSize( self:GetFont(), self._TextEdit:GetText() )
	end

	return w, h

end

function PANEL:DoDoubleClick()

	if ( !self:IsEnabled() ) then return end

	local TextEdit = vgui.Create( "DTextEntry", self )
	TextEdit:Dock( FILL )
	TextEdit:SetText( self:GetText() )
	TextEdit:SetFont( self:GetFont() )

	TextEdit.OnTextChanged = function()

		self:SizeToContents()

	end

	TextEdit.OnEnter = function()

		local text = self:OnLabelTextChanged( TextEdit:GetText() ) or TextEdit:GetText()
		if ( text:byte() == 35 ) then text = "#" .. text end -- Hack!

		self:SetText( text )
		hook.Run( "OnTextEntryLoseFocus", TextEdit )
		TextEdit:Remove()

	end

	TextEdit.OnLoseFocus = function()

		hook.Run( "OnTextEntryLoseFocus", TextEdit )
		TextEdit:Remove()

	end

	TextEdit:RequestFocus()
	TextEdit:OnGetFocus() -- Because the keyboard input might not be enabled yet! (spawnmenu)
	TextEdit:SelectAllText( true )

	self._TextEdit = TextEdit

end

function PANEL:IsEditing()

	if ( !IsValid( self._TextEdit ) ) then return false end

	return self._TextEdit:IsEditing()

end

function PANEL:OnLabelTextChanged( text )

	return text

end

derma.DefineControl( "DLabelEditable", "A Label", PANEL, "DLabel" )
