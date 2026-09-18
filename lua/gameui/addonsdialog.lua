--[[----------------------------------------------------------------------------
    HL2SB: main-menu Addons manager.

    Two front ends, same engine work behind both:

      PLAIN  (default)  engine controls (Frame/Label/Button/CheckButton/TextEntry)
                        with an explicit CJK font, a layout computed in one
                        place, text colours and no resizable borders.  This is
                        the one that reliably paints in the menu realm, and the
                        main menu is Source UI territory anyway.

      DERMA  (opt-in)   the GMod-style window (DFrame/DScrollPanel/
                        DCheckBoxLabel).  Available with the console command
                        `hl2sb_addons_derma`, which toggles it and reopens.

    What "disabling" does
    ---------------------
    An addon is a folder under addons/ (or a .gma archive, which the engine
    unpacks into addons/<name>/).  Both are MOUNTED as search paths at startup
    (game/shared/lua/mountaddons.cpp + shared/hl2sb/hl2sb_gma.cpp).  A disabled
    addon is simply not mounted -- the Lua side never sees it.

    ENABLE/DISABLE APPLIES IMMEDIATELY unless a map is already running.  The
    engine exposes two globals for that (HL2SB_LuaRegisterAddons):

        hl2sb_setaddon( name, enabled ) -> bool   true = took effect NOW
        hl2sb_addons_live()             -> bool   can a change take effect NOW
------------------------------------------------------------------------------]]

if ( not engine or not engine.GetGameDirectory ) then print( "[HL2SB] addonsdialog: no engine.GetGameDirectory" ) return end
if ( not vgui or not vgui.Create ) then print( "[HL2SB] addonsdialog: no vgui.Create" ) return end
if ( not file or not file.Find ) then print( "[HL2SB] addonsdialog: no file.Find" ) return end

require( "concommand" )

local FCVAR_CLIENTDLL = _E and _E.FCVAR and _E.FCVAR.CLIENTDLL or 0

-- print, not Msg: the menu realm is not guaranteed to carry Msg, and a
-- diagnostic that throws takes the whole file (and its concommand) down.
local Say = ( type( print ) == "function" and print ) or function() end

-- DFrame:OnMousePressed compares against MOUSE_LEFT; the menu realm may not
-- have the enumeration globals the client realm seeds.
MOUSE_LEFT  = MOUSE_LEFT  or ( _E and _E.MOUSE_LEFT )  or 107
MOUSE_RIGHT = MOUSE_RIGHT or ( _E and _E.MOUSE_RIGHT ) or 108

local STR = {
    Title      = "插件管理",
    Hint       = "取消勾选的插件不会被挂载。修改立即生效；已进入地图时则在下次启动生效。",
    Empty      = "addons/ 目录中没有找到插件",
    EnableAll  = "启用全部",
    DisableAll = "禁用全部",
    Refresh    = "刷新",
    Close      = "关闭",
    Filter     = "筛选",
    Prev       = "上一页",
    Next       = "下一页",
    AppliedNow     = "✓ 已立即生效",
    AppliedRestart = "已在地图中：已保存，下次启动生效",
}

-- ---------------------------------------------------------------------------
-- fonts: the scheme's "Default" is a small bitmap face and everything CJK in
-- it is unreadable, so the dialog defines its own (GMod-style: the UI layer
-- owns its fonts; luaL_checkfont accepts the NAME).
-- ---------------------------------------------------------------------------

local FONT_TEXT = "HL2SB_MenuText"
local FONT_TITLE = "HL2SB_MenuTitle"
local m_FontsReady = false

local function MakeFonts()
    if ( not surface or not surface.CreateFont ) then return end

    surface.CreateFont( FONT_TEXT, { font = "Microsoft YaHei", size = 15, weight = 500, extended = true } )
    surface.CreateFont( FONT_TITLE, { font = "Microsoft YaHei", size = 17, weight = 800, extended = true } )
    m_FontsReady = true
end

MakeFonts()

