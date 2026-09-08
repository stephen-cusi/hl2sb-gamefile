-- hl2sb_player_color.lua
-- ---------------------------------------------------------------------------
-- Basic GMod-style per-player sleeve colour.
--
-- The C++ "PlayerColor" material proxy renders the c_arms sleeves in the
-- colour the player picked. The colour decision is made HERE in Lua (the GMod
-- way); the engine only transports it ( player:SetPlayerColor -> the client's
-- c_hands proxy ) and never decides which colour a player gets.
--
-- To change the scheme, edit the palette / logic below - no C++ rebuild.
-- ---------------------------------------------------------------------------

require( "hook" )

-- PlayerSpawn hook receives the player as its first argument.
hook.add( "PlayerSpawn", "hl2sb_player_color", function( ply )
	if not ply then return end

	-- Palette cycled by the player's userid so repeat spawns stay consistent.
	local palette = {
		Color( 62, 88, 106 ),    -- GMod teal (default)
		Color( 200, 70, 70 ),    -- red
		Color( 70, 130, 200 ),   -- blue
		Color( 90, 170, 90 ),    -- green
	}

	local id = ply:GetUserID() or 0
	local c = palette[ ( id % #palette ) + 1 ]

	ply:SetPlayerColor( c )
end )
