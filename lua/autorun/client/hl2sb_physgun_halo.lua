-- HL2SB GMod compat: the physgun held-entity halo.
--
-- Faithful port of sandbox/gamemode/cl_init.lua's DrawPhysgunBeam +
-- PreDrawHalos pair (the wiki facepunch.com/gmod/halo.Add reference shot --
-- glowing outlined props -- is exactly this code path):
--
--   * GM:DrawPhysgunBeam runs per frame from the engine's physgun draw;
--     returning nil keeps the default beam, and the held target is recorded;
--   * GM:PreDrawHalos runs once per frame from the halo library (see
--     lua/includes/modules/halo.lua, hooked on PostDrawEffects); the recorded
--     targets are handed to halo.Add with the PLAYER'S WEAPON COLOR plus a
--     small random jitter, exactly like GMod.
--
-- Differences from upstream, forced by this fork:
--   * `continue` does not exist in this Lua -- rewritten as plain ifs;
--   * math.Rand does not exist -- jitter uses math.random.

local PhysgunHalos = {}

hook.Add( "DrawPhysgunBeam", "HL2SB_PhysgunHaloCapture", function( ply, weapon, bOn, target, boneid, pos )

	local cvarHalo = GetConVar( "physgun_halo" )
	if ( cvarHalo != nil and cvarHalo:GetInt() == 0 ) then return end

	if ( IsValid( target ) ) then
		PhysgunHalos[ ply ] = target
	end

	-- return nil: the engine's default beam/glow keeps drawing

end )

hook.Add( "PreDrawHalos", "HL2SB_AddPhysgunHalos", function()

	if ( PhysgunHalos == nil or next( PhysgunHalos ) == nil ) then return end

	for k, v in pairs( PhysgunHalos ) do

		if ( IsValid( k ) ) then

			local size = math.random( 1, 2 )
			local colr = k:GetWeaponColor() + Vector( ( math.random() - 0.5 ) * 0.6, ( math.random() - 0.5 ) * 0.6, ( math.random() - 0.5 ) * 0.6 )

			halo.Add( PhysgunHalos, Color( colr.x * 255, colr.y * 255, colr.z * 255 ), size, size, 1, true, false )

		end

	end

	PhysgunHalos = {}

end )
