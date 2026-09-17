--[[ DProperty_Generic -- the base of every DProperties editor (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DProperty_Generic
	  Parent: Panel.  GMod's own header says it best: "prop_generic is the base for
	  all other properties.  All the business should be done in :Setup using inline
	  functions.  So when you derive from this class - you should ideally only
	  override Setup."

	Ported from GMod's lua/vgui/prop_generic.lua (77 lines).  A row created by
	DProperties:CreateRow is filled in with row:Setup( type, vars ), and the editor
	that appears is built here: a DTextEntry, plus IsEditing / IsEnabled / SetValue
	closures that the row painter and the DProperty_* subclasses drive.

	Note for this fork: GMod's `text.OnValueChange` field is the fork's DTextEntry
	hook too (lua/vgui/DTextEntry.lua:OnTextChanged calls OnValueChange( value )),
	so this is verbatim; `text:SetPaintBackground( false )` (no field chrome) and
	`text:SetUpdateOnType( true )` were added to DTextEntry for it.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_pRow", "Row" )

function PANEL:Init()
end

--- GMod's Think; the value poll has to run in OnThink in this engine
--- (AGENTS.md 5.0.3).
function PANEL:OnThink()

	--
	-- Periodically update the value
	--
	if ( !self:IsEditing() && isfunction( self.m_pRow.DataUpdate ) ) then

		self.m_pRow:DataUpdate()

	end

end

function PANEL:Think()
	self:OnThink()
end

--
-- Called by this control, or a derived control, to alert the row of the change
--
function PANEL:ValueChanged( newval, bForce )

	if ( ( self:IsEditing() || bForce ) && isfunction( self.m_pRow.DataChanged ) ) then

		self.m_pRow:DataChanged( newval )

	end

end

function PANEL:Setup( vars )

	self:Clear()

	local text = self:Add( "DTextEntry" )
	if ( !vars || !vars.waitforenter ) then text:SetUpdateOnType( true ) end
	text:SetPaintBackground( false )
	text:Dock( FILL )

	-- Return true if we're editing
	self.IsEditing = function( slf )
		return text:IsEditing()
	end

	-- Enabled/disabled support
	self.IsEnabled = function( slf )
		return text:IsEnabled()
	end
	self.SetEnabled = function( slf, b )
		text:SetEnabled( b )
	end

	-- Set the value
	self.SetValue = function( slf, val )
		text:SetText( util.TypeToString( val ) )
	end

	-- Alert row that value changed
	text.OnValueChange = function( slf, newval )

		self:ValueChanged( newval )

	end

end

derma.DefineControl( "DProperty_Generic", "Base property editor", PANEL, "Panel" )
