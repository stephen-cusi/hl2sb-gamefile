--[[ DTooltip -- hover text bubble (original implementation).

	GMod API surface per the wiki (DTooltip + lua/util/tooltips.lua's ChangeTooltip
	calls): SetText / SetContents( panel, bDelete ) / OpenForPanel( panel ) /
	PositionTooltip / Close / SetDeleteContentsOnClose.  The fork keeps its own
	skin painting (derma.SkinHook "Tooltip") and positions from the target panel
	like GMod's PositionTooltip (cursor-anchored, clamped above the panel and to
	the screen) instead of following the mouse every frame.
--]]

local PANEL = {}

function PANEL:Init()
	-- The tooltip wiring in includes/init.lua skips panels carrying this flag:
	-- ChangeTooltip on a tooltip would RemoveTooltip() itself (see that file).
	self.m_bIsTooltipPanel = true

	self:SetVisible( false )
	self:SetMouseInputEnabled( false )
	self:SetDrawBackground( false )

	-- GMod: SetDrawOnTop so the bubble clears its host popup's clip; this engine
	-- has no such binding, recorded for a later real implementation.
	if ( self.SetDrawOnTop ) then self:SetDrawOnTop( true ) end

	self.DeleteContentsOnClose = false

	self.m_pLabel = vgui.Create( "DLabel", self, "Text" )
	self.m_pLabel:SetMouseInputEnabled( false )

	self.Contents = nil
	self.TargetPanel = nil
end

--- GMod: DTooltip:SetContents( panel, bDelete ) -- show a custom panel inside the
--- tooltip instead of the text label.  GMod parents it, remembers the delete flag
--- and keeps it invisible until PerformLayout shows it.
function PANEL:SetContents( panel, bDelete )
	if ( IsValid( panel ) ) then
		panel:SetParent( self )
	end

	self.Contents = panel
	self.DeleteContentsOnClose = bDelete or false

	if ( IsValid( panel ) and panel.SizeToContents ) then
		panel:SizeToContents()
	end

	self:InvalidateLayout( true )
end

--- GMod: DTooltip:SetDeleteContentsOnClose( b )
function PANEL:SetDeleteContentsOnClose( b )
	self.DeleteContentsOnClose = b and true or false
end

function PANEL:SetText( strText )
	self.m_pLabel:SetText( tostring( strText or "" ) )
	self.m_pLabel:SizeToContents()

	self.Contents = nil
	self:InvalidateLayout( true )
end

--- GMod: DTooltip:PerformLayout -- with contents, size from them; otherwise from
--- the label, caption centred (alignment 5).
function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( IsValid( self.Contents ) ) then
		self:SetSize( self.Contents:GetWide() + 8, self.Contents:GetTall() + 8 )
		self.Contents:SetPos( 4, 4 )
		self.Contents:SetVisible( true )

		if ( IsValid( self.m_pLabel ) ) then self.m_pLabel:SetVisible( false ) end
		return
	end

	if ( IsValid( self.m_pLabel ) ) then
		self.m_pLabel:SetVisible( true )
		self.m_pLabel:SetPos( 5, 4 )
	end
end

--- GMod: DTooltip:PositionTooltip -- cursor anchored, lifted 50px, clamped to just
--- above the target panel and to the screen.
function PANEL:PositionTooltip()
	if ( not IsValid( self.TargetPanel ) ) then
		self:Hide()
		return
	end

	self:PerformLayout()

	local x, y = input.GetCursorPos()
	if ( not x ) then
		local lx, ly = self.TargetPanel:LocalToScreen( 0, 0 )
		x, y = lx, ly
	end

	local w, h = self:GetSize()
	local lx, ly = self.TargetPanel:LocalToScreen( 0, 0 )

	y = y - 50
	y = math.min( y, ly - h - 10 )
	if ( y < 2 ) then y = 2 end

	self:SetPos( math.Clamp( x - w * 0.5, 0, ScrW() - w ), math.Clamp( y, 0, ScrH() - h ) )
end

--- GMod: DTooltip:OpenForPanel( panel ) -- anchor to the panel, honour
--- Panel:SetTooltipDelay (GMod falls back to its tooltip_delay convar; the
--- fork's field store leaves numTooltipDelay nil for instant).
function PANEL:OpenForPanel( panel )
	self.TargetPanel = panel

	local iDelay = 0
	if ( IsValid( panel ) and isnumber( panel.numTooltipDelay ) ) then
		iDelay = panel.numTooltipDelay
	end

	self:PositionTooltip()

	if ( iDelay > 0 ) then
		self:SetVisible( false )
		timer.Simple( iDelay, function()
			if ( not IsValid( self ) ) then return end
			if ( not IsValid( panel ) ) then return end

			self:PositionTooltip()
			self:SetVisible( true )
		end )
	else
		self:SetVisible( true )
	end
end

--- GMod: DTooltip:Close -- release contents when not owned, then remove.
function PANEL:Close()
	if ( not self.DeleteContentsOnClose and IsValid( self.Contents ) ) then
		self.Contents:SetVisible( false )
		self.Contents:SetParent( nil )
	end

	self:Remove()
end

--- Fork legacy: ShowFor( pnl, strText, iDelay ) -- the pre-OpenForPanel API, kept
--- for anything that already used it; routes through the GMod pair now.
function PANEL:ShowFor( pnl, strText, iDelay )
	if ( IsValid( pnl ) and isnumber( iDelay ) ) then
		pnl.numTooltipDelay = iDelay
	end

	self:SetText( strText )
	self:OpenForPanel( pnl )
end

function PANEL:Hide()
	if ( IsValid( self.m_pLabel ) and self.m_pLabel.m_pTimer ) then
		timer.Remove( self.m_pLabel.m_pTimer )
	end

	self:SetVisible( false )
end

function PANEL:Paint( w, h )
	derma.SkinHook( "Paint", "Tooltip", self, w or self:GetWide(), h or self:GetTall() )
end

derma.DefineControl( "DTooltip", "HL2SB tooltip", PANEL, "DPanel" )
