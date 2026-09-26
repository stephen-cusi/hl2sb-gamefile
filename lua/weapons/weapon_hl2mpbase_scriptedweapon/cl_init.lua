--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Initialize the base scripted weapon.
--
--===========================================================================--

include( "shared.lua" )

function SWEP:DrawLargeWeaponBox( bSelected, xpos, ypos, boxWide, boxTall, selectedColor, alpha, number )
end

-- HL2SB (2026-09-27): a `SWEP:DrawModel( flags )` EMPTY STUB used to live here,
-- and it silently swallowed every scripted weapon's model draw.
--
-- Why: the engine sets SWEP.__base = "weapon_hl2mpbase_scriptedweapon" on every
-- scripted weapon (luasrc_LoadOneWeapon), so this base's fields are inherited
-- into every SWEP.  Both of these then resolved to the empty stub instead of
-- the real entity draw:
--
--   * CHL2MPScriptedWeapon::DrawModel() -> Lua SWEP:DrawModel (the virtual)
--   * SWEP:DrawWorldModel (weapon_base)  -> self:DrawModel()
--
-- Result: no SWEP world model was ever drawn, in third person or in a mirror --
-- the reported "SWEPs have no model".  GMod's own weapon base defines no
-- SWEP:DrawModel at all; the lookup falls through to the entity metatable's
-- Entity:DrawModel (CBaseAnimating_DrawModel -> InternalDrawModel), which is the
-- draw that actually renders the model.  Matched here by deleting the stub.
--
-- (Addons and derived bases may still define their own SWEP:DrawModel to
-- replace the draw, exactly as in GMod.)

function SWEP:MuzzleFlash( pos1, angles, type, firstPerson )
end
