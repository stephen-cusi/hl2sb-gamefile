--[[ DNumberWang -- a numeric field with up/down arrows (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DNumberWang
	  "A text entry with up and down arrows."  Parent: DTextEntry.
	  SetValue/GetValue, SetMinMax/GetMin/GetMax, SetDecimals/GetDecimals,
	  SetInterval/GetInterval, SetFloatValue/GetFloatValue, SetFraction/GetFraction,
	  OnValueChanged( val ) (override, "called when the value changes"), HideWang,
	  and SizeToContents.

	Ported from GMod's lua/vgui/dnumberwang.lua (252 lines).  DForm:NumberWang and
	the DProperty_* editors are built on it.

	Notes for this fork:
	  * The up/down buttons ask the skin for "NumberUp"/"NumberDown" first (as
	    GMod does); this fork's skin implements neither, so the arrow triangles
	    below are the fallback (same substitution as DVScrollBar/DHorizontalScroller).
	  * This fork's DTextEntry gained SetNumeric / SetUpdateOnType and calls the
	    GMod-style `OnChange` field, which is what Init below relies on.
	  * `PANEL:Think` -> OnThink (AGENTS.md 5.0.3): the drag-to-change anchor is
	    followed there.
	  * GetValue goes through the engine's TextEntry GetValue (Panel metatable),
	    exactly as GMod's `meta.GetValue( self )` does.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_numMin", "Min" )
AccessorFunc( PANEL, "m_numMax", "Max" )
AccessorFunc( PANEL, "m_iDecimals", "Decimals" ) -- The number of decimal places in the output
AccessorFunc( PANEL, "m_fFloatValue", "FloatValue" )
AccessorFunc( PANEL, "m_iInterval", "Interval" )

Derma_Install_Convar_Functions( PANEL )

--- GMod: Panel:ConVarChanged( strNewValue ).  See DNumPad's header for why this
--- is not the framework's three-argument version.
function PANEL:ConVarChanged( a, b, c )
	if ( b ~= nil or c ~= nil ) then return end
	if ( !self.m_strConVar or #self.m_strConVar < 2 ) then return end

	RunConsoleCommand( self.m_strConVar, tostring( a ) )
end

--- The arrows GMod paints from its skin.
local function PaintArrow( pnl, w, h, bDown )
	w = w or pnl:GetWide()
	h = h or pnl:GetTall()

	if ( derma.SkinHook( "Paint", bDown and "NumberDown" or "NumberUp", pnl, w, h ) ) then return end

	local bright = 210
	if ( pnl.m_bDepressed ) then bright = 255
	elseif ( pnl.m_bHover ) then bright = 235 end

	surface.DrawSetColor( 70, 70, 70, 255 )
	surface.DrawFilledRect( 0, 0, w, h )

	surface.DrawSetColor( bright, bright, bright, 255 )

	local cx = math.floor( w * 0.5 )
	local cy = math.floor( h * 0.5 )

	for i = 0, math.max( 1, math.floor( w * 0.5 ) - 2 ) do
		local len = math.max( 1, math.floor( w * 0.5 ) - 2 - i )

		if ( bDown ) then
			surface.DrawFilledRect( cx - len, cy - math.floor( i * 0.5 ), cx + len, cy - math.floor( i * 0.5 ) + 1 )
		else
			surface.DrawFilledRect( cx - len, cy + math.floor( i * 0.5 ), cx + len, cy + math.floor( i * 0.5 ) + 1 )
		end
	end
end

-- AnchorValue and UnAnchorValue functions are internally used for "drag-changing" the value
local function AnchorValue( wang, button, mcode )
	button:OldOnMousePressed( mcode )
	wang.mouseAnchor = gui.MouseY()
	wang.valAnchor = wang:GetValue()
end

local function UnAnchorValue( wang, button, mcode )
	button:OldOnMouseReleased( mcode )
	wang.mouseAnchor = nil
	wang.valAnchor = nil
end

function PANEL:Init()
	self:SetDecimals( 2 )
	self:SetTall( 20 )
	self:SetMinMax( 0, 100 )

	self:SetInterval( 1 )

	self:SetUpdateOnType( true )
	self:SetNumeric( true )

	self.OnChange = function()
		-- SetValue writes the field itself and reports the change at the end; this
		-- guard keeps that one write from reporting twice (this fork's DTextEntry
		-- dispatches OnChange on every SetText).
		if ( self.m_bSettingValue ) then return end

		self:OnValueChanged( self:GetValue() )
	end

	self.Up = vgui.Create( "DButton", self )
	self.Up:SetText( "" )
	self.Up.DoClick = function( button, mcode ) self:SetValue( self:GetValue() + self:GetInterval() ) end
	self.Up.Paint = function( panel, w, h ) PaintArrow( panel, w, h, false ) end

	self.Up.OldOnMousePressed = self.Up.OnMousePressed
	self.Up.OldOnMouseReleased = self.Up.OnMouseReleased
	self.Up.OnMousePressed = function( button, mcode ) AnchorValue( self, button, mcode ) end
	self.Up.OnMouseReleased = function( button, mcode ) UnAnchorValue( self, button, mcode ) end
	self.Up.OnMouseWheeled = function( button, delta ) self:SetValue( self:GetValue() + delta ) end

	self.Down = vgui.Create( "DButton", self )
	self.Down:SetText( "" )
	self.Down.DoClick = function( button, mcode ) self:SetValue( self:GetValue() - self:GetInterval() ) end
	self.Down.Paint = function( panel, w, h ) PaintArrow( panel, w, h, true ) end

	self.Down.OldOnMousePressed = self.Down.OnMousePressed
	self.Down.OldOnMouseReleased = self.Down.OnMouseReleased
	self.Down.OnMousePressed = function( button, mcode ) AnchorValue( self, button, mcode ) end
	self.Down.OnMouseReleased = function( button, mcode ) UnAnchorValue( self, button, mcode ) end
	self.Down.OnMouseWheeled = function( button, delta ) self:SetValue( self:GetValue() + delta ) end

	self:SetValue( 0 )
end

function PANEL:HideWang()
	self.Up:Hide()
	self.Down:Hide()
end

--- GMod's Think; see the header.
function PANEL:OnThink()
	if ( self.mouseAnchor ) then
		self:SetValue( self.valAnchor + self.mouseAnchor - gui.MouseY() )
	end
end

function PANEL:Think()
	self:OnThink()
end

function PANEL:SetDecimals( num )
	self.m_iDecimals = num
	self:SetValue( self:GetValue() )
end

function PANEL:SetMinMax( min, max )
	self:SetMin( min )
	self:SetMax( max )
end

function PANEL:SetMin( min )
	self.m_numMin = tonumber( min )
end

function PANEL:SetMax( max )
	self.m_numMax = tonumber( max )
end

function PANEL:GetFloatValue( max )
	if ( !self.m_fFloatValue ) then self.m_fFloatValue = 0 end

	return tonumber( self.m_fFloatValue ) or 0
end

function PANEL:SetValue( val )
	if ( val == nil ) then return end

	val = tonumber( val )
	val = val or 0

	if ( self.m_numMax != nil ) then
		val = math.min( self.m_numMax, val )
	end

	if ( self.m_numMin != nil ) then
		val = math.max( self.m_numMin, val )
	end

	local valText
	if ( self.m_iDecimals == 0 ) then
		valText = string.format( "%i", val )
	elseif ( val != 0 ) then
		valText = string.format( "%." .. self.m_iDecimals .. "f", val )

		-- Trim trailing 0's and .'s 0 this gets rid of .00 etc
		valText = string.TrimRight( valText, "0" )
		valText = string.TrimRight( valText, "." )
	else
		valText = tostring( val )
	end

	local hasChanged = tonumber( val ) != tonumber( self:GetValue() )

	--
	-- Don't change the value while we're typing into it!
	-- It causes confusion!
	--
	if ( !self:HasFocus() ) then
		self.m_bSettingValue = true
		self:SetText( valText )
		self.m_bSettingValue = false
		self:ConVarChanged( valText )
	end

	if ( hasChanged ) then
		self:OnValueChanged( val )
	end
end

--- GMod reaches the engine's TextEntry GetValue through FindMetaTable( "Panel" ),
--- because GMod binds it there.  This fork binds it on the TextEntry metatable
--- instead (game/client/lua/scripted_controls/lTextEntry.cpp:141
--- `LUA_BINDING_BEGIN( TextEntry, GetValue, ... )`), and GetText -- which the engine
--- always exposes here -- is the same string for a single-line entry, so read that
--- first and fall back to GetValue if some other realm has it.
function PANEL:GetValue()
	local txt = nil

	if ( self.GetText ) then txt = self:GetText() end
	if ( txt == nil and self.GetValue ) then txt = self:GetValue() end
	if ( txt == nil ) then return 0 end

	return tonumber( txt ) or 0
end

function PANEL:PerformLayout()
	local s = math.floor( self:GetTall() * 0.5 )

	self.Up:SetSize( s, s - 1 )
	self.Up:AlignRight( 3 )
	self.Up:AlignTop( 0 )

	self.Down:SetSize( s, s - 1 )
	self.Down:AlignRight( 3 )
	self.Down:AlignBottom( 2 )
end

function PANEL:SizeToContents()
	-- Size based on the max number and max amount of decimals

	local chars = 0

	local min = math.Round( self:GetMin(), self:GetDecimals() )
	local max = math.Round( self:GetMax(), self:GetDecimals() )

	local minchars = string.len( "" .. min .. "" )
	local maxchars = string.len( "" .. max .. "" )

	chars = chars + math.max( minchars, maxchars )

	if ( self:GetDecimals() && self:GetDecimals() > 0 ) then
		chars = chars + 1
		chars = chars + self:GetDecimals()
	end

	self:InvalidateLayout( true )
	self:SetWide( chars * 6 + 10 + 5 + 5 )
	self:InvalidateLayout()
end

function PANEL:GetFraction( val )
	local Value = val or self:GetValue()

	local Fraction = ( Value - self.m_numMin ) / ( self.m_numMax - self.m_numMin )
	return Fraction
end

function PANEL:SetFraction( val )
	local Fraction = self.m_numMin + ( ( self.m_numMax - self.m_numMin ) * val )
	self:SetValue( Fraction )
end

function PANEL:OnValueChanged( val )
end

function PANEL:GetTextArea()
	return self
end

function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )
	ctrl:SetDecimals( 0 )
	ctrl:SetMinMax( 0, 255 )
	ctrl:SetValue( 3 )

	PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
end

derma.DefineControl( "DNumberWang", "A numeric field with up/down arrows", PANEL, "DTextEntry" )
