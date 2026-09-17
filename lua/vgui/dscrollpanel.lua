--[[ DScrollPanel -- a container that scrolls (original, pure Lua).

	Owns a PnlContainer child that all Add()ed content lives in; content is
	shifted by Paint offset against a vertical DScrollBar.  GMod's contract:
	Add / GetCanvas / SetVScrollRange / SetValue / GetVScrollPos, child Dock
	inside the canvas. --]]

local PANEL = {}

local BAR_W = 14

function PANEL:Init()
	self:SetDrawBackground( false )
	self.m_bHorizontalScroll = false

	self.m_pVBar = vgui.Create( "DScrollBar", self, "VBar" )
	self.m_pVBar:SetVertical( true )
	self.m_pVBar:SetEnabled( false )
	self.m_pVBar:SetParentPanel( self )

	self.m_pCanvas = vgui.Create( "DPanel", self, "ContentContainer" )
	self.m_pCanvas:SetDrawBackground( false )

	-- ⚠️ The canvas MUST accept mouse input, or nothing Add()ed to it can ever be
	-- clicked: vgui2/vgui_controls/Panel.cpp:3347 refuses the whole subtree of a panel
	-- whose IsMouseInputEnabled() is false.  GMod does exactly this -
	-- _legacy_gmod/vgui/dscrollpanel.lua:11 `self.pnlCanvas:SetMouseInputEnabled( true )`.
	self.m_pCanvas:SetMouseInputEnabled( true )

	-- ... and because the canvas now takes the press, hand it back to the scroll panel,
	-- which is how GMod keeps drag/scroll behaviour on its canvas
	-- (_legacy_gmod/vgui/dscrollpanel.lua:10).  Without the forward the canvas would
	-- swallow every press in its empty area.
	self.m_pCanvas.OnMousePressed = function( slf, code )
		slf:GetParent():OnMousePressed( code )
	end

	self.m_iScrollDelta = 0
	self.m_iRange = 0
	self.m_iPos = 0
end

function PANEL:GetCanvas()
	return self.m_pCanvas
end

--- GMod: DScrollPanel:SizeToContents() - `self:SetSize( self.pnlCanvas:GetSize() )`
--- (_legacy_gmod/vgui/dscrollpanel.lua:45, the only implementation of it in GMod's
--- panel library that copies an inner canvas).  DTree_Node calls it on its child list
--- before adding that height to its own.
function PANEL:SizeToContents()
	local w, h = self.m_pCanvas:GetSize()
	self:SetSize( w, h )
end

--- GMod's DScrollPanel does NOT override Panel:Add (it has AddItem for the parented
--- case), so `scrollpanel:Add( "DLabel" )` and `scrollpanel:Add( someTable )` both
--- go through Panel:Add - which accepts a class name or an anonymous control table.
--- This fork narrowed that to a panel; DProperties relies on the wider contract
--- (`self:GetCanvas():Add( tblCategory )`), so the string/table forms are restored
--- here and parented to the canvas the same way.
function PANEL:Add( pnl )
	if ( isstring( pnl ) or istable( pnl ) ) then
		pnl = vgui.Create( pnl, self:GetCanvas() )
		return pnl
	end

	pnl:SetParent( self:GetCanvas() )
	return pnl
end

function PANEL:SetContentHeight( iH )
	self.m_iRange = math.max( 0, iH - self:GetCanvas():GetTall() )
	self.m_pVBar:SetEnabled( self.m_iRange > 0 )
	self:InvalidateLayout( true )
end

function PANEL:ContentSizeChanged( w, h )
	self:SetContentHeight( h )
end

function PANEL:InvalidateContentSize( b )
	local canvas = self:GetCanvas()
	local _, h = canvas:GetChildrenSize()
	self:SetContentHeight( h or 0 )
end

function PANEL:SetVScrollRange( iMin, iMax )
	self:SetContentHeight( iMax )
end

function PANEL:SetValue( iVal )
	self.m_iPos = math.Clamp( iVal or 0, 0, math.max( 0, self.m_iRange ) )
	self.m_pVBar:SetValue( self.m_iRange > 0 and ( self.m_iPos / self.m_iRange ) or 0 )
end

function PANEL:GetValue()
	return self.m_iPos
end

