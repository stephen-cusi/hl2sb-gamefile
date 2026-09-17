--[[ DBinder -- a button that captures the next pressed key (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DBinder
	  Parent: DButton.  GetSelectedNumber / SetSelectedNumber, GetDefaultNumber /
	  SetDefaultNumber, SetValue / GetValue, ResetToDefaultValue, OnChange
	  (override), and SetConVar - the chosen key code is written to that convar.
	  Its tooltip is "#dbinder.help".

	Ported from GMod's lua/vgui/dbinder.lua (121 lines).  This is what the spawn
	menu's key rows and every "bind a key" dialog are built from.

	Notes for this fork:
	  * input.StartKeyTrapping / IsKeyTrapping / CheckKeyTrapping / GetKeyName did
	    not exist at all (the only definitions lived in the inert
	    modules/gmod_compatibility/sh_init.lua).  They are engine bindings now -
	    public/lua/vgui/LIInput.cpp wraps IVEngineClient::StartKeyTrapMode /
	    CheckDoneKeyTrapping (public/cdll_int.h:278-279) and IInput::GetKeyCodeText
	    (public/vgui/IInput.h:53), with GMod's semantics.
	  * ConVarChanged is redefined with GMod's one-argument contract: this fork's
	    Derma_Install_Convar_Functions links the push-style ( name, old, new )
	    version, so the guard below ignores that call and `self:ConVarChanged( iNum )`
	    writes the number.  Same note as DNumPad.lua.
	  * Think -> OnThink (AGENTS.md 5.0.3): this engine dispatches OnThink.
	  * DoRightClick uses DMenuOption:SetIcon, which was added to
	    lua/vgui/DMenu.lua together with this port.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_iSelectedNumber", "SelectedNumber" )
AccessorFunc( PANEL, "m_iDefaultNumber", "DefaultNumber" )

Derma_Install_Convar_Functions( PANEL )

--- GMod: Panel:ConVarChanged( strNewValue ).  See the header for why this is not
--- the framework's three-argument version.
function PANEL:ConVarChanged( a, b, c )
	-- A three-argument call is this fork's push binding firing (name, old, new);
	-- the poll in OnThink picks the value up instead, so ignore it.
	if ( b ~= nil or c ~= nil ) then return end
	if ( !self.m_strConVar or #self.m_strConVar < 2 ) then return end

	RunConsoleCommand( self.m_strConVar, tostring( a ) )
end

function PANEL:Init()

	self:SetSelectedNumber( 0 )
	self:SetDefaultNumber( 0 )
	self:SetSize( 60, 30 )

	self:SetTooltip( "#dbinder.help" )

end

function PANEL:UpdateText()

	local str = input.GetKeyName( self:GetSelectedNumber() )
	if ( !str ) then str = "#dbinder.none" end

	str = language.GetPhrase( str )

	self:SetText( str )

end

function PANEL:DoClick()

	self:SetText( "#dbinder.press_a_key" )
	input.StartKeyTrapping()
	self.Trapping = true

end

function PANEL:ResetToDefaultValue()

	local def = self:GetDefaultNumber()
	if ( def != 0 ) then self:SetValue( def ) end

end

function PANEL:DoMiddleClick()

	self:ResetToDefaultValue()

end

function PANEL:DoRightClick()

	local m = DermaMenu()
	if ( self:GetDefaultNumber() != 0 ) then m:AddOption( "#tool.reset_to_default", function() self:ResetToDefaultValue() end ):SetIcon( "icon16/arrow_rotate_clockwise.png" ) end
	m:AddOption( "#tool.clear", function() self:SetValue( 0 ) end ):SetIcon( "icon16/stop_cross.png" )
	m:Open()

end

function PANEL:SetSelectedNumber( iNum )

	self.m_iSelectedNumber = iNum
	self:ConVarChanged( iNum )
	self:UpdateText()
	self:OnChange( iNum )

end

function PANEL:SetConVar( strConVar )
	self.m_strConVar = strConVar

	if ( strConVar ) then
		local cvar = GetConVar( strConVar )
		if ( cvar ) then self:SetDefaultNumber( cvar:GetDefault() ) end
	end
end

--- GMod's Think; this engine dispatches OnThink (AGENTS.md 5.0.3).
function PANEL:OnThink()

	if ( input.IsKeyTrapping() and self.Trapping ) then

		local code = input.CheckKeyTrapping()
		if ( code ) then

			if ( code == KEY_ESCAPE ) then

				self:SetValue( self:GetSelectedNumber() )

			else

				self:SetValue( code )

			end

			self.Trapping = false

		end

	end

	self:ConVarNumberThink()

end

function PANEL:Think()
	self:OnThink()
end

function PANEL:SetValue( iNumValue )

	self:SetSelectedNumber( iNumValue )

end

function PANEL:GetValue()

	return self:GetSelectedNumber()

end

function PANEL:OnChange( iNum )
end

derma.DefineControl( "DBinder", "A button that binds a key", PANEL, "DButton" )
