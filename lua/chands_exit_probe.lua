-- chands_exit_probe.lua - discriminate the post-vehicle-exit arms kill
local ply = LocalPlayer()
if ( not IsValid( ply ) ) then print( "[exitprobe] no local player" ) return end
local wep   = ply:GetActiveWeapon()
local vm    = ply.GetViewModel and ply:GetViewModel( 0 ) or nil
local hands = ply.GetHands and ply:GetHands() or nil
local EF_BONEMERGE = 8

print( "[exitprobe] InVehicle=" .. tostring( ply.InVehicle and ply:InVehicle() or "?" ) )
print( "[exitprobe] wep=" .. tostring( wep ) .. " scripted=" ..
	tostring( IsValid( wep ) and wep:IsScripted() or "?" ) .. " model=" ..
	tostring( IsValid( wep ) and wep:GetModel() or "?" ) )
print( "[exitprobe] vm=" .. tostring( vm ) .. " model=" ..
	tostring( IsValid( vm ) and vm:GetModel() or "?" ) .. " parent=" ..
	tostring( IsValid( vm ) and vm:GetParent() or "?" ) )
print( "[exitprobe] hands=" .. tostring( hands ) .. " idx=" ..
	tostring( IsValid( hands ) and hands:EntIndex() or "?" ) .. " cls=" ..
	tostring( IsValid( hands ) and hands:GetClassname() or "?" ) .. " grp=" ..
	tostring( IsValid( hands ) and hands.GetRenderGroup and hands:GetRenderGroup() or "?" ) )
print( "[exitprobe] hands parent=" ..
	tostring( IsValid( hands ) and hands:GetParent() or "?" ) .. " bonemerge=" ..
	tostring( IsValid( hands ) and hands.IsEffectActive and hands:IsEffectActive( EF_BONEMERGE ) or "?" )
	.. " handspos=" .. tostring( IsValid( hands ) and hands:GetPos() or "?" ) )

-- 1s counters: which layer dies?
local c = { PreDrawViewModel = 0, PostDrawViewModel = 0, ViewModelDrawn = 0,
	PreDrawPlayerHands = 0, PostDrawPlayerHands = 0 }
for k, _ in pairs( c ) do hook.Add( k, "exitprobe_" .. k, function() c[ k ] = c[ k ] + 1 end ) end
timer.Simple( 1, function()
	for k, v in pairs( c ) do print( string.format( "[exitprobe] %s=%d", k, v ) ) end
	for k, _ in pairs( c ) do hook.Remove( k, "exitprobe_" .. k ) end
end )

-- FIX TEST: run `ply:DrawViewModel( true )` afterwards once — if the arms come back,
-- the sticky g_HL2SB_HideViewModel global was the killer (lc_baseplayer.cpp:66,
-- consumed at view.cpp:1246-1248). r_drawviewmodel must also read 1.