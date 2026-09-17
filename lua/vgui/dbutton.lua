--[[ DButton -- a push button (original implementation).

	The engine's C Button (vgui.Button) fires DoClick in C++ and never consults
	a Lua DoClick field, so GMod's `button.DoClick = function() end` idiom does
	not work on it.  This control lives on the scripted Panel instead, whose
	OnMousePressed / OnMouseReleased are dispatched to Lua by
	scripted_controls/lPanel.cpp, and DoClick is raised right there -- exactly
	what GMod code expects. --]]

local PANEL = {}

-- The engine's own enable/disable, kept before the class override below hides
-- the name; the scripted Panel metatable is where it lives.
local PanelMeta = FindMetaTable( "Panel" )
local EngineSetEnabled = PanelMeta and PanelMeta.SetEnabled

function PANEL:Init()
	self:SetText( "" )
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
	self:SetDrawBackground( false )
	self.m_strFont = "DermaDefault"
	self.m_bDepressed = false
	self.m_bHover = false
	self.m_bEnabled = true
end

function PANEL:SetText( strText )
	self.m_strText = tostring( strText or "" )
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

--- GMod: DLabel:SetTextStyleColor( clr ) -- the colour of the caption, set by a
--- control's UpdateColours.  This fork stores the label colour in m_colText, so
--- the two names point at the same value.
function PANEL:SetTextStyleColor( clr )
	self.m_colText = clr or self.m_colText
end

function PANEL:GetTextStyleColor()
	return self.m_colText
end

--- GMod: DButton's scheme pass asks the skin for its colours and then lets the
--- control override them (`UpdateColours`, which DTree_Node_Button and several
--- other ported controls define).  Nothing dispatched it before, so those
--- overrides were dead code.
function PANEL:ApplySchemeSettings()
	if ( isfunction( self.UpdateColours ) and self.GetSkin ) then
		local skin = self:GetSkin()
		if ( skin ) then self:UpdateColours( skin ) end
	end
end

function PANEL:SetEnabled( b )
	self.m_bEnabled = b
	if ( EngineSetEnabled ) then EngineSetEnabled( self, b ) end
end

function PANEL:IsEnabled()
	return self.m_bEnabled
end

--- GMod: DButton:IsDown() -- "Returns whether the button is currently held down."
--- (GMod's own dbutton.lua:26 reads its `Depressed` field; this control tracks
--- the same state as m_bDepressed.)  DHorizontalScroller:Think polls it.
function PANEL:IsDown()
	return self.m_bDepressed == true
end

--- GMod: DButton derives from DLabel, so GetContentSize / SizeToContents come along
--- with it; this fork's DButton derives from DPanel and neither existed, which
--- DTab (lua/vgui/DTab.lua) needs to size itself from its caption
--- ("local w, h = self:GetContentSize(); self:SetSize( w + 10, h )").
--- ⚠️ The text inset counts, like vgui2's `Label::GetContentSize`
--- (`wide = (tx1 - tx0) + _textInset[0]`, vgui2/vgui_controls/Label.cpp): DTab insets
--- its caption by `10 + icon width` first, so without it the tab is too narrow and the
--- caption is clipped.
function PANEL:GetContentSize()
	local w, h = derma.GetTextSize( self.m_strFont or "DermaDefault", self.m_strText or "" )

	w = w + ( self.m_iTextInsetX or 0 )

	if ( IsValid( self.m_Image ) ) then
		w = w + self.m_Image:GetWide()
	end

	return w, h
end

function PANEL:SizeToContents()
	local w, h = self:GetContentSize()
	self:SetSize( w + 8, h + 6 )
end

