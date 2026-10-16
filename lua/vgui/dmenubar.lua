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

	-- HL2SB (2026-10-16): measure the RESOLVED caption, not the raw token.
	-- The labels arrive as "#menubar.drawing"-style tokens and the button
	-- paints them through derma.DrawText (which resolves them); sizing from
	-- the token's own byte length left every button far wider than its text,
	-- and a localized (CJK) caption was sized from a 16-byte token while
	-- painted as 2 glyphs.  derma.GetTextSize resolves through the same
	-- chokepoint, so the measurement matches what is drawn.
	local x = 4
	for _, entry in ipairs( self.m_tButtons ) do
		local text = entry.btn:GetText() or ""
		local tw = 8

		if ( derma ~= nil and derma.GetTextSize ~= nil ) then
			local measured = derma.GetTextSize( "DermaDefault", text )

			if ( measured ~= nil and measured > 0 ) then
				tw = 8 + measured
			else
				tw = 8 + ( text ):len() * 8
			end
		else
			tw = 8 + ( text ):len() * 8
		end

		entry.btn:SetPos( x, 0 )
		entry.btn:SetSize( tw, h )
		x = x + tw + 4
	end
end

derma.DefineControl( "DMenuBar", "HL2SB menu bar", PANEL, "DPanel" )
