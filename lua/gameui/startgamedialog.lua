--[[----------------------------------------------------------------------------
    HL2SB: main-menu "Start Game (Lua)" dialog.

    The Lua twin of gameui's CCreateMultiplayerGameDialog, kept side by side so
    the two can be compared live (gamemenu.res entries 9 and 9b).  Everything
    the C++ dialog does is redone here on the menu-realm scripted controls:

      * map grid with maps/thumb/<name>.png cards, category filter on the left
      * server name / password / max players / LAN
      * the sandbox.txt settings list (gamemodes/<active>/<active>.txt, GMod's
        own "server settings from the gamemode file" design): Numeric rows and
        CheckBox rows generated from the file, so adding a settings entry to
        sandbox.txt grows this dialog without code changes
      * the values ride to the server in ServerConfig.vdf; sandbox's
        HL2SB_ApplyStartOptions() applies them once the convars exist

    Differences from the C++ dialog (deliberate):
      * max players defaults to 2 (the C++ one defaults to the single player
        row), per user requirement
      * the settings section only shows when the selected player count is not
        the single player row; the single player row keeps the small
        singleplayer-flagged set (fall damage, max ammo, loadout, godmode,
        suit), matching the C++ sidebar
      * no P2P controls: this engine has no GMod Steam P2P layer, so
        p2p_enabled / p2p_friendsonly would be dead controls

    Realm notes (see addonsdialog.lua for the full story): this menu state has
    no layout pump, so every position goes through Record() and is applied by
    ReassertPositions() + HL2SB_MenuLayout(); the settings scroll viewport is
    the same wheel/drag construction as the Addons dialog; strings come from
    the engine localize files through Localizations.Find (UTF-8 on the Lua
    side) so both dialogs share the same tokens.
------------------------------------------------------------------------------]]

if ( not engine or not engine.GetGameDirectory ) then print( "[HL2SB] startgamedialog: no engine.GetGameDirectory" ) return end
if ( not vgui or not vgui.Panel ) then print( "[HL2SB] startgamedialog: no vgui" ) return end
if ( not file or not file.Find ) then print( "[HL2SB] startgamedialog: no file lib" ) return end

require( "concommand" )

-- util.KeyValuesToTable lives in an extensions file that only installs itself
-- when the util table already exists; the menu realm never opened the C util
-- library, so seed the table before including it.
util = util or {}
include( "includes/extensions/hl2sb_util_keyvalues.lua" )
local KeyValuesToTable = ( util ~= nil and util.KeyValuesToTable ) or nil

local FCVAR_CLIENTDLL = _E and _E.FCVAR and _E.FCVAR.CLIENTDLL or 0

local Say = ( type( print ) == "function" and print ) or function() end

MOUSE_LEFT  = MOUSE_LEFT  or ( _E and _E.MOUSE_LEFT )  or 107

-- ---------------------------------------------------------------------------
-- touch switch: system.IsAndroid() detection + hl2sb_startgame_touch cycling
-- auto -> forced touch -> forced desktop (same shape as the Addons dialog).
-- ---------------------------------------------------------------------------

local TOUCH_AUTO = ( system and system.IsAndroid and system.IsAndroid() ) and true or false
local TOUCH_MODE = 0    -- 0 = follow detection, 1 = force touch, 2 = force desktop

local function TouchUI()
    return ( TOUCH_MODE == 1 ) or ( TOUCH_MODE == 0 and TOUCH_AUTO )
end

-- ---------------------------------------------------------------------------
-- fonts: Microsoft YaHei for CJK, own names so the two dialogs stay independent
-- ---------------------------------------------------------------------------

local FONT_TEXT  = "HL2SB_StartText"
local FONT_TITLE = "HL2SB_StartTitle"
local FONT_TOUCH = "HL2SB_StartTextTouch"
local m_FontsReady = false

-- Windows: Microsoft YaHei, a system font since Vista and the same face the
-- mod's own clientscheme.res already declares.  Android: the launcher ships
-- DroidSansFallback.ttf in its assets - that is the CJK face there.
local FONT_FACE = ( system ~= nil and system.IsAndroid ~= nil and system.IsAndroid() )
    and "DroidSansFallback" or "Microsoft YaHei"

local function MakeFonts()
    if ( not surface or not surface.CreateFont ) then return end
    surface.CreateFont( FONT_TEXT,  { font = FONT_FACE, size = 16, weight = 600, extended = true } )
    surface.CreateFont( FONT_TITLE, { font = FONT_FACE, size = 18, weight = 800, extended = true } )
    surface.CreateFont( FONT_TOUCH, { font = FONT_FACE, size = 21, weight = 600, extended = true } )
    m_FontsReady = true
end

MakeFonts()

local function ApplyFont( panel, name )
    if ( m_FontsReady and panel and panel.SetFont ) then
        panel:SetFont( name )
    end
    return panel
end

local COL_TEXT  = Color and Color( 235, 235, 235 ) or nil
local COL_TITLE = Color and Color( 255, 255, 255 ) or nil
local COL_DIM   = Color and Color( 175, 175, 175 ) or nil

local DrawSetColor     = surface and surface.DrawSetColor or nil
local DrawFilledRect   = surface and surface.DrawFilledRect or nil
local DrawOutlinedRect = surface and surface.DrawOutlinedRect or nil
local DrawTexturedRect = surface and surface.DrawTexturedRect or nil

local function FillRect( x, y, w, h )
    if ( DrawFilledRect == nil ) then return end
    DrawFilledRect( x, y, x + w, y + h )
end

