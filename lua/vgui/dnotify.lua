--[[ DNotify -- a stackable notification (original implementation).

	notification.lua (the Add / SetTitle / SetText / SetType module) creates
	these into the notify stack.  The type field selects the skin colour; the
	fade-out is a timer, GMod-style. --]]

local PANEL = {}

local NOTIF_W = 300
local NOTIF_H = 60

function PANEL:Init()
	self:SetDrawBackground( false )
	self:SetMouseInputEnabled( true )
	self:SetSize( NOTIF_W, NOTIF_H )
	self.m_strType = "normal"
	self.m_iLifeTime = 5

	self.m_pTitle = vgui.Create( "DLabel", self, "Title" )
	self.m_pTitle:SetFont( "DermaDefaultBold" )
	self.m_pTitle:SetPos( 8, 6 )

	self.m_pText = vgui.Create( "DLabel", self, "Text" )
	self.m_pText:SetPos( 8, 24 )
end

function PANEL:SetType( strType )
	self.m_strType = strType
end

function PANEL:SetTitle( strTitle )
	self.m_pTitle:SetText( strTitle )
end

function PANEL:SetText( strText )
	self.m_pText:SetText( strText )
end

--- GMod: notice:SetExpireTime / the module schedules this itself.
function PANEL:Fade( flDelay )
	self.m_flFadeDelay = flDelay or 0.5

	timer.Create( "dnotify_fade_" .. tostring( self ), self.m_flFadeDelay, 1, function()
		if ( IsValid( self ) ) then self:Remove() end
	end )
end

--[[ GMod's DNotify is a CONTAINER (dnotify.lua): AddItem( panel, life ) adds a
	panel to a re-stacking stack, GetItems/SetSpacing/SetAlignment/SetLife drive
	the stack.  This fork's DNotify grew as a single card, so those container
	names were all nil-call errors.  Both surfaces live here now: AddItem parents
	the given panel in and stacks the children on the next think. --]]

AccessorFunc( PANEL, "m_iSpacing", "Spacing", FORCE_NUMBER )
AccessorFunc( PANEL, "m_iAlignment", "Alignment", FORCE_NUMBER )
AccessorFunc( PANEL, "m_flLife", "Life", FORCE_NUMBER )

function PANEL:AddItem( pnl, flLife )
	if ( not IsValid( pnl ) ) then return end

	pnl:SetParent( self )
	self.m_tItems = self.m_tItems or {}
	table.insert( self.m_tItems, pnl )

	local life = flLife or self.m_flLife or 4
	timer.Create( "dnotify_item_" .. tostring( pnl ), life, 1, function()
		if ( IsValid( pnl ) ) then pnl:Remove() end
	end )

	self:InvalidateLayout( true )
	return pnl
end

function PANEL:GetItems()
	return self.m_tItems or {}
end

function PANEL:PerformLayout_Notify( w, h )
	-- vertical stack, GMod's default alignment (BOTTOM alignment 4 in GMod's
	-- enum; only the stacking matters here)
	local y = 0
	for _, pnl in ipairs( self:GetItems() ) do
		if ( IsValid( pnl ) ) then
			pnl:SetPos( 0, y )
			pnl:SetSize( w, pnl:GetTall() )
			y = y + pnl:GetTall() + ( self.m_iSpacing or 4 )
		end
	end
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local saved = self.m_strType
	self.m_strStyle = saved
	derma.SkinHook( "Paint", "Notify", self, w, h )
	self.m_strStyle = nil
end

derma.DefineControl( "DNotify", "HL2SB notification", PANEL, "DPanel" )
