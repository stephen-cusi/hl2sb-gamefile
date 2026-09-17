--[[ DPanel -- HL2SB derma base container (original implementation). --]]

local PANEL = {}

function PANEL:Init()
	-- ⚠️ Mouse input must stay ENABLED (the engine default), even though this is "just a
	-- container".  GMod's DPanel does not touch it either (_legacy_gmod/vgui/dpanel.lua
	-- :16-24 only sets the paint flags); this fork used to disable it here.
	--
	-- Why it matters: vgui2/vgui_controls/Panel.cpp:3343 IsWithinTraverse() starts with
	--   if (!IsVisible() || !IsMouseInputEnabled()) return NULL;      // line 3347
	-- so a panel that refuses mouse input takes its WHOLE SUBTREE with it - children are
	-- never hit-tested.  With the disable in here every DPanel-derived container
	-- (DPanel, DIconLayout, DListLayout, DPropertySheet, DListView, DCategoryList, DMenu
	-- ...) silently made its buttons unclickable, and GMod content never calls
	-- SetMouseInputEnabled( true ) on a plain DPanel because upstream it is already on.
	--
	-- Decorative panels have to opt OUT themselves, exactly like GMod's controls do
	-- (DLabel / DImage / DTooltip and the Derma_DrawBackgroundBlur overlay all call
	-- SetMouseInputEnabled( false )).
	self:SetKeyBoardInputEnabled( false )
	self.m_bDrawBackground = true
end

function PANEL:SetDrawBackground( b )
	self.m_bDrawBackground = b
end

function PANEL:GetDrawBackground()
	return self.m_bDrawBackground
end

--- GMod: DPanel:SetPaintBackground( b ) / GetPaintBackground() -- the same flag as
--- SetBackgroundColor's painting under GMod's own name (GMod's DPanel:Init calls
--- SetPaintBackground( true ) and its deprecated DrawBackground accessor is an
--- alias).  A number of controls ported here call it -- DScrollPanel's canvas,
--- DForm, DDragBase -- so it lives on the base class rather than per control.
function PANEL:SetPaintBackground( b )
	self.m_bDrawBackground = ( b ~= false )
end

function PANEL:GetPaintBackground()
	return self.m_bDrawBackground
end

--- GMod's SetBackgroundColor / GetBackgroundColor map onto the engine's
--- background colour field (SetBgColor is engine-bound).
---
--- ⚠️ The colour is ALSO kept in `m_bgColor`, because that is the field GMod's skin
--- reads (`skins/default.lua`: self.tex.Panels.Normal( 0, 0, w, h, panel.m_bgColor )) --
--- this fork's SKIN:PaintPanel painted a flat skin colour and ignored the panel's own
--- one, so every SetBackgroundColor in GMod content was invisible (DPropertySheet's
--- pages, DBubbleContainer, DFileBrowser's list - found in game 2026-09-17: the demo's
--- three pages all came out the same grey).
function PANEL:SetBackgroundColor( clr )
	self.m_bgColor = clr
	if ( self.SetBgColor ) then self:SetBgColor( clr ) end
end

function PANEL:GetBackgroundColor()
	if ( self.m_bgColor ) then return self.m_bgColor end
	if ( self.GetBgColor ) then return self:GetBgColor() end
end

--- GMod's DPanel is drag & drop aware: dragging only has an effect on panels made
--- droppable with Panel:Droppable( name ), because dragndrop.lua:425 DragMousePress
--- starts with `if ( !self.m_DragSlot ) then return end`.  Without these two
--- methods nothing in this fork ever called DragMousePress/DragMouseRelease, so
--- DDragBase / DTileLayout / DHorizontalScroller could receive drops but no drag
--- could ever begin.  Ported verbatim from GMod's lua/vgui/dpanel.lua:52-78; the
--- selection helpers it uses (StartBoxSelection / EndBoxSelection /
--- IsSelectionCanvas / IsDraggable) all exist in
--- lua/includes/extensions/client/panel/{selections,dragdrop}.lua.
function PANEL:OnMousePressed( mousecode )
	if ( self:IsSelectionCanvas() && !dragndrop.IsDragging() ) then
		self:StartBoxSelection()
		return
	end

	if ( self:IsDraggable() ) then
		self:MouseCapture( true )
		self:DragMousePress( mousecode )
	end
end

function PANEL:OnMouseReleased( mousecode )
	if ( self:EndBoxSelection() ) then return end

	self:MouseCapture( false )

	if ( self:DragMouseRelease( mousecode ) ) then
		return
	end
end

function PANEL:Paint( w, h )
	if ( not self.m_bDrawBackground ) then return end

	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Panel", self, w, h )
end

derma.DefineControl( "DPanel", "HL2SB base container panel", PANEL, "Panel" )
