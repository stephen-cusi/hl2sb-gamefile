-- Platform-specific module paths for the native Lua 5.4 runtime.
local is64bit = ( #string.pack( "T", 0 ) == 8 )
local suffix, binext
if ( system.IsWindows() ) then
	suffix, binext = ( is64bit and "win64" or "win32" ), ".dll"
elseif ( system.IsAndroid and system.IsAndroid() ) then
	suffix, binext = ( is64bit and "android64" or "android32" ), ".so"
else
	suffix, binext = ( is64bit and "linux64" or "linux" ), ".so"
end
local fmt = "lua/bin/gm" .. ( ( CLIENT and !MENU_DLL ) and "cl" or "sv" ) .. "_%s_" .. suffix .. binext
function util.IsBinaryModuleInstalled( name )
	if ( !isstring( name ) ) then
		error( "bad argument #1 to 'IsBinaryModuleInstalled' (string expected, got " .. type( name ) .. ")", 2 )
	elseif ( #name == 0 ) then
		error( "bad argument #1 to 'IsBinaryModuleInstalled' (string cannot be empty)", 2 )
	end

	return file.Exists( string.format( fmt, name ), "MOD" )
end
