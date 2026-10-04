-- HL2SB (sbrust): veccam_dbg v3 -- replays the seat camera math next to the
-- real GM:CalcVehicleView and dumps the TraceHull verdict.
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
		local dist = Vehicle.GetCameraDistance and Vehicle:GetCameraDistance() or 0
		local mn, mx = Vehicle:GetRenderBounds()
		local radius = ( mn - mx ):Length() * ( 1 + dist )

		-- replay GMod's exact pull-back + trace
		local target = view.origin + ( view.angles:Forward() * -radius )
		local tr = util.TraceHull( {
			start = view.origin,
			endpos = target,
			filter = function( e )
				local c = e:GetClass()
				return !c:StartsWith( "prop_physics" ) && !c:StartsWith( "prop_dynamic" ) && !c:StartsWith( "phys_bone_follower" ) && !c:StartsWith( "prop_ragdoll" ) && !e:IsVehicle() && !c:StartsWith( "gmod_" )
			end,
			mins = Vector( -4, -4, -4 ),
			maxs = Vector( 4, 4, 4 ),
		} )
		print( string.format(
			"[veccam3] third=%s dist=%.3f radius=%.1f target=(%.0f %.0f %.0f) hit=%s frac=%.3f ss=%s hitent=%s(%s) hitpos=(%.0f %.0f %.0f) normal=(%.1f %.1f %.1f)",
			tostring( third ), dist, radius,
			target.x, target.y, target.z,
			tostring( tr.Hit ), tr.Fraction or tr.fraction or -1, tostring( tr.StartSolid ),
			tostring( tr.Entity ), ( tr.Entity and tr.Entity.GetClass and tr.Entity:GetClass() ) or "?",
			tr.HitPos.x, tr.HitPos.y, tr.HitPos.z,
			tr.HitNormal.x, tr.HitNormal.y, tr.HitNormal.z ) )
	end

	if ( not ok ) then
		ErrorNoHalt( "[veccamdbg] raised: " .. tostring( out ) .. "\n" )
		return view
	end
	return out
end
print( "[veccamdbg3] installed" )
