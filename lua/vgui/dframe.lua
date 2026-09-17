--[[ DFrame -- a draggable window (original implementation).

	Built on the scripted Panel rather than the engine's C Frame: this fork's
	LFrame has no Lua ApplySchemeSettings dispatch and its close button is
	C++-owned, while GMod's DFrame draws its entire chrome in Lua.  Dragging
	uses the panel's own mouse capture + OnCursorMoved (LPanel dispatches
	both), so there is no global Think poll. --]]

local PANEL = {}

local TITLEBAR_TALL = 24

-- Engine MakePopup captured before the override below hides the name.
local PanelMeta = FindMetaTable( "Panel" )
local EngineMakePopup = PanelMeta and PanelMeta.MakePopup

function PANEL:Init()
	self:SetSize( 400, 300 )
	self:SetVisible( true )
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
	self:SetDrawBackground( false )	-- the frame paints itself

	self.m_strTitle = ""
	self.m_bDragMoving = false
	self.m_bActive = false

	-- close button in the title bar
	self.m_pCloseButton = vgui.Create( "DButton", self, "CloseButton" )
	self.m_pCloseButton:SetText( "" )	-- the skin paints the glyph
	self.m_pCloseButton.DoClick = function( btn ) self:Close() end
	self.m_pCloseButton.Paint = function( btn, w, h )
		derma.SkinHook( "Paint", "CloseButton", btn, w, h )
	end

	-- caption buttons: GMod's DFrame has these too, hidden until asked for with
	-- SetMinimizeButtonVisible( true ) / SetMaximizeButtonVisible( true ).
	self.m_pMinimizeButton = vgui.Create( "DButton", self, "MinimizeButton" )
	self.m_pMinimizeButton:SetText( "" )
	self.m_pMinimizeButton:SetVisible( false )
	self.m_pMinimizeButton.DoClick = function( btn ) self:Minimize() end
	self.m_pMinimizeButton.Paint = function( btn, w, h )
		derma.SkinHook( "Paint", "MinimizeButton", btn, w, h )
	end

	self.m_pMaximizeButton = vgui.Create( "DButton", self, "MaximizeButton" )
	self.m_pMaximizeButton:SetText( "" )
	self.m_pMaximizeButton:SetVisible( false )
	self.m_pMaximizeButton.DoClick = function( btn ) self:Maximize() end
	self.m_pMaximizeButton.Paint = function( btn, w, h )
		derma.SkinHook( "Paint", "MaximizeButton", btn, w, h )
	end

	-- body panel: GMod's DFrame content docks into this, not the frame itself
	self.m_pBody = vgui.Create( "DPanel", self, "Body" )
	self.m_pBody:SetDrawBackground( false )
end

-- HL2SB: GMod's DFrame:Add() parents the child to the body (the area below the
-- title bar), not to the frame itself.  Without this, window:Add("DHorizontalDivider")
-- puts the divider behind the title bar and the layout collapses.
function PANEL:Add( class, name )
	local pnl = vgui.Create( class, self.m_pBody, name )
	return pnl
end

function PANEL:SetTitle( strTitle )
	self.m_strTitle = tostring( strTitle or "" )
end

function PANEL:GetTitle()
	return self.m_strTitle or ""
end

--- GMod's DFrame:GetClientArea() -> x, y, w, h of the content region.
function PANEL:GetClientArea()
	local w, h = self:GetSize()
	return 0, TITLEBAR_TALL, w, math.max( 0, h - TITLEBAR_TALL )
end

function PANEL:SetSizable( b )
	self.m_bSizable = b
end

function PANEL:SetDeleteOnClose( b )
	self.m_bDeleteOnClose = b
end

