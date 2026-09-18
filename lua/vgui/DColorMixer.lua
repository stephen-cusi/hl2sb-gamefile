--[[ DColorMixer -- the standard Derma colour mixer (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DColorMixer
	  "A standard Derma color mixer".  Parent: DPanel.
	  Event:  DColorMixer:ValueChanged( col )          -- override me
	  Colour: SetColor / GetColor / SetVector / GetVector / SetBaseColor
	          UpdateColor / UpdateDefaultColor / ValueChanged
	  Layout: SetPalette / GetPalette / SetPaletteName / SetAlphaBar / GetAlphaBar /
	          SetWangs / GetWangs / SetLabel / PerformLayout / Paint
	  Convars: SetConVarR/G/B/A + Get* / UpdateConVar / UpdateConVars /
	          ConVarThink / DoConVarThink / Think

	The mixer is assembled from the controls the wiki says it is made of, all of which
	now exist here: DRGBPicker (hue) + DColorCube (saturation/value) + DAlphaBar +
	DColorPalette, with a preview swatch and - "wangs", in GMod's own wording - the
	per-channel readout.

	⚠️ Deliberate deviations, all of them about internals rather than the API:
	  * The "wangs" are four read-only channel labels (GMod draws draggable channel
	    gradients).  `SetWangs` / `GetWangs` show and hide the same panel.
	  * `SetPaletteName` renames the palette's cookie (GMod also networks it; this fork
	    has no client->server net channel - see DColorPalette).
	  * `UpdateDefaultColor` keeps the current colour as the baseline the convar poll
	    compares against, which is what makes SetColor survive an external convar write.
--]]

local PANEL = {}

local PAD = 4
local PICKER_W = 28
local BAR_W = 20
local PALETTE_H = 44

AccessorFunc( PANEL, "m_ConVarR", "ConVarR" )
AccessorFunc( PANEL, "m_ConVarG", "ConVarG" )
AccessorFunc( PANEL, "m_ConVarB", "ConVarB" )
AccessorFunc( PANEL, "m_ConVarA", "ConVarA" )
AccessorFunc( PANEL, "m_bPalette", "Palette", FORCE_BOOL )
AccessorFunc( PANEL, "m_bAlpha", "AlphaBar", FORCE_BOOL )
AccessorFunc( PANEL, "m_bWangsPanel", "Wangs", FORCE_BOOL )

