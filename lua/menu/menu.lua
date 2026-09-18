--[[----------------------------------------------------------------------------
    lua/menu/menu.lua  --  HL2SB main-menu entry point (canonical form).

    Spec: lua/docs/menu_spec.md.  Rules this file exists to enforce:

      * the menu realm is a hand-opened lua_State with NO frame loop, so nothing here
        positions a control by absolute coordinates - Dock only (rule 2);
      * every page is built, then MENU.Layout() runs the engine pass
        HL2SB_MenuLayout() (game/client/lua/lua_gameui_menu.cpp) - immediately and again
        on the next frame (rule 3/4);
      * includes, when a page needs them, are ROOT-relative: include() does not resolve
        "../" (rule 5).  This file needs none: the engine already loaded table/vgui/
        panel/gmod_globals/hook/concommand for this realm (luamanager.cpp menuFiles[]).

    A page is a plain table:   { name = "内容", build = function( parent ) ... end }
    and is registered with MENU.Register( page ).  No page opens a window itself.
--]]----------------------------------------------------------------------------

if ( not _GAMEUI or vgui == nil ) then return end

MENU = MENU or {}
MENU.Pages = MENU.Pages or {}
MENU.Frame = MENU.Frame or nil
MENU.Font = MENU.Font or "HL2SB_MenuFont"
MENU.Errors = MENU.Errors or {}

if ( surface ~= nil and surface.CreateFont ~= nil ) then
    surface.CreateFont( MENU.Font, { font = "Microsoft YaHei", size = 15, weight = 500, extended = true } )
end

--- Engine-side layout pass for this realm (spec rule 3/4).  Doing this from Lua alone
--- (InvalidateLayout) was measured NOT to work here; the engine function re-applies every
--- panel's recorded x/y/w/h with the native setters and then runs PerformLayout().
function MENU.Layout( root )
    if ( root == nil ) then return end

    if ( HL2SB_MenuLayout ) then
        HL2SB_MenuLayout( root )
    end

    if ( timer and timer.Simple ) then
        timer.Simple( 0, function()
            if ( root ~= nil and HL2SB_MenuLayout ) then
                HL2SB_MenuLayout( root )
            end
        end )
    end
end

--- Apply the menu font to a control (the scheme's font is not reliable in this realm).
function MENU.UseFont( panel )
    if ( panel ~= nil and panel.SetFont ~= nil ) then
        panel:SetFont( MENU.Font )
    end
    return panel
end

function MENU.Register( page )
    if ( type( page ) ~= "table" or type( page.build ) ~= "function" ) then return end

    MENU.Pages[ #MENU.Pages + 1 ] = page
end

-- ---------------------------------------------------------------------------
-- the window
-- ---------------------------------------------------------------------------

local function ClearParent( pnl )
    if ( pnl == nil ) then return end

    if ( pnl.GetChildren ~= nil ) then
        for _, child in ipairs( pnl:GetChildren() or {} ) do
            if ( child.Remove ~= nil ) then child:Remove() end
        end
    end
end

function MENU.Open()
    if ( MENU.Frame ~= nil and MENU.Frame.SetVisible ~= nil ) then
        MENU.Frame:SetVisible( true )
        if ( MENU.Frame.Activate ) then MENU.Frame:Activate() end
        MENU.Layout( MENU.Frame )
        return MENU.Frame
    end

    local parent = VGui_GetGameUIPanel and VGui_GetGameUIPanel() or nil
    local frame = vgui.Frame( parent, "HL2SBMenu", true )
    if ( frame == nil ) then return nil end

    frame:SetTitle( "HL2SB" )
    frame:SetSize( 640, 480 )
    frame:MoveToCenterOfScreen()
    if ( frame.SetSizeable ) then frame:SetSizeable( false ) end

    -- left column: one button per registered page; right: the page's own panel.
    local side = vgui.Panel( frame, "HL2SBMenuSide" )
    side:Dock( 2 )            -- DOCK_LEFT
    side:SetWide( 120 )

    local body = vgui.Panel( frame, "HL2SBMenuBody" )
    body:Dock( 5 )            -- DOCK_FILL

    local current = nil

    local function Show( page )
        ClearParent( body )
        current = page

        local ok, err = pcall( page.build, body )
        if ( not ok ) then
            MENU.Errors[ #MENU.Errors + 1 ] = tostring( err )
            Msg( "[HL2SB] menu page '" .. tostring( page.name ) .. "' failed: " .. tostring( err ) .. "\n" )
        end

        MENU.Layout( frame )
    end

    for _, page in ipairs( MENU.Pages ) do
        local btn = vgui.Button( side, "hl2sb_menu_" .. tostring( page.name ), tostring( page.name ), frame, "page" )
        if ( btn ~= nil ) then
            btn:Dock( 1 )     -- DOCK_TOP
            btn:SetTall( 28 )
            MENU.UseFont( btn )
        end
    end

    -- the side buttons route through OnCommand like the legacy dialogs did.
    frame.OnCommand = function( self, cmd, data )
        if ( type( self ) == "string" ) then cmd = self end
        if ( cmd ~= "page" ) then return end

        -- find the page by matching the clicked control's text
        for _, page in ipairs( MENU.Pages ) do
            if ( tostring( page.name ) == tostring( data ) ) then
                Show( page )
                return
            end
        end

        if ( #MENU.Pages > 0 ) then Show( MENU.Pages[ 1 ] ) end
    end

    MENU.Frame = frame

    if ( frame.SetVisible ) then frame:SetVisible( true ) end
    if ( frame.Activate ) then frame:Activate() end

    if ( #MENU.Pages > 0 ) then
        Show( MENU.Pages[ 1 ] )
    end

    MENU.Layout( frame )
    return frame
end

concommand.Create( "OpenHL2SBMenu", MENU.Open, "Open the HL2SB main menu.", FCVAR_CLIENTDLL )
concommand.Create( "hl2sb_menu", MENU.Open, "Alias of OpenHL2SBMenu.", FCVAR_CLIENTDLL )

-- ---------------------------------------------------------------------------
-- pages shipped with the menu (each file registers itself)
-- ---------------------------------------------------------------------------
include( "menu/pages/_errors.lua" )
include( "menu/pages/addons.lua" )
include( "menu/pages/content.lua" )