--- GMod: DFrame:SetMinWidth / GetMinWidth / SetMinHeight / GetMinHeight
--- (AccessorFunc( PANEL, "m_iMinWidth", "MinWidth", FORCE_NUMBER ) in GMod's
--- lua/vgui/dframe.lua:11-12).
--- ⚠️ They only store the values: this fork's DFrame has no resize implementation at
--- all (SetSizable above just records a flag and the engine's C Frame resize handles are
--- unreachable from a scripted panel), so there is no size the minimum could clamp.
--- They exist so GMod code keeps working, e.g. the player model selector
--- (garrysmod/gamemodes/sandbox/gamemode/editor_player.lua:25-26:
---  window:SetMinWidth( 400 ) / window:SetMinHeight( 250 )).
function PANEL:SetMinWidth( i )
	self.m_iMinWidth = i
end

function PANEL:GetMinWidth()
	return self.m_iMinWidth or 0
end

function PANEL:SetMinHeight( i )
	self.m_iMinHeight = i
end

function PANEL:GetMinHeight()
	return self.m_iMinHeight or 0
end

--- GMod's DFrame chrome API.  The engine's C Frame bindings ("Frame" metatable) are
--- unreachable from here because DFrame is built on the scripted Panel (see the header
--- comment), so these live in Lua.  Without them
---     Frame:SetDraggable( false ) / Frame:ShowCloseButton( true )
--- threw "attempt to call a nil value" and MakePopup() was never reached.
function PANEL:SetDraggable( b )
	self.m_bDraggable = b and true or false

	if ( not self.m_bDraggable and self.m_bDragMoving ) then
		self.m_bDragMoving = false
		self:MouseCapture( false )
	end
end

function PANEL:IsDraggable()
	return self.m_bDraggable ~= false
end

function PANEL:ShowCloseButton( b )
	if ( self.m_pCloseButton ) then
		self.m_pCloseButton:SetVisible( b ~= false )
	end
end

function PANEL:IsCloseButtonVisible()
	return self.m_pCloseButton ~= nil and self.m_pCloseButton:IsVisible()
end

--- Not drawn by this fork's DFrame; kept so guide / addon code does not die on them.
function PANEL:SetTitleBarVisible( b )
	self.m_bTitleBarVisible = b ~= false
end

--- GMod's caption buttons.  They are hidden by default; GMod's own DFrame:Init hides
--- them too, and guide code turns them on with the setters below.
function PANEL:SetMinimizeButtonVisible( b )
	if ( self.m_pMinimizeButton ) then self.m_pMinimizeButton:SetVisible( b ~= false ) end
	if ( self.InvalidateLayout ) then self:InvalidateLayout( true ) end
end

function PANEL:SetMaximizeButtonVisible( b )
	if ( self.m_pMaximizeButton ) then self.m_pMaximizeButton:SetVisible( b ~= false ) end
	if ( self.InvalidateLayout ) then self:InvalidateLayout( true ) end
end

function PANEL:IsMinimizeButtonVisible()
	return self.m_pMinimizeButton ~= nil and self.m_pMinimizeButton:IsVisible()
end

function PANEL:IsMaximizeButtonVisible()
	return self.m_pMaximizeButton ~= nil and self.m_pMaximizeButton:IsVisible()
end

-- GMod 12 spellings, still used by old addons.
function PANEL:ShowMinimizeButton( b ) self:SetMinimizeButtonVisible( b ) end
function PANEL:ShowMaximizeButton( b ) self:SetMaximizeButtonVisible( b ) end

function PANEL:Minimize()
	if ( self.m_bMinimized ) then return end

	self.m_bMinimized = true
	self.m_nRestoreW, self.m_nRestoreH = self:GetSize()

	if ( self.m_pBody ) then self.m_pBody:SetVisible( false ) end
	self:SetTall( TITLEBAR_TALL )
end

function PANEL:Restore()
	if ( self.m_pBody ) then self.m_pBody:SetVisible( true ) end

	if ( not self.m_bMinimized ) then return end

	self.m_bMinimized = false
	self:SetSize( self.m_nRestoreW or 400, self.m_nRestoreH or 300 )
end

