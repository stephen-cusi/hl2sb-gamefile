-- HL2SB GMod compat: the physgun held-entity halo.
--
-- Complete port of the sandbox gamemode pair that produces the wiki
-- halo.Add reference look (held prop outlined in the player's weapon
-- color), verified against garrysmod/gamemodes/sandbox/gamemode/cl_init.lua
-- (lines 121-155) and the wiki pages halo / halo.Add / GM:DrawPhysgunBeam /
-- GM:PreDrawHalos:
--
--   GM:DrawPhysgunBeam( ply, weapon, enabled, target, physBone, hitPos )
--     fired per frame from the engine's physgun draw (both the third-person
--     and viewmodel paths in game/shared/hl2sb/weapon_physgun.cpp); a
--     literal false would suppress the default beam, so we always return
--     true and just record the held target;
--   GM:PreDrawHalos
--     fired once per frame from the halo library's own PostDrawEffects
--     hook (lua/includes/modules/halo.lua); hands the recorded targets
--     to halo.Add, then clears the table.
--
-- Fork differences (all verified in the engine tree, 2026-09-23):
--   * `continue` EXISTS in this Lua (lua/src/lparser.c has TK_CONTINUE;
--     modules/halo.lua already uses it) -- kept from upstream.  The old
--     "continue does not exist" note was wrong.
--   * The `physgun_halo` ConVar is already defined ENGINE-SIDE
--     (game/client/lua/lrender.cpp, same name/default/archive as sandbox
--     cl_init.lua:24) -- queried with GetConVar, not created again.
--   * VectorRand / math.Rand do not exist in this fork's Lua -- the jitter
--     uses math.random with the identical [-0.3, 0.3] range of
--     VectorRand() * 0.3.
--   * halo.Add( PhysgunHalos, ... ) passes the WHOLE table per valid
--     holding player, exactly like upstream (the 2026-09-23 "PERF" rewrite
--     to per-player single-target calls deviated from GMod and is reverted).

local PhysgunHalos = {}

local physgun_halo = GetConVar( "physgun_halo" )

hook.Add( "DrawPhysgunBeam", "HL2SB_PhysgunHaloCapture", function( ply, weapon, bOn, target, boneid, pos )

	if ( physgun_halo != nil and physgun_halo:GetInt() == 0 ) then return true end

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
		local colr = k:GetWeaponColor() + Vector( ( math.random() - 0.5 ) * 0.6, ( math.random() - 0.5 ) * 0.6, ( math.random() - 0.5 ) * 0.6 )

		halo.Add( PhysgunHalos, Color( colr.x * 255, colr.y * 255, colr.z * 255 ), size, size, 1, true, false )

	end

	PhysgunHalos = {}

end )
