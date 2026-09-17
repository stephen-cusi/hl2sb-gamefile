--[[ DCategoryHeader -- the clickable header of a collapsible category (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DCategoryHeader
	  Parent: DButton.  DoClick toggles the parent, and UpdateColours picks the
	  closed/open header colour out of Skin.Colours.Category.

	Ported from GMod's lua/vgui/dcategorycollapse.lua:2-44 (its own table-literal
	style, kept).

	Notes for this fork:
	  * lua/vgui/DCollapsibleCategory.lua here is an older, self-contained
	    implementation whose header is a DButton painting its own caption + chevron
	    (lua/vgui/DCollapsibleCategory.lua:12-30), and DProperties / DForm are built
	    on top of it.  This control is therefore registered for addon code that
	    creates it directly (and for a later faithful rewrite of that category),
	    not wired into DCollapsibleCategory yet - rewiring it means porting GMod's
	    whole 348-line category, which paints the header caption itself.
	  * Label:SetExpensiveShadow is a recorded no-op in this fork
	    (lua/includes/init.lua, vgui2 has no shadow concept); the panel-metatable
	    shim that makes it callable from a DButton was added with this port.
	  * Skin.Colours.Category.Header / Header_Closed were added to
	    lua/skins/hl2sb_default.lua for the same reason.
--]]

local PANEL = {

	Init = function( self )

		self:SetContentAlignment( 4 )
		self:SetTextInset( 5, 0 )
		self:SetFont( "DermaDefaultBold" )

	end,

	DoClick = function( self )

		self:GetParent():Toggle()

	end,

	UpdateColours = function( self, skin )

		if ( !self:GetParent():GetExpanded() ) then
			self:SetExpensiveShadow( 0, Color( 0, 0, 0, 200 ) )
			return self:SetTextStyleColor( skin.Colours.Category.Header_Closed )
		end

		self:SetExpensiveShadow( 1, Color( 0, 0, 0, 100 ) )
		return self:SetTextStyleColor( skin.Colours.Category.Header )

	end,

	Paint = function( self, w, h )

		-- GMod does nothing here: its DCollapsibleCategory paints the header caption
		-- and this button is only the click target.  This fork's category paints its
		-- own header too, so a bare DCategoryHeader would be invisible - ask the same
		-- skin hook this fork already uses (new: is "CategoryHead", painted by
		-- lua/skins/hl2sb_default.lua PaintCategoryHead) and draw the caption when
		-- nothing handled it.
		w = w or self:GetWide()
		h = h or self:GetTall()

		if ( derma.SkinHook( "Paint", "CategoryHead", self, w, h ) ) then return end

		derma.DrawText( self:GetFont() or "DermaDefaultBold", 8, math.floor( ( h - 13 ) / 2 ),
			self:GetText() or "", self:GetTextStyleColor() or Color( 228, 228, 228, 255 ) )

	end,

	GenerateExample = function()

		-- Do nothing!

	end

}

derma.DefineControl( "DCategoryHeader", "Category Header", PANEL, "DButton" )
