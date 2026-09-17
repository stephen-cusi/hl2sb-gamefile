--[[ DDragBase -- the drag & drop rearrangement container (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DDragBase
	  "A panel that allows you to drag and drop its children to reorder them" -
	  the wiki lists MakeDroppable( name[, allowCopy] ) plus the DropAction_*
	  methods, and DPanel supplies Add/AddPanel.
	  Parent: DPanel.  DTileLayout / DHorizontalScroller (and upstream,
	  DListLayout / DIconLayout) derive from it.

	Ported from GMod's lua/vgui/ddragbase.lua (170 lines).  Every dependency the
	port needs already exists in this fork, which is why it can be near-verbatim:

	  Panel:Receiver / Droppable / OnDrop / DroppedOn / IsDraggable /
	    SetDropTarget / DrawDragHover       -> includes/extensions/client/panel/dragdrop.lua
	  Panel:IsOurChild / GetClosestChild / MoveToBefore / MoveToAfter,
	    table.Reverse / HasValue            -> includes/extensions/client/panel.lua,
	                                           includes/extensions/table.lua
	  dragndrop.Drop hands DropAction_* the array from dragndrop.GetDroppable(),
	    so the "Drops" parameter really is a table of panels.

	Deliberate deviations from GMod:
	  * GMod's DPanel:SetPaintBackground( b ) does not exist in this fork (the
	    paint flag here is DPanel:SetDrawBackground); it is provided as an alias.
	  * MakeDroppable's right-click copy/move menu uses plain English labels: the
	    "#spawnmenu.menu.copy_dnd" language tokens are not in this fork.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_DNDName", "DnD" )
AccessorFunc( PANEL, "m_bLiveDrag", "UseLiveDrag" )
AccessorFunc( PANEL, "m_bReadOnly", "ReadOnly" )

function PANEL:Init()
	-- engine bindings (public/lua/vgui_controls/lPanel.cpp:1842/1844)
	self:SetPaintBackgroundEnabled( false )
	self:SetPaintBorderEnabled( false )
	self:SetMouseInputEnabled( true )
	self:SetPaintBackground( false )
	self:SetReadOnly( false )

	self:SetDropPos( "5" )
end

--- GMod: DPanel:SetPaintBackground( b ).  Alias to this fork's own paint flag,
--- so upstream containers that call it keep working.
function PANEL:SetPaintBackground( b )
	if ( self.SetDrawBackground ) then self:SetDrawBackground( b ) end
end

function PANEL:GetPaintBackground()
	if ( self.GetDrawBackground ) then return self:GetDrawBackground() end
	return false
end

--
-- Determines where we can drop stuff - relative to the other children
-- Param is a string of numpad numbers, ie "852" is top middle bottom
--
function PANEL:SetDropPos( strPos )
	self.bDropLeft = string.find( strPos, "4" )
	self.bDropCenter = string.find( strPos, "5" )
	self.bDropRight = string.find( strPos, "6" )
	self.bDropTop = string.find( strPos, "8" )
	self.bDropBottom = string.find( strPos, "2" )
end

function PANEL:MakeDroppable( name, bAllowCopy )
	self:SetDnD( name )

	if ( bAllowCopy ) then
		self:Receiver( name, self.DropAction_Copy, { copy = "Copy", move = "Move" } )
	else
		self:Receiver( name, self.DropAction_Normal )
	end
end

-- Backwards compatibility
function PANEL:DropAction_Copy( Drops, bDoDrop, Command, x, y )
	self:DropAction_Normal( Drops, bDoDrop, Command, x, y )
end

function PANEL:DropAction_Simple( Drops, bDoDrop, Command, x, y )
	self:SetDropTarget( 0, 0, self:GetWide(), 2 )

	if ( bDoDrop ) then
		for k, v in pairs( Drops ) do
			v = v:OnDrop( self )
			v:SetParent( self )
		end

		self:OnModified()
	end
end

function PANEL:DropAction_Normal( Drops, bDoDrop, Command, x, y )
	local closest = self:GetClosestChild( x, y )
	if ( !IsValid( closest ) ) then
		return self:DropAction_Simple( Drops, bDoDrop, Command, x, y )
	end

	-- This panel is only meant to be copied from, not edited!
	if ( self:GetReadOnly() ) then return end

	local h = closest:GetTall()
	local w = closest:GetWide()

	local disty = y - ( closest.y + h * 0.5 )
	local distx = x - ( closest.x + w * 0.5 )

	local drop = 0
	if ( self.bDropCenter ) then drop = 5 end

	if ( disty < 0 && self.bDropTop && ( drop == 0 || math.abs( disty ) > h * 0.1 ) ) then drop = 8 end
	if ( disty >= 0 && self.bDropBottom && ( drop == 0 || math.abs( disty ) > h * 0.1 ) ) then drop = 2 end
	if ( distx < 0 && self.bDropLeft && ( drop == 0 || math.abs( distx ) > w * 0.1 ) ) then drop = 4 end
	if ( distx >= 0 && self.bDropRight && ( drop == 0 || math.abs( distx ) > w * 0.1 ) ) then drop = 6 end

	self:UpdateDropTarget( drop, closest )

	if ( table.HasValue( Drops, closest ) ) then return end

	if ( !bDoDrop && !self:GetUseLiveDrag() ) then return end

	-- This keeps the drop order the same,
	-- whether we add it before an object or after
	if ( drop == 6 || drop == 2 ) then
		Drops = table.Reverse( Drops )
	end

	for k, v in pairs( Drops ) do
		-- Don't drop one of our parents onto us
		-- because we'll be sucked into a vortex
		if ( v:IsOurChild( self ) ) then continue end

		-- Copy the panel if we are told to from the DermaMenu(), or if we are moving from a read only panel to a not read only one.
		if ( ( Command && Command == "copy" || ( IsValid( v:GetParent() ) && v:GetParent().GetReadOnly && v:GetParent():GetReadOnly() && v:GetParent():GetReadOnly() != self:GetReadOnly() ) ) && v.Copy ) then v = v:Copy() end

		v = v:OnDrop( self )

		if ( drop == 5 ) then
			closest:DroppedOn( v )
		end

		if ( drop == 8 || drop == 4 ) then
			v:SetParent( self )
			v:MoveToBefore( closest )
		end

		if ( drop == 2 || drop == 6 ) then
			v:SetParent( self )
			v:MoveToAfter( closest )
		end
	end

	self:OnModified()
end

function PANEL:OnModified()
	-- For override
end

function PANEL:UpdateDropTarget( drop, pnl )
	if ( drop == 5 ) then
		return self:SetDropTarget( pnl.x, pnl.y, pnl:GetWide(), pnl:GetTall() )
	end

	if ( drop == 8 ) then
		return self:SetDropTarget( pnl.x, pnl.y - 2, pnl:GetWide(), 4 )
	end

	if ( drop == 2 ) then
		return self:SetDropTarget( pnl.x, pnl.y + pnl:GetTall() - 2, pnl:GetWide(), 4 )
	end

	if ( drop == 4 ) then
		return self:SetDropTarget( pnl.x - 2, pnl.y - 2, 4, pnl:GetTall() )
	end

	if ( drop == 6 ) then
		return self:SetDropTarget( pnl.x + pnl:GetWide() - 2, pnl.y, 4, pnl:GetTall() )
	end

	-- Unhandled!
	--self:ClearDropTarget()
end

--- The wiki example creates one like this (drag a child onto another to reorder).
function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )
	ctrl:MakeDroppable( "ExampleDraggable" )
	ctrl:SetSize( Width or 200, Height or 200 )

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DDragBase", "A panel that allows you to drag and drop its children to reorder them", PANEL, "DPanel" )
