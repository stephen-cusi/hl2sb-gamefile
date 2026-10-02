-- hitnumbers_lib_test.lua -- HL2SB (2026-10-03)
-- Probe for the hitnumbers (damage indicator) binding round:
--   Entity:GetViewEntity            (shared, the render-hook killer)
--   Entity:PrintMessage             (client realm)
--   cam.IgnoreZ                     (real depth-range implementation)
--   file.CreateDir                  (GMod spelling)
--   HUD_PRINT_* globals
-- plus every other API the addon consumes, so one run shows the whole chain.
-- Run: lua_dofile hitnumbers_lib_test.lua (server) / lua_dofile_cl (client)

local nTests, nFailed = 0, 0
local function CHECK(cond, name)
	nTests = nTests + 1
	if ( cond ) then
		print( "[PASS] " .. name )
	else
		nFailed = nFailed + 1
		print( "[FAIL] " .. name )
	end
end

CHECK( type( hook ) == "table" and isfunction( hook.Add ), "hook library" )
CHECK( isfunction( CreateConVar ), "CreateConVar global" )
CHECK( type( cvars ) == "table" and isfunction( cvars.AddChangeCallback ), "cvars.AddChangeCallback" )
CHECK( isfunction( GetConVarNumber ) and isfunction( GetConVarString ), "GetConVarNumber/String" )
CHECK( isfunction( RunConsoleCommand ), "RunConsoleCommand" )
CHECK( isfunction( util.AddNetworkString ) or CLIENT, "util.AddNetworkString (server)" )
CHECK( isfunction( util.JSONToTable ) and isfunction( util.TableToJSON ), "util JSON pair" )
CHECK( isfunction( util.TraceHull ) or CLIENT, "util.TraceHull (server)" )
CHECK( isfunction( math.Clamp ) and isfunction( math.Round ) and isfunction( math.Rand ), "math Clamp/Round/Rand" )
CHECK( isfunction( string.StartWith ) or isfunction( string.StartsWith ), "string.StartWith" )
CHECK( type( file ) == "table" and isfunction( file.CreateDir ), "file.CreateDir bound" )
CHECK( isfunction( MsgC ) and isfunction( MsgN ), "MsgC / MsgN" )

-- The damage-type / mask / collision enums the server hook reads.
CHECK( DMG_CLUB == 128 and DMG_SLASH == 4, "DMG_CLUB / DMG_SLASH" )
CHECK( DMG_BURN ~= nil and DMG_SLOWBURN ~= nil and DMG_PLASMA ~= nil, "DMG burn family" )
CHECK( DMG_BLAST ~= nil and DMG_BLAST_SURFACE ~= nil, "DMG blast family" )
CHECK( DMG_ACID ~= nil and DMG_POISON ~= nil and DMG_RADIATION ~= nil and DMG_NERVEGAS ~= nil, "DMG acid family" )
CHECK( DMG_DISSOLVE ~= nil and DMG_ENERGYBEAM ~= nil and DMG_SHOCK ~= nil, "DMG energy family" )
CHECK( COLLISION_GROUP_DEBRIS ~= nil, "COLLISION_GROUP_DEBRIS" )
CHECK( MASK_SHOT_HULL ~= nil, "MASK_SHOT_HULL" )
CHECK( HUD_PRINTTALK == 3 and HUD_PRINTCONSOLE == 2, "HUD_PRINT_* globals" )

-- The global-var sync pair the settings ride on.
if ( SERVER ) then
	SetGlobalFloat( "HDN_TEST", 0.75 )
	SetGlobalBool( "HDN_TEST_B", true )
	CHECK( true, "SetGlobalFloat/Bool (server)" )
else
	local f = GetGlobalFloat( "HDN_TEST", 0 )
	local b = GetGlobalBool( "HDN_TEST_B", false )
	-- The server probe only ran if it shares the process (listen server);
	-- either way both calls must return the default type without error.
	CHECK( isnumber( f ) and isbool( b ), "GetGlobalFloat/Bool callable (client)" )
	if ( f == 0.75 ) then
		print( "[info] global sync arrived: HDN_TEST=" .. f .. " b=" .. tostring( b ) )
	end
end

-- file.CreateDir round trip in DATA.
file.CreateDir( "hitnumbers_test" )
CHECK( file.Exists( "hitnumbers_test", "DATA" ), "file.CreateDir makes the dir" )
if ( file.Exists( "hitnumbers_test/dummy.txt", "DATA" ) ) then
	file.Delete( "hitnumbers_test/dummy.txt" )
end

