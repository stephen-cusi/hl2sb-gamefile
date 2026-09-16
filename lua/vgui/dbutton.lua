--[[ DButton -- a push button (original implementation).

	The engine's C Button (vgui.Button) fires DoClick in C++ and never consults
	a Lua DoClick field, so GMod's `button.DoClick = function() end` idiom does
	not work on it.  This control lives on the scripted Panel instead, whose
	OnMousePressed / OnMouseReleased are dispatched to Lua by
	scripted_controls/lPanel.cpp, and DoClick is raised right there -- exactly
	what GMod code expects. --]]

local PANEL = {}

-- The engine's own enable/disable, kept before the class override below hides
-- the name; the scripted Panel metatable is where it lives.
local PanelMeta = FindMetaTable( "Panel" )
local EngineSetEnabled = PanelMeta and PanelMeta.SetEnabled

function PANEL:Init()
	self:SetText( "" )
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
	self:SetDrawBackground( false )
	self.m_strFont = "DermaDefault"
	self.m_bDepressed = false
	self.m_bHover = false
	self.m_bEnabled = true
end

function PANEL:SetText( strText )
	self.m_strText = tostring( strText or "" )
end

function PANEL:GetText()
	return self.m_strText or ""
end

function PANEL:SetFont( strFont )
	self.m_strFont = strFont
end

function PANEL:GetFont()
	return self.m_strFont
end

function PANEL:SetEnabled( b )
	self.m_bEnabled = b
	if ( EngineSetEnabled ) then EngineSetEnabled( self, b ) end
end

function PANEL:IsEnabled()
	return self.m_bEnabled
end

function PANEL:OnMousePressed( code )
	if ( code == MOUSE_RIGHT ) then
		self:DoRightClick()
		return
	end

	if ( not self.m_bEnabled ) then return end

	self.m_bDepressed = true
	self.m_bHover = true

	-- Without the capture, releasing the button outside the panel never reaches
	-- us and m_bDepressed sticks; with it, OnMouseReleased decides below
	-- whether the cursor is still over the button (GMod's cancel behaviour).
	self:MouseCapture( true )
end

function PANEL:OnCursorEntered()
	if ( self.m_bEnabled ) then self.m_bHover = true end
end

function PANEL:OnCursorExited()
	self.m_bHover = false
end

function PANEL:OnMouseReleased( code )
	local wasDepressed = self.m_bDepressed
	self.m_bDepressed = false
	self:MouseCapture( false )

	if ( not self.m_bEnabled ) then return end
	if ( not wasDepressed ) then return end
	if ( self.m_bHover == false ) then return end

	self:DoClick()
end

function PANEL:OnMouseCaptureLost()
	self.m_bDepressed = false
end

--- GMod's default click does nothing; scripts overwrite this field.
function PANEL:DoClick()
end

--- GMod's right-click hook.
function PANEL:DoRightClick()
end

function PANEL:OnMouseReleasedRight( code )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Button", self, w, h )

	local text = self.m_strText or ""
	if ( text == "" ) then return end

	local tw, th = derma.GetTextSize( self.m_strFont, text )
	local clr = self.m_bEnabled and Color( 228, 228, 228, 255 ) or Color( 120, 120, 120, 255 )
	derma.DrawText( self.m_strFont, math.floor( ( w - tw ) / 2 ), math.floor( ( h - th ) / 2 ), text, clr )
end

derma.DefineControl( "DButton", "HL2SB push button", PANEL, "DPanel" )
