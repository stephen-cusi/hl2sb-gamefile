-- HL2SB GMod compat: the physgun held-entity halo.
--
-- 2026-09-24 (final): the held-entity GLOW is drawn NATIVELY -- the C++ shell
-- in c_baseanimating.cpp (additive pass tinted through the material's $color
-- var with cl_weaponcolor + a hold pulse) plus a weapon-colour dlight wash.
-- This file therefore does NOT feed halo.Add for the physgun: every Lua-side
-- tint mechanism (SetColourModulation on override draws, the Material() stub
-- wrapper's SetTexture/SetString) is dead in this branch, and the RT
-- pipeline's restore/composite could not be verified end to end.  The
-- capture hook stays registered and returns true so GM:DrawPhysgunBeam stays
-- overridable for addons and the engine's default beam keeps drawing.
--
-- The halo library (lua/includes/modules/halo.lua, halo_draw) remains for
-- addon halo.Add calls.

hook.Add( "DrawPhysgunBeam", "HL2SB_PhysgunHaloCapture", function( ply, weapon, bOn, target, boneid, pos )
	return true
end )
