--[[ DProperty_Float -- a number property (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DProperty_Float
	  Parent: DProperty_Generic.  Setup builds a DNumSlider and moves its parts
	  around so the row looks like GMod's property sheet:

		ctrl.Scratch:SetParent( self:GetRow().Label )   -- drag-to-change on the label
		ctrl.Label:SetVisible( false )
		ctrl.TextArea:Dock( LEFT )
		ctrl.Slider:DockMargin( 0, 3, 8, 3 )

	  and its Paint shows the slider only while the row is being edited or hovered
	  (GMod's "PERFORMANCE !!!" comment).

	Ported from GMod's lua/vgui/prop_float.lua (77 lines).  This fork's DNumSlider
	now exposes GMod's names for those parts (Label/Slider/TextArea, plus SetDark,
	IsEditing, SetEnabled) - see lua/vgui/DNumSlider.lua.  `Scratch` is a
	DNumberScratch, which is not ported yet, so that one move is guarded and the
	drag-to-change stays unavailable until it lands.
--]]

local PANEL = {}

function PANEL:Init()
end

function PANEL:GetDecimals()
	return 2
end

function PANEL:Setup( vars )

	self:Clear()

	vars = vars or {}

	local ctrl = self:Add( "DNumSlider" )
	ctrl:Dock( FILL )
	ctrl:SetDark( true )
	ctrl:SetDecimals( self:GetDecimals() )

	-- Apply vars
	ctrl:SetMin( vars.min or 0 )
	ctrl:SetMax( vars.max or 1 )

	-- The label needs mouse input so we can scratch
	self:GetRow().Label:SetMouseInputEnabled( true )

	if ( IsValid( ctrl.Scratch ) ) then
		-- Take the scratch and place it on the Row's label
		ctrl.Scratch:SetParent( self:GetRow().Label )
	end

	-- Hide the numslider's label
	ctrl.Label:SetVisible( false )
	-- Move the text area to the left
	ctrl.TextArea:Dock( LEFT )
	-- Add a margin onto the slider - so it's not right up the side
	ctrl.Slider:DockMargin( 0, 3, 8, 3 )

	-- Return true if we're editing
	self.IsEditing = function( slf )
		return ctrl:IsEditing()
	end

	-- Enabled/disabled support
	self.IsEnabled = function( slf )
		return ctrl:IsEnabled()
	end
	self.SetEnabled = function( slf, b )
		ctrl:SetEnabled( b )
	end

	-- Set the value
	self.SetValue = function( slf, val )
		ctrl:SetValue( val )
	end

	-- Alert row that value changed
	ctrl.OnValueChanged = function( slf, newval )

		self:ValueChanged( newval )

	end

	self.Paint = function()

		-- PERFORMANCE !!!
		ctrl.Slider:SetVisible( self:IsEditing() or self:GetRow():IsChildHovered() )

	end

end

derma.DefineControl( "DProperty_Float", "A number property", PANEL, "DProperty_Generic" )
