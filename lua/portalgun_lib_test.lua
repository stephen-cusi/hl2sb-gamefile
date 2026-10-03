--[[ portalgun_lib_test.lua: portalgun 插件缺口补齐的合同
     跑法：server 控制台 lua_dofile portalgun_lib_test.lua；client 控制台 lua_dofile_cl portalgun_lib_test.lua ]]--

local nTests, nFailed = 0, 0
local function Check( bCond, sName )
	nTests = nTests + 1
	if ( !bCond ) then
		nFailed = nFailed + 1
		print( "[portalgun_lib_test] FAIL: " .. tostring( sName ) )
	end
end

-- ---- math extensions（双端） ------------------------------------------------
Check( math.Round( -0.5 ) == 0, "math.Round(-0.5) == 0 (GMod half-up)" )
Check( math.Round( 2.5 ) == 3, "math.Round(2.5)" )
Check( math.Round( 1.234, 2 ) == 1.23, "math.Round(1.234, 2)" )
Check( math.Truncate( -2.7 ) == -2, "math.Truncate(-2.7)" )
Check( math.abs( math.atan2( 1, 1 ) - math.pi / 4 ) < 0.0001, "math.atan2(y, x)" )
Check( math.ApproachAngle( 350, 10, 5 ) == 355, "math.ApproachAngle walks the short way" )
Check( math.Approach( 0, 10, 3 ) == 3, "math.Approach still works" )

-- ---- umsg（双端） ------------------------------------------------------------
Check( type( umsg ) == "table", "umsg global exists" )
if ( type( umsg ) == "table" ) then
	for _, f in pairs( { "Start", "End", "Char", "Short", "Long", "Float", "Bool",
		"Entity", "Vector", "Angle", "String" } ) do
		Check( type( umsg[ f ] ) == "function", "umsg." .. f )
	end
end
Check( type( usermessage ) == "table" and type( usermessage.Hook ) == "function", "usermessage.Hook" )
Check( type( usermessage.IncomingMessage ) == "function", "usermessage.IncomingMessage" )

-- ---- Networked aliases（双端） ----------------------------------------------
local EM = FindMetaTable( "Entity" )
Check( EM.SetNetworkedInt == EM.SetNWInt, "SetNetworkedInt == SetNWInt" )
Check( EM.GetNetworkedBool == EM.GetNWBool, "GetNetworkedBool == GetNWBool" )
Check( EM.SetNetworkedEntity == EM.SetNWEntity, "SetNetworkedEntity == SetNWEntity" )

-- ---- brush/point 基类（server 扫描后） --------------------------------------
if ( SERVER and scripted_ents ) then
	local brushStore = scripted_ents.GetStored and scripted_ents.GetStored( "base_brush" )
	Check( brushStore != nil, "base_brush registered" )
	local filterStore = scripted_ents.GetStored and scripted_ents.GetStored( "base_filter" )
	Check( filterStore != nil, "base_filter registered" )

	-- 派生类不能再报 "non existant entity base_brush"
	local t, err = pcall( scripted_ents.Get, "trigger_portal_cleanser" )
	Check( t == true, "scripted_ents.Get(trigger_portal_cleanser) no error" )
	if ( t == false ) then print( "[portalgun_lib_test]   -> " .. tostring( err ) ) end
	local f, ferr = pcall( scripted_ents.Get, "func_noportal" )
	Check( f == true, "scripted_ents.Get(func_noportal) no error" )
	if ( f == false ) then print( "[portalgun_lib_test]   -> " .. tostring( ferr ) ) end

	Check( scripted_ents.IsBasedOn( "trigger_portal_cleanser", "base_entity" ),
		"cleanser derives from base_entity" )
	Check( type( scripted_ents.GetStored( "prop_portal" ) ) == "table", "prop_portal registered" )

	if ( scripted_ents.GetStored( "base_brush" ) ) then
		local baseT = scripted_ents.Get( "base_brush" )
		Check( type( baseT ) == "table" and type( baseT.StartTouch ) == "function",
			"base_brush has StartTouch stub" )
		Check( type( baseT.PassesTriggerFilters ) == "function", "base_brush PassesTriggerFilters" )
	end

	-- RecipientFilter short spellings (server)
	if ( RecipientFilter ) then
		local rf = RecipientFilter()
		Check( type( rf.AddPVS ) == "function", "RecipientFilter():AddPVS" )
		if ( rf.AddPVS != rf.AddRecipientsByPVS ) then
			print( "[portalgun_lib_test]   note: AddPVS is its own function (fine)" )
		end
	end
end

-- ---- server globals ----------------------------------------------------------
if ( SERVER ) then
	Check( type( AddOriginToPVS ) == "function", "AddOriginToPVS global" )
end

-- ---- client render/bone surface ----------------------------------------------
if ( CLIENT ) then
	local AM = FindMetaTable( "Entity" )
	Check( type( AM.GetManipulateBoneScale ) == "function", "GetManipulateBoneScale" )
	Check( type( AM.GetManipulateBoneAngles ) == "function", "GetManipulateBoneAngles" )
	Check( type( AM.GetManipulateBonePosition ) == "function", "GetManipulateBonePosition" )
	Check( type( AM.ManipulateBoneAngles ) == "function", "ManipulateBoneAngles" )
	Check( type( AM.GetBoneParent ) == "function", "GetBoneParent" )
	Check( type( AM.SetBonePosition ) == "function", "SetBonePosition" )
	Check( type( AM.SetRenderClipPlaneEnabled ) == "function", "SetRenderClipPlaneEnabled" )
	Check( type( AM.SetRenderClipPlane ) == "function", "SetRenderClipPlane" )

	Check( type( render.GetSuperFPTex ) == "function", "render.GetSuperFPTex" )
	Check( type( render.GetSuperFPTex2 ) == "function", "render.GetSuperFPTex2" )
	Check( type( render.RenderView ) == "function", "render.RenderView" )

	Check( type( DynamicLight ) == "function", "DynamicLight global" )
	Check( type( CreateSound ) == "function", "CreateSound global" )

	-- GetBoneName past the last bone must not be nil (the viewmodel bone-mod
	-- base indexes a table with it).
	local lp = LocalPlayer()
	if ( IsValid( lp ) ) then
		local count = lp:GetBoneCount and lp:GetBoneCount() or 0
		if ( count and count > 0 ) then
			Check( lp:GetBoneName( count ) != nil, "GetBoneName(count) non-nil" )
		end
	end
end

print( string.format( "[portalgun_lib_test] %d checks, %d failed", nTests, nFailed ) )
