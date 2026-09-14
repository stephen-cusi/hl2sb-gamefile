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

	-- close the previously-open menus first (GMod behaviour)
	CloseDermaMenus()
	RegisterDermaMenuForClose( menu )

	menu:Open()
	return menu
end

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
	panel.  We have no blur RT path here, so this draws a dimming overlay instead
	(the visual intent - focus the dialog - holds; the blur is a documented gap).
-----------------------------------------------------------------------------]]
function Derma_DrawBackgroundBlur( panel, startTime )
	if ( IsValid( panel.m_hBlurPanel ) ) then return end

	local overlay = vgui.Create( "DPanel" )
	overlay:SetSize( ScrW(), ScrH() )
	overlay:SetPos( 0, 0 )
	overlay:SetMouseInputEnabled( false )
	overlay.Paint = function( self, w, h )
		surface.SetDrawColor( 0, 0, 0, 180 )
		surface.DrawRect( 0, 0, w, h )
	end
	if ( IsValid( panel ) ) then panel.m_hBlurPanel = overlay end
end

--[[---------------------------------------------------------------------------
	Derma_Anim - the tiny animation helper GMod's skins use for fades.
	Anim:Run() advances and calls func( anim, key, data, progress ).
-----------------------------------------------------------------------------]]
local DermaAnimation = {}
DermaAnimation.__index = DermaAnimation

function DermaAnimation:SetData( data ) self.Data = data end
function DermaAnimation:Start( length, data )
	self.Length = length or 1
	self.Start = CurTime()
	self.Finished = false
	self:SetData( data )
end
function DermaAnimation:Stop() self.Finished = true end
function DermaAnimation:Active() return self.Finished == false end
function DermaAnimation:Run()
	if ( not self:Active() ) then return end
	local elapsed = CurTime() - self.Start
	local progress = ( CurTime() - self.Start ) / math.max( 0.0001, self.Length )
	if ( progress < 0 ) then progress = 0 elseif ( progress > 1 ) then progress = 1 end
	self.CallFunc( self, self.Name, self.Panel, progress, self.Data )
	if ( progress >= 1 ) then self.Finished = true end
end

function Derma_Anim( strName, panel, func )
	local anim = setmetatable( {}, DermaAnimation )
	anim.Name = strName
	anim.Panel = panel
	anim.CallFunc = func
	anim.Finished = false
	return anim
end

print( "[HL2SB] derma helpers loaded (menus/modals/anim/skinhook)" )
