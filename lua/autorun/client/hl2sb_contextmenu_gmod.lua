--[[----------------------------------------------------------------------------
    hl2sb_contextmenu_gmod.lua

    Port of GMod's C context menu, from

        garrysmod/gamemodes/sandbox/gamemode/spawnmenu/contextmenu.lua  (259 lines)

    Pressing C (bind "c" "+menu_context") opens the GMod context menu: the
    active tool's control panel docked bottom-right plus the DesktopWindows
    icon column (the player model selector is one of those icons - GMod itself
    registers exactly the same list.Set entry we already carry in
    lua/game/client/hl2sb_playermodel_gmod.lua).  C is no longer bound to the
    old standalone open_playermodel_selector keypress; that concommand still
    exists for direct use.

    Engine side needs nothing: cdll_client_int.cpp already registers the
    +menu_context/-menu_context ConCommands and dispatches the GMod
    OnContextMenuOpen/OnContextMenuClose hooks (same hold-to-show shape as
    +menu/Q), and the fork's Q menu port already listens to its pair of
    hooks the same way this file listens to these.

    STRUCTURE (mirrors GMod's file):
      * spawnmenu_toggle convar           - GMod creates it in its sandbox
        spawnmenu/spawnmenu.lua:3; the fork has no GMod spawnmenu creation
        chain, so it is created (guarded) at the top of this file instead.
      * "ContextMenu" panel class         - verbatim (Init/Open/Close/
        PerformLayout/StartKeyFocus/EndKeyFocus/RestoreControlPanel).
      * CreateContextMenu()               - verbatim, three deltas below.
      * GM:OnContextMenuOpen/Close        - registered as HOOK listeners here
        instead of gamemode methods (same pattern as the fork's Q-menu port);
        the veto hooks (ContextMenuEnabled/ContextMenuOpen) keep GMod's
        gamemode-method shape: the fork's sandbox cl_init defines them to
        return true, non-sandbox gamemodes leave C inert exactly like GMod.

    DELTAS from GMod's file, each also marked at its site:
      1. SetWorldClicker calls guarded - this fork's vgui2 has no such binding
         (world click-through is a toolgun-era behaviour with no consumer
         here).  Harmless: with no tools ported there is no world click to
         pass through.
      2. Open() closes the spawn menu through hook.Run("OnSpawnMenuClose")
         instead of touching the (nonexistent) g_SpawnMenu global - the fork's
         Q menu closes idempotently behind that same hook.
      3. g_ContextMenu is built lazily on the first C press instead of inside
         CreateSpawnMenu at gamemode load (the fork has no CreateSpawnMenu).
         "contextmenu_reload" (GMod's is "spawnmenu_reload") rebuilds it.
--]]----------------------------------------------------------------------------

if ( SERVER ) then return end

-- ---------------------------------------------------------------------------
-- debug channel: hl2sb_ctxdebug (default ON until the in-game chain is proven;
-- set 0 to silence).  Everything prints into hl2sb_lua.log / console.
-- ---------------------------------------------------------------------------
local ctxdebugCV = GetConVar( "hl2sb_ctxdebug" )
if ( !ctxdebugCV and CreateClientConVar ) then
	ctxdebugCV = CreateClientConVar( "hl2sb_ctxdebug", "1", false, false, "Log the C context menu chain" )
end
local function Dbg( s )
	if ( ctxdebugCV and ctxdebugCV:GetBool() ) then
		print( "[ctx] " .. s )
	end
end

-- ---------------------------------------------------------------------------
-- DELTA: this fork's input routing walks the panel tree requiring EVERY level
-- to have mouse input enabled itself (the exact quirk that forced the Q menu
-- port to carry its AssertMouseInput helper).  GMod only ever enables the
-- popup root, so its DIconLayout / Canvas never enable themselves and are
-- still clickable; here a click would skip the whole icon row, land on the
-- full-screen panel itself and - with the world-click bridge installed - die
-- on gui.ScreenToVector (which this fork never bound).  Recurse and enable
-- after every tree change.
-- ---------------------------------------------------------------------------
local function EnableInputTree( pnl )
	if ( !IsValid( pnl ) ) then return end

	if ( pnl.SetMouseInputEnabled ) then
		pnl:SetMouseInputEnabled( true )
	end

	if ( pnl.GetChildren ) then
		for _, ch in pairs( pnl:GetChildren() ) do
			EnableInputTree( ch )
		end
	end
end

-- ---------------------------------------------------------------------------
-- spawnmenu_toggle (GMod: sandbox spawnmenu.lua:3, CreateConVar on the client)
-- ---------------------------------------------------------------------------
local spawnmenu_toggle = GetConVar( "spawnmenu_toggle" )

if ( !spawnmenu_toggle and CreateClientConVar ) then
	spawnmenu_toggle = CreateClientConVar( "spawnmenu_toggle", "0", true, false,
		"Tapping Q or C will toggle spawnmenu or contextmenu on and off, without having to hold the button." )
end

if ( !spawnmenu_toggle ) then
	-- Worst case: hold semantics (toggle off), never crash over a missing convar.
	spawnmenu_toggle = { GetBool = function() return false end }
end

-- ---------------------------------------------------------------------------
-- The ContextMenu panel (GMod contextmenu.lua:2-135, verbatim modulo delta 1)
-- ---------------------------------------------------------------------------
local PANEL = {}

AccessorFunc( PANEL, "m_bHangOpen", "HangOpen" )

function PANEL:Init()

	--
	-- This makes it so that when you're hovering over this panel
	-- you can `click` on the world. Your viewmodel will aim etc.
	--
	-- DELTA(1): SetWorldClicker is not bound in this fork's vgui2.
	if ( self.SetWorldClicker ) then
		self:SetWorldClicker( true )
	end

	self.Canvas = vgui.Create( "DCategoryList", self )
	self:SetHangOpen( false )

	-- DELTA: GMod's file docks this panel FILL and the ENGINE root resolves
	-- that to screen size (its root panel is a bounded fullscreen surface -
	-- vgui_rootpanel_hl2.cpp:127 does exactly SetBounds(0,0,ScreenWidth,
	-- ScreenHeight)).  This fork's parent for every top-level Lua panel is
	-- CScriptedClientLuaPanel (scripted_controls/lPanel.cpp:569), whose
	-- constructor never sizes it at all - so Dock( FILL ) here would fight a
	-- 0x0 parent layout and keep re-collapsing the whole tree (icons paint,
	-- every IsWithinTraverse hit-test against the zero rects fails, and the
	-- popup itself swallows all clicks).  Do NOT dock: size the panel to the
	-- screen explicitly; PerformLayout re-asserts it on resolution changes.
	self:SetPos( 0, 0 )
	self:SetSize( ScrW(), ScrH() )

end

function PANEL:Open()

	self:SetHangOpen( false )

	-- If the spawn menu is open, try to close it..
	-- DELTA(2): the fork's Q menu listens to this hook and hides itself
	-- (its Close is guarded and idempotent, so firing it while Q is closed
	-- does nothing).
	hook.Run( "OnSpawnMenuClose" )

	if ( self:IsVisible() ) then return end

	CloseDermaMenus()

	self:MakePopup()
	self:SetVisible( true )
	self:SetKeyboardInputEnabled( false )
	self:SetMouseInputEnabled( true )

	RestoreCursorPosition()

	local bShouldShow = hook.Run( "ContextMenuShowTool" )
	local bShow = bShouldShow == nil or bShouldShow

	-- Set up the active panel..
	if ( bShow && IsValid( spawnmenu.ActiveControlPanel() ) ) then

		self.OldParent = spawnmenu.ActiveControlPanel():GetParent()
		self.OldPosX, self.OldPosY = spawnmenu.ActiveControlPanel():GetPos()

		spawnmenu.ActiveControlPanel():SetParent( self )

		self.Canvas:Clear()
		self.Canvas:AddItem( spawnmenu.ActiveControlPanel() )
		self.Canvas:Rebuild()
		self.Canvas:SetVisible( true )

	else

		self.Canvas:SetVisible( false )

	end

	self:InvalidateLayout( true )

	-- DELTA: every level of this fork's input tree needs its own flag (see
	-- EnableInputTree).  Covers the icon row, the menubar we just adopted and
	-- any desktop window children built since the last open.
	EnableInputTree( self )

end

function PANEL:Close()

	if ( self:GetHangOpen() ) then
		self:SetHangOpen( false )
		return
	end

	RememberCursorPosition()

	CloseDermaMenus()

	self:SetKeyboardInputEnabled( false )
	self:SetMouseInputEnabled( false )

	self:SetAlpha( 255 )
	self:SetVisible( false )
	self:RestoreControlPanel()

end

function PANEL:PerformLayout()

	-- DELTA: keep the explicit screen size (see Init).  GMod's engine root does
	-- this for every top-level panel through Dock( FILL ); this fork's scripted
	-- root (CScriptedClientLuaPanel) is never given bounds, so FILL has no
	-- parent size to resolve against and the whole menu tree would hit-test at
	-- zero size.
	local w, h = self:GetSize()
	if ( w != ScrW() or h != ScrH() ) then
		self:SetSize( ScrW(), ScrH() )
	end

	if ( IsValid( spawnmenu.ActiveControlPanel() ) ) then

		spawnmenu.ActiveControlPanel():InvalidateLayout( true )

		local Tall = math.min( spawnmenu.ActiveControlPanel():GetTall() + 10, ScrH() * 0.8 )
		if ( self.Canvas:GetTall() != Tall ) then self.Canvas:SetTall( Tall ) end
		if ( self.Canvas:GetWide() != 320 ) then self.Canvas:SetWide( 320 ) end

		self.Canvas:SetPos( ScrW() - self.Canvas:GetWide() - 50, ScrH() - 50 - Tall )
		self.Canvas:InvalidateLayout( true )

	end

end

function PANEL:StartKeyFocus( pPanel )

	self:SetKeyboardInputEnabled( true )
	self:SetHangOpen( true )

end

function PANEL:EndKeyFocus( pPanel )

	self:SetKeyboardInputEnabled( false )

end

function PANEL:RestoreControlPanel()

	-- Restore the active panel
	if ( !spawnmenu.ActiveControlPanel() ) then return end
	if ( !self.OldParent ) then return end

	spawnmenu.ActiveControlPanel():SetParent( self.OldParent )
	spawnmenu.ActiveControlPanel():SetPos( self.OldPosX, self.OldPosY )

	self.OldParent = nil

end

--
-- Note here: EditablePanel is important! Child panels won't be able to get
-- keyboard input if it's a DPanel or a Panel. You need to either have an
-- EditablePanel or a DFrame (which is derived from EditablePanel) as your
-- first panel attached to the system.
--
vgui.Register( "ContextMenu", PANEL, "EditablePanel" )

-- ---------------------------------------------------------------------------
-- Creation (GMod: CreateContextMenu, called from CreateSpawnMenu; DELTA(3):
-- called lazily from Open() and from the contextmenu_reload command here)
-- ---------------------------------------------------------------------------
function CreateContextMenu()

	if ( !hook.Run( "ContextMenuEnabled" ) ) then return end

	if ( IsValid( g_ContextMenu ) ) then
		g_ContextMenu:Remove()
		g_ContextMenu = nil
	end

	g_ContextMenu = vgui.Create( "ContextMenu" )

	if ( !IsValid( g_ContextMenu ) ) then return end

	g_ContextMenu:SetVisible( false )

	--
	-- We're blocking clicks to the world - but we don't want to
	-- so feed clicks to the proper functions..
	--
	-- DELTA: gui.ScreenToVector is not bound in this fork (the GMod engine has
	-- it, the fork's gui library does not - clicking used to die here with
	-- "attempt to call a nil value (field 'ScreenToVector')" before the click
	-- could reach any child).  The bridge exists so the TOOLGUN can keep
	-- working while the menu is open; with no tools ported there is no
	-- GUIMousePressed consumer, so the vector call is guarded - but the press
	-- itself is LOGGED unconditionally: whether it lands here or on a child is
	-- the difference between "the popup swallowed the click" and "the click
	-- never reached vgui at all".
	g_ContextMenu.OnMousePressed = function( p, code )
		Dbg( "press on menu surface itself (code=" .. tostring( code ) .. ")" )
		if ( gui.ScreenToVector ) then
			hook.Run( "GUIMousePressed", code, gui.ScreenToVector( input.GetCursorPos() ) )
		end
	end
	g_ContextMenu.OnMouseReleased = function( p, code )
		Dbg( "release on menu surface itself (code=" .. tostring( code ) .. ")" )
		if ( gui.ScreenToVector ) then
			hook.Run( "GUIMouseReleased", code, gui.ScreenToVector( input.GetCursorPos() ) )
		end
	end

	hook.Run( "ContextMenuCreated", g_ContextMenu )

	local IconLayout = g_ContextMenu:Add( "DIconLayout" )
	IconLayout:SetBorder( 8 )
	IconLayout:SetSpaceX( 8 )
	IconLayout:SetSpaceY( 8 )
	IconLayout:SetLayoutDir( LEFT )
	if ( IconLayout.SetWorldClicker ) then IconLayout:SetWorldClicker( true ) end -- DELTA(1)
	IconLayout:SetStretchWidth( true )
	IconLayout:SetStretchHeight( false ) -- No infinite re-layouts
	IconLayout:Dock( LEFT )

	g_ContextMenu.DesktopWidgets = IconLayout

	-- This overrides DIconLayout's OnMousePressed (which is inherited from DPanel), but we don't care about that in this case
	IconLayout.OnMousePressed = function( s, ... ) s:GetParent():OnMousePressed( ... ) end

	for k, wdgt in pairs( list.Get( "DesktopWindows" ) ) do

		local icon = IconLayout:Add( "DButton" )
		icon:SetText( "" )
		icon:SetSize( 80, 82 )
		icon.Paint = nil
		icon.WidgetClass = k

		local image = icon:Add( "DImage" )
		image:SetImage( wdgt.icon )
		image:SetSize( 64, 64 )
		image:Dock( TOP )
		image:DockMargin( 8, 0, 8, 0 )

		local label = icon:Add( "DLabel" )
		label:Dock( BOTTOM )
		label:SetText( wdgt.title )
		label:SetContentAlignment( 5 )
		label:SetTextColor( color_white )
		label:SetExpensiveShadow( 1, Color( 0, 0, 0, 200 ) )

		icon.DoClick = function()

			Dbg( "DoClick: " .. tostring( k ) )

			-- Changing parents causes loss of input and I don't have time to figure out why
			if ( IsValid( icon.Window ) && icon.Window:GetParent() != g_ContextMenu ) then
				icon.Window:Remove()
			end

			-- wdgt might have changed using autorefresh, so grab it again
			local newWdgt = list.GetEntry( "DesktopWindows", k )

			if ( newWdgt.onewindow and IsValid( icon.Window ) ) then
				icon.Window:Center()
				EnableInputTree( icon.Window )
				Dbg( "DoClick: onewindow re-center " .. tostring( k ) )
				return
			end

			-- Make the window
			icon.Window = g_ContextMenu:Add( "DFrame" )
			icon.Window:SetSize( newWdgt.width, newWdgt.height )
			icon.Window:SetTitle( newWdgt.title )
			icon.Window:Center()

			newWdgt.init( icon, icon.Window )

			-- DELTA: the init just built the window's whole subtree; GMod's
			-- popup chain routes input to it automatically, this fork does not.
			EnableInputTree( icon.Window )

			Dbg( "DoClick: window built + init for " .. tostring( k ) )

		end

		-- DELTA debug: hover + press + release probes, chained so derma's own
		-- behaviour (DButton sets these on its class table) still runs.
		local prevEnter = icon.OnCursorEntered
		icon.OnCursorEntered = function( s )
			Dbg( "hover: " .. tostring( k ) )
			if ( prevEnter ) then prevEnter( s ) end
		end
		local prevPress = icon.OnMousePressed
		icon.OnMousePressed = function( s, code )
			Dbg( "press: " .. tostring( k ) .. " code=" .. tostring( code ) )
			if ( prevPress ) then return prevPress( s, code ) end
		end
		local prevRel = icon.OnMouseReleased
		icon.OnMouseReleased = function( s, code )
			Dbg( "release: " .. tostring( k ) .. " code=" .. tostring( code ) )
			if ( prevRel ) then return prevRel( s, code ) end
		end
		local prevLost = icon.OnMouseCaptureLost
		icon.OnMouseCaptureLost = function( s )
			Dbg( "capture-lost: " .. tostring( k ) )
			if ( prevLost ) then return prevLost( s ) end
		end

	end

	EnableInputTree( g_ContextMenu ) -- icon row + label/image children, fork input-tree quirk

end

-- ---------------------------------------------------------------------------
-- Open / Close (GMod: GM:OnContextMenuOpen / GM:OnContextMenuClose, verbatim
-- bodies; registered as hook listeners instead of gamemode methods to match
-- the fork's Q-menu port pattern.  The veto defaults (ContextMenuEnabled /
-- ContextMenuOpen returning true) are gamemode methods on the fork's sandbox,
-- exactly like GMod's sandbox cl_spawnmenu.lua - under gamemodes without them
-- the C menu is never created, same as GMod.)
-- ---------------------------------------------------------------------------
local contextMenuLastOpen = 0

local function Open()

	Dbg( "OnContextMenuOpen received" )

	-- Already open (toggle)
	if ( spawnmenu_toggle:GetBool() && g_ContextMenu and g_ContextMenu:IsVisible() ) then
		Dbg( "toggle on + already visible -> ignore press" )
		return
	end
	contextMenuLastOpen = SysTime()

	-- Let the gamemode decide whether we should open or not..
	if ( !hook.Run( "ContextMenuOpen" ) ) then
		Dbg( "vetoed by ContextMenuOpen (not sandbox? gamemode method missing)" )
		return
	end

	if ( !IsValid( g_ContextMenu ) ) then
		CreateContextMenu()
	end

	if ( IsValid( g_ContextMenu ) && !g_ContextMenu:IsVisible() ) then
		g_ContextMenu:Open()
		menubar.ParentTo( g_ContextMenu )
		EnableInputTree( g_ContextMenu ) -- the just-adopted menubar strip was not in the tree yet
		local w, h = g_ContextMenu:GetSize()
		Dbg( string.format( "opened: vis=%s size=%dx%d popup=%s",
			tostring( g_ContextMenu:IsVisible() ), w, h,
			tostring( g_ContextMenu.IsPopup and g_ContextMenu:IsPopup() ) ) )
	end

	hook.Run( "ContextMenuOpened" )

end

local function Close()

	if ( spawnmenu_toggle:GetBool() && SysTime() - contextMenuLastOpen < 0.180 ) then
		Dbg( "toggle-on release within 0.180s -> keep open" )
		return
	end

	if ( IsValid( g_ContextMenu ) ) then g_ContextMenu:Close() end
	hook.Run( "ContextMenuClosed" )

end

--
-- Game-side probe: prints the live context-menu panel tree with absolute
-- positions, sizes, visibility and mouse-input flags, plus which panel the
-- engine reports under the cursor.  Run with the menu open to see whether the
-- Player Model button has a non-zero rect under the mouse.
--
if ( concommand and concommand.Create ) then
	concommand.Create( "hl2sb_ctxdump", function()

		if ( !IsValid( g_ContextMenu ) ) then
			print( "[ctx] g_ContextMenu not built" )
			return
		end

		local function dump( p, depth )
			if ( !IsValid( p ) ) then return end
			local x, y = p:GetPos()
			local w, h = p:GetSize()
			local ax, ay = 0, 0
			if ( p.GetAbsPos ) then ax, ay = p:GetAbsPos() end
			local line = string.rep( "  ", depth )
			line = line .. ( p.GetClassName and p:GetClassName() or "?" )
			line = line .. string.format( " pos=%d,%d abs=%d,%d size=%dx%d vis=%s mouse=%s",
				x, y, ax, ay, w, h,
				tostring( p.IsVisible and p:IsVisible() ),
				tostring( p.IsMouseInputEnabled and p:IsMouseInputEnabled() ) )
			if ( p.WidgetClass ) then line = line .. " widget=" .. p.WidgetClass end
			print( line )
			if ( p.GetChildren ) then
				for _, ch in pairs( p:GetChildren() ) do dump( ch, depth + 1 ) end
			end
		end

		dump( g_ContextMenu, 0 )

		if ( gui and gui.GetCurrentFocus ) then
			print( "[ctx] focus=" .. tostring( gui.GetCurrentFocus() ) )
		end
		if ( input and input.GetCursorPos ) then
			local mx, my = input.GetCursorPos()
			print( "[ctx] cursor at " .. tostring( mx ) .. "," .. tostring( my ) )
		end

	end, "Dump the live context-menu panel tree" )
end

if ( hook and hook.Add ) then
	hook.Add( "OnContextMenuOpen", "hl2sb_contextmenu_open", Open )
	hook.Add( "OnContextMenuClose", "hl2sb_contextmenu_close", Close )
end

if ( concommand and concommand.Create ) then
	concommand.Create( "contextmenu_reload", function() CreateContextMenu() end, "Rebuilds the context menu." )
end

Msg( "[HL2SB] context menu loaded (C = +menu_context)\n" )
