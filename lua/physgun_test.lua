-- HL2SB physgun audit test (2026-09-22) -- SERVER realm: lua_dofile physgun_test.lua
-- Grab/freeze/R behaviour still needs a live player: see the checklist at the bottom.

local ok, err = pcall( function()
	local ply = Entity( 1 )

	-- 1) binding existence
	local function chk( name, fn ) print( "[pgun]", name, type( fn ) ) end
	local props = ents.Create( "prop_physics" )
	props:SetModel( "models/props_junk/wood_crate001a.mdl" )
	props:SetPos( ply:GetPos() + ply:GetForward() * 120 + Vector( 0, 0, 48 ) )
	props:Spawn()
	props:Activate()

	local phys = props:GetPhysicsObject()
	chk( "PhysObj:UpdateShadow", phys.UpdateShadow )
	chk( "PhysObj:ComputeShadowControl", phys.ComputeShadowControl )
	chk( "PhysObj:GetMassCenter", phys.GetMassCenter )
	chk( "Entity:GetPhysicsObjectCount", props.GetPhysicsObjectCount )
	chk( "Entity:GetPhysicsObjectNum", props.GetPhysicsObjectNum )
	chk( "Entity:MakePhysicsObjectAShadow", props.MakePhysicsObjectAShadow )
	chk( "Player:AddFrozenPhysicsObject", ply.AddFrozenPhysicsObject )
	chk( "Player:PhysgunUnfreeze", ply.PhysgunUnfreeze )
	chk( "Player:UnfreezePhysicsObjects", ply.UnfreezePhysicsObjects )

	print( "[pgun] count:", props:GetPhysicsObjectCount(), "num0 nil?:", props:GetPhysicsObjectNum( 0 ) == nil )
	print( "[pgun] masscenter:", phys:GetMassCenter() )

	-- 2) freeze-list round trip (no weapon needed)
	phys:EnableMotion( false )
	ply:AddFrozenPhysicsObject( props, phys )
	local n = ply:UnfreezePhysicsObjects()
	print( "[pgun] unfreeze-all returned:", n, "(expect >= 1)", "moveable now:", phys:IsMoveable() )

	-- 3) ComputeShadowControl: drive the crate toward a point 128u up
	local vStart = props:GetPos()
	local vTarget = vStart + Vector( 0, 0, 128 )
	local tEnd = CurTime() + 1.0
	local hUpdate
	hUpdate = hook.add( "Think", "pgun_shadowtest", function()
		if not IsValid( props ) or not IsValid( phys ) then hook.remove( "Think", "pgun_shadowtest" ) return end
		phys:Wake()
		phys:ComputeShadowControl( {
			secondstoarrive = 0.5,
			pos = vTarget,
			angle = props:GetAngles(),
			maxangular = 1000,
			maxangulardamp = 10000,
			maxspeed = 10000,
			maxspeeddamp = 1000,
			dampfactor = 0.8,
			teleportdistance = 100,
			delta = 0.015
		} )
		if CurTime() >= tEnd then
			hook.remove( "Think", "pgun_shadowtest" )
			print( "[pgun] shadow-control rise:", math.floor( ( props:GetPos() - vStart ):Length() ), "units (expect > 32)" )
			props:Remove()
		end
	end )

	-- 4) hook registrations the weapon will fire (watch console while playing)
	hook.add( "PhysgunPickup", "pgun_test", function( p, e ) print( "[pgun] PhysgunPickup", p, e ) end )
	hook.add( "OnPhysgunPickup", "pgun_test", function( p, e ) print( "[pgun] OnPhysgunPickup", p, e ) end )
	hook.add( "PhysgunDrop", "pgun_test", function( p, e ) print( "[pgun] PhysgunDrop", p, e ) end )
	hook.add( "OnPhysgunFreeze", "pgun_test", function( w, ph, e, p ) print( "[pgun] OnPhysgunFreeze", w, e, p ) end )
	hook.add( "OnPhysgunReload", "pgun_test", function( w, p ) print( "[pgun] OnPhysgunReload", w, p ) end )
	hook.add( "GetPreferredCarryAngles", "pgun_test", function( e, p ) return nil end )
	print( "[pgun] hooks registered - now in game: grab / RMB-freeze / R / double-R with the physgun" )

	print( "[pgun] ALL OK" )
end )
if not ok then print( "[pgun] FAILED:", err ) end