function PANEL:Init()
	self.m_Color = Color( 255, 255, 255, 255 )
	self.m_bPalette = true
	self.m_bAlpha = true
	self.m_bWangsPanel = true
	self.m_strLabel = ""
	self.m_bValueChangedGuard = false

	self:SetMouseInputEnabled( true )

	-- the pieces (GMod's own names are picked through BaseClass where they exist)
	self.picker = vgui.Create( "DRGBPicker", self )
	self.cube = vgui.Create( "DColorCube", self )
	self.alphabar = vgui.Create( "DAlphaBar", self )
	self.palette = vgui.Create( "DColorPalette", self )
	self.Wangs = vgui.Create( "DPanel", self )
	self.Label = vgui.Create( "DLabel", self )
	self.Preview = vgui.Create( "DColorButton", self )

	if ( self.picker ) then
		self.picker.OnChange = function( _, col )
			if ( not IsValid( self.cube ) ) then return end

			local _, s, v = ColorToHSV( self.cube:GetRGB() )
			local h = ColorToHSV( col )

			self.cube:SetBaseRGB( HSVToColor( h, 1, 1 ) )
			self.cube:SetColor( HSVToColor( h, s, v ) )
			self:UpdateColor( self.cube:GetRGB() )
		end
	end

	if ( self.cube ) then
		self.cube.OnUserChanged = function( _, col )
			self:UpdateColor( col )
		end
	end

	if ( self.alphabar ) then
		self.alphabar.OnChange = function( _, fAlpha )
			local c = self.m_Color
			self:UpdateColor( Color( c.r, c.g, c.b, math.floor( 255 * fAlpha ) ) )
		end
	end

	if ( self.palette ) then
		self.palette.OnValueChanged = function( _, col )
			self:SetColor( col )
		end
	end

	if ( self.Wangs ) then
		self.Wangs:SetDrawBackground( false )
		self.Wangs.m_tLabels = {}

		for i, key in ipairs( { "r", "g", "b", "a" } ) do
			local lbl = vgui.Create( "DLabel", self.Wangs )
			lbl:SetText( string.upper( key ) .. ": 255" )
			lbl:SetTextColor( Color( 200, 200, 200, 255 ) )
			self.Wangs.m_tLabels[ key ] = lbl
		end
	end

	if ( self.Label ) then
		self.Label:SetText( "" )
	end

	self:SetColor( self.m_Color )
end

-------------------------------------------------------------------------------
-- colour
-------------------------------------------------------------------------------
--- Wiki: "An AccessorFunc that sets the color of the DColorMixer."
function PANEL:SetColor( col )
	if ( not col ) then return end

	col = Color( col.r or 255, col.g or 255, col.b or 255, col.a or 255 )
	self.m_Color = col

	self.m_bValueChangedGuard = true

	if ( IsValid( self.cube ) ) then self.cube:SetColor( col ) end
	if ( IsValid( self.alphabar ) ) then self.alphabar:SetBarColor( col ) end
	if ( IsValid( self.alphabar ) ) then self.alphabar:SetValue( ( col.a or 255 ) / 255 ) end
	if ( IsValid( self.picker ) ) then
		self:SyncPicker()
	end
	if ( IsValid( self.Preview ) ) then self.Preview:SetColor( col, true ) end
	if ( IsValid( self.Wangs ) and self.Wangs.m_tLabels ) then
		for key, lbl in pairs( self.Wangs.m_tLabels ) do
			if ( IsValid( lbl ) ) then
				lbl:SetText( string.upper( key ) .. ": " .. tostring( col[ key ] or 255 ) )
			end
		end
	end

	self.m_bValueChangedGuard = false

	self:ValueChanged( { r = col.r, g = col.g, b = col.b, a = col.a } )
	self:UpdateConVars( col )
end

function PANEL:GetColor()
	return self.m_Color
end

--- Put the hue picker's indicator on the current colour's hue WITHOUT going through
--- DRGBPicker:OnChange (that would snap saturation/value back to full).
function PANEL:SyncPicker()
	if ( not IsValid( self.picker ) ) then return end

	local h = ColorToHSV( self.m_Color )

	self.picker.LastY = ( ( h % 360 ) / 360 ) * math.max( 1, self.picker:GetTall() )
	self.picker.m_RGB = HSVToColor( h, 1, 1 )
end

--- Wiki: "Returns the color as a normalized Vector."
function PANEL:GetVector()
	local c = self.m_Color

	return Vector( ( c.r or 0 ) / 255, ( c.g or 0 ) / 255, ( c.b or 0 ) / 255 )
end

--- Wiki: "Sets the color of DColorMixer from a Vector. Alpha is not included."
function PANEL:SetVector( vec )
	if ( not vec ) then return end

	self:SetColor( Color( math.floor( vec.x * 255 ), math.floor( vec.y * 255 ),
		math.floor( vec.z * 255 ), self.m_Color.a or 255 ) )
end

--- Wiki: "Sets the base color of the DColorCube part of the DColorMixer."
function PANEL:SetBaseColor( col )
	if ( IsValid( self.cube ) ) then self.cube:SetBaseRGB( col ) end
end

--- Wiki: "Called when the player changes the color of the DColorMixer. Meant to be
--- overridden.  The returned color will not have the color metatable."
function PANEL:ValueChanged( col )
end

--- Wiki: "sets the default color of the element to the currently selected color"
--- (kept as the baseline the convar poll compares against, see the header).
function PANEL:UpdateDefaultColor()
	self.m_DefaultColor = table.Copy( self.m_Color )
end

--- GMod keeps the "default" on the HSV picker: `panel.HSV:SetDefaultColor( color )`
--- (gamemodes/sandbox/gamemode/editor_player.lua:6-11).  This fork has no HSV sub-object,
--- so the baseline lives here - and unlike UpdateDefaultColor() it does NOT read the
--- current colour: setting the default must never change what the panel shows.
function PANEL:SetDefaultColor( col )
	if ( not col ) then return end

	self.m_DefaultColor = Color( col.r or 255, col.g or 255, col.b or 255, col.a or 255 )
end

--- Wiki: "Internal ... Use DColorMixer:SetColor instead!"
function PANEL:UpdateColor( col )
	local c = col or ( IsValid( self.cube ) and self.cube:GetRGB() ) or self.m_Color

	self.m_Color = Color( c.r or 255, c.g or 255, c.b or 255, self.m_Color.a or 255 )

	if ( IsValid( self.alphabar ) ) then self.alphabar:SetBarColor( self.m_Color ) end
	if ( IsValid( self.Preview ) ) then self.Preview:SetColor( self.m_Color, true ) end
	if ( IsValid( self.Wangs ) and self.Wangs.m_tLabels ) then
		for key, lbl in pairs( self.Wangs.m_tLabels ) do
			if ( IsValid( lbl ) ) then
				lbl:SetText( string.upper( key ) .. ": " .. tostring( self.m_Color[ key ] or 255 ) )
			end
		end
	end

	self:ValueChanged( { r = self.m_Color.r, g = self.m_Color.g,
		b = self.m_Color.b, a = self.m_Color.a } )
	self:UpdateConVars( self.m_Color )
end

-------------------------------------------------------------------------------
-- convars
-------------------------------------------------------------------------------
function PANEL:SetConVarR( str ) self.m_ConVarR = str; self:UpdateConVars( self.m_Color ) end
function PANEL:SetConVarG( str ) self.m_ConVarG = str; self:UpdateConVars( self.m_Color ) end
function PANEL:SetConVarB( str ) self.m_ConVarB = str; self:UpdateConVars( self.m_Color ) end
function PANEL:SetConVarA( str ) self.m_ConVarA = str; self:UpdateConVars( self.m_Color ) end

function PANEL:UpdateConVar( cvar, part, col )
	if ( not cvar or cvar == "" or not col ) then return end

	local v = col[ part ] or 0

	if ( ConVarExists and ConVarExists( cvar ) ) then
		RunConsoleCommand( cvar, tostring( v ) )
	end
end

function PANEL:UpdateConVars( col )
	if ( not col ) then return end

	self:UpdateConVar( self.m_ConVarR, "r", col )
	self:UpdateConVar( self.m_ConVarG, "g", col )
	self:UpdateConVar( self.m_ConVarB, "b", col )
	self:UpdateConVar( self.m_ConVarA, "a", col )

	self.m_LastConVars = { r = col.r, g = col.g, b = col.b, a = col.a }
end

--- The convar poll: if a convar changed under us (a console write, another panel),
--- pull the colour back in.  GMod does this from Panel:Think.
function PANEL:DoConVarThink( cvar )
	if ( not cvar or cvar == "" or not GetConVar ) then return false end

	local cv = GetConVar( cvar )
	if ( not cv ) then return false end

	local v = cv.GetInt and cv:GetInt() or nil
	if ( v == nil ) then return false end

	local last = self.m_LastConVars or {}
	local part = nil

	if ( cvar == self.m_ConVarR ) then part = "r"
	elseif ( cvar == self.m_ConVarG ) then part = "g"
	elseif ( cvar == self.m_ConVarB ) then part = "b"
	elseif ( cvar == self.m_ConVarA ) then part = "a" end

	if ( part == nil or last[ part ] == v ) then return false end

	local c = self.m_Color
	local newcol = Color( c.r, c.g, c.b, c.a )
	newcol[ part ] = v

	self.m_bValueChangedGuard = true
	self.m_Color = newcol
	self.m_bValueChangedGuard = false

	if ( IsValid( self.Preview ) ) then self.Preview:SetColor( newcol, true ) end
	if ( IsValid( self.Wangs ) and self.Wangs.m_tLabels and self.Wangs.m_tLabels[ part ] ) then
		self.Wangs.m_tLabels[ part ]:SetText( string.upper( part ) .. ": " .. tostring( v ) )
	end

	(self.m_LastConVars or {})[ part ] = v

	return true
end

function PANEL:ConVarThink()
	if ( not ( ConVarExists and ConVarExists ) ) then return end

	self:DoConVarThink( self.m_ConVarR )
	self:DoConVarThink( self.m_ConVarG )
	self:DoConVarThink( self.m_ConVarB )
	self:DoConVarThink( self.m_ConVarA )
end

--- ⚠️ This fork's scripted panels dispatch OnThink, not Think (see the note in
--- lua/vgui/DScrollPanel.lua), so the poll runs from OnThink; Think is kept as an
--- alias because GMod scripts override it.
function PANEL:OnThink()
	self:ConVarThink()
