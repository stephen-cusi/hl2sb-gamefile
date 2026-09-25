-- Verification probe for the rebuilt file library (engine-side, lfilesystem.cpp):
--   * file.Open block list (.db/.mdmp/.dmp + the five cfg names) and the
--     write-side extension whitelist on DATA
--   * file.Size -1 / file.Time 0-and-1 contracts
--   * the File object binary accessors (Read/WriteBool..WriteUInt64, ReadLine,
--     Skip) added 2026-09-25
--   * FSASYNC_* globals + file.AsyncRead callback shape
-- Run from the console after a FULL restart (DLLs only load at process start):
--     lua_dofile file_lib_test.lua        (server realm)
--     lua_dofile_cl file_lib_test.lua     (client realm)
-- Safe to delete afterwards.

local nPassed = 0
local nFailed = 0

local function Check( label, ok, extra )
	if ok then
		nPassed = nPassed + 1
		print( "  PASS  " .. label )
	else
		nFailed = nFailed + 1
		print( "  FAIL  " .. label .. ( extra ~= nil and ( "   (" .. tostring( extra ) .. ")" ) or "" ) )
	end
end

local function Near( a, b, eps )
	return math.abs( a - b ) <= eps
end

print( "==================== file library probe ====================" )

-- ---------------------------------------------------------------------------
-- 0. FSASYNC_* globals (were nil before 2026-09-25)
-- ---------------------------------------------------------------------------
Check( "FSASYNC_OK == 0",					FSASYNC_OK == 0,					FSASYNC_OK )
Check( "FSASYNC_ERR_FILEOPEN == -1",		FSASYNC_ERR_FILEOPEN == -1,			FSASYNC_ERR_FILEOPEN )
Check( "FSASYNC_ERR_NOT_MINE == -8",		FSASYNC_ERR_NOT_MINE == -8,			FSASYNC_ERR_NOT_MINE )
Check( "FSASYNC_STATUS_UNSERVICED == 4",	FSASYNC_STATUS_UNSERVICED == 4,		FSASYNC_STATUS_UNSERVICED )

-- ---------------------------------------------------------------------------
-- 1. cleanup from any previous run
-- ---------------------------------------------------------------------------
local g_TestFiles = { "hl2sb_probe_ok.txt", "hl2sb_probe_bin.dat", "hl2sb_probe_lines.txt",
			"hl2sb_probe_lower.txt", "hl2sb_probe_ren_src.txt", "hl2sb_probe_ren_dst.txt" }
for _, name in ipairs( g_TestFiles ) do
	file.Delete( name, "DATA" )
end

-- ---------------------------------------------------------------------------
-- 2. file.Open block list (reads included)
-- ---------------------------------------------------------------------------
Check( "Open config.cfg -> nil",			file.Open( "config.cfg", "r", "GAME" ) == nil )
Check( "Open cfg/server.cfg -> nil",		file.Open( "cfg/server.cfg", "r", "MOD" ) == nil )
Check( "Open autoexec.cfg -> nil",			file.Open( "autoexec.cfg", "r", "GAME" ) == nil )
Check( "Open listenserver.cfg -> nil",		file.Open( "listenserver.cfg", "r", "GAME" ) == nil )
Check( "Open mount.cfg -> nil",				file.Open( "mount.cfg", "r", "GAME" ) == nil )
Check( "Open x.db -> nil",					file.Open( "x.db", "rb", "GAME" ) == nil )
Check( "Open x.mdmp -> nil",				file.Open( "x.mdmp", "rb", "GAME" ) == nil )
Check( "Open x.dmp -> nil",					file.Open( "x.dmp", "rb", "GAME" ) == nil )

-- ---------------------------------------------------------------------------
-- 3. write-side extension whitelist (DATA only) + lowercase rule
-- ---------------------------------------------------------------------------
Check( "Write ok.txt -> true",				file.Write( "hl2sb_probe_ok.txt", "hello" ) == true )
Check( "Read back ok.txt",					file.Read( "hl2sb_probe_ok.txt", "DATA" ) == "hello" )
Check( "Write bad.cfg -> false",			file.Write( "hl2sb_probe_bad.cfg", "x" ) == false )
Check( "Open bad2.ini wb -> nil",			file.Open( "hl2sb_probe_bad2.ini", "wb", "DATA" ) == nil )

