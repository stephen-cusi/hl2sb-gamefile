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

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local saved = self.m_strType
	self.m_strStyle = saved
	derma.SkinHook( "Paint", "Notify", self, w, h )
	self.m_strStyle = nil
end

derma.DefineControl( "DNotify", "HL2SB notification", PANEL, "DPanel" )
