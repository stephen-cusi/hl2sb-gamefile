--[[ DPanelSelect -- a list of selectable panels (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DPanelSelect
	  "A DPanelList that allows the user to select one of its children."
	  Parent: DPanelList.
	  AddPanel( pnl, tblConVars ), SelectPanel( pnl ), OnActivePanelChanged( old,
	  new ) -- "for override" -- and FindBestActive(), which selects the entry whose
	  convars match the current ones.

	Ported from GMod's lua/vgui/dpanelselect.lua (94 lines).  DModelSelect and
	DModelSelectMulti derive from it, and DProperties/DEntityProperties use that
	family for their model pickers.

	Notes for this fork:
	  * The active entry is highlighted by assigning `pnl.PaintOver`, exactly as
	    GMod does.  That hook is dispatched here only since
	    game/client/lua/scripted_controls/lPanel.cpp started enabling
	    POST_CHILD_PAINT for Lua panels and dispatching GMod's PaintOver name, so a
	    build with that change (client.dll) is a prerequisite for the highlight.
	    Before it, Panel:PaintOver was never called anywhere in this fork.
	  * GMod's DrawSelected calls
	    `surface.DrawOutlinedRect( i, i, w - i * 2, h - i * 2 )`, which is GMod's
	    ( x, y, w, h ) spelling; this engine's binding takes the two CORNERS
	    ( x0, y0, x1, y1 ) - the same mismatch DProgress documents - so the call
	    below is `( i, i, w - i, h - i )`, which draws the identical rectangle.
--]]

local PANEL = {}

-- This function is used as the paint function for selected buttons.
local function DrawSelected( self )
	surface.SetDrawColor( 255, 200, 0, 255 )

	for i = 2, 3 do
		surface.DrawOutlinedRect( i, i, self:GetWide() - i, self:GetTall() - i )
	end
end

function PANEL:Init()
	self:EnableHorizontal( true )
	self:EnableVerticalScrollbar()
	self:SetSpacing( 2 )
	self:SetPadding( 2 )
end

function PANEL:AddPanel( pnl, tblConVars )
	pnl.tblConVars = tblConVars
	pnl.DoClick = function() self:SelectPanel( pnl ) end

	self:AddItem( pnl )

	self:FindBestActive()
end

function PANEL:OnActivePanelChanged( pnlOld, pnlNew )
	-- For override
end

function PANEL:SelectPanel( pnl )
	self:OnActivePanelChanged( self.SelectedPanel, pnl )

	if ( self.SelectedPanel == pnl ) then return end

	if ( self.SelectedPanel ) then
		self.SelectedPanel.PaintOver = self.OldSelectedPaintOver
		self.SelectedPanel = nil
	end

	-- Run all the convars, if it has any..
	if ( pnl.tblConVars ) then
		for k, v in pairs( pnl.tblConVars ) do RunConsoleCommand( k, v ) end
	end

	self.SelectedPanel = pnl

	if ( self.SelectedPanel ) then
		self.OldSelectedPaintOver = self.SelectedPanel.PaintOver
		self.SelectedPanel.PaintOver = DrawSelected
	end
end

function PANEL:FindBestActive()
	-- Select the item that resembles the chosen panel the closest
	local BestCandidate = nil
	local BestNumMatches = 0

	for id, panel in pairs( self:GetItems() ) do
		local ItemMatches = 0
		if ( panel.tblConVars ) then
			for key, value in pairs( panel.tblConVars ) do
				if ( GetConVarString( key ) == tostring( value ) ) then ItemMatches = ItemMatches + 1 end
			end
		end

		if ( ItemMatches > BestNumMatches ) then
			BestCandidate = panel
			BestNumMatches = ItemMatches
		end
	end

	if ( BestCandidate ) then
		self:SelectPanel( BestCandidate )
	end
end

derma.DefineControl( "DPanelSelect", "A list of selectable panels", PANEL, "DPanelList" )
