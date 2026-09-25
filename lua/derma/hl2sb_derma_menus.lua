--[[--========================================================
	HL2SB Derma helper globals: menus, modal dialogs, skin hooks, animation.

	These are the small global helpers GMod's lua/derma provides that our fork's
	derma framework (hl2sb_derma.lua / hl2sb_skin.lua) did not have, so addons
	(and our own dragdrop.lua / properties.lua / presets.lua) that call them hit
	"attempt to call a nil value (global 'DermaMenu')".

	Implemented from scratch against the GMod wiki surface, on top of OUR controls
	(DMenu / DFrame / DButton / DLabel / DTextEntry), NOT copied from GMod's lua.

	Provided (client realm - all of these create visible panels):
		Derma_Hook( panel, functionname, hookname, typename )
		DermaMenu( parentmenu, parent ) -> DMenu   (opened at the cursor)
		RegisterDermaMenuForClose( dmenu )
		CloseDermaMenus()
		Derma_Message( text, title, buttonText )
		Derma_Query( text, title, label1, fn1, label2, fn2, ... )
		Derma_StringRequest( title, text, default, onOkay, onCancel, okText, cancelText )
		Derma_DrawBackgroundBlur( panel, startTime )   (darkening overlay; no RT blur)
		Derma_Anim( name, panel, func ) -> DermaAnimation
------------------------------------------------------------]]--

--[[---------------------------------------------------------------------------
	Derma_Hook - route a panel method through the skin's SkinHook.
	Matches the wiki: Derma_Hook( panel, functionname, hookname, typename ).
-----------------------------------------------------------------------------]]
function Derma_Hook( panel, functionname, hookname, typename )
	panel[ functionname ] = function( self, a, b, c, d )
		return derma.SkinHook( hookname, typename, self, a, b, c, d )
	end
end

--[[---------------------------------------------------------------------------
	Derma menus.  GMod tracks every open DMenu so opening a new one closes the
	others; we keep a small registry.  DermaMenu() returns a menu already open at
	the mouse cursor (that is how dragdrop.lua / properties.lua use it).
-----------------------------------------------------------------------------]]
local g_tDermaMenus = {}

function RegisterDermaMenuForClose( dmenu )
	if ( not IsValid( dmenu ) ) then return end
	table.insert( g_tDermaMenus, dmenu )
end

local function CloseMenu( m )
	if ( not IsValid( m ) ) then return end
	if ( m.Close ) then m:Close()
	elseif ( m.Delete ) then m:Delete()
	else m:SetVisible( false ) end
end

function CloseDermaMenus()
	for i = #g_tDermaMenus, 1, -1 do
		CloseMenu( g_tDermaMenus[ i ] )
		table.remove( g_tDermaMenus, i )
	end
end

function DermaMenu( parentmenu, parent )
	local menu = vgui.Create( "DMenu", parent )
	if ( not menu ) then return end

	-- GMod closes the open menus only when this is a ROOT menu; a submenu must
	-- not kill its own parent chain (gmod/derma/derma_menus.lua:12).
	if ( not parentmenu ) then
		CloseDermaMenus()
	end
	RegisterDermaMenuForClose( menu )

	-- Fork delta vs GMod: GMod returns an UNOPENED menu for the caller to
	-- position, but three in-tree callers (dragdrop.lua:49, DTab, DColorCube)
	-- rely on the menu appearing on its own, so the auto-open stays.
	menu:Open()
	return menu
end

--[[---------------------------------------------------------------------------
	Click-away plumbing.  GMod's engine raises the gamemode hook
	VGUIMousePressed( panel, mousecode ), and lua/derma/derma_menus.lua's
	DermaDetectMenuFocus closes every registered menu when the press landed
	outside a menu; lua/vgui/dtextentry.lua's TextEntryLoseFocus drops the
	keyboard the same way.  This engine has no such dispatch, so the same two
	rules run off an input poll: on the press EDGE (not while held), walk the
	hovered panel's parent chain -- no menu ancestor closes the menus, no text
	entry ancestor surrenders keyboard focus.
-----------------------------------------------------------------------------]]
local bWasMouseDown = false