-- ---------------------------------------------------------------------------
-- localization: resolve a token to a UTF-8 string through the engine localize
-- files (the same files the C++ dialog's "#token" labels use).
-- ---------------------------------------------------------------------------

local function T( token )
    if ( Localizations ~= nil and Localizations.Find ~= nil ) then
        local ok, s = pcall( Localizations.Find, token )
        if ( ok and s ~= nil and s != "" ) then return s end
    end
    return token
end

-- ---------------------------------------------------------------------------
-- categories (same shape as the C++ dialog's MAPCAT_* set)
-- ---------------------------------------------------------------------------

local MAPCAT_ALL, MAPCAT_HL2, MAPCAT_HL2DM, MAPCAT_SANDBOX, MAPCAT_OTHER = 1, 2, 3, 4, 5
local MAPCAT_COUNT = 5
local MAPCAT_TOKENS = {
    [ MAPCAT_ALL ]     = "HL2SB_MapCat_All",
    [ MAPCAT_HL2 ]     = "HL2SB_MapCat_HL2",
    [ MAPCAT_HL2DM ]   = "HL2SB_MapCat_HL2DM",
    [ MAPCAT_SANDBOX ] = "HL2SB_MapCat_Sandbox",
    [ MAPCAT_OTHER ]   = "HL2SB_MapCat_Other",
}

local function StartsWith( s, prefix )
    return string.sub( s, 1, string.len( prefix ) ) == prefix
end

local function MapNameToCategory( name )
    local lower = string.lower( name )
    -- prefix heuristics only.  file.Exists() with a game path ID is NOT a
    -- usable mount probe here: an unknown path ID falls back to searching
    -- everything, which classified every map as HL2 and left the other
    -- categories empty (observed in the first live test).
    if ( StartsWith( lower, "gm_" ) or StartsWith( lower, "sb_" ) or
         StartsWith( lower, "mm_" ) or StartsWith( lower, "rp_" ) ) then
        return MAPCAT_SANDBOX
    end
    if ( StartsWith( lower, "dm_" ) ) then return MAPCAT_HL2DM end
    if ( StartsWith( lower, "d1_" ) or StartsWith( lower, "d2_" ) or StartsWith( lower, "d3_" ) or
         StartsWith( lower, "ep1_" ) or StartsWith( lower, "ep2_" ) or
         StartsWith( lower, "background" ) or StartsWith( lower, "credits" ) or
         StartsWith( lower, "intro" ) or StartsWith( lower, "testchamber" ) ) then
        return MAPCAT_HL2
    end
    return MAPCAT_OTHER
end

local function ListMaps()
    local seen, out = {}, {}
    local files = file.Find( "maps/*.bsp", "GAME" )
    for _, name in ipairs( files or {} ) do
        if ( string.sub( string.lower( name ), -4 ) == ".bsp" ) then
            name = string.sub( name, 1, -5 )
        end
        local key = string.lower( name )
        if ( name ~= nil and name != "" and seen[ key ] == nil ) then
            seen[ key ] = true
            out[ #out + 1 ] = name
        end
    end
    table.sort( out )
    return out
end

-- ---------------------------------------------------------------------------
-- gamemode settings: gamemodes/<active>/<active>.txt "settings" section
-- ---------------------------------------------------------------------------

local function ActiveGamemode()
    local gm = "sandbox"
    if ( GetConVar ~= nil ) then
        local ok, cv = pcall( GetConVar, "gamemode" )
        if ( ok and cv ~= nil and cv.GetString ~= nil ) then
            local s = cv:GetString()
            if ( s ~= nil and s != "" ) then gm = s end
        end
    end
    return gm
end

local function LoadGamemodeSettings()
    local out = {}
    if ( KeyValuesToTable == nil ) then return out end

    local gm = ActiveGamemode()
    local txt = file.Read( "gamemodes/" .. gm .. "/" .. gm .. ".txt", "GAME" )
    if ( txt == nil ) then return out end

    local t = KeyValuesToTable( txt )
    local st = ( t ~= nil and type( t ) == "table" ) and t.settings or nil
    if ( type( st ) ~= "table" ) then return out end

    -- the numbered keys carry the file order
    local entries = {}
    for k, v in pairs( st ) do
        local n = tonumber( k )
        if ( n ~= nil and type( v ) == "table" and v.name ~= nil ) then
            entries[ #entries + 1 ] = { n, v }
        end
    end
    table.sort( entries, function( a, b ) return a[ 1 ] < b[ 1 ] end )

    for _, e in ipairs( entries ) do
        local v = e[ 2 ]
        out[ #out + 1 ] = {
            name         = tostring( v.name ),
            text         = tostring( v.text or v.name ),
            stype        = tostring( v.type or "Numeric" ),
            default      = tostring( v.default or "" ),
            singleplayer = ( tostring( v.singleplayer or "" ) == "1" ),
        }
    end
    return out
end

-- Which rows show where.
--   single player row: the small singleplayer-flagged set (the C++ sidebar's
--                      company: fall damage, max ammo, loadout, godmode, suit)
--   multiplayer rows:  everything else - the sandbox caps list, exactly the
--                      column the reference screenshot shows
local function VisibleSettings( settings, bSinglePlayer )
    local out = {}
    for _, s in ipairs( settings ) do
        if ( bSinglePlayer ) then
            if ( s.singleplayer and s.name != "sbox_persist" ) then
                out[ #out + 1 ] = s
            end
        else
            if ( s.stype != "Numeric" or not s.singleplayer ) then
                out[ #out + 1 ] = s
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- ServerConfig.vdf (the same file the C++ dialog reads and writes)
-- ---------------------------------------------------------------------------

local function LoadServerConfig()
    if ( KeyValuesToTable == nil ) then return {} end
    local txt = file.Read( "ServerConfig.vdf", "GAME" )
    if ( txt == nil ) then return {} end
    local t = KeyValuesToTable( txt )
    if ( t == nil or type( t ) ~= "table" ) then return {} end
    return t
end

local function SaveServerConfig( t )
    local parts = { '"ServerConfig"\n{\n' }
    local keys = {}
    for k in pairs( t ) do keys[ #keys + 1 ] = k end
    table.sort( keys )
    for _, k in ipairs( keys ) do
        parts[ #parts + 1 ] = '"' .. k .. '"\t"' .. tostring( t[ k ] ) .. '"\n'
    end
    parts[ #parts + 1 ] = '}\n'
    file.Write( "ServerConfig.vdf", table.concat( parts ), "GAME" )
end

-- ---------------------------------------------------------------------------
-- state
-- ---------------------------------------------------------------------------

local m_Frame           = nil
local m_SelectedMap     = nil
local m_SelectedCategory = MAPCAT_ALL
local m_PlayerCount     = 2      -- default per user requirement
local m_PlayersExpanded = false

local PLAYERS = { 1, 2, 4, 8, 16, 32, 64 }

local function PlayerLabel( n )
    if ( n == 1 ) then return T( "HL2SB_SinglePlayer" ) end
    local fmt = T( "HL2SB_StartGame_PlayersFmt" )
    if ( string.find( fmt, "%%d", 1, false ) == nil ) then return tostring( n ) end
    return string.format( fmt, n )
end

local function EntryValue( e )
    if ( e == nil ) then return "" end
    if ( e.GetValue ~= nil ) then
        local ok, v = pcall( e.GetValue, e )
        if ( ok and v ~= nil ) then return tostring( v ) end
    end
    return ""
end

local Open    -- forward declaration (Reopen() closures, same trap as addonsdialog)

local function Reopen()
    if ( m_Frame ~= nil and m_Frame.Close ~= nil ) then
        pcall( m_Frame.Close, m_Frame )
    end
    -- vgui "Close" only hides; without an explicit delete the whole tree is
    -- kept alive by the panel GC ("was still parented - kept alive" spam) and
    -- every reopen piled another ~130 panels on top.
    if ( m_Frame ~= nil and m_Frame.MarkForDeletion ~= nil ) then
        pcall( m_Frame.MarkForDeletion, m_Frame )
    end
    m_Frame = nil
    Open()
end

-- ---------------------------------------------------------------------------
-- the dialog
-- ---------------------------------------------------------------------------

Open = function()
    if ( m_Frame ~= nil ) then
        -- already open: just raise it
        if ( m_Frame.MoveToFront ~= nil ) then pcall( m_Frame.MoveToFront, m_Frame ) end
        return m_Frame
    end

    -- fonts created at file-load time can predate a usable surface; re-assert
    -- them on every open (CreateFont is idempotent for the same name+shape)
    MakeFonts()

    local TOUCH    = TouchUI()
    local FONT_ROW = TOUCH and FONT_TOUCH or FONT_TEXT

    local parent = ( VGui_GetGameUIPanel ~= nil ) and VGui_GetGameUIPanel() or nil
    if ( parent == nil ) then
        Say( "[HL2SB] startgamedialog: no GameUI root panel - frame is parentless" )
    end

    local scrW, scrH = 1280, 720
    if ( surface and surface.GetScreenSize ) then
        local w2, h2 = surface.GetScreenSize()
        if ( w2 and w2 > 0 and h2 and h2 > 0 ) then scrW, scrH = w2, h2 end
    end

    local frame = vgui.Frame( parent, "HL2SBStartGameDialog", true )
    if ( frame == nil ) then return nil end
    m_Frame = frame

    frame:SetTitle( T( "HL2SB_GameMenu_CreateServerLua" ) )

    local config    = LoadServerConfig()
    local settings  = LoadGamemodeSettings()
    local maps      = ListMaps()

    local bSinglePlayer = ( m_PlayerCount <= 1 )
    local rows          = VisibleSettings( settings, bSinglePlayer )

    -- saved state
    if ( m_SelectedMap == nil and config.map ~= nil ) then m_SelectedMap = tostring( config.map ) end
    if ( config.maxplayers ~= nil ) then
        local saved = tonumber( tostring( config.maxplayers ) )
        if ( saved ~= nil ) then m_PlayerCount = saved end
    end

    -- make sure the default map is legal
    local function MapAllowed( name )
        for _, m in ipairs( maps ) do
            if ( m == name ) then return true end
        end
        return false
    end
    if ( m_SelectedMap == nil or not MapAllowed( m_SelectedMap ) ) then
        -- first map of the active category, else first map at all
        m_SelectedMap = nil
        for _, m in ipairs( maps ) do
            if ( m_SelectedCategory == MAPCAT_ALL or MapNameToCategory( m ) == m_SelectedCategory ) then
                m_SelectedMap = m
                break
            end
        end
        if ( m_SelectedMap == nil and maps[ 1 ] ~= nil ) then m_SelectedMap = maps[ 1 ] end
    end

    -- -----------------------------------------------------------------------
    -- geometry
    -- -----------------------------------------------------------------------

    local fw, fh
    local cardW, cardH, cardGap
    local ROW_H = TOUCH and 40 or 26
    local M     = TOUCH and 10 or 14
    if ( TOUCH ) then
        fw, fh = scrW - 16, scrH - 16
        cardW, cardH, cardGap = 132, 158, 8
    else
        fw, fh = scrW, scrH
        cardW, cardH, cardGap = 150, 178, 10
    end

    local Layout = {}
    -- the "Map: x" summary label in the options column; card clicks update it
    -- live, so the closure below needs the upvalue declared up here
    local m_MapLabel = nil

    local function Record( pnl, x, y, w, h )
        if ( pnl == nil ) then return nil end
        pnl:SetPos( x, y )
        pnl:SetSize( w, h )
        Layout[ #Layout + 1 ] = { pnl, x, y, w, h }
        return pnl
    end

    -- Opaque backdrop, first child (bottom of the paint order).  Without this
    -- the whole dialog is transparent over the 3D menu background: antialiased
    -- glyph edges blend with the busy wallpaper (the "字体重影" look) and
    -- every panel reads as translucent.
    local bg = vgui.Panel( frame, "startBg" )
    if ( bg ~= nil ) then
        Record( bg, 0, 0, fw, fh )
        bg.Paint = function( pnl, w, h )
            if ( DrawFilledRect == nil ) then return end
            DrawSetColor( 34, 36, 40, 255 )
            FillRect( 0, 0, w, h )
        end
        if ( bg.SetZPos ~= nil ) then pcall( bg.SetZPos, bg, -100 ) end
    end

    local function NewLabel( parentPanel, x, y, w, text, h )
        local lbl = vgui.Create( "Label", parentPanel or frame )
        if ( lbl == nil ) then return nil end
        if ( lbl.SetWrap ~= nil ) then lbl:SetWrap( true ) end
        lbl:SetText( text or "" )
        ApplyFont( lbl, FONT_ROW )
        if ( lbl.SetTextColor ~= nil and COL_TEXT ~= nil ) then lbl:SetTextColor( COL_TEXT ) end
        return Record( lbl, x, y, w, h or 20 )
    end

    local function NewButton( parentPanel, x, y, w, h, text, cmd )
        local btn = vgui.Button( parentPanel or frame, "start_" .. cmd, text, frame, cmd )
        if ( btn == nil ) then return nil end
        ApplyFont( btn, FONT_ROW )
        return Record( btn, x, y, w, h )
    end

    -- ---- frame chrome -------------------------------------------------------
    Record( frame, TOUCH and 8 or 0, TOUCH and 8 or 0, fw, fh )

    -- the Frame chrome already shows the title; no second title label

    -- category column (vertical stack on desktop, one horizontal row on touch)
    local catX, catY, catW, catH, catStep
    if ( TOUCH ) then
        catX, catY = M, 46
        catW = math.floor( ( fw - M * 2 - 4 * 6 ) / MAPCAT_COUNT )
        catH, catStep = 36, catW + 6
    else
        catX, catY = math.floor( fw * 0.02 ), math.floor( fh * 0.16 )
        catW, catH, catStep = math.floor( fw * 0.14 ), 28, 34
    end
    for i = 1, MAPCAT_COUNT do
        local bx, by = catX, catY
        if ( TOUCH ) then bx = catX + ( i - 1 ) * catStep else by = catY + ( i - 1 ) * catStep end
        NewButton( frame, bx, by, catW, catH, T( MAPCAT_TOKENS[ i ] ), "mapcat_" .. i )
    end

    -- map grid viewport
    local mapX = TOUCH and M or math.floor( fw * 0.18 )
    local mapW = TOUCH and ( fw - M * 2 ) or math.floor( fw * 0.50 )
    local mapY = TOUCH and ( catY + catH + 8 ) or math.floor( fh * 0.16 )
    local mapBottom = TOUCH and math.floor( fh * 0.56 ) or math.floor( fh * 0.90 )
    local mapH = math.max( cardH + 20, mapBottom - mapY )

    -- options column
    local optX = TOUCH and M or math.floor( fw * 0.72 )
    local optW = ( TOUCH and ( fw - M * 2 ) or ( fw - optX - math.floor( fw * 0.02 ) ) )
    local optY = mapY

    -- ---- map grid (scroll viewport) -----------------------------------------
    local maps2 = {}
    for _, m in ipairs( maps ) do
        if ( m_SelectedCategory == MAPCAT_ALL or MapNameToCategory( m ) == m_SelectedCategory ) then
            maps2[ #maps2 + 1 ] = m
        end
    end

    local mapScroll, mapMaxScroll, mapCanvasH = 0, 0, 0
    local mapViewport = vgui.Panel( frame, "startMapViewport" )
    Record( mapViewport, mapX, mapY, mapW, mapH )
    local mapCanvas = nil    -- assigned below; Scroll closures use the upvalue

    local cols = math.max( 1, math.floor( ( mapW - 12 ) / ( cardW + cardGap ) ) )
    local mapRows = math.ceil( math.max( 1, #maps2 ) / cols )
    mapCanvasH = mapRows * ( cardH + cardGap ) + cardGap
    mapMaxScroll = math.max( 0, mapCanvasH - mapH )

    local function MapScrollApply()
        if ( mapCanvas ~= nil and mapCanvas.SetPos ~= nil ) then
            mapCanvas:SetPos( 0, -mapScroll )
        end
        if ( HL2SB_MenuLayout ~= nil ) then HL2SB_MenuLayout( mapViewport ) end
    end
    local function MapScrollBy( delta )
        if ( mapMaxScroll <= 0 ) then return end
        local nv = math.max( 0, math.min( mapScroll - delta * 40, mapMaxScroll ) )
        if ( nv != mapScroll ) then
            mapScroll = nv
            MapScrollApply()
        end
    end
    mapViewport.OnMouseWheeled = function( pnl, delta ) MapScrollBy( delta ) end

    mapCanvas = vgui.Panel( mapViewport, "startMapCanvas" )
    Record( mapCanvas, 0, 0, mapW - 12, math.max( mapCanvasH, mapH ) )

    for i = 1, #maps2 do
        local mapName = maps2[ i ]
        local cx = ( ( i - 1 ) % cols ) * ( cardW + cardGap ) + cardGap
        local cy = math.floor( ( i - 1 ) / cols ) * ( cardH + cardGap ) + cardGap

        local card = vgui.Panel( mapCanvas, "startMap_" .. i )
        Record( card, cx, cy, cardW, cardH )
        card.OnMouseWheeled = function( pnl, delta ) MapScrollBy( delta ) end
        card.OnMousePressed = function( pnl, code )
            if ( code != MOUSE_LEFT ) then return end
            -- live select: the Paint overrides read m_SelectedMap every frame,
            -- so just flip the state and refresh the summary label.  A full
            -- Reopen() here was the "every click reloads the page" behaviour.
            m_SelectedMap = mapName
            if ( m_MapLabel ~= nil and m_MapLabel.SetText ~= nil ) then
                m_MapLabel:SetText( "Map: " .. mapName )
            end
        end

        local nameBar = 24
        card.Paint = function( pnl, w, h )
            if ( DrawFilledRect == nil ) then return end
            local selected = ( m_SelectedMap == mapName )
            DrawSetColor( 255, 200, 0, selected and 110 or 40 )
            FillRect( 0, 0, w, h )
            DrawSetColor( selected and 255 or 90, selected and 176 or 90, 32, 255 )
            DrawOutlinedRect( 0, 0, w - 1, h - 1 )

            if ( pnl.__thumbID == nil ) then
                pnl.__thumbID = false
                if ( surface.CreateNewTextureID ~= nil ) then
                    local id = surface.CreateNewTextureID( true )
                    local path = "maps/thumb/" .. mapName .. ".png"
                    if ( file.Exists( path, "GAME" ) ) then
                        local ok = false
                        if ( surface.DrawSetTexturePNG ~= nil ) then
                            -- immediate RGBA upload: survives level transitions,
                            -- unlike the texture-manager file entries whose
                            -- thumbnails all died after one map load
                            ok = surface.DrawSetTexturePNG( id, path ) and true or false
                        elseif ( surface.DrawSetTextureFile ~= nil ) then
                            surface.DrawSetTextureFile( id, path, 1, false )
                            ok = true
                        end
                        if ( ok ) then pnl.__thumbID = id end
                    end
                end
            end
            if ( pnl.__thumbID ~= false and DrawTexturedRect ~= nil ) then
                surface.DrawSetTexture( pnl.__thumbID )
                -- vgui multiplies textured draws by the current draw colour;
                -- whatever the border pass left here tinted every thumbnail
                -- (the "偏色" report).  Reset to white first.
                DrawSetColor( 255, 255, 255, 255 )
                DrawTexturedRect( 4, 4, w - 8, h - nameBar - 6 )
            end
        end

        local lbl = vgui.Create( "Label", card )
        if ( lbl ~= nil ) then
            lbl:SetText( mapName )
            ApplyFont( lbl, FONT_ROW )
            if ( lbl.SetTextColor ~= nil and COL_TEXT ~= nil ) then lbl:SetTextColor( COL_TEXT ) end
            Record( lbl, 2, cardH - nameBar, cardW - 4, nameBar - 2 )
        end
    end

    if ( #maps2 == 0 ) then
        NewLabel( mapViewport, 6, 4, mapW - 16, T( "HL2SB_StartGame_NoMaps" ), 20 )
    end

    -- map grid scrollbar (painted thumb; wheel is on the viewport/cards)
    do
        local sbW = TOUCH and 16 or 10
        local sb = vgui.Panel( mapViewport, "startMapScrollbar" )
        Record( sb, mapW - sbW, 0, sbW, mapH )
        local dragging, dragY = false, nil
        sb.OnMousePressed = function( pnl, code )
            if ( code != MOUSE_LEFT ) then return end
            dragging, dragY = true, nil
            if ( surface.EnableMouseCapture ~= nil ) then surface.EnableMouseCapture( pnl, true ) end
        end
        sb.OnCursorMoved = function( pnl, x, y )
            if ( not dragging or mapMaxScroll <= 0 ) then return end
            if ( dragY == nil ) then dragY = y return end
            local track = math.max( 1, mapH - 8 )
            MapScrollBy( -( y - dragY ) * ( mapCanvasH / track ) / 40 )
            dragY = y
        end
        sb.OnMouseReleased = function( pnl, code )
            dragging, dragY = false, nil
            if ( surface.EnableMouseCapture ~= nil ) then surface.EnableMouseCapture( pnl, false ) end
        end
        sb.Paint = function( pnl, w, h )
            if ( mapMaxScroll <= 0 or DrawFilledRect == nil ) then return end
            DrawSetColor( 255, 255, 255, 24 )
            FillRect( 1, 1, w - 2, h - 2 )
            local track = h - 6
            local thumbH = math.max( TOUCH and 48 or 32, math.floor( track * h / ( h + mapMaxScroll ) ) )
            local thumbY = 3 + math.floor( ( track - thumbH ) * ( mapScroll / mapMaxScroll ) + 0.5 )
            DrawSetColor( 190, 190, 190, 235 )
            FillRect( 2, thumbY, w - 4, thumbH )
        end
    end

    -- ---- options column ------------------------------------------------------
    local widgets = { checks = {}, texts = {} }

    local function OptLabel( y, text, h )
        return NewLabel( frame, optX, y, optW, text, h or 20 )
    end

    -- selected map (reference kept: card clicks update it live)
    m_MapLabel = OptLabel( optY, "Map: " .. ( m_SelectedMap or "-" ), 20 )
    optY = optY + 26

    -- server name
    OptLabel( optY, T( "GameUI_ServerName" ), 20 )
    local hostEntry = vgui.TextEntry( frame, "startHostname" )
    if ( hostEntry ~= nil ) then
        ApplyFont( hostEntry, FONT_ROW )
        Record( hostEntry, optX, optY + 20, optW, TOUCH and 34 or 26 )
        hostEntry:SetText( tostring( config.hostname or "HL2SB Server" ) )
        hostEntry.OnSetFocus = function( pnl ) Say( "[HL2SB] startgamedialog: entry focused: hostname" ) end
    end
    optY = optY + ( TOUCH and 62 or 54 )

    -- password
    OptLabel( optY, T( "GameUI_Password" ), 20 )
    local passEntry = vgui.TextEntry( frame, "startPassword" )
    if ( passEntry ~= nil ) then
        ApplyFont( passEntry, FONT_ROW )
        Record( passEntry, optX, optY + 20, optW, TOUCH and 34 or 26 )
        passEntry:SetText( tostring( config.sv_password or "" ) )
    end
    optY = optY + ( TOUCH and 62 or 54 )

    -- max players dropdown (inline expand list).  The rows themselves are
    -- created AFTER the settings viewport further down: a row created before
    -- it is a earlier sibling, so the viewport paints over it AND takes its
    -- clicks (MoveToFront is not in this realm's panel dispatch - the silent
    -- nil-guard skip is why the expanded list read "transparent / cannot
    -- click").  Only their geometry is decided here.
    OptLabel( optY, T( "GameUI_MaxPlayers" ), 20 )
    local playersBtn = NewButton( frame, optX, optY + 20, optW, TOUCH and 36 or 26,
        PlayerLabel( m_PlayerCount ), "toggleplayers" )
    optY = optY + ( TOUCH and 64 or 54 )

    local playerRows = {}                    -- filled in after the viewport
    local playerRowY, playerRowStep = optY, ( TOUCH and 38 or 26 )
    if ( m_PlayersExpanded ) then
        optY = optY + #PLAYERS * playerRowStep
    else
        optY = optY + ( TOUCH and 8 or 6 )
    end

    -- LAN
    local lanCheck = nil
    if ( vgui.CheckButton ~= nil ) then
        lanCheck = vgui.CheckButton( frame, "startLan", T( "HL2SB_StartGame_LAN" ) )
        if ( lanCheck ~= nil ) then
            Record( lanCheck, optX, optY, optW, TOUCH and 36 or 24 )
            lanCheck:SetSelected( tostring( config.sv_lan or "0" ) == "1" )
            ApplyFont( lanCheck, FONT_ROW )
            optY = optY + ( TOUCH and 40 or 30 )
        end
    end

    -- ---- settings rows (scroll viewport) -------------------------------------
    local optsViewport = vgui.Panel( frame, "startOptsViewport" )
    local optsH = ( TOUCH and ( mapBottom + 8 ) or mapBottom ) - optY - ( TOUCH and 76 or 64 )
    optsH = math.max( ROW_H * 3, optsH )
    Record( optsViewport, optX, optY, optW, optsH )

    local optScroll, optMaxScroll, optCanvasH = 0, 0, 0
    local optsCanvas = nil   -- assigned below; the scroll closures use the upvalue
    local function OptsScrollApply()
        if ( optsCanvas ~= nil and optsCanvas.SetPos ~= nil ) then
            optsCanvas:SetPos( 0, -optScroll )
        end
        if ( HL2SB_MenuLayout ~= nil ) then HL2SB_MenuLayout( optsViewport ) end
    end
    local function OptsScrollBy( delta )
        if ( optMaxScroll <= 0 ) then return end
        local nv = math.max( 0, math.min( optScroll - delta * 40, optMaxScroll ) )
        if ( nv != optScroll ) then
            optScroll = nv
            OptsScrollApply()
        end
    end
    optsViewport.OnMouseWheeled = function( pnl, delta ) OptsScrollBy( delta ) end

    local rowH  = TOUCH and 44 or 30
    local entryW = TOUCH and 170 or 150
    optCanvasH = #rows * rowH + 4
    optMaxScroll = math.max( 0, optCanvasH - optsH )

    optsCanvas = vgui.Panel( optsViewport, "startOptsCanvas" )
    Record( optsCanvas, 0, 0, optW - 16, math.max( optCanvasH, optsH ) )

    if ( #rows == 0 ) then
        local lbl = vgui.Create( "Label", optsCanvas )
        if ( lbl ~= nil ) then
            lbl:SetText( T( "HL2SB_StartGame_Options" ) )
            ApplyFont( lbl, FONT_ROW )
            if ( lbl.SetTextColor ~= nil and COL_DIM ~= nil ) then lbl:SetTextColor( COL_DIM ) end
            Record( lbl, 4, 4, optW - 24, 20 )
        end
    end

    for i = 1, #rows do
        local s = rows[ i ]
        local y0 = ( i - 1 ) * rowH

        local wrap = vgui.Panel( optsCanvas, "startOpt_" .. i )
        Record( wrap, 0, y0, optW - 16, rowH )
        wrap.OnMouseWheeled = function( pnl, delta ) OptsScrollBy( delta ) end

        local lbl = vgui.Create( "Label", wrap )
        if ( lbl ~= nil ) then
            lbl:SetText( T( s.text ) )
            ApplyFont( lbl, FONT_ROW )
            if ( lbl.SetTextColor ~= nil and COL_TEXT ~= nil ) then lbl:SetTextColor( COL_TEXT ) end
            Record( lbl, 2, ( rowH - 20 ) / 2, optW - entryW - 24, 20 )
        end

        local savedValue = config[ s.name ]
        if ( savedValue == nil ) then savedValue = s.default end
        savedValue = tostring( savedValue )

        if ( s.stype == "CheckBox" ) then
            if ( vgui.CheckButton ~= nil ) then
                local cb = vgui.CheckButton( wrap, "startcb_" .. i, "" )
                if ( cb ~= nil ) then
                    -- the row label is already drawn by our Label; shrink the
                    -- checkbox onto the right edge
                    Record( cb, optW - entryW - 8, ( rowH - 20 ) / 2, entryW, 20 )
                    cb:SetSelected( savedValue == "1" )
                    ApplyFont( cb, FONT_ROW )
                    widgets.checks[ s.name ] = cb
                end
            end
        else
        local te = vgui.TextEntry( wrap, "startte_" .. i )
        if ( te ~= nil ) then
            ApplyFont( te, FONT_ROW )
            Record( te, optW - entryW - 8, ( rowH - ( TOUCH and 34 or 24 ) ) / 2, entryW, TOUCH and 34 or 24 )
            te:SetText( savedValue )
            widgets.texts[ s.name ] = te
            -- clicking anywhere on the row focuses the entry: at 150px wide the
            -- box itself is an easy miss, and a missed click reads as "the
            -- option cannot be typed into"
            wrap.OnMousePressed = function( pnl, code )
                if ( code != MOUSE_LEFT ) then return end
                Say( "[HL2SB] startgamedialog: settings row clicked: " .. s.name )
                if ( te.RequestFocus ~= nil ) then pcall( te.RequestFocus, te ) end
            end
            -- temporary probes: if a click prints "entry focused" but keys
            -- still do nothing, the break is in keyboard routing, not focus
            te.OnSetFocus = function( pnl ) Say( "[HL2SB] startgamedialog: entry focused: " .. s.name ) end
            te.OnKillFocus = function( pnl ) Say( "[HL2SB] startgamedialog: entry unfocused: " .. s.name ) end
        end
        end
    end

    -- settings scrollbar (drag or wheel; there was no visible affordance
    -- before and the column reads as "nothing below")
    do
        local sbW = TOUCH and 16 or 10
        local sb = vgui.Panel( optsViewport, "startOptsScrollbar" )
        Record( sb, optW - sbW, 0, sbW, optsH )
        local dragging, dragY = false, nil
        sb.OnMousePressed = function( pnl, code )
            if ( code != MOUSE_LEFT ) then return end
            dragging, dragY = true, nil
            if ( surface.EnableMouseCapture ~= nil ) then surface.EnableMouseCapture( pnl, true ) end
        end
        sb.OnCursorMoved = function( pnl, x, y )
            if ( not dragging or optMaxScroll <= 0 ) then return end
            if ( dragY == nil ) then dragY = y return end
            local track = math.max( 1, optsH - 8 )
            OptsScrollBy( -( y - dragY ) * ( optCanvasH / track ) / 40 )
            dragY = y
        end
        sb.OnMouseReleased = function( pnl, code )
            dragging, dragY = false, nil
            if ( surface.EnableMouseCapture ~= nil ) then surface.EnableMouseCapture( pnl, false ) end
        end
        sb.Paint = function( pnl, w, h )
            if ( optMaxScroll <= 0 or DrawFilledRect == nil ) then return end
            DrawSetColor( 255, 255, 255, 24 )
            FillRect( 1, 1, w - 2, h - 2 )
            local track = h - 6
            local thumbH = math.max( TOUCH and 48 or 32, math.floor( track * h / ( h + optMaxScroll ) ) )
            local thumbY = 3 + math.floor( ( track - thumbH ) * ( optScroll / optMaxScroll ) + 0.5 )
            DrawSetColor( 190, 190, 190, 235 )
            FillRect( 2, thumbY, w - 4, thumbH )
        end
    end

    -- player pick rows, now created AFTER the settings viewport: later
    -- siblings paint on top of it and receive the clicks (see note above)
    for i = 1, #PLAYERS do
        local n = PLAYERS[ i ]
        local r = NewButton( frame, optX, playerRowY + ( i - 1 ) * playerRowStep, optW,
            TOUCH and 36 or 24, PlayerLabel( n ), "mpsel_" .. n )
        if ( r ~= nil ) then
            if ( r.SetVisible ~= nil ) then r:SetVisible( m_PlayersExpanded ) end
            -- opaque row backing: without it the row text floats over the
            -- settings content underneath and reads as a ghost
            if ( r.PaintBackground ~= nil ) then
                r.PaintBackground = function( pnl, w, h )
                    if ( DrawFilledRect == nil ) then return end
                    DrawSetColor( 58, 62, 68, 255 )
                    FillRect( 0, 0, w, h )
                end
            end
        end
        playerRows[ #playerRows + 1 ] = r
    end

    -- ---- start / back ---------------------------------------------------------
    local btnH = TOUCH and 56 or math.floor( fh * 0.05 )
    local btnY = ( TOUCH and ( 8 + fh - btnH - M ) or math.floor( fh * 0.92 ) )
    if ( TOUCH ) then
        NewButton( frame, M, btnY, fw - M * 2, btnH, T( "GameUI_StartGame" ), "startgame" )
        NewButton( frame, M, btnY - ( TOUCH and 44 or 40 ), fw - M * 2, TOUCH and 40 or 36, T( "GameUI_Back" ), "Close" )
    else
        NewButton( frame, optX, btnY, math.floor( optW * 0.55 ), btnH, T( "GameUI_StartGame" ), "startgame" )
        NewButton( frame, catX, btnY, math.floor( optW * 0.30 ), btnH, T( "GameUI_Back" ), "Close" )
    end

    -- ---- command routing -------------------------------------------------------
    frame.OnCommand = function( self, cmd )
        if ( type( self ) == "string" ) then cmd = self end
        if ( cmd == nil ) then return end

        if ( cmd == "Close" ) then
            frame:Close()
            if ( frame.MarkForDeletion ~= nil ) then pcall( frame.MarkForDeletion, frame ) end
            m_Frame = nil
        elseif ( cmd == "startgame" ) then
            -- gather live widget state into the config and go
            config.map        = m_SelectedMap or ""
            config.hostname   = EntryValue( hostEntry )
            config.sv_password = EntryValue( passEntry )
            config.sv_lan     = ( lanCheck ~= nil and lanCheck.IsChecked ~= nil and lanCheck:IsChecked() ) and "1" or "0"
            config.maxplayers = tostring( m_PlayerCount )
            for name, cb in pairs( widgets.checks ) do
                config[ name ] = ( cb.IsChecked ~= nil and cb:IsChecked() ) and "1" or "0"
            end
            for name, te in pairs( widgets.texts ) do
                config[ name ] = EntryValue( te )
            end
            SaveServerConfig( config )

            local gm = ActiveGamemode()
            local cmd2 = string.format(
                "disconnect\nwait\nwait\nsv_lan %d\ngamemode \"%s\"\nmaxplayers %d\nsv_password \"%s\"\nhostname \"%s\"\nprogress_enable\nmap %s\n",
                ( config.sv_lan == "1" ) and 1 or 0,
                gm,
                m_PlayerCount,
                tostring( config.sv_password or "" ),
                tostring( config.hostname or "" ),
                tostring( config.map or "" ) )
            frame:Close()
            if ( frame.MarkForDeletion ~= nil ) then pcall( frame.MarkForDeletion, frame ) end
            m_Frame = nil
            engine.ClientCmd_Unrestricted( cmd2 )
        elseif ( StartsWith( cmd, "mapcat_" ) ) then
            local n = tonumber( string.sub( cmd, 8 ) )
            if ( n ~= nil and n >= 1 and n <= MAPCAT_COUNT ) then
                m_SelectedCategory = n
                m_SelectedMap = nil
                Reopen()
            end
        elseif ( cmd == "toggleplayers" ) then
            m_PlayersExpanded = not m_PlayersExpanded
            for _, r in ipairs( playerRows ) do
                if ( r ~= nil and r.SetVisible ~= nil ) then r:SetVisible( m_PlayersExpanded ) end
                -- the settings viewport is a LATER sibling and would sit on top
                -- of the expanded rows (painting over them AND eating their
                -- clicks - the "transparent / cannot click" report); raise the
                -- rows above it while they are open
                if ( m_PlayersExpanded and r ~= nil and r.MoveToFront ~= nil ) then
                    pcall( r.MoveToFront, r )
                end
            end
            if ( playersBtn ~= nil and playersBtn.SetText ~= nil ) then
                playersBtn:SetText( PlayerLabel( m_PlayerCount ) )
            end
            if ( HL2SB_MenuLayout ~= nil ) then HL2SB_MenuLayout( frame ) end
        elseif ( StartsWith( cmd, "mpsel_" ) ) then
            local n = tonumber( string.sub( cmd, 7 ) )
            if ( n ~= nil ) then
                local bBoundary = ( n <= 1 ) != ( m_PlayerCount <= 1 )
                m_PlayerCount = n
                m_PlayersExpanded = false
                if ( bBoundary ) then
                    -- crossing the single player row swaps the whole settings
                    -- set (small singleplayer sidebar vs the sandbox caps list)
                    Reopen()
                else
                    -- live update: same settings set, just reflect the pick
                    for _, r in ipairs( playerRows ) do
                        if ( r ~= nil and r.SetVisible ~= nil ) then r:SetVisible( false ) end
                    end
                    if ( playersBtn ~= nil and playersBtn.SetText ~= nil ) then
                        playersBtn:SetText( PlayerLabel( m_PlayerCount ) )
                    end
                    if ( HL2SB_MenuLayout ~= nil ) then HL2SB_MenuLayout( frame ) end
                end
            end
        end
    end

    -- ---- raise + layout pass ----------------------------------------------------
    if ( frame.SetSizeable ~= nil ) then frame:SetSizeable( false ) end
    if ( frame.SetVisible ~= nil ) then frame:SetVisible( true ) end
    if ( frame.MoveToFront ~= nil ) then frame:MoveToFront() end
    frame:Activate()

    local function ReassertPositions()
        for i = 1, #Layout do
            local e = Layout[ i ]
            if ( e[ 1 ] ~= nil and e[ 1 ].SetPos ~= nil and e[ 1 ].SetSize ~= nil ) then
                e[ 1 ]:SetPos( e[ 2 ], e[ 3 ] )
                e[ 1 ]:SetSize( e[ 4 ], e[ 5 ] )
            end
        end
        if ( HL2SB_MenuLayout ~= nil ) then HL2SB_MenuLayout( frame ) end
        if ( frame.InvalidateLayout ~= nil ) then frame:InvalidateLayout( true ) end
    end

    ReassertPositions()
    if ( timer ~= nil and timer.Simple ~= nil ) then
        timer.Simple( 0, function()
            if ( m_Frame ~= frame or frame.SetBounds == nil ) then return end
            ReassertPositions()
        end )
    end

    -- localization diagnostic: raw token strings everywhere in the dialog mean
    -- either the Localizations lib is missing (old client.dll) or the localize
    -- system has no such token - this line separates the two at a glance.
    local locState = "MISSING"
    if ( Localizations ~= nil and Localizations.Find ~= nil ) then
        local ok, probe = pcall( Localizations.Find, "GameUI_Back" )
        locState = ( ok and probe ~= nil and probe != "" ) and "ok" or "no-tokens"
    end

    Say( string.format( "[HL2SB] startgamedialog: %s layout %dx%d, %d maps (%d in category), %d settings rows, players default %d, loc=%s",
        TOUCH and "touch" or "desktop", fw, fh, #maps, #maps2, #rows, m_PlayerCount, locState ) )

    return frame
end

concommand.Create( "OpenStartGameDialogLua", function()
    Open()
end, "Open the Lua start game dialog.", FCVAR_CLIENTDLL )

concommand.Create( "hl2sb_startgame_touch", function()
    TOUCH_MODE = ( TOUCH_MODE + 1 ) % 3
    if ( TOUCH_MODE == 0 ) then
        Say( "[HL2SB] startgame touch: auto (" .. ( TOUCH_AUTO and "android detected" or "desktop" ) .. ")" )
    elseif ( TOUCH_MODE == 1 ) then
        Say( "[HL2SB] startgame touch: forced ON" )
    else
        Say( "[HL2SB] startgame touch: forced OFF" )
    end
end, "Cycle the start game dialog touch layout override.", FCVAR_CLIENTDLL )
