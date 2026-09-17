--[[ DColorCombo -- colour picker in tabs (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DColorCombo
	  "The DColorCombo allows the user to choose color, without alpha, using DColorMixer
	   or DColorPalette in a tabbed view."  Parent: DPropertySheet.
	  Event: DColorCombo:OnValueChanged( newcol )   -- override me
	  Methods: BuildControls / GetColor / SetColor / IsEditing

	It is a DPropertySheet with two sheets - "Color" (a DColorMixer with no alpha bar) and
	"Palette" (a DColorPalette) - which is exactly how the wiki describes it, and both of
	those controls exist here now.

	⚠️ `IsEditing` returns true while this panel is the one pushing a colour into its
	children, which is what GMod uses it for; both children are wired so that a colour
	coming from them raises OnValueChanged exactly once.
--]]

local PANEL = {}

function PANEL:Init()
	self.m_Color = Color( 255, 255, 255, 255 )
	self.m_bEditing = false

	self:BuildControls()
end

--- Wiki: "Called internally to create panels necessary for this panel to work."
function PANEL:BuildControls()
	self.Mixer = vgui.Create( "DColorMixer", self )

	if ( IsValid( self.Mixer ) ) then
		self.Mixer:SetPalette( true )
		self.Mixer:SetAlphaBar( false )		-- the wiki: "choose color, without alpha"
		self.Mixer:SetWangs( true )

		self.Mixer.ValueChanged = function( _, col )
			if ( self.m_bEditing ) then return end

			self:SetColor( col, true )
		end
	end

	self.Palette = vgui.Create( "DColorPalette", self )

	if ( IsValid( self.Palette ) ) then
		self.Palette.OnValueChanged = function( _, col )
			if ( self.m_bEditing ) then return end

			self:SetColor( col, true )
		end
	end

	if ( IsValid( self.Mixer ) ) then
		self:AddSheet( "Color", self.Mixer, nil, true, true )
	end

	if ( IsValid( self.Palette ) ) then
		self:AddSheet( "Palette", self.Palette, nil, true, true )
	end
end

--- Wiki: "Returns true if the panel is currently being edited."
function PANEL:IsEditing()
	return self.m_bEditing == true
end

function PANEL:GetColor()
	return self.m_Color
end

--- `bFromControls` is the internal flag that says "a child already shows this colour",
--- which is what keeps OnValueChanged to one call per user action.
function PANEL:SetColor( col, bFromControls )
	if ( not col ) then return end

	col = Color( col.r or 255, col.g or 255, col.b or 255, col.a or 255 )

	self.m_bEditing = true

	if ( not bFromControls ) then
		if ( IsValid( self.Mixer ) ) then self.Mixer:SetColor( col ) end
		if ( IsValid( self.Palette ) and self.Palette.SetColor ) then self.Palette:SetColor( col ) end
	end

	self.m_Color = col
	self.m_bEditing = false

	self:OnValueChanged( col )
end

--- Wiki: "Called when the value (color) of this panel was changed. For override"
function PANEL:OnValueChanged( newcol )
end

function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )

	ctrl:SetSize( Width or 267, Height or 186 )
	ctrl:SetColor( Color( 255, 255, 255 ) )

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DColorCombo", "Colour picker in tabs", PANEL, "DPropertySheet" )
