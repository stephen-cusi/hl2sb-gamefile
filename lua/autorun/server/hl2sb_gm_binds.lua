-- HL2SB: GMod's base-gamemode server concommands behind the GAMEMODES
-- keyboard options (F1 Open help / F2 Open team menu). Addons gamemode the
-- ShowHelp / ShowTeam hooks; the binds in scripts/kb_act.lst just need the
-- commands to exist and fire them.

if not SERVER then return end

local function FireHook( ply, hookName )
	hook.Call( hookName, GAMEMODE, ply )
end

concommand.Add( "gm_showhelp", function( ply ) FireHook( ply, "ShowHelp" ) end, nil, "Open help", { FCVAR_DONTRECORD } )
concommand.Add( "gm_showteam", function( ply ) FireHook( ply, "ShowTeam" ) end, nil, "Open team menu", { FCVAR_DONTRECORD } )
concommand.Add( "gm_showspawns", function( ply ) FireHook( ply, "ShowSpawns" ) end, nil, "Open spawn menu", { FCVAR_DONTRECORD } )
