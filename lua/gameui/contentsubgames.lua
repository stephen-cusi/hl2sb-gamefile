--[[
    HL2SB: Content dialog -- the "Games" page.

    Lists the Source games installed next to this one and lets the user pick
    which to mount; lua/autorun/mount_games.lua reads the selection back out of
    gamecontent.txt on the next start.

    The detection runs IN THIS PAGE, not off a global set by lua/autorun: this
    page lives in the menu realm, which is a separate Lua state and cannot see
    the client realm's globals.  detect_source_games.lua exposes
    _G.HL2SB_DetectSourceGames() for exactly that, and including it here is also
    what gives this state the file library it needs.
]]
-- The menu realm is a hand-opened Lua state: it only has the GMod spellings
-- (`file`, `render`, ...) when the engine installed the alias table there, and
-- otherwise the Experiment names (`Files`).  Point the GMod name at whichever
-- exists BEFORE the includes below -- detect_source_games.lua checks for `file`
-- as it loads and silently gives up without it.
if ( not file and Files ) then file = Files end

include( "../includes/extensions/table.lua" )
include( "../includes/extensions/vgui.lua" )
include( "../autorun/detect_source_games.lua" )

local CContentSubGames = {}
local m_CheckBoxes = {}

-- Panel's constructor default is 64x24 (vgui2/vgui_controls/Panel.cpp:626).  A
-- page still carrying that size when it is drawn was never laid out by its
-- sheet, and VGUI clips children to the parent -- so every checkbox below y=24
-- is clipped away and the dialog shows an empty page even though the checkboxes
-- exist, are "visible" and sit correctly at (20,30)/(20,56).
local nDefaultPageWide, nDefaultPageTall = 64, 24

-- Where the rows start, how far apart they are, and how wide the content wants
-- to be.  The last two are only used to rescue a page the sheet never sized.
local nFirstRowY = 30
local nRowHeight = 26
local nContentWide = 440

-- The live page, so the hl2sb_contentdump console command (bottom of this file)
-- can report geometry while the dialog is actually on screen.
local m_Page = nil

-- The two labels this page owns, kept so the layout below can be re-applied to
-- them (and so the dumps can report where they really ended up).
local m_Hint = nil
local m_Empty = nil

-- TEMPORARY PROBE markers -- remove with the SetText("MARK-...") pair in Init.
local m_ProbeTop = nil
local m_ProbeBot = nil

-- Read selected AppIds from gamecontent.txt.  mount_games.lua scans the same
-- file for "the first number on a line", so both this plain form and the
-- KeyValues form an older dialog left behind are read correctly.
local function ReadSelectedAppIds()
    local ids = {}
    local path = engine.GetGameDirectory() .. "/gamecontent.txt"
    local f = io.open( path, "r" )
    if ( not f ) then return ids end
    for line in f:lines() do
        local id = tonumber( line:match( "%s*(%d+)%s*" ) )
        if ( id ) then ids[ id ] = true end
    end
    f:close()
    return ids
end

-- Write the checked AppIds, one per line.
local function WriteSelectedAppIds()
    local path = engine.GetGameDirectory() .. "/gamecontent.txt"
    local f = io.open( path, "w" )
    if ( not f ) then return end
    for _, entry in ipairs( m_CheckBoxes ) do
        if ( entry.panel:IsSelected() and entry.appId > 0 ) then
            f:write( tostring( entry.appId ), "\n" )
        end
    end
    f:close()
end

--[[
    Panel geometry the way the diagnostics need it: identity, position, size AND
    visibility, of the panel itself.  A checkbox can be visible=true, correctly
    placed, and still never drawn because the page it lives on is hidden or is
    still only 64x24 tall.
]]
local function Geometry( panel )
    if ( not panel ) then return "nil" end
    local x, y = panel:GetPos()
    local w, h = panel:GetSize()
    return string.format( "%s pos=(%d,%d) size=(%d,%d) visible=%s",
        tostring( panel ), x, y, w, h, tostring( panel:IsVisible() ) )
end

--[[
    The sheet sizes its pages in PropertySheet::PerformLayout().  A page that
    still carries Panel's 64x24 default never went through it, and everything
    below y=24 is clipped away.  Only that case is corrected here -- a page the
    sheet did lay out keeps whatever geometry the sheet gave it, so this can
    never fight a working layout.

    Returns true when the rescue was applied.
]]
local function EnsurePageSize( page, nWantedTall )
    local w, h = page:GetSize()
    if ( w ~= nDefaultPageWide or h ~= nDefaultPageTall ) then return false end
    page:SetSize( nContentWide, nWantedTall )
    return true