-- Per-realm surface.
if ( SERVER ) then

	local tAll = player.GetAll()
	local ply = tAll[ 1 ]
	if ( ply ~= nil ) then
		CHECK( isfunction( ply.GetViewEntity ), "Entity:GetViewEntity bound (server)" )
		local viewEnt = ply:GetViewEntity()
		-- type() reports the metatable name for userdata in this fork; the
		-- isentity() helper does not recognise engine entities.
		CHECK( viewEnt == nil or type( viewEnt ) == "Entity", "Entity:GetViewEntity returns entity/nil (server)" )
		CHECK( isfunction( ply.GetCollisionGroup ), "Entity:GetCollisionGroup" )
		CHECK( isfunction( ply.GetShootPos ) and isfunction( ply.GetAimVector ), "GetShootPos / GetAimVector" )
		CHECK( isfunction( ply.Health ) and isfunction( ply.GetMaxHealth ), "Health / GetMaxHealth" )
		CHECK( isfunction( ply.IsNPC ), "Entity:IsNPC" )

		local npc = ents.FindByClass( "npc_*" )[ 1 ]
		local anyEnt = npc or ply
		CHECK( isfunction( anyEnt.LocalToWorld ) and isfunction( anyEnt.OBBCenter ), "LocalToWorld / OBBCenter" )
		CHECK( isfunction( anyEnt.IsPlayer ) and isfunction( anyEnt.IsWorld ), "IsPlayer / IsWorld" )
	end

	-- The two damage hooks this fork dispatches from TakeDamage; registering
	-- must not error, and the registered flag must be visible.
	hook.Add( "EntityTakeDamage", "hdn_test_probe", function( ent, dmg ) end )
	hook.Add( "PostEntityTakeDamage", "hdn_test_probe", function( ent, dmg, took ) end )
	CHECK( hook.GetTable()[ "EntityTakeDamage" ] ~= nil, "EntityTakeDamage registerable" )
	CHECK( hook.GetTable()[ "PostEntityTakeDamage" ] ~= nil, "PostEntityTakeDamage registerable" )

	-- dmginfo metatype: the shared CTakeDamageInfo table must be reachable
	-- through a fake dispatch (hook.Call keeps the gamemode fallback path).
	local okDmg = pcall( hook.Call, "PostEntityTakeDamage", GAMEMODE, ply, nil, true )
	CHECK( okDmg or ply == nil, "PostEntityTakeDamage hook.Call survives nil dmginfo" )
	hook.Remove( "EntityTakeDamage", "hdn_test_probe" )
	hook.Remove( "PostEntityTakeDamage", "hdn_test_probe" )

else

	local ply = LocalPlayer()
	if ( ply ~= nil and IsValid( ply ) ) then
		CHECK( isfunction( ply.GetViewEntity ), "Entity:GetViewEntity bound (client)" )
		local viewEnt = ply:GetViewEntity()
		CHECK( viewEnt == nil or type( viewEnt ) == "Entity", "Entity:GetViewEntity returns entity/nil (client)" )
		CHECK( isfunction( ply.EyeAngles ), "Entity:EyeAngles" )
		CHECK( isfunction( ply.PrintMessage ), "Entity:PrintMessage bound (client)" )
	end

	local ang = Angle( 15, 90, 0 )
	CHECK( isfunction( ang.RotateAroundAxis ), "Angle:RotateAroundAxis" )
	CHECK( isfunction( ang.Forward ) and isfunction( ang.Right ), "Angle:Forward / Right" )

	-- The exact font/table/text surface the addon's draw loop uses.
	CHECK( type( surface ) == "table" and isfunction( surface.CreateFont ), "surface.CreateFont" )
	surface.CreateFont( "font_HDN_TEST", {
		font = "coolvetica", size = 50, weight = 800, antialias = false,
		underline = false, italic = false, strikeout = false, symbol = false,
		rotary = false, shadow = false, additive = false, outline = true,
		blursize = 0, scanlines = 0,
	} )
	surface.SetFont( "font_HDN_TEST" )
	local w, h = surface.GetTextSize( "-123" )
	CHECK( isnumber( w ) and isnumber( h ) and w > 0 and h > 0, "surface.SetFont+GetTextSize pair (" .. w .. "x" .. h .. ")" )
	CHECK( isfunction( surface.SetTextColor ) and isfunction( surface.SetTextPos ) and isfunction( surface.DrawText ), "surface text trio (GMod spelling)" )

	CHECK( type( cam ) == "table" and isfunction( cam.Start3D2D ) and isfunction( cam.End3D2D ), "cam.Start3D2D / End3D2D" )
	CHECK( isfunction( cam.IgnoreZ ), "cam.IgnoreZ bound" )

	CHECK( type( net ) == "table" and isfunction( net.Receive ), "net.Receive (client)" )

	-- One-shot 3D2D visual: draws "-123" in front of the local player's eyes
	-- for three seconds inside the real translucent render pass, exactly the
	-- way hdn_drawInds does it.  Visible number = the whole draw stack works.
	hook.Add( "PostDrawTranslucentRenderables", "hdn_test_oneshot", function()
		local p = LocalPlayer()
		if ( p == nil or not IsValid( p ) ) then return end

		local t = CurTime() - ( HDN_TEST_T0 or CurTime() )
		HDN_TEST_T0 = HDN_TEST_T0 or CurTime()
		if ( t > 3 ) then
			hook.Remove( "PostDrawTranslucentRenderables", "hdn_test_oneshot" )
			print( "[info] 3D2D one-shot finished (3s)" )
			return
		end

		local pos = p:EyePos() + p:EyeAngles():Forward() * 80
		local ang2 = p:EyeAngles()
		ang2:RotateAroundAxis( ang2:Forward(), 90 )
		ang2:RotateAroundAxis( ang2:Right(), 90 )
		ang2 = Angle( 0, ang2.y, ang2.r )

		cam.Start3D2D( pos, ang2, 0.3 )
			surface.SetFont( "font_HDN_TEST" )
			surface.SetTextColor( 255, 230, 210, 255 )
			surface.SetTextPos( -w / 2, -h / 2 )
			surface.DrawText( "-123" )
		cam.End3D2D()
	end )
	print( "[info] 3D2D one-shot armed: look straight ahead, a -123 should float there for 3s" )

end

print( string.format( "[hitnumbers_lib_test] %d checks, %d failed", nTests, nFailed ) )
if ( nFailed == 0 ) then
	print( "[hitnumbers_lib_test] PASSED" )
end
