--[[ DSlider -- float slider 0..1 (original implementation). --]]

local PANEL = {}

local GRIP_W = 12

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetDrawBackground( false )
	self.m_flValue = 0
	self.m_bHeld = false
end

function PANEL:SetValue( flVal )
	flVal = math.Clamp( flVal or 0, 0, 1 )
	if ( flVal == self.m_flValue ) then return end
	self.m_flValue = flVal
	if ( self.OnValueChanged ) then
		local ok, err = pcall( self.OnValueChanged, self, flVal )
		if ( not ok ) then Warning( "DSlider:OnValueChanged failed: " .. tostring( err ) .. "\n" ) end
	end
end

function PANEL:GetValue()
	return self.m_flValue
end

function PANEL:SetXPos( x ) self:SetValue( ( x - GRIP_W / 2 ) / math.max( 1, self:GetWide() - GRIP_W ) ) end

function PANEL:OnMousePressed( code )
	if ( code ~= MOUSE_LEFT ) then return end
	self.m_bHeld = true
	self:MouseCapture( true )
	local x, y = derma.CursorPos( self )
	self:SetXPos( x )
end

function PANEL:OnCursorMoved( x, y )
	if ( self.m_bHeld ) then self:SetXPos( x ) end
end

function PANEL:OnMouseReleased( code )
	self.m_bHeld = false
	self:MouseCapture( false )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Slider", self, w, h )
end

derma.DefineControl( "DSlider", "HL2SB float slider", PANEL, "DPanel" )