function PANEL:Maximize()
	local pParent = self:GetParent()
	if ( not IsValid( pParent ) ) then return end

	if ( not self.m_bMaximized ) then
		self.m_nRestoreX, self.m_nRestoreY = self:GetPos()
		self.m_nRestoreW, self.m_nRestoreH = self:GetSize()

		self:SetPos( 0, 0 )
		self:SetSize( pParent:GetWide(), pParent:GetTall() )
		self.m_bMaximized = true
	else
		self:SetPos( self.m_nRestoreX or 5, self.m_nRestoreY or 5 )
		self:SetSize( self.m_nRestoreW or 400, self.m_nRestoreH or 300 )
		self.m_bMaximized = false
	end
end

function PANEL:IsMaximized()
	return self.m_bMaximized == true
end

function PANEL:Close()
	self:SetVisible( false )

	if ( self.OnClose ) then
		local ok, err = pcall( self.OnClose, self )
		if ( not ok ) then Warning( "DFrame:OnClose failed: " .. tostring( err ) .. "\n" ) end
	end

	if ( self.m_bDeleteOnClose ~= false ) then
		self:Remove()
	end
end

function PANEL:MakePopup()
	if ( EngineMakePopup ) then EngineMakePopup( self ) end
	self:SetKeyBoardInputEnabled( true )
	self.m_bActive = true
end

function PANEL:SetActive( b )
	self.m_bActive = b
end

function PANEL:IsActive()
	return self.m_bActive
end

function PANEL:OnMousePressed( code )
	if ( code == MOUSE_LEFT and self:IsDraggable() ) then
		local x, y = derma.CursorPos( self )
		if ( y < TITLEBAR_TALL and not self:IsCloseButtonPoint( x, y ) ) then
			self.m_bDragMoving = true
			self.m_nDragOffX = x
			self.m_nDragOffY = y
			self:MouseCapture( true )
		end
	end
end

function PANEL:IsCloseButtonPoint( x, y )
	local w = self:GetWide()
	return x >= w - TITLEBAR_TALL and y < TITLEBAR_TALL
end

function PANEL:OnCursorMoved( x, y )
	if ( not self.m_bDragMoving ) then return end

	-- CursorPos is panel-relative; the window moves so that the point the drag
	-- started at stays under the cursor.
	local px, py = self:GetPos()
	self:SetPos( px + ( x - self.m_nDragOffX ), py + ( y - self.m_nDragOffY ) )
end

function PANEL:OnMouseReleased( code )
	if ( self.m_bDragMoving ) then
		self.m_bDragMoving = false
		self:MouseCapture( false )
	end
end

function PANEL:PerformLayout( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	local btnW, btnH = TITLEBAR_TALL, TITLEBAR_TALL - 4
	local bx = w - TITLEBAR_TALL

	-- right to left: close, maximize, minimize - only the visible ones take space
	self.m_pCloseButton:SetSize( btnW, btnH )
	self.m_pCloseButton:SetPos( bx, 2 )

	if ( self:IsMaximizeButtonVisible() ) then
		bx = bx - TITLEBAR_TALL
		self.m_pMaximizeButton:SetSize( btnW, btnH )
		self.m_pMaximizeButton:SetPos( bx, 2 )
	end

	if ( self:IsMinimizeButtonVisible() ) then
		bx = bx - TITLEBAR_TALL
		self.m_pMinimizeButton:SetSize( btnW, btnH )
		self.m_pMinimizeButton:SetPos( bx, 2 )
	end

	self.m_pBody:SetPos( 0, TITLEBAR_TALL )
	self.m_pBody:SetSize( w, math.max( 0, h - TITLEBAR_TALL ) )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Frame", self, w, h )
	derma.SkinHook( "Paint", "FrameTitle", self, w, TITLEBAR_TALL )

	-- title text
	local font = "DermaDefaultBold"
	local tw, th = derma.GetTextSize( font, self.m_strTitle )
	local ty = math.floor( ( TITLEBAR_TALL - th ) / 2 )
	derma.DrawText( font, 8, ty, self.m_strTitle, Color( 235, 235, 235, 255 ) )
end

derma.DefineControl( "DFrame", "HL2SB window", PANEL, "DPanel" )
