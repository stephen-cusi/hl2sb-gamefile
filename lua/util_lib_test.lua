-- Verification probe for the rebuilt GMod util library (2026-09-25):
--   * codecs: Base64Encode/Decode, CRC, MD5, SHA1, SHA256, Compress/Decompress
--   * SteamIDTo64/From64, SharedRandom, AimVector, DistanceToLine
--   * IntersectRayWith* family + Is*Intersecting* family
--   * surface props, model membership, activity/anim-event lookups
--   * Lua side: TableToKeyValues, KeyValuesToTablePreserveOrder, GetUserGroups,
--     NetworkStringToID/NetworkIDToString, TimerCycle
-- Run from the console after a FULL restart (DLLs only load at process start):
--     lua_dofile util_lib_test.lua       (server realm)
--     lua_dofile_cl util_lib_test.lua    (client realm)
-- Safe to delete afterwards.

local nPassed = 0
local nFailed = 0

local function Check( label, ok, extra )
	if ok then
		nPassed = nPassed + 1
		print( "  PASS  " .. label )
	else
		nFailed = nFailed + 1
		print( "  FAIL  " .. label .. ( extra ~= nil and ( "   (" .. tostring( extra ) .. ")" ) or "" ) )
	end
end

local function Near( a, b, eps )
	if ( type( a ) ~= "number" or type( b ) ~= "number" ) then return false end
	return math.abs( a - b ) <= eps
end

print( "==================== util library probe ====================" )

-- ---------------------------------------------------------------------------
-- 1. codecs
-- ---------------------------------------------------------------------------
Check( "Base64Encode wiki example",
	util.Base64Encode( "Base64 Encoding" ) == "QmFzZTY0IEVuY29kaW5n",
	util.Base64Encode( "Base64 Encoding" ) )

local nLong = string.rep( "x", 200 )
local sB64 = util.Base64Encode( nLong )
if ( type( sB64 ) == "string" ) then
	Check( "Base64Encode RFC2045 has line breaks",	sB64:find( "\n" ) ~= nil )
	Check( "Base64Encode inline has no breaks",		util.Base64Encode( nLong, true ):find( "\n" ) == nil )
	Check( "Base64Decode roundtrip",				util.Base64Decode( sB64 ) == nLong )
else
	Check( "Base64Encode RFC2045 has line breaks", false, tostring( sB64 ) )
end
Check( "Base64Decode bad input -> nil",			util.Base64Decode( "!!!!" ) == nil )

Check( "CRC wiki example (CRC of 'a')",
	util.CRC( "a" ) == "3904355907", util.CRC( "a" ) )

