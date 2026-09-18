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

	-- GMod: dnumslider.lua:Init -- `self.Slider:SetLockY( 0.5 )`.  It is not decoration:
	-- a DSlider with both axes free is drawn as a 2-D *box* grip (DSlider:DrawBoxGrip) and
	-- has no groove, which is exactly how this row looked broken in the player model
	-- selector's Bodygroups tab (2026-09-17).  Locking Y makes it the horizontal slider
	-- GMod shows, and stops a drag from writing a Y value nothing reads.
	self.m_Slider:SetLockY( 0.5 )

	-- GMod also gives the value box no chrome and a numeric filter
	-- (dnumslider.lua: `self.TextArea:SetPaintBackground( false )`, `:SetNumeric( true )`).
	-- Without the first one this fork painted the DTextEntry skin behind "1" - a black box
	-- in the middle of a dark row.
	self.m_Entry:SetPaintBackground( false )
	self.m_Entry:SetNumeric( true )


	-- GMod's names for the same three panels (see SetDark/IsEditing below)
	self.Label = self.m_Label
	self.Slider = self.m_Slider
	self.TextArea = self.m_Entry

	self.m_bEnabled = true

	self.m_Slider.OnValueChanged = function( _, flVal )
		self:SetValue( flVal, true )
	end

	self.m_Entry.OnEnter = function( pnl )
		local fl = tonumber( pnl:GetValue() )
		if ( fl ) then self:SetValue( fl ) end
	end
end

--- GMod: DNumSlider:ApplySchemeSettings() -- "Copy the color of the label to the slider
--- notches and the text entry" (dnumslider.lua:135-150).  It is what makes the notch marks
--- and the value text readable on the fork's dark theme (GMod's default is the label
--- colour with alpha 100 for the notches).
function PANEL:ApplySchemeSettings()
	local col = nil

	if ( self.m_Label ) then
		col = self.m_Label.GetTextStyleColor and self.m_Label:GetTextStyleColor()
		if ( not col and self.m_Label.GetTextColor ) then col = self.m_Label:GetTextColor() end
	end

	if ( not col ) then return end

	if ( self.m_Entry and self.m_Entry.SetTextColor ) then self.m_Entry:SetTextColor( col ) end

	if ( self.m_Slider and self.m_Slider.SetNotchColor ) then
		self.m_Slider:SetNotchColor( Color( col.r or 255, col.g or 255, col.b or 255, 100 ) )
	end
end

function PANEL:SetText( strLabel )
	self.m_Label:SetText( strLabel )
end

function PANEL:GetText()
	return self.m_Label:GetText()
end

--[[ GMod's DNumSlider exposes its parts under plain names, and lua/vgui/
	prop_float.lua moves them around:

		ctrl.Scratch:SetParent( ctrl:GetRow().Label )   -- drag-to-change
		ctrl.Label:SetVisible( false )
		ctrl.TextArea:Dock( LEFT )
		ctrl.Slider:DockMargin( 0, 3, 8, 3 )

	This fork stores them as m_Label / m_Slider / m_Entry, so the GMod names are
	aliased to those.  GMod's Scratch is a DNumberScratch, which is not ported yet
	(lua/vgui/DNumberScratch.lua), so `Scratch` stays nil until it is - prop_float
	guards for that. ]]

function PANEL:SetDark( b )
	if ( self.m_Label.SetDark ) then self.m_Label:SetDark( b ) end
end

function PANEL:IsEditing()
	-- GMod: `return self.Scratch:IsEditing() || self.TextArea:IsEditing() ||
	-- self.Slider:IsEditing()` (dnumslider.lua:179).  Without DNumberScratch the
	-- first term is skipped; the other two are what make DProperty_Float notify
	-- while the slider is being dragged (DSlider:IsEditing -> the drag state).
	return ( self.m_Slider.IsEditing and self.m_Slider:IsEditing() )
		or self.m_Entry:HasFocus() == true
end

function PANEL:SetEnabled( b )
	self.m_bEnabled = b ~= false

	if ( self.m_Entry.SetEnabled ) then self.m_Entry:SetEnabled( self.m_bEnabled ) end
	if ( self.m_Slider.SetEnabled ) then self.m_Slider:SetEnabled( self.m_bEnabled ) end
end

function PANEL:IsEnabled()
	return self.m_bEnabled ~= false
end

function PANEL:SetMin( v ) self.m_flMin = v; self:UpdateNotches() end
function PANEL:SetMax( v ) self.m_flMax = v; self:UpdateNotches() end
function PANEL:GetMin() return self.m_flMin end
function PANEL:GetMax() return self.m_flMax end

--- GMod: DNumSlider:UpdateNotches() -- "the slider draws a notch for every value it can
--- take" (dnumslider.lua:289-300, which caps the count at a quarter of the width so a wide
--- range does not turn the groove into a solid bar).
function PANEL:UpdateNotches()
	if ( not self.m_Slider or not self.m_Slider.SetNotches ) then return end

	local range = ( self.m_flMax or 0 ) - ( self.m_flMin or 0 )

	self.m_Slider:SetNotches( nil )

	if ( range < self:GetWide() / 4 ) then
		self.m_Slider:SetNotches( range )
	else
		self.m_Slider:SetNotches( self:GetWide() / 4 )
	end
end

--- GMod: DNumSlider:SetMinMax( min, max ) -- one call for both ends (DForm's
--- NumSlider row uses it; the fork only had the two setters).
function PANEL:SetMinMax( min, max )
	self:SetMin( min )
	self:SetMax( max )
end

function PANEL:SetDecimals( i ) self.m_iDecimals = i; self:UpdateNotches() end

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

	-- the notch cap in UpdateNotches depends on the width, so re-run it here
	self:UpdateNotches()
end

derma.DefineControl( "DNumSlider", "HL2SB number slider", PANEL, "DPanel" )
