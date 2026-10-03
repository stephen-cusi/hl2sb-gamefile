-- vehicle_eyeprobe.lua -- HL2SB (2026-10-04) diagnostic, run with: lua_dofile_cl vehicle_eyeprobe.lua
-- Sits in the jeep and dumps the actual camera / attachment / head-bone numbers
-- so the head-clip geometry is measured instead of guessed.  Prints one frame
-- immediately (if seated) and then once a second for 10 seconds.

local function dump( tag )
	local ply = LocalPlayer()
	if ( not IsValid( ply ) ) then print( "[eyeprobe] no local player" ) return end

	local veh = ply:GetVehicle()
	print( "==== [eyeprobe " .. tag .. "] ====" )
	print( "InVehicle      : " .. tostring( ply:InVehicle() ) )
	if ( not IsValid( veh ) ) then print( "no vehicle" ) return end

	print( "vehicle class  : " .. veh:GetClass() )
	print( "EyePos         : " .. tostring( EyePos() ) )
	print( "EyeAngles      : " .. tostring( EyeAngles() ) )
	print( "ply origin     : " .. tostring( ply:GetPos() ) )
	print( "ply angles     : " .. tostring( ply:GetAngles() ) )

	local seq = ply:GetSequence()
	print( "ply sequence   : " .. seq .. " (" .. tostring( ply:GetSequenceName( seq ) ) .. ")" )

	-- vehicle driver-eye attachment (what the native camera sits on)
	local iVehEye = veh:LookupAttachment( "vehicle_driver_eyes" )
	local vFirst, vSecond = veh:GetAttachment( iVehEye )
	local vPos = ( type( vFirst ) == "table" and vFirst.Pos ) or vFirst
	local vAng = ( type( vFirst ) == "table" and vFirst.Ang ) or vSecond
	print( "veh driver_eyes: " .. tostring( vPos ) .. " ang " .. tostring( vAng ) )

	-- the rider model's own eyes attachment (what FPB snaps X/Y to)
	local iEyes = ply:LookupAttachment( "eyes" )
	if ( iEyes and iEyes > 0 ) then
		local pFirst, pSecond = ply:GetAttachment( iEyes )
		local pPos = ( type( pFirst ) == "table" and pFirst.Pos ) or pFirst
		local pAng = ( type( pFirst ) == "table" and pFirst.Ang ) or pSecond
		print( "ply eyes att   : " .. tostring( pPos ) .. " ang " .. tostring( pAng ) )
	else
		print( "ply eyes att   : NONE" )
	end

	-- head bone world position
	local h = ply:LookupBone( "ValveBiped.Bip01_Head1" )
	if ( h and h >= 0 ) then
		local hpos = ply:GetBonePosition( h )
		print( "head bone      : " .. tostring( hpos ) )
	else
		print( "head bone      : NONE" )
	end

	local dv = Vector( 0, 0, 0 )
	if ( vPos ) then dv = EyePos() - vPos end
	print( "EyePos-vehEye  : " .. tostring( dv ) )
end

dump( "instant" )

-- Per-frame EyePos sampling: 90 consecutive frames.  A stable camera prints
-- the same vector; a flapping gate alternates between two positions; a
-- mid-frame bone fight shows small oscillation every frame.
local nFrames = 0
local vPrev = EyePos()
hook.Add( "Think", "vehicle_eyeprobe_frames", function()
	if ( nFrames >= 90 ) then
		hook.Remove( "Think", "vehicle_eyeprobe_frames" )
		print( "[eyeprobe] per-frame sampling done" )
		return
	end
	nFrames = nFrames + 1
	local v = EyePos()
	local d = v - vPrev
	print( string.format( "[eyeprobe f%02d] eye %s  delta (%.2f %.2f %.2f) len %.3f",
		nFrames, tostring( v ), d.x, d.y, d.z, d:Length() ) )
	vPrev = v
end )

print( "[eyeprobe] per-frame sampling running for 90 frames -- sit still in the jeep" )
