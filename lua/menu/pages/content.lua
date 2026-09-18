--[[----------------------------------------------------------------------------
    lua/menu/pages/content.lua  --  content page: mount sibling Source games.

    Same persistence as the legacy page it replaces (lua/gameui/contentsubgames.lua):
      * detection : global HL2SB_DetectSourceGames()  (lua/autorun/detect_source_games.lua)
      * selection : <gamedir>/gamecontent.txt - one AppId per line, written on 应用,
                    read by the mount loader on the next start.

    Layout per spec: no absolute coordinates - a scrollable list Docked FILL, a bottom bar
    Docked BOTTOM, and MENU.Layout() at the end (the engine pass).
--]]----------------------------------------------------------------------------

if ( not _GAMEUI or MENU == nil ) then return end

local function ReadSelected()
    local selected = {}
    local f = io.open( engine.GetGameDirectory() .. "/gamecontent.txt", "r" )

    if ( f == nil ) then return selected end

    for line in f:lines() do
        local id = tonumber( (line or ""):match( "^%s*(%-?%d+)%s*$" ) )
        if ( id ~= nil ) then selected[ id ] = true end
    end

    f:close()
    return selected
end

local function WriteSelected( ids )
    local f = io.open( engine.GetGameDirectory() .. "/gamecontent.txt", "w" )
    if ( f == nil ) then return false end

    f:write( "# HL2SB: sibling Source games to mount. One AppId per line.\n" )
    for _, id in ipairs( ids ) do f:write( tostring( id ), "\n" ) end
    f:close()

    return true
end

MENU.Register( {
    name = "内容",

    build = function( parent )
        local games = {}
        if ( _G.HL2SB_DetectSourceGames ) then
            games = _G.HL2SB_DetectSourceGames() or {}
        end

        local selected = ReadSelected()
        local checks = {}

        local list = vgui.Panel( parent, "hl2sb_menu_contentlist" )
        list:Dock( 5 )   -- DOCK_FILL

        local status = vgui.Create( "Label", parent )
        if ( status ~= nil ) then
            status:Dock( 3 )   -- DOCK_BOTTOM
            status:SetTall( 20 )
            status:SetText( "" )
            MENU.UseFont( status )
        end

        local bar = vgui.Panel( parent, "hl2sb_menu_contentbar" )
        bar:Dock( 3 )   -- DOCK_BOTTOM
        bar:SetTall( 30 )

        if ( #games == 0 ) then
            local lbl = vgui.Create( "Label", list )
            if ( lbl ~= nil ) then
                lbl:Dock( 1 )
                lbl:SetTall( 22 )
                lbl:SetText( "没有检测到同目录的 Source 游戏。" )
                MENU.UseFont( lbl )
            end
        end

        for i, game in ipairs( games ) do
            local id = tonumber( game.appid or game.appId or game.id or 0 ) or 0
            local title = tostring( game.title or game.name or game.folder or id )
            local folder = tostring( game.folder or "" )

            local cb = vgui.CheckButton( list, "hl2sb_game_" .. i,
                string.format( "%s   (%s, AppId %d)", title, folder, id ) )

            if ( cb ~= nil ) then
                cb:Dock( 1 )   -- DOCK_TOP
                cb:SetTall( 26 )
                cb:SetSelected( selected[ id ] == true )
                MENU.UseFont( cb )
                checks[ #checks + 1 ] = { panel = cb, id = id }
            end
        end

        local apply = vgui.Button( bar, "hl2sb_content_apply", "应用", parent, "apply" )
        if ( apply ~= nil ) then
            apply:Dock( 2 )   -- DOCK_RIGHT
            apply:SetWide( 90 )
            apply:SetTall( 26 )
            MENU.UseFont( apply )
        end

        local close = vgui.Button( bar, "hl2sb_content_close", "关闭", parent, "close" )
        if ( close ~= nil ) then
            close:Dock( 2 )
            close:SetWide( 90 )
            close:SetTall( 26 )
            MENU.UseFont( close )
        end

        parent.OnCommand = function( self, cmd )
            if ( type( self ) == "string" ) then cmd = self end

            if ( cmd == "close" ) then
                if ( MENU.Frame ~= nil and MENU.Frame.Close ~= nil ) then MENU.Frame:Close() end
                MENU.Frame = nil

            elseif ( cmd == "apply" ) then
                local ids = {}

                for _, entry in ipairs( checks ) do
                    if ( entry.panel.IsChecked ~= nil and entry.panel:IsChecked() and entry.id ~= 0 ) then
                        ids[ #ids + 1 ] = entry.id
                    end
                end

                if ( WriteSelected( ids ) ) then
                    if ( status ~= nil ) then status:SetText( "已保存 gamecontent.txt - 下次启动生效。" ) end
                    Msg( "[HL2SB] gamecontent.txt saved (" .. tostring( #ids ) .. " game(s)); restart to apply mounts\n" )
                elseif ( status ~= nil ) then
                    status:SetText( "写 gamecontent.txt 失败。" )
                end

                MENU.Layout( MENU.Frame )
            end
        end

        MENU.Layout( parent )
    end,
} )
