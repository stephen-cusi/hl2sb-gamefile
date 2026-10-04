-- HL2SB (sbrust): seat/camera chain probe -- run in BOTH realms while seated:
--   lua_dofile     seat_pose_probe.lua   (server)
--   lua_dofile_cl  seat_pose_probe.lua   (client)
-- Prints per vehicle: the table name (GMod's SetVehicleClass chain), the
-- Vehicles-list entry, the HandleAnimation resolution and the camera state --
-- so a mismatch between realms (server state right, client camera frozen) is
-- visible as one line of diff.
local realm = SERVER and "SV" or "CL"

local function vehicle_line( ent )
	local cls = ent.GetClass and ent:GetClass() or "?"
	local vclass = "?"
	if ( ent.GetVehicleClass ) then
		vclass = ent:GetVehicleClass()
	end
	local entry, animType = nil, "nil"
	if ( list and list.GetEntry ) then
		entry = list.GetEntry( "Vehicles", vclass )
		if ( entry and entry.Members and entry.Members.HandleAnimation ) then
			animType = type( entry.Members.HandleAnimation )
		end
	end
	local tp, dist = "?", "?"
	if ( ent.GetThirdPersonMode ) then
		tp = tostring( ent:GetThirdPersonMode() )
		dist = tostring( ent:GetCameraDistance() )
	end
	local rmn, rmxc, diag = "?", "?", "?"
	if ( ent.GetRenderBounds ) then
		local mn, mx = ent:GetRenderBounds()
		if ( mn and mx ) then
			rmxc = string.format( "%.0f", ( mx - mn ):Length() )
		end
	end
	return string.format( "[%s] veh ent=%s cls=%s vclass=%s entry=%s anim=%s third=%s dist=%s boundsdiag=%s",
		realm, tostring( ent ), cls, tostring( vclass ),
		tostring( entry ~= nil ), animType, tp, dist, tostring( rmxc ) )
end

local n = 0
for _, ent in ipairs( ents.GetAll() ) do
	-- IsVehicle is the engine predicate (drivable vehicles AND chairs, and it
	-- does not depend on the class-name string, which on the client can fall
	-- back to RTTI text for entities without a networked classname)
	if ( ent:IsVehicle() ) then
		print( vehicle_line( ent ) )
		n = n + 1
	end
end

if ( SERVER ) then
	-- the local driver's current pose (server view: what the anim state runs)
	for _, ply in ipairs( player.GetAll() ) do
		local veh = ply:GetVehicle()
		if ( IsValid( veh ) ) then
			local sid = ply:GetSequence()
			local sname = "?"
			if ( ply.GetSequenceName ) then
				sname = ply:GetSequenceName( sid )
			end
			print( string.format( "[SV] player %s in %s runs seq %d (%s) cycle %.2f",
				tostring( ply ), tostring( veh:GetClass() ), sid, sname, ply:GetCycle() ) )
		end
	end
else
	-- CLIENT camera-chain witnesses: which entity the camera math will run for,
	-- what the guard sees, and what the view currently is.
	local ply = LocalPlayer()
	if ( IsValid( ply ) ) then
		local veh = ply:GetVehicle()
		if ( IsValid( veh ) ) then
			print( vehicle_line( veh ) )
			local ve = ply:GetViewEntity()
			print( string.format( "[CL] viewentity=%s (==ply? %s)  InVehicle=%s",
				tostring( ve ), tostring( ve == ply ), tostring( ply:InVehicle() ) ) )
			local sid = ply:GetSequence()
			local sname = "?"
			if ( ply.GetSequenceName ) then
				sname = ply:GetSequenceName( sid )
			end
			print( string.format( "[CL] player seq %d (%s) cycle %.2f  cam=(%.0f %.0f %.0f) ang=(%.1f %.1f)",
				sid, sname, ply:GetCycle(), ply:GetPos().x, ply:GetPos().y, ply:GetPos().z,
				ply:EyeAngles().pitch, ply:EyeAngles().yaw ) )
		else
			print( "[CL] not seated (GetVehicle invalid)" )
		end
	end
end
print( string.format( "[%s] %d vehicle(s) scanned", realm, n ) )
