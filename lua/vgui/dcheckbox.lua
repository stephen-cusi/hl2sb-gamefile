--[[ DCheckBox -- a check box with caption (original implementation).

	The engine's vgui::CheckButton already paints the whole control:

	  * it owns a CheckImage child -- the tick box and the check glyph, drawn as
	    text images through the scheme's checkbox font, and
	  * because vgui::CheckButton derives from vgui::Label, the caption is
	    painted in the same pass with the image/caption spacing the engine lays
	    out itself.

	So the Lua side must NOT draw a caption of its own.  The first version made a
	child DLabel at a hard-coded x = 22 and painted the same string a second
	time, right on top of the engine's tick -- which is why DCheckBoxLabel's
	caption looked smeared into the check mark (tick and "Enable HUD?" printed
	over each other).  That DLabel is gone; there is one caption, the engine's.

	Where the caption bindings come from: they are Label methods -- vgui::CheckButton
	derives from vgui::Label and paints its own caption -- but Label's *bindings*
	cannot be used from a checkbox panel: luaL_checklabel() validates the
	metatable NAME ("Label") with luaL_checkudata, so it rejects a CheckButton
	before lua_tolabel()'s dynamic_cast ever runs:

	    bad argument #1 to 'EngineSetText' (Label expected, got INVALID_PANEL)

	The engine therefore publishes SetText / GetText / SizeToContents /
	GetContentSize / GetTextInset / SetTextInset on the CheckButton metatable
	itself (game/client/lua/scripted_controls/lCheckButton.cpp, plain Label
	forwarders), and this control uses those.
--]]

local PANEL = {}

local CheckButtonMeta = FindMetaTable( "CheckButton" )

local EngineSetChecked = CheckButtonMeta and CheckButtonMeta.SetChecked
local EngineGetChecked = CheckButtonMeta and CheckButtonMeta.GetChecked
local EngineSetText = CheckButtonMeta and CheckButtonMeta.SetText
local EngineGetText = CheckButtonMeta and CheckButtonMeta.GetText

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
end

function PANEL:SetText( strText )
	if ( EngineSetText ) then EngineSetText( self, tostring( strText or "" ) ) end
end

function PANEL:GetText()
	if ( not EngineGetText ) then return "" end
	return EngineGetText( self ) or ""
end

function PANEL:SetChecked( b )
	if ( EngineSetChecked ) then EngineSetChecked( self, b and true or false ) end
end

function PANEL:GetChecked()
	if ( EngineGetChecked ) then return EngineGetChecked( self ) end
	return false
end

function PANEL:IsChecked()
	return self:GetChecked() and true or false
end

--- Stage-1 dispatch (lCheckButton.cpp).  Reads the engine state so the value is
--- always the truth, never a copy that a stray click desynced.
function PANEL:OnCheckButtonChecked()
	if ( self.OnChange ) then
		local ok, err = pcall( self.OnChange, self, self:GetChecked() )
		if ( not ok ) then Warning( "DCheckBox:OnChange failed: " .. tostring( err ) .. "\n" ) end
	end
end

derma.DefineControl( "DCheckBox", "HL2SB check box", PANEL, "CheckButton" )
