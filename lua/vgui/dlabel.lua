--[[ DLabel -- a transparent text label (original implementation).

	Draws through the framework's font/skin helpers rather than the engine's
	Label control: this fork's C Label re-applies the scheme font after every
	Lua hook (see scripted_controls/lLabel.h), which is why the copied GMod
	DLabel always rendered at the wrong size.  Text drawn in Lua from Paint
	cannot be clobbered. --]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )	-- DPanel heritage: labels are transparent
	self:SetText( "" )
	self:SetMouseInputEnabled( false )
	self:SetKeyBoardInputEnabled( false )
	self.m_strFont = "DermaDefault"
	self.m_colText = Color( 228, 228, 228, 255 )
	self.m_bWrap = false
	self.m_iAlign = 0	-- 0 left, 1 center, 2 right
end

function PANEL:SetText( strText )
	self.m_strText = tostring( strText or "" )
	if ( self.m_bAutoWide ) then self:SizeToContents() end
end

function PANEL:GetText()
	return self.m_strText or ""
end

function PANEL:SetFont( strFont )
	self.m_strFont = strFont
end

function PANEL:GetFont()
	return self.m_strFont
end

function PANEL:SetTextColor( clr )
	self.m_colText = clr or self.m_colText
end

function PANEL:GetTextColor()
	return self.m_colText
end

