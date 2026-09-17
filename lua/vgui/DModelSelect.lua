--[[ DModelSelect -- a picker of model thumbnails (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DModelSelect
	  Parent: DPanelSelect.  SetModelList( modelList, conVar, dontSort,
	  dontCallListConVars ) and SetHeight( numHeight ) -- "sets the height in
	  'rows'"; each row is 66 pixels tall.

	Ported from GMod's lua/vgui/dmodelselect.lua (51 lines).  Its thumbnails are
	SpawnIcon panels (lua/vgui/SpawnIcon.lua, ported in this batch), and DForm's
	model pickers and DEntityProperties' model rows are built on it.

	Note for this fork: GMod's DPanelSelect base is a DPanelList, and
	`SortByMember( "Model", false )` is the DPanelList method this fork already
	has (lua/vgui/DPanelList.lua:211).
--]]

local PANEL = {}

function PANEL:Init()
	self:EnableVerticalScrollbar()
	self:SetHeight( 2 )
end

function PANEL:SetHeight( numHeight )
	self:SetTall( 66 * ( numHeight or 2 ) + 2 )
end

function PANEL:SetModelList( modelList, conVar, dontSort, dontCallListConVars )
	for model, v in pairs( modelList ) do
		local icon = vgui.Create( "SpawnIcon" )
		icon:SetModel( model )
		icon:SetSize( 64, 64 )
		icon:SetTooltip( model )
		icon.Model = model
		icon.ConVars = v

		local convars = {}

		-- some model lists, like from wheels, have extra convars in the ModelList
		-- we'll need to add those too
		if ( !dontCallListConVars && istable( v ) ) then
			table.Merge( convars, v ) -- copy them in to new list
		end

		-- make strConVar optional so we can have everything in the ModelList instead, if we want to
		if ( conVar ) then
			convars[ conVar ] = model
		end

		self:AddPanel( icon, convars )
	end

	if ( !dontSort ) then
		self:SortByMember( "Model", false )
	end
end

derma.DefineControl( "DModelSelect", "A picker of model thumbnails", PANEL, "DPanelSelect" )