file.Write( "HL2SB_Probe_Lower.TXT", "abc" )
Check( "Write HL2SB_Lower.TXT lowercased",	file.Exists( "hl2sb_probe_lower.txt", "DATA" ) == true )

-- ---------------------------------------------------------------------------
-- 4. file.Size / file.Time contracts
-- ---------------------------------------------------------------------------
Check( "Size missing -> -1",				file.Size( "hl2sb_probe_missing.txt", "DATA" ) == -1,
	file.Size( "hl2sb_probe_missing.txt", "DATA" ) )
Check( "Size ok.txt -> 5",					file.Size( "hl2sb_probe_ok.txt", "DATA" ) == 5 )
Check( "Time missing -> 0",					file.Time( "hl2sb_probe_missing.txt", "DATA" ) == 0,
	file.Time( "hl2sb_probe_missing.txt", "DATA" ) )
Check( "Time ok.txt > 0",					( file.Time( "hl2sb_probe_ok.txt", "DATA" ) or 0 ) > 0 )

-- ---------------------------------------------------------------------------
-- 5. File object: binary accessors round trip (LE)
-- ---------------------------------------------------------------------------
do
	local f = file.Open( "hl2sb_probe_bin.dat", "wb", "DATA" )
	Check( "Open bin.dat for write", f ~= nil )
	if f then
		f:WriteBool( true )
		f:WriteByte( 255 )
		f:WriteShort( -12345 )
		f:WriteUShort( 65535 )
		f:WriteLong( -1234567890 )
		f:WriteULong( 4294967295 )
		f:WriteFloat( 3.14 )
		f:WriteDouble( 3.14159265358979 )
		f:WriteUInt64( "18446744073709551615" )
		f:Close()
	end

	local r = file.Open( "hl2sb_probe_bin.dat", "rb", "DATA" )
	Check( "Open bin.dat for read", r ~= nil )
	if r then
		-- read everything sequentially first: each call advances the stream by
		-- exactly its own size, and no check may sneak in a second read
		local vBool		= r:ReadBool()
		local vByte		= r:ReadByte()
		local vShort	= r:ReadShort()
		local vUShort	= r:ReadUShort()
		local vLong		= r:ReadLong()
		local vULong	= r:ReadULong()
		local vFloat	= r:ReadFloat()
		local vDouble	= r:ReadDouble()
		local vU64		= r:ReadUInt64()
		local bEOF		= r:EndOfFile()
		local vEOFByte	= r:ReadByte()

		Check( "ReadBool",				vBool == true, vBool )
		Check( "ReadByte == 255",		vByte == 255, vByte )
		Check( "ReadShort == -12345",	vShort == -12345, vShort )
		Check( "ReadUShort == 65535",	vUShort == 65535, vUShort )
		Check( "ReadLong",				vLong == -1234567890, vLong )
		Check( "ReadULong == 4294967295", vULong == 4294967295, vULong )
		Check( "ReadFloat ~= 3.14",		Near( vFloat, 3.14, 0.001 ), vFloat )
		Check( "ReadDouble ~= pi",		Near( vDouble, 3.14159265358979, 1e-12 ), vDouble )
		Check( "ReadUInt64 == max u64",	vU64 == "18446744073709551615", vU64 )
		Check( "EOF after all reads",	bEOF == true, bEOF )
		Check( "ReadByte at EOF == 0",	vEOFByte == 0, vEOFByte )

		-- Skip: moves relative, returns the amount itself (wiki contract)
		r:Seek( 0 )
		local nSkipped = r:Skip( 5 )
		Check( "Skip returns amount",	nSkipped == 5, nSkipped )
		r:Close()
	end
end

-- ---------------------------------------------------------------------------
-- 6. File:ReadLine -- \r ignored, \0 stops but yields a newline, includes \n
-- ---------------------------------------------------------------------------
do
	local payload = "first\r\nsecond\n" .. string.char( 0 ) .. "hidden"
	local f = file.Open( "hl2sb_probe_lines.txt", "wb", "DATA" )
	if f then
		f:Write( payload )
		f:Close()
	end

	local r = file.Open( "hl2sb_probe_lines.txt", "rb", "DATA" )
	if r then
		local l1	= r:ReadLine()
		local l2	= r:ReadLine()
		local l3	= r:ReadLine()
		local rest	= r:Read()

		Check( "ReadLine #1 strips \\r, keeps \\n",	l1 == "first\n", tostring( l1 ) )
		Check( "ReadLine #2",						l2 == "second\n", tostring( l2 ) )
		Check( "ReadLine stops at \\0, adds \\n",	l3 == "\n", tostring( l3 ) )
		Check( "rest after \\0",					rest == "hidden", tostring( rest ) )
		r:Close()
	end
