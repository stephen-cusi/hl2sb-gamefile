--[[ DEntityProperties -- the entity's own property sheet (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DEntityProperties
	  Parent: DProperties.  SetEntity( ent ), RebuildControls(), EditVariable(
	  varname, editdata ), EntityLost() / OnEntityLost(), AllowAutoRefresh and
	  Pre/PostAutoRefresh.

	Ported from GMod's lua/vgui/dentityproperties.lua (128 lines).  Each entry in
	`entity:GetEditingData()` becomes a row whose type string names the editor
	("Float", "Boolean", "String", "Vector", ...), the value is read back with
	GetNetworkKeyValue and written with EditValue -- so the whole property system
	ported in the last round is driven from here.

	Note for this fork: the rows are ordered with GMod's
	SortedPairsByMemberValue, which was missing here and has now been added to
	lua/includes/extensions/table.lua.
--]]

local PANEL = {}

function PANEL:Init()

	-- Nothing :)

end

--
-- Sets the entity to edit.
-- This can be called any time, even when another entity has been set.
--
function PANEL:SetEntity( entity )

	if ( self.m_Entity == entity ) then return end

	self.m_Entity = entity
	self:RebuildControls()

end

--
-- Clears and rebuilds the controls. Should only really be called internally.
--
function PANEL:RebuildControls()

	--
	-- we're rebuilding - so clear all the old controls
	--
	self:Clear()

	--
	-- It's kewl to return here - because it will leave an empty property sheet.
	--
	if ( !IsValid( self.m_Entity ) ) then return end
	if ( !isfunction( self.m_Entity.GetEditingData ) ) then return end

	--
	-- Call EditVariable for each entry in the entity's EditingData
	--
	local editor = self.m_Entity:GetEditingData()

	local i = 1000
	for name, edit in pairs( editor ) do
		if ( edit.order == nil ) then edit.order = i end
		i = i + 1
	end

	for name, edit in SortedPairsByMemberValue( editor, "order" ) do
		self:EditVariable( name, edit )
	end

end

--
-- Called internally. Adds an entity variable to watch.
--
function PANEL:EditVariable( varname, editdata )

	if ( !istable( editdata ) ) then return end
	if ( !isstring( editdata.type ) ) then return end

	--
	-- Create a property row in the specified category.
	--
	local row = self:CreateRow( editdata.category or "#entedit.general", editdata.title or varname )

	--
	-- This is where the real business is done. Setup creates the specific controls for
	-- the 'type' (eg, Float, Boolean). If the type isn't found it reverts to a generic textbox.
	--
	row:Setup( editdata.type, editdata )

	--
	-- These functions need to be implemented for each row. This is how it
	-- gets and sets the data from the entity. DataUpdate is called peridocailly
	-- but only when it's not being edited.
	--
	row.DataUpdate = function( _ )
		if ( !IsValid( self.m_Entity ) ) then self:EntityLost() return end
		row:SetValue( self.m_Entity:GetNetworkKeyValue( varname ) )
	end

	--
	-- This is called when the data has changed as a result of user input.
	-- We use it to edit the value on the entity itself.
	--
	row.DataChanged = function( _, val )
		if ( !IsValid( self.m_Entity ) ) then self:EntityLost() return end
		self.m_Entity:EditValue( varname, tostring( val ) )
	end

end

--
-- Called when we were editing an entity and then it became invalid (probably removed)
--
function PANEL:EntityLost()

	self:Clear()
	self:OnEntityLost()

end

function PANEL:OnEntityLost()

	-- For override

end

--
-- Auto-refreshing - these functions are just for the benefit
-- of development. So that when this control gets auto-reloaded
-- due to editing - we can rebuild things using the new function(s).
--
PANEL.AllowAutoRefresh = true

function PANEL:PreAutoRefresh()
end

function PANEL:PostAutoRefresh()

	self:RebuildControls()

end

derma.DefineControl( "DEntityProperties", "The entity's own property sheet", PANEL, "DProperties" )