end

--[[
    Both the sheet and the page have to be big enough to hold the rows, because
    VGUI only draws a child inside its parent's bounds.

    The sheet is sized by PropertyDialog::PerformLayout()
    (vgui2/vgui_controls/PropertyDialog.cpp:104) and nothing else, and the dump
    showed it still at Panel's 64x24 default while the dialog itself was 460x380
    -- so this page, checkbox rows and all, was clipped to a 64x24 corner: an
    empty gray dialog with a correctly built list inside it.

    Panel:InvalidateLayout( true ) runs PerformLayout immediately
    (vgui2/vgui_controls/Panel.cpp:4308, the "layout now has to mean now" fix),
    which is what this dialog never got: a panel created from Lua still has
    NEEDS_SCHEME_UPDATE set during its first frame, InternalPerformLayout()
    returns early while that is set, and an invalidation in that window therefore
    does nothing at all.

    A sheet the engine did size is left alone.
]]
local function EnsureSheetSize( sheet )
    if ( not sheet ) then return false end
    local w, h = sheet:GetSize()
    if ( w ~= nDefaultPageWide or h ~= nDefaultPageTall ) then return false end

    local dialog = sheet:GetParent()

    -- 1. Ask the dialog for the layout it owes its sheet.
    if ( dialog and dialog.InvalidateLayout ) then
        dialog:InvalidateLayout( true )
    end

    -- 2. Still at the default -- the layout did not happen, or ran before the
    --    dialog had a size.  Size the sheet from the dialog and lay IT out too,
    --    so the page inside it stops being clipped either way.
    local w2, h2 = sheet:GetSize()
    if ( w2 == nDefaultPageWide and h2 == nDefaultPageTall and dialog ) then
        local dw, dh = dialog:GetSize()
        sheet:SetBounds( 0, 24, dw - 16, dh - 68 )
        if ( sheet.InvalidateLayout ) then
            sheet:InvalidateLayout( true )
        end
        return true
    end

    return false
end

--[[
    Apply the row layout and return the bottom edge it reached.

    Called from Init AND again from OnPageShow on purpose.  Init runs inside
    vgui.register's factory, i.e. before CContentDialog:Init hands the page to
    PropertyDialog:AddPage -- and what the sheet does to the page there
    (re-parent, activate, lay out, reset) is exactly where a child's coordinates
    can be lost: the labels then draw at the page's top-left corner, on top of
    each other, which is what the dialog looked like.  Re-applying is idempotent,
    so it costs nothing and makes this page independent of that ordering.
]]
local function PlaceContent()
    local y = nFirstRowY

    for _, entry in ipairs( m_CheckBoxes ) do
        entry.panel:SetBounds( 20, y, 400, 24 )
        y = y + nRowHeight
    end

    if ( m_Empty ) then
        m_Empty:SetBounds( 20, y, 400, 20 )
        y = y + 24
    end

    if ( m_Hint ) then
        m_Hint:SetBounds( 20, y + 10, 400, 32 )
        y = y + 42
    end

    -- TEMPORARY PROBE markers, positioned here so they ride along with any
    -- layout change: page-local (20,2) and the page's bottom edge, the page being
    -- y+20 tall (see the EnsurePageSize calls).
    if ( m_ProbeTop ) then m_ProbeTop:SetBounds( 20, 2, 200, 16 ) end
    if ( m_ProbeBot ) then m_ProbeBot:SetBounds( 20, y + 4, 200, 16 ) end

    return y
end

--[[
    Diagnostics go to both channels: the console (Msg, which lands in
    engine.log) and data/<name>.  The menu realm has no console of its own and
    its output used to be invisible, so a file is the only thing that survives a
    run -- and "the dialog is empty and nothing was printed" was exactly how the
    missing file library hid itself once already.
]]
local function Dump( lines, name )
    -- Both channels on purpose.  The console is the only feedback the user gets
    -- when the page comes up empty ("no output at all" was the symptom that hid
    -- the missing file library), and the file survives for review afterwards.
    local say = Msg or print
    if ( say ) then
        for _, line in ipairs( lines ) do
            say( "[HL2SB] " .. line .. "\n" )
        end
    end

    if ( file and file.Write ) then
        file.Write( name or "hl2sb_contentdialog.txt", table.concat( lines, "\n" ) .. "\n" )
    elseif ( say ) then
        say( "[HL2SB] content dialog: no file library in this realm, see the lines above\n" )
    end
end

