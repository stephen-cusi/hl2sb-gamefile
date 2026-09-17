--[[ DTree_Node_Button -- the clickable caption row of a tree node (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DTree_Node_Button
	  Parent: DButton.  It is the label half of DTree_Node: a left inset makes room
	  for the node's icon and expander, and UpdateColours picks the tree's
	  Selected / Hover / Normal text colour.

	Ported from GMod's lua/vgui/dtree_node_button.lua (37 lines).

	Note for this fork: `SetTextInset` / `SetContentAlignment` are now real on
	DButton, and DButton:ApplySchemeSettings calls UpdateColours (added with this
	port) - before that the colour override here was never reached.
--]]

local PANEL = {}

function PANEL:Init()

	self:SetTextInset( 32, 0 )
	self:SetContentAlignment( 4 )

end

function PANEL:Paint( w, h )

	derma.SkinHook( "Paint", "TreeNodeButton", self, w, h )

	--
	-- Draw the button text
	--
	return false

end

function PANEL:UpdateColours( skin )

	if ( self:IsSelected() ) then return self:SetTextStyleColor( skin.Colours.Tree.Selected ) end
	if ( self.Hovered ) then return self:SetTextStyleColor( skin.Colours.Tree.Hover ) end

	return self:SetTextStyleColor( skin.Colours.Tree.Normal )

end

function PANEL:GenerateExample()

	-- Do nothing!

end

derma.DefineControl( "DTree_Node_Button", "Tree Node Button", PANEL, "DButton" )
