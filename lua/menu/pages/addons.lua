--[[----------------------------------------------------------------------------
    lua/menu/pages/addons.lua  --  addons page: enable/disable addons.

    Same persistence as the legacy dialog it replaces (lua/gameui/addonsdialog.lua):
      * list      : file.Find( "addons/*", "MOD" ) - folders and *.gma archives
      * disabled  : <gamedir>/addons_disabled.txt - one lower-cased folder name per line
      * the mount layer is the engine's (HL2SB_LuaRegisterAddons), so nothing here mounts
        anything itself - 应用 only writes the file, and the next start obeys it.

    Layout per spec: Dock only (list FILL, bar BOTTOM), MENU.Layout() at the end.
--]]----------------------------------------------------------------------------

if ( not _GAMEUI or MENU == nil ) then return end

if ( file == nil or file.Find == nil ) then
    MENU.Register( { name = "插件", build = function( parent )
        local lbl = vgui.Create( "Label", parent )
        if ( lbl ~= nil ) then
            lbl:Dock( 1 )
            lbl:SetTall( 22 )
            lbl:SetText( "这个 realm 里没有 file.Find，插件列表不可用。" )
            MENU.UseFont( lbl )
        end
    end } )

    return
end

local function ListAddons()
    local out = {}

    local _, dirs = file.Find( "addons/*", "MOD" )
    for _, name in ipairs( dirs or {} ) do
        if ( name:sub( 1, 1 ) ~= "." ) then
            out[ #out + 1 ] = { name = name, key = name:lower(), isGma = false }
        end
    end

    local files = file.Find( "addons/*.gma", "MOD" )
    for _, name in ipairs( files or {} ) do
        local base = name:gsub( "%.gma$", "" )
        out[ #out + 1 ] = { name = base, key = base:lower(), isGma = true }
    end

    table.sort( out, function( a, b ) return a.key < b.key end )
    return out
end

local function ReadDisabled()
    local set = {}
    local f = io.open( engine.GetGameDirectory() .. "/addons_disabled.txt", "r" )

    if ( f == nil ) then return set end

    for line in f:lines() do
        local name = (line or ""):match( "^%s*([^#%s].*%S)%s*$" )
        if ( name ~= nil ) then set[ name:lower() ] = true end
    end

    f:close()
    return set
end

MENU.Register( {
    name = "插件",

    build = function( parent )
        local addons = ListAddons()
        local disabled = ReadDisabled()
        local checks = {}

        local list = vgui.Panel( parent, "hl2sb_menu_addonlist" )
        list:Dock( 5 )   -- DOCK_FILL

        local status = vgui.Create( "Label", parent )
        if ( status ~= nil ) then
            status:Dock( 3 )
            status:SetTall( 20 )
            status:SetText( "" )
            MENU.UseFont( status )
        end

        local bar = vgui.Panel( parent, "hl2sb_menu_addonbar" )
        bar:Dock( 3 )
        bar:SetTall( 30 )

        for i, entry in ipairs( addons ) do
            local cb = vgui.CheckButton( list, "hl2sb_addon_" .. i,
                entry.name .. ( entry.isGma and "   [GMA]" or "" ) )

            if ( cb ~= nil ) then
                cb:Dock( 1 )
                cb:SetTall( 26 )
                cb:SetSelected( not disabled[ entry.key ] )
                MENU.UseFont( cb )
                checks[ #checks + 1 ] = { panel = cb, key = entry.key }
            end
        end

        if ( #addons == 0 ) then
            local lbl = vgui.Create( "Label", list )
            if ( lbl ~= nil ) then
                lbl:Dock( 1 )
                lbl:SetTall( 22 )
                lbl:SetText( "addons/ 下没有东西。" )
                MENU.UseFont( lbl )
            end
        end

        local function BarButton( text, cmd, wide )
            local btn = vgui.Button( bar, "hl2sb_addon_" .. cmd, text, parent, cmd )
            if ( btn ~= nil ) then
                btn:Dock( 2 )    -- DOCK_RIGHT
                btn:SetWide( wide or 90 )
                btn:SetTall( 26 )
                MENU.UseFont( btn )
            end
        end

        BarButton( "关闭", "close", 80 )
        BarButton( "应用", "apply", 80 )
        BarButton( "全部禁用", "disableall", 100 )
        BarButton( "全部启用", "enableall", 100 )

        parent.OnCommand = function( self, cmd )
            if ( type( self ) == "string" ) then cmd = self end

            if ( cmd == "close" ) then
                if ( MENU.Frame ~= nil and MENU.Frame.Close ~= nil ) then MENU.Frame:Close() end
                MENU.Frame = nil
                return
            end

            if ( cmd == "enableall" or cmd == "disableall" ) then
                local want = ( cmd == "enableall" )
                for _, entry in ipairs( checks ) do
                    if ( entry.panel.SetSelected ~= nil ) then entry.panel:SetSelected( want ) end
                end
                return
            end

            if ( cmd == "apply" ) then
                local out = {}
                for _, entry in ipairs( checks ) do
                    if ( entry.panel.IsChecked ~= nil and not entry.panel:IsChecked() ) then
                        out[ #out + 1 ] = entry.key
                    end
                end

                local f = io.open( engine.GetGameDirectory() .. "/addons_disabled.txt", "w" )
                if ( f == nil ) then
                    if ( status ~= nil ) then status:SetText( "写 addons_disabled.txt 失败。" ) end
                    return
                end

                f:write( "# HL2SB: addons switched off in the main menu. One folder name per line.\n" )
                f:write( "# Changes apply on the next start.\n" )
                for _, key in ipairs( out ) do f:write( key, "\n" ) end
                f:close()

                if ( status ~= nil ) then status:SetText( "已保存 - 下次启动生效。" ) end
                Msg( "[HL2SB] addons_disabled.txt written (" .. tostring( #out ) .. " disabled)\n" )

                MENU.Layout( MENU.Frame )
            end
        end

        MENU.Layout( parent )
    end,
} )