hook.Add( "Think", "HL2SB_DermaClickAway", function()
	local ml = input.IsMouseDown( MOUSE_LEFT )
	local mr = input.IsMouseDown( MOUSE_RIGHT )
	local down = ml or mr

	if ( down and not bWasMouseDown and vgui.GetHoveredPanel ~= nil ) then
		local hovered = vgui.GetHoveredPanel()

		-- GMod's VGUIMousePressed only fires when the press landed on VGUI; a
		-- pure gameplay click (no panel under the cursor) must not touch the
		-- keyboard focus of whatever engine panel may hold it.
		if ( IsValid( hovered ) ) then
			local inMenu = false
			local focused = ( vgui.GetKeyboardFocus ~= nil ) and vgui.GetKeyboardFocus() or nil
			local inFocused = false

			local pnl = hovered
			while ( IsValid( pnl ) ) do
				if ( pnl.m_bIsMenu ) then inMenu = true end
				if ( focused ~= nil and pnl == focused ) then inFocused = true end
				pnl = ( pnl.GetParent ~= nil ) and pnl:GetParent() or nil
			end

			if ( not inMenu and CloseDermaMenus ~= nil ) then
				CloseDermaMenus()
			end

			-- a text entry keeps the keyboard only while the press is inside it
			if ( focused ~= nil and not inFocused and focused.KillFocus ~= nil ) then
				focused:KillFocus()
			end
		end
	end

	bWasMouseDown = down
end )

--[[---------------------------------------------------------------------------
	Shared modal-frame builder for the dialog helpers.  A DFrame centred on
	screen, no title bar buttons beyond close, non-sizable, that removes itself
	on close.  Returns the frame and a content host panel to lay children in.
-----------------------------------------------------------------------------]]
local function NewModalFrame( strTitle, w, h )
	local frame = vgui.Create( "DFrame" )
	frame:SetTitle( strTitle or "" )
	frame:SetVisible( true )
	frame:SetDraggable( false )
	frame:ShowCloseButton( true )
	frame:SetDeleteOnClose( true )
	frame:SetSizable( false )
	frame:SetSize( w, h )
	frame:MakePopup()

	local sw, sh = ScrW(), ScrH()
	frame:SetPos( math.floor( ( sw - w ) / 2 ), math.floor( ( sh - h ) / 2 ) )

	return frame
end

-- a full-width DButton row; DoClick is our DButton's click callback.
local function ModalButton( parent, strLabel, fn )
	local btn = vgui.Create( "DButton", parent )
	btn:SetText( strLabel or "" )
	btn.DoClick = fn
	return btn
end

--[[---------------------------------------------------------------------------
	Derma_Message - a single OK button.
-----------------------------------------------------------------------------]]
function Derma_Message( strText, strTitle, strButtonText )
	local frame = NewModalFrame( strTitle, 400, 140 )

	local label = vgui.Create( "DLabel", frame )
	label:SetText( strText or "" )
	label:SetPos( 10, 30 )
	label:SetSize( 380, 60 )
	label:SetWrap( true )

	local btn = ModalButton( frame, strButtonText or "#Close", function()
		frame:Close()
	end )
	btn:SetPos( 150, 100 )
	btn:SetSize( 100, 26 )
	frame:MakePopup()
	return frame
end

