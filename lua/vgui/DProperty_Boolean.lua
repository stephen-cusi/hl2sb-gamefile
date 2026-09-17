--[[ DProperty_Boolean -- a checkbox property (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DProperty_Boolean
	  Parent: DProperty_Generic.  Setup builds a DCheckBox, reports 1/0 through
	  ValueChanged, and DProperties paints the row while it is held down
	  (DCheckBox:IsEditing, added to lua/vgui/DCheckBox.lua).

	Ported from GMod's lua/vgui/prop_boolean.lua (49 lines).
--]]

local PANEL = {}

function PANEL:Init()
end

function PANEL:Setup( vars )

	self:Clear()

	local ctrl = self:Add( "DCheckBox" )
	ctrl:SetPos( 0, 2 )

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
		ctrl:SetChecked( tobool( val ) )
	end

	-- Alert row that value changed
	ctrl.OnChange = function( slf, newval )

		if ( newval ) then newval = 1 else newval = 0 end

		self:ValueChanged( newval )

	end

end

derma.DefineControl( "DProperty_Boolean", "A boolean property", PANEL, "DProperty_Generic" )
