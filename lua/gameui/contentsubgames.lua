--[[
    HL2SB: Content dialog -- dynamically detect installed Source games.

    Scans the parent of the mod directory for sibling folders that contain
    gameinfo.txt (i.e. other Source engine games) and builds the checkbox
    list from what is actually on disk.  Only games that exist get a row.

    The AppId map is used only for gamecontent.txt compatibility; the
    mount itself is done by filesystem.AddSearchPath on the sibling dir.
]]

include( "../includes/extensions/table.lua" )
include( "../includes/extensions/vgui.lua" )
include( "../includes/extensions/keyvalues.lua" )

local vgui = vgui

-- Known Source-game folder names -> friendly display name + AppId.
-- Keys are lowercase folder names under the parent of the mod dir.
local KnownSourceGames =
{
    ["hl2"]               = { name = "Half-Life 2",              appId = 220 },
    ["hl2base"]           = { name = "Half-Life 2",              appId = 220 },
    ["hl2mp"]             = { name = "HL2 Deathmatch",           appId = 320 },
    ["hl2client"]         = { name = "HL2: Episode One",         appId = 380 },
    ["episodic"]          = { name = "HL2: Episode One",         appId = 380 },
    ["episodic_two"]      = { name = "HL2: Episode Two",         appId = 420 },
    ["ep2"]               = { name = "HL2: Episode Two",         appId = 420 },
    ["lostcoast"]         = { name = "HL2: Lost Coast",          appId = 340 },
    ["hl2lostcoast"]      = { name = "HL2: Lost Coast",          appId = 340 },
    ["portal"]            = { name = "Portal",                   appId = 400 },
    ["portal2"]           = { name = "Portal 2",                 appId = 620 },
    ["cstrike"]           = { name = "CS: Source",               appId = 240 },
    ["cstrike:source"]    = { name = "CS: Source",               appId = 240 },
    ["counter-strike"]    = { name = "CS: Source",               appId = 240 },
    ["dod"]               = { name = "DoD: Source",              appId = 300 },
    ["dayofdefeat"]       = { name = "DoD: Source",              appId = 300 },
    ["hl1"]               = { name = "Half-Life: Source",        appId = 280 },
    ["hls"]               = { name = "Half-Life: Source",        appId = 280 },
    ["halflifesource"]    = { name = "Half-Life: Source",        appId = 280 },
    ["hl1source"]         = { name = "Half-Life: Source",        appId = 280 },
    ["hldeathmatch"]      = { name = "HL Deathmatch: Source",    appId = 360 },
    ["hl2deathmatch"]     = { name = "HL Deathmatch: Source",    appId = 360 },
    ["tf"]                = { name = "Team Fortress 2",          appId = 440 },
    ["tf2"]               = { name = "Team Fortress 2",          appId = 440 },
    ["teamfortress2"]     = { name = "Team Fortress 2",          appId = 440 },
    ["garrysmod"]         = { name = "Garry's Mod",              appId = 4000 },
}

-- ---------------------------------------------------------------------------
-- Detect sibling Source games by scanning for gameinfo.txt.
-- ---------------------------------------------------------------------------
local function DetectInstalledGames()
    local gameDir  = engine.GetGameDirectory()   -- e.g. D:\srceng\hl2sb
    local parentDir = gameDir:match( "^(.*)[/\\][^/\\]+$" )  -- e.g. D:\srceng

    if ( not parentDir ) then
        return {}
    end

    local found = {}
    local dirs = file.FindDir( parentDir .. "/*", "GAME" )

    for _, folderName in ipairs( dirs or {} ) do
        -- Skip the current mod itself.
        local lower = folderName:lower()
        if ( lower != "hl2sb" ) then
            -- A Source game must have gameinfo.txt at its root.
            local giPath = parentDir .. "/" .. folderName .. "/gameinfo.txt"
            if ( file.Exists( folderName .. "/gameinfo.txt", "GAME" ) ) then
                local info = KnownSourceGames[ lower ]
                if ( info ) then
                    table.insert( found, {
                        folder = folderName,
                        name   = info.name,
                        appId  = info.appId,
                    } )
                else
                    -- Unknown folder with gameinfo.txt -- still list it so the
                    -- user can mount custom forks, but mark the name as the
                    -- folder name itself.
                    table.insert( found, {
                        folder = folderName,
                        name   = folderName,
                        appId  = 0,
                    } )
                end
            end
        end
    end

    table.sort( found, function( a, b ) return a.name:lower() < b.name:lower() end )
    return found
