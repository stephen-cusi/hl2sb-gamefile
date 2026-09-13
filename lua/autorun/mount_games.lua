--[[
    HL2SB: mount extra Source games listed in gamecontent.txt at startup.

    The Content dialog (lua/gameui/contentsubgames.lua) writes gamecontent.txt
    with Steam AppIds the user checked.  This autorun reads that file and calls
    filesystem.MountSteamContent( appId ) for each, so the game's maps /
    materials / models become available.

    Format written by OnApplyChanges:

        "GameContent"
        {
            "FileSystem"
            {
                "AppId" "220"   // Half-Life 2
                "AppId" "400"   // Portal
            }
        }
]]

local FILE_PATH = engine.GetGameDirectory() .. "/gamecontent.txt"

local AppNames =
{
    [220]  = "Half-Life 2",
    [240]  = "Counter-Strike: Source",
    [280]  = "Half-Life: Source",
    [300]  = "Day of Defeat: Source",
    [340]  = "Half-Life 2: Lost Coast",
    [360]  = "Half-Life Deathmatch: Source",
    [380]  = "Half-Life 2: Episode One",
    [400]  = "Portal",
    [420]  = "Half-Life 2: Episode Two",
    [440]  = "Team Fortress 2",
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

    local mounted = 0
    local fs = kv:GetData( "FileSystem" )
    if ( fs ) then
        local appId = fs:GetFirstSubKey()
        while ( appId ) do
            local id = tonumber( appId:GetString() )
            if ( id and id > 0 ) then
                local name = AppNames[ id ] or ( "App " .. id )
                local ret = filesystem.MountSteamContent( id )
                if ( ret == 0 ) then
                    Msg( "[HL2SB] Mounted " .. name .. " (appid " .. id .. ")\n" )
                    mounted = mounted + 1
                else
                    Msg( "[HL2SB] FAILED to mount " .. name ..
                         " (appid " .. id .. ", ret " .. tostring( ret ) .. ")\n" )
                end
            end
            appId = appId:GetNextKey()
        end
    end

    kv:deleteThis()

    if ( mounted > 0 ) then
        Msg( "[HL2SB] " .. mounted .. " extra game(s) mounted from gamecontent.txt\n" )
    end
end

-- Small delay so the filesystem is fully up before we add search paths.
timer.Simple( 0, MountGameApps )
