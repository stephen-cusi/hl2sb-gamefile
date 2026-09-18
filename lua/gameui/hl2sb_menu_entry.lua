--[[----------------------------------------------------------------------------
    lua/gameui/hl2sb_menu_entry.lua

    The menu realm loads lua/gameui/* by folder scan (luamanager.cpp -> the main-menu Lua
    state), so this is the one file that has to live there: it pulls in the canonical menu
    (lua/menu/menu.lua, see lua/docs/menu_spec.md) and points the GameUI's own menu entries
    at it.

    include() resolves caller-relative first and then falls back to the lua root, so the
    root-relative name below is the form that works from here (see spec rule 5: never use
    "../" - it is not understood and produced "lua\gameuiincludes/...").
--]]----------------------------------------------------------------------------

include( "menu/menu.lua" )

-- ⚠️ TEMPORARY: the new menu does NOT take over the GameUI's own entries yet.  On
-- 2026-09-18 the first cut showed only the "错误" page registered (the page includes below
-- did not all land) and quitting the game raised an error, so pointing "内容 / 插件" at it
-- made the existing windows worse.  Until the pages verify, the new menu is reachable only
-- through its own command; the GameUI entries keep using the old dialog.
--
-- To switch over (after the pages verify): uncomment the two lines below.
--
-- if ( MENU ~= nil and MENU.Open ~= nil and concommand ~= nil and concommand.Create ~= nil ) then
--     concommand.Create( "OpenContentDialog", MENU.Open, "Open the HL2SB menu.", FCVAR_CLIENTDLL )
--     concommand.Create( "OpenAddonsDialog",  MENU.Open, "Open the HL2SB menu.", FCVAR_CLIENTDLL )
-- end

