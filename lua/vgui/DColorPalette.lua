--[[ DColorPalette -- a grid of coloured buttons (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DColorPalette
	  "The DColorPalette allows the player to select a color from a list of given
	   colors."  Parent: DIconLayout.
	  Event: DColorPalette:OnValueChanged( newcol )   -- override me
	  Methods: SetButtonSize / GetButtonSize / SetNumRows / GetNumRows /
	           SetColorButtons / SetColor / DoClick / OnRightClickButton /
	           SaveColor / Reset / ResetSavedColors /
	           SetConVarR/G/B/A + Get* / UpdateConVar / UpdateConVars /
	           NetworkColorChange / PaintOver

	It is an DIconLayout full of DColorButtons, exactly as the wiki describes, so the
	layout work stays in DIconLayout and this file is only about the colours.

	⚠️ Two deliberate deviations:
	  * The default palette is GENERATED (a grey row plus hues at three
	    saturation/value steps) instead of GMod's hand-written 80-colour table.  The wiki
	    documents the behaviour ("Reset ... to a default preset one") but not the exact
	    colours, and GMod's table is presentation, not API.
	  * `NetworkColorChange` cannot broadcast: this fork's `net` library is server->client
	    only, so palettes with the same name are synced **within the client** (the local
	    registry below) and the cross-client case is left for when a client->server
	    channel exists.  Colour choices still stick through the panel cookie system
	    (Panel:SetCookie/GetCookie) - note this fork's SQLite is a stub, so a cookie
	    survives until the process restarts, not across sessions.
--]]

local PANEL = {}

local COLUMNS = 6			-- the wiki: "provided 6 colors fill each row"

AccessorFunc( PANEL, "m_ConVarR", "ConVarR" )
AccessorFunc( PANEL, "m_ConVarG", "ConVarG" )
AccessorFunc( PANEL, "m_ConVarB", "ConVarB" )
AccessorFunc( PANEL, "m_ConVarA", "ConVarA" )
AccessorFunc( PANEL, "m_buttonsize", "ButtonSize", FORCE_NUMBER )
AccessorFunc( PANEL, "m_NumRows", "NumRows", FORCE_NUMBER )

--- Palettes with the same name share their colours (GMod networks this; see the note
--- in the header - here it is one client's registry).
local SharedPalettes = {}

function PANEL:Init()
	self.m_buttonsize = 16
	self.m_NumRows = 6
	self.m_Color = color_white
	self.m_tColors = {}
	self.m_iSelected = 0

	self:SetSpaceX( 0 )
	self:SetSpaceY( 0 )

	if ( self.SetCookieName ) then
		self:SetCookieName( "hl2sb_colorpalette" )
	end

	self:Reset()
end

-------------------------------------------------------------------------------
-- the colours
-------------------------------------------------------------------------------
--- A grey ramp for the first row, then hues stepping through the HSV wheel with the
--- saturation/value varied once each so the grid is not one flat rainbow.
local function DefaultColors( n )
	local out = {}

	for i = 0, COLUMNS - 1 do
		local v = math.floor( 255 * i / math.max( 1, COLUMNS - 1 ) )
		out[ #out + 1 ] = Color( v, v, v, 255 )
	end

	for i = #out + 1, n do
		local idx = i - 1 - COLUMNS

		local hue = ( idx * 37 ) % 360
		local s, v = 1, 1

		if ( idx % 3 == 1 ) then s = 0.55 end
		if ( idx % 3 == 2 ) then v = 0.55 end

		out[ #out + 1 ] = HSVToColor( hue, s, v )
	end

	return out
end

--- Wiki: "Clears the palette and adds new buttons with given colors."
function PANEL:SetColorButtons( tab )
	-- drop whatever is there (the layout's own children)
	for _, child in ipairs( self:GetChildren() ) do
		if ( IsValid( child ) ) then child:Remove() end
	end

	self.m_tColors = {}

	for id, col in ipairs( tab ) do
		local btn = vgui.Create( "DColorButton" )

		if ( not btn or not btn.SetColor ) then
			Warning( "DColorPalette: DColorButton did not come back with SetColor\n" )
			return
		end

		btn:SetSize( self.m_buttonsize, self.m_buttonsize )
		btn:SetColor( col, true )
		btn:SetID( id )
		btn:SetTooltip( string.format( "Color( %d, %d, %d, %d )",
			col.r, col.g, col.b, col.a ) )

		btn.DoClick = function( pnl )
			self:DoClick( pnl:GetColor(), pnl )
		end

		btn.DoRightClick = function( pnl )
			self:OnRightClickButton( pnl )
		end

		self:Add( btn )

		self.m_tColors[ id ] = col
	end

	self:InvalidateLayout( true )
end

function PANEL:SetButtonSize( n )
	n = math.max( 1, math.floor( tonumber( n ) or 16 ) )
	self.m_buttonsize = n

	for _, child in ipairs( self:GetChildren() ) do
		if ( IsValid( child ) ) then child:SetSize( n, n ) end
	end

	self:InvalidateLayout( true )
end

--- Wiki: "Note: Reset or ResetSavedColors must be called after this function to apply
--- changes."
function PANEL:SetNumRows( n )
	self.m_NumRows = math.max( 1, math.floor( tonumber( n ) or 6 ) )
end

-------------------------------------------------------------------------------
-- picking
-------------------------------------------------------------------------------
--- Wiki: "Basically the same functionality as OnValueChanged, you should use that
--- instead!  For Override"
function PANEL:DoClick( clr, btn )
	self.m_Color = clr
	self.m_iSelected = btn and btn:GetID() or 0

	self:OnValueChanged( clr )
	self:UpdateConVars( clr )
	self:NetworkColorChange()
end

--- Wiki: "Called when the color is changed after clicking a new value. For Override"
function PANEL:OnValueChanged( newcol )
end

--- Wiki: "Called when a palette button has been pressed. For Override"
function PANEL:OnRightClickButton( pnl )
end

--- Wiki: "Currently does nothing. Intended to 'select' the color."  (GMod ships it as
--- a deprecated no-op; kept so old scripts do not error.)
function PANEL:SetColor( newcol )
end

--- The colour the player picked last (not a wiki method, but every caller wants it).
function PANEL:GetColor()
	return self.m_Color or color_white
end

-------------------------------------------------------------------------------
-- cookies
-------------------------------------------------------------------------------
--- Wiki: "Saves the color of given button across sessions.  The color is saved as a
--- panel cookie."
function PANEL:SaveColor( btn, clr )
	if ( not IsValid( btn ) or not clr ) then return end

	local id = btn:GetID() or 0
	self.m_tColors[ id ] = clr

	if ( self.SetCookie ) then
		self:SetCookie( "col" .. id, string.format( "%d %d %d %d",
			clr.r or 255, clr.g or 255, clr.b or 255, clr.a or 255 ) )
	end
end

local function LoadSavedColors( self, n )
	local out = {}

	for id = 1, n do
		local str = self.GetCookie and self:GetCookie( "col" .. id, nil ) or nil
		local r, g, b, a = nil, nil, nil, nil

		if ( type( str ) == "string" ) then
			r, g, b, a = string.match( str, "(%d+)%s+(%d+)%s+(%d+)%s+(%d+)" )
		end

		if ( r ) then
			out[ id ] = Color( tonumber( r ), tonumber( g ), tonumber( b ), tonumber( a ) )
		end
	end

	return out
end

--- Wiki: "Resets this entire color palette to a default preset one, without saving."
function PANEL:Reset()
	local n = math.max( COLUMNS, self.m_NumRows * COLUMNS )

	self:SetColorButtons( DefaultColors( n ) )
	self.m_Color = self.m_tColors[ 1 ] or color_white
end

--- Wiki: "Resets ... to a default preset one and saves the changes."
function PANEL:ResetSavedColors()
	self:Reset()

	for _, btn in ipairs( self:GetChildren() ) do
		if ( IsValid( btn ) and btn.GetID ) then
			self:SaveColor( btn, btn:GetColor() )
		end
	end
end

--- Wiki: "Used internally to make sure changes on one palette affect other palettes
--- with same name."  (See the header: local sync only.)
function PANEL:NetworkColorChange()
	local name = self.GetCookieName and self:GetCookieName() or nil

	if ( not name ) then return end

	SharedPalettes[ name ] = self.m_Color
end

-------------------------------------------------------------------------------
-- convars (R/G/B/A channels)
-------------------------------------------------------------------------------
function PANEL:UpdateConVar( strName, strKey, clr )
	if ( not strName or strName == "" or not clr ) then return end

	local v = clr[ strKey ] or 0

	if ( ConVarExists and ConVarExists( strName ) ) then
		RunConsoleCommand( strName, tostring( v ) )
	elseif ( CreateClientConVar ) then
		local cv = CreateClientConVar( strName, tostring( v ), true, false )
		if ( cv and cv.SetInt ) then cv:SetInt( v ) end
	end
end

function PANEL:UpdateConVars( clr )
	if ( not clr ) then return end

	self:UpdateConVar( self.m_ConVarR, "r", clr )
	self:UpdateConVar( self.m_ConVarG, "g", clr )
	self:UpdateConVar( self.m_ConVarB, "b", clr )
	self:UpdateConVar( self.m_ConVarA, "a", clr )
end

function PANEL:PaintOver( w, h )
	-- a skin that wants to decorate the palette (GMod's does: it draws the "this many
	-- rows" hint) gets the chance; nothing is drawn otherwise
	derma.SkinHook( "PaintOver", "ColorPalette", self, w, h )
end

function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )

	ctrl:SetSize( Width or 160, Height or 100 )
	ctrl.OnValueChanged = function( s, col ) end

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DColorPalette", "A palette of colours", PANEL, "DIconLayout" )

--- Saved colours are applied on top of the default palette (see SaveColor/Reset): the
--- panel cookie name is per-instance, so this reads whatever this panel saved before.
function PANEL:LoadCookies()
	local n = math.max( COLUMNS, ( self.m_NumRows or 6 ) * COLUMNS )
	local saved = LoadSavedColors( self, n )

	for id, col in pairs( saved ) do
		local btn = self:GetChild( id - 1 )

		if ( IsValid( btn ) and btn.SetColor ) then
			btn:SetColor( col, true )
			self.m_tColors[ id ] = col
		end
	end
end
