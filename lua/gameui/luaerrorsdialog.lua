--[[----------------------------------------------------------------------------
    HL2SB: main-menu Lua error viewer (GMod-style "Lua errors" window).

    The errors are collected ENGINE SIDE (luamanager.cpp, HL2SB_CollectLuaError,
    fed from luasrc_report_error), grouped by the addon that raised them and
    kept alive across map changes.  This dialog reads that through:

        hl2sb_getluaerrors()   { { addon=, total=, items={ {msg=, count=, traceback=} } } }
        hl2sb_clearluaerrors()
        hl2sb_luaerrorcount()
        hl2sb_setclipboardtext( text )

    Layout: one accordion group per addon (the most recent group starts
    expanded), each item line with its repeat count and a copy button, a
    per-group hint like GMod's, and a clear/refresh/close bar.

    Same rendering rules as addonsdialog.lua: engine controls, own CJK fonts,
    one computed layout, ReassertPositions + HL2SB_MenuLayout (the menu realm
    never runs a vgui layout pass on its own).
------------------------------------------------------------------------------]]

if ( not vgui or not vgui.Create ) then print( "[HL2SB] luaerrorsdialog: no vgui" ) return end

require( "concommand" )

local Say = ( type( print ) == "function" and print ) or function() end

local FCVAR_CLIENTDLL = _E and _E.FCVAR and _E.FCVAR.CLIENTDLL or 0

local STR = {
    Title     = "Lua 错误",
    Empty     = "目前没有收集到 Lua 错误",
    Stats     = "%d 个位置报告了 Lua 错误，共 %d 条",
    Clear     = "清空",
    Refresh   = "刷新",
    Close     = "关闭",
    Copy      = "复制",
    CopyAll   = "复制全部",
    HintGroup = "看来插件 \"%s\" 正在制造 Lua 错误。\n您可以停用该插件以使错误消失，你也应该向插件作者报告错误。",
    NoEngine  = "引擎没有提供错误收集器（hl2sb_getluaerrors 不存在），请更新 client.dll",
    Collapsed = "  ▶",
    Expanded  = "  ▼",
}

local FONT_TEXT  = "HL2SB_MenuText"
local FONT_TITLE = "HL2SB_MenuTitle"

local COL_TEXT   = Color and Color( 235, 235, 235 ) or nil
local COL_ERR    = Color and Color( 255, 120, 120 ) or nil
local COL_DIM    = Color and Color( 175, 175, 175 ) or nil
local COL_COUNT  = Color and Color( 255, 200,  90 ) or nil

local m_Frame  = nil
local m_Expand = nil      -- index of the expanded group (nil = none)

local DIALOG_W = 700

-- ---------------------------------------------------------------------------
-- data
-- ---------------------------------------------------------------------------

local function GetGroups()
    if ( hl2sb_getluaerrors == nil ) then return nil end
    local ok, groups = pcall( hl2sb_getluaerrors )
    if ( not ok or type( groups ) ~= "table" ) then return nil end
    return groups
end

-- ---------------------------------------------------------------------------
-- fonts / colours (the addonsdialog pair)
-- ---------------------------------------------------------------------------

local m_FontsReady = false

local function MakeFonts()
    if ( not surface or not surface.CreateFont ) then return end
    surface.CreateFont( FONT_TEXT,  { font = "Microsoft YaHei", size = 15, weight = 500, extended = true } )
    surface.CreateFont( FONT_TITLE, { font = "Microsoft YaHei", size = 17, weight = 800, extended = true } )
    m_FontsReady = true
end

MakeFonts()

local function ApplyFont( panel, name )
    if ( m_FontsReady and panel and panel.SetFont ) then
        panel:SetFont( name )
    end
    return panel
end

local function Colour( panel, clr )
    if ( panel and clr and panel.SetTextColor ) then
        panel:SetTextColor( clr )
    end
    return panel
end

-- ---------------------------------------------------------------------------
-- window
-- ---------------------------------------------------------------------------

local Open    -- forward declaration (same scoping trap as addonsdialog.lua)

