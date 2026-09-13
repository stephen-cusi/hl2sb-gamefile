--[[
    HL2SB: mount extra Source games listed in gamecontent.txt at startup.

    The Content dialog writes gamecontent.txt with AppIds.  This autorun
    reads that file, finds the matching sibling game directory, and adds
    it to the GAME search path via filesystem.AddSearchPath -- the same
    mechanism the engine uses to mount hl2 / hl2mp.
]]

local FILE_PATH = engine.GetGameDirectory() .. "/gamecontent.txt"

-- AppId -> sibling folder name (case-sensitive as on disk).
local AppIdToFolder =
{
    [220] = "hl2",       -- Half-Life 2
    [320] = "hl2mp",     -- HL2 Deathmatch
    [380] = "hl2client", -- Episode One
    [420] = "ep2",       -- Episode Two
    [400] = "portal",    -- Portal
    [240] = "cstrike",   -- CS: Source
    [300] = "dod",       -- DoD: Source
    [280] = "hl1",       -- Half-Life: Source
    [360] = "hldeathmatch", -- HL DM: Source
    [440] = "tf",        -- TF2
}

local function MountGameApps()
    if ( not file.Exists( "gamecontent.txt", "MOD" ) ) then
        return
    end

    local kv = KeyValues( "GameContent" )
    if ( not kv:LoadFromFile( FILE_PATH, "MOD" ) ) then
        kv:deleteThis()
        return
    end

    local parentDir = engine.GetGameDirectory():match( "^(.*)[/\\][^/\\]+$" ) or ""

    local mounted = 0
    local fs = kv:GetData( "FileSystem" )
    if ( fs ) then
        local appIdKv = fs:GetFirstSubKey()
        while ( appIdKv ) do
            local id = tonumber( appIdKv:GetString() )
            local folder = id and AppIdToFolder[ id ]

            if ( folder ) then
                local path = parentDir .. "/" .. folder
                -- Verify the folder exists and has a gameinfo.txt.
                if ( file.Exists( folder .. "/gameinfo.txt", "GAME" ) ) then
                    filesystem.AddSearchPath( path .. "/", "GAME", PATH_ADD_TO_HEAD )
                    -- Also mount its VPKs if present.
                    local vpkDirs = file.Find( folder .. "/*.vpk", "GAME" )
                    for _, vpk in ipairs( vpkDirs or {} ) do
                        filesystem.AddSearchPath( path .. "/" .. vpk, "GAME", PATH_ADD_TO_HEAD )
                    end
                    Msg( "[HL2SB] Mounted " .. folder .. " (appid " .. id .. ")\n" )
                    mounted = mounted + 1
                else
                    Msg( "[HL2SB] Skipped appid " .. id .. " -- folder '" .. folder ..
                         "' not found next to game dir\n" )
                end
            else
                Msg( "[HL2SB] Unknown AppId " .. tostring( id ) .. " in gamecontent.txt\n" )
            end

            appIdKv = appIdKv:GetNextKey()
        end
    end

    kv:deleteThis()

    if ( mounted > 0 ) then
        Msg( "[HL2SB] " .. mounted .. " extra game(s) mounted\n" )
    end
end

-- Small delay so the filesystem is fully up.
timer.Simple( 0, MountGameApps )
