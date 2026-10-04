-- HL2SB (sbrust): steering pose chain probe -- client realm, while DRIVING:
--   lua_dofile_cl steer_probe.lua
-- Prints every 0.5s: the vehicle's own steering pose (server-simulated, networked)
-- vs the player's steering pose (what the arm bones blend with).  Turn the
-- steering left/right while it runs.
--   veh changes, ply follows  -> chain healthy, problem is the model/FPB side
--   veh changes, ply frozen   -> client GM:UpdateAnimation link is broken
--   both frozen               -> server->client pose network is broken
local ply = LocalPlayer()
if ( not IsValid( ply ) ) then print( "[steerprobe] no local player" ) return end
local veh = ply:GetVehicle()
if ( not IsValid( veh ) ) then print( "[steerprobe] not seated - drive a jeep/airboat first" ) return end

local vi = veh:LookupPoseParameter( "vehicle_steer" )
local pi = ply:LookupPoseParameter( "vehicle_steer" )
print( string.format( "[steerprobe] veh=%s(%d) ply=%s(%d) vehcls=%s", veh:GetClass(), vi, ply:GetModel(), pi, veh:GetClass() ) )
if ( vi < 0 ) then print( "[steerprobe] vehicle model has NO vehicle_steer pose" ) end
if ( pi < 0 ) then print( "[steerprobe] PLAYER model has NO vehicle_steer pose" ) end

timer.Create( "steerprobe", 0.5, 0, function()
	if ( not IsValid( ply ) or not IsValid( veh ) ) then timer.Remove( "steerprobe" ) print( "[steerprobe] end" ) return end
	local v = ( vi >= 0 ) and veh:GetPoseParameter( vi ) or -1
	local p = ( pi >= 0 ) and ply:GetPoseParameter( pi ) or -1
	local seq = ( ply.GetSequenceName and ply:GetSequence() ) and ply:GetSequenceName( ply:GetSequence() ) or "?"
	print( string.format( "[steerprobe] veh_steer=%.3f ply_steer=%.3f seq=%s cycle=%.2f", v, p, seq, ply:GetCycle() ) )
end )