local function OpenPlain()
    -- one-shot bisect: what does the menu realm actually see?
    Say( "[HL2SB] luaerrorsdialog: report binding=" .. tostring( hl2sb_reportluaerror ~= nil )
        .. " count=" .. tostring( hl2sb_luaerrorcount and hl2sb_luaerrorcount() or "n/a" ) )

    local parent = VGui_GetGameUIPanel and VGui_GetGameUIPanel() or nil
    if ( not parent ) then
        Say( "[HL2SB] luaerrorsdialog: no GameUI root panel" )
    end

    local frame = vgui.Frame( parent, "HL2SBLuaErrorsDialog", true )
    if ( not frame ) then return nil end

    m_Frame = frame

    frame:SetTitle( STR.Title )
    frame:SetSize( DIALOG_W, 540 )
    frame:MoveToCenterOfScreen()

    local groups = GetGroups()

    local Layout = {}

    local function NewLabel( x, y, w, h, text, clr )
        local lbl = vgui.Create( "Label", frame )
        if ( not lbl ) then return nil end
        lbl:SetPos( x, y )
        lbl:SetSize( w, h )
        if ( lbl.SetWrap ) then lbl:SetWrap( true ) end
        lbl:SetText( text )
        ApplyFont( lbl, FONT_TEXT )
        Colour( lbl, clr )
        Layout[ #Layout + 1 ] = { lbl, x, y, w, h }
        return lbl
    end

    local function NewButton( text, x, y, w, h, cmd )
        if ( not vgui.Button ) then return nil end
        local btn = vgui.Button( frame, "err_" .. cmd, text, frame, cmd )
        btn:SetBounds( x, y, w, h )
        ApplyFont( btn, FONT_TEXT )
        Layout[ #Layout + 1 ] = { btn, x, y, w, h }
        return btn
    end

    local M      = 14
    local fw     = DIALOG_W
    local innerW = DIALOG_W - M * 2
    local y      = 30

    -- status line
    if ( groups == nil ) then
        NewLabel( M, y, innerW, 20, STR.NoEngine, COL_ERR )
        y = y + 28
    elseif ( #groups == 0 ) then
        NewLabel( M, y, innerW, 20, STR.Empty, COL_DIM )
        y = y + 28
    else
        local total = 0
        for _, g in ipairs( groups ) do
            total = total + ( g.total or 0 )
        end
        NewLabel( M, y, innerW, 20, string.format( STR.Stats, #groups, total ), COL_TEXT )
        y = y + 28
    end

    -- groups: headers always visible, one group expanded at a time (the
    -- expanded group is bounded by the engine's own per-group item cap)
    if ( groups ~= nil ) then
        for gi, grp in ipairs( groups ) do
            local addon = tostring( grp.addon or "?" )
            local total = tonumber( grp.total or 0 ) or 0

            local open = ( m_Expand == gi )
            local arrow = open and STR.Expanded or STR.Collapsed
            local header = NewButton( addon .. arrow .. "   x" .. total,
                M, y, innerW - 96, 24, "grp_" .. gi )
            if ( header and header.SetTooltip and grp.items and grp.items[ 1 ] ) then
                header:SetTooltip( grp.items[ 1 ].msg )
            end
            NewButton( STR.CopyAll, fw - M - 90, y, 90, 24, "copyall_" .. gi )
            y = y + 28

            if ( open and grp.items ) then
                for ii, item in ipairs( grp.items ) do
                    local msg  = tostring( item.msg or "?" )
                    local cnt  = tonumber( item.count or 1 ) or 1
                    local trace = tostring( item.traceback or "" )

                    local lineH = 32
                    if ( #msg > 90 ) then lineH = 46 end

                    NewLabel( M + 10, y, innerW - 130, lineH, msg, COL_ERR )
                    NewLabel( M + 10, y + lineH, 40, 18, "x" .. cnt, COL_COUNT )
                    NewButton( STR.Copy, fw - M - 100, y + 4, 90, 22, "copy_" .. gi .. "_" .. ii )
                    y = y + lineH + 20

                    -- first traceback frame, so the origin is visible without copying
                    local where = trace:match( "\n\t([^\n]+)" )
                    if ( where == nil ) then where = trace:match( "([^\n]+:%d+:[^\n]*)" ) end
                    if ( where ~= nil and where ~= "" ) then
                        NewLabel( M + 28, y, innerW - 42, 18, where, COL_DIM )
                        y = y + 20
                    end
                end

                NewLabel( M + 10, y, innerW - 20, 36,
                    string.format( STR.HintGroup, addon ), COL_DIM )
                y = y + 42
            end
        end
    end

    y = y + 8

    NewButton( STR.Clear,   M,          y, 100, 26, "clear" )
    NewButton( STR.Refresh, M + 108,    y, 100, 26, "refresh" )
    NewButton( STR.Close,   fw - M - 100, y, 100, 26, "Close" )
    y = y + 26 + M

    frame:SetSize( DIALOG_W, y )
    frame:MoveToCenterOfScreen()

    if ( frame.SetSizeable ) then frame:SetSizeable( false ) end

    frame.OnCommand = function( self, cmd )
        if ( type( self ) == "string" ) then cmd = self end
        if ( not cmd ) then return end

        local function Reopen()
            if ( m_Frame and m_Frame.Close ) then m_Frame:Close() end
            m_Frame = nil
            Open()
        end

        if ( cmd == "Close" ) then
            frame:Close()
            m_Frame = nil
        elseif ( cmd == "refresh" ) then
            Reopen()
        elseif ( cmd == "clear" ) then
            if ( hl2sb_clearluaerrors ) then pcall( hl2sb_clearluaerrors ) end
            m_Expand = nil
            Reopen()
        elseif ( cmd:sub( 1, 4 ) == "grp_" ) then
            local gi = tonumber( cmd:sub( 5 ) )
            if ( m_Expand == gi ) then m_Expand = nil else m_Expand = gi end
            Reopen()
        elseif ( cmd:sub( 1, 8 ) == "copyall_" ) then
            local gi = tonumber( cmd:sub( 9 ) )
            local gs = GetGroups()
            if ( gs and gs[ gi ] and hl2sb_setclipboardtext ) then
                local buf = {}
                local g = gs[ gi ]
                for _, item in ipairs( g.items or {} ) do
                    buf[ #buf + 1 ] = item.msg or ""
                    buf[ #buf + 1 ] = item.traceback or ""
                    buf[ #buf + 1 ] = ""
                end
                hl2sb_setclipboardtext( table.concat( buf, "\n" ) )
                local nItems = 0
                for _ in ipairs( g.items or {} ) do nItems = nItems + 1 end
                Say( "[HL2SB] copied " .. nItems .. " error item(s) from '" .. tostring( g.addon ) .. "'" )
            end
        elseif ( cmd:sub( 1, 5 ) == "copy_" ) then
            local gi = tonumber( cmd:match( "copy_(%d+)_" ) )
            local ii = tonumber( cmd:match( "_(%d+)$" ) )
            local gs = GetGroups()
            if ( gs and gs[ gi ] and gs[ gi ].items and gs[ gi ].items[ ii ] and hl2sb_setclipboardtext ) then
                local item = gs[ gi ].items[ ii ]
                hl2sb_setclipboardtext( ( item.msg or "" ) .. "\n" .. ( item.traceback or "" ) )
                Say( "[HL2SB] error text copied to clipboard" )
            end
        end
    end

    if ( frame.SetVisible ) then frame:SetVisible( true ) end
    if ( frame.MoveToFront ) then frame:MoveToFront() end
    frame:Activate()

    local function ReassertPositions()
        for i = 1, #Layout do
            local e = Layout[ i ]
            if ( e[ 1 ] ~= nil and e[ 1 ].SetBounds ~= nil ) then
                e[ 1 ]:SetBounds( e[ 2 ], e[ 3 ], e[ 4 ], e[ 5 ] )
            end
        end
        if ( HL2SB_MenuLayout ) then
            HL2SB_MenuLayout( frame )
        end
        if ( frame.InvalidateLayout ) then frame:InvalidateLayout( true ) end
    end

    ReassertPositions()

    if ( timer and timer.Simple ) then
        timer.Simple( 0, function()
            if ( frame == nil or frame.SetBounds == nil ) then return end
            ReassertPositions()
        end )
    end

    frame:SetSize( DIALOG_W, y )

    return frame
end

Open = function()
    local ok, frame = pcall( OpenPlain )
    if ( not ok ) then
        Say( "[HL2SB] luaerrorsdialog: open failed: " .. tostring( frame ) )
        return nil
    end
    return frame
end

concommand.Create( "OpenLuaErrorsDialog", function()
    if ( m_Frame and m_Frame.Close ) then m_Frame:Close() end
    m_Frame = nil
    Open()
end, "Open the HL2SB Lua error viewer.", FCVAR_CLIENTDLL )

Say( "[HL2SB] luaerrorsdialog loaded" )