function PANEL:GetVScrollPos()
	return self.m_iPos
end

--- GMod: DScrollPanel:ScrollToChild( panel ) -- "Scrolls the scroll panel to the
--- given child panel" (gmod/vgui/dscrollpanel.lua:94-106).  GMod centres the child
--- and animates the bar; this fork's scroll value IS the pixel offset (m_iPos), so
--- the same maths lands directly on SetValue.  GMod asks the canvas for
--- GetChildPosition; children live in the canvas here, so their own y is the same
--- number.
function PANEL:ScrollToChild( pnl )
	if ( !IsValid( pnl ) ) then return end

	self:InvalidateLayout( true )

	local _, y = pnl:GetPos()
	local _, h = pnl:GetSize()

	self:SetValue( math.max( 0, y + h * 0.5 - self:GetTall() * 0.5 ) )
end

function PANEL:OnMouseWheeled( delta )
	self:SetValue( self.m_iPos - delta * 48 )
end

-- ⚠️ OnThink, NOT Think.  A panel's per-frame hook has exactly one name in this
-- engine, and it is the one scripted_controls/lPanel.cpp:181-187 dispatches:
--
--     void LPanel::OnThink() { BEGIN_LUA_CALL_PANEL_METHOD( "OnThink" ); ... }
--
-- so a `PANEL:Think` is never called.  THIS function is what mirrors the scrollbar's
-- drag value back into the canvas offset, which is why the grid could be dragged by
-- its bar with nothing moving: only the wheel worked, because OnMouseWheeled IS
-- dispatched and reaches the same value from the other direction.
function PANEL:OnThink()
	-- the bar's value tracks the drag; mirror it back into pixel positions
	if ( self.m_pVBar:Enabled() and self.m_iRange > 0 ) then
		local wanted = self.m_pVBar:GetValue() * self.m_iRange
		if ( math.abs( wanted - self.m_iPos ) > 0.5 ) then
			self.m_iPos = wanted
		end
	end
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local pad = self.m_iPadding or 0
	local barVisible = self.m_pVBar:Enabled()
	local canvasW = w - ( barVisible and BAR_W or 0 ) - 2 * pad

	self.m_pCanvas:SetPos( pad, pad )
	self.m_pCanvas:SetSize( math.max( 1, canvasW ), math.max( 1, h - 2 * pad ) )

	self.m_pVBar:SetPos( w - BAR_W, 0 )
	self.m_pVBar:SetSize( BAR_W, h )
end

function PANEL:Paint( w, h )
	-- shift the canvas by the scroll position; clipping comes from the engine's
	-- panel clip (the canvas is a child of a visible panel with PaintEnabled
	-- children -- content outside the bar-less rect stays hidden because vgui2
	-- clips child painting to the parent bounds).
	self.m_pCanvas:SetPos( 0, -math.floor( self.m_iPos ) )
end

--[[---------------------------------------------------------------------------
	GMod's own names for the same things, per
	https://wiki.facepunch.com/gmod/DScrollPanel

		AddItem( pnl )      -> Add
		GetCanvas()         -> already above
		GetVBar()           -> the vertical DScrollBar
		InnerWidth()        -> the width left for content once the bar is counted
		SetPadding( n )     -> an inset around the content
		Rebuild()           -> re-measure the content

	The wiki documents AddItem, not Add, so GMod code (and anything ported from it)
	calls AddItem; both work here.
-----------------------------------------------------------------------------]]

function PANEL:AddItem( pnl )
	return self:Add( pnl )
end

function PANEL:GetVBar()
	return self.m_pVBar
end

--- The width content actually gets, i.e. minus the bar when it is showing.
function PANEL:InnerWidth()
	return self:GetWide() - ( self.m_pVBar:Enabled() and BAR_W or 0 )
end

function PANEL:SetPadding( n )
	self.m_iPadding = math.max( 0, math.floor( n or 0 ) )
	self:InvalidateLayout( true )
end

function PANEL:GetPadding()
	return self.m_iPadding or 0
end

--- GMod's Rebuild: measure the children again instead of trusting the last range.
function PANEL:Rebuild()
	self:InvalidateContentSize( true )
end

derma.DefineControl( "DScrollPanel", "HL2SB scrolling container", PANEL, "DPanel" )
