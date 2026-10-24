-- Legacy engine and gamemode spellings stay outside the original libraries.
table.copy = table.Copy
table.merge = table.Merge
table.inherit = table.Inherit
table.hasvalue = table.HasValue

-- Legacy fork spellings remain outside the original gamemode module.
if ( gamemode ) then
    gamemode.get = gamemode.Get
    gamemode.register = gamemode.Register
    gamemode.call = gamemode.Call
end

if ( CLIENT ) then
    concommand.Add( "+showscoreboard", function() hook.Run( "ScoreboardShow" ) end )
    concommand.Add( "-showscoreboard", function() hook.Run( "ScoreboardHide" ) end )
end

hook.Add( "OnGamemodeLoaded", "HL2SB.LegacySpawnChain", function()
    local base = gamemode.Get( "base" )
    if ( base ) then base.PlayerSpawnChain = base.PlayerSpawn end
    if ( GAMEMODE and GAMEMODE.PlayerSpawnChain == nil and base ) then
        GAMEMODE.PlayerSpawnChain = base.PlayerSpawn
    end
end )
