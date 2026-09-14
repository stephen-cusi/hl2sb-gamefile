--[[----------------------------------------------------------------------------
	lua/derma/init.lua  --  entry point for HL2SB's own Derma-style framework.

	NOT Garry's Mod's file.  Same call-shape (this is included from
	lua/includes/init.lua before the control list), completely different guts:

		derma/hl2sb_derma.lua    class system: derma.DefineControl / vgui.Create /
		                         vgui.Register on top of the engine's scripted
		                         panels (ref-table method merge, flat chain copy)
		derma/hl2sb_skin.lua     skin registry + vector drawing helpers
		skins/hl2sb_default.lua  the built-in skin

	The engine half of the contract lives in C++:
	scripted_controls' BEGIN_LUA_CALL_PANEL_METHOD dispatch, the panel ref table
	(panel:GetTable), and vgui2's native docking pass -- none of that is
	Garry's Mod code, all of it is this fork's.
-----------------------------------------------------------------------------]]

if ( not ( ( CLIENT or _GAMEUI ) and surface and vgui ) ) then return end

include( "derma/hl2sb_derma.lua" )
include( "derma/hl2sb_skin.lua" )

--[[---------------------------------------------------------------------------
	Fonts

	DermaDefault / DermaDefaultBold / DermaLarge: the three names control code
	and the HUD reference.  Created once at load, resolved to HFont handles
	lazily through derma.GetFontHandle.  Sizes/weights are what this mod's UI
	was verified with -- the font DATA (a name, a size, a weight) is not
	code, but the numbers are ours: 13px Tahoma at these weights suits the
	13px HUD text this fork already ships.
---------------------------------------------------------------------------]]

derma.CreateFont( "DermaDefault", {
	font		= "Tahoma",
	size		= 13,
	weight		= 500,
	extended	= true
} )

derma.CreateFont( "DermaDefaultBold", {
	font		= "Tahoma",
	size		= 13,
	weight		= 800,
	extended	= true
} )

derma.CreateFont( "DermaLarge", {
	font		= "Roboto",
	size		= 32,
	weight		= 500,
	extended	= true
} )

derma.DefaultFont = "DermaDefault"

include( "skins/hl2sb_default.lua" )

-- Derma helper globals (menus, modal dialogs, Derma_Hook, Derma_Anim) built on
-- our controls - the small API surface GMod's lua/derma exposes that our
-- framework was missing.
include( "derma/hl2sb_derma_menus.lua" )

--[[---------------------------------------------------------------------------
	Derma_Install_Convar_Functions ( global )

	HL2SB's own implementation of the panel <-> ConVar binding the GMod wiki
	documents (Panel:SetConVar / Panel:SetConVarFront / Panel:GetConVar, with a
	per-control ConVarChanged override).  GMod ships this in lua/derma/derma.lua,
	which this fork never had, so the whole SetConVar family was missing.

	Relies on the cvars bridge added in cvar.lua: the engine's global change
	callback now reaches cvars.OnConVarChanged, which drives these callbacks.

	identifier is a minted unique string per binding - the wiki requires
	cvars.AddChangeCallback's third argument to be a string, and it lets us
	re-bind a panel cleanly (remove the old callback before adding the new one).
-----------------------------------------------------------------------------]]
local nConVarCallbackID = 0

function Derma_Install_Convar_Functions( Panel )

	function Panel:GetConVar()
		return self.m_ConVar
	end

	function Panel:SetConVar( strName )
		-- unbind the previous convar, if any
		if ( self.m_ConVarName and self.m_ConVarCallbackID ) then
			cvars.RemoveChangeCallback( self.m_ConVarName, self.m_ConVarCallbackID )
		end
		self.m_ConVarCallbackID = nil

		self.m_ConVarName = strName
		self.m_ConVar = ( strName != nil and strName != "" ) and GetConVar( strName ) or nil

		if ( !self.m_ConVar ) then return end

		nConVarCallbackID = nConVarCallbackID + 1
		local strID = "derma_convar_" .. nConVarCallbackID
		self.m_ConVarCallbackID = strID

		local pPanel = self
		cvars.AddChangeCallback( strName, function( name, old, new )
			if ( IsValid( pPanel ) ) then
				pPanel:ConVarChanged( name, old, new )
			end
		end, strID )

		-- reflect the current value immediately (wiki: SetConVarFront updates on the spot)
		self:ConVarChanged( strName, "", self.m_ConVar:GetString() )
	end

	function Panel:SetConVarFront( strName )
		self:SetConVar( strName )
	end

	-- default no-op; controls override to map the string value onto their state
	function Panel:ConVarChanged( strName, strOld, strNew )
	end

end

--[[---------------------------------------------------------------------------
	Wire the ConVar functions onto the controls that GMod links to convars.
	Original control files stay untouched; the binding is applied to each class
	table here.  m_bApplyingConVar guards the convar -> panel -> convar loop.
-----------------------------------------------------------------------------]]
local function InstallConVar( strClass, fnApply, fnWrap )
	-- ⚠️ Deferred on purpose -- see the note above.  This file loads before the
	-- control list, so the class must not be looked up here.
	derma.InstallConVarLink( strClass, function( cls )
		Derma_Install_Convar_Functions( cls )

		cls.ConVarChanged = function( pnl, name, old, new )
			pnl.m_bApplyingConVar = true
			fnApply( pnl, new )
			pnl.m_bApplyingConVar = false
		end

		if ( fnWrap and cls[ fnWrap.name ] ) then
			local orig = cls[ fnWrap.name ]
			cls[ fnWrap.name ] = function( pnl, ... )
				local r = orig( pnl, ... )
				if ( not pnl.m_bApplyingConVar and pnl.m_ConVar ) then
					pnl.m_ConVar:SetString( tostring( fnWrap.write( pnl ) ) )
				end
				return r
			end
		end
	end )
end

InstallConVar( "DCheckBox",
	function( pnl, new ) pnl:SetChecked( tonumber( new ) ~= 0 or new == "true" ) end,
	{ name = "OnCheckButtonChecked", write = function( pnl ) return pnl:GetChecked() and "1" or "0" end } )

InstallConVar( "DNumSlider",
	function( pnl, new ) local v = tonumber( new ); if ( v ) then pnl:SetValue( v ) end end,
	{ name = "SetValue", write = function( pnl ) return pnl:GetValue() end } )

InstallConVar( "DSlider",
	function( pnl, new ) local v = tonumber( new ); if ( v ) then pnl:SetValue( v ) end end,
	{ name = "SetValue", write = function( pnl ) return pnl:GetValue() end } )

InstallConVar( "DTextEntry",
	function( pnl, new ) pnl:SetText( new ) end,
	{ name = "OnTextChanged", write = function( pnl ) return pnl:GetValue() end } )

InstallConVar( "DComboBox",
	function( pnl, new )
		for i = 1, #pnl.m_tOptions do
			if ( pnl.m_tOptions[ i ].label == new ) then pnl:SelectIndex( i ) break end
		end
	end,
	{ name = "ChooseOption", write = function( pnl ) return pnl:GetValue() end } )

print( "[HL2SB] derma framework loaded (hl2sb core)" )
