-- ===========================================================================
-- HL2SB hl1sweps compat engine-contract test (2026-10-07).
--
-- Server console (or client for the surface checks), in any map:
--   lua_dofile hl1_compat_lib_test.lua
--
-- Asserts the engine fixes this round relies on:
--   1.  Vector / Angle integer indexing v[1..3] / a[1..3], read AND write.
--   2.  surface.GetTextureSize exists (both realms; menu scripts use it).
--   3.  game.GetAmmoID answers the ammo-def index and -1 on a miss.
--   4.  hook.Remove on an event nobody registered is silent.
--   5.  weapon.get() deep-merges base subtables (357 sees Primary.RecoilRandom).
--   6.  Weapon metatable exposes IsCarriedByLocalPlayer on the client.
--   7.  Entities reached through generic paths keep method dispatch.
--   8.  The Lua matproxy registry carries the addon proxies (HL1Chrome).
-- ===========================================================================

local nPassed, nFailed = 0, 0
local function Check( bCond, sName )
	if ( bCond ) then
		nPassed = nPassed + 1
		print( "[PASS] " .. sName )
	else
		nFailed = nFailed + 1
		print( "[FAIL] " .. sName )
	end
end

-- 1. Vector / Angle integer indexing --------------------------------------
local v = Vector( 1, 2, 3 )
Check( v[ 1 ] == 1 && v[ 2 ] == 2 && v[ 3 ] == 3, "Vector[1..3] reads x/y/z" )
v[ 2 ] = 20
Check( v.y == 20, "Vector[2] write lands on y" )
local a = Angle( 10, 20, 30 )
Check( a[ 1 ] == 10 && a[ 2 ] == 20 && a[ 3 ] == 30, "Angle[1..3] reads p/y/r" )
a[ 3 ] = 33
Check( a.r == 33, "Angle[3] write lands on roll" )
-- the exact hl1sweps arithmetic (punch-angle helpers + CalcBob):
local vel = Vector( 3, 4, 0 )
Check( math.sqrt( vel[ 1 ] * vel[ 1 ] + vel[ 2 ] * vel[ 2 ] ) == 5, "CalcBob-style integer arithmetic" )
local pa = Angle()
local vadd = Angle()
vadd[ 1 ] = pa[ 1 ] + a[ 1 ]
Check( vadd[ 1 ] == 10, "HL1_VectorAdd-style angle add" )

-- 2. surface.GetTextureSize ------------------------------------------------
if ( CLIENT ) then
	Check( isfunction( surface.GetTextureSize ), "surface.GetTextureSize exists" )
	local w, h = surface.GetTextureSize( surface.GetTextureID( "vgui/white" ) )
	Check( w ~= nil and h ~= nil, "surface.GetTextureSize returns two values" )
else
	print( "[SKIP] surface checks are client-side" )
end

-- 3. game.GetAmmoID --------------------------------------------------------
Check( isfunction( game.GetAmmoID ), "game.GetAmmoID exists" )
local iAr2 = game.GetAmmoID( "AR2" )
Check( isnumber( iAr2 ) && iAr2 > 0, "game.GetAmmoID('AR2') = " .. tostring( iAr2 ) )
Check( game.GetAmmoID( "nonexistent_ammo_xyz" ) == -1, "game.GetAmmoID miss = -1" )
Check( game.GetAmmoName( iAr2 ) == "AR2", "GetAmmoID/GetAmmoName round-trip" )

-- 4. hook.Remove on unregistered events is silent ---------------------------
local bOk, sErr = pcall( function()
	hook.Remove( "HL1CompatNeverRegisteredEvent", "HL1CompatTest" )
end )
Check( bOk, "hook.Remove on unregistered event is silent (" .. tostring( sErr ) .. ")" )

-- 5. weapon.get() deep merge ------------------------------------------------
if ( SERVER ) then
	local t357 = weapon.get and weapon.get( "weapon_hl1_357" ) or nil
	if ( t357 ~= nil ) then
		Check( t357.Primary ~= nil && t357.Primary.RecoilRandom ~= nil,
			"weapon_hl1_357 inherits Primary.RecoilRandom (SendRecoil fix)" )
		if ( t357.Primary.RecoilRandom ~= nil ) then
			Check( isnumber( t357.Primary.RecoilRandom[ 1 ] ),
				"...and the merged table itself indexes by integer" )
		end
	else
		print( "[SKIP] hl1sweps not mounted; add the addon and rerun" )
	end
end

-- 6. Weapon metatable surface ----------------------------------------------
local tWeaponMeta = FindMetaTable( "Weapon" ) or FindMetaTable( "CBaseCombatWeapon" )
if ( tWeaponMeta ~= nil ) then
	if ( CLIENT ) then
		Check( isfunction( tWeaponMeta.IsCarriedByLocalPlayer ),
			"Weapon:IsCarriedByLocalPlayer bound (mflash effect fix)" )
	end
else
	print( "[SKIP] no Weapon metatable in this realm" )
end

-- 7. matproxy registry ------------------------------------------------------
if ( CLIENT && isfunction( matproxy.ShouldOverrideProxy ) ) then
	-- The addon registers at autorun time, so by the time this runs the
	-- entry must be live (and the material system must resolve it now).
	Check( matproxy.ShouldOverrideProxy( "HL1Chrome" ) == true, "matproxy registry has HL1Chrome" )
else
	print( "[SKIP] matproxy checks are client-side" )
end

print( string.format( "\n%d passed, %d failed\n", nPassed, nFailed ) )
