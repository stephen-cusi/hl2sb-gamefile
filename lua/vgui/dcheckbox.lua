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

	Where the caption bindings come from: lCheckButton.cpp binds only
	SetChecked / GetChecked / SetSelected / SetCheckButtonCheckable / ..., so
	FindMetaTable( "CheckButton" ).SetText is nil -- reading it there and bailing
	out was how GetText() ended up returning "" (which made DCheckBoxLabel's
	SizeToContents measure an empty string and clip the caption away).  The
	caption methods live on the *Label* metatable instead, and lua_tolabel() is a
	dynamic_cast< vgui::Label * >: a CheckButton IS-A Label, so Label's bindings
	apply to this panel unchanged.
--]]

local PANEL = {}

local CheckButtonMeta = FindMetaTable( "CheckButton" )
local LabelMeta = FindMetaTable( "Label" )

local EngineSetChecked = CheckButtonMeta and CheckButtonMeta.SetChecked
local EngineGetChecked = CheckButtonMeta and CheckButtonMeta.GetChecked

-- Label's bindings (see the header): usable on a CheckButton panel.
local EngineSetText = LabelMeta and LabelMeta.SetText
local EngineGetText = LabelMeta and LabelMeta.GetText

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
