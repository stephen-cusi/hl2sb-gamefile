--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Extends the table library.
--
-- HL2SB additions: ports the GMod table extension (lua/includes/extensions/
-- table.lua) subset that HL2SB can actually use. GMod-specific global type
-- predicates (istable/isstring/isnumber/isbool/IsColor) are replaced with the
-- standard `type()` checks, and functions that depend on Vector/Angle/IsColor
-- userdata (Sanitise/DeSanitise/ToString's color handling) are left out since
-- those types don't exist in HL2SB's Lua env.
--
-- Loaded every level from lua/includes/extensions/.
--===========================================================================--

require( "table" )

local setmetatable = setmetatable
local getmetatable = getmetatable
local pairs = pairs
local type = type
local print = print
local KeyValues = KeyValues
local istable = function( x ) return type( x ) == "table" end
local isnumber = function( x ) return type( x ) == "number" end
local isstring = function( x ) return type( x ) == "string" end
local isbool = function( x ) return type( x ) == "boolean" end

function table.copy( t, tRecursive )
  if ( t == nil ) then
    return nil
  end
  local __copy = {}
  setmetatable( __copy, getmetatable( t ) )
  for i, v in pairs( t ) do
    if ( type( v ) ~= "table" ) then
      __copy[ i ] = v
    else
      tRecursive = tRecursive or {}
      tRecursive[ t ] = __copy
      if ( tRecursive[ v ] ) then
        __copy[ i ] = tRecursive[ v ]
      else
        __copy[ i ] = table.copy( v, tRecursive )
      end
    end
  end
  return __copy
end

function table.hasvalue( t, val )
  for _, v in pairs( t ) do
    if ( v == val ) then
      return true
    end
  end
  return false
end

function table.inherit( t, BaseClass )
  for k, v in pairs( BaseClass ) do
    if ( t[ k ] == nil ) then
      t[ k ] = v
    end
  end
  t.BaseClass = BaseClass
  return t
end

function table.merge( dest, src )
  if ( type( dest ) ~= "table" ) then
    error( "bad argument #1 to 'merge' (table expected, got " .. type( dest ) .. ")", 2 )
  end
  if ( type( src ) ~= "table" ) then
    error( "bad argument #2 to 'merge' (table expected, got " .. type( src ) .. ")", 2 )
  end
  for k, v in pairs( src ) do
    if ( type( dest[ k ] ) == "table" and type( v ) == "table" ) then
      table.merge( dest[ k ], v )
    else
      dest[ k ] = v
    end
  end
end

function table.print( t, bOrdered, i )
  i = i or 0
  local indent = ""
  for j = 1, i do
    indent = indent .. "\t"
  end
  if ( not bOrdered ) then
    for k, v in pairs( t ) do
      if ( type( v ) == "table" ) then
        print( indent .. k )
        table.print( v, false, i + 1 )
      else
        print( indent .. k, v )
      end
    end
  else
    for j, pair in ipairs( t ) do
      if ( type( pair.value ) == "table" ) then
        print( indent .. pair.key )
        table.print( pair.value, true, i + 1 )
      else
        print( indent .. pair.key, pair.value )
      end
    end
  end
end

function table.tokeyvalues( t, setName, bOrdered )
  local pKV = KeyValues( setName )
  if ( not bOrdered ) then
    for k, v in pairs( t ) do
      if ( type( v ) == "table" ) then
        pKV:AddSubKey( table.tokeyvalues( v, k ) )
      elseif ( type( v ) == "string" ) then
        pKV:SetString( k, v )
      elseif ( type( v ) == "number" ) then
        pKV:SetFloat( k, v )
      elseif ( type( v ) == "table" and isnumber( v.r ) and isnumber( v.g ) and isnumber( v.b ) ) then
        pKV:SetColor( k, v )
      else
        pKV:SetString( k, tostring( v ) )
      end
    end
  else
    for i, pair in ipairs( t ) do
      if ( type( pair.value ) == "table" ) then
        pKV:AddSubKey( table.tokeyvalues( pair.value, pair.key, true ) )
      else
        local pKey = pKV:CreateNewKey()
        pKey:SetName( pair.key )
        pKey:SetStringValue( tostring( pair.value ) )
      end
    end
  end
  return pKV
end

-- ===========================================================================
-- GMod-style table extension (HL2SB-adapted)
-- ===========================================================================

function table.Pack( ... )
  return { ... }, select( "#", ... )
end

function table.Empty( tab )
  for k, v in pairs( tab ) do
    tab[ k ] = nil
  end
end

function table.IsEmpty( tab )
  return next( tab ) == nil
end

function table.CopyFromTo( from, to )
  table.Empty( to )
  table.Merge( to, from )
end

function table.Merge( dest, source, forceOverride )
  for k, v in pairs( source ) do
    if ( not forceOverride and istable( v ) and istable( dest[ k ] ) ) then
      table.Merge( dest[ k ], v )
    else
      dest[ k ] = v
    end
  end
  return dest
end

function table.Add( dest, source )
  if ( dest == source ) then return dest end
  if ( not istable( source ) ) then return dest end
  if ( not istable( dest ) ) then dest = {} end
  for k, v in pairs( source ) do
    table.insert( dest, v )
  end
  return dest
end

function table.SortDesc( t )
  return table.sort( t, function( a, b ) return a > b end )
end

function table.SortByKey( t, desc )
  local temp = {}
  for key, _ in pairs( t ) do table.insert( temp, key ) end
  if ( desc ) then
    table.sort( temp, function( a, b ) return t[ a ] < t[ b ] end )
  else
    table.sort( temp, function( a, b ) return t[ a ] > t[ b ] end )
  end
  return temp
end

function table.Count( t )
  local i = 0
  for k in pairs( t ) do i = i + 1 end
  return i
end

function table.Random( t )
  local rk = math.random( 1, table.Count( t ) )
  local i = 1
  for k, v in pairs( t ) do
    if ( i == rk ) then return v, k end
    i = i + 1
  end
end

function table.Shuffle( t )
  local n = #t
  for i = 1, n - 1 do
    local j = math.random( i, n )
    t[ i ], t[ j ] = t[ j ], t[ i ]
  end
end

function table.IsSequential( t )
  local i = 1
  for key, value in pairs( t ) do
    if ( t[ i ] == nil ) then return false end
    i = i + 1
  end
  return true
end

--[[---------------------------------------------------------
    Name: table.ToString( table )
    Desc: Convert a plain table to a readable string (no Vector/Angle/Color).
-----------------------------------------------------------]]
local function MakeTable( t, nice, indent, done )
  local str = ""
  done = done or {}
  indent = indent or 0
  local idt = ""
  if ( nice ) then idt = string.rep( "\t", indent ) end
  local nl, tab = "", ""
  if ( nice ) then nl, tab = "\n", "\t" end
  for key, value in pairs( t ) do
    str = str .. idt .. tab .. tab
    if ( istable( value ) and not done[ value ] ) then
      done[ value ] = true
      str = str .. tostring( key ) .. tab .. '{' .. nl .. MakeTable( value, nice, indent + 1, done )
      str = str .. idt .. tab .. tab .. tab .. tab .. "}," .. nl
    else
      if isstring( value ) then
        value = '"' .. tostring( value ) .. '"'
      else
        value = tostring( value )
      end
      str = str .. tostring( key ) .. tab .. value .. "," .. nl
    end
  end
  return str
end

function table.ToString( t, n, nice )
  local nl, tab = "", ""
  if ( nice ) then nl, tab = "\n", "\t" end
  local str = ""
  if ( n ) then str = n .. tab .. "=" .. tab end
  return str .. "{" .. nl .. MakeTable( t, nice ) .. "}"
end

function table.ForceInsert( t, v )
  if ( t == nil ) then t = {} end
  table.insert( t, v )
  return t
end

function table.SortByMember( tab, memberName, bAsc )
  local TableMemberSort = function( a, b, MemberName, bReverse )
    if ( not istable( a ) ) then return not bReverse end
    if ( not istable( b ) ) then return bReverse end
    if ( not a[ MemberName ] ) then return not bReverse end
    if ( not b[ MemberName ] ) then return bReverse end
    if ( isstring( a[ MemberName ] ) ) then
      if ( bReverse ) then
        return a[ MemberName ]:lower() < b[ MemberName ]:lower()
      else
        return a[ MemberName ]:lower() > b[ MemberName ]:lower()
      end
    end
    if ( bReverse ) then
      return a[ MemberName ] < b[ MemberName ]
    else
      return a[ MemberName ] > b[ MemberName ]
    end
  end
  table.sort( tab, function( a, b )
    return TableMemberSort( a, b, memberName, bAsc or false )
  end )
end

function table.LowerKeyNames( tab )
  local OutTable = {}
  for k, v in pairs( tab ) do
    if ( istable( v ) ) then
      v = table.LowerKeyNames( v )
    end
    OutTable[ k ] = v
    if ( isstring( k ) ) then
      OutTable[ k ] = nil
      OutTable[ string.lower( k ) ] = v
    end
  end
  return OutTable
end

function table.GetFirstKey( t )
  local k, _ = next( t )
  return k
end

function table.GetFirstValue( t )
  local _, v = next( t )
  return v
end

function table.GetWinningKey( tab )
  local highest = -math.huge
  local winner = nil
  for k, v in pairs( tab ) do
    if ( v > highest ) then
      winner = k
      highest = v
    end
  end
  return winner
end

function table.KeyFromValue( tbl, val )
  for key, value in pairs( tbl ) do
    if ( value == val ) then return key end
  end
end

function table.RemoveByValue( tbl, val )
  local key = table.KeyFromValue( tbl, val )
  if ( not key ) then return false end
  if ( isnumber( key ) ) then
    table.remove( tbl, key )
  else
    tbl[ key ] = nil
  end
  return key
end

function table.KeysFromValue( tbl, val )
  local res = {}
  for key, value in pairs( tbl ) do
    if ( value == val ) then res[ #res + 1 ] = key end
  end
  return res
end

function table.Reverse( tbl )
  local len = #tbl
  local ret = {}
  for i = len, 1, -1 do
    ret[ len - i + 1 ] = tbl[ i ]
  end
  return ret
end

function table.ForEach( tab, funcname )
  for k, v in pairs( tab ) do
    funcname( k, v )
  end
end

function table.GetKeys( tab )
  local keys = {}
  local id = 1
  for k, v in pairs( tab ) do
    keys[ id ] = k
    id = id + 1
  end
  return keys
end

function table.Flip( tab )
  local res = {}
  for k, v in pairs( tab ) do
    res[ v ] = k
  end
  return res
end

-- Polyfill for table.move (Lua 5.1 has no table.move; use unpack).
if ( not table.move ) then
  function table.move( sourceTbl, from, to, dest, destTbl )
    if ( not istable( sourceTbl ) ) then error( "bad argument #1 to 'move' (table expected, got " .. type( sourceTbl ) .. ")", 2 ) end
    if ( not isnumber( from ) ) then error( "bad argument #2 to 'move' (number expected, got " .. type( from ) .. ")", 2 ) end
    if ( not isnumber( to ) ) then error( "bad argument #3 to 'move' (number expected, got " .. type( to ) .. ")", 2 ) end
    if ( not isnumber( dest ) ) then error( "bad argument #4 to 'move' (number expected, got " .. type( dest ) .. ")", 2 ) end
    if ( destTbl ~= nil ) then
      if ( not istable( destTbl ) ) then error( "bad argument #5 to 'move' (table expected, got " .. type( destTbl ) .. ")", 2 ) end
    else
      destTbl = sourceTbl
    end
    local buffer = { unpack( sourceTbl, from, to ) }
    dest = math.floor( dest - 1 )
    for i = 1, to - from + 1 do
      destTbl[ dest + i ] = buffer[ i ]
    end
    return destTbl
  end
end

-- Sorted pairs helpers (global, like GMod).
local function getKeys( tbl )
  local keys, i = {}, 0
  for k in pairs( tbl ) do
    i = i + 1
    keys[ i ] = k
  end
  return keys
end

function SortedPairs( pTable, Desc )
  local keys = getKeys( pTable )
  if ( Desc ) then
    table.sort( keys, function( a, b ) return a > b end )
  else
    table.sort( keys, function( a, b ) return a < b end )
  end
  local i, key = 1, nil
  return function()
    key, i = keys[ i ], i + 1
    return key, pTable[ key ]
  end
end

print( "[HL2SB] table extension loaded" )

-- ===========================================================================
-- GMod 大小写/命名兼容别名
--   GMod 的库用 table.Copy / table.HasValue / table.Implode ...
--   HL2SB 原来是 table.copy / table.hasvalue。两个名字都留，
--   从 GMod 搬过来的库（list.lua、team.lua 等）才能原样跑。
-- ===========================================================================
table.Copy     = table.Copy     or table.copy
table.HasValue = table.HasValue or table.hasvalue
table.Merge    = table.Merge    or table.merge
table.Implode  = table.Implode  or function( sep, t ) return string.Implode( sep, t ) end
table.GetN     = table.GetN     or function( t ) return #t end

-- Lua 5.4 去掉了 5.1 的这几个；GMod 代码还在用。
table.getn     = table.getn     or table.GetN
table.foreach  = table.foreach  or function( t, fn )
  for k, v in pairs( t ) do
    local r = fn( k, v )
    if ( r ~= nil ) then return r end
  end
end
table.foreachi = table.foreachi or function( t, fn )
  for i = 1, #t do
    local r = fn( i, t[ i ] )
    if ( r ~= nil ) then return r end
  end
end

-- ===========================================================================
-- table.insert 返回值
--   GMod 的引擎补丁让 table.insert 返回"插入位置"，标准 Lua 返回 nothing。
--   GMod 自己的 undo.lua 就是靠这个：
--       local id = table.insert( PlayerUndo[ index ], Current_Undo )
--       net.WriteInt( id, 16 )        -- 标准 Lua 下 id 是 nil -> 报错
--   GMod 的 lua/includes/extensions/table.lua 里没有这个补丁，是引擎侧的，
--   所以这里用纯 Lua 复刻：
--       table.insert( t, value )        -> 返回 #t
--       table.insert( t, pos, value )   -> 返回 pos
--   内部一律走保存下来的原生实现，避免递归。
-- ===========================================================================
local rawinsert = table.insert
function table.insert( t, a, b )
  if ( b == nil ) then
    rawinsert( t, a )
    return #t
  end

  rawinsert( t, a, b )
  return a
end
-- ===========================================================================
-- HL2SB: the remaining GMod table/pairs helpers (2026-09-13).
--
-- Ported verbatim from GMod's lua/includes/extensions/table.lua, which defines
-- 42 top-level names; this file only had 33.  The missing ones were not merely
-- "unused":  SortedPairsByMemberValue is called by the GMod sandbox spawnmenu
--
--   gamemodes/sandbox/gamemode/spawnmenu/creationmenu.lua:31
--       for k, v in SortedPairsByMemberValue( tabs, "Order" ) do
--
-- so PANEL:Populate() threw "attempt to call a nil value (global
-- 'SortedPairsByMemberValue')" and CreationMenu:Init() aborted the whole
-- spawnmenu build.  (properties.lua:90, dcombobox.lua:206, dentityproperties.lua:50,
-- dform.lua:114 and propselect.lua:136 were already calling it and silently
-- failing.)
--
-- Deliberately NOT ported: table.Sanitise / table.DeSanitise, which need the
-- GMod entity/Vector/Color userdata predicates this fork does not have (the
-- reason the rest of this file is a subset).  Nothing in lua/ or gamemodes/
-- calls them.
-- ===========================================================================

--[[---------------------------------------------------------
	Name: table.CollapseKeyValue( table )
	Desc: Collapses a table with keyvalue structure
-----------------------------------------------------------]]
function table.CollapseKeyValue( Table )

	local OutTable = {}

	for k, v in pairs( Table ) do

		local Val = v.Value

		if ( istable( Val ) ) then
			Val = table.CollapseKeyValue( Val )
		end

		OutTable[ v.Key ] = Val

	end

	return OutTable

end

--[[---------------------------------------------------------
	Name: table.ClearKeys( table, bSaveKey )
	Desc: Clears the keys, converting to a numbered format
-----------------------------------------------------------]]
function table.ClearKeys( Table, bSaveKey )

	local OutTable = {}

	for k, v in pairs( Table ) do
		if ( bSaveKey ) then
			v.__key = k
		end
		table.insert( OutTable, v )
	end

	return OutTable

end

local function hl2sb_keyValuePairs( state )

	state.Index = state.Index + 1

	local keyValue = state.KeyValues[ state.Index ]
	if ( !keyValue ) then return end

	return keyValue.key, keyValue.val

end

local function hl2sb_toKeyValues( tbl )

	local result = {}

	for k, v in pairs( tbl ) do
		table.insert( result, { key = k, val = v } )
	end

	return result

end

--[[---------------------------------------------------------
	A Pairs function
		Sorted by VALUE
-----------------------------------------------------------]]
function SortedPairsByValue( pTable, Desc )

	local sortedTbl = hl2sb_toKeyValues( pTable )

	if ( Desc ) then
		table.sort( sortedTbl, function( a, b ) return a.val > b.val end )
	else
		table.sort( sortedTbl, function( a, b ) return a.val < b.val end )
	end

	return hl2sb_keyValuePairs, { Index = 0, KeyValues = sortedTbl }

end

--[[---------------------------------------------------------
	A Pairs function
		Sorted by Member Value (All table entries must be a table!)
-----------------------------------------------------------]]
function SortedPairsByMemberValue( pTable, pValueName, Desc )

	local sortedTbl = hl2sb_toKeyValues( pTable )

	for k, v in pairs( sortedTbl ) do
		v.member = v.val[ pValueName ]
	end

	table.SortByMember( sortedTbl, "member", !Desc )

	return hl2sb_keyValuePairs, { Index = 0, KeyValues = sortedTbl }

end

--[[---------------------------------------------------------
	A Pairs function
-----------------------------------------------------------]]
function RandomPairs( pTable, Desc )

	local sortedTbl = hl2sb_toKeyValues( pTable )

	for k, v in pairs( sortedTbl ) do
		v.rand = math.random( 1, 1000000 )
	end

	if ( Desc ) then
		table.sort( sortedTbl, function( a, b ) return a.rand > b.rand end )
	else
		table.sort( sortedTbl, function( a, b ) return a.rand < b.rand end )
	end

	return hl2sb_keyValuePairs, { Index = 0, KeyValues = sortedTbl }

end

function table.GetLastKey( t )
	local k, _ = next( t, table.Count( t ) - 1 )
	return k
end

function table.GetLastValue( t )
	local _, v = next( t, table.Count( t ) - 1 )
	return v
end

function table.FindNext( tab, val )
	local bfound = false
	for k, v in pairs( tab ) do
		if ( bfound ) then return v end
		if ( val == v ) then bfound = true end
	end

	return table.GetFirstValue( tab )
end

function table.FindPrev( tab, val )

	local last = table.GetLastValue( tab )
	for k, v in pairs( tab ) do
		if ( val == v ) then return last end
		last = v
	end

	return last

end

function table.MemberValuesFromKey( tab, key )
	local res = {}
	for k, v in pairs( tab ) do
		if ( istable( v ) and v[ key ] != nil ) then res[ #res + 1 ] = v[ key ] end
	end
	return res
end