function PANEL:OnMousePressed( code )
	if ( code == MOUSE_RIGHT ) then
		self:DoRightClick()
		return
	end

	if ( not self.m_bEnabled ) then return end

	self.m_bDepressed = true
	self.m_bHover = true

	-- Without the capture, releasing the button outside the panel never reaches
	-- us and m_bDepressed sticks; with it, OnMouseReleased decides below
	-- whether the cursor is still over the button (GMod's cancel behaviour).
	self:MouseCapture( true )

	-- Drag & drop: only does anything on a panel made droppable with
	-- Panel:Droppable( name ) (dragdrop.lua:425 returns immediately otherwise).
	-- GMod gets this from DLabel (GMod's DButton derives from DLabel); this fork's
	-- DButton derives from DPanel, which carries the same two calls.
	self:DragMousePress( code )
end

function PANEL:OnCursorEntered()
	if ( self.m_bEnabled ) then
		self.m_bHover = true
		-- GMod's DLabel keeps the same state under this name, and ported controls
		-- read it (DTree_Node_Button:UpdateColours checks self.Hovered).
		self.Hovered = true
	end
end

function PANEL:OnCursorExited()
	self.m_bHover = false
	self.Hovered = false
end

function PANEL:OnMouseReleased( code )
	local wasDepressed = self.m_bDepressed
	self.m_bDepressed = false
	self:MouseCapture( false )

	-- The drag has to be resolved FIRST: while dragging, the cursor is normally no
	-- longer over this button (m_bHover false), so the hover test below would skip
	-- the drop and the drag would never land.  GMod's DLabel does the same
	-- (`if ( self:DragMouseRelease( mousecode ) ) then return end` before its click
	-- handling); for a plain button DragMouseRelease returns false and the click
	-- below runs exactly as before.
	if ( self:DragMouseRelease( code ) ) then
		return
	end

	if ( not self.m_bEnabled ) then return end
	if ( not wasDepressed ) then return end
	if ( self.m_bHover == false ) then return end

	self:DoClick()
end

function PANEL:OnMouseCaptureLost()
	self.m_bDepressed = false
end

--- GMod's default click does nothing; scripts overwrite this field.
function PANEL:DoClick()
end

--- GMod's right-click hook.
function PANEL:DoRightClick()
end

function PANEL:OnMouseReleasedRight( code )
end

--- GMod: Panel:SetContentAlignment( align ) / SetTextInset( x, y ), using
--- vgui2's Label alignment enum (public/vgui_controls/Label.h): 0 a_northwest,
--- 1 a_north, 2 a_northeast, 3 a_west, 4 a_center, 5 a_east, 6 a_southwest,
--- 7 a_south, 8 a_southeast.  4 (a_center) is the default, which is what this
--- button has always drawn; DNumPad's "0" key uses 4 + SetTextInset( 6, 0 ).
function PANEL:SetContentAlignment( align )
	self.m_iContentAlignment = align
end

function PANEL:GetContentAlignment()
	return self.m_iContentAlignment or 4
end

function PANEL:SetTextInset( x, y )
	self.m_iTextInsetX = x or 0
	self.m_iTextInsetY = y or 0
end

function PANEL:GetTextInset()
	return self.m_iTextInsetX or 0, self.m_iTextInsetY or 0
end

--- GMod: DButton:SetToggle( b ) / GetToggle() -- a toggled button stays visually
--- "held" (DColumnSheet's tabs drive this through SetActiveButton; DNumPad's
--- sticky keys use SetSelected instead).  GMod draws it from its skin; this
--- fork's skin has no such state, so Paint tints it below.
function PANEL:SetToggle( b )
	self.m_bToggle = b and true or false
end

function PANEL:GetToggle()
	return self.m_bToggle == true
end

-- NOTE: SetSelected / IsSelected are deliberately NOT overridden here.  The
-- Panel metatable owns them (includes/extensions/client/panel/selections.lua:47
-- sets self.m_bSelected and ApplySchemeSettings, with IsSelected gated on
-- IsSelectable), and DNumPad's sticky keys / DColumnSheet's tabs both go through
-- that path.  Paint below reads the same m_bSelected field.

--[[ GMod's DButton keeps an icon in a child DImage (its dbutton.lua:32-52, with
	`PANEL.SetIcon = PANEL.SetImage`); DColumnSheet's tabs, DProperty_Entity and
	MatSelect all call it.  This fork paints its own caption, so PerformLayout parks
	the image on the left and Paint starts the text after it. ]]

function PANEL:SetImage( img )
	if ( !img ) then
		if ( IsValid( self.m_Image ) ) then
			self.m_Image:Remove()
			self.m_Image = nil
		end

		self:InvalidateLayout()
		return
	end

	if ( !IsValid( self.m_Image ) ) then
		self.m_Image = vgui.Create( "DImage", self )
	end

	self.m_Image:SetImage( img )
	self.m_Image:SetMouseInputEnabled( false )

	if ( self.m_Image.SizeToContents ) then
		self.m_Image:SizeToContents()
	end

	self:InvalidateLayout()
end

PANEL.SetIcon = PANEL.SetImage

--- GMod: DButton:SetMaterial( mat ) -- the same slot, given an IMaterial.
function PANEL:SetMaterial( mat )
	if ( !mat ) then
		self:SetImage( nil )
		return
	end

	if ( !IsValid( self.m_Image ) ) then
		self.m_Image = vgui.Create( "DImage", self )
	end

	if ( self.m_Image.SetMaterial ) then
		self.m_Image:SetMaterial( mat )
	end

	self.m_Image:SetMouseInputEnabled( false )
	self:InvalidateLayout()
end

function PANEL:GetImage()
	if ( IsValid( self.m_Image ) and self.m_Image.GetImage ) then
		return self.m_Image:GetImage()
	end
end

function PANEL:PerformLayout( w, h )
	if ( !IsValid( self.m_Image ) ) then return end

	w = w or self:GetWide()
	h = h or self:GetTall()

	local iw, ih = self.m_Image:GetSize()
	self.m_Image:SetPos( 3, math.floor( ( h - ih ) / 2 ) )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Button", self, w, h )

	-- a toggled / selected button keeps a visible marker on top of the skin
	if ( self.m_bToggle or self.m_bSelected ) then
		surface.DrawSetColor( 52, 108, 190, 90 )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	local text = self.m_strText or ""
	if ( text == "" ) then return end

	local tw, th = derma.GetTextSize( self.m_strFont, text )

	local align = self.m_iContentAlignment or 4
	local ax = align % 3
	local ay = math.floor( align / 3 )

	local x = 0
	if ( ax == 1 ) then x = math.floor( ( w - tw ) / 2 )
	elseif ( ax == 2 ) then x = w - tw end

	-- an icon (SetImage, above) sits on the left: keep the caption clear of it
	if ( IsValid( self.m_Image ) ) then
		local iw = self.m_Image:GetWide()

		if ( ax == 1 ) then
			x = math.max( x, 3 + iw )
		else
			x = x + 3 + iw
		end
	end

	local y = 0
	if ( ay == 1 ) then y = math.floor( ( h - th ) / 2 )
	elseif ( ay == 2 ) then y = h - th end

	local clr = self.m_colText or ( self.m_bEnabled and Color( 228, 228, 228, 255 ) or Color( 120, 120, 120, 255 ) )
	derma.DrawText( self.m_strFont, x + ( self.m_iTextInsetX or 0 ), y + ( self.m_iTextInsetY or 0 ), text, clr )
end

derma.DefineControl( "DButton", "HL2SB push button", PANEL, "DPanel" )
