--[[----------------------------------------------------------------------------
    hl2sb_lua_errors.lua

    An in-game Lua error viewer, the way Garry's Mod has one.

    Engine side: luasrc_report_error() in luamanager.cpp now fires

        hook.call( "LuaError", message, traceback )

    for every error that used to go to Warning() alone -- lua_run, lua_dofile and
    the script loaders all route through it.  This file collects those and shows
    them in a window.

    Console:
        hl2sb_errors        open the window
        hl2sb_errors_clear  empty the list
        hl2sb_errors_test   raise a deliberate error, to prove collection works

    Loaded every level from lua/includes/modules/.
-----------------------------------------------------------------------------]]

--- Realms.  Both the in-game client state and the main menu state (LGameUI) run this,
--- the way GMod's error viewer is available in both.  _GAMEUI is set by
--- luasrc_init_gameui, which runs from CHLClient::Init before any map loads.
if ( not _CLIENT and not _GAMEUI ) then return end

--- The parent the window is created under, per realm.
local function rootPanel()
    if ( not _CLIENT and _GAMEUI ) then
        if ( VGui_GetGameUIPanel ) then return VGui_GetGameUIPanel() end
        return nil
    end
    if ( VGui_GetClientLuaRootPanel ) then return VGui_GetClientLuaRootPanel() end
    return nil
end

local Errors = {}
local MAX_KEPT = 50

hook.add( "LuaError", "hl2sb_lua_errors", function( message, traceback )
    table.insert( Errors, 1, {
        message   = tostring( message ),
        traceback = tostring( traceback or "" ),
        time      = CurTime(),
        map       = game and game.GetMap and game.GetMap() or "?",
    } )

    if ( #Errors > MAX_KEPT ) then
        table.remove( Errors, MAX_KEPT + 1 )
    end
end )

--- First line of the message, which is what GMod shows in its list.
local function summarise( message )
    return ( message:gsub( "\n.*", "" ) )
end

local window

local function OpenErrors()
    if ( window ) then
        window:Close()
        window = nil
    end

    local frame = vgui.Create( "DFrame", rootPanel(), "HL2SB_LuaErrors" )
    if ( not frame ) then
        print( "[HL2SB] could not create the error window (vgui.Create returned nothing)" )
        return
    end
    window = frame

    frame:SetSize( math.min( 900, ScrW() - 80 ), math.min( 600, ScrH() - 80 ) )
    frame:SetPos( ScrW() / 2 - frame:GetWide() / 2, ScrH() / 2 - frame:GetTall() / 2 )
    frame:SetTitle( "Lua 错误  (" .. #Errors .. ")" )
    frame:MakePopup()
    frame:SetVisible( true )

    -- A header line, coloured, then one label per error.  No scroll panel exists
    -- in HL2SB yet, so the list is capped at what fits.
    local header = vgui.Create( "Label", frame, "Header" )
    header:SetPos( 16, 36 )
    header:SetSize( frame:GetWide() - 32, 22 )
    if ( #Errors == 0 ) then
        header:SetText( "目前没有 Lua 错误报告" )
    else
        header:SetText( "最近 " .. #Errors .. " 条错误（最新的在最上面）" )
    end

    local y = 66
    local shown = 0
    for _, entry in ipairs( Errors ) do
        if ( y + 46 > frame:GetTall() - 48 ) then break end

        local label = vgui.Create( "Label", frame, "Err" .. shown )
        label:SetPos( 16, y )
        label:SetSize( frame:GetWide() - 32, 20 )
        label:SetText( string.format( "[%s] %s", string.format( "%.0f", entry.time ), summarise( entry.message ) ) )

        -- The first frame of the traceback, which is where it actually broke.
        local where = entry.traceback:match( "\n\t([^\n]+)" ) or ""
        if ( where ~= "" ) then
            local sub = vgui.Create( "Label", frame, "Loc" .. shown )
            sub:SetPos( 32, y + 20 )
            sub:SetSize( frame:GetWide() - 48, 20 )
            sub:SetText( where )
        end

        y = y + 46
        shown = shown + 1
    end

    local clear = vgui.Create( "Button", frame, "Clear", "清除" )
    clear:SetPos( 16, frame:GetTall() - 40 )
    clear:SetSize( 120, 28 )
    clear.DoClick = function()
        Errors = {}
        OpenErrors()
    end

    local close = vgui.Create( "Button", frame, "Close", "关闭" )
    close:SetPos( frame:GetWide() - 136, frame:GetTall() - 40 )
    close:SetSize( 120, 28 )
    close.DoClick = function()
        frame:Close()
        window = nil
    end

    print( "[HL2SB] hl2sb_errors: " .. #Errors .. " error(s) collected" )
    return frame
end

concommand.Create( "hl2sb_errors", function()
    OpenErrors()
end, "Show the collected Lua errors" )

concommand.Create( "hl2sb_errors_clear", function()
    Errors = {}
    print( "[HL2SB] error list cleared" )
end, "Clear the collected Lua errors" )

concommand.Create( "hl2sb_errors_test", function()
    error( "hl2sb_errors_test: this is a deliberate error" )
end, "Raise a Lua error, to check the collector" )

print( "[HL2SB] hl2sb_lua_errors.lua loaded - run 'hl2sb_errors'" )