end

function PANEL:Think()
	self:ConVarThink()
end

-------------------------------------------------------------------------------
-- layout
-------------------------------------------------------------------------------
function PANEL:SetLabel( strText )
	self.m_strLabel = strText or ""

	if ( IsValid( self.Label ) ) then
		self.Label:SetText( self.m_strLabel )
		self:InvalidateLayout( true )
	end
end

function PANEL:SetPalette( bEnabled )
	self.m_bPalette = bEnabled and true or false

	if ( IsValid( self.palette ) ) then self.palette:SetVisible( self.m_bPalette ) end

	self:InvalidateLayout( true )
end

function PANEL:SetPaletteName( strName )
	if ( not IsValid( self.palette ) ) then return end

	if ( self.palette.SetCookieName ) then
		self.palette:SetCookieName( "hl2sb_colorpalette_" .. tostring( strName ) )

		if ( self.palette.LoadCookies ) then self.palette:LoadCookies() end
	end
end

function PANEL:SetAlphaBar( bEnabled )
	self.m_bAlpha = bEnabled and true or false

	if ( IsValid( self.alphabar ) ) then self.alphabar:SetVisible( self.m_bAlpha ) end

	self:InvalidateLayout( true )
end

function PANEL:SetWangs( bEnabled )
	self.m_bWangsPanel = bEnabled and true or false

	if ( IsValid( self.Wangs ) ) then self.Wangs:SetVisible( self.m_bWangsPanel ) end

	self:InvalidateLayout( true )
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local labelH = ( self.m_strLabel ~= "" ) and 16 or 0
	local paletteH = self.m_bPalette and PALETTE_H or 0

	local top = PAD + labelH
	local boxH = math.max( 32, h - top - PAD - paletteH - PAD )

	local barW = self.m_bAlpha and BAR_W or 0
	local wangsW = self.m_bWangsPanel and 54 or 0

	local cubeW = math.max( 32, w - PAD * 2 - PICKER_W - PAD - barW - PAD - wangsW - PAD )

	if ( IsValid( self.Label ) ) then
		self.Label:SetVisible( self.m_strLabel ~= "" )
		self.Label:SetPos( PAD, PAD )
		self.Label:SetSize( w - 2 * PAD, 14 )
	end

	if ( IsValid( self.cube ) ) then
		self.cube:SetPos( PAD, top )
		self.cube:SetSize( cubeW, boxH )
	end

	-- GMod puts the hue strip to the RIGHT of the square (dcolormixer.lua's
	-- PerformLayout: cube first, then the picker, then the Wangs), which is what the
	-- GMod screenshot shows; this fork had it on the left (2026-09-17).
	if ( IsValid( self.picker ) ) then
		self.picker:SetPos( PAD + cubeW + PAD, top )
		self.picker:SetSize( PICKER_W, boxH )
	end

	if ( IsValid( self.alphabar ) ) then
		self.alphabar:SetPos( PAD + cubeW + PAD + PICKER_W + PAD, top )
		self.alphabar:SetSize( barW, boxH )
	end

	if ( IsValid( self.Wangs ) ) then
		self.Wangs:SetPos( PAD + cubeW + PAD + PICKER_W + PAD + barW + PAD, top )
		self.Wangs:SetSize( wangsW, boxH )

		for i, key in ipairs( { "r", "g", "b", "a" } ) do
			local lbl = self.Wangs.m_tLabels and self.Wangs.m_tLabels[ key ]

			if ( IsValid( lbl ) ) then
				lbl:SetPos( 0, ( i - 1 ) * 14 )
				lbl:SetSize( wangsW, 12 )
			end
		end
	end

	if ( IsValid( self.Preview ) ) then
		self.Preview:SetPos( PAD, top + boxH + PAD )
		self.Preview:SetSize( w - 2 * PAD, 12 )
		self.Preview:SetVisible( true )
	end

	if ( IsValid( self.palette ) ) then
		self.palette:SetVisible( self.m_bPalette )
		self.palette:SetPos( PAD, h - PAD - paletteH + 4 )
		self.palette:SetSize( w - 2 * PAD, paletteH - 8 )
	end

	self:SyncPicker()
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	surface.DrawSetColor( 40, 40, 40, 255 )
	surface.DrawFilledRect( 0, 0, w, h )

	surface.DrawSetColor( 0, 0, 0, 255 )
	surface.DrawOutlinedRect( 0, 0, w, h )
end

function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )

	ctrl:SetSize( Width or 267, Height or 186 )
	ctrl:SetPalette( true )
	ctrl:SetAlphaBar( true )
	ctrl:SetWangs( true )
	ctrl:SetColor( Color( 30, 100, 160 ) )

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DColorMixer", "The standard Derma colour mixer", PANEL, "DPanel" )
