--[[----------------------------------------------------------------------------
    HL2SB: main-menu Addons manager.

    Two front ends, same engine work behind both:

      PLAIN  (default)  engine controls (Frame/Label/Button/CheckButton/TextEntry
                        plus plain LPanel containers) with an explicit CJK font,
                        a layout computed in one place, text colours and no
                        resizable borders.  This is the one that reliably paints
                        in the menu realm, and the main menu is Source UI
                        territory anyway.
                        The addon list is a wheel-scrollable viewport (clipped
                        canvas child, painted scrollbar thumb) - every addon is
                        reachable however long the list is.  A GMod-style info
                        card beside the list shows the selected addon's title,
                        author, type, mount state, path and description; the
                        card follows the row you toggle.

      TOUCH  (system.IsAndroid())  the PLAIN front end with phone metrics, the
                        same switch the derma skin's hl2sb_touch_ui default
                        uses: the dialog fills the screen in ONE column (list
                        on top, the info card as a bottom sheet), rows are 40px
                        with a 20px font, and the scrollbar strip is 24px wide
                        and drag-scrollable (mouse capture keeps the drag alive
                        outside the strip - a phone has no wheel).
                        `hl2sb_addons_touch` cycles a manual override:
                        auto (follow the detection) -> forced on -> forced off.

      DERMA  (opt-in)   the GMod-style window (DFrame/DScrollPanel/
                        DCheckBoxLabel).  Available with the console command
                        `hl2sb_addons_derma`, which toggles it and reopens.

    Scrolling in the menu realm
    ---------------------------
    The realm has no layout pump, so geometry lands only through the
    HL2SB_MenuLayout() pass.  The viewport scroll works the same way: the wheel
    handler changes the canvas' recorded position (SetPos( 0, -scroll )) and
    then drives HL2SB_MenuLayout( viewport ) to apply it natively.  Wheel input
    over a CheckButton row reaches the viewport because Panel forwards
    "MouseWheeled" up the parent chain into the wrapper's Lua OnMouseWheeled.
    Children are painted clipped to their parent chain, so the rows pushed
    above the viewport are simply not drawn.

    What "disabling" does
    ---------------------
    An addon is a folder under addons/ (or a .gma archive, which the filesystem
    mounts READ-ONLY IN PLACE -- GMod style, nothing is extracted).  Both are
    MOUNTED as search paths at startup
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

-- Touch layout switch: the same default the derma skin's hl2sb_touch_ui
-- convar uses (system.IsAndroid(); never IsLinux - that is also true on
-- desktop).  The menu realm opens the Systems lib for exactly this
-- (luasrc_init_gameui); without it the desktop layout runs.
-- `hl2sb_addons_touch` cycles a manual override on top of the detection:
-- auto -> forced on -> forced off -> auto.
local TOUCH_AUTO = ( system and system.IsAndroid and system.IsAndroid() ) and true or false
local TOUCH_MODE = 0    -- 0 = follow the detection, 1 = force touch, 2 = force desktop

local function TouchUI()
    return ( TOUCH_MODE == 1 ) or ( TOUCH_MODE == 0 and TOUCH_AUTO )
end

local STR = {
    Title      = "插件管理",
    Hint       = "取消勾选的插件不会被挂载。修改立即生效；已进入地图时则在下次启动生效。",
    Hint2      = "滚轮滚动列表，点击行看信息",
    Empty      = "addons/ 目录中没有找到插件",
    Stats      = "共 %d 个插件，已启用 %d 个",
    StatsTouch = "，点击行看信息卡",
    EnableAll  = "启用全部",
    DisableAll = "禁用全部",
    Refresh    = "刷新",
    Close      = "关闭",
    Filter     = "筛选",
    NoDesc     = "（没有描述信息）",
    CardEmpty  = "点击左侧的插件行，在这里显示插件信息。",
    AppliedNow     = "已立即生效",
    AppliedRestart = "已在地图中：已保存，下次启动生效",
}

-- ---------------------------------------------------------------------------
-- fonts: the scheme's "Default" is a small bitmap face and everything CJK in
-- it is unreadable, so the dialog defines its own (GMod-style: the UI layer
-- owns its fonts; luaL_checkfont accepts the NAME).
-- ---------------------------------------------------------------------------

local FONT_TEXT  = "HL2SB_MenuText"
local FONT_TITLE = "HL2SB_MenuTitle"
local FONT_TOUCH = "HL2SB_MenuTextTouch"   -- rows in the touch layout
local m_FontsReady = false

local function MakeFonts()
    if ( not surface or not surface.CreateFont ) then return end

    surface.CreateFont( FONT_TEXT, { font = "Microsoft YaHei", size = 15, weight = 500, extended = true } )
    surface.CreateFont( FONT_TITLE, { font = "Microsoft YaHei", size = 17, weight = 800, extended = true } )
    -- always created: the touch layout can be forced onto a desktop with
    -- hl2sb_addons_touch, so the font must exist regardless of the detection
    surface.CreateFont( FONT_TOUCH, { font = "Microsoft YaHei", size = 20, weight = 500, extended = true } )
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

-- engine-name surface draws: the surface lib here spells them DrawSetColor /
-- DrawFilledRect / DrawOutlinedRect (GMod's SetDrawColor/DrawRect aliases are
-- a client-realm extension and may not exist in the menu state).
local DrawSetColor     = surface and surface.DrawSetColor or nil
local DrawFilledRect   = surface and surface.DrawFilledRect or nil
local DrawOutlinedRect = surface and surface.DrawOutlinedRect or nil

-- engine DrawFilledRect takes corner coordinates
local function FillRect( x, y, w, h )
    if ( DrawFilledRect == nil ) then return end
    DrawFilledRect( x, y, x + w, y + h )
end

-- ---------------------------------------------------------------------------
-- metrics
-- ---------------------------------------------------------------------------

local ROW_H     = 26                   -- derma front end rows; the plain front
                                       -- end sizes everything per open, because
                                       -- the touch override is runtime-switchable
local DIALOG_W  = 680                  -- desktop window width (touch fills the screen)

-- ---------------------------------------------------------------------------
-- state
-- ---------------------------------------------------------------------------

local m_Frame        = nil
local m_Filter       = ""
local m_Status       = nil
local m_UseDerma     = false        -- opt-in: hl2sb_addons_derma

-- ---------------------------------------------------------------------------
-- the addons
-- ---------------------------------------------------------------------------

-- Parse a .gma header for its addon metadata (GMod shows title/author in its
-- Addons panel; we do the same).  Pure Lua over file.Open -- the .gma header
-- is: "GMAD" + version byte, v3+: 16 bytes (steamid+timestamp), a NUL-list of
-- required content ended by an empty string, then name/description/author as
-- NUL-terminated strings.  Returns title, author, description (or nothing).
local function ReadGmaInfo( gmaName )
    if ( not file.Open ) then return nil end
    local f = file.Open( "addons/" .. gmaName, "rb", "MOD" )
    if ( not f ) then return nil end

    local function cstring( max )
        local chars = {}
        for _ = 1, max or 4096 do
            local b = f:Read( 1 )
            if ( not b or b == "" ) then return nil end
            local c = b:byte()
            if ( c == 0 ) then return table.concat( chars ) end
            chars[ #chars + 1 ] = b
        end
        return table.concat( chars )
    end

    local title, author, desc

    repeat
        local magic = f:Read( 4 )
        if ( magic != "GMAD" ) then break end

        local verByte = f:Read( 1 )
        local ver = verByte and verByte:byte() or 0
        if ( ver < 1 or ver > 3 ) then break end

        if ( ver >= 3 ) then
            f:Read( 16 )        -- steamid + timestamp
        end

        -- required content: NUL-separated, ended by an empty string
        local broken = false
        for _ = 1, 64 do
            local s = cstring( 1024 )
            if ( s == nil ) then broken = true break end
            if ( s == "" ) then break end
        end
        if ( broken ) then break end

        title  = cstring()
        desc   = cstring()
        author = cstring()
    until true

    f:Close()

    if ( not title or title == "" ) then return nil end
    return title, author, desc
end

-- Folder addons may carry GMod's addon.json (title/author/description/type).
-- A real JSON parser is overkill for a metadata card; scanning the flat
-- "key": "value" string fields covers every key this dialog shows.
local function ReadAddonJson( name )
    if ( not file.Open ) then return nil end
    local f = file.Open( "addons/" .. name .. "/addon.json", "r", "MOD" )
    if ( not f ) then return nil end

    local n = f:Size()
    local text = ( n and n > 0 ) and f:Read( n ) or nil
    f:Close()
    if ( not text or text == "" ) then return nil end

    local out = {}
    for key, val in text:gmatch( '"([%w_]+)"%s*:%s*"(.-)"' ) do
        out[ key:lower() ] = val:gsub( '\\(.)', '%1' )
    end
    return out
end

local m_GmaInfo  = {}    -- archive file name -> { title = , author = , desc = }
local m_JsonInfo = {}    -- folder name -> parsed addon.json string fields

local function ListAddons()
    local out = {}

    local files, dirs = file.Find( "addons/*", "MOD" )

    for _, name in ipairs( dirs or {} ) do
        if ( name:sub( 1, 1 ) != "." ) then
            local entry = { name = name, key = name:lower(), isGma = false }

            -- addon.json metadata, cached per dialog session
            local info = m_JsonInfo[ name ]
            if ( info == nil ) then
                info = ReadAddonJson( name ) or {}
                m_JsonInfo[ name ] = info
            end
            entry.title     = info.title
            entry.author    = info.author
            entry.addonType = info.type
            entry.desc      = info.description or info.desc

            out[ #out + 1 ] = entry
        end
    end

    for _, name in ipairs( files or {} ) do
        if ( name:lower():sub( -4 ) == ".gma" ) then
            local base = name:sub( 1, -5 )
            local entry = { name = name, key = base:lower(), isGma = true }

            -- addon metadata straight out of the archive header (cached per
            -- dialog session; reading it is a few header bytes)
            local info = m_GmaInfo[ name ]
            if ( info == nil ) then
                local title, author, desc = ReadGmaInfo( name )
                info = { title = title, author = author, desc = desc }
                m_GmaInfo[ name ] = info
            end
            entry.title, entry.author, entry.desc = info.title, info.author, info.desc

            out[ #out + 1 ] = entry
        end
    end

    table.sort( out, function( a, b ) return a.key < b.key end )
    return out
end

-- What a row shows: GMod style title (by author) when the addon carries one
-- (gma header or addon.json), otherwise the file/folder name.
local function DisplayName( entry )
    if ( entry.title and entry.title != "" and entry.title:lower() != entry.name:lower() ) then
        local s = entry.title
        if ( entry.author and entry.author != "" ) then
            s = s .. "  -  " .. entry.author
        end
        return s
    end
    return entry.name .. ( entry.isGma and "  [GMA]" or "" )
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
        local hay = entry.name:lower()
        if ( entry.title ) then hay = hay .. "\n" .. entry.title:lower() end
        if ( query == "" or hay:find( query, 1, true ) ) then
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
    -- effective layout mode for THIS open - the override command may have
    -- flipped it since the file loaded
    local TOUCH    = TouchUI()
    local ROW_H    = TOUCH and 40 or 26
    local M        = TOUCH and 10 or 14
    local SB_W     = TOUCH and 24 or 12
    local FONT_ROW = TOUCH and FONT_TOUCH or FONT_TEXT

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
    -- right-hand column past its edge.  The height is re-asserted after the
    -- layout math.
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

    -- Screen size for the touch layout (menu realm has ScrW/ScrH via
    -- gmod_globals, but the surface binding is the direct source here).
    local scrW, scrH = 1280, 720
    if ( surface and surface.GetScreenSize ) then
        local w2, h2 = surface.GetScreenSize()
        if ( w2 and w2 > 0 and h2 and h2 > 0 ) then scrW, scrH = w2, h2 end
    end

    -- Column geometry: two columns on the desktop (list left, card right); a
    -- single column on touch screens (list on top, card as a bottom sheet).
    local fw, listW, cardX, cardW, cardH, listH, searchW
    if ( TOUCH ) then
        fw      = math.max( 480, scrW - 24 )
        listW   = fw - M * 2
        cardX   = M
        cardW   = listW
        cardH   = 170
        searchW = listW - 86
    else
        fw      = DIALOG_W
        listW   = 330
        cardX   = M + listW + 16
        cardW   = fw - M - cardX
        cardH   = 340
        searchW = 250
    end

    -- The touch window fills the screen; the list gets whatever is left after
    -- the header stack, the card sheet and the button bar reserve theirs.
    if ( TOUCH ) then
        local frameH = math.max( 360, scrH - 32 )
        listH = frameH - ( 30 + 42 + 32 + 26 ) - 8 - cardH - 8 - 26 - 8 - 26 - M
    else
        listH = 340
    end
    listH = math.max( listH, ROW_H * 4 )

    -- Every control that gets an explicit position is recorded here, because in this
    -- (GameUI) state SetSize() takes effect immediately but SetPos() does not: positions
    -- are only applied by a vgui layout pass.  ReassertPositions() replays the table
    -- through the native setters and drives HL2SB_MenuLayout().
    local Layout = {}

    local function Record( pnl, x, y, w, h )
        if ( pnl == nil ) then return nil end
        pnl:SetBounds( x, y, w, h )
        Layout[ #Layout + 1 ] = { pnl, x, y, w, h }
        return pnl
    end

    local function NewLabel( parentPanel, x, y, w, text, h )
        if ( not vgui.Create ) then return nil end
        local lbl = vgui.Create( "Label", parentPanel or frame )
        if ( lbl == nil ) then return nil end
        if ( lbl.SetWrap ) then lbl:SetWrap( true ) end
        lbl:SetText( text or "" )
        ApplyFont( lbl, FONT_ROW )
        Colour( lbl, COL_TEXT )
        return Record( lbl, x, y, w, h or 20 )
    end

    local function NewButton( text, x, y, w, h, cmd )
        if ( not vgui.Button ) then return nil end
        local btn = vgui.Button( frame, "addons_" .. cmd, text, frame, cmd )
        if ( btn == nil ) then return nil end
        ApplyFont( btn, FONT_ROW )
        return Record( btn, x, y, w, h )
    end

    -- ---- scroll state (per open; shared with the closures below) -----------
    local canvasH   = #rows * ROW_H
    local scroll    = 0
    local maxScroll = math.max( 0, canvasH - listH )
    local selectedKey = nil

    local viewport = nil
    local canvas   = nil

    -- SetPos only lands through a layout pass in this realm: record the new
    -- canvas position, then make HL2SB_MenuLayout apply it natively.
    local function ScrollApply()
        if ( canvas and canvas.SetPos ) then
            canvas:SetPos( 0, -scroll )
        end
        if ( HL2SB_MenuLayout and viewport ) then
            HL2SB_MenuLayout( viewport )
        end
    end

    local function SetScroll( v )
        local nv = math.max( 0, math.min( v, maxScroll ) )
        if ( nv != scroll ) then
            scroll = nv
            ScrollApply()
        end
    end

    local function ScrollBy( delta )
        if ( maxScroll <= 0 ) then return end
        SetScroll( scroll - delta * 40 )
    end

    -- ---- layout: every block reserves its space, in order -------------------
    -- The layout measures from the computed width, NOT from frame:GetWide().
    -- An earlier version "adapted to the real width" and committed it at the
    -- end with SetSize( fw, y ): before the frame has laid out, GetWide()
    -- answers something small (the panel's default), so that logic SHRANK the
    -- window to a strip and every line of text ran into the next.
    local innerW = fw - M * 2
    local y      = 30

    NewLabel( frame, M, y, innerW, STR.Hint, 36 )  -- two wrapped lines
    y = y + 42

    local search = nil
    if ( vgui.TextEntry ) then
        search = vgui.TextEntry( frame, "addonsSearch" )
        if ( search.SetText ) then search:SetText( m_Filter or "" ) end
        ApplyFont( search, FONT_ROW )
        Record( search, M, y, searchW, 24 )
        NewButton( STR.Filter, M + searchW + 8, y, 70, 24, "applyfilter" )
    end
    y = y + 32

    local statsText = string.format( STR.Stats, #addons, enabledCount )
    if ( TOUCH ) then statsText = statsText .. STR.StatsTouch end
    NewLabel( frame, M, y, listW, statsText, 20 )
    if ( not TOUCH ) then
        NewLabel( frame, cardX, y, cardW, STR.Hint2, 20 )
    end
    y = y + 26

    local rowsTop = y

    -- ---- the scroll viewport ------------------------------------------------
    -- A plain panel the wheel scrolls over; its bounds clip the canvas child,
    -- so rows pushed above the top are not drawn (vgui2 clips children to the
    -- parent chain while painting).
    viewport = vgui.Panel( frame, "addonsViewport" )
    Record( viewport, M, rowsTop, listW, listH )
    viewport.OnMouseWheeled = function( pnl, delta ) ScrollBy( delta ) end

    -- ---- the scrollbar (painted thumb; drag-scrollable) ----------------------
    local scrollbar = vgui.Panel( viewport, "addonsScrollbar" )
    Record( scrollbar, listW - SB_W, 0, SB_W, listH )

    local dragging = false
    local dragY    = nil

    scrollbar.OnMousePressed = function( pnl, code )
        if ( code != MOUSE_LEFT or maxScroll <= 0 ) then return end
        dragging = true
        dragY = nil
        -- keep the drag alive when the finger leaves the strip
        if ( surface and surface.EnableMouseCapture ) then
            surface.EnableMouseCapture( pnl, true )
        end
    end

    scrollbar.OnCursorMoved = function( pnl, x, y )
        if ( not dragging or maxScroll <= 0 ) then return end
        if ( dragY == nil ) then dragY = y return end
        -- thumb pixels -> content pixels: the full track maps onto maxScroll
        local track = math.max( 1, listH - 40 )
        SetScroll( scroll + ( y - dragY ) * ( canvasH / track ) )
        dragY = y
    end

    scrollbar.OnMouseReleased = function( pnl, code )
        if ( dragging and surface and surface.EnableMouseCapture ) then
            surface.EnableMouseCapture( pnl, false )
        end
        dragging = false
        dragY = nil
    end

    local scrollbarPainted = false
    scrollbar.Paint = function( pnl, w, h )
        if ( maxScroll <= 0 or canvasH <= 0 or DrawFilledRect == nil ) then return end
        local barW = TOUCH and 12 or 5
        if ( not scrollbarPainted ) then
            scrollbarPainted = true
            Say( string.format( "[HL2SB] addonsdialog: scrollbar thumb painting (%d rows, panel %dx%d, thumb %dpx, maxScroll %d)",
                #rows, w, h, barW, maxScroll ) )
        end
        DrawSetColor( 255, 255, 255, 24 )
        FillRect( w - barW - 3, 1, barW + 3, h - 2 )
        local track = h - 6
        local thumbH = math.max( TOUCH and 64 or 36, math.floor( track * h / ( h + maxScroll ) ) )
        local thumbY = 3 + math.floor( ( track - thumbH ) * ( scroll / maxScroll ) + 0.5 )
        DrawSetColor( 180, 180, 180, 235 )
        FillRect( w - barW - 2, thumbY, barW, thumbH )
    end

    canvas = vgui.Panel( viewport, "addonsCanvas" )
    Record( canvas, 0, 0, listW - SB_W - 4, math.max( canvasH, listH ) )

    -- ---- the info card (GMod-style: details beside the list) ----------------
    local card = vgui.Panel( frame, "addonsCard" )
    local cardY = TOUCH and ( rowsTop + listH + 8 ) or rowsTop
    Record( card, cardX, cardY, cardW, cardH )
    card.PaintBackground = function( pnl )
        if ( DrawFilledRect == nil ) then return end
        local w, h = pnl:GetWide(), pnl:GetTall()
        DrawSetColor( 38, 38, 38, 248 )
        FillRect( 0, 0, w, h )
        DrawSetColor( 76, 76, 76, 255 )
        DrawOutlinedRect( 0, 0, w - 1, h - 1 )
    end

    local function NewCardLabel( y2, h, clr, font )
        local lbl = vgui.Create( "Label", card )
        if ( lbl == nil ) then return nil end
        if ( lbl.SetWrap ) then lbl:SetWrap( true ) end
        lbl:SetText( "" )
        ApplyFont( lbl, font or FONT_TEXT )
        Colour( lbl, clr or COL_TEXT )
        return Record( lbl, 10, y2, cardW - 20, h )
    end

    -- the touch sheet is shorter: compact label rows
    local nameY, nameH, metaY, authY, pathY, descY
    if ( TOUCH ) then
        nameY, nameH, metaY, authY, pathY, descY = 6, 32, 40, 58, 76, 96
    else
        nameY, nameH, metaY, authY, pathY, descY = 10, 40, 54, 74, 94, 118
    end

    local cardName   = NewCardLabel( nameY, nameH, COL_TITLE, FONT_TITLE )
    local cardMeta   = NewCardLabel( metaY, 18, COL_DIM )
    local cardAuthor = NewCardLabel( authY, 18, COL_TEXT )
    local cardPath   = NewCardLabel( pathY, 18, COL_DIM )
    local cardDesc   = NewCardLabel( descY, cardH - descY - 8, COL_TEXT )

    local function TrimDesc( s )
        if ( s == nil ) then return nil end
        s = s:gsub( "\r", "" )
        if ( #s > 600 ) then s = s:sub( 1, 600 ) .. "..." end
        return s
    end

    local function ShowCard( entry )
        if ( cardName == nil ) then return end

        if ( entry == nil ) then
            selectedKey = nil
            cardName:SetText( STR.CardEmpty )
            cardMeta:SetText( "" )
            cardAuthor:SetText( "" )
            cardPath:SetText( "" )
            cardDesc:SetText( "" )
            return
        end

        selectedKey = entry.key
        cardName:SetText( DisplayName( entry ) )

        local bits = { entry.isGma and "GMA 归档" or "文件夹" }
        if ( entry.addonType and entry.addonType != "" ) then bits[ #bits + 1 ] = entry.addonType end
        bits[ #bits + 1 ] = disabled[ entry.key ] and "已禁用" or "已启用"
        cardMeta:SetText( table.concat( bits, "  ·  " ) )

        cardAuthor:SetText( ( entry.author and entry.author != "" ) and ( "作者: " .. entry.author ) or "" )
        cardPath:SetText( "addons/" .. entry.name )
        cardDesc:SetText( TrimDesc( entry.desc ) or STR.NoDesc )
    end

    -- ---- the rows ------------------------------------------------------------
    for i = 1, #rows do
        local entry = rows[ i ]

        -- The wrapper panel is the paint surface for the selection highlight;
        -- wheel input over the row also lands here (CheckButton forwards
        -- "MouseWheeled" up the parent chain into this LPanel's dispatcher).
        local wrap = vgui.Panel( canvas, "addonsRow_" .. i )
        Record( wrap, 0, ( i - 1 ) * ROW_H, listW - SB_W - 4, ROW_H )
        wrap.OnMouseWheeled = function( pnl, delta ) ScrollBy( delta ) end
        wrap.Paint = function( pnl, w, h )
            if ( entry.key != selectedKey or DrawFilledRect == nil ) then return end
            DrawSetColor( 255, 255, 255, 14 )
            FillRect( 0, 0, w, h )
            DrawSetColor( 96, 160, 240, 255 )
            FillRect( 0, 0, 2, h )
        end

        local cb = nil
        if ( vgui.CheckButton ) then cb = vgui.CheckButton( wrap, "addon_" .. i, DisplayName( entry ) ) end
        if ( cb ~= nil ) then
            Record( cb, 0, 0, listW - SB_W - 4, ROW_H )
            cb:SetSelected( not disabled[ entry.key ] )
            ApplyFont( cb, FONT_ROW )
            cb.OnCheckButtonChecked = function( btn )
                -- keep the snapshot current so the card shows the live state
                disabled[ entry.key ] = not btn:IsChecked()
                Status( SetEnabled( entry.key, btn:IsChecked() ) )
                ShowCard( entry )
            end
        end
    end

    if ( #rows == 0 ) then
        NewLabel( viewport, 6, 4, listW - SB_W - 16, STR.Empty, 20 )
    end
    ShowCard( rows[ 1 ] )   -- nil shows the hint text

    -- ---- status + button bar -------------------------------------------------
    local statusY = TOUCH and ( cardY + cardH + 8 ) or ( rowsTop + listH + 8 )
    m_Status = NewLabel( frame, M, statusY, innerW, "", 20 )
    y = statusY + 26

    NewButton( STR.EnableAll,  M,      y, 100, 26, "enableall" )
    NewButton( STR.DisableAll, M+108,  y, 100, 26, "disableall" )
    NewButton( STR.Refresh,    M+216,  y,  80, 26, "refresh" )
    NewButton( STR.Close,      fw - M - 100, y, 100, 26, "Close" )
    y = y + 26 + M

    -- ---- the frame itself ---------------------------------------------------
    -- Set the size and KEEP it: the requested width and the height the layout
    -- just computed.
    frame:SetSize( fw, y )
    frame:MoveToCenterOfScreen()

    -- children are laid out once here; a border resize would leave them behind
    -- (big blank areas), so the frame is not resizable
    if ( frame.SetSizeable ) then frame:SetSizeable( false ) end

    Say( string.format( "[HL2SB] addonsdialog: %s layout %dx%d, %d addons (%d filtered), list %dpx (canvas %dpx, scroll max %d)",
        TOUCH and "touch" or "desktop", fw, y, #addons, #rows, listH, canvasH, maxScroll ) )

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
                disabled[ entry.key ] = not want
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
    -- vgui2 applies child geometry in a layout pass, and nothing drives that
    -- pass for a menu-state frame on its own.  InvalidateLayout( true )
    -- performs the pass IMMEDIATELY; HL2SB_MenuLayout() additionally re-applies
    -- each panel's recorded geometry through the native setters (the part this
    -- realm never does by itself).
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

    -- ...and once more on the next frame: by then the frame is actually up,
    -- which is when the first pass normally happens.
    if ( timer and timer.Simple ) then
        timer.Simple( 0, function()
            if ( frame == nil or frame.SetBounds == nil ) then return end
            ReassertPositions()
        end )
    end

    -- Last word on the size: activating runs the scheme/layout pass, and the
    -- window must not end up smaller than what everything above was laid out
    -- for (that is exactly how it once collapsed into a strip).
    frame:SetSize( fw, y )

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
        row:SetText( DisplayName( entry ) )
        if ( entry.desc and entry.desc != "" and row.SetTooltip ) then
            row:SetTooltip( entry.desc )
        end
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

-- Manual override for the touch layout: cycles AUTO (follow the platform
-- detection) -> FORCED ON -> FORCED OFF, reopening the dialog so the new
-- mode applies immediately.
concommand.Create( "hl2sb_addons_touch", function()
    TOUCH_MODE = ( TOUCH_MODE + 1 ) % 3

    local state
    if ( TOUCH_MODE == 0 ) then
        state = "AUTO (" .. ( TOUCH_AUTO and "android detected" or "desktop detected" ) .. ")"
    elseif ( TOUCH_MODE == 1 ) then
        state = "FORCED ON"
    else
        state = "FORCED OFF"
    end
    Say( "[HL2SB] addonsdialog: touch layout " .. state )

    CloseAndOpen()
end, "Cycle the addon manager layout mode: auto, forced touch, forced desktop.", FCVAR_CLIENTDLL )
