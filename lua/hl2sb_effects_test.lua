-----------------------------------------------------------------------------
-- HL2SB effects 库测试脚本（客户端）
--
-- 控制台加载:  lua_dofile_cl hl2sb_effects_test.lua
-- 反复可跑:    每次执行都在准星指向处重放一轮特效
--
-- 覆盖 2026-09 审计补上的五件事:
--   1. effects 库 C 半边 (Bubbles / BubbleTrail / BeamRingPoint)
--   2. effects.TracerSound Lua shim
--   3. CEffectData:GetMaterialIndex / SetMaterialIndex 别名
--   4. util.Effect 第 3 参 allowOverride=false (强制引擎回调)
--   5. Lua effect 名字压过引擎回调 (allowOverride 默认 true)
-----------------------------------------------------------------------------

local FAILS = 0

local function PASS( name )
	Msg( "[FXTEST] PASS  " .. name .. "\n" )
end

local function FAIL( name, err )
	FAILS = FAILS + 1
	Msg( "[FXTEST] FAIL  " .. name .. "  --  " .. tostring( err ) .. "\n" )
end

local function TEST( name, fn )
	local ok, err = pcall( fn )
	if ok then PASS( name ) else FAIL( name, err ) end
end

local ply = LocalPlayer()
if not IsValid( ply ) then
	Msg( "[FXTEST] 还没有本地玩家 -- 进图后再跑\n" )
	return
end

local eye = ply:EyePos()
local tr = ply:GetEyeTrace()
local hit
if tr and tr.HitPos then
	hit = tr.HitPos
else
	hit = eye + ply:GetAimVector() * 300
end
local normal = ( tr and tr.HitNormal ) or Vector( 0, 0, 1 )

-- 保证测试点在玩家前方、离地面近，肉眼可看
if eye:DistToSqr( hit ) < 100 * 100 then
	hit = eye + ply:GetAimVector() * 300
end

Msg( "[FXTEST] origin=" .. tostring( hit ) .. "  正在看: 请盯准星指向的地面/墙面\n" )

-- 1. effects 库形状: GMod 的 Register / Create / GetList
TEST( "effects.Register/Create/GetList", function()
	assert( type( effects ) == "table", "no effects table" )
	assert( type( effects.Register ) == "function", "effects.Register missing" )
	assert( type( effects.Create ) == "function", "effects.Create missing" )
	assert( type( effects.GetList ) == "function", "effects.GetList missing" )
	assert( type( effects.Bubbles ) == "function", "effects.Bubbles missing (C half)" )
	assert( type( effects.BubbleTrail ) == "function", "effects.BubbleTrail missing (C half)" )
	assert( type( effects.BeamRingPoint ) == "function", "effects.BeamRingPoint missing (C half)" )
	assert( type( effects.TracerSound ) == "function", "effects.TracerSound missing" )

	local probe = {
		Init = function() end,
		Think = function() return false end,
		Render = function() end,
	}
	effects.Register( probe, "hl2sb_fxtest_probe" )
	local inst = effects.Create( "hl2sb_fxtest_probe" )
	assert( type( inst ) == "table" and type( inst.Init ) == "function",
		"effects.Create did not return a template copy" )
end )

-- 2. effects.Bubbles -- 准星指向处冒一箱气泡
TEST( "effects.Bubbles (world)", function()
	effects.Bubbles( hit + Vector( -40, -40, 0 ), hit + Vector( 40, 40, 120 ), 120, 200, 20 )
end )

-- 3. effects.BubbleTrail -- 眼睛到命中点一条气泡航迹
TEST( "effects.BubbleTrail (world)", function()
	effects.BubbleTrail( eye, hit, 60, 120, 20 )
end )

-- 4. effects.BeamRingPoint -- 默认材质 + extra 表全套
TEST( "effects.BeamRingPoint (world, default material)", function()
	effects.BeamRingPoint( hit + Vector( 0, 0, 8 ), 1.0, 4, 256, 8, 0, Color( 255, 255, 225, 255 ) )
end )

TEST( "effects.BeamRingPoint (world, extra table)", function()
	effects.BeamRingPoint( hit + Vector( 0, 0, 8 ), 1.4, 8, 512, 24, 0,
		Color( 120, 255, 120, 80 ),
		{ speed = 0, spread = 0, delay = 0, framerate = 2, material = "sprites/lgtning.vmt" } )
end )

-- 5. effects.TracerSound -- 应能听到(贴近时)子弹嗖嗖声
TEST( "effects.TracerSound", function()
	effects.TracerSound( eye, hit, 1 )
end )

-- 6. CEffectData MaterialIndex 别名 (GMod 拼法) + 旧名仍在
TEST( "CEffectData GetMaterialIndex/SetMaterialIndex aliases", function()
	local d = EffectData()
	d:SetMaterialIndex( 12345 )
	assert( d:GetMaterialIndex() == 12345,
		"GetMaterialIndex roundtrip gave " .. tostring( d:GetMaterialIndex() ) )
	d:SetMaterial( 777 )
	assert( d:GetMaterial() == 777, "legacy GetMaterial/SetMaterial broken" )
end )

-- 7. util.Effect( ..., false ) -- allowOverride=false 强制引擎回调
TEST( "util.Effect GlassImpact (engine, allowOverride=false)", function()
	local d = EffectData()
	d:SetOrigin( hit )
	d:SetNormal( normal )
	util.Effect( "GlassImpact", d, false )
end )

-- 8. Lua effect 压过引擎同名回调 (默认 allowOverride=true)
--    注意: 会覆盖本会话的引擎 watersplash, 重进地图恢复
TEST( "Lua effect overrides engine callback (watersplash)", function()
	effects.Register( {
		Init = function( self, data ) self.HitPos = data:GetOrigin() self.Born = SysTime() end,
		Think = function( self )
			-- 存活 1.5 秒再退役: 验证 Think 契约的同时, 让 Render 有机会画出来
			return SysTime() - self.Born < 1.5
		end,
		Render = function( self )
			-- 画一个明显的青色十字光束, 证明走的是 Lua 半边
			local p = self.HitPos
			local c = Color( 0, 255, 255, 255 )
			local function cross( size )
				render.DrawBeam( p + Vector( -size, 0, 0 ), p + Vector( size, 0, 0 ), 4, 0, 1, c )
				render.DrawBeam( p + Vector( 0, -size, 0 ), p + Vector( 0, size, 0 ), 4, 0, 1, c )
				render.DrawBeam( p + Vector( 0, 0, -size ), p + Vector( 0, 0, size ), 4, 0, 1, c )
			end
			render.SetMaterial( Material( "sprites/lgtning.vmt" ) )
			cross( 24 )
		end,
	}, "watersplash" )

	local d = EffectData()
	d:SetOrigin( hit )
	util.Effect( "watersplash", d )
end )

Msg( "[FXTEST] 完成: " .. ( FAILS == 0 and "全部 PASS" or ( FAILS .. " 项 FAIL" ) )
	.. " -- 世界里应看到气泡/闪电环/玻璃渣/青色球, 控制台应有 [HL2SB] Lua effect 'watersplash' created\n" )
