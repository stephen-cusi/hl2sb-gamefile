--[[ DMenuOptionCVar -- a menu row that reflects and drives a convar (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DMenuOptionCVar
	  "A DMenuOption that can be tied to a console variable to show its state,
	  and to change it when clicked."  Parent: DMenuOption.
	  GetConVar/SetConVar, GetValueOn/SetValueOn (default "1"),
	  GetValueOff/SetValueOff (default "0"), and the OnChecked hook it drives
	  RunConsoleCommand from.

	Ported from GMod's lua/vgui/dmenuoptioncvar.lua (47 lines).  It is what makes a
	GMod menu row able to be a toggle - `DEFINE_BASECLASS` is real in this fork
	(game/shared/lua/luamanager.cpp:796 rewrites it to `local BaseClass =
	baseclass.Get`, exactly GMod's lexer-level expansion), and the checked-state
	methods it needs on its base were added to this fork's DMenuOption
	(lua/vgui/DMenu.lua, the OPT table) at the same time.

	Deliberate deviation: GMod's poll lives in `PANEL:Think()`; this engine only
	dispatches the Lua field OnThink (AGENTS.md 5.0.3), so the body is in OnThink
	and Think forwards to it.
--]]

local PANEL = {}

DEFINE_BASECLASS( "DMenuOption" )

AccessorFunc( PANEL, "m_strConVar", "ConVar" )
AccessorFunc( PANEL, "m_strValueOn", "ValueOn" )
AccessorFunc( PANEL, "m_strValueOff", "ValueOff" )

function PANEL:Init()
	self:SetChecked( false )
	self:SetIsCheckable( true )

	self:SetValueOn( "1" )
	self:SetValueOff( "0" )
	self._NextThink = 0
end

function PANEL:OnThink()
	if ( !self.m_strConVar ) then return end
	if ( self._NextThink > RealTime() ) then return end

	local strValue = GetConVarString( self.m_strConVar )

	self:SetChecked( strValue == self.m_strValueOn )
end

--- GMod's name for the poll above (see the header).
function PANEL:Think()
	self:OnThink()
end

function PANEL:OnChecked( b )
	if ( !self.m_strConVar ) then return end

	-- Give time for the cvar to update
	self._NextThink = RealTime() + 0.1

	if ( b ) then
		RunConsoleCommand( self.m_strConVar, self.m_strValueOn )
	else
		RunConsoleCommand( self.m_strConVar, self.m_strValueOff )
	end
end

derma.DefineControl( "DMenuOptionCVar", "A convar menu option", PANEL, "DMenuOption" )
