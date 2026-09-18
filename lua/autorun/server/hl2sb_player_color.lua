-- hl2sb_player_color.lua
-- ---------------------------------------------------------------------------
-- Per-player colour, applied on spawn - the GMod way.
--
-- Verbatim source (garrysmod/gamemodes/sandbox/gamemode/player_class/
-- player_sandbox.lua:104-117):
--
--     function PLAYER:Spawn()
--         BaseClass.Spawn( self )
--         local plyclr = self.Player:GetInfo( "cl_playercolor" )
--         self.Player:SetPlayerColor( Vector( plyclr ) )
--         local wepclr = Vector( self.Player:GetInfo( "cl_weaponcolor" ) )
--         if ( wepclr:Length() < 0.001 ) then wepclr = Vector( 0.001, 0.001, 0.001 ) end
--         self.Player:SetWeaponColor( wepclr )
--     end
--
-- So the two cl_* convars the player model selector writes ARE the answer; there is no
-- second colour scheme in GMod.
--
-- ⚠️ This file used to hand out a fixed four-colour palette picked from the userid
-- (`c = palette[ ( id % #palette ) + 1 ]; ply:SetPlayerColor( c )`).  That overwrote
-- whatever the selector had just chosen, on every spawn - the colour survived until the
-- player died and then snapped back to the palette entry: "调完颜色重生几次就没了"
-- (2026-09-17).  Nothing in GMod does that.
-- ---------------------------------------------------------------------------

--- The convars are "r g b" in 0-1, the same format GMod's Vector( string ) overload
--- reads.  Guarded because Vector( "" ) is an error and a client that never set the
--- convar (a bot, a very early spawn) answers an empty string.
local function ConVarVector( ply, name, fallback )
	local v = ply:GetInfo( name )

	if ( type( v ) ~= "string" ) then return fallback end

	local r, g, b = string.match( v, "^%s*(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)%s*$" )

	if ( r == nil ) then return fallback end

	return Vector( tonumber( r ), tonumber( g ), tonumber( b ) )
end

-- PlayerSpawn hook receives the player as its first argument
-- (hl2mp_gamerules.cpp:431 BEGIN_LUA_CALL_HOOK( "PlayerSpawn" )).
hook.Add( "PlayerSpawn", "hl2sb_player_color", function( ply )
	if ( not IsValid( ply ) ) then return end

	-- The engine takes a normalized Vector (Player:SetPlayerColor) exactly like GMod's.
	ply:SetPlayerColor( ConVarVector( ply, "cl_playercolor", Vector( 1, 1, 1 ) ) )

	-- GMod guards the all-black weapon colour (its own default is "0.30 1.80 2.10").
	local wepclr = ConVarVector( ply, "cl_weaponcolor", Vector( 1, 1, 1 ) )

	if ( wepclr:Length() < 0.001 ) then wepclr = Vector( 0.001, 0.001, 0.001 ) end

	ply:SetWeaponColor( wepclr )
end )