-- Only touch the font when the creation above actually happened: setting a
-- name the engine never registered leaves the label without a usable font.
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

local COL_TEXT  = Color and Color( 235, 235, 235 ) or nil
local COL_TITLE = Color and Color( 255, 255, 255 ) or nil
local COL_WARN  = Color and Color( 255, 165, 0 ) or nil
local COL_OK    = Color and Color( 140, 255, 140 ) or nil
local COL_DIM   = Color and Color( 175, 175, 175 ) or nil

-- ---------------------------------------------------------------------------
-- state
-- ---------------------------------------------------------------------------

local m_Frame        = nil
local m_Filter       = ""
local m_Status       = nil
local m_UseDerma     = false        -- opt-in: hl2sb_addons_derma

local ROW_H     = 26
local DIALOG_W  = 470
local PAGE_SIZE = 14

-- ---------------------------------------------------------------------------
-- the addons
-- ---------------------------------------------------------------------------

local function ListAddons()
    local out = {}

    local files, dirs = file.Find( "addons/*", "MOD" )

    for _, name in ipairs( dirs or {} ) do
        if ( name:sub( 1, 1 ) != "." ) then
            out[ #out + 1 ] = { name = name, key = name:lower(), isGma = false }
        end
    end

    for _, name in ipairs( files or {} ) do
        if ( name:lower():sub( -4 ) == ".gma" ) then
            local base = name:sub( 1, -5 )
            out[ #out + 1 ] = { name = name, key = base:lower(), isGma = true }
        end
    end

    table.sort( out, function( a, b ) return a.key < b.key end )
    return out
end

local function DedupeList( list )
    local seen, out = {}, {}
    for _, entry in ipairs( list ) do
        if ( not seen[ entry.key ] ) then
            seen[ entry.key ] = true
            out[ #out + 1 ] = entry
        elseif ( entry.isGma ) then
            for i = 1, #out do
                if ( out[ i ].key == entry.key ) then
                    out[ i ].name = entry.name
                    out[ i ].isGma = true
                    break
                end
            end
        end
    end
    return out
end

local function FilteredAddons( addons )
    local query = ( m_Filter or "" ):lower()
    local rows = {}
    for _, entry in ipairs( addons ) do
        if ( query == "" or entry.name:lower():find( query, 1, true ) ) then
            rows[ #rows + 1 ] = entry
        end
    end
    return rows
end

local function ReadDisabled()
    local set = {}
    local dir = engine.GetGameDirectory()
    if ( not dir ) then return set end

    local f = io.open( dir .. "/addons_disabled.txt", "r" )
    if ( not f ) then return set end

    for line in f:lines() do
        local name = line:match( "^%s*([^#;%s].*)$" )
        if ( name ) then
            name = name:gsub( "%s+$", "" )
            if ( name != "" ) then
                set[ name:lower() ] = true
            end
        end
    end
    f:close()
    return set
end

local m_Live = ( hl2sb_setaddon != nil )

local function SetEnabled( key, enabled )
    if ( m_Live ) then
        return hl2sb_setaddon( key, enabled ) and true or false
    end

    local dir = engine.GetGameDirectory()
    if ( not dir ) then return false end

    local set = ReadDisabled()
    if ( enabled ) then set[ key:lower() ] = nil else set[ key:lower() ] = true end

    local f = io.open( dir .. "/addons_disabled.txt", "w" )
    if ( not f ) then return false end

    local names = {}
    for name, on in pairs( set ) do
        if ( on ) then names[ #names + 1 ] = name end
    end
    table.sort( names )

    f:write( "# HL2SB: addons switched off in the main menu. One folder name per line.\n" )
    f:write( "# Changes apply on the next start.\n" )
    for _, name in ipairs( names ) do
        f:write( name, "\n" )
    end
    f:close()
    return false
end

local function Status( applied )
    if ( not m_Status ) then return end
    m_Status:SetText( applied and STR.AppliedNow or STR.AppliedRestart )
    Colour( m_Status, applied and COL_OK or COL_WARN )
end

-- ---------------------------------------------------------------------------
-- PLAIN front end: engine controls, one computed layout, no overlap possible
-- ---------------------------------------------------------------------------

-- HL2SB: forward declaration.  OpenPlain()'s Reopen() closes the frame and calls Open()
-- again, but "local function Open()" is defined further down - a closure created before it
-- cannot see that local, so Reopen() resolved Open to the GLOBAL (nil) and every refresh /
-- filter click raised
--     hl2sb\lua\gameui\addonsdialog.lua:431: attempt to call a nil value (global 'Open')
-- Declaring it here and assigning later (see "Open = function()" below) fixes the scoping.
local Open

local function OpenPlain()
    local parent = VGui_GetGameUIPanel and VGui_GetGameUIPanel() or nil
    if ( not parent ) then
        Say( "[HL2SB] addonsdialog: no GameUI root panel - frame is parentless" )
    end

    local frame = vgui.Frame( parent, "HL2SBAddonsDialog", true )
    if ( not frame ) then return nil end

    m_Frame = frame
    m_Status = nil

    -- Size the frame BEFORE the children: the layout below measures against the
    -- frame's REAL width, so a frame that ignores the request cannot push the
    -- right-hand column past its edge (that is what "the menu overlaps" looks
    -- like from outside).  The height is re-asserted after the layout math.
    frame:SetTitle( STR.Title )
    frame:SetSize( DIALOG_W, 480 )
    frame:MoveToCenterOfScreen()

    local addons = DedupeList( ListAddons() )
    local disabled = ReadDisabled()
    local rows = FilteredAddons( addons )

    local enabledCount = 0
    for _, entry in ipairs( addons ) do
        if ( not disabled[ entry.key ] ) then enabledCount = enabledCount + 1 end
    end

    -- Every control that gets an explicit position is recorded here, because in this
    -- (GameUI) state the dbg dump proved something very specific:
    --
    --     15 LLabel      size=442x36   pos=(0,0)
    --     16 LTextEntry  size=250x24   pos=(0,0)
    --     19 LCheckButton size=442x26  pos=(0,0)
    --     ...  1..14 = the frame's OWN chrome, also pos=(0,0)
    --
    -- i.e. SetSize() takes effect immediately but SetPos() does not: positions are only
    -- applied by a vgui layout pass, and nothing drives that pass for a menu-state frame.
    -- So issue them once through ReassertPositions() below and once more on the next frame.
    local Layout = {}

    local function NewLabel( x, y, w, text, h )
        if ( not vgui.Create ) then return nil end
        local lbl = vgui.Create( "Label", frame )
        if ( not lbl ) then return nil end
        lbl:SetPos( x, y )
        lbl:SetSize( w, h or 20 )
        if ( lbl.SetWrap ) then lbl:SetWrap( true ) end
        lbl:SetText( text )
        ApplyFont( lbl, FONT_TEXT )
        Colour( lbl, COL_TEXT )
        Layout[ #Layout + 1 ] = { lbl, x, y, w, h or 20 }
        return lbl
    end

    local function NewButton( text, x, y, w, h, cmd )
        if ( not vgui.Button ) then return nil end
        local btn = vgui.Button( frame, "addons_" .. cmd, text, frame, cmd )
        btn:SetBounds( x, y, w, h )
        ApplyFont( btn, FONT_TEXT )
        Layout[ #Layout + 1 ] = { btn, x, y, w, h }
        return btn
    end

    -- ---- layout: every block reserves its space, in order -------------------
    -- ⚠️ The layout measures from DIALOG_W, NOT from frame:GetWide().  An
    -- earlier version "adapted to the real width" and committed it at the end
    -- with SetSize( fw, y ): before the frame has laid out, GetWide() answers
    -- something small (the panel's default), so that logic SHRANK the window to
    -- a strip and every line of text ran into the next.
    local M      = 14                      -- margin
    local fw     = DIALOG_W
    local innerW = DIALOG_W - M * 2
    local y      = 30

    NewLabel( M, y, innerW, STR.Hint, 36 )  -- two wrapped lines
    y = y + 42

    local search = nil
    if ( vgui.TextEntry ) then
        search = vgui.TextEntry( frame, "addonsSearch" )
        search:SetBounds( M, y, 250, 24 )
        Layout[ #Layout + 1 ] = { search, M, y, 250, 24 }
        if ( search.SetText ) then search:SetText( m_Filter or "" ) end
        ApplyFont( search, FONT_TEXT )
        NewButton( STR.Filter, M + 258, y, 70, 24, "applyfilter" )
    end
    y = y + 32

    NewLabel( M, y, innerW, string.format( "共 %d 个插件，已启用 %d 个（当前显示 %d 个）",
        #addons, enabledCount, #rows ), 20 )
    y = y + 26

    -- rows: a full page is always reserved, so page flips move nothing else
    local rowsTop = y
    local show = math.min( #rows, PAGE_SIZE )
    for i = 1, show do
        local entry = rows[ i ]
        local cb = nil
        if ( vgui.CheckButton ) then cb = vgui.CheckButton( frame, "addon_" .. i, entry.name .. ( entry.isGma and "  [GMA]" or "" ) ) end
        if ( cb ~= nil ) then
            cb:SetBounds( M, rowsTop + ( i - 1 ) * ROW_H, innerW, ROW_H )
            Layout[ #Layout + 1 ] = { cb, M, rowsTop + ( i - 1 ) * ROW_H, innerW, ROW_H }
            cb:SetSelected( not disabled[ entry.key ] )
            ApplyFont( cb, FONT_TEXT )
            cb.OnCheckButtonChecked = function( btn )
                Status( SetEnabled( entry.key, btn:IsChecked() ) )
            end
        end
    end

    if ( #rows == 0 ) then
        NewLabel( M, rowsTop, innerW, STR.Empty, 20 )
    elseif ( #rows > PAGE_SIZE ) then
        NewLabel( M, rowsTop + PAGE_SIZE * ROW_H, innerW,
            string.format( "还有 %d 个未显示，请用上面的筛选框缩小范围", #rows - PAGE_SIZE ), 20 )
    end
    y = rowsTop + ( PAGE_SIZE + 1 ) * ROW_H + 6

    m_Status = NewLabel( M, y, innerW, "", 20 )
    y = y + 26

    NewButton( STR.EnableAll,  M,      y, 100, 26, "enableall" )
    NewButton( STR.DisableAll, M+108,  y, 100, 26, "disableall" )
    NewButton( STR.Refresh,    M+216,  y,  80, 26, "refresh" )
    NewButton( STR.Close,      fw - M - 100, y, 100, 26, "Close" )
    y = y + 26 + M

    -- ---- the frame itself ---------------------------------------------------
    -- Set the size and KEEP it: the requested width and the height the layout
    -- just computed.
    frame:SetSize( DIALOG_W, y )
    frame:MoveToCenterOfScreen()

    -- ---- diagnosis ----------------------------------------------------------
    -- The window has twice been reported as an empty translucent box with
    -- overlapping text, and every layout number here says it should be fine -
    -- so dump what the panel tree actually ended up as (and which factories the
    -- GameUI state has at all).  Log-only: Say() goes to the console/log and
    -- changes nothing about the window.
    Say( string.format( "[HL2SB] addonsdialog dbg: factories Frame=%s Button=%s Label=%s CheckButton=%s TextEntry=%s Create=%s",
        tostring( vgui.Frame ~= nil ), tostring( vgui.Button ~= nil ), tostring( vgui.Create ~= nil ),
        tostring( vgui.CheckButton ~= nil ), tostring( vgui.TextEntry ~= nil ), tostring( vgui.Create ~= nil ) ) )

    if ( frame.GetChildren ) then
        local kids = frame:GetChildren() or {}
        local direct = 0

        for i = 1, #kids do
            local k = kids[ i ]
            if ( k.GetParent and k:GetParent() == frame ) then direct = direct + 1 end
        end

        Say( string.format( "[HL2SB] addonsdialog dbg: frame %dx%d, %d children (%d of them direct)",
            frame:GetWide(), frame:GetTall(), #kids, direct ) )

        -- ALL of them: the first entries are the frame's own chrome, the dialog's own
        -- controls come after, and it is exactly those the dump has to show.
        for i = 1, math.min( #kids, 40 ) do
            local k = kids[ i ]
            local x, y2 = 0, 0
            if ( k.GetPos ) then local px, py = k:GetPos(); x, y2 = px, py end

            local parentName = "?"
            if ( k.GetParent ) then
                local p = k:GetParent()
                parentName = ( p == frame ) and "(frame)" or ( p and p.GetName and p:GetName() or "?" )
            end

            Say( string.format( "[HL2SB] addonsdialog dbg:   %d %s parent=%s pos=(%s,%s) size=%sx%s visible=%s",
                i, tostring( k.GetClassName and k:GetClassName() or "?" ), tostring( parentName ),
                tostring( x ), tostring( y2 ),
                tostring( k.GetWide and k:GetWide() or "?" ), tostring( k.GetTall and k:GetTall() or "?" ),
                tostring( k.IsVisible and k:IsVisible() or "?" ) ) )
        end
    end

    -- children are laid out once here; a border resize would leave them behind
    -- (big blank areas), so the frame is not resizable
    if ( frame.SetSizeable ) then frame:SetSizeable( false ) end

    -- One line, so a window that comes out the wrong size says so instead of
    -- just looking wrong (the reported numbers are for DIAGNOSIS ONLY; the
    -- window's size is DIALOG_W x y above).
    Say( string.format( "[HL2SB] addonsdialog: %dx%d -> reports %dx%d",
        DIALOG_W, y, frame:GetWide(), frame:GetTall() ) )

    frame.OnCommand = function( self, cmd )
        -- the scripted dispatcher may pass the command as arg 1 or 2
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
        elseif ( cmd == "applyfilter" ) then
            m_Filter = ( search and search:GetValue() ) or ""
            Reopen()
        elseif ( cmd == "refresh" ) then
            Reopen()
        elseif ( cmd == "enableall" or cmd == "disableall" ) then
            local want = ( cmd == "enableall" )
            local applied = true
            for _, entry in ipairs( rows ) do
                if ( not SetEnabled( entry.key, want ) ) then applied = false end
            end
            Reopen()
            Status( applied )
        end
    end

    if ( frame.SetVisible ) then frame:SetVisible( true ) end
    if ( frame.MoveToFront ) then frame:MoveToFront() end
    frame:Activate()

    -- ---- run the layout pass NOW -------------------------------------------
    -- vgui2 applies child geometry in a layout pass.  The dbg dump showed the frame's
    -- OWN chrome still at (0,0) with the default 64x24 / 18x18 sizes - i.e. no pass had
    -- run for this frame in the GameUI state, and the frame's own title bar was never
    -- schemed.  InvalidateLayout( true ) performs the pass IMMEDIATELY (vgui2's
    -- Panel::InvalidateLayout( bForce ); DPanelList:PerformLayout relies on the same call,
    -- see its comment in lua/vgui/DPanelList.lua), so drive it explicitly here and again
    -- for every child that has its own layout.
    local function ReassertPositions()
        for i = 1, #Layout do
            local e = Layout[ i ]
            if ( e[ 1 ] ~= nil and e[ 1 ].SetBounds ~= nil ) then
                e[ 1 ]:SetBounds( e[ 2 ], e[ 3 ], e[ 4 ], e[ 5 ] )
            end
        end

        -- The ENGINE pass: HL2SB_MenuLayout() walks the frame and its whole subtree and
        -- calls InvalidateLayout(true) + PerformLayout() on each - that is the pass this
        -- realm never runs (game/client/lua/lua_gameui_menu.cpp).  The Lua-side call below
        -- is the fallback for a build without it.
        if ( HL2SB_MenuLayout ) then
            HL2SB_MenuLayout( frame )
        end

        if ( frame.InvalidateLayout ) then frame:InvalidateLayout( true ) end
    end

    ReassertPositions()

    -- ...and once more on the next frame: by then the frame is actually up, which is when
    -- the first pass normally happens (the dump above ran before it).
    if ( timer and timer.Simple ) then
        timer.Simple( 0, function()
            if ( frame == nil or frame.SetBounds == nil ) then return end
            ReassertPositions()

            -- prove it: the positions we recorded, read back one frame later
            for i = 1, math.min( #Layout, 40 ) do
                local e = Layout[ i ]
                if ( e[ 1 ] ~= nil and e[ 1 ].GetPos ~= nil ) then
                    local px, py = e[ 1 ]:GetPos()
                    Say( string.format( "[HL2SB] addonsdialog dbg2:   %d pos=(%s,%s) size=%sx%s",
                        i, tostring( px ), tostring( py ),
                        tostring( e[ 1 ]:GetWide() ), tostring( e[ 1 ]:GetTall() ) ) )
                end
            end
        end )
    end

    -- Last word on the size: activating runs the scheme/layout pass, and the
    -- window must not end up smaller than what everything above was laid out
    -- for (that is exactly how it once collapsed into a strip).
    frame:SetSize( DIALOG_W, y )

    return frame
end

-- ---------------------------------------------------------------------------
-- DERMA front end (opt-in): the GMod-style window
-- ---------------------------------------------------------------------------

local function OpenDerma()
    local frame = vgui.Create( "DFrame" )
    if ( not frame ) then return nil end

    m_Frame = frame
    m_Status = nil

    local addons = DedupeList( ListAddons() )
    local disabled = ReadDisabled()
    local rows = FilteredAddons( addons )

    local enabledCount = 0
    for _, entry in ipairs( addons ) do
        if ( not disabled[ entry.key ] ) then enabledCount = enabledCount + 1 end
    end

    frame:SetTitle( STR.Title )
    frame:SetSize( 480, 620 )
    frame:SetPos( math.max( 0, ( ScrW() - 480 ) / 2 ), math.max( 0, ( ScrH() - 620 ) / 2 ) )
    frame:SetSizable( false )
    frame:SetDeleteOnClose( true )
    frame:MakePopup()

    local hint = vgui.Create( "DLabel", frame )
    hint:SetText( STR.Hint )
    hint:SetPos( 10, 30 )
    hint:SetSize( 460, 34 )
    hint:SetWrap( true )

    local search = vgui.Create( "DTextEntry", frame )
    search:SetPos( 10, 66 )
    search:SetSize( 250, 22 )
    search:SetText( m_Filter or "" )

    local filterBtn = vgui.Create( "DButton", frame )
    filterBtn:SetText( STR.Filter )
    filterBtn:SetPos( 268, 66 )
    filterBtn:SetSize( 70, 22 )
    filterBtn.DoClick = function()
        m_Filter = ( search and search:GetValue() ) or ""
        if ( m_Frame and m_Frame.Close ) then m_Frame:Close() end
        m_Frame = nil
        Open()
    end

    local stats = vgui.Create( "DLabel", frame )
    stats:SetPos( 10, 94 )
    stats:SetSize( 460, 16 )
    stats:SetText( string.format( "共 %d 个插件，已启用 %d 个", #addons, enabledCount ) )

    local sheet = vgui.Create( "DScrollPanel", frame )
    sheet:SetPos( 10, 114 )
    sheet:SetSize( 460, 620 - 114 - 74 )

    local canvas = sheet:GetCanvas()
    local y = 2
    for i = 1, #rows do
        local entry = rows[ i ]
        local row = vgui.Create( "DCheckBoxLabel", canvas )
        row:SetText( entry.name .. ( entry.isGma and "  [GMA]" or "" ) )
        row:SetPos( 6, y )
        row:SetSize( 430, ROW_H )
        row:SetChecked( not disabled[ entry.key ] )
        row.OnChange = function( pnl, checked )
            Status( SetEnabled( entry.key, checked ) )
        end
        y = y + ROW_H
    end

    if ( #rows == 0 ) then
        local empty = vgui.Create( "DLabel", canvas )
        empty:SetText( STR.Empty )
        empty:SetPos( 6, 4 )
        empty:SetSize( 430, 16 )
        y = y + 20
    end

    canvas:SetTall( math.max( y, sheet:GetTall() ) )
    sheet:SetContentHeight( y + 4 )

    m_Status = vgui.Create( "DLabel", frame )
    m_Status:SetPos( 10, 620 - 58 )
    m_Status:SetSize( 460, 16 )

    local function BarButton( text, x, w, cmd )
        local btn = vgui.Create( "DButton", frame )
        btn:SetText( text )
        btn:SetPos( x, 620 - 36 )
        btn:SetSize( w, 26 )
        btn.DoClick = function()
            if ( cmd == "close" ) then
                frame:Close()
                m_Frame = nil
                return
            end

            if ( cmd == "enableall" or cmd == "disableall" ) then
                local want = ( cmd == "enableall" )
                local applied = true
                for _, entry in ipairs( rows ) do
                    if ( not SetEnabled( entry.key, want ) ) then applied = false end
                end
                Status( applied )
            end

            if ( m_Frame and m_Frame.Close ) then m_Frame:Close() end
            m_Frame = nil
            Open()
        end
        return btn
    end

    BarButton( STR.EnableAll, 10, 100, "enableall" )
    BarButton( STR.DisableAll, 118, 100, "disableall" )
    BarButton( STR.Refresh, 226, 76, "refresh" )
    BarButton( STR.Close, 370, 100, "close" )

    return frame
end

-- ---------------------------------------------------------------------------
-- entry points
-- ---------------------------------------------------------------------------

-- HL2SB: assignment, not "local function" - the forward declaration above is what the
-- dialog's own Reopen() closure captures.
Open = function()
    if ( m_UseDerma and derma and derma.DefineControl ) then
        local ok, frame = pcall( OpenDerma )
        if ( ok and frame ) then return frame end
        Say( "[HL2SB] addonsdialog: derma UI failed (" .. tostring( frame ) .. ") - using the plain one" )
    end

    local ok2, frame2 = pcall( OpenPlain )
    if ( not ok2 ) then
        Say( "[HL2SB] addonsdialog: plain UI failed: " .. tostring( frame2 ) )
        return nil
    end
    return frame2
end

local function CloseAndOpen()
    if ( m_Frame and m_Frame.Close ) then m_Frame:Close() end
    m_Frame = nil
    return Open()
end

concommand.Create( "OpenAddonsDialog", function()
    CloseAndOpen()
end, "Open the HL2SB addon manager.", FCVAR_CLIENTDLL )

-- The GMod-style window is opt-in: the menu realm paints the plain controls
-- reliably, while the derma one needs the whole stack (derma + vgui_base) to
-- have loaded.  This switches and reopens.
concommand.Create( "hl2sb_addons_derma", function()
    -- The derma stack is a client-realm feature; the menu realm has the engine
    -- controls only.  Say so instead of pretending the switch did something.
    if ( not ( derma and derma.DefineControl ) ) then
        Say( "[HL2SB] addonsdialog: derma is not loaded in the main menu - the plain UI is the only one available here" )
        CloseAndOpen()
        return
    end

    m_UseDerma = not m_UseDerma
    Say( "[HL2SB] addonsdialog: derma UI " .. ( m_UseDerma and "ON" or "OFF" ) )
    CloseAndOpen()
end, "Toggle the GMod-style (derma) addon manager window.", FCVAR_CLIENTDLL )