--- GMod: DLabel:SetDark( b ) / SetBright( b ) -- "sets the text of the label to be
--- dark/bright colored in accordance with the currently active Derma skin"
--- (GMod's lua/vgui/dlabel.lua:107-121; its AccessorFunc pair is m_bDark/m_bBright).
---
--- ⚠️ These used to hardcode Color( 60, 60, 60 ) for "dark", which is invisible on every
--- panel this fork has (they are all dark): in the player model selector the category
--- header printed "Other" barely legibly (2026-09-17, seen in a screenshot).  GMod asks
--- the skin - skins/default.lua:267-271 has the whole Colours.Label group, and this
--- fork's lua/skins/hl2sb_default.lua has it too.  The hardcoded pair stays as the
--- fallback for a skin that defines no such group, so nothing changes there.
local FALLBACK_LABEL_DARK = Color( 60, 60, 60, 255 )
local FALLBACK_LABEL_BRIGHT = Color( 255, 255, 255, 255 )

--- GMod: DLabel:UpdateColours( skin ) -- the scheme pass asks for the colour (DLabel's
--- ApplySchemeSettings in this file calls it), so the skin's values keep winning after a
--- later skin/theme pass too.
function PANEL:UpdateColours( skin )
	if ( self.m_bBright ) then return self:SetTextColor( self:SkinLabelColour( skin, "Bright" ) ) end
	if ( self.m_bDark ) then return self:SetTextColor( self:SkinLabelColour( skin, "Dark" ) ) end

	return self:SetTextColor( self.m_colText )
end

--- The skin's Colours.Label[ key ], or this file's own default pair.
function PANEL:SkinLabelColour( skin, strKey )
	skin = skin or ( self.GetSkin and self:GetSkin() )
	local col = skin and skin.Colours and skin.Colours.Label and skin.Colours.Label[ strKey ]

	if ( col ) then return col end

	return ( strKey == "Dark" ) and FALLBACK_LABEL_DARK or FALLBACK_LABEL_BRIGHT
end

function PANEL:SetDark( bDark )
	self.m_bDark = bDark and true or false
	if ( self.m_bDark ) then self.m_bBright = false end

	self:SetTextColor( self:SkinLabelColour( nil, "Dark" ) )
end

function PANEL:GetDark()
	return self.m_bDark == true
end

function PANEL:SetBright( bBright )
	self.m_bBright = bBright and true or false
	if ( self.m_bBright ) then self.m_bDark = false end

	self:SetTextColor( self:SkinLabelColour( nil, "Bright" ) )
end

function PANEL:GetBright()
	return self.m_bBright == true
end

function PANEL:SetWrap( b )
	self.m_bWrap = b
end

function PANEL:GetWrap()
	return self.m_bWrap == true
end

--- GMod: DLabel:SetAutoStretchVertical( b ) -- "Sets whether the label should
--- automatically stretch vertically to fit its text" (used with SetWrap; DForm's
--- Help/ControlHelp rows and the spawnmenu's help text call it).
function PANEL:SetAutoStretchVertical( b )
	self.m_bAutoStretchVertical = b and true or false
	self:InvalidateLayout()
end

function PANEL:GetAutoStretchVertical()
	return self.m_bAutoStretchVertical == true
end

--- Word-wrap `text` to `maxW` and return the lines.  GMod gets this from the C
--- label; this fork's label paints in Lua, so the wrapping is done here (only
--- when SetWrap( true ) was asked for - an unwrapped label is one line, exactly
--- as before).
function PANEL:GetWrappedLines( maxW )
	local text = self.m_strText or ""

	if ( not self.m_bWrap or not maxW or maxW <= 0 or text == "" ) then
		return { text }
	end

	local lines = {}
	local line = ""

	for word in string.gmatch( text, "%S+" ) do
		local candidate = ( line == "" ) and word or ( line .. " " .. word )
		local w = derma.GetTextSize( self.m_strFont, candidate )

		if ( w > maxW and line ~= "" ) then
			lines[ #lines + 1 ] = line
			line = word
		else
			line = candidate
		end
	end

	if ( line ~= "" ) then lines[ #lines + 1 ] = line end
	if ( #lines == 0 ) then lines[ 1 ] = "" end

	return lines
end

--- GMod: Panel:SetContentAlignment( align ) -- vgui2's Label alignment enum
--- (public/vgui_controls/Label.h): 0 a_northwest, 1 a_north, 2 a_northeast,
--- 3 a_west, 4 a_center, 5 a_east, 6 a_southwest, 7 a_south, 8 a_southeast.
--- Paint maps it below; the default (a_west, vertically centred) is what this
--- label has always drawn.
function PANEL:SetContentAlignment( iAlign )
	self.m_iAlign = iAlign
end

function PANEL:GetContentAlignment()
	return self.m_iAlign or 3
end

--- GMod: Panel:SetTextInset( x, y ) -- offset added to the text's own position.
--- DForm:Help / DForm:ControlHelp and a lot of GMod Lua pass ( 0, 0 ) to reset it.
function PANEL:SetTextInset( x, y )
	self.m_iTextInsetX = x or 0
	self.m_iTextInsetY = y or 0
end

function PANEL:GetTextInset()
	return self.m_iTextInsetX or 0, self.m_iTextInsetY or 0
end

--- GMod: DLabel:GetContentSize() -- the text's own size, which
--- includes/extensions/client/panel.lua:334/346 (SizeToContentsX/Y, both documented
--- "Only works on Labels") and GMod's DLabel:SizeToContents are built on.  This
--- fork's label measures the same way it paints (derma.GetTextSize), so
--- SizeToContents below and any addon calling GetContentSize agree.
---
--- ⚠️ The text inset is part of the answer, exactly like the engine Label it replaces:
--- vgui2/vgui_controls/Label.cpp `Label::GetContentSize` ends with
--- `wide = (tx1 - tx0) + _textInset[0];`.  GMod code depends on that - a DTab insets
--- its caption by `10 + icon width` and then sizes the tab from GetContentSize
--- (gmod/lua/vgui/dpropertysheet.lua:92-102), so without the inset the tab comes out
--- too narrow and the caption is clipped (seen in game 2026-09-17, see AGENTS.md).
function PANEL:GetContentSize()
	local insetX = self.m_iTextInsetX or 0

	-- wrapped text: as wide as the widest line, as tall as all of them
	if ( self.m_bWrap ) then
		local lines = self:GetWrappedLines( self:GetWide() )
		local w, h = 0, 0
		local lineH = select( 2, derma.GetTextSize( self.m_strFont, "Xg" ) )

		for _, line in ipairs( lines ) do
			w = math.max( w, derma.GetTextSize( self.m_strFont, line ) )
		end

		h = lineH * #lines

		return w + insetX, h
	end

	local w, h = derma.GetTextSize( self.m_strFont, self.m_strText or "" )

	return w + insetX, h
end

--- GMod: DLabel:SetTextStyleColor( col ) -- "the colour of the text, ignoring the
--- skin" (GMod's DLabel keeps m_colTextStyle and hands it to the engine Label's
--- FGColor).  DLabelURL sets it for its blue links, and DButton already has the
--- same pair.  Here it goes straight to this control's own text colour.
function PANEL:SetTextStyleColor( col )
	self.m_colTextStyle = col
	self:SetTextColor( col )
end

function PANEL:GetTextStyleColor()
	return self.m_colTextStyle or self.m_colText
end

function PANEL:SizeToContents()
	local w, h = self:GetContentSize()
	self:SetSize( w + 2, h + 2 )
end

--- GMod: DLabel:SizeToContentsX() / DLabel:SizeToContentsY()
--- (wiki: https://wiki.facepunch.com/gmod/DLabel:SizeToContentsX).  SizeToContents
--- sizes both axes; these size one and leave the other alone.  GMod's player model
--- selector uses them for its category captions
--- (sandbox/gamemode/editor_player.lua:85: label:SizeToContentsX()), and this fork
--- only ever had the both-axes version.
function PANEL:SizeToContentsX()
	local w = select( 1, self:GetContentSize() )
	self:SetWide( w + 2 )
end

function PANEL:SizeToContentsY()
	local _, h = self:GetContentSize()
	self:SetTall( h + 2 )
end

--- GMod: with SetAutoStretchVertical the label keeps its width and grows (or
--- shrinks) to the wrapped text, instead of being resized to it.
function PANEL:PerformLayout( w, h )
	if ( not self.m_bAutoStretchVertical ) then return end

	local _, th = self:GetContentSize()
	self:SetTall( math.max( 1, th + 2 ) )
end

--- GMod idiom: widen to the text and let the parent's layout place it.
function PANEL:DockToWindowPosition( x, y )
	self:SetPos( x, y )
end

--[[ GMod's click surface (dlabel.lua:168-296).

	Labels ship with mouse input OFF (Init above, GMod's dlabel.lua:28), so this
	path is only reached by the controls that turn it back on: DLabelURL and
	DLabelEditable here, and any addon label that enables it.

	GMod's OnMousePressed also does its own 0.2s double-click timing; this fork's
	engine already dispatches OnMouseDoublePressed (scripted_controls/lLabel.h),
	so the timing copy is not needed - SetDoubleClickingEnabled stays as the API
	compatibility accessor.  GMod keeps the pressed flag in `self.Depressed`
	(shared with its toggle/selectable machinery); this fork uses its own field.  --]]

AccessorFunc( PANEL, "m_bDoubleClicking", "DoubleClickingEnabled", FORCE_BOOL )

function PANEL:OnMousePressed( mousecode )
	if ( !self:IsEnabled() ) then return end

	self.m_bLabelDepressed = true
	self:DragMousePress( mousecode )
end

function PANEL:OnMouseDoublePressed( mousecode )
	if ( !self:IsEnabled() ) then return end

	self:DoDoubleClick()
end

function PANEL:OnMouseReleased( mousecode )
	if ( !self:IsEnabled() ) then return end

	-- GMod checks this before the hover/click handling, because a drag that ends
	-- outside the label must not also click it.
	if ( self:DragMouseRelease( mousecode ) ) then
		self.m_bLabelDepressed = false
		return
	end

	if ( !self.m_bLabelDepressed ) then return end
	self.m_bLabelDepressed = false

	if ( self:IsSelectionCanvas() ) then
		self:StartBoxSelection()
		self:EndBoxSelection()
	end

	if ( mousecode == MOUSE_RIGHT ) then
		self:DoRightClick()
	elseif ( mousecode == MOUSE_MIDDLE ) then
		self:DoMiddleClick()
	elseif ( mousecode == MOUSE_LEFT ) then
		self:DoClick()
	end
end

function PANEL:DoClick()
end

function PANEL:DoRightClick()
end

function PANEL:DoMiddleClick()
end

function PANEL:DoDoubleClick()
end

--- GMod: DLabel's scheme pass asks the control to pick its colours
--- ("if ( self.UpdateColours ) then self:UpdateColours( self:GetSkin() ) end"), which
--- is how DListViewLabel (lua/vgui/DListViewLine.lua) and DTree_Node_Button colour
--- themselves.  This fork's DLabel had no ApplySchemeSettings at all, so those
--- overrides were dead code; DButton already works this way.
function PANEL:ApplySchemeSettings()
	if ( isfunction( self.UpdateColours ) and self.GetSkin ) then
		local skin = self:GetSkin()
		if ( skin ) then self:UpdateColours( skin ) end
	end
end

--- GMod labels carry a `Hovered` flag that derived controls read in Paint (GMod's
--- DListBoxItem does: `elseif ( self.Hovered ) then draw.RoundedBox( ... )`).  This
--- fork's engine does not maintain it - DButton sets it by hand the same way - so
--- the two cursor hooks do it here.
function PANEL:OnCursorEntered()
	self.Hovered = true
end

function PANEL:OnCursorExited()
	self.Hovered = false
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local text = self.m_strText or ""
	if ( text == "" ) then return end

	local tw, th = derma.GetTextSize( self.m_strFont, text )

	-- vgui2's Label alignment enum (see SetContentAlignment above): the low digit
	-- is the horizontal third, the high digit the vertical one.
	local align = self.m_iAlign or 3
	local ax = align % 3
	local ay = math.floor( align / 3 )

	-- wrapped: draw every line, one under the other
	if ( self.m_bWrap ) then
		local lines = self:GetWrappedLines( w )
		local lineH = th
		local blockH = lineH * #lines

		local y = self.m_iTextInsetY or 0
		if ( ay == 1 ) then y = math.floor( ( h - blockH ) / 2 )
		elseif ( ay == 2 ) then y = h - blockH end

		for _, line in ipairs( lines ) do
			local lw = derma.GetTextSize( self.m_strFont, line )
			local x = self.m_iTextInsetX or 0
			if ( ax == 1 ) then x = math.floor( ( w - lw ) / 2 )
			elseif ( ax == 2 ) then x = w - lw end

			derma.DrawText( self.m_strFont, x, y, line, self.m_colText )
			y = y + lineH
		end

		return
	end

	local x = 0
	if ( ax == 1 ) then x = math.floor( ( w - tw ) / 2 )
	elseif ( ax == 2 ) then x = w - tw end

	local y = 0
	if ( ay == 1 ) then y = math.floor( ( h - th ) / 2 )
	elseif ( ay == 2 ) then y = h - th end

	derma.DrawText( self.m_strFont, x + ( self.m_iTextInsetX or 0 ), y + ( self.m_iTextInsetY or 0 ),
		text, self.m_colText )
end

derma.DefineControl( "DLabel", "HL2SB text label", PANEL, "DPanel" )
