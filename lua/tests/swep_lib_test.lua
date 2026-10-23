--[[ swep_lib_test.lua: 本轮 SWEP 绑定/派发修复的合同
     跑法：server 控制台 lua_dofile swep_lib_test.lua；client 控制台 lua_dofile_cl swep_lib_test.lua ]]--

local nTests, nFailed = 0, 0
local function Check( bCond, sName )
	nTests = nTests + 1
	if ( !bCond ) then
		nFailed = nFailed + 1
		print( "[swep_lib_test] FAIL: " .. tostring( sName ) )
	end
end

-- ---- class registration（双端） --------------------------------------------
local stored = weapons.GetStored and weapons.GetStored( "weapon_base" ) or nil
Check( type( stored ) == "table", "weapons.GetStored(weapon_base)" )
if ( stored ) then
	Check( type( stored.CallOnClient ) == "function", "SWEP:CallOnClient exists" )
	Check( type( stored.ShootBullet ) == "function", "SWEP:ShootBullet" )
	Check( type( stored.GetHoldType ) == "function", "SWEP:GetHoldType" )
	Check( type( stored.TakePrimaryAmmo ) == "function", "SWEP:TakePrimaryAmmo" )
	Check( stored.Primary ~= nil and stored.Secondary ~= nil, "Primary/Secondary tables" )
end

-- ---- live instance（server 才能造实体） ------------------------------------
if ( SERVER and ents and ents.Create ) then
	local wep = ents.Create( "weapon_base" )
	Check( IsValid( wep ), "ents.Create(weapon_base)" )

	if ( IsValid( wep ) ) then
		wep:Spawn()

		-- DeploySpeed：绑定 + 缺省 1.0 + 往返
		Check( type( wep.GetDeploySpeed ) == "function", "GetDeploySpeed binding" )
		Check( type( wep.SetDeploySpeed ) == "function", "SetDeploySpeed binding" )
		local d0 = wep:GetDeploySpeed()
		Check( type( d0 ) == "number" and math.abs( d0 - 1.0 ) < 0.001, "DeploySpeed defaults to 1.0, got " .. tostring( d0 ) )
		wep:SetDeploySpeed( 2.5 )
		local d1 = wep:GetDeploySpeed()
		Check( math.abs( d1 - 2.5 ) < 0.001, "DeploySpeed roundtrip, got " .. tostring( d1 ) )

		-- ActivityOverride：旧实现把 true cast 成指针 0x1，翻译命中即 AV
		local okAct, translated, required = pcall( wep.ActivityOverride, wep, ACT_VM_IDLE, true )
		Check( okAct, "ActivityOverride(act, true) did not crash" )
		Check( okAct and type( translated ) == "number", "ActivityOverride returns an activity" )
		Check( okAct and type( required ) == "boolean", "ActivityOverride returns the required flag" )

		-- 无主武器 GetOwner 应答 nil（NPC/玩家都不该被硬 cast）
		Check( wep:GetOwner() == nil, "GetOwner is nil without an owner" )

		-- HasAmmo 应是 Source 语义（不用弹药的武器也回 true），不是被 HasAnyAmmo 顶掉
		Check( wep:HasAmmo() == true, "HasAmmo true for a weapon with no ammo types" )

		-- tostring 对齐 GMod "Weapon [i][s]"
		local s = tostring( wep )
		Check( type( s ) == "string" and string.find( s, "Weapon [", 1, true ) != nil,
			"tostring is Weapon [i][s], got: " .. tostring( s ) )

		-- WeaponSound 的 soundtime 现在从槽 3 读：传了第三参不应报错
		local okSnd = pcall( wep.WeaponSound, wep, 1, 0.0 )
		Check( okSnd, "WeaponSound(category, 0.0) accepts the third argument" )

		wep:Remove()
	end
end

if ( CLIENT ) then
	Check( type( weapons ) == "table", "weapons table on client" )
	Check( type( net ) == "table" and type( net.Receive ) == "function", "net.Receive available (CallOnClient receive path)" )
end

print( string.format( "[swep_lib_test] %d checks, %d failed", nTests, nFailed ) )
if ( nFailed == 0 ) then
	print( "[swep_lib_test] PASSED" )
end
