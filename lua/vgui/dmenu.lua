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

	-- ⚠️ Two things a menu canvas needs before its rows can be clicked at all, and both
	-- were missing here (that is why the popup painted but no option ever answered -
	-- "right click does nothing"):
	--   1. mouse input ENABLED - panel.cpp:3347 refuses the subtree of a panel that
	--      answers IsMouseInputEnabled() == false;
	--   2. a real SIZE - the traversePopups = false path (InputWin32.cpp:960 walks the
	--      popup list with `false`) checks `if (IsWithin(x, y))` BEFORE recursing into
	--      children (panel.cpp:3395), so a 0x0 canvas rejects every point and its rows
	--      are never even considered.  ReLayout() sizes it now.
	self.m_pCanvas:SetMouseInputEnabled( true )
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
	-- the canvas has to cover the rows, not just hold them: the engine's hit test
	-- rejects a point that is outside the panel it is about to descend into
	-- (see the note in Init).
	self.m_pCanvas:SetPos( 2, 2 )
	self.m_pCanvas:SetSize( self.m_iWidth, self.m_iHeight )

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

	-- GMod toggles a checkable option as part of the click
	-- (dmenuoption.lua:96 DoClickInternal); the fork's row keeps its own
	-- onClicked field and gains the same toggle here.
	if ( self:GetIsCheckable() ) then
		self:ToggleCheck()
	end

	if ( self.onClicked ) then self:onClicked() end
end

--[[ The checked-state subsystem, ported from GMod's lua/vgui/dmenuoption.lua
	:5-7 and :110-135.  The rest of this row is the fork's own lighter take, but
	DMenuOptionCVar (lua/vgui/DMenuOptionCVar.lua) is built on exactly these
	methods - it sets IsCheckable in Init and drives its convar from OnChecked -
	so they are GMod's, verbatim apart from the guards noted below.  --]]

AccessorFunc( OPT, "m_bCheckable", "IsCheckable" )
AccessorFunc( OPT, "m_bRadio", "Radio" )

function OPT:SetChecked( b )
	if ( self:GetChecked() != b ) then
		self:OnChecked( b )
	end

	self.m_bChecked = b
end

function OPT:GetChecked()
	return self.m_bChecked == true
end

function OPT:OnChecked( b )
end

function OPT:ToggleCheck()
	if ( self:GetRadio() ) then
		if ( self:GetChecked() ) then return end

		-- GMod: self:GetMenu():GetCanvas(); this fork's DMenu has no GetCanvas,
		-- so fall back to the menu it was added to (and skip when neither exists).
		local menu = self.m_pMenu

		if ( IsValid( menu ) and menu.GetCanvas ) then
			local canvas = menu:GetCanvas()

			if ( IsValid( canvas ) ) then
				for k, pnl in pairs( canvas:GetChildren() ) do
					if ( pnl ~= self and pnl.SetChecked ) then pnl:SetChecked( false ) end
				end
			end
		end
	end

	self:SetChecked( !self:GetChecked() )
end

--- GMod: DMenuOption:SetIcon( strIcon ) / GetIcon() (dmenuoption.lua:26/30).
--- DBinder's right-click menu is the first caller here
--- (`m:AddOption( ... ):SetIcon( "icon16/...png" )`), and GMod's row reserves the
--- left 24px for it.  This row draws a DImage child instead of inset text (the
--- fork's rows are DButton + a single derma.DrawText call), so Paint below moves
--- the caption and places the icon.
function OPT:SetIcon( strIcon )
	self.m_strIcon = strIcon

	if ( !IsValid( self.m_pIcon ) ) then
		self.m_pIcon = vgui.Create( "DImage", self )
		self.m_pIcon:SetMouseInputEnabled( false )
	end

	self.m_pIcon:SetImage( strIcon or "" )
end

function OPT:GetIcon()
	return self.m_strIcon
end

function OPT:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( self.m_bHover ) then
		local c = Color( 52, 108, 190, 255 )
		surface.DrawSetColor( c.r, c.g, c.b, c.a )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	-- GMod's icon inset (dmenuoption.lua: "local iIconSize = 16; ... 8 + iIconSize + 4")
	local tx = 8

	if ( self.m_strIcon ) then
		tx = 28

		if ( IsValid( self.m_pIcon ) ) then
			self.m_pIcon:SetPos( 8, math.floor( ( h - 16 ) / 2 ) )
			self.m_pIcon:SetSize( 16, 16 )
		end
	end

	derma.DrawText( "DermaDefault", tx, math.floor( ( h - 13 ) / 2 ),
		self:GetText(), Color( 228, 228, 228, 255 ) )

	-- GMod's skin draws the tick (PaintMenuOption); this fork's skin has no
	-- MenuOption hook, so draw it here.  On the right, because this row's text
	-- starts at x = 8 (GMod's starts at 32 to leave room for an icon).
	if ( self:GetIsCheckable() and self:GetChecked() ) then
		local cx = w - 12
		local cy = math.floor( h * 0.5 )

		surface.DrawSetColor( 255, 200, 0, 255 )
		surface.DrawFilledRect( cx - 5, cy - 3, cx - 3, cy - 1 )
		surface.DrawFilledRect( cx - 4, cy - 1, cx - 2, cy + 1 )
		surface.DrawFilledRect( cx - 2, cy - 2, cx, cy + 2 )
		surface.DrawFilledRect( cx - 1, cy - 5, cx + 1, cy - 1 )
	end
end

derma.DefineControl( "DMenuOption", "HL2SB menu row", OPT, "DButton" )