end

-- ---------------------------------------------------------------------------
-- 7. file.Rename round trip
-- ---------------------------------------------------------------------------
do
	file.Write( "hl2sb_probe_ren_src.txt", "move me" )
	local ok = file.Rename( "hl2sb_probe_ren_src.txt", "hl2sb_probe_ren_dst.txt" )
	Check( "Rename -> true",			ok == true, ok )
	Check( "Rename old gone",			file.Exists( "hl2sb_probe_ren_src.txt", "DATA" ) == false )
	Check( "Rename new here",			file.Exists( "hl2sb_probe_ren_dst.txt", "DATA" ) == true )
end

-- ---------------------------------------------------------------------------
-- 8. file.AsyncRead -- callback( fileName, gamePath, status, data ), returns status
-- ---------------------------------------------------------------------------
do
	local tArgs = nil
	local nStatus = file.AsyncRead( "hl2sb_probe_ok.txt", "DATA", function( name, path, status, data )
		tArgs = { name, path, status, data }
	end )
	Check( "AsyncRead returns FSASYNC_OK",	nStatus == FSASYNC_OK, nStatus )
	Check( "AsyncRead callback arg1",		tArgs ~= nil and tArgs[ 1 ] == "hl2sb_probe_ok.txt", tArgs and tArgs[ 1 ] )
	Check( "AsyncRead callback arg2",		tArgs ~= nil and tArgs[ 2 ] == "DATA" )
	Check( "AsyncRead callback arg3",		tArgs ~= nil and tArgs[ 3 ] == FSASYNC_OK )
	Check( "AsyncRead callback arg4 data",	tArgs ~= nil and tArgs[ 4 ] == "hello" )

	-- "All limitations of file.Read also apply": blocked name -> FSASYNC_ERR_FILEOPEN
	local nBlocked = file.AsyncRead( "config.cfg", "GAME", function( name, path, status )
	end )
	Check( "AsyncRead blocked -> ERR_FILEOPEN", nBlocked == FSASYNC_ERR_FILEOPEN, nBlocked )
end

-- ---------------------------------------------------------------------------
-- 9. file.Find sees the probe files; CreateDir / IsDir
-- ---------------------------------------------------------------------------
do
	local files, dirs = file.Find( "hl2sb_probe_*", "DATA" )
	Check( "Find returns a files table",	type( files ) == "table", type( files ) )

	local nFound = 0
	for _ in pairs( files or {} ) do nFound = nFound + 1 end
	Check( "Find sees >= 3 probe files",	nFound >= 3, nFound )

	file.CreateDir( "hl2sb_probe_dir/sub" )
	Check( "CreateDir a/b style",			file.IsDir( "hl2sb_probe_dir/sub", "DATA" ) == true )
	-- wiki file.Exists: "file or directory" -- directories count
	Check( "Exists on directory -> true",	file.Exists( "hl2sb_probe_dir", "DATA" ) == true )

	-- GMod deletes empty folders; this engine's IFileSystem has no
	-- RemoveDirectory, so file.Delete on a folder answers false SILENTLY
	-- (no "Unable to remove" spew, matching GMod's silence on misses)
	local bSubGone	= file.Delete( "hl2sb_probe_dir/sub", "DATA" )
	local bDirGone	= file.Delete( "hl2sb_probe_dir", "DATA" )
	print( "  INFO  Delete(empty folder) -> " .. tostring( bSubGone ) .. ", Delete(folder) -> " .. tostring( bDirGone ) ..
		" (engine has no RemoveDirectory; false is expected)" )
end

-- ---------------------------------------------------------------------------
-- 10. cleanup
-- ---------------------------------------------------------------------------
do
	local nLeft = 0
	for _, name in ipairs( g_TestFiles ) do
		file.Delete( name, "DATA" )
		if file.Exists( name, "DATA" ) then nLeft = nLeft + 1 end
	end
	Check( "cleanup deleted everything", nLeft == 0, nLeft .. " left" )
end

print( string.format( "==================== file probe done: %d passed, %d failed ====================",
	nPassed, nFailed ) )
if nFailed > 0 then
	print( "!! FAILURES ABOVE -- engine file library deviates from the wiki contracts" )
end
