--[[ DKillIcon -- a kill icon panel (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DKillIcon
	  "A kill icon."  Parent: Panel.  Members: SetName / GetName (AccessorFunc on
	  m_Name) and SizeToContents(), which sizes the panel to the kill icon.
	  The icon itself is drawn by the killicon library
	  (lua/includes/modules/killicon.lua here -- the same one the kill feed uses).

	Ported from GMod's lua/vgui/dkillicon.lua (28 lines).

	Deliberate deviation: GMod calls self:NoClipping( true ) in Init, and relies on
	it because SizeToContents makes the panel 5px tall while the icon is drawn
	taller.  This engine binds no clipping switch, so the guard here just keeps the
	call from throwing; if the icon ever looks cropped, making the panel as tall as
	the icon (killicon.GetSize) is the substitution to use.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_Name", "Name" )

function PANEL:Init()
	self.m_Name = ""
	self.m_fOffset = 0

	if ( self.NoClipping ) then
		self:NoClipping( true )
	end
end

function PANEL:SizeToContents()
	local w, h = killicon.GetSize( self.m_Name )
	self.m_fOffset = h * 0.1
	self:SetSize( w, 5 )
end

function PANEL:Paint()
	killicon.Draw( self:GetWide() * 0.5, self.m_fOffset, self.m_Name, 255 )
end

derma.DefineControl( "DKillIcon", "A kill icon", PANEL, "Panel" )
