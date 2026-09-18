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

-- GMod's colours for this kind of list: the message is what you must read, the
-- traceback line is context.  The engine Label binding grew SetTextColor for
-- exactly this (lLabel.cpp) -- before it had no colour setter at all, so the
-- window was monochrome even though its own comment promised colours.
local COL_HEADER = Color and Color( 235, 235, 235 ) or nil
local COL_MESSAGE = Color and Color( 255, 90, 90 ) or nil
local COL_TRACE   = Color and Color( 170, 170, 170 ) or nil
local COL_IDLE    = Color and Color( 200, 200, 200 ) or nil

-- Applies the colour on whichever control this realm ended up with; both the
-- derma DLabel and the engine Label expose SetTextColor now.
local function Colour( panel, clr )
    if ( panel and clr and panel.SetTextColor ) then
        panel:SetTextColor( clr )
    end
    return panel
end

local function OpenErrors()
    if ( window ) then
        window:Close()
        window = nil
    end

    -- Prefer the derma window (scrollable, skinned); the plain engine Frame
    -- version stays as the fallback for realms without the derma stack.
    local useDerma = ( derma and derma.DefineControl ) and true or false
    -- This fork's Lua parser rejects `f( a and b or c )`, so the class names are
    -- picked once here instead of inline in the calls below.
    local sLabel = useDerma and "DLabel" or "Label"
    local sButton = useDerma and "DButton" or "Button"

    local frame
    if ( useDerma ) then
        frame = vgui.Create( "DFrame", rootPanel(), "HL2SB_LuaErrors" )
    else
        frame = vgui.Frame and vgui.Frame( rootPanel(), "HL2SB_LuaErrors", true )
    end

    if ( not frame ) then
        print( "[HL2SB] could not create the error window (vgui.Create returned nothing)" )
        return
    end
    window = frame

    local wWide = math.min( 900, ScrW() - 80 )
    local wTall = math.min( 600, ScrH() - 80 )

    frame:SetSize( wWide, wTall )
    frame:SetPos( math.max( 0, ScrW() / 2 - wWide / 2 ), math.max( 0, ScrH() / 2 - wTall / 2 ) )
    frame:SetTitle( "Lua 错误  (" .. #Errors .. ")" )
    if ( frame.MakePopup ) then frame:MakePopup() end
    if ( frame.SetVisible ) then frame:SetVisible( true ) end
    if ( frame.Activate ) then frame:Activate() end

    local host = frame
    local listTop = 40
    local listH = wTall - 40 - 48

    if ( useDerma ) then
        local sheet = vgui.Create( "DScrollPanel", frame, "List" )
        sheet:SetPos( 8, listTop - 4 )
        sheet:SetSize( wWide - 16, listH )
        host = sheet:GetCanvas() or sheet
        listTop = 4
    end

    -- A coloured header line, then one coloured entry per error.
    local header = vgui.Create( sLabel, frame, "Header" )
    header:SetPos( 16, 16 )
    header:SetSize( wWide - 32, 22 )
    if ( #Errors == 0 ) then
        header:SetText( "目前没有 Lua 错误报告" )
        Colour( header, COL_IDLE )
    else
        header:SetText( "最近 " .. #Errors .. " 条错误（最新的在最上面）" )
        Colour( header, COL_HEADER )
    end

    local y = listTop
    local shown = 0
    for _, entry in ipairs( Errors ) do
        local label = vgui.Create( sLabel, host, "Err" .. shown )
        label:SetPos( 16, y )
        label:SetSize( wWide - 48, 20 )
        label:SetText( string.format( "[%.0fs] %s", entry.time or 0, summarise( entry.message ) ) )
        Colour( label, COL_MESSAGE )

        -- The first frame of the traceback, which is where it actually broke.
        local where = entry.traceback:match( "\n\t([^\n]+)" ) or ""
        if ( where ~= "" ) then
            y = y + 20
            local sub = vgui.Create( sLabel, host, "Loc" .. shown )
            sub:SetPos( 32, y )
            sub:SetSize( wWide - 64, 20 )
            sub:SetText( where )
            Colour( sub, COL_TRACE )
        end

        y = y + 26
        shown = shown + 1
    end

    if ( useDerma ) then
        local canvas = host
        if ( canvas.SetTall ) then canvas:SetTall( math.max( y, listH ) ) end
        -- the scroll range comes from the canvas height (kept out of an `and`
        -- expression: this fork's Lua parser rejects method calls there)
        local sheet = nil
        if ( host.GetParent ) then sheet = host:GetParent() end
        if ( sheet and sheet.SetContentHeight ) then sheet:SetContentHeight( y + 4 ) end
    end

    local clear = vgui.Create( sButton, frame, "Clear", "清除" )
    if ( clear ) then
        clear:SetPos( 16, wTall - 40 )
        clear:SetSize( 120, 28 )
        clear.DoClick = function()
            Errors = {}
            OpenErrors()
        end
    end

    local close = vgui.Create( sButton, frame, "Close", "关闭" )
    if ( close ) then
        close:SetPos( wWide - 136, wTall - 40 )
        close:SetSize( 120, 28 )
        close.DoClick = function()
            frame:Close()
            window = nil
        end
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