end

-- ---------------------------------------------------------------------------
-- ContentSubGames page -- builds checkboxes from the detected list.
-- ---------------------------------------------------------------------------
local CContentSubGames = {}
local m_CheckBoxes = {}   -- populated in Init; each entry is { panel, folder, appId }

function CContentSubGames:Init( parent )
    self.m_DetectedGames = DetectInstalledGames()
    m_CheckBoxes = {}

    local y = 12
    for i, game in ipairs( self.m_DetectedGames ) do
        local cb = vgui.CheckButton( self, "game_" .. i, game.name )
        cb:SetPos( 20, y )
        cb:SetSize( 380, 24 )
        cb.OnCheckButtonChecked = function( btn )
            -- Enable the Apply button on the parent PropertyDialog.
            local dialog = self:GetParent():GetParent():GetParent()
            if ( dialog and dialog.EnableApplyButton ) then
                dialog:EnableApplyButton( true )
            end
        end
        m_CheckBoxes[ i ] = { panel = cb, folder = game.folder, appId = game.appId }
        y = y + 26
    end

    -- Show something if nothing was found.
    if ( #self.m_DetectedGames == 0 ) then
        local lbl = vgui.Create( "Label", self )
        lbl:SetPos( 20, y )
        lbl:SetSize( 380, 40 )
        lbl:SetText( "No other Source games found next to this install." )
    end

    -- Restart note at the bottom.
    local note = vgui.Create( "Label", self )
    note:SetPos( 20, y + 40 )
    note:SetSize( 380, 32 )
    note:SetWrap( true )
    note:SetFont( "DefaultSmall" )
    note:SetText( "#GameUI_GamesRestartNote" )
end

function CContentSubGames:OnResetData()
    -- Load previous selections from gamecontent.txt.
    local kv = KeyValues( "GameContent" )
    if ( not kv:LoadFromFile( engine.GetGameDirectory() .. "/gamecontent.txt", "MOD" ) ) then
        kv:deleteThis()
        return
    end

    local fs = kv:GetData( "FileSystem" )
    if ( fs ) then
        local appIds = {}
        local appId = fs:GetFirstSubKey()
        while ( appId ) do
            local id = tonumber( appId:GetString() )
            if ( id ) then appIds[ id ] = true end
            appId = appId:GetNextKey()
        end
        for _, entry in ipairs( m_CheckBoxes ) do
            if ( entry.appId > 0 and appIds[ entry.appId ] ) then
                entry.panel:SetSelected( true )
            end
        end
    end

    kv:deleteThis()
end

function CContentSubGames:OnApplyChanges()
    local kv = KeyValues( "GameContent" )
    local fs  = kv:CreateNewKey()
    fs:SetName( "FileSystem" )

    for _, entry in ipairs( m_CheckBoxes ) do
        if ( entry.panel:IsSelected() and entry.appId > 0 ) then
            local appKv = KeyValues( "AppId" )
            appKv:SetStringValue( tostring( entry.appId ) )
            fs:AddSubKey( appKv )
        end
    end

    kv:SaveToFile( "gamecontent.txt", "MOD" )
    kv:deleteThis()

    print( "[HL2SB] gamecontent.txt saved; restart to apply mounts\n" )
end

function CContentSubGames:OnOK( applyOnly )
    self:OnApplyChanges()
end

vgui.register( CContentSubGames, "CContentSubGames", "PropertyPage" )
