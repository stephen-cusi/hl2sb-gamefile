--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Ammo type definitions for the Deathmatch gamemode.
--
--          Included by shared.lua, so the server and the client always load
--          the same table. The engine reads it once per map load
--          (luasrc_SetGamemode -> luasrc_ApplyAmmoTypes).
--
--          Only the fields written here are changed; anything omitted keeps
--          the value the engine registered in GetAmmoDef().
--
--          Deathmatch is the base gamemode, so this is also what Campaign
--          inherits.
--
--===========================================================================--

-- 基础值:HL2MP 原版携带上限。
ammo.register( { name = "Pistol",       maxcarry = 150 } )
ammo.register( { name = "SMG1",         maxcarry = 225 } )
ammo.register( { name = "AR2",          maxcarry = 60 } )
ammo.register( { name = "AR2AltFire",   maxcarry = 3 } )
ammo.register( { name = "357",          maxcarry = 12 } )
ammo.register( { name = "XBowBolt",     maxcarry = 10 } )
ammo.register( { name = "Buckshot",     maxcarry = 30 } )
ammo.register( { name = "RPG_Round",    maxcarry = 3 } )
ammo.register( { name = "SMG1_Grenade", maxcarry = 3 } )
ammo.register( { name = "Grenade",      maxcarry = 5 } )
ammo.register( { name = "slam",         maxcarry = 5 } )

-- 想改伤害 / 曳光 / 溅射,加对应字段即可,例如:
-- ammo.register( { name = "Buckshot", dmgtype = ammo.DMG_BUCKSHOT, maxsplash = 12 } )
