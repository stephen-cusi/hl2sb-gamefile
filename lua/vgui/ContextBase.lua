--[[ ContextBase -- base for context-menu (tool option) panels (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/ContextBase
	  "A base for all context menu panels ( The ones used for tool options in
	  sandbox )."  Parent: Panel.
	  ControlValues( contextData ), ConVar(), SetConVar( string ),
	  TestForChanges() -- "You should override this function and use it to check
	  whether your convar value changed."

	Ported from GMod's lua/vgui/contextbase.lua (57 lines).  The label it creates is
	a DLabel with SetDark( true ); that method now exists in this fork
	(lua/vgui/DLabel.lua -- GMod lua/vgui/dlabel.lua:107).

	Deliberate deviation: the per-frame poll lives in OnThink, with Think forwarding
	to it.  This engine only dispatches the Lua field OnThink
	(game/client/lua/scripted_controls/lPanel.cpp:181), so GMod's own
	`function PANEL:Think()` would otherwise never run and TestForChanges would
	never be called.
--]]

local PANEL = {}

function PANEL:Init()
	self.Label = vgui.Create( "DLabel", self )
	self.Label:SetText( "" )
	self.Label:SetDark( true )
end

function PANEL:SetConVar( cvar )
	self.ConVarValue = cvar
end

function PANEL:ConVar()
	return self.ConVarValue
end

function PANEL:ControlValues( kv )
	self:SetConVar( kv.convar or "" )
	self.Label:SetText( kv.label or "" )
end

function PANEL:PerformLayout()
	local y = 5
	self.Label:SetPos( 5, y )
	self.Label:SetWide( self:GetWide() )

	y = y + self.Label:GetTall()
	y = y + 5

	return y
end

function PANEL:TestForChanges()
	-- You should override this function and use it to
	-- check whether your convar value changed
end

function PANEL:OnThink()
	if ( self.NextPoll && self.NextPoll > CurTime() ) then return end

	self.NextPoll = CurTime() + 0.1

	self:TestForChanges()
end

--- GMod's name for the poll above (see the header).
function PANEL:Think()
	self:OnThink()
end

derma.DefineControl( "ContextBase", "Base for context menu panels", PANEL, "Panel" )
