-- veh_probe_gmod.lua -- seated-vehicle reference probe
--
-- Run in GMod (oracle) and in HL2SB (subject), seated in the SAME seat/car,
-- then diff the two output files.
--
--   GMod:   lua_openscript veh_probe_gmod.lua      (server)
--           lua_openscript_cl veh_probe_gmod.lua   (client)
--   HL2SB:  lua_dofile veh_probe_gmod.lua          (server)
--           lua_dofile_cl veh_probe_gmod.lua       (client)
--
-- Output: data/veh_probe_gmod_sv.txt / veh_probe_gmod_cl.txt
--
-- Answers: which sequence does a seated player actually run (sit_rollercoaster?
-- drive_jeep? plain idle?), does the model even HAVE those sequences, which
-- pose parameters move, and where the body sits relative to the seat.

local realm = SERVER and "SV" or "CL"

local lines = {}
local function p( fmt, ... )
	local s = string.format( tostring( fmt ), ... )
	table.insert( lines, s )
	MsgN( "[vehprobe] " .. s )
end

local ply
if SERVER then
	local all = player.GetAll()
	ply = all[ 1 ]
else
	ply = LocalPlayer()
end
if not IsValid( ply ) then
	MsgN( "[vehprobe] no player found (seat a vehicle, run from a listen server)" )
	return
end

p( "=== realm=%s map=%s time=%.1f", realm, game.GetMap and game.GetMap() or "?", CurTime() )
p( "player model   = %s", ply:GetModel() )

-- Player main sequence + cycle
local seqid = ply.GetSequence and ply:GetSequence() or -1
local seqname = "?"
if seqid and seqid >= 0 and ply.GetSequenceName then
	local ok, nm = pcall( function() return ply:GetSequenceName( seqid ) end )
	seqname = ok and tostring( nm ) or ( "ERR:" .. tostring( nm ) )
end
p( "player seq     = id %d  name %s  cycle %.3f  playback %.2f",
	seqid, seqname, ply.GetCycle and ply:GetCycle() or -1,
	ply.GetPlaybackRate and ply:GetPlaybackRate() or -1 )

-- Seat-sequence availability in the CURRENT player model
p( "--- LookupSequence (player model) ---" )
for _, name in ipairs( {
	"sit", "sit_rollercoaster", "sit_pistol", "sit_smg1", "sit_ar", "sit_rpg",
	"sit_shotgun", "sit_crossbow", "sit_melee", "sit_knife", "sit_crowbar",
	"sit_slam", "sit_passive", "sit_normal", "sit_fist", "sit_dualwield",
	"drive_jeep", "drive_airboat", "drive_pd", "modellike", "modellikeshot",
	"modellikemelee", "sit_357", "sit_physgun", "sit_toolgun", "sit_grenade" } ) do
	local id = ply.LookupSequence and ply:LookupSequence( name ) or -1
	if id and id >= 0 then p( "seq %-18s = %d", name, id ) end
end

-- Full sequence name dump (GetSequenceName answers "Unknown" past the end;
-- stop there -- calling further would print a "Bad sequence" warning per call).
p( "--- ALL sequences (id name) ---" )
if ply.GetSequenceName then
	local n = 0
	for i = 0, 1023 do
		local ok, nm = pcall( function() return ply:GetSequenceName( i ) end )
		if not ok or not nm or nm == "" or nm == "Unknown" then break end
		table.insert( lines, string.format( "S %3d %s", i, tostring( nm ) ) )
		n = n + 1
	end
	p( "sequence count = %d", n )
end

-- Pose parameters + current values
p( "--- pose parameters (name = value) ---" )
if ply.GetPoseParameterName then
	local np = 0
	for i = 0, 64 do
		local ok, nm = pcall( function() return ply:GetPoseParameterName( i ) end )
		if not ok or not nm or nm == "" or nm == "Unknown" then break end
		local val = "?"
		if ply.GetPoseParameter then
			local ok2, v = pcall( function() return ply:GetPoseParameter( i ) end )
			if ok2 then val = string.format( "%.3f", v ) end
		end
		if string.find( nm:lower(), "sit" ) or string.find( nm:lower(), "vehicle" )
			or string.find( nm:lower(), "vertical" ) or string.find( nm:lower(), "aim" )
			or string.find( nm:lower(), "move" ) or string.find( nm:lower(), "lean" ) then
			p( "pose %-24s = %s  <== interesting", nm, val )
		else
			p( "pose %-24s = %s", nm, val )
		end
		np = np + 1
	end
	p( "pose param count = %d", np )
end

-- Does a vehicle exist?
local veh = ply.GetVehicle and ply:GetVehicle() or NULL
if not IsValid( veh ) then veh = ply.GetParent and ply:GetParent() or NULL end
if not IsValid( veh ) then
	p( "player parent  = NONE (not seated?)" )
else
	p( "--- vehicle ---" )
	p( "vehicle class  = %s", veh:GetClass() )
	p( "vehicle model  = %s", veh:GetModel() )
	if veh.GetRenderBounds then
		local mn, mx = veh:GetRenderBounds()
		if mn and mx then
			p( "veh renderbounds mn=(%.1f %.1f %.1f) mx=(%.1f %.1f %.1f) diag=%.1f",
				mn.x, mn.y, mn.z, mx.x, mx.y, mx.z, ( mx - mn ):Length() )
		end
	end
	if veh.GetThirdPersonMode then
		p( "veh thirdPerson= %s   camDist= %s",
			tostring( veh:GetThirdPersonMode() ),
			veh.GetCameraDistance and tostring( veh:GetCameraDistance() ) or "?" )
	else
		p( "veh thirdPerson= (method absent)" )
	end
	-- seat attachments that a parent could sit on
	if veh.LookupAttachment then
		for _, at in ipairs( { "vehicle_seatbase", "vehicle_movein_vehicle",
		                       "vehicle_feet_passenger0", "vehicle_view" } ) do
			local idx = veh:LookupAttachment( at )
			if idx and idx > 0 then
				local ok, att = pcall( function() return veh:GetAttachment( idx ) end )
				local tp = veh:GetPos()
				if ok and att and att.Pos then
					p( "attach %-22s idx=%d relpos=(%.1f %.1f %.1f)", at, idx,
						att.Pos.x - tp.x, att.Pos.y - tp.y, att.Pos.z - tp.z )
				else
					p( "attach %-22s idx=%d (no transform)", at, idx )
				end
			else
				p( "attach %-22s absent", at )
			end
		end
	end
	if ply.GetParent then
		local pp, vp = ply:GetPos(), veh:GetPos()
		p( "player pos - vehicle pos = (%.1f %.1f %.1f)", pp.x - vp.x, pp.y - vp.y, pp.z - vp.z )
		p( "player has parent = %s (class %s)", tostring( IsValid( ply:GetParent() ) ),
			IsValid( ply:GetParent() ) and ply:GetParent():GetClass() or "-" )
		p( "player angles - vehicle angles = (%.1f %.1f %.1f)",
			ply:GetAngles().p - veh:GetAngles().p, ply:GetAngles().y - veh:GetAngles().y,
			ply:GetAngles().r - veh:GetAngles().r )
	end
end

if file and file.Write then
	file.Write( "veh_probe_gmod_" .. realm:lower() .. ".txt", table.concat( lines, "\n" ) )
	MsgN( "[vehprobe] written to data/veh_probe_gmod_" .. realm:lower() .. ".txt" )
end
