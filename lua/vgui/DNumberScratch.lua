--[[ DNumberScratch -- a scratch-to-adjust number field (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DNumberScratch
	  Parent: DImageButton.  GetMin / SetMin, GetMax / SetMax, GetZoom / SetZoom,
	  GetFloatValue / SetFloatValue, GetDecimals / SetDecimals, SetValue / GetValue,
	  SetFraction / GetFraction, IsEditing, and OnValueChanged (override).

	Ported from GMod's lua/vgui/dnumberscratch.lua (373 lines).  Holding the left
	mouse button opens a scratch window and moving the cursor scrubs the value;
	the right mouse button scrubs without the window.  It is the control GMod's
	spawn menu uses for any loose number.

	Notes for this fork:
	  * Material(): there are no Lua IMaterial panels here, so the two scratch
	    window textures are loaded through surface.CreateNewTextureID +
	    DrawSetTextureFile - the same path lua/vgui/DImage.lua uses - and drawn with
	    DrawSetTexture / DrawTexturedRect in place of SetMaterial / DrawTexturedRect.
	  * Text: surface.GetTextSize is the two-argument engine binding here
	    (lua/game/client/font.lua redefines the one-argument GMod form), so both the
	    notch labels and the big value go through derma.GetTextSize / derma.DrawText
	    with the font named, exactly like DLabel does.
	  * render.SetScissorRect is the engine binding's GMod name; this fork binds it
	    as render.SetScissorRectangle (public/lua/lrender.cpp:475), so that is what
	    the window uses.
	  * GMod draws the scratch window from a "DrawOverlay" hook.  This fork has no
	    such hook (its overlay entry points are the HUD ones), but it does dispatch
	    PaintOver now (AGENTS.md 5.0.4), and DrawScreen already disables clipping -
	    so the window is painted from PaintOver instead.
	  * Think -> OnThink (AGENTS.md 5.0.3).
	  * ConVarNumberThink / UpdateConVar: ConVarChanged is redefined with GMod's
	    one-argument contract (see DNumPad.lua / DBinder.lua).
--]]

DEFINE_BASECLASS( "DImageButton" )

local g_Active = nil

-- one texture id per material NAME, shared (there is no Lua IMaterial here)
local ScratchTex = {}

local function ScratchTexture( path )
	local id = ScratchTex[ path ]

	if ( id == nil ) then
		if ( surface.CreateNewTextureID ) then
			id = surface.CreateNewTextureID()
			surface.DrawSetTextureFile( id, path, 1, true )
		else
			id = false
		end

		ScratchTex[ path ] = id
	end

	return id or nil
end

local PANEL = {}

AccessorFunc( PANEL, "m_numMin",		"Min" )
AccessorFunc( PANEL, "m_numMax",		"Max" )
AccessorFunc( PANEL, "m_Zoom",			"Zoom" )
AccessorFunc( PANEL, "m_fFloatValue",	"FloatValue" )
AccessorFunc( PANEL, "m_bActive",		"Active" )
AccessorFunc( PANEL, "m_iDecimals",		"Decimals" )
AccessorFunc( PANEL, "m_bDrawScreen",	"ShouldDrawScreen" )

Derma_Install_Convar_Functions( PANEL )

--- GMod: Panel:ConVarChanged( strNewValue ).  See the header.
function PANEL:ConVarChanged( a, b, c )
	if ( b ~= nil or c ~= nil ) then return end
	if ( !self.m_strConVar or #self.m_strConVar < 2 ) then return end

	RunConsoleCommand( self.m_strConVar, tostring( a ) )
end

function PANEL:Init()

	self:SetMin( 0 )
	self:SetMax( 10 )
	self:SetZoom( 0 )
	self:SetDecimals( 2 )
	self:SetFloatValue( 1.5 )
	self:SetShouldDrawScreen( false )

	self.MouseX = 0
	self.MouseY = 0
	self.m_strUnderTexture = "gui/numberscratch_under.png"
	self.m_strCoverTexture = "gui/numberscratch_cover.png"

	self:SetImage( "icon16/scratchnumber.png" )
	self:SetStretchToFit( false )
	self:SetSize( 16, 16 )

	self:SetCursor( "sizewe" )

end

function PANEL:SetValue( val )

	val = tonumber( val )
	if ( val == nil ) then return end
	if ( val == self:GetFloatValue() ) then return end

	self:SetFloatValue( val )
	self:OnValueChanged( val )
	self:UpdateConVar()

end

function PANEL:SetFraction( fFraction )

	self:SetFloatValue( self:GetMin() + ( fFraction * self:GetRange() ) )

end

function PANEL:GetFraction()

	return ( self:GetFloatValue() - self:GetMin() ) / self:GetRange()

end

function PANEL:GetDecimals()

	return self.m_iDecimals or 0

end

function PANEL:GetRange()
	return self:GetMax() - self:GetMin()
end

function PANEL:IdealZoom()

	return 400 / self:GetRange()

end

function PANEL:OnMousePressed( mousecode )

	if ( mousecode != MOUSE_LEFT  and mousecode != MOUSE_RIGHT ) then return end

	if ( !self:IsEnabled() ) then return end

	if ( self:GetZoom() == 0 ) then self:SetZoom( self:IdealZoom() ) end

	self:SetActive( true )
	self:MouseCapture( true )

	self:LockCursor()

	-- Temporary fix for Linux
	-- Something keeps snapping the cursor to the center of the screen when it is invisible
	-- and we definitely don't want that, let's keep the cursor visible for now
	if ( !system.IsLinux() ) then
		self:SetCursor( "none" )
	end

	self:SetShouldDrawScreen( mousecode == MOUSE_LEFT )

	g_Active = self

end

function PANEL:OnMouseReleased( mousecode )

	g_Active = nil

	self:SetActive( false )
	self:MouseCapture( false )
	self:SetCursor( "sizewe" )

end

function PANEL:LockCursor()

	local x, y = self:LocalToScreen( math.floor( self:GetWide() * 0.5 ), math.floor( self:GetTall() * 0.5 ) )
	input.SetCursorPos( x, y )

end

function PANEL:OnCursorMoved( x, y )

	if ( !self:GetActive() ) then return end

	x = x - math.floor( self:GetWide() * 0.5 )
	y = y - math.floor( self:GetTall() * 0.5 )

	local zoom = self:GetZoom()

	local ControlScale = 100 / zoom

	local maxzoom = 10 ^ ( 1 + self:GetDecimals() )

	zoom = math.Clamp( zoom + ( ( y * -0.6 ) / ControlScale ), 0.01, maxzoom )
	if ( !input.IsKeyDown( KEY_LSHIFT ) ) then self:SetZoom( zoom ) end

	local oldValue = self:GetFloatValue()
	local value = self:GetFloatValue()
	value = math.Clamp( value + ( x * ControlScale * 0.002 ), self:GetMin(), self:GetMax() )
	self:SetFloatValue( value )

	self:LockCursor()

	if ( oldValue != value ) then self:OnValueChanged( value ) end
	self:UpdateConVar()

end

function PANEL:GetTextValue()

	local iDecimals = self:GetDecimals()
	if ( iDecimals == 0 ) then
		return Format( "%i", self:GetFloatValue() )
	end

	return Format( "%." .. iDecimals .. "f", self:GetFloatValue() )

end

function PANEL:UpdateConVar()

	self:ConVarChanged( self:GetTextValue() )

end

function PANEL:DrawNotches( level, x, y, w, h, range, value, min, max )

	local size = level * self:GetZoom()
	if ( size < 5 ) then return end
	if ( size > w * 2 ) then return end

	local alpha = 255

	if ( size < 150 ) then alpha = alpha * ( ( size - 2 ) / 140 ) end
	if ( size > ( w * 2 ) - 100 ) then alpha = alpha * ( 1 - ( ( size - ( w - 50 ) ) / 50 ) ) end

	local halfw = w * 0.5
	local span = math.ceil( w / size )
	local realmid = x + w * 0.5 - ( value * self:GetZoom() )
	local mid = x + w * 0.5 - math.fmod( value * self:GetZoom(), size )
	local top = h * 0.4
	local nh = h - top

	local frame_min = math.floor( realmid + min * self:GetZoom() )
	local frame_width = math.ceil( range * self:GetZoom() )
	local targetW = math.min( w - math.max( 0, frame_min - x ), frame_width - math.max( 0, x - frame_min ) )

	surface.DrawSetColor( 0, 0, 0, alpha )
	surface.DrawRect( math.max( x, frame_min ), y + top, targetW, 2 )

	for n = -span, span, 1 do

		local nx = mid + n * size

		if ( nx > x + w or nx < x ) then continue end

		local dist = 1 - ( math.abs( halfw - nx + x ) / w )

		local val = ( nx - realmid ) / self:GetZoom()

		if ( val <= min + 0.001 ) then continue end
		if ( val >= max - 0.001 ) then continue end

		surface.DrawSetColor( 0, 0, 0, alpha * dist )

		surface.DrawRect( nx, y + top, 2, nh )

		local str = tostring( val )
		local tw, th = derma.GetTextSize( "DermaDefault", str )

		derma.DrawText( "DermaDefault", math.floor( nx - ( tw * 0.5 ) ), math.floor( y + top - th ),
			str, Color( 0, 0, 0, alpha * dist ) )

	end

	surface.DrawSetColor( 0, 0, 0, alpha )

	--
	-- Draw the last one.
	--
	local nx = realmid + max * self:GetZoom()
	if ( nx < x + w ) then
		surface.DrawRect( nx, y + top, 2, nh )

		local str = tostring( max )
		local tw, th = derma.GetTextSize( "DermaDefault", str )

		derma.DrawText( "DermaDefault", math.floor( nx - ( tw * 0.5 ) ), math.floor( y + top - th ),
			str, Color( 0, 0, 0, alpha ) )
	end

	--
	-- Draw the first
	--
	nx = realmid + min * self:GetZoom()
	if ( nx > x ) then
		surface.DrawRect( nx, y + top, 2, nh )

		local str = tostring( min )
		local tw, th = derma.GetTextSize( "DermaDefault", str )

		derma.DrawText( "DermaDefault", math.floor( nx - ( tw * 0.5 ) ), math.floor( y + top - th ),
			str, Color( 0, 0, 0, alpha ) )
	end

end

--- GMod's Think; this engine dispatches OnThink (AGENTS.md 5.0.3).
function PANEL:OnThink()

	if ( !self:GetActive() ) then
		self:ConVarNumberThink()
	end

end

function PANEL:Think()
	self:OnThink()
end

function PANEL:IsEditing()
	return self:GetActive()
end

--- GMod: the two Material()'d scratch textures.  See the header note.
local function DrawScratchTexture( self, strPath, x, y, w, h )
	local id = ScratchTexture( strPath )

	surface.DrawSetColor( 255, 255, 255, 255 )

	if ( id ) then
		surface.DrawSetTexture( id )
		surface.DrawTexturedRect( math.floor( x ), math.floor( y ), math.floor( w ), math.floor( h ) )
	end
end

function PANEL:DrawScreen( x, y, w, h )

	if ( !self:GetShouldDrawScreen() ) then return end

	local wasEnabled = DisableClipping( true )

	--
	-- Background
	--
	DrawScratchTexture( self, self.m_strUnderTexture, x, y, w, h )

	local min = self:GetMin()
	local max = self:GetMax()
	local range = self:GetMax() - self:GetMin()
	local value = self:GetFloatValue()

	--
	-- Background colour block
	--
	surface.DrawSetColor( 255, 250, 180, 100 )
	local targetX = x + w * 0.5 - ( ( value - min ) * self:GetZoom() )
	local targetW = range * self:GetZoom()
	targetW = targetW - math.max( 0, x - targetX )
	targetW = math.min( targetW, w - math.max( 0, targetX - x ) )
	surface.DrawRect( math.max( targetX, x ) + 3, y + h * 0.4, targetW - 6, h * 0.6 )

	for i = 1, 4 do
		self:DrawNotches( 10 ^ i, x, y, w, h, range, value, min, max )
	end

	for i = 0, self:GetDecimals() do
		self:DrawNotches( 1 / 10 ^ i, x, y, w, h, range, value, min, max )
	end

	--
	-- Cover
	--
	DrawScratchTexture( self, self.m_strCoverTexture, x, y, w, h )

	--
	-- Text Value
	--
	local str = self:GetTextValue()
	str = string.Comma( str )
	local tw, th = derma.GetTextSize( "DermaLarge", str )

	draw.RoundedBoxEx( 8, x + w * 0.5 - tw / 2 - 10, y + h - 43, tw + 20, 39, Color( 0, 186, 255, 255 ), true, true, false, false )

	derma.DrawText( "DermaLarge", math.floor( x + w * 0.5 - tw * 0.5 ), math.floor( y + h - th - 6 ),
		str, Color( 255, 255, 255, 255 ) )

	DisableClipping( wasEnabled )

end

function PANEL:PaintScratchWindow()

	if ( !self:GetActive() ) then return end

	if ( self:GetZoom() == 0 ) then self:SetZoom( self:IdealZoom() ) end

	local w, h = 512, 256
	local x, y = self:LocalToScreen( 0, 0 )

	x = x + self:GetWide() * 0.5 - w * 0.5
	y = y - 8 - h

	if ( x + w + 32 > ScrW() ) then x = ScrW() - w - 32 end
	if ( y + h + 32 > ScrH() ) then y = ScrH() - h - 32 end
	if ( x < 32 ) then x = 32 end
	if ( y < 32 ) then y = 32 end

	if ( render and render.SetScissorRectangle ) then render.SetScissorRectangle( x, y, x + w, y + h, true ) end
		self:DrawScreen( x, y, w, h )
	if ( render and render.SetScissorRectangle ) then render.SetScissorRectangle( 0, 0, 0, 0, false ) end

end

--- GMod draws this from its "DrawOverlay" hook, which this fork does not have; it
--- does dispatch PaintOver (AGENTS.md 5.0.4), and DrawScreen disables clipping, so
--- the window is painted from there instead.
function PANEL:PaintOver( w, h )

	if ( IsValid( g_Active ) and g_Active == self ) then
		self:PaintScratchWindow()
	end

end

--
-- For your pleasure.
--
function PANEL:OnValueChanged( value )
end

PANEL.AllowAutoRefresh = true

function PANEL:GenerateExample()

	-- The concommand derma_controls currently runs in the menu realm
	-- DNumberScratch uses the render library which is currently unavailable in this realm
	-- Therefor we cannot generate an example without spitting errors

end

derma.DefineControl( "DNumberScratch", "A number field you can scratch", PANEL, "DImageButton" )
