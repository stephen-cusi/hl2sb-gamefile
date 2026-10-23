-- pphud_lib_test.lua -- HL2SB (2026-10-02)
-- Probe for the tarkov_hud / GMod-postprocess binding round:
--   Player:Armor / GetArmor / SetArmor / GetMaxArmor / SetMaxArmor
--   Player:IsSprinting
--   game.GetAmmoName
--   DrawColorModify / DrawMotionBlur / DrawToyTown (lua/postprocess)
--   render.GetMoBlurTex0 / render.GetScreenEffectTexture() no-arg
--   GM:PostProcessPermitted
-- Run: lua_dofile pphud_lib_test.lua (server) / lua_dofile_cl pphud_lib_test.lua (client)

local function CHECK(cond, name)
	if ( cond ) then
		print( "[PASS] " .. name )
	else
		print( "[FAIL] " .. name )
	end
end

if ( SERVER ) then

	CHECK( player.GetAll ~= nil, "player.GetAll exists" )

	local ply = player.GetAll()[ 1 ]
	if ( ply ~= nil ) then
		CHECK( isfunction( ply.Armor ), "Player:Armor bound" )
		CHECK( isfunction( ply.GetArmor ), "Player:GetArmor bound" )
		CHECK( isfunction( ply.SetArmor ), "Player:SetArmor bound" )
		CHECK( isfunction( ply.GetMaxArmor ), "Player:GetMaxArmor bound" )
		CHECK( isfunction( ply.SetMaxArmor ), "Player:SetMaxArmor bound" )
		CHECK( isfunction( ply.IsSprinting ), "Player:IsSprinting bound" )

		local before = ply:Armor()
		ply:SetArmor( 25 )
		CHECK( ply:Armor() == 25, "SetArmor(25) roundtrip (got " .. ply:Armor() .. ")" )
		ply:SetArmor( before )
		CHECK( ply:GetMaxArmor() == 100, "GetMaxArmor default 100" )
		CHECK( ply:IsSprinting() == false or ply:IsSprinting() == true, "IsSprinting returns boolean" )
	end

	CHECK( isfunction( game.GetAmmoName ), "game.GetAmmoName bound" )
	local sName = game.GetAmmoName( 1 )
	CHECK( sName == nil or isstring( sName ), "GetAmmoName(1) string or nil (GMod contract)" )
	CHECK( game.GetAmmoName( -1 ) == nil, "GetAmmoName(-1) nil" )
	CHECK( game.GetAmmoName( 9999 ) == nil, "GetAmmoName(9999) nil" )

	-- The issue #40 fix: numeric ammo GiveAmmo must resolve a name and return
	-- given > 0 with headroom.  Pure return-value check -- the HL2SB_AMMO
	-- popup itself needs a connected client.
	if ( ply ~= nil ) then
		local n = ply:GiveAmmo( 1, 2, true )
		CHECK( isnumber( n ), "GiveAmmo(amount, numericID, hide) returns given" )
	end

end

if ( CLIENT ) then

	CHECK( isfunction( DrawColorModify ), "DrawColorModify global (lua/postprocess/color_modify.lua)" )
	CHECK( isfunction( DrawMotionBlur ), "DrawMotionBlur global (lua/postprocess/motion_blur.lua)" )
	CHECK( isfunction( DrawToyTown ), "DrawToyTown global (lua/postprocess/toytown.lua)" )

	CHECK( isfunction( render.GetMoBlurTex0 ), "render.GetMoBlurTex0 bound" )
	local tex = render.GetMoBlurTex0()
	CHECK( tex ~= nil, "GetMoBlurTex0 returns a texture" )

	CHECK( isfunction( render.GetScreenEffectTexture ), "render.GetScreenEffectTexture bound" )
	CHECK( render.GetScreenEffectTexture() ~= nil, "GetScreenEffectTexture() no-arg works (GMod optional index)" )

	CHECK( isfunction( render.SupportsPixelShaders_2_0 ), "render.SupportsPixelShaders_2_0 shim" )
	CHECK( render.SupportsPixelShaders_2_0() == true, "SupportsPixelShaders_2_0() true" )

	local gm = GAMEMODE or _G._GAMEMODE
	CHECK( gm ~= nil and isfunction( gm.PostProcessPermitted ), "GM:PostProcessPermitted wired" )
	if ( gm ~= nil and isfunction( gm.PostProcessPermitted ) ) then
		CHECK( gm:PostProcessPermitted( "color mod" ) == true, "PostProcessPermitted('color mod') true" )
	end

	-- Player methods on the client meta (tarkov_hud calls these every frame).
	local ply = LocalPlayer()
	if ( IsValid( ply ) ) then
		CHECK( isfunction( ply.Armor ), "Player:Armor bound (client)" )
		CHECK( isfunction( ply.GetMaxArmor ), "Player:GetMaxArmor bound (client)" )
		CHECK( isfunction( ply.IsSprinting ), "Player:IsSprinting bound (client)" )
		local nArmor = ply:Armor()
		CHECK( isnumber( nArmor ), "client Armor() returns number (networked m_ArmorValue), got " .. tostring( nArmor ) )
	end

	-- Smoke: the three postprocess entry points survive a direct call.
	DrawColorModify( { [ "$pp_colour_brightness" ] = 0, [ "$pp_colour_contrast" ] = 1, [ "$pp_colour_colour" ] = 1 } )
	DrawToyTown( 1, 10 )
	DrawMotionBlur( 0.01, 0.5, 0.01 )
	print( "[PASS] postprocess entry points callable without error" )

end

print( "[pphud_lib_test] done (" .. ( SERVER and "server" or "client" ) .. ")" )
