--[[ matrix_lib_test.lua: Entity matrix 家族绑定的合同（GMod wiki 收录的 7 个方法）
     跑法：client 控制台 lua_dofile_cl matrix_lib_test.lua
           server 控制台 lua_dofile    matrix_lib_test.lua
     覆盖：
       - Entity:GetWorldTransformMatrix / Entity:GetParentWorldTransformMatrix（双端）
       - Entity:GetBoneMatrix / Entity:CopyBoneMatrix（双端）
       - Entity:SetBoneMatrix（双端；server 侧按 reference 是空桩，只断言可调用）
       - Entity:EnableMatrix / Entity:DisableMatrix（仅 client —— reference 引擎
         只在客户端注册这两个名字，server 侧应当为 nil）
     EnableMatrix 的真实缩放/旋转效果只能肉眼验证，见文件尾的检查步骤。--]]

local nTests, nFailed = 0, 0
local function Check( bCond, sName )
	nTests = nTests + 1
	if ( !bCond ) then
		nFailed = nFailed + 1
		print( "[matrix_lib_test] FAIL: " .. tostring( sName ) )
	end
end

local function SafeCall( fn )
	local ok, a = pcall( fn )
	return ok, a
end

-- 挑一个确定存在的实体：client 用本地玩家，server 用第一个玩家
local ent = nil
if ( CLIENT ) then
	local ply = LocalPlayer and LocalPlayer()
	if ( IsValid( ply ) ) then ent = ply end
else
	local t = player.GetAll and player.GetAll() or {}
	if ( #t > 0 ) then ent = t[1] end
end

Check( IsValid( ent ), "找得到一个测试实体" )

if ( IsValid( ent ) ) then

	-- ---- GetWorldTransformMatrix（双端） ---------------------------------
	local ok, wm = SafeCall( function() return ent:GetWorldTransformMatrix() end )
	Check( ok and wm ~= nil, "Entity:GetWorldTransformMatrix 可调用" )
	if ( ok and wm ) then
		local okTr, tr = SafeCall( function() return wm:GetTranslation() end )
		Check( okTr and tr ~= nil, "返回值是 VMatrix（GetTranslation 可用）" )
		if ( okTr and tr ) then
			local d = ( tr - ent:GetPos() ):Length()
			Check( d < 0.5, "平移分量等于实体位置 (delta=" .. tostring( d ) .. ")" )
		end
	end

	-- ---- GetParentWorldTransformMatrix（双端） ---------------------------
	local okP, pm = SafeCall( function() return ent:GetParentWorldTransformMatrix() end )
	Check( okP and pm ~= nil, "Entity:GetParentWorldTransformMatrix 可调用" )
	if ( okP and pm and pm.IsIdentity and !ent:GetMoveParent() ) then
		Check( pm:IsIdentity() == true, "无 move parent 时返回单位矩阵" )
	end

	-- ---- GetBoneMatrix（双端） -------------------------------------------
	local okB, bm = SafeCall( function() return ent:GetBoneMatrix( 0 ) end )
	Check( okB, "Entity:GetBoneMatrix(0) 可调用" )
	Check( okB and bm ~= nil, "GetBoneMatrix(0) 返回矩阵" )

	-- ---- CopyBoneMatrix（双端） ------------------------------------------
	if ( okB and bm ) then
		local copy = Matrix()
		local okC, errC = SafeCall( function() return ent:CopyBoneMatrix( 0, copy ) end )
		Check( okC, "Entity:CopyBoneMatrix 可调用" .. ( okC and "" or ( " (" .. tostring( errC ) .. ")" ) ) )
		local okD, d = SafeCall( function()
			return ( bm:GetTranslation() - copy:GetTranslation() ):Length()
		end )
		Check( okD and d < 0.01, "CopyBoneMatrix 与 GetBoneMatrix 结果一致" )

		local okNeg = SafeCall( function() return ent:CopyBoneMatrix( -1, copy ) end )
		Check( okNeg, "CopyBoneMatrix 越界骨骼静默返回" )
	end

	-- ---- SetBoneMatrix ----------------------------------------------------
	-- client：把当前骨骼矩阵原样写回（视觉无变化）；server：reference 空桩
	if ( CLIENT ) then
		if ( okB and bm ) then
			local okW = SafeCall( function() return ent:SetBoneMatrix( 0, bm ) end )
			Check( okW, "client Entity:SetBoneMatrix 可调用" )
		end
	else
		local okW = SafeCall( function() return ent:SetBoneMatrix( 0, Matrix() ) end )
		Check( okW, "server Entity:SetBoneMatrix 是可调用的空桩" )
	end

	-- ---- EnableMatrix / DisableMatrix（仅 client） ------------------------
	local okHasC, hasClient = SafeCall( function() return ent.EnableMatrix end )
	if ( CLIENT ) then
		Check( okHasC and isfunction( hasClient ), "client Entity:EnableMatrix 存在" )
		local okHasD, hasDis = SafeCall( function() return ent.DisableMatrix end )
		Check( okHasD and isfunction( hasDis ), "client Entity:DisableMatrix 存在" )

		if ( isfunction( hasClient ) ) then
			local m = Matrix()
			m:Scale( Vector( 1, 1, 1 ) )
			local o1, e1 = SafeCall( function() return ent:EnableMatrix( "RenderMultiply", m ) end )
			Check( o1, "EnableMatrix(\"RenderMultiply\", matrix) 可调用" .. ( o1 and "" or ( " (" .. tostring( e1 ) .. ")" ) ) )
			local o2 = SafeCall( function() return ent:EnableMatrix( "NoSuchType", m ) end )
			Check( o2, "EnableMatrix 未知类型静默忽略" )
			local o3 = SafeCall( function() return ent:EnableMatrix( "RenderMultiply", 42 ) end )
			Check( o3, "EnableMatrix 非矩阵参数不报错（reference 清除语义）" )
			local o4, e4 = SafeCall( function() return ent:DisableMatrix( "RenderMultiply" ) end )
			Check( o4, "DisableMatrix(\"RenderMultiply\") 可调用" .. ( o4 and "" or ( " (" .. tostring( e4 ) .. ")" ) ) )
		end
	else
		-- reference 引擎只在客户端注册这两个名字
		Check( okHasC and hasClient == nil, "server 侧没有 EnableMatrix（与 reference 一致）" )
	end
end

print( string.format( "[matrix_lib_test] %d tests, %d failed", nTests, nFailed ) )
if ( nFailed > 0 ) then
	print( "[matrix_lib_test] RESULT: FAIL" )
else
	print( "[matrix_lib_test] RESULT: PASS" )
end

-- ---------------------------------------------------------------------------
-- 肉眼检查（脚本断言覆盖不到的部分）：
--   client 控制台 lua_dofile_cl awpdragon_visual_check.lua 之外的手工步骤：
--   1) 进图拿 AWP（awpdragon），第三人称/看地上掉落的枪：世界模型的
--      WElements 面板模型（w_clout_awp）应当照常绘制，控制台不再刷
--      "attempt to call a nil value (method 'EnableMatrix')"；
--   2) 眼前摆一个 props 实体，控制台跑：
--        local e = Entity( <entindex> ) ; local m = Matrix() ; m:Scale( Vector(1,1,3) )
--        e:EnableMatrix( "RenderMultiply", m )
--      模型应当纵向拉高 3 倍（绕自身原点），再
--        e:DisableMatrix( "RenderMultiply" )
--      恢复原尺寸。
-- ---------------------------------------------------------------------------
