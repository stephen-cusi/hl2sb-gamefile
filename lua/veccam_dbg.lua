-- HL2SB (sbrust): veccam_dbg v2 -- prints every intermediate of the seat camera
--   hl2sb_veh_thirdperson_debug 1
--   lua_dofile_cl veccam_dbg.lua
local Original = GAMEMODE and GAMEMODE.CalcVehicleView or nil
if ( not CLIENT or Original == nil ) then
	print( "[veccamdbg] run in-game, client realm" )
	return
end

local flNext = 0
GAMEMODE.CalcVehicleView = function( self, Vehicle, ply, view )
	local ok, out = pcall( Original, self, Vehicle, ply, view )

	local dbg = GetConVar( "hl2sb_veh_thirdperson_debug" )
	if ( dbg and dbg:GetBool() and CurTime() >= flNext and IsValid( Vehicle ) ) then
		flNext = CurTime() + 1
		local third = Vehicle.GetThirdPersonMode and Vehicle:GetThirdPersonMode()
		local dist = Vehicle.GetCameraDistance and Vehicle:GetCameraDistance()
		local mn, mx = Vehicle:GetRenderBounds()
		local mns, mxs = tostring( mn ), tostring( mx )
		local radius = -1
		if ( mn and mx ) then
			radius = ( mn - mx ):Length()
		end
		local fwd = view.angles:Forward()
		print( string.format(
			"[veccamdbg2] third=%s dist=%.3f mn=%s mx=%s radius=%.2f eye=(%.0f %.0f %.0f) fwd=(%.2f %.2f %.2f) cam=(%.0f %.0f %.0f) ent=%s",
			tostring( third ), dist or -99, mns:sub( 1, 40 ), mxs:sub( 1, 40 ),
			radius, view.origin.x, view.origin.y, view.origin.z,
			fwd.x, fwd.y, fwd.z,
			out and out.origin.x or -1, out and out.origin.y or -1, out and out.origin.z or -1,
			tostring( Vehicle ) ) )
	end

	if ( not ok ) then
		ErrorNoHalt( "[veccamdbg] raised: " .. tostring( out ) .. "\n" )
		return view
	end
	return out
end
print( "[veccamdbg2] installed" )
