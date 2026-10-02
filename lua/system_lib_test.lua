-- system_lib_test.lua: system.GetPlatformInfo / GetPlatform 合同（双 realm）。
-- 跑法：lua_dofile system_lib_test.lua（server）/ lua_dofile_cl system_lib_test.lua（client）。
-- 字段按宿主能力缺失即缺（nil 合法），测试只断言"出现则类型正确 + 必现字段"。

local nTests, nFailed = 0, 0
local function Check( bCond, sName )
	nTests = nTests + 1
	if ( !bCond ) then
		nFailed = nFailed + 1
		print( "[system_lib_test] FAIL: " .. sName )
	end
end

Check( type( system ) == "table", "system table exists" )
Check( type( system.IsWindows ) == "function", "system.IsWindows" )
Check( type( system.IsAndroid ) == "function", "system.IsAndroid" )
Check( type( system.GetPlatformInfo ) == "function", "system.GetPlatformInfo" )
Check( type( system.GetPlatform ) == "function", "system.GetPlatform" )

Check( system.IsWindows() or system.IsAndroid() or system.IsLinux() or system.IsOsx(), "one known OS is true" )

local t = system.GetPlatformInfo()
Check( type( t ) == "table", "GetPlatformInfo returns table" )
Check( t.os == "windows" or t.os == "android" or t.os == "linux" or t.os == "osx", "t.os known value" )
Check( t.arch == nil or type( t.arch ) == "string", "t.arch string or nil" )
Check( t.processArch == nil or type( t.processArch ) == "string", "t.processArch string or nil" )
Check( t.emulated == nil or type( t.emulated ) == "boolean", "t.emulated boolean or nil" )
Check( t.osVersion == nil or type( t.osVersion ) == "string", "t.osVersion string or nil" )
Check( t.cpu == nil or type( t.cpu ) == "string", "t.cpu string or nil" )
Check( type( t.cores ) == "number" and t.cores > 0, "t.cores positive" )
Check( type( t.totalMemoryMB ) == "number" and t.totalMemoryMB > 0, "t.totalMemoryMB positive" )
Check( type( t.freeMemoryMB ) == "number" and t.freeMemoryMB > 0 and t.freeMemoryMB <= t.totalMemoryMB, "t.freeMemoryMB sane" )
Check( t.gpu == nil or type( t.gpu ) == "string", "t.gpu string or nil" )
Check( t.gpuMemoryMB == nil or ( type( t.gpuMemoryMB ) == "number" and t.gpuMemoryMB > 0 ), "t.gpuMemoryMB positive or nil" )

local sToken = system.GetPlatform()
Check( type( sToken ) == "string" and sToken:find( "-", 1, true ) ~= nil, "GetPlatform token is os-arch" )
Check( t.os == nil or sToken:sub( 1, #t.os ) == t.os, "GetPlatform token starts with t.os" )

print( string.format( "[system_lib_test] %d checks, %d failed", nTests, nFailed ) )

local sDetail = string.format( "  %s | os %s | arch %s (process %s%s) | cpu %s | cores %s | RAM free %s/%sMB | GPU %s %s",
	sToken, tostring( t.osVersion ), tostring( t.arch ), tostring( t.processArch or t.arch ),
	t.emulated == nil and "" or ( t.emulated and " EMULATED" or " native" ),
	tostring( t.cpu ), tostring( t.cores ),
	tostring( t.freeMemoryMB ), tostring( t.totalMemoryMB ),
	tostring( t.gpu ), t.gpuMemoryMB and ( tostring( t.gpuMemoryMB ) .. "MB" ) or "-" )
if ( CLIENT and ScrW ~= nil ) then
	sDetail = sDetail .. string.format( " | screen %dx%d", ScrW(), ScrH() )
end
print( sDetail )

if ( nFailed == 0 ) then
	print( "[system_lib_test] PASSED" )
end
