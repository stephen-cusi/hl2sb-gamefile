-- Verification probe for the rebuilt file.Find (engine-side, lfilesystem.cpp).
-- Run from the console after a FULL restart (DLLs only load at process start):
--     lua_dofile_cl file_find_test.lua
-- Safe to delete afterwards.

local function Show( label, files, dirs )
	print( string.format( "%-46s files=%-3d dirs=%-3d  %s | %s",
		label,
		table.Count( files or {} ),
		table.Count( dirs or {} ),
		table.concat( files or {}, "," ):sub( 1, 60 ),
		table.concat( dirs or {}, "," ):sub( 1, 60 ) ) )
end

print( "==================== file.Find probe ====================" )

-- 1. the call shapes imported addons actually use (these all returned nothing
--    before, because the old stub appended "/*" to an already-globbed path)
local f, d = file.Find( "entities/weapons/*", "LUA" )
Show( "glob  entities/weapons/*  LUA", f, d )
if #f == 0 and #d == 0 then
	print( "  !! empty - check whether lua/entities/weapons exists under the mod dir" )
end

f, d = file.Find( "addons/*", "MOD" )
Show( "glob  addons/*  MOD", f, d )

-- 2. bare folder, no wildcard -> engine appends "*" itself
f, d = file.Find( "gamemodes", "GAME" )
Show( "folder gamemodes  GAME", f, d )

-- 3. no wildcard but a sub-folder with one
f, d = file.Find( "weapons/*", "LUA" )
Show( "glob  weapons/*  LUA", f, d )

-- 4. DATA is GMod's garrysmod/data, i.e. the mod dir plus a data/ prefix.
--    Empty here on a fresh install; section 10 writes into it and re-lists.
f, d = file.Find( "*", "DATA" )
Show( "star  *  DATA (prefix data/)", f, d )

-- 5. root listing
f, d = file.Find( "", "GAME" )
Show( "root  ''  GAME", f, d )

-- 6. sorting.  nameasc is the default, so 1..5 must already be ascending.
local function IsSortedAsc( t )
	for i = 2, #t do
		if t[i]:lower() < t[i - 1]:lower() then return false end
	end
	return true
end

local asc = { file.Find( "addons/*", "MOD", "nameasc" ) }
local desc = { file.Find( "addons/*", "MOD", "namedesc" ) }
print( string.format( "sort nameasc=%s  namedesc=%s  asc-is-sorted=%s",
	tostring( asc[1] and asc[1][1] or "n/a" ),
	tostring( desc[1] and desc[1][1] or "n/a" ),
	tostring( IsSortedAsc( asc[1] or {} ) ) ) )

-- 7. the two tables must be disjoint and neither may be nil
f, d = file.Find( "lua", "GAME" )
local both = 0
for _, n in ipairs( f ) do
	for _, m in ipairs( d ) do
		if n == m then both = both + 1 end
	end
end
print( string.format( "files/dirs overlap = %d (must be 0)", both ) )

-- ======================================================================
-- The GMod contract this revision was written against:
--   https://wiki.facepunch.com/gmod/file.Find  +  /gmod/File_Search_Paths
-- and the value of every check below is printed next to it.
-- ======================================================================

local function Try( label, fn )
	local ok, a, b = pcall( fn )
	if ( not ok ) then
		print( string.format( "%-46s ERROR: %s", label, tostring( a ) ) )
		return nil, nil
	end
	return a, b
end

-- 8. "A table of found files, or nil if the path is invalid."  An unknown path
--    ID must be nil/nil; a valid path with nothing in it must be two tables.
local badF, badD = Try( "invalid path -> nil,nil", function() return file.Find( "*", "NOT_A_PATH_ID" ) end )
print( string.format( "invalid path: files=%s dirs=%s   (both must be nil)",
	tostring( badF ), tostring( badD ) ) )

local emptyF, emptyD = Try( "valid+empty -> tables", function() return file.Find( "no/such/folder/*", "GAME" ) end )
print( string.format( "valid+empty: files=%s dirs=%s   (both must be tables)",
	tostring( type( emptyF ) ), tostring( type( emptyD ) ) ) )

-- 9. BASE_PATH is the launcher's folder, i.e. this mod's parent.  It is what
--    lua/autorun/detect_source_games.lua lists to find sibling Source games.
local _, baseDirs = Try( "BASE_PATH dirs", function() return file.Find( "*", "BASE_PATH" ) end )
print( string.format( "BASE_PATH dirs=%d  %s", table.Count( baseDirs or {} ),
	table.concat( baseDirs or {}, "," ):sub( 1, 70 ) ) )

-- 10. DATA is a real writable folder now (GMod: garrysmod/data, names
--     lowercased, sub-folders created on demand).
local wrote = Try( "file.Write", function() return file.Write( "hl2sb_probe/TestFile.TXT", "hello" ) end )
local read = Try( "file.Read", function() return file.Read( "hl2sb_probe/testfile.txt" ) end )
local dataFiles, dataDirs = Try( "file.Find data/", function() return file.Find( "hl2sb_probe/*", "DATA" ) end )
print( string.format( "write=%s  read=%s  find files=[%s] dirs=[%s]   (want true / \"hello\" / testfile.txt)",
	tostring( wrote ), tostring( read ),
	table.concat( dataFiles or {}, "," ), table.concat( dataDirs or {}, "," ) ) )

-- the folder must also show up in a listing of data/ itself (section 4 ran
-- before anything had been written, so it was empty there on a fresh install)
local dataRootF, dataRootD = Try( "file.Find * DATA", function() return file.Find( "*", "DATA" ) end )
print( string.format( "data/ now: files=%d dirs=[%s]   (want files=0 dirs=hl2sb_probe)",
	table.Count( dataRootF or {} ), table.concat( dataRootD or {}, "," ) ) )

local renamed = Try( "file.Rename", function() return file.Rename( "hl2sb_probe/testfile.txt", "hl2sb_probe/renamed.txt" ) end )
local stillThere = Try( "file.Exists after rename", function() return file.Exists( "hl2sb_probe/testfile.txt", "DATA" ) end )
print( string.format( "rename=%s  old-name-still-there=%s   (want true / false)",
	tostring( renamed ), tostring( stillThere ) ) )

Try( "cleanup", function()
	file.Delete( "hl2sb_probe/renamed.txt", "DATA" )
	return true
end )
print( string.format( "cleanup left behind: %s   (want false)",
	tostring( file.Exists( "hl2sb_probe/renamed.txt", "DATA" ) ) ) )

-- 11. file.AsyncRead reports through GMod's callback signature and status code.
local _, seen = Try( "AsyncRead", function()
	local captured
	file.AsyncRead( "gameinfo.txt", "MOD", function( name, path, status2, data )
		captured = { name, path, status2, type( data ), data and #data or -1 }
	end )
	return 1, captured
end )
print( string.format( "AsyncRead callback: %s  status==FSASYNC_OK? %s",
	seen and ( seen[1] .. " | " .. tostring( seen[2] ) .. " | " .. tostring( seen[3] ) ..
		" | " .. seen[4] .. " | len=" .. tostring( seen[5] ) ) or "NOT CALLED",
	tostring( seen and seen[3] == FSASYNC_OK ) ) )

-- 12. library surface, against https://wiki.facepunch.com/gmod/file
local expected = { "Append", "AsyncRead", "CreateDir", "Delete", "Exists", "Find",
	"IsDir", "Open", "Read", "Rename", "Size", "Time", "Write" }
local missing = {}
for _, name in ipairs( expected ) do
	if ( type( file[ name ] ) != "function" ) then table.insert( missing, name ) end
end
print( string.format( "file.* missing: %s   (none = full GMod surface)",
	#missing > 0 and table.concat( missing, "," ) or "none" ) )
print( string.format( "FSASYNC_OK=%s  file.FindDir=%s   (GMod has no file.FindDir)",
	tostring( FSASYNC_OK ), tostring( file.FindDir ) ) )

-- 13. cosmetic, but worth pinning down: the GAME listing is the UNION of every
--     mounted root, and the engine itself contributes a synthetic "/" entry
--     (GMod has the same one -- its lua/vgui/dtree_node.lua:512 strips it).
--     Anything else that is not a real folder name gets dumped by byte value
--     here, so a surprise entry can be identified instead of guessed at.
local _, rootDirs = Try( "root dirs", function() return file.Find( "", "GAME" ) end )
for _, name in ipairs( rootDirs or {} ) do
	if ( not name:sub( 1, 1 ):match( "[%w_]" ) ) then
		local bytes = {}
		for i = 1, #name do
			bytes[ i ] = string.format( "%02X", name:byte( i ) )
		end
		print( string.format( "odd root dir: [%s] len=%d bytes=%s",
			name, #name, table.concat( bytes, " " ) ) )
	end
end

print( "=========================================================" )
