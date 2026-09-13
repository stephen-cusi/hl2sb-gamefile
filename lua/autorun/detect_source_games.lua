--[[
    HL2SB: detect installed Source games in sibling directories.

    Exposes two globals:

      _G.HL2SB_DetectSourceGames()  the detector itself, so a caller in another
                                    Lua state (lua/gameui/contentsubgames.lua --
                                    the menu realm is a separate state) can run
                                    it instead of depending on this file's
                                    load-time result;
      _G.HL2SB_DetectedGames        the result, filled in once at load time;
      _G.HL2SB_DetectInfo           what the last run saw, for diagnostics.

    The listing goes through GMod's own file API:

      * the folder is "BASE_PATH", GMod's ID for the directory the launcher
        lives in -- which is this mod's parent
        (https://wiki.facepunch.com/gmod/File_Search_Paths).  "GAME" cannot see
        a sibling install: it mounts each game's CONTENTS at its own root, so
        "hl2/gameinfo.txt" is not addressable there.

      * file.Find( name, path ) returns ( files, directories ), so the folder
        list is the SECOND return value.  There is no file.FindDir in GMod, and
        an invalid path comes back as nil/nil, hence the `or {}`.
]]
if ( not engine or not engine.GetGameDirectory or not file or not file.Find ) then
    return
end

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

local function DetectInstalledGames()
    local info = { selfName = "", baseDirs = -1, candidates = {}, found = 0 }
    _G.HL2SB_DetectInfo = info

    local gameDir = engine.GetGameDirectory()
    if ( not gameDir ) then return {} end

    local found = {}
    local selfName = gameDir:match( "[^/\\]+$" )
    selfName = selfName and selfName:lower() or ""
    info.selfName = selfName
    info.gameDir = gameDir

    local _, pDirs = file.Find( "*", "BASE_PATH" )
    info.baseDirs = table.Count( pDirs or {} )

    for _, folderName in ipairs( pDirs or {} ) do
        local lower = folderName:lower()

        if ( #info.candidates < 24 ) then
            table.insert( info.candidates, folderName )
        end

        if ( lower != selfName ) then
            local hasGameInfo = file.Exists( folderName .. "/gameinfo.txt", "BASE_PATH" )
            info[ "probe_" .. folderName ] = hasGameInfo and 1 or 0

            if ( hasGameInfo ) then
                local known = Known[ lower ]
                table.insert( found, {
                    folder = folderName,
                    name   = known and known.name or folderName,
                    appId  = known and known.appId or 0,
                } )
            end
        end
    end

    info.found = #found
    table.sort( found, function( a, b ) return a.name:lower() < b.name:lower() end )
    return found
end

-- For callers in another Lua state (the menu realm).
_G.HL2SB_DetectSourceGames = DetectInstalledGames

if ( not _G.HL2SB_DetectedGames ) then
    _G.HL2SB_DetectedGames = DetectInstalledGames()

    -- Msg is a game-realm global (lsrcinit.cpp), not a language builtin; the menu
    -- realm has no such name.  print is there in both.
    local say = Msg or print
    say( "[HL2SB] Detected " .. #_G.HL2SB_DetectedGames .. " sibling Source game(s)\n" )
    for _, g in ipairs( _G.HL2SB_DetectedGames ) do
        say( "  - " .. g.folder .. " (" .. g.name .. ", appid " .. g.appId .. ")\n" )
    end

    --[[
        And to disk, because neither realm's console is a reliable read-back:
        lua/autorun/*.lua runs at startup, before autoexec.cfg has opened the
        console log, so these lines are usually lost.  Two files (one per realm)
        so a server-realm result never overwrites the client's -- the mount path
        (lua/autorun/mount_games.lua) runs on the server, the dialog on the
        client/menu side, and they can disagree.

        Written under data/ (the path ID GMod's file.Write is constrained to).
    ]]
    if ( file and file.Write ) then
        local realm = ( CLIENT and "client" ) or ( SERVER and "server" ) or "unknown"
        local out = {
            "HL2SB sibling-game detection -- realm=" .. realm,
            "gameDir=" .. tostring( _G.HL2SB_DetectInfo and _G.HL2SB_DetectInfo.gameDir ),
            "selfName=" .. tostring( _G.HL2SB_DetectInfo and _G.HL2SB_DetectInfo.selfName ),
            "baseDirs=" .. tostring( _G.HL2SB_DetectInfo and _G.HL2SB_DetectInfo.baseDirs ),
            "found=" .. tostring( #_G.HL2SB_DetectedGames ),
        }
        local info = _G.HL2SB_DetectInfo
        if ( info ) then
            for k, v in pairs( info ) do
                if ( type( k ) == "string" and k:sub( 1, 6 ) == "probe_" ) then
                    table.insert( out, "probe " .. k:sub( 7 ) .. " gameinfo=" .. tostring( v ) )
                end
            end
            if ( info.candidates ) then
                table.insert( out, "base dirs: " .. table.concat( info.candidates, "," ) )
            end
        end
        for _, g in ipairs( _G.HL2SB_DetectedGames ) do
            table.insert( out, "  " .. g.folder .. " / " .. g.name .. " / " .. tostring( g.appId ) )
        end
        file.Write( "hl2sb_detect_" .. realm .. ".txt", table.concat( out, "\n" ) .. "\n" )
    end
end
