--[[ DModelSelectMulti -- several DModelSelects behind tabs (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DModelSelectMulti
	  Parent: DPropertySheet.  AddModelList( name, modelList, conVar, dontSort,
	  dontCallListConVars ) -- one tab per model list, returned so the caller can
	  keep using it -- plus the ModelPanels table and SetHeight( numHeight ).

	Ported from GMod's lua/vgui/dmodelselectmulti.lua (31 lines).  Its tab panels
	are DModelSelects, and `self:AddSheet( name, ModelSelect )` is the DPropertySheet
	method this fork has (lua/vgui/DPropertySheet.lua).
--]]

local PANEL = {}

function PANEL:Init()
	self.ModelPanels = {}
	self:SetHeight( 2 )
end

function PANEL:SetHeight( numHeight )
	self:SetTall( 66 * ( numHeight or 2 ) + 26 )
end

function PANEL:AddModelList( name, modelList, conVar, dontSort, dontCallListConVars )
	local ModelSelect = vgui.Create( "DModelSelect", self )

	ModelSelect:SetModelList( modelList, conVar, dontSort, dontCallListConVars )

	self:AddSheet( name, ModelSelect )

	self.ModelPanels[ name ] = ModelSelect

	return ModelSelect
end

derma.DefineControl( "DModelSelectMulti", "Several model pickers behind tabs", PANEL, "DPropertySheet" )