--[[---------------------------------------------------------------------------
	Derma_Query( text, title, label1, fn1, label2, fn2, ... ) - varargs pairs of
	(button label, click function).  Every button closes the frame after running.
-----------------------------------------------------------------------------]]
function Derma_Query( strText, strTitle, ... )
	local options = { ... }
	local n = math.floor( #options / 2 )

	local frame = NewModalFrame( strTitle, 420, 90 + n * 30 )

	local label = vgui.Create( "DLabel", frame )
	label:SetText( strText or "" )
	label:SetPos( 10, 30 )
	label:SetSize( 400, 40 )
	label:SetWrap( true )

	for i = 1, n do
		local strLabel = options[ i * 2 - 1 ]
		local fn = options[ i * 2 ]
		local btn = ModalButton( frame, strLabel, function()
			frame:Close()
			if ( isfunction( fn ) ) then fn() end
		end )
		btn:SetPos( 10, 70 + ( i - 1 ) * 30 )
		btn:SetSize( 400, 26 )
	end

	frame:MakePopup()
	return frame
end

--[[---------------------------------------------------------------------------
	Derma_StringRequest( title, text, default, onOkay, onCancel, okText, cancelText )
-----------------------------------------------------------------------------]]
function Derma_StringRequest( strTitle, strText, strDefault, fnEnter, fnCancel, strOK, strCancel )
	local frame = NewModalFrame( strTitle, 420, 150 )

	if ( strText and strText != "" ) then
		local desc = vgui.Create( "DLabel", frame )
		desc:SetText( strText )
		desc:SetPos( 10, 28 )
		desc:SetSize( 400, 16 )
	end

	local entry = vgui.Create( "DTextEntry", frame )
	entry:SetPos( 10, 50 )
	entry:SetSize( 400, 24 )
	entry:SetText( strDefault or "" )

	local function Finish( bOK )
		local val = entry:GetValue()
		frame:Close()
		if ( bOK ) then
			if ( isfunction( fnEnter ) ) then fnEnter( val ) end
		else
			if ( isfunction( fnCancel ) ) then fnCancel() end
		end
	end

	entry.OnEnter = function() Finish( true ) end

	local ok = ModalButton( frame, strOK or "#OKAY", function() Finish( true ) end )
	ok:SetPos( 210, 90 ); ok:SetSize( 100, 26 )

	local cancel = ModalButton( frame, strCancel or "#CANCEL", function() Finish( false ) end )
	cancel:SetPos( 310, 90 ); cancel:SetSize( 100, 26 )

	frame:MakePopup()
	if ( entry.RequestFocus ) then entry:RequestFocus() end
	return frame
end

--[[---------------------------------------------------------------------------
	Derma_DrawBackgroundBlur - GMod renders a blurred render-target behind the
	panel.  We have no blur RT path here, and the previous implementation created
	a new fullscreen panel ON EVERY CALL that was never removed -- a per-frame
	panel leak plus a permanent dim once called.  GMod's own helper is called
	from Paint every frame (gmod/derma/derma_utils.lua:12-42), so this now only
	DRAWS the dim: no panels, nothing to leak.  DFrame:SetBackgroundBlur drives
	it through the frame's Paint.
-----------------------------------------------------------------------------]]
function Derma_DrawBackgroundBlur( panel, startTime )
	surface.DrawSetColor( 0, 0, 0, 180 )
	surface.DrawFilledRect( 0, 0, ScrW(), ScrH() )
end

--[[---------------------------------------------------------------------------
	Derma_Anim - the tiny animation helper GMod's skins use for fades.

	GMod's contract (gmod/derma/derma_animation.lua) is func( panel, anim,
	delta, data ) with the panel FIRST -- a method like
	`PANEL:AnimSlide( anim, delta, data )` binds self to the panel.  The
	previous call here passed ( anim, name, panel, progress, data ), which made
	DTree_Node's AnimSlide run with self = the animation TABLE and anim = the
	NAME STRING -- node expansion died on "attempt to index a string value".

	Like GMod, an anim is inert until Start() (Running), and Run() ticks it;
	Active() answers Running.  The old Finished-at-creation made Active() true
	and Run() crash on "Start == nil" for every anim that was never started.
-----------------------------------------------------------------------------]]
local DermaAnimation = {}
DermaAnimation.__index = DermaAnimation

function DermaAnimation:SetData( data ) self.Data = data end
function DermaAnimation:Start( length, data )
	self.Length = length or 1
	self.Start = SysTime()
	self.Running = true
	self:SetData( data )
end
function DermaAnimation:Stop() self.Running = false end
function DermaAnimation:Active() return self.Running == true end
function DermaAnimation:Run()
	if ( not self.Running ) then return end

	local elapsed = SysTime() - ( self.Start or 0 )
	local progress = elapsed / math.max( 0.0001, self.Length or 1 )
	if ( progress < 0 ) then progress = 0 elseif ( progress > 1 ) then progress = 1 end

	-- GMod's callback order: panel, anim, delta, data.
	self.CallFunc( self.Panel, self, progress, self.Data )
	if ( progress >= 1 ) then self.Running = false end
end

function Derma_Anim( strName, panel, func )
	local anim = setmetatable( {}, DermaAnimation )
	anim.Name = strName
	anim.Panel = panel
	anim.CallFunc = func
	anim.Running = false
	return anim
end

print( "[HL2SB] derma helpers loaded (menus/modals/anim/skinhook)" )