Check( "MD5 known vector",	util.MD5( "abc" ) == "900150983cd24fb0d6963f7d28e17f72", util.MD5( "abc" ) )
Check( "SHA1 known vector",	util.SHA1( "abc" ) == "a9993e364706816aba3e25717850c26c9cd0d89d", util.SHA1( "abc" ) )
Check( "SHA256 known vector", util.SHA256( "abc" ) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", util.SHA256( "abc" ) )

-- Compress / Decompress
local sEmpty = util.Compress( "" )
Check( "Compress('') == ''", sEmpty == "", sEmpty )

local sRaw = string.rep( "Hello HL2SB! ", 2000 )
local sZip = util.Compress( sRaw )
Check( "Compress shrinks repetitive data",	sZip ~= nil and #sZip < #sRaw, sZip and #sZip or "nil" )
Check( "Compress has 8-byte size prefix",	sZip ~= nil and sZip:byte( 1 ) == ( #sRaw % 256 ) )
local sUnzip = util.Decompress( sZip )
Check( "Decompress roundtrip",				sUnzip == sRaw, sUnzip and #sUnzip or "nil" )
Check( "Decompress maxSize guard -> nil",	util.Decompress( sZip, 4 ) == nil )
Check( "Decompress garbage -> nil",			util.Decompress( "not-lzma-data-at-all" ) == nil )
Check( "Decompress('') -> nil",				util.Decompress( "" ) == nil )

-- ---------------------------------------------------------------------------
-- 2. SteamIDs (64-bit math lives in C++; Lua doubles lose bits up here)
-- ---------------------------------------------------------------------------
local sID64 = util.SteamIDTo64( "STEAM_0:1:7099" )
Check( "SteamIDTo64 garry's id",			sID64 == "76561197960279927", sID64 )
if ( type( sID64 ) == "string" ) then
	Check( "SteamIDFrom64 roundtrip",			util.SteamIDFrom64( sID64 ) == "STEAM_0:1:7099", util.SteamIDFrom64( sID64 ) )
else
	Check( "SteamIDFrom64 roundtrip", false, "no id64" )
end
Check( "SteamIDTo64 invalid -> nil",		util.SteamIDTo64( "not-a-steamid" ) == nil )

-- ---------------------------------------------------------------------------
-- 3. geometry
-- ---------------------------------------------------------------------------
local v = util.AimVector( Angle( 0, 0, 0 ), 90, 320, 240, 640, 480 )
Check( "AimVector center == forward",		v ~= nil and Near( v.x, 1, 0.001 ) and Near( v.y, 0, 0.001 ) and Near( v.z, 0, 0.001 ),
	v and ( v.x .. "," .. v.y .. "," .. v.z ) or "nil" )

local nDist, vClosest, nAlong = util.DistanceToLine( Vector( 0, 0, 0 ), Vector( 10, 0, 0 ), Vector( 5, 3, 0 ) )
Check( "DistanceToLine distance",	Near( nDist, 3, 0.001 ), nDist )
Check( "DistanceToLine closest",	vClosest ~= nil and Near( vClosest.x, 5, 0.001 ) and Near( vClosest.y, 0, 0.001 ) )
Check( "DistanceToLine along",		Near( nAlong, 5, 0.01 ), nAlong )

local vHit, nPlaneDist = util.IntersectRayWithPlane( Vector( 0, 0, 10 ), Vector( 0, 0, -1 ), Vector( 0, 0, 0 ), Vector( 0, 0, 1 ) )
Check( "IntersectRayWithPlane hit",		vHit ~= nil and Near( vHit.z, 0, 0.001 ), vHit and vHit.z or "nil" )
Check( "IntersectRayWithPlane dist",	Near( nPlaneDist, 10, 0.001 ), nPlaneDist )
Check( "IntersectRayWithPlane parallel -> nil",
	util.IntersectRayWithPlane( Vector( 0, 0, 1 ), Vector( 1, 0, 0 ), Vector( 0, 0, 0 ), Vector( 0, 0, 1 ) ) == nil )

local vHit, vNormal, nFrac = util.IntersectRayWithOBB( Vector( 0, 0, -50 ), Vector( 0, 0, 100 ),
	Vector( 0, 0, 0 ), Angle( 0, 0, 0 ), Vector( -10, -10, -10 ), Vector( 10, 10, 10 ) )
Check( "IntersectRayWithOBB hit pos",	vHit ~= nil and Near( vHit.z, -10, 0.001 ), vHit and vHit.z or "nil" )
Check( "IntersectRayWithOBB fraction",	Near( nFrac, 0.4, 0.001 ), nFrac )
Check( "IntersectRayWithOBB normal",	vNormal ~= nil and Near( vNormal.z, -1, 0.001 ) )
Check( "IntersectRayWithOBB miss -> nil",
	util.IntersectRayWithOBB( Vector( 100, 0, -50 ), Vector( 0, 0, 100 ),
		Vector( 0, 0, 0 ), Angle( 0, 0, 0 ), Vector( -10, -10, -10 ), Vector( 10, 10, 10 ) ) == nil )

local nT1, nT2 = util.IntersectRayWithSphere( Vector( 0, 0, -5 ), Vector( 0, 0, 10 ), Vector( 0, 0, 0 ), 1 )
Check( "IntersectRayWithSphere fractions",	Near( nT1, 0.4, 0.001 ) and Near( nT2, 0.6, 0.001 ),
	nT1 and ( nT1 .. "," .. nT2 ) or "nil" )

local vHit, nFrac = util.IntersectRayWithTriangle( Vector( 0, 0, -5 ), Vector( 0, 0, 5 ),
	Vector( -1, -1, 0 ), Vector( 1, -1, 0 ), Vector( 0, 1, 0 ), false )
Check( "IntersectRayWithTriangle hit",	vHit ~= nil and Near( nFrac, 0.5, 0.001 ), nFrac )

Check( "IsBoxIntersectingBox overlap",	util.IsBoxIntersectingBox( Vector( 0, 0, 0 ), Vector( 2, 2, 2 ), Vector( 1, 1, 1 ), Vector( 3, 3, 3 ) ) == true )
Check( "IsBoxIntersectingBox apart",	util.IsBoxIntersectingBox( Vector( 0, 0, 0 ), Vector( 1, 1, 1 ), Vector( 2, 2, 2 ), Vector( 3, 3, 3 ) ) == false )
Check( "IsBoxIntersectingSphere in",	util.IsBoxIntersectingSphere( Vector( -1, -1, -1 ), Vector( 1, 1, 1 ), Vector( 0, 0, 0 ), 0.5 ) == true )
Check( "IsBoxIntersectingSphere out",	util.IsBoxIntersectingSphere( Vector( -1, -1, -1 ), Vector( 1, 1, 1 ), Vector( 5, 0, 0 ), 0.5 ) == false )
Check( "IsSphereIntersectingSphere",	util.IsSphereIntersectingSphere( Vector( 0, 0, 0 ), 1, Vector( 1.5, 0, 0 ), 1 ) == true )
Check( "IsSphereIntersectingSphere out", util.IsSphereIntersectingSphere( Vector( 0, 0, 0 ), 1, Vector( 3, 0, 0 ), 1 ) == false )
Check( "IsOBBIntersectingOBB same",		util.IsOBBIntersectingOBB( Vector( 0, 0, 0 ), Angle( 0, 0, 0 ), Vector( -1, -1, -1 ), Vector( 1, 1, 1 ),
	Vector( 0, 0, 0 ), Angle( 0, 0, 0 ), Vector( -1, -1, -1 ), Vector( 1, 1, 1 ) ) == true )
Check( "IsOBBIntersectingOBB apart",	util.IsOBBIntersectingOBB( Vector( 0, 0, 0 ), Angle( 0, 0, 0 ), Vector( -1, -1, -1 ), Vector( 1, 1, 1 ),
	Vector( 10, 0, 0 ), Angle( 0, 0, 0 ), Vector( -1, -1, -1 ), Vector( 1, 1, 1 ) ) == false )
Check( "IsOBBIntersectingOBB rotated",	util.IsOBBIntersectingOBB( Vector( 0, 0, 0 ), Angle( 0, 0, 45 ), Vector( -1, -1, -1 ), Vector( 1, 1, 1 ),
	Vector( 1.4, 1.4, 0 ), Angle( 0, 0, 0 ), Vector( -1, -1, -1 ), Vector( 1, 1, 1 ) ) == true )
Check( "IsPointInCone inside",			util.IsPointInCone( Vector( 1, 0, 0 ), Vector( 0, 0, 0 ), Vector( 1, 0, 0 ), 0.5, 10 ) == true )
Check( "IsPointInCone outside",			util.IsPointInCone( Vector( 5, 5, 0 ), Vector( 0, 0, 0 ), Vector( 1, 0, 0 ), 0.5, 10 ) == false )
Check( "IsRayIntersectingRay cross",	util.IsRayIntersectingRay( Vector( 0, -1, 0 ), Vector( 0, 1, 0 ), Vector( -1, 0, 0 ), Vector( 1, 0, 0 ) ) == true )
Check( "IsRayIntersectingRay apart",	util.IsRayIntersectingRay( Vector( 0, -1, 0 ), Vector( 0, 1, 0 ), Vector( 5, -1, 0 ), Vector( 5, 1, 0 ) ) == false )
Check( "IsSphereIntersectingCone in",	util.IsSphereIntersectingCone( Vector( 2, 0, 0 ), 0.5, Vector( 0, 0, 0 ), Vector( 1, 0, 0 ), 0.5, 0.866 ) == true )
Check( "IsSphereIntersectingCone out",	util.IsSphereIntersectingCone( Vector( 0, 10, 0 ), 0.5, Vector( 0, 0, 0 ), Vector( 1, 0, 0 ), 0.5, 0.866 ) == false )

-- ---------------------------------------------------------------------------
-- 4. SharedRandom
-- ---------------------------------------------------------------------------
local nR = util.SharedRandom( "hl2sb_probe", 5, 10 )
Check( "SharedRandom in range", type( nR ) == "number" and nR >= 5 and nR <= 10, nR )
Check( "SharedRandom deterministic", util.SharedRandom( "hl2sb_probe", 5, 10 ) == nR )

-- ---------------------------------------------------------------------------
-- 5. surface props
-- ---------------------------------------------------------------------------
local nConcrete = util.GetSurfaceIndex( "default" )
if ( nConcrete == nil ) then nConcrete = util.GetSurfaceIndex( "concrete" ) end
Check( "GetSurfaceIndex finds one",		type( nConcrete ) == "number" and nConcrete >= 0, tostring( nConcrete ) )
if ( nConcrete ~= nil and nConcrete >= 0 ) then
	Check( "GetSurfacePropName roundtrip", util.GetSurfacePropName( nConcrete ) ~= nil, util.GetSurfacePropName( nConcrete ) )
	local tSurf = util.GetSurfaceData( nConcrete )
	Check( "GetSurfaceData returns table", type( tSurf ) == "table", type( tSurf ) )
	if ( type( tSurf ) == "table" ) then
		Check( "GetSurfaceData has name",		tSurf.name ~= nil, tSurf.name )
		Check( "GetSurfaceData has friction",	tSurf.friction ~= nil, tSurf.friction )
		Check( "GetSurfaceData has sounds",		tSurf.impactHardSound ~= nil )
	end
end

-- ---------------------------------------------------------------------------
-- 6. model membership
-- ---------------------------------------------------------------------------
Check( "IsModelLoaded boolean",			type( util.IsModelLoaded( "models/error.mdl" ) ) == "boolean" )
Check( "IsValidModel rejects junk",		util.IsValidModel( "notamodel.txt" ) == false )
Check( "IsValidModel rejects anim frag", util.IsValidModel( "models/player/_anims/x.mdl" ) == false )
util.PrecacheModel( "models/error.mdl" )
Check( "IsValidModel accepts error.mdl", util.IsValidModel( "models/error.mdl" ) == true, util.IsValidModel( "models/error.mdl" ) )
Check( "IsValidProp boolean",			type( util.IsValidProp( "models/error.mdl" ) ) == "boolean" )
Check( "IsValidRagdoll boolean",		type( util.IsValidRagdoll( "models/error.mdl" ) ) == "boolean" )

-- GetModelInfo: pick any real model on disk
local tFiles = file.Find( "models/props/*.mdl", "GAME" )
local sModel = ( tFiles and tFiles[ 1 ] ) or "models/error.mdl"
local tInfo = util.GetModelInfo( sModel )
Check( "GetModelInfo returns table",	type( tInfo ) == "table", tostring( tInfo ) )
if ( type( tInfo ) == "table" ) then
	Check( "GetModelInfo SkinCount",	tInfo.SkinCount ~= nil )
	Check( "GetModelInfo BoneCount",	tInfo.BoneCount ~= nil )
	Check( "GetModelInfo KeyValues",	tInfo.KeyValues ~= nil )
end
Check( "GetModelInfo anim fragment -> nil", util.GetModelInfo( "models/foo_anims.mdl" ) == nil )

-- ---------------------------------------------------------------------------
-- 7. activity / anim event lookups
-- ---------------------------------------------------------------------------
local nAct = util.GetActivityIDByName( "ACT_IDLE" )
Check( "GetActivityIDByName ACT_IDLE",	type( nAct ) == "number" and nAct >= 0, tostring( nAct ) )
if ( type( nAct ) == "number" and nAct >= 0 ) then
	Check( "GetActivityNameByID roundtrip", util.GetActivityNameByID( nAct ) == "ACT_IDLE", util.GetActivityNameByID( nAct ) )
end
local nEv = util.GetAnimEventIDByName( "AE_EMPTY" )
Check( "GetAnimEventIDByName sane",		nEv == nil or type( nEv ) == "number", tostring( nEv ) )

-- ---------------------------------------------------------------------------
-- 8. damage / trace / misc
-- ---------------------------------------------------------------------------
Check( "FilterText passthrough",	util.FilterText( "hello world" ) == "hello world" )
Check( "TraceEntityHull exists",	type( util.TraceEntityHull ) == "function" )
Check( "BlastDamageInfo exists",	type( util.BlastDamageInfo ) == "function" )

-- ---------------------------------------------------------------------------
-- 9. Lua-side members
-- ---------------------------------------------------------------------------
local sKV = util.TableToKeyValues( { a = 1, b = { c = "x" } }, "Probe" )
if ( type( sKV ) == "string" ) then
	Check( "TableToKeyValues emits root",	sKV:find( '"Probe"' ) ~= nil, sKV:sub( 1, 40 ) )
	Check( "TableToKeyValues emits body",	sKV:find( '"b"' ) ~= nil )
else
	Check( "TableToKeyValues emits root", false, tostring( sKV ) )
end

local sKVText = '"Outer"\n{\n"soli" "a"\n"soli" "b"\n"inner"\n{\n"n" "5"\n}\n}\n'
local tPres = util.KeyValuesToTablePreserveOrder( sKVText )
Check( "KVTblPreserveOrder root array",	type( tPres ) == "table" and #tPres == 3, tPres and #tPres or "nil" )
if ( type( tPres ) == "table" ) then
	Check( "KVTblPreserveOrder repeated keys", tPres[ 1 ].Key == "soli" and tPres[ 2 ].Key == "soli" )
	Check( "KVTblPreserveOrder values",	tPres[ 1 ].Value == "a" and tPres[ 2 ].Value == "b" )
	if ( type( tPres[ 3 ] ) == "table" and type( tPres[ 3 ].Value ) == "table" ) then
		Check( "KVTblPreserveOrder nested",	tPres[ 3 ].Key == "inner" and tPres[ 3 ].Value[ 1 ].Value == 5,
			tostring( tPres[ 3 ].Value[ 1 ] and tPres[ 3 ].Value[ 1 ].Value ) )
	end
end
local tCase = util.KeyValuesToTablePreserveOrder( '"R"\n{\n"MixedCase" "1"\n}\n', false, true )
Check( "KVTblPreserveOrder preserveCase", type( tCase ) == "table" and tCase[ 1 ] ~= nil and tCase[ 1 ].Key == "MixedCase" )

Check( "GetUserGroups returns table",	type( util.GetUserGroups() ) == "table" )

local nID = util.AddNetworkString( "hl2sb_probe_net" )
Check( "AddNetworkString returns id",	type( nID ) == "number" and nID > 0, tostring( nID ) )
Check( "AddNetworkString idempotent",	util.AddNetworkString( "hl2sb_probe_net" ) == nID )
Check( "NetworkStringToID roundtrip",	util.NetworkStringToID( "hl2sb_probe_net" ) == nID )
Check( "NetworkStringToID unknown -> 0", util.NetworkStringToID( "never_registered_xyz" ) == 0 )
Check( "NetworkIDToString roundtrip",	util.NetworkIDToString( nID ) == "hl2sb_probe_net" )
Check( "NetworkIDToString unknown -> nil", util.NetworkIDToString( 99999 ) == nil )

local nCycle = util.TimerCycle()
Check( "TimerCycle positive",			type( nCycle ) == "number" and nCycle >= 0, tostring( nCycle ) )

-- ---------------------------------------------------------------------------
-- 10. client-only members
-- ---------------------------------------------------------------------------
if ( CLIENT ) then
	local tSun = util.GetSunInfo()
	Check( "GetSunInfo table or none",	tSun == nil or type( tSun ) == "table" )
	if ( type( tSun ) == "table" ) then
		Check( "GetSunInfo direction",	tSun.direction ~= nil )
		Check( "GetSunInfo enabled",	type( tSun.enabled ) == "boolean" )
	end
	Check( "IsSkyboxVisibleFromPoint",	type( util.IsSkyboxVisibleFromPoint( Vector( 0, 0, 0 ) ) ) == "boolean" )
	Check( "IsPlayerSpeaking",			type( util.IsPlayerSpeaking( 1 ) ) == "boolean" )
end

print( string.format( "==================== util probe done: %d passed, %d failed ====================",
	nPassed, nFailed ) )
if nFailed > 0 then
	print( "!! FAILURES ABOVE -- engine util library deviates from the wiki contracts" )
end
