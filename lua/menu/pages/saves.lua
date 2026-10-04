--[[----------------------------------------------------------------------------
    lua/menu/pages/saves.lua  --  saves page: gm_save / gm_load from the menu.

    Lists data/hl2sb_saves/*.txt (the gm_save output).  Load and Save go
    through HL2SB_MenuConsoleCommand, which hands a sanitized command line to
    the engine console - the serialisation itself runs server-side in
    gamemodes/deathmatch/gamemode/save_load.lua, this page only drives it.
    Delete is a plain data/ file delete done right here.

    Layout per spec: Dock only (list FILL, bar BOTTOM), MENU.Layout() at the end.
--]]----------------------------------------------------------------------------

if ( not _GAMEUI or MENU == nil ) then return end

if ( file == nil or file.Find == nil ) then
    MENU.Register( { name = "存档", build = function( parent )
        local lbl = vgui.Create( "Label", parent )
        if ( lbl ~= nil ) then
            lbl:Dock( 1 )
            lbl:SetTall( 22 )
            lbl:SetText( "这个 realm 里没有 file 库，存档列表不可用。" )
            MENU.UseFont( lbl )
        end
    end } )

    return
end

local SAVE_DIR = "hl2sb_saves"

local function ListSaves()
    local out = {}

    for _, name in ipairs( file.Find( SAVE_DIR .. "/*.txt", "DATA" ) or {} ) do
        out[ #out + 1 ] = string.gsub( name, "%.txt$", "" )
    end

    table.sort( out )
    return out
end

MENU.Register( {
    name = "存档",

    build = function( parent )
        local names = ListSaves()

        local list = vgui.Panel( parent, "hl2sb_menu_savelist" )
        list:Dock( 5 )   -- DOCK_FILL

        local status = vgui.Create( "Label", parent )
        if ( status ~= nil ) then
            status:Dock( 3 )
            status:SetTall( 20 )
            status:SetText( #names .. " 个存档（data/" .. SAVE_DIR .. "/）。读取/保存要进图后才有意义。" )
            MENU.UseFont( status )
        end

        local bar = vgui.Panel( parent, "hl2sb_menu_savebar" )
        bar:Dock( 3 )
        bar:SetTall( 30 )

        local entry = vgui.TextEntry( bar, "hl2sb_savename" )
        if ( entry ~= nil ) then
            entry:Dock( 5 )   -- DOCK_FILL
            entry:SetTall( 24 )
            entry:SetText( "" )
            MENU.UseFont( entry )
        end

        local function BarButton( text, cmd, wide )
            local btn = vgui.Button( bar, "hl2sb_save_" .. cmd, text, parent, cmd )
            if ( btn ~= nil ) then
                btn:Dock( 2 )    -- DOCK_RIGHT
                btn:SetWide( wide or 90 )
                btn:SetTall( 26 )
                MENU.UseFont( btn )
            end
        end

        BarButton( "关闭", "close", 80 )
        BarButton( "保存当前地图", "save", 120 )

        for i, name in ipairs( names ) do
            local row = vgui.Panel( list, "hl2sb_saverow_" .. i )
            if ( row == nil ) then break end
            row:Dock( 1 )    -- DOCK_TOP
            row:SetTall( 26 )

            local lbl = vgui.Create( "Label", row )
            if ( lbl ~= nil ) then
                lbl:Dock( 5 )
                lbl:SetText( name )
                MENU.UseFont( lbl )
            end

            local function RowButton( text, cmd, wide )
                local btn = vgui.Button( row, "hl2sb_saverow_" .. i .. cmd, text, row, cmd )
                if ( btn ~= nil ) then
                    btn:Dock( 2 )    -- DOCK_RIGHT
                    btn:SetWide( wide or 70 )
                    MENU.UseFont( btn )
                end
            end

            RowButton( "删除", "delete", 70 )
            RowButton( "读取", "load", 70 )

            row.OnCommand = function( self, cmd )
                if ( cmd == "load" ) then
                    if ( HL2SB_MenuConsoleCommand ~= nil ) then
                        HL2SB_MenuConsoleCommand( "gm_load " .. name )
                    end
                    if ( status ~= nil ) then
                        status:SetText( "已发送读取命令: " .. name )
                    end
                elseif ( cmd == "delete" ) then
                    file.Delete( SAVE_DIR .. "/" .. name .. ".txt", "DATA" )
                    row:SetVisible( false )
                    if ( status ~= nil ) then
                        status:SetText( "已删除: " .. name )
                    end
                end
            end
        end

        if ( #names == 0 ) then
            local lbl = vgui.Create( "Label", list )
            if ( lbl ~= nil ) then
                lbl:Dock( 1 )
                lbl:SetTall( 22 )
                lbl:SetText( "还没有存档。进图后控制台 gm_save（可带名字）即可写入。" )
                MENU.UseFont( lbl )
            end
        end

        parent.OnCommand = function( self, cmd )
            if ( type( self ) == "string" ) then cmd = self end

            if ( cmd == "close" ) then
                if ( MENU.Frame ~= nil and MENU.Frame.Close ~= nil ) then MENU.Frame:Close() end
                MENU.Frame = nil
            elseif ( cmd == "save" ) then
                if ( HL2SB_MenuConsoleCommand ~= nil ) then
                    local typed = ( entry ~= nil and entry.GetText ~= nil ) and entry:GetText() or ""
                    if ( typed ~= nil and typed ~= "" ) then
                        HL2SB_MenuConsoleCommand( "gm_save " .. typed )
                    else
                        HL2SB_MenuConsoleCommand( "gm_save" )
                    end
                end
                if ( status ~= nil ) then
                    status:SetText( "已发送保存命令（完成后重开本页可见）。" )
                end
            end

            if ( MENU.Frame ~= nil ) then
                MENU.Layout( MENU.Frame )
            end
        end

        MENU.Layout( parent )
    end
} )
