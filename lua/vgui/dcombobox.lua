--[[ DComboBox -- dropdown selector (original implementation).

	The engine binds no Menu control, so the popup list is a DPanel drawn as a
	popup window (surface popup / MakePopup chain). --]]

local PANEL = {}

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
	self:SetDrawBackground( false )

	self.m_tOptions = {}
	self.m_iSelected = 0
	self.m_strLabel = ""
	self.m_pDown = false

	self.m_Label = vgui.Create( "DLabel", self, "Label" )
	self.m_Label:SetMouseInputEnabled( false )

	self.m_pOptions = vgui.Create( "DPanel", nil, "Menu" )
	self.m_pOptions:SetVisible( false )
	self.m_pOptions.Paint = function( pnl, w, h )
		derma.SkinHook( "Paint", "Menu", pnl, w, h )
	end
end

function PANEL:AddItem( strLabel, bSelect )
	local i = #self.m_tOptions + 1
	self.m_tOptions[ i ] = { label = tostring( strLabel or "" ), value = i }
	if ( bSelect ) then self:SelectIndex( i ) end
	self:BuildOptions()
	return i
end

function PANEL:RemoveItem( i )
	table.remove( self.m_tOptions, i )
	if ( self.m_iSelected > i ) then self.m_iSelected = self.m_iSelected - 1 end
	self:BuildOptions()
end

function PANEL:Clear()
	self.m_tOptions = {}
	self.m_iSelected = 0
	self:BuildOptions()
end

function PANEL:Count()
	return #self.m_tOptions
end

function PANEL:GetOption( i )
	local o = self.m_tOptions[ i ]
	return o and o.label or ""
end

function PANEL:GetValue()
	local opt = self.m_tOptions[ self.m_iSelected ]
	return opt and opt.label or ""
end

function PANEL:SetText( str )
	self.m_strLabel = str
	self.m_Label:SetText( str )
end

function PANEL:GetText()
	return self.m_strLabel
end

function PANEL:SelectIndex( i )
	self.m_iSelected = i
	local opt = self.m_tOptions[ i ]
	if ( opt ) then self:SetText( opt.label ) end
end

function PANEL:ChooseOption( strLabel, iOptionID )
	if ( iOptionID ) then
		self:SelectIndex( iOptionID )
	else
		for i, o in ipairs( self.m_tOptions ) do
			if ( o.label == strLabel ) then self:SelectIndex( i ) break end
		end
	end

	self:SetDropdownVisible( false )

	if ( self.OnSelect ) then
		local ok, err = pcall( self.OnSelect, self, self.m_iSelected, strLabel )
		if ( not ok ) then Warning( "DComboBox:OnSelect failed: " .. tostring( err ) .. "\n" ) end
	end
end

function PANEL:BuildOptions()
	-- the engine Panel has no RemoveAll; tear the old rows down by hand
	for _, old in ipairs( self.m_tOptionPanels or {} ) do
		old:Remove()
	end
	self.m_tOptionPanels = {}

	local y = 2
	for i, o in ipairs( self.m_tOptions ) do
		local opt = vgui.Create( "DButton", self.m_pOptions, "Opt" .. i )
		opt:SetText( o.label )
		opt.DoClick = function() self:ChooseOption( o.label, i ) end
		opt:SetPos( 0, y )
		opt:SetSize( 140, 18 )
		self.m_tOptionPanels[ i ] = opt
		y = y + 18
	end

	self.m_pOptions:SetSize( 140, math.max( 18, y + 2 ) )
end

function PANEL:SetDropdownVisible( b )
	self.m_pDown = b
	self.m_pOptions:SetVisible( b )

	if ( b ) then
		local x, y = self:LocalToScreen( 0, self:GetTall() )
		self.m_pOptions:SetPos( x, y )
		self.m_pOptions:MakePopup()
	end
end

function PANEL:OnMousePressed( code )
	if ( code == MOUSE_LEFT ) then
		self:SetDropdownVisible( not self.m_pDown )
	end
end

--- The popup is a root child (no parent), so it must die with the combo.
function PANEL:OnRemove()
	if ( IsValid( self.m_pOptions ) ) then
		self.m_pOptions:Remove()
	end
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	self.m_Label:SetPos( 6, math.floor( ( h - 14 ) / 2 ) )
	self.m_Label:SetSize( w - 22, 14 )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "ComboBox", self, w, h )
end

derma.DefineControl( "DComboBox", "HL2SB dropdown", PANEL, "DPanel" )
