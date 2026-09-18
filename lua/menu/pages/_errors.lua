--[[----------------------------------------------------------------------------
    lua/menu/pages/_errors.lua  --  the menu's own error page (spec: rule 1, page per file).

    Records what the menu realm throws (hook "LuaError" is the hook this realm's hook.lua
    is loaded for - see luamanager.cpp menuFiles[]) and lists it.  Nothing here positions
    by absolute coordinates: Dock only, and the page is laid out by MENU.Layout().
--]]----------------------------------------------------------------------------

if ( not _GAMEUI or MENU == nil ) then return end

MENU.Errors = MENU.Errors or {}

if ( hook ~= nil and hook.Add ~= nil ) then
    hook.Add( "LuaError", "hl2sb_menu_errors", function( err )
        MENU.Errors[ #MENU.Errors + 1 ] = tostring( err )
    end )
end

MENU.Register( {
    name = "错误",

    build = function( parent )
        local list = vgui.Panel( parent, "hl2sb_menu_errorlist" )
        list:Dock( 5 )   -- DOCK_FILL

        local shown = 0

        for i, err in ipairs( MENU.Errors ) do
            if ( shown < 40 ) then
                shown = shown + 1

                local lbl = vgui.Create( "Label", list )
                if ( lbl ~= nil ) then
                    lbl:Dock( 1 )   -- DOCK_TOP
                    lbl:SetTall( 22 )
                    lbl:SetText( "• " .. tostring( err ) )
                    MENU.UseFont( lbl )
                end
            end
        end

        if ( shown == 0 ) then
            local lbl = vgui.Create( "Label", list )
            if ( lbl ~= nil ) then
                lbl:Dock( 1 )
                lbl:SetTall( 22 )
                lbl:SetText( "没有记录到菜单错误。（引擎那份用控制台 hl2sb_errors 看。）" )
                MENU.UseFont( lbl )
            end
        end

        local clear = vgui.Button( parent, "hl2sb_menu_errclear", "清空", parent, "errclear" )
        if ( clear ~= nil ) then
            clear:Dock( 3 )   -- DOCK_BOTTOM
            clear:SetTall( 26 )
            MENU.UseFont( clear )
        end

        parent.OnCommand = function( self, cmd )
            if ( type( self ) == "string" ) then cmd = self end
            if ( cmd == "errclear" ) then
                MENU.Errors = {}
            end
        end
    end,
} )
