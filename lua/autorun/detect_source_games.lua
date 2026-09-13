--[[
    HL2SB: detect installed Source games in sibling directories.
    Runs from lua/autorun (has the file library); the Content dialog
    reads _G.HL2SB_DetectedGames.
]]

local function DetectInstalledGames()
    local gameDir  = engine.GetGameDirectory()
    local parentDir = gameDir:match( "^(.*)[/\\][^/\\]+$" )
    if ( not parentDir ) then return {} end

    -- Known Source-game folder names -> { name, appId }
    local Known =
    {
        ["hl2"]        = { name = "Half-Life 2",           appId = 220 },
        ["hl2base"]    = { name = "Half-Life 2",           appId = 220 },
        ["hl2mp"]      = { name = "HL2 Deathmatch",        appId = 320 },
        ["hl2client"]  = { name = "HL2: Episode One",      appId = 380 },
        ["episodic"]   = { name = "HL2: Episode One",      appId = 380 },
        ["ep2"]        = { name = "HL2: Episode Two",      appId = 420 },
        ["lostcoast"]  = { name = "HL2: Lost Coast",       appId = 340 },
        ["portal"]     = { name = "Portal",                appId = 400 },
        ["portal2"]    = { name = "Portal 2",              appId = 620 },
        ["cstrike"]    = { name = "CS: Source",            appId = 240 },
        ["dod"]        = { name = "DoD: Source",           appId = 300 },
        ["hl1"]        = { name = "Half-Life: Source",     appId = 280 },
        ["hls"]        = { name = "Half-Life: Source",     appId = 280 },
        ["tf"]         = { name = "Team Fortress 2",       appId = 440 },
        ["tf2"]        = { name = "Team Fortress 2",       appId = 440 },
    }

    local found = {}
    local selfName = gameDir:match( "[^/\\]+$" ):lower()

    -- file.Find with "GAME" searches all mounted paths; we want the parent
    -- of the mod.  Walk the physical parent instead.
    local pDirs = file.FindDir( parentDir .. "/*", "GAME" )

    for _, folderName in ipairs( pDirs or {} ) do
        local lower = folderName:lower()
        if ( lower != selfName ) then
            local giPath = parentDir .. "/" .. folderName .. "/gameinfo.txt"
            if ( file.Exists( folderName .. "/gameinfo.txt", "GAME" ) ) then
                local info = Known[ lower ]
                table.insert( found, {
                    folder = folderName,
                    name   = info and info.name or folderName,
                    appId  = info and info.appId or 0,
                } )
            end
        end
    end

    table.sort( found, function( a, b ) return a.name:lower() < b.name:lower() end )
    return found
end

_G.HL2SB_DetectedGames = DetectInstalledGames()
Msg( "[HL2SB] Detected " .. #_G.HL2SB_DetectedGames .. " sibling Source game(s)\n" )
for _, g in ipairs( _G.HL2SB_DetectedGames ) do
    Msg( "  - " .. g.folder .. " (" .. g.name .. ", appid " .. g.appId .. ")\n" )
end
