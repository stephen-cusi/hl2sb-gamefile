-- ===========================================================================
-- HL2SB NW / NW2 variable test (2026-10-11, issue #47).
--
-- Fully restart the game, enter a map (spawn once), then:
--   server console:  lua_dofile  nw2_lib_test.lua
-- The store is per-realm, so this run exercises whichever realm executes it;
-- run it on both consoles to cover both sides.
--
-- Facts under test:
--   * SetNW2*/GetNW2* exist on entities (issue #47: they were missing and
--     sv_vrnvgs died with "attempt to call a nil value (method 'SetNW2Bool')")
--   * NW and NW2 are separate tables: the same key through SetNWInt and
--     SetNW2Int must stay two independent values
--   * get with a default falls back to that default when never set
--   * GetNW2Entity answers an unset key with the NULL sentinel (never nil),
--     same as GetNWEntity
--   * NW1 Vector/Angle family: SetNWVector/GetNWVector/SetNWAngle/GetNWAngle
--   * Player:SetSuppressPickupNotices( bool ) exists on the server
-- ===========================================================================

local passed, failed = 0, 0
local function check( name, ok )
  if ( ok ) then
    passed = passed + 1
    print( "[nw2 ok] " .. name )
  else
    failed = failed + 1
    print( "[nw2 FAIL] " .. name )
  end
end

local ply = player.GetAll()[1]
check( "player found", ply ~= nil )
if ( ply == nil ) then
  print( string.format( "[nw2 test] %d passed, %d failed", passed, failed ) )
  return
end

-- unique-per-run keys so a re-run never reads yesterday's leftovers
local t = tostring( math.floor( CurTime() * 1000 ) )
local kInt   = "hl2sb_test_int_" .. t
local kStr   = "hl2sb_test_str_" .. t
local kFloat = "hl2sb_test_float_" .. t
local kBool  = "hl2sb_test_bool_" .. t
local kEnt   = "hl2sb_test_ent_" .. t
local kVec   = "hl2sb_test_vec_" .. t
local kAng   = "hl2sb_test_ang_" .. t
local kMiss  = "hl2sb_test_never_set_" .. t
local kIndep = "hl2sb_test_indep_" .. t

-- roundtrips
ply:SetNW2Int( kInt, 42 )
check( "SetNW2Int/GetNW2Int roundtrip", ply:GetNW2Int( kInt ) == 42 )

ply:SetNW2String( kStr, "hello" )
check( "SetNW2String/GetNW2String roundtrip", ply:GetNW2String( kStr ) == "hello" )

ply:SetNW2Float( kFloat, 1.5 )
check( "SetNW2Float/GetNW2Float roundtrip", math.abs( ply:GetNW2Float( kFloat ) - 1.5 ) < 0.0001 )

ply:SetNW2Bool( kBool, true )
check( "SetNW2Bool/GetNW2Bool roundtrip", ply:GetNW2Bool( kBool ) == true )

ply:SetNW2Entity( kEnt, ply )
check( "SetNW2Entity/GetNW2Entity roundtrip", ply:GetNW2Entity( kEnt ) == ply )

ply:SetNW2Vector( kVec, Vector( 1, 2, 3 ) )
local v = ply:GetNW2Vector( kVec )
check( "SetNW2Vector/GetNW2Vector roundtrip",
  v ~= nil and v.x == 1 and v.y == 2 and v.z == 3 )

ply:SetNW2Angle( kAng, Angle( 10, 20, 30 ) )
local a = ply:GetNW2Angle( kAng )
check( "SetNW2Angle/GetNW2Angle roundtrip",
  a ~= nil and a.pitch == 10 and a.yaw == 20 and a.roll == 30 )

-- defaults on a key that was never written
check( "GetNW2Int default", ply:GetNW2Int( kMiss, 7 ) == 7 )
check( "GetNW2String default", ply:GetNW2String( kMiss, "d" ) == "d" )
check( "GetNW2Float default", math.abs( ply:GetNW2Float( kMiss, 2.5 ) - 2.5 ) < 0.0001 )
check( "GetNW2Bool default", ply:GetNW2Bool( kMiss, true ) == true )
local vdef = ply:GetNW2Vector( kMiss, Vector( 4, 5, 6 ) )
check( "GetNW2Vector default",
  vdef ~= nil and vdef.x == 4 and vdef.y == 5 and vdef.z == 6 )

-- unset entity var answers with the NULL sentinel, never nil (portalgun
-- contract on GetNWEntity; NW2 mirrors it)
local nul = ply:GetNW2Entity( kMiss )
check( "GetNW2Entity unset is not nil", nul ~= nil )
check( "GetNW2Entity unset is not valid", not IsValid( nul ) )

-- NW and NW2 are separate tables: same key, two independent values
ply:SetNWInt( kIndep, 7 )
ply:SetNW2Int( kIndep, 9 )
check( "NW/NW2 key independence (NW1 side)", ply:GetNWInt( kIndep ) == 7 )
check( "NW/NW2 key independence (NW2 side)", ply:GetNW2Int( kIndep ) == 9 )

-- NW1 Vector/Angle family (was missing alongside NW2)
ply:SetNWVector( kVec, Vector( 9, 8, 7 ) )
local v1 = ply:GetNWVector( kVec )
check( "SetNWVector/GetNWVector roundtrip",
  v1 ~= nil and v1.x == 9 and v1.y == 8 and v1.z == 7 )
check( "GetNWVector default", ply:GetNWVector( kMiss, Vector( 1, 1, 1 ) ).x == 1 )

ply:SetNWAngle( kAng, Angle( 45, 46, 47 ) )
local a1 = ply:GetNWAngle( kAng )
check( "SetNWAngle/GetNWAngle roundtrip",
  a1 ~= nil and a1.pitch == 45 and a1.yaw == 46 and a1.roll == 47 )
check( "GetNWAngle default", ply:GetNWAngle( kMiss, Angle( 5, 5, 5 ) ).pitch == 5 )

-- server-only mute switch used by the NVG addon around its weapon give/strip
if ( SERVER ) then
  local ok, err = pcall( function()
    ply:SetSuppressPickupNotices( true )
    ply:SetSuppressPickupNotices( false )
  end )
  check( "SetSuppressPickupNotices callable", ok )
  if ( not ok ) then print( "[nw2] err: " .. tostring( err ) ) end
else
  check( "SetSuppressPickupNotices is server-side", true )
end

print( string.format( "[nw2 test] %d passed, %d failed", passed, failed ) )
