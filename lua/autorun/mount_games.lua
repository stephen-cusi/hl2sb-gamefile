--[[
    HL2SB: mount extra Source games listed in gamecontent.txt at startup.

    gamecontent.txt is plain text, one AppId per line:
        220
        320
]]

local FILE_PATH = engine.GetGameDirectory() .. "/gamecontent.txt"

local AppIdToFolder =
{
    [220] = "hl2",
    [320] = "hl2mp",
    [380] = "hl2client",
    [420] = "ep2",
    [400] = "portal",
    [240] = "cstrike",
    [300] = "dod",
    [280] = "hl1",
    [360] = "hldeathmatch",
    [440] = "tf",
}

local function MountGameApps()
    local f = io.open( FILE_PATH, "r" )
    if ( not f ) then return end

    local parentDir = engine.GetGameDirectory():match( "^(.*)[/\\][^/\\]+$" ) or ""
    local mounted = 0

    for line in f:lines() do
        local id = tonumber( line:match( "%s*(%d+)%s*" ) )
        local folder = id and AppIdToFolder[ id ]

        if ( folder ) then
            local path = parentDir .. "/" .. folder
            if ( file.Exists( folder .. "/gameinfo.txt", "GAME" ) ) then
                filesystem.AddSearchPath( path .. "/", "GAME", PATH_ADD_TO_HEAD )
                local vpkFiles = file.Find( folder .. "/*.vpk", "GAME" )
                for _, vpk in ipairs( vpkFiles or {} ) do
                    filesystem.AddSearchPath( path .. "/" .. vpk, "GAME", PATH_ADD_TO_HEAD )
                end
                Msg( "[HL2SB] Mounted " .. folder .. " (appid " .. id .. ")\n" )
                mounted = mounted + 1
            else
                Msg( "[HL2SB] Skipped appid " .. id .. " -- '" .. folder .. "' not found\n" )
            end
        elseif ( id ) then
            Msg( "[HL2SB] Unknown AppId " .. id .. " in gamecontent.txt\n" )
        end
    end

    f:close()

    if ( mounted > 0 ) then
        Msg( "[HL2SB] " .. mounted .. " extra game(s) mounted\n" )
    end
end

timer.Simple( 0, MountGameApps )
