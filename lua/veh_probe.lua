-- HL2SB: in-game probe for the GMod Vehicle library
-- (https://wiki.facepunch.com/gmod/Vehicle).
--
-- Console:  lua_dofile_cl veh_probe.lua
-- NOTE: lua_dofile_cl prepends "lua/" itself, so passing "lua/veh_probe.lua" makes it
-- look for lua/lua/veh_probe.lua and fail with "No such file or directory".
--
-- Running it while seated probes your vehicle; running it on foot falls back to a
-- nearby vehicle entity so the library can be tested without driving.

local ply = LocalPlayer and LocalPlayer() or nil
if not ply then
	print( "[veh_probe] no LocalPlayer" )
	return
end

-- First: which player->vehicle accessors does this build actually have?
print( "[veh_probe] LocalPlayer=" .. tostring( ply ) ..
	   " GetVehicle=" .. tostring( ply.GetVehicle ) ..
	   " GetVehicleEntity=" .. tostring( ply.GetVehicleEntity ) ..
	   " InVehicle=" .. tostring( ply.InVehicle ) )

local veh = nil
local how = "none"

if ply.GetVehicle then
	veh = ply:GetVehicle()
	if veh then how = "LocalPlayer():GetVehicle()" end
end

if not veh and ply.GetVehicleEntity then
	veh = ply:GetVehicleEntity()
	if veh then how = "LocalPlayer():GetVehicleEntity()" end
end

-- On foot: borrow a vehicle entity so the library itself can still be probed.
if not veh and ents and ents.FindByClass then
	local classes = { "prop_vehicle_jeep", "prop_vehicle_airboat", "prop_vehicle_driveable" }
	for _, class in ipairs( classes ) do
		local found = ents.FindByClass( class )
		if found and found[ 1 ] then
			veh = found[ 1 ]
			how = "ents.FindByClass( " .. class .. " )[1]"
			break
		end
	end
end

print( "[veh_probe] veh=" .. tostring( veh ) .. "  (via " .. how .. ")" )
if not veh then
	print( "[veh_probe] no vehicle found: sit in one, or spawn one, then re-run" )
	return
end

-- GMod wiki: vehicle objects answer both Entity and Vehicle methods.
local ok, err = pcall( function()
	print( "[veh_probe] IsVehicle=" .. tostring( veh:IsVehicle() ) ..
		   " IsValidVehicle=" .. tostring( veh:IsValidVehicle() ) ..
		   " class=" .. tostring( veh:GetVehicleClass() ) )
	print( "[veh_probe] speed=" .. tostring( veh:GetSpeed() ) ..
		   " rpm=" .. tostring( veh:GetRPM() ) ..
		   " throttle=" .. tostring( veh:GetThrottle() ) ..
		   " hlSpeed=" .. tostring( veh:GetHLSpeed() ) )
	print( "[veh_probe] wheels=" .. tostring( veh:GetWheelCount() ) ..
		   " driver=" .. tostring( veh:GetDriver() ) ..
		   " maxSpeed=" .. tostring( veh:GetMaxSpeed() ) ..
		   " steering=" .. tostring( veh:GetSteering() ) )
	print( "[veh_probe] boost=" .. tostring( veh:HasBoost() ) ..
		   "/" .. tostring( veh:IsBoosting() ) ..
		   " engine=" .. tostring( veh:IsEngineEnabled() ) ..
		   "/" .. tostring( veh:IsEngineStarted() ) )
	print( "[veh_probe] thirdPerson=" .. tostring( veh:GetThirdPersonMode() ) ..
		   " camDist=" .. tostring( veh:GetCameraDistance() ) )
end )

if not ok then
	print( "[veh_probe] FAILED inside Vehicle methods: " .. tostring( err ) )
	return
end

-- The two calls the GMod wiki documents for the vehicle camera; they drive the convars
-- the engine camera (ClientModeShared::OverrideView) reads every frame.
veh:SetThirdPersonMode( true )
veh:SetCameraDistance( 480 )

local cvar = GetConVar( "hl2sb_veh_thirdperson" )
local cvarDist = GetConVar( "hl2sb_veh_thirdperson_dist" )
print( "[veh_probe] SetThirdPersonMode(true) + SetCameraDistance(480) -> hl2sb_veh_thirdperson=" ..
	   tostring( cvar and cvar:GetBool() ) .. " hl2sb_veh_thirdperson_dist=" ..
	   tostring( cvarDist and cvarDist:GetFloat() ) )
