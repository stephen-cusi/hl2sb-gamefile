--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: 
--
--===========================================================================--

-- HL2SB: root-relative, NOT "../includes/...".  The engine's include() resolves relative to
-- the calling file first, then falls back to the lua root, but it does NOT understand "../":
-- the candidate came out as   hl2sb\lua\gameuiincludes/extensions/panel.lua
-- (caller dir + path, no separator) and the file never loaded - which is why the menu
-- dialogs (Content / Addons) were missing table.merge / vgui.register / ToPanel.
include( "includes/extensions/panel.lua" )

local FCVAR_CLIENTDLL = _E.FCVAR.CLIENTDLL

require( "concommand" )

local hContentDialog = INVALID_PANEL

local function PositionDialog(dlg)
	if ( dlg == INVALID_PANEL ) then
		return;
	end

	local x, y, ww, wt, wide, tall;
	x, y, ww, wt = surface.GetWorkspaceBounds();
	wide, tall = dlg:GetSize();

	-- Center it, keeping requested size
	dlg:SetPos(x + ((ww - wide) / 2), y + ((wt - tall) / 2));
end

local function OnOpenContentDialog()
	if ( ToPanel( hContentDialog ) == INVALID_PANEL ) then
		hContentDialog = vgui.CContentDialog(VGui_GetGameUIPanel(), "ContentDialog");
		PositionDialog( hContentDialog );
	end
	hContentDialog:Activate();

	-- HL2SB: force the vgui layout pass.  In this menu realm nothing drives it: the Addons
	-- dialog's dbg dump showed every control - and even the frame's OWN title bar /
	-- FrameSystemButton - still at pos=(0,0) with the default size, while the sizes we set
	-- had been applied.  SetSize is immediate, SetPos lands in a layout pass, so the Content
	-- dialog (and the Addons one) came up as an overlapping mess.
	--
	-- The real pass is now the ENGINE one: HL2SB_MenuLayout() walks the panel and its whole
	-- subtree and calls InvalidateLayout(true) + PerformLayout() on each (see
	-- game/client/lua/lua_gameui_menu.cpp).  The Lua-side InvalidateLayout( true ) below is
	-- kept as a fallback for a build without it.
	if ( HL2SB_MenuLayout ) then
		HL2SB_MenuLayout( hContentDialog );
	end

	if ( hContentDialog.InvalidateLayout ) then
		hContentDialog:InvalidateLayout( true );
	end

	if ( timer and timer.Simple ) then
		timer.Simple( 0, function()
			if ( HL2SB_MenuLayout ) then
				HL2SB_MenuLayout( hContentDialog );
			end

			if ( hContentDialog ~= nil and hContentDialog.InvalidateLayout ) then
				hContentDialog:InvalidateLayout( true );
			end
		end );
	end
end

concommand.Create( "OpenContentDialog", OnOpenContentDialog, "Open content dialog.", FCVAR_CLIENTDLL )
