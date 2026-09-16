--[[ DMenuBar -- a row of drop-down menus (minimal implementation).

	Only as much as the existing menubar.lua and the spawnmenu need: AddMenu
	returns a DMenu, which populates itself with AddOption. --]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )
	self.m_tButtons = {}
	self.m_iNextX = 4
end

function PANEL:AddMenu( strLabel, iWide )
	local menu = vgui.Create( "DMenu", nil, "Menu_" .. strLabel )
	menu:SetVisible( false )

	local btn = vgui.Create( "DButton", self, "Btn_" .. strLabel )
	btn:SetText( strLabel )
	btn.m_pMenu = menu

	btn.DoClick = function()
		local x, y = btn:LocalToScreen( 0, btn:GetTall() )
		menu:Open( x, y )
	end

	self.m_tButtons[ #self.m_tButtons + 1 ] = { btn = btn, menu = menu }
	self:InvalidateLayout( true )
	return menu
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local x = 4
	for _, entry in ipairs( self.m_tButtons ) do
		local tw = 8 + ( entry.btn:GetText() or "" ):len() * 8
		entry.btn:SetPos( x, 0 )
		entry.btn:SetSize( tw, h )
		x = x + tw + 4
	end
end

derma.DefineControl( "DMenuBar", "HL2SB menu bar", PANEL, "DPanel" )
