--[[ DCheckBox -- a check box with label (original implementation).

	Uses the engine's scripted CheckButton: the tick box and click toggling are
	native vgui2 (ToggleButton), and the Lua side adds GMod's API surface --
	SetChecked / GetChecked / IsChecked and OnChange -- plus a DLabel caption.
	Checked state lives in the engine control (no Lua mirror to go stale); the
	stage-1 lCheckButton.cpp SetSelected override dispatches OnCheckButtonChecked
	for both user clicks and programmatic SetChecked. --]]

local PANEL = {}

-- Engine CheckButton bindings, captured before the class methods below shadow
-- them on the ref table.
local CheckButtonMeta = FindMetaTable( "CheckButton" )
local EngineSetChecked = CheckButtonMeta and CheckButtonMeta.SetChecked
local EngineGetChecked = CheckButtonMeta and CheckButtonMeta.GetChecked
local EngineSetText = CheckButtonMeta and CheckButtonMeta.SetText

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )

	self.m_Label = vgui.Create( "DLabel", self, "Label" )
	self.m_Label:SetText( "" )
	self:LayoutLabel()
end

function PANEL:LayoutLabel()
	local h = self:GetTall()
	self.m_Label:SetPos( 22, math.floor( ( h - 14 ) / 2 ) )
	self.m_Label:SizeToContents()
end

function PANEL:SetText( strText )
	if ( EngineSetText ) then EngineSetText( self, strText ) end
	self.m_Label:SetText( strText )
	self:LayoutLabel()
end

function PANEL:GetText()
	-- ⚠️ 2026-09-15: the caption is the DLabel mirror, NOT the native CheckButton.
	--
	-- The engine's "CheckButton" metatable (game/client/lua/scripted_controls/
	-- lCheckButton.cpp:337-358) binds SetChecked/GetChecked/SetSelected/... and
	-- has NO SetText at all, so `EngineSetText` above is nil.  The old body was
	--
	--     if ( EngineSetText == nil ) then return "" end
	--     return self.m_Label:GetText()
	--
	-- i.e. it returned the EMPTY STRING on this engine -- which made
	-- DCheckBoxLabel:SizeToContents() measure "" and size the panel to 24px, so
	-- the caption (drawn at x=22 inside a 24px parent) was clipped away and
	-- looked like "the label does not render".  The tick kept painting, which is
	-- why it looked like a text bug.
	--
	-- The mirror is always kept in sync by SetText below, so it is the truth.
	if ( self.m_Label ) then return self.m_Label:GetText() end
	return ""
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
