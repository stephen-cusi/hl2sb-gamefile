-- HL2SB (2026-09-26): the physgun halo wiring, now the UPSTREAM sandbox
-- gamemode block line-for-line (garrysmod/gamemodes/sandbox/gamemode/
-- cl_init.lua, the PhysgunHalos section) -- the user's standing order is
-- "halo must be GMod's, reference and reimplemented".  GMod's halo colour,
-- jitter and lifecycle below are the sandbox originals:
--
--   GM:DrawPhysgunBeam( ply, weapon, bOn, target, boneid, pos )
--       records the held target and returns true (the engine contract:
--       only a LITERAL false suppresses the default beam);
--   hook "PreDrawHalos"
--       feeds halo.Add the WHOLE ply-keyed table with the player's
--       GetWeaponColor + VectorRand()*0.3 shimmer, one pass per player,
--       and clears the table -- the ring lives exactly as long as the
--       hold and dies the frame the beam stops.
--
-- Fork adaptations (all invisible):
--   * this is an autorun file, so the GM method is registered through
--     hook.Add instead -- the engine dispatch (hook.Call + gamemode
--     fallback) treats a registered hook returning true identically;
--   * physgun_halo is read through GetConVar/ConVar (sandbox reads an
--     auto-global convar object this engine does not publish);
--   * Player:GetWeaponColor answers the LIVE cl_weaponcolor for the local
--     player (the C++ map only fills at spawn), so the ring and the beam
--     cannot flash between two colours mid-session.

-- HL2SB: the C++ whole-body glow shell (physgun_halo_shell,
-- c_baseanimating.cpp) would double-draw against this outline.  Archived
-- convars are written back at shutdown with their LIVE values, so the shell
-- is forced off where the ring lives instead of trusting config.cfg.
do
	local cv = ( type( GetConVar ) == "function" ) and GetConVar( "physgun_halo_shell" ) or nil
	if ( cv == nil && type( ConVar ) == "function" ) then
		local ok, c = pcall( ConVar, "physgun_halo_shell" )
		cv = ok and c or nil
	end
	if ( cv != nil && cv.SetInt != nil ) then
		pcall( cv.SetInt, cv, 0 )
	end
end

local PhysgunHalos = {}

hook.Add( "DrawPhysgunBeam", "HL2SB_PhysgunHaloCapture", function( ply, weapon, bOn, target, boneid, pos )

	-- sandbox: if ( physgun_halo:GetInt() == 0 ) then return true end
	local cvar = ( type( GetConVar ) == "function" ) and GetConVar( "physgun_halo" ) or nil
	if ( cvar == nil && type( ConVar ) == "function" ) then
		local ok, c = pcall( ConVar, "physgun_halo" )
		cvar = ok and c or nil
	end
	if ( cvar != nil && cvar.GetInt != nil ) then
		local ok, n = pcall( cvar.GetInt, cvar )
		if ( ok && n == 0 ) then return true end
	end

	if ( IsValid( target ) ) then
		PhysgunHalos[ ply ] = target
	end

	return true

end )

hook.Add( "PreDrawHalos", "AddPhysgunHalos", function()

	if ( !PhysgunHalos || table.IsEmpty( PhysgunHalos ) ) then return end

	for k, v in pairs( PhysgunHalos ) do

		if ( !IsValid( k ) ) then continue end

		local size = math.random( 1, 2 )
		local colr = k:GetWeaponColor() + VectorRand() * 0.3

		halo.Add( PhysgunHalos, Color( colr.x * 255, colr.y * 255, colr.z * 255 ), size, size, 1, true, false )

	end

	PhysgunHalos = {}

end )
