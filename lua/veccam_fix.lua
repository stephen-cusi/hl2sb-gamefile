-- HL2SB (sbrust): hot fix for the seat camera -- driver skipped in the trace
-- filter (cl_init.lua carries the same fix; this patch works without a map
-- reload).  Run client-side once per session:
--   lua_dofile_cl veccam_fix.lua
if ( not CLIENT or not GAMEMODE or not GAMEMODE.CalcVehicleView ) then
	print( "[veccamfix] run in-game, client realm" )
	return
end

GAMEMODE.CalcVehicleView = function( self, Vehicle, ply, view )
	if ( Vehicle.GetThirdPersonMode == nil || ply:GetViewEntity() != ply ) then
		return
	end
	if ( !Vehicle:GetThirdPersonMode() ) then return view end

	local mn, mx = Vehicle:GetRenderBounds()
	local radius = ( mn - mx ):Length()
	local radius = radius + radius * Vehicle:GetCameraDistance()

	local TargetOrigin = view.origin + ( view.angles:Forward() * -radius )
	local WallOffset = 4

	local tr = util.TraceHull( {
		start = view.origin,
		endpos = TargetOrigin,
		filter = function( e )
			if ( e == ply ) then return false end
			local c = e:GetClass()
			return !c:StartsWith( "prop_physics" ) && !c:StartsWith( "prop_dynamic" ) && !c:StartsWith( "phys_bone_follower" ) && !c:StartsWith( "prop_ragdoll" ) && !e:IsVehicle() && !c:StartsWith( "gmod_" )
		end,
		mins = Vector( -WallOffset, -WallOffset, -WallOffset ),
		maxs = Vector( WallOffset, WallOffset, WallOffset ),
	} )

	view.origin = tr.HitPos
	view.drawviewer = true

	if ( tr.Hit && !tr.StartSolid ) then
		view.origin = view.origin + tr.HitNormal * WallOffset
	end

	return view
end
print( "[veccamfix] seat camera filter patched - CTRL again to see third person" )
