-- HL2SB (sbrust): vehicle third person camera contract -- state on the vehicle,
-- camera in the gamemode Lua, GMod's GM:VehicleMove semantics.  Both realms:
--   lua_dofile veh_cam_lib_test.lua      (server)
--   lua_dofile_cl veh_cam_lib_test.lua   (client)

local nTests, nFailed = 0, 0
local function Check( bCond, sName )
	nTests = nTests + 1
	if ( !bCond ) then
		nFailed = nFailed + 1
		print( "[veh_cam_lib_test] FAIL: " .. sName )
	end
end

-- The four wiki methods are engine bindings on the Vehicle class, not Lua shims.
local veh = nil
local ply = LocalPlayer and LocalPlayer() or nil
if ply and ply.GetVehicle then veh = ply:GetVehicle() end
if not veh and SERVER and ents and ents.FindByClass then
	-- driveables only: this fork's prisoner pod is NOT a CPropVehicleDriveable
	-- (physics prop + vehicle interface), so it has no Vehicle metatable here --
	-- an existing asymmetry, out of this test's contract.
	for _, class in ipairs( { "prop_vehicle_jeep", "prop_vehicle_airboat" } ) do
		local found = ents.FindByClass( class )
		if found and found[ 1 ] then veh = found[ 1 ] break end
	end
end

if veh then
	Check( type( veh.GetThirdPersonMode ) == "function", "GetThirdPersonMode bound" )
	Check( type( veh.SetThirdPersonMode ) == "function", "SetThirdPersonMode bound" )
	Check( type( veh.GetCameraDistance ) == "function", "GetCameraDistance bound" )
	Check( type( veh.SetCameraDistance ) == "function", "SetCameraDistance bound" )

	-- read-back is the same engine field, not a Lua mirror
	local bWasMode = veh:GetThirdPersonMode()
	Check( type( bWasMode ) == "boolean", "GetThirdPersonMode boolean" )
	Check( type( veh:GetCameraDistance() ) == "number", "GetCameraDistance number" )

	veh:SetThirdPersonMode( true )
	Check( veh:GetThirdPersonMode() == true, "SetThirdPersonMode round-trip on" )
	veh:SetCameraDistance( 2.5 )
	Check( math.abs( veh:GetCameraDistance() - 2.5 ) < 0.001, "SetCameraDistance round-trip" )
	veh:SetThirdPersonMode( false )
	Check( veh:GetThirdPersonMode() == false, "SetThirdPersonMode round-trip off" )
else
	print( "[veh_cam_lib_test] NOTE: no vehicle entity present, entity-level checks skipped" )
end

-- The camera is the gamemode Lua; the toggle/zoom is the server's.
if CLIENT then
	Check( type( GAMEMODE.CalcVehicleView ) == "function", "GM:CalcVehicleView defined" )
	Check( type( GAMEMODE.VehicleMove ) == "function", "GM:VehicleMove client stub" )
	Check( type( LocalPlayer().GetViewEntity ) == "function", "GetViewEntity bound" )
	Check( type( util.TraceHull ) == "function", "util.TraceHull bound" )
end
if SERVER then
	Check( type( GAMEMODE.VehicleMove ) == "function", "GM:VehicleMove server method (dormant port)" )
end

-- The old global-convar camera is gone.
Check( GetConVar( "hl2sb_veh_thirdperson" ) == nil, "hl2sb_veh_thirdperson removed" )
Check( GetConVar( "hl2sb_veh_thirdperson_dist" ) == nil, "hl2sb_veh_thirdperson_dist removed" )
Check( GetConVar( "hl2sb_veh_thirdperson_up" ) == nil, "hl2sb_veh_thirdperson_up removed" )

-- The debug switch stays where it lives (the client DLL owns it).
if CLIENT then
	Check( GetConVar( "hl2sb_veh_thirdperson_debug" ) != nil, "hl2sb_veh_thirdperson_debug kept" )
end

print( string.format( "[veh_cam_lib_test] %d checks, %d failed", nTests, nFailed ) )
if ( nFailed == 0 ) then
	print( "[veh_cam_lib_test] PASSED" )
end
