--[[ DMenu -- a popup menu (original implementation).

	No native CMenu is bound to Lua, so the menu is a borderless popup panel of
	DMenuOption rows, same pattern as DComboBox's dropdown.  GMod's AddOption /
	AddPanel / Open / Delete contract is kept. --]]

local PANEL = {}

local OPTION_H = 20

function PANEL:Init()
	self:SetVisible( false )
	self:SetDrawBackground( false )
	self:SetMouseInputEnabled( true )

	self.m_pCanvas = vgui.Create( "DPanel", self, "Content" )
	self.m_pCanvas:SetDrawBackground( false )
	self.m_iHeight = 4
	self.m_iWidth = 140
end

--- GMod: menu:AddOption( text, fn ) -> the DMenuOption.
function PANEL:AddOption( strText, fnFunction )
	local opt = vgui.Create( "DMenuOption", self.m_pCanvas, "Option" )
	opt:SetText( strText )
	opt.m_pMenu = self
	if ( fnFunction ) then
		opt.DoClick = function( pnl )
			-- GMod closes the menu when an option is chosen
			if ( IsValid( pnl.m_pMenu ) ) then
				pnl.m_pMenu:SetVisible( false )
			end
			local ok, err = pcall( fnFunction )
			if ( not ok ) then Warning( "DMenu option failed: " .. tostring( err ) .. "\n" ) end
		end
	end

	self.m_iHeight = self.m_iHeight + OPTION_H
	self:ReLayout()
	return opt
end

--- GMod: menu:AddPanel( pnl ) -- embed any control as a menu row.
function PANEL:AddPanel( pnl )
	pnl:SetParent( self.m_pCanvas )
	self.m_iHeight = self.m_iHeight + ( pnl:GetTall() > 0 and pnl:GetTall() or OPTION_H )
	self:ReLayout()
	return pnl
end

function PANEL:AddSpacer()
	local sp = vgui.Create( "DPanel", self.m_pCanvas, "Spacer" )
	sp:SetTall( 6 )
	self.m_iHeight = self.m_iHeight + 6
	self:ReLayout()
	return sp
end

function PANEL:SetMenuWidth( iW )
	self.m_iWidth = iW
	self:ReLayout()
end

function PANEL:ReLayout()
	local y = 2
	for i = 0, self.m_pCanvas:GetChildCount() - 1 do
		local child = self.m_pCanvas:GetChild( i )
		if ( IsValid( child ) ) then
			local chH = child:GetTall() > 0 and child:GetTall() or OPTION_H
			child:SetPos( 0, y )
			child:SetSize( self.m_iWidth, chH )
			y = y + chH
		end
	end

	self:SetSize( self.m_iWidth + 4, self.m_iHeight + 6 )
end

--- GMod: menu:Open( x, y ) or menu:Open( ) at the cursor.
function PANEL:Open( x, y )
	if ( not x ) then
		if ( gui and gui.MouseX and gui.MouseY ) then
			x, y = gui.MouseX(), gui.MouseY()
		else
			x, y = 0, 0
		end
	end

	self:SetPos( x, y )
	self:SetVisible( true )
	self:MakePopup()
end

function PANEL:Delete()
	self:Remove()
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()
	derma.SkinHook( "Paint", "Menu", self, w, h )
end

derma.DefineControl( "DMenu", "HL2SB popup menu", PANEL, "DPanel" )


--[[ DMenuOption -- one row inside a DMenu. --]]

local OPT = {}

function OPT:Init()
	self:SetDrawBackground( false )
	self:SetText( "" )
	self.m_bHover = false
end

function OPT:OnCursorEntered() self.m_bHover = true end
function OPT:OnCursorExited() self.m_bHover = false end

function OPT:DoClick()
	local menu = self.m_pMenu
	if ( IsValid( menu ) ) then
		menu:SetVisible( false )
	end

	if ( self.onClicked ) then self:onClicked() end
end

function OPT:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( self.m_bHover ) then
		local c = Color( 52, 108, 190, 255 )
		surface.DrawSetColor( c.r, c.g, c.b, c.a )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	derma.DrawText( "DermaDefault", 8, math.floor( ( h - 13 ) / 2 ),
		self:GetText(), Color( 228, 228, 228, 255 ) )
end

derma.DefineControl( "DMenuOption", "HL2SB menu row", OPT, "DButton" )
