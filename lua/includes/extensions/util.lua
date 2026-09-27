
-- Return if there's nothing to add on to
if ( !util ) then return end

if ( CLIENT ) then
	include( "util/worldpicker.lua" )
end

--[[---------------------------------------------------------
   Name:	IsValidPhysicsObject
   Params:	<ent> <num>
   Desc:	Returns true if physics object is valid, false if not
-----------------------------------------------------------]]
function util.IsValidPhysicsObject( ent, num )

	-- Make sure the entity is valid
	if ( !ent or ( !ent:IsValid() and !ent:IsWorld() ) ) then return false end

	-- This is to stop attaching to walking NPCs.
	-- Although this is possible and `works', it can severly reduce the
	-- performance of the server.. Plus they don't pay attention to constraints
	-- anyway - so we're not really losing anything.

	local MoveType = ent:GetMoveType()
	if ( !ent:IsWorld() and MoveType != MOVETYPE_VPHYSICS and !( ent:GetModel() and ent:GetModel():StartsWith( "*" ) ) ) then return false end

	local Phys = ent:GetPhysicsObjectNum( num )
	return IsValid( Phys )

end

--[[---------------------------------------------------------
	Name: GetPlayerTrace( ply, dir )
	Desc: Returns a generic trace table for the player
			(dir is optional, defaults to the player's aim)
-----------------------------------------------------------]]
function util.GetPlayerTrace( ply, dir )

	dir = dir or ply:GetAimVector()

	local trace = {}

	trace.start = ply:EyePos()
	trace.endpos = trace.start + ( dir * ( 4096 * 8 ) )
	trace.filter = ply

	return trace

end


--[[---------------------------------------------------------
	Name: QuickTrace( origin, offset, filter )
	Desc: Quick trace
-----------------------------------------------------------]]
function util.QuickTrace( origin, dir, filter )

	local trace = {}

	trace.start = origin
	trace.endpos = origin + dir
	trace.filter = filter

	return util.TraceLine( trace )

end


--[[---------------------------------------------------------
	Name: tobool( in )
	Desc: Turn variable into bool
-----------------------------------------------------------]]
-- HL2SB: the SERVER loads extensions/ BEFORE includes/init.lua, so the global
-- tobool does not exist yet at this point and `util.tobool = tobool` stored nil
-- (sent_nuke's Initialize then died on "attempt to call a nil value (field
-- 'tobool')").  Fall back to the same definition includes/util.lua carries.
util.tobool = tobool or function( val )
	if ( val == nil or val == false or val == 0 or val == "0" or val == "false" ) then return false end
	return true
end


--[[---------------------------------------------------------
	Name: LocalToWorld( ent, lpos, bone )
	Desc: Convert the local position on an entity to world pos
-----------------------------------------------------------]]
function util.LocalToWorld( ent, lpos, bone )

	bone = bone or 0
	if ( ent:EntIndex() == 0 ) then
		return lpos
	else
		if ( IsValid( ent:GetPhysicsObjectNum( bone ) ) ) then
			return ent:GetPhysicsObjectNum( bone ):LocalToWorld( lpos )
		else
			return ent:LocalToWorld( lpos )
		end
	end

	return nil

end


--[[---------------------------------------------------------
	Returns year, month, day and hour, minute, second in a formatted string.
-----------------------------------------------------------]]
function util.DateStamp()

	local t = os.date( "*t" )
	return t.year .. "-" .. t.month .. "-" .. t.day .. " " .. Format( "%02i-%02i-%02i", t.hour, t.min, t.sec )

end

--[[---------------------------------------------------------
	Convert a string to a certain type
-----------------------------------------------------------]]
function util.StringToType( str, typename )

	typename = typename:lower()

	if ( typename == "vector" )	then return Vector( str ) end
	if ( typename == "angle" )	then return Angle( str ) end
	if ( typename == "float" || typename == "number" )	then return tonumber( str ) end
	if ( typename == "int" )	then local v = tonumber( str ) return v and math.Round( v ) or nil end
	if ( typename == "bool" || typename == "boolean" )	then return tobool( str ) end
	if ( typename == "string" )	then return tostring( str ) end
	if ( typename == "entity" )	then return Entity( str ) end

	MsgN( "util.StringToType: unknown type \"", typename, "\"!" )

end

--
-- Convert a type to a (nice, but still parsable) string
--
function util.TypeToString( v )

	local iD = TypeID( v )

	if ( iD == TYPE_VECTOR or iD == TYPE_ANGLE ) then
		return string.format( "%.2f %.2f %.2f", v:Unpack() )
	end

	if ( iD == TYPE_NUMBER ) then
		return util.NiceFloat( v )
	end

	return tostring( v )

end


--
-- Formats a float by stripping off extra 0's and .'s
--
--	0.00	->		0
--	0.10	->		0.1
--	1.00	->		1
--	1.49	->		1.49
--	5.90	->		5.9
--
function util.NiceFloat( f )

	local str = string.format( "%f", f )

	str = str:TrimRight( "0" )
	str = str:TrimRight( "." )

	return str

end



--
-- Timer
--
--
local T =
{
	--
	-- Resets the timer to nothing
	--
	Reset = function( self )

		self.starttime = CurTime() - self.starttime
		self.endtime = nil

	end,

	--
	-- Starts the timer, call with end time
	--
	Start = function( self, time )

		self.starttime = CurTime()
		self.endtime = CurTime() + ( time or 0 )

	end,

	--
	-- Returns true if the timer has been started
	--
	Started = function( self )

		return self.endtime != nil

	end,

	--
	-- Returns true if the time has elapsed
	--
	Elapsed = function( self )

		return self.endtime == nil or self.endtime <= CurTime()

	end,

	--
	-- Returns the amount of time that has passed since the Timer was started
	--
	GetElaspedTime = function( self )

		return self:Started() and CurTime() - self.starttime or self.starttime

	end
}

T.__index = T

--
-- Create a new timer object
--
function util.Timer( startdelay )

	local t = {}
	setmetatable( t, T )
	t:Start( startdelay or 0 )
	return t

end

local function PopStack( self, num )

	if ( num == nil ) then
		num = 1
	elseif ( num < 0 ) then
		error( string.format( "attempted to pop %d elements in stack, expected >= 0", num ), 3 )
	else
		num = math.floor( num )
	end

	local len = self[ 0 ]

	if ( num > len ) then
		error( string.format( "attempted to pop %u element%s in stack of length %u", num, num == 1 and "" or "s", len ), 3 )
	end

	return num, len

end

local STACK =
{
	Push = function( self, obj )
		local len = self[ 0 ] + 1
		self[ len ] = obj
		self[ 0 ] = len
	end,

	Pop = function( self, num )
		local len
		num, len = PopStack( self, num )

		if ( num == 0 ) then
			return nil
		end

		local newlen = len - num
		self[ 0 ] = newlen

		newlen = newlen + 1
		local ret = self[ newlen ]

		-- Pop up to the last element
		for i = len, newlen, -1 do
			self[ i ] = nil
		end

		return ret
	end,

	PopMulti = function( self, num )
		local len
		num, len = PopStack( self, num )

		if ( num == 0 ) then
			return {}
		end

		local newlen = len - num
		self[ 0 ] = newlen

		local ret = {}
		local retpos = 0

		-- Pop each element and add it to the table
		-- Iterate in reverse since the stack is internally stored
		-- with 1 being the bottom element and len being the top
		-- But the return will have 1 as the top element
		for i = len, newlen + 1, -1 do
			retpos = retpos + 1
			ret[ retpos ] = self[ i ]

			self[ i ] = nil
		end

		return ret
	end,

	Top = function( self )
		local len = self[ 0 ]

		if ( len == 0 ) then
			return nil
		end

		return self[ len ]
	end,

	Size = function( self )
		return self[ 0 ]
	end
}

STACK.__index = STACK

function util.Stack()
	return setmetatable( { [ 0 ] = 0 }, STACK )
end

-- Helper for the following functions. This is not ideal but we cannot change this because it will break existing addons.
local function GetUniqueID( sid )
	return util.CRC( "gm_" .. sid .. "_gm" )
end

--[[---------------------------------------------------------
	Name: GetPData( steamid, name, default )
	Desc: Gets the persistant data from a player by steamid
-----------------------------------------------------------]]
function util.GetPData( steamid, name, default )

	-- First try looking up using the new key
	local key = Format( "%s[%s]", util.SteamIDTo64( steamid ), name )
	local val = sql.QueryValue( "SELECT value FROM playerpdata WHERE infoid = " .. SQLStr( key ) .. " LIMIT 1" )
	if ( val == nil ) then

		-- Not found? Look using the old key
		local oldkey = Format( "%s[%s]", GetUniqueID( steamid ), name )
		val = sql.QueryValue( "SELECT value FROM playerpdata WHERE infoid = " .. SQLStr( oldkey ) .. " LIMIT 1" )
		if ( val == nil ) then return default end

	end

	return val

end

--[[---------------------------------------------------------
	Name: SetPData( steamid, name, value )
	Desc: Sets the persistant data of a player by steamid
-----------------------------------------------------------]]
function util.SetPData( steamid, name, value )

	local key = Format( "%s[%s]", util.SteamIDTo64( steamid ), name )
	sql.Query( "REPLACE INTO playerpdata ( infoid, value ) VALUES ( " .. SQLStr( key ) .. ", " .. SQLStr( value ) .. " )" )

end

--[[---------------------------------------------------------
	Name: RemovePData( steamid, name )
	Desc: Removes the persistant data from a player by steamid
-----------------------------------------------------------]]
function util.RemovePData( steamid, name )

	-- First the old key
	local oldkey = Format( "%s[%s]", GetUniqueID( steamid ), name )
	sql.Query( "DELETE FROM playerpdata WHERE infoid = " .. SQLStr( oldkey ) )

	-- Then the new key. util.SteamIDTo64 is not ideal, but nothing we can do about it now
	local key = Format( "%s[%s]", util.SteamIDTo64( steamid ), name )
	sql.Query( "DELETE FROM playerpdata WHERE infoid = " .. SQLStr( key ) )

end

--[[---------------------------------------------------------
	Name: IsBinaryModuleInstalled( name )
	Desc: Returns whether a binary module with the given name is present on disk

	DELTA (sbrust): 与 GMod 原文的三处偏离，全部有据：
	  1. GMod 公式没有安卓槽位，且本引擎 system.IsLinux() 在安卓上为 true
	     （__linux__），原公式会把安卓算进 linux64 -- 与桌面 glibc 模块命名撞车。
	     改为 IsAndroid 优先判定，后缀 android64/android32（C++ 侧
	     hl2sb_binmod.c 的 HL2SB_BinModSuffix 同表）。
	  2. 扩展名不再硬编码 .dll（GMod 原文在 Linux 上本来就是坏的）：
	     Windows .dll，POSIX .so。
	  3. 64 位判定不再依赖 jit.arch（jit 是替身表，arch 已在 lsrcinit 补上，
	     这里用 string.pack 的 size_t 宽度做权威判定，双保险）。
-----------------------------------------------------------]]
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


--===========================================================================--
-- HL2SB (2026-09-25): the rest of GMod's util library, wiki-checked.
-- C++ (lutil_shared.cpp / lcdll_util.cpp) carries the codecs, geometry,
-- surface props and model membership; these four are GMod's own Lua-side
-- members.  Page text is in D:\project\wiki\UTIL_*.txt.
--===========================================================================--

-- ---------------------------------------------------------------------------
-- util.TableToKeyValues( table, rootKey ) -> Valve KV text.  GMod's own
-- emitter writes every key quoted; nested tables become blocks.
-- ---------------------------------------------------------------------------
local function kvEscapeValue( v )
	return tostring( v ):gsub( "\\", "\\\\" ):gsub( '"', '\\"' )
end

local function kvEmitTable( tab, out, indent )
	for k, v in pairs( tab ) do
		local key = kvEscapeValue( k )
		if ( type( v ) == "table" ) then
			out[ #out + 1 ] = indent .. '"' .. key .. '"\n' .. indent .. "{\n"
			kvEmitTable( v, out, indent .. "\t" )
			out[ #out + 1 ] = indent .. "}\n"
		else
			out[ #out + 1 ] = indent .. '"' .. key .. '"\t\t"' .. kvEscapeValue( v ) .. '"\n'
		end
	end
end

if ( util.TableToKeyValues == nil ) then
	function util.TableToKeyValues( tab, rootKey )
		rootKey = rootKey or "TableToKeyValues"
		if ( type( tab ) ~= "table" ) then return "" end

		local out = { '"' .. tostring( rootKey ) .. '"\n{\n' }
		kvEmitTable( tab, out, "\t" )
		out[ #out + 1 ] = "}\n"
		return table.concat( out )
	end
end

-- ---------------------------------------------------------------------------
-- util.KeyValuesToTablePreserveOrder( keyValues, usesEscapeSequences,
-- preserveKeyCase ) -> array of { Key = ..., Value = scalar | same-shape }.
-- Repeated keys survive as separate entries, which is the whole point.
-- ---------------------------------------------------------------------------
local function kvUnescape( s )
	if ( s == nil ) then return nil end
	return ( s:gsub( "\\(.)", function( c )
		if ( c == "n" ) then return "\n"
		elseif ( c == "t" ) then return "\t"
		elseif ( c == '"' ) then return '"'
		elseif ( c == "\\" ) then return "\\"
		end
		return c
	end ) )
end

function util.KeyValuesToTablePreserveOrder( keyValues, usesEscapeSequences, preserveKeyCase )
	if ( type( keyValues ) ~= "string" or keyValues == "" ) then return nil end

	-- tokenize: quoted strings, bare words, braces
	local tokens = {}
	local i = 1
	local n = #keyValues
	while ( i <= n ) do
		local c = keyValues:sub( i, i )
		if ( c == '"' ) then
			local j = i + 1
			local buf = {}
			while ( j <= n ) do
				local ch = keyValues:sub( j, j )
				if ( ch == "\\" and j < n ) then
					buf[ #buf + 1 ] = ch .. keyValues:sub( j + 1, j + 1 )
					j = j + 2
				elseif ( ch == '"' ) then
					j = j + 1
					break
				else
					buf[ #buf + 1 ] = ch
					j = j + 1
				end
			end
			tokens[ #tokens + 1 ] = { str = table.concat( buf ), quoted = true }
			i = j
		elseif ( c == "{" or c == "}" ) then
			tokens[ #tokens + 1 ] = c
			i = i + 1
		elseif ( c == "/" and keyValues:sub( i, i + 1 ) == "//" ) then
			local nl = keyValues:find( "\n", i, true )
			i = nl or ( n + 1 )
		elseif ( c:match( "%s" ) ) then
			i = i + 1
		else
			local j = i
			local buf = {}
			while ( j <= n ) do
				local ch = keyValues:sub( j, j )
				if ( ch:match( "%s" ) or ch == "{" or ch == "}" ) then break end
				buf[ #buf + 1 ] = ch
				j = j + 1
			end
			tokens[ #tokens + 1 ] = { str = table.concat( buf ), quoted = false }
			i = j
		end
	end

	-- GMod coerces numeric strings to numbers whether or not they were
	-- quoted (the wiki's GetModelInfo example prints quoted "1" as 1).
	local function coerce( raw, quoted )
		local v = tonumber( raw )
		if ( v ~= nil ) then return v end
		return raw
	end

	-- The first token is the root block's name; GMod discards it and parses
	-- what follows (same treatment the plain KeyValuesToTable applies).
	local pos = 1
	if ( tokens[ 2 ] == "{" ) then
		pos = 3
	end
	local function parseBlock()
		local node = {}
		while ( pos <= #tokens ) do
			local tok = tokens[ pos ]
			if ( tok == "}" ) then
				pos = pos + 1
				return node
			elseif ( tok == "{" ) then
				pos = pos + 1
				parseBlock() -- stray block without a key: skip
			else
				local key = tok.str
				pos = pos + 1
				if ( tokens[ pos ] == "{" ) then
					pos = pos + 1
					node[ #node + 1 ] = { Key = key, Value = parseBlock() }
				elseif ( tokens[ pos ] ~= nil and tokens[ pos ] ~= "}" ) then
					local vTok = tokens[ pos ]
					pos = pos + 1
					node[ #node + 1 ] = { Key = key, Value = coerce( vTok.str, vTok.quoted ) }
				else
					node[ #node + 1 ] = { Key = key, Value = "" }
				end
			end
		end
		return node
	end

	local result = parseBlock()

	-- pass 2: apply escape sequences / key casing once the structure is safe
	local function normalize( node )
		for i = 1, #node do
			local entry = node[ i ]
			if ( usesEscapeSequences and type( entry.Value ) == "string" ) then
				entry.Value = kvUnescape( entry.Value )
			end
			if ( not preserveKeyCase ) then
				entry.Key = string.lower( entry.Key )
			end
			if ( type( entry.Value ) == "table" ) then
				normalize( entry.Value )
			end
		end
	end
	normalize( result )

	return result
end

-- ---------------------------------------------------------------------------
-- util.GetUserGroups() -> { [steamid] = groupname }, from settings/users.txt.
-- ---------------------------------------------------------------------------
if ( util.GetUserGroups == nil ) then
	function util.GetUserGroups()
		local groups = {}

		local text = file.Read( "settings/users.txt", "GAME" )
			or file.Read( "settings/users.txt", "MOD" )
		if ( text == nil ) then return groups end

		local parsed = util.KeyValuesToTable( text )
		if ( type( parsed ) ~= "table" ) then return groups end

		for groupName, members in pairs( parsed ) do
			if ( type( members ) == "table" ) then
				for _, sid in pairs( members ) do
					if ( type( sid ) == "string" ) then
						groups[ sid ] = groupName
					end
				end
			elseif ( type( members ) == "string" ) then
				groups[ members ] = groupName
			end
		end

		return groups
	end
end

-- ---------------------------------------------------------------------------
-- util.TimerCycle() -> seconds since the previous call (cycle timing).
-- ---------------------------------------------------------------------------
if ( util.TimerCycle == nil ) then
	local nLastCycle = SysTime and SysTime() or 0
	function util.TimerCycle()
		local nNow = SysTime()
		local nDelta = nNow - nLastCycle
		nLastCycle = nNow
		return nDelta
	end
end
