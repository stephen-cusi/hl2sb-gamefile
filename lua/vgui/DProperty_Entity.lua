--[[ DProperty_Entity -- an entity picker property (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DProperty_Entity
	  Parent: DProperty_Generic.  Setup builds a wand button next to the text box;
	  clicking it starts the world picker and the chosen entity's EntIndex is
	  reported through ValueChanged.

	Ported from GMod's lua/vgui/prop_entity.lua (59 lines).

	This fork has the two things it needs: `DEFINE_BASECLASS` is a real lexer-level
	rewrite (game/shared/lua/luamanager.cpp:796) and `util.worldpicker` ships in
	lua/includes/extensions/util/worldpicker.lua.
--]]

DEFINE_BASECLASS( "DProperty_Generic" )

local PANEL = {}

function PANEL:Init()
end

function PANEL:Setup( vars )

	vars = vars or {}

	BaseClass.Setup( self, vars )

	local btn = self:Add( "DButton" )
	btn:Dock( LEFT )
	btn:DockMargin( 0, 1, 4, 1 )
	btn:SetWide( 24 )
	btn:SetText( "" )
	btn:SetImage( "icon16/wand.png" )

	-- Use the world picked to select an entity
	btn.DoClick = function( s )

		-- Make it look different when selecting things
		s:SetEnabled( false )

		util.worldpicker.Start( function( tr )

			self:SetEnabled( true )

			if ( !IsValid( tr.Entity ) ) then return end

			-- TODO: Maybe this should be EntSerial()?
			self:ValueChanged( tr.Entity:EntIndex(), true )

		end )

	end

	-- Enabled/disabled support
	self.IsEnabled = function( slf )
		return btn:IsEnabled()
	end
	local oldSetEnabled = self.SetEnabled
	self.SetEnabled = function( slf, b )
		btn:SetEnabled( b )
		oldSetEnabled( b ) -- Also handle the text entry
	end

end

derma.DefineControl( "DProperty_Entity", "An entity picker property", PANEL, "DProperty_Generic" )
