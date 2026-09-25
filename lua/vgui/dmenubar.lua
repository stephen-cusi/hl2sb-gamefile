--[[ DMenuBar -- a row of drop-down menus.

	AddMenu / AddOrGetMenu / GetOpenMenu per GMod's dmenubar.lua, plus the
	toggle + hover-switch behaviour (click a label opens its menu, clicking the
	open label closes it, hovering another label switches) and OnRemove cleanup:
	the menus are ROOT panels (they must overlay everything), so a removed bar
	has to remove them or they leak invisibly on screen forever. --]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )
	self.m_tButtons = {}
	self.m_iNextX = 4
	self.m_pOpenMenu = nil
end

--- GMod: DMenuBar:GetOpenMenu() (dmenubar.lua:19-27).
function PANEL:GetOpenMenu()
	return self.m_pOpenMenu
end

--- GMod: DMenuBar:AddOrGetMenu( name ) (dmenubar.lua:29-34).
function PANEL:AddOrGetMenu( name )
	for _, entry in ipairs( self.m_tButtons ) do
		if ( entry.btn:GetText() == name ) then return entry.menu end
	end

	return self:AddMenu( name )
end

function PANEL:AddMenu( strLabel, iWide )
	local menu = vgui.Create( "DMenu", nil, "Menu_" .. strLabel )
	menu:SetVisible( false )

	local btn = vgui.Create( "DButton", self, "Btn_" .. strLabel )
	btn:SetText( strLabel )
	btn.m_pMenu = menu

	btn.DoClick = function()
		-- GMod toggles: clicking the label of the OPEN menu closes it
		-- (dmenubar.lua:51-61)
		if ( self.m_pOpenMenu == menu ) then
			self:CloseMenus()
			return
		end

		self:OpenMenu( btn, menu )
	end

	btn.OnCursorEntered = function()
		-- GMod switches to the hovered label while a menu is open
		-- (dmenubar.lua:63-68)
		if ( self.m_pOpenMenu ~= nil and self.m_pOpenMenu ~= menu ) then
			self:OpenMenu( btn, menu )
		end
	end

	self.m_tButtons[ #self.m_tButtons + 1 ] = { btn = btn, menu = menu }
	self:InvalidateLayout( true )
	return menu
end

function PANEL:OpenMenu( btn, menu )
	self:CloseMenus()

	local x, y = btn:LocalToScreen( 0, btn:GetTall() )
	menu:Open( x, y )
	self.m_pOpenMenu = menu
end

function PANEL:CloseMenus()
	for _, entry in ipairs( self.m_tButtons ) do
		if ( IsValid( entry.menu ) ) then entry.menu:SetVisible( false ) end
	end
	self.m_pOpenMenu = nil
end

--- The menus are unparented root popups: without this they outlive the bar.
function PANEL:OnRemove()
	for _, entry in ipairs( self.m_tButtons ) do
		if ( IsValid( entry.menu ) ) then entry.menu:Remove() end
	end
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