function CContentSubGames:Init( parent )
    m_CheckBoxes = {}

    local games = {}
    if ( _G.HL2SB_DetectSourceGames ) then
        games = _G.HL2SB_DetectSourceGames() or {}
    end
    if ( #games == 0 and type( _G.HL2SB_DetectedGames ) == "table" ) then
        games = _G.HL2SB_DetectedGames
    end

    local diag = {}
    local function note( s ) table.insert( diag, tostring( s ) ) end

    note( "HL2SB content dialog -- Games page" )
    note( "self=" .. tostring( self ) .. " type(self)=" .. type( self ) .. " parent=" .. tostring( parent ) )
    note( "detector=" .. tostring( _G.HL2SB_DetectSourceGames ) .. " games=" .. #games )
    for i, game in ipairs( games ) do
        note( string.format( "  game[%d] folder=%s name=%s appId=%s",
            i, tostring( game.folder ), tostring( game.name ), tostring( game.appId ) ) )
    end

    local info = _G.HL2SB_DetectInfo
    if ( info ) then
        note( "detector: gameDir=" .. tostring( info.gameDir ) .. " selfName=" .. tostring( info.selfName ) ..
              " baseDirs=" .. tostring( info.baseDirs ) .. " found=" .. tostring( info.found ) )
        for k, v in pairs( info ) do
            if ( type( k ) == "string" and k:sub( 1, 6 ) == "probe_" ) then
                note( "  probe " .. k:sub( 7 ) .. " gameinfo=" .. tostring( v ) )
            end
        end
        if ( info.candidates ) then
            note( "  base dirs: " .. table.concat( info.candidates, "," ) )
        end
    else
        note( "detector: no _G.HL2SB_DetectInfo" )
    end

    m_Page = self

    -- TEMPORARY PROBE -- remove once the rows paint.
    --
    -- Every number in the dumps is right (page 440x144, rows inside it, all
    -- visible) and still nothing on the page shows.  VGUI clips children to the
    -- parent, and a border/inset can shrink that clip without ever changing
    -- GetSize(), so put one label at the page's top and one near its bottom edge:
    -- both visible = the clip covers the page and the checkboxes fail on their
    -- own, only the top one = the clip is short and the rows below it are cut.
    -- (Dyeing the page would be louder, but SetBgColor wants a Color object and
    -- the Color library is not open in this state.)
    m_ProbeTop = vgui.Create( "Label", self )
    m_ProbeTop:SetText( "MARK-TOP" )
    m_ProbeBot = vgui.Create( "Label", self )
    m_ProbeBot:SetText( "MARK-BOT" )

    for i, game in ipairs( games ) do
        local cb = vgui.CheckButton( self, "game_" .. i, game.name )
        cb.OnCheckButtonChecked = function( btn )
            local dialog = self:GetParent():GetParent():GetParent()
            if ( dialog and dialog.EnableApplyButton ) then
                dialog:EnableApplyButton( true )
            end
        end
        m_CheckBoxes[ i ] = { panel = cb, folder = game.folder, appId = game.appId, name = game.name }
    end

    -- TEMPORARY PROBE -- remove with the MARK labels above.
    --
    -- The dump reported each checkbox' parent as an unnamed Panel while the page
    -- itself prints as a PropertyPage, and the hint label beside them (same page,
    -- same parent chain) does paint.  Re-parent explicitly and report the
    -- parent's SIZE: the page is 440x144, a Lua root panel is screen sized.
    for i, entry in ipairs( m_CheckBoxes ) do
        local p = entry.panel:GetParent()
        local pw, ph = p:GetSize()
        note( string.format( "  probe cb[%d] parent=%s parentSize=(%d,%d)",
            i, tostring( p ), pw, ph ) )

        entry.panel:SetParent( self )
    end

    if ( #games == 0 ) then
        m_Empty = vgui.Create( "Label", self )
        m_Empty:SetText( "No other Source games found next to this install." )
    end

    -- Content starts below the tab strip: a page whose first row sits at y=12
    -- draws straight into the tab row / page title area.
    m_Hint = vgui.Create( "Label", self )
    m_Hint:SetWrap( true )
    m_Hint:SetFont( "DefaultSmall" )
    m_Hint:SetText( "#GameUI_GamesRestartNote" )

    local y = PlaceContent()

    -- Geometry, read back: a panel whose SetPos/SetBounds was swallowed shows up
    -- here instead of only on screen.
    note( "sheet=" .. Geometry( self:GetParent() ) )
    note( "page=" .. Geometry( self ) )
    note( "hint=" .. Geometry( m_Hint ) )
    if ( m_Empty ) then note( "empty=" .. Geometry( m_Empty ) ) end
    if ( m_ProbeTop ) then note( "probeTop=" .. Geometry( m_ProbeTop ) ) end
    if ( m_ProbeBot ) then note( "probeBot=" .. Geometry( m_ProbeBot ) ) end

    for i, entry in ipairs( m_CheckBoxes ) do
        note( string.format( "  cb[%d] %s text=%s selected=%s",
            i, Geometry( entry.panel ), tostring( entry.name ), tostring( entry.panel:IsSelected() ) ) )
    end

    --[[
        The page is still 64x24 here, and that is expected rather than broken:
        vgui.register's factory (lua/includes/extensions/vgui.lua:40) calls this
        Init before CContentDialog:Init hands the page to
        PropertyDialog:AddPage, so the sheet has not sized it yet.  Whether it
        ever does is what OnPageShow below measures -- and what EnsurePageSize
        rescues when it does not.
    ]]
    local bRescued = EnsurePageSize( self, y + 20 )
    note( string.format( "page failed layout=%s -> %s", tostring( bRescued ), Geometry( self ) ) )

    Dump( diag )
end

--[[
    Posted by PropertySheet::ChangeActiveTab() right after this page becomes the
    active one -- the first moment the sheet could have laid the page out, and
    therefore the first honest measurement of the page's size.  Written to its
    own file so the Init snapshot above survives next to it.
]]
function CContentSubGames:OnPageShow()
    local sheet = self:GetParent()

    -- The sheet has just taken this page over (PropertyDialog:AddPage ->
    -- PropertySheet::AddPage -> ChangeActiveTab).  Both of these are the same
    -- kind of repair and both only fire while the panel is still at Panel's
    -- 64x24 default: the sheet first, because the page is drawn inside it.
    local bSheetRescued = EnsureSheetSize( sheet )

    local y = PlaceContent()
    local bPageRescued = EnsurePageSize( self, y + 20 )

    local lines = { "HL2SB content dialog -- Games page shown" }
    lines[ #lines + 1 ] = string.format( "  sheet=%s resized=%s", Geometry( sheet ), tostring( bSheetRescued ) )
    lines[ #lines + 1 ] = "  dialog=" .. Geometry( sheet and sheet:GetParent() )
    lines[ #lines + 1 ] = string.format( "  page=%s resized=%s", Geometry( self ), tostring( bPageRescued ) )
    lines[ #lines + 1 ] = "  hint=" .. Geometry( m_Hint )
    if ( m_Empty ) then lines[ #lines + 1 ] = "  empty=" .. Geometry( m_Empty ) end
    if ( m_ProbeTop ) then lines[ #lines + 1 ] = "  probeTop=" .. Geometry( m_ProbeTop ) end
    if ( m_ProbeBot ) then lines[ #lines + 1 ] = "  probeBot=" .. Geometry( m_ProbeBot ) end
    for i, entry in ipairs( m_CheckBoxes ) do
        local p = entry.panel:GetParent()
        local pw, ph = p:GetSize()
        lines[ #lines + 1 ] = string.format( "  cb[%d] %s parent=%s parentSize=(%d,%d)",
            i, Geometry( entry.panel ), tostring( p ), pw, ph )
    end

    Dump( lines, "hl2sb_contentdialog_shown.txt" )
end

function CContentSubGames:OnResetData()
    local ids = ReadSelectedAppIds()
    for _, entry in ipairs( m_CheckBoxes ) do
        if ( entry.appId > 0 and ids[ entry.appId ] ) then
            entry.panel:SetSelected( true )
        end
    end
end

function CContentSubGames:OnApplyChanges()
    WriteSelectedAppIds()
    -- Same snapshot at apply time: by now the dialog has been on screen, so this
    -- is the post-layout ground truth to compare against the Init numbers.
    self:OnPageShow()
    local say = Msg or print
    say( "[HL2SB] gamecontent.txt saved; restart to apply mounts\n" )
end

function CContentSubGames:OnOK( applyOnly )
    self:OnApplyChanges()
end

vgui.register( CContentSubGames, "CContentSubGames", "PropertyPage" )

-- Menu realm console command: reports the page as it is RIGHT NOW, which is the
-- only way to see the numbers once the dialog has been up for a while (the two
-- dumps above are written at build and at page-show time).
concommand.Create( "hl2sb_contentdump", function()
    if ( m_Page ) then
        m_Page:OnPageShow()
    else
        local say = Msg or print
        if ( say ) then
            say( "[HL2SB] content dialog page not built yet\n" )
        end
    end
end, "Dump the Content dialog's Games page geometry.", FCVAR_CLIENTDLL )
