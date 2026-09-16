--[[ DNumSlider -- labelled numeric slider with editable value (original). --]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )

	self.m_flMin = 0
	self.m_flMax = 1
	self.m_flValue = 0
	self.m_iDecimals = 2

	self.m_Label = vgui.Create( "DLabel", self, "Label" )
	self.m_Slider = vgui.Create( "DSlider", self, "Slider" )
	self.m_Entry = vgui.Create( "DTextEntry", self, "Entry" )

	self.m_Slider.OnValueChanged = function( _, flVal )
		self:SetValue( flVal, true )
	end

	self.m_Entry.OnEnter = function( pnl )
		local fl = tonumber( pnl:GetValue() )
		if ( fl ) then self:SetValue( fl ) end
	end
end

function PANEL:SetText( strLabel )
	self.m_Label:SetText( strLabel )
end

function PANEL:GetText()
	return self.m_Label:GetText()
end

function PANEL:SetMin( v ) self.m_flMin = v end
function PANEL:SetMax( v ) self.m_flMax = v end
function PANEL:GetMin() return self.m_flMin end
function PANEL:GetMax() return self.m_flMax end

function PANEL:SetDecimals( i ) self.m_iDecimals = i end

function PANEL:SetValue( flVal, bFromSlider )
	flVal = math.Clamp( flVal or 0, self.m_flMin, self.m_flMax )
	self.m_flValue = flVal

	if ( not bFromSlider ) then
		self.m_Slider:SetValue( ( flVal - self.m_flMin ) / math.max( 1e-9, self.m_flMax - self.m_flMin ) )
	end

	self.m_Entry:SetText( string.format( "%." .. ( self.m_iDecimals or 2 ) .. "f", flVal ) )

	if ( self.OnValueChanged ) then
		local ok, err = pcall( self.OnValueChanged, self, flVal )
		if ( not ok ) then Warning( "DNumSlider:OnValueChanged failed: " .. tostring( err ) .. "\n" ) end
	end
end

function PANEL:GetValue()
	return self.m_flValue
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local labelW = math.floor( w * 0.35 )
	local entryW = 56

	self.m_Label:SetPos( 0, math.floor( ( h - 14 ) / 2 ) )
	self.m_Label:SetSize( labelW, 14 )

	self.m_Entry:SetPos( w - entryW, math.floor( ( h - 18 ) / 2 ) )
	self.m_Entry:SetSize( entryW, 18 )

	self.m_Slider:SetPos( labelW + 4, math.floor( h / 2 ) - 6 )
	self.m_Slider:SetSize( math.max( 20, w - labelW - entryW - 12 ), 12 )
end

derma.DefineControl( "DNumSlider", "HL2SB number slider", PANEL, "DPanel" )
