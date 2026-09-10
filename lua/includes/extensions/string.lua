--[[---------------------------------------------------------------------------
    HL2SB string extension.

    Ported from GMod's lua/includes/extensions/string.lua, adapted to HL2SB's
    Lua 5.1.5 kernel which now carries the `continue` keyword and the `!`
    / `!=` operators (GMod/LuaJIT style), so the original GMod source loads
    almost verbatim.

    HL2SB-specific differences handled here:
      * Color is a userdata whose .r/.g/.b/.a are *methods*, not fields.
        string.FromColor therefore uses color:r():g():b():a() if those are
        functions, and falls back to field access for plain tables.
      * The global helper `Format` does not exist; use string.format.
      * isstring / isnumber are not defined; use type() checks.

    Loaded every level from lua/includes/extensions/.
------------------------------------------------------------------------------]]

local string = string
local math = math

-- Allow these, but no more
local string_sub = string.sub
local string_gsub = string.gsub
local string_len = string.len
local string_byte = string.byte

--[[---------------------------------------------------------
    Name: string.ToTable( string )
-----------------------------------------------------------]]
function string.ToTable( input )
    local tbl = {}
    local str = tostring( input )
    for i = 1, #str do
        tbl[i] = string_sub( str, i, i )
    end
    return tbl
end

--[[---------------------------------------------------------
    Name: string.JavascriptSafe( string )
-----------------------------------------------------------]]
local javascript_escape_replacements = {
    ["\\"] = "\\\\",
    ["\0"] = "\\x00" ,
    ["\b"] = "\\b" ,
    ["\t"] = "\\t" ,
    ["\n"] = "\\n" ,
    ["\v"] = "\\v" ,
    ["\f"] = "\\f" ,
    ["\r"] = "\\r" ,
    ["\""] = "\\\"",
    ["\'"] = "\\\'",
    ["`"] = "\\`",
    ["$"] = "\\$",
    ["{"] = "\\{",
    ["}"] = "\\}"
}

function string.JavascriptSafe( str )
    str = string_gsub( str, ".", javascript_escape_replacements )
    str = string_gsub( str, "\226\128\168", "\\\226\128\168" )
    str = string_gsub( str, "\226\128\169", "\\\226\128\169" )
    return str
end

--[[---------------------------------------------------------
    Name: string.PatternSafe( string )
-----------------------------------------------------------]]
local pattern_escape_replacements = {
    ["("] = "%(",
    [")"] = "%)",
    ["."] = "%.",
    ["%"] = "%%",
    ["+"] = "%+",
    ["-"] = "%-",
    ["*"] = "%*",
    ["?"] = "%?",
    ["["] = "%[",
    ["]"] = "%]",
    ["^"] = "%^",
    ["$"] = "%$",
    ["\0"] = "%z"
}

function string.PatternSafe( str )
    return ( string_gsub( str, ".", pattern_escape_replacements ) )
end

--[[---------------------------------------------------------
    Name: string.Explode( separator, string )
-----------------------------------------------------------]]
local string_ToTable = string.ToTable
local string_find = string.find
function string.Explode( separator, str, withpattern )
    if ( separator == "" ) then return string_ToTable( str ) end
    if ( withpattern == nil ) then withpattern = false end

    local ret = {}
    local current_pos = 1

    for i = 1, string_len( str ) do
        local start_pos, end_pos = string_find( str, separator, current_pos, not withpattern )
        if ( not start_pos ) then break end
        ret[ i ] = string_sub( str, current_pos, start_pos - 1 )
        current_pos = end_pos + 1
    end

    ret[ #ret + 1 ] = string_sub( str, current_pos )

    return ret
end

function string.Split( str, delimiter )
    return string.Explode( delimiter, str )
end

--[[---------------------------------------------------------
    Name: string.Implode( separator, Table )
-----------------------------------------------------------]]
function string.Implode( seperator, Table )
    return table.concat( Table, seperator )
end

--[[---------------------------------------------------------
    Name: string.GetExtensionFromFilename( path )
-----------------------------------------------------------]]
function string.GetExtensionFromFilename( path )
    for i = #path, 1, -1 do
        local c = string_byte( path, i )
        if ( c == 47 or c == 92 ) then -- Slash
            return nil
        end
        if ( c == 46 ) then -- Point
            return string_sub( path, i + 1 )
        end
    end
    return nil
end

--[[---------------------------------------------------------
    Name: string.StripExtension( path )
-----------------------------------------------------------]]
function string.StripExtension( path )
    for i = #path, 1, -1 do
        local c = string_byte( path, i )
        if ( c == 47 or c == 92 ) then -- Slash
            return path
        elseif ( c == 46 ) then -- Point
            return string_sub( path, 1, i - 1 )
        end
    end
    return path
end

--[[---------------------------------------------------------
    Name: string.GetPathFromFilename( path )
-----------------------------------------------------------]]
function string.GetPathFromFilename( path )
    for i = #path, 1, -1 do
        local c = string_byte( path, i )
        if ( c == 47 or c == 92 ) then -- Slash
            return string_sub( path, 1, i )
        end
    end
    return ""
end

--[[---------------------------------------------------------
    Name: string.GetFileFromFilename( path )
-----------------------------------------------------------]]
function string.GetFileFromFilename( path )
    for i = #path, 1, -1 do
        local c = string_byte( path, i )
        if ( c == 47 or c == 92 ) then -- Slash
            return string_sub( path, i + 1 )
        end
    end
    return path
end

--[[---------------------------------------------------------
    Name: string.FormattedTime( TimeInSeconds, Format )
-----------------------------------------------------------]]
function string.FormattedTime( seconds, format )
    if ( not seconds ) then seconds = 0 end
    local hours = math.floor( seconds / 3600 )
    local minutes = math.floor( ( seconds / 60 ) % 60 )
    local millisecs = ( seconds - math.floor( seconds ) ) * 1000
    seconds = math.floor( seconds % 60 )

    if ( format ) then
        return string.format( format, minutes, seconds, millisecs )
    else
        return { h = hours, m = minutes, s = seconds, ms = millisecs }
    end
end

function string.ToMinutesSecondsMilliseconds( TimeInSeconds ) return string.FormattedTime( TimeInSeconds, "%02i:%02i:%02i" ) end
function string.ToMinutesSeconds( TimeInSeconds ) return string.FormattedTime( TimeInSeconds, "%02i:%02i" ) end

local function pluralizeString( str, quantity )
    return str .. ( ( quantity ~= 1 ) and "s" or "" )
end

--[[---------------------------------------------------------
    Name: string.NiceTime( seconds )
-----------------------------------------------------------]]
function string.NiceTime( seconds )
    if ( seconds == nil ) then return "a few seconds" end

    if ( seconds < 60 ) then
        local t = math.floor( seconds )
        return t .. pluralizeString( " second", t )
    end
    if ( seconds < 60 * 60 ) then
        local t = math.floor( seconds / 60 )
        return t .. pluralizeString( " minute", t )
    end
    if ( seconds < 60 * 60 * 24 ) then
        local t = math.floor( seconds / (60 * 60) )
        return t .. pluralizeString( " hour", t )
    end
    if ( seconds < 60 * 60 * 24 * 7 ) then
        local t = math.floor( seconds / ( 60 * 60 * 24 ) )
        return t .. pluralizeString( " day", t )
    end
    if ( seconds < 60 * 60 * 24 * 365 ) then
        local t = math.floor( seconds / ( 60 * 60 * 24 * 7 ) )
        return t .. pluralizeString( " week", t )
    end

    local t = math.floor( seconds / ( 60 * 60 * 24 * 365 ) )
    return t .. pluralizeString( " year", t )
end

function string.Left( str, num ) return string_sub( str, 1, num ) end
function string.Right( str, num ) return string_sub( str, -num ) end

function string.Replace( str, tofind, toreplace )
    local tbl = string.Explode( tofind, str )
    if ( tbl[ 1 ] ) then return table.concat( tbl, toreplace ) end
    return str
end

--[[---------------------------------------------------------
    Name: string.Trim( s )
-----------------------------------------------------------]]
function string.Trim( s, char )
    if ( char ) then char = string.PatternSafe( char ) else char = "%s" end
    return string.match( s, "^" .. char .. "*(.-)" .. char .. "*$" ) or s
end

--[[---------------------------------------------------------
    Name: string.TrimRight( s )
-----------------------------------------------------------]]
function string.TrimRight( s, char )
    if ( char ) then char = string.PatternSafe( char ) else char = "%s" end
    return string.match( s, "^(.-)" .. char .. "*$" ) or s
end

--[[---------------------------------------------------------
    Name: string.TrimLeft( s )
-----------------------------------------------------------]]
function string.TrimLeft( s, char )
    if ( char ) then char = string.PatternSafe( char ) else char = "%s" end
    return string.match( s, "^" .. char .. "*(.-)$" ) or s
end

function string.NiceSize( size )
    size = tonumber( size )
    if ( size <= 0 ) then return "0" end
    if ( size < 1000 ) then return size .. " Bytes" end
    if ( size < 1000 * 1000 ) then return math.Round( size / 1000, 2 ) .. " KB" end
    if ( size < 1000 * 1000 * 1000 ) then return math.Round( size / ( 1000 * 1000 ), 2 ) .. " MB" end
    return math.Round( size / ( 1000 * 1000 * 1000 ), 2 ) .. " GB" end

function string.SetChar( s, k, v )
    return string_sub( s, 0, k - 1 ) .. v .. string_sub( s, k + 1 )
end

function string.GetChar( s, k )
    return string_sub( s, k, k )
end

-- allow `str[ i ]` numeric char access, like GMod
local meta = getmetatable( "" )
function meta:__index( key )
    local val = string[ key ]
    if ( val ~= nil ) then
        return val
    elseif ( tonumber( key ) ) then
        return string_sub( self, key, key )
    end
end

function string.StartsWith( str, start )
    return string_sub( str, 1, string_len( start ) ) == start
end
string.StartWith = string.StartsWith

function string.EndsWith( str, endStr )
    return endStr == "" or string_sub( str, -string_len( endStr ) ) == endStr
end

function string.FromColor( color )
    local r = type( color.r ) == "function" and color:r() or color.r
    local g = type( color.g ) == "function" and color:g() or color.g
    local b = type( color.b ) == "function" and color:b() or color.b
    local a = type( color.a ) == "function" and color:a() or color.a
    return string.format( "%i %i %i %i", r, g, b, a )
end

function string.ToColor( str )
    local r, g, b, a = string.match( str, "(%d+) (%d+) (%d+) (%d+)" )
    if ( not a ) then r, g, b = string.match( str, "(%d+) (%d+) (%d+)" ) end
    return Color( tonumber( r ) or 255, tonumber( g ) or 255, tonumber( b ) or 255, tonumber( a ) or 255 )
end

function string.Comma( number, str )
    if ( str ~= nil and type( str ) ~= "string" ) then
        error( "bad argument #2 to 'string.Comma' (string expected, got " .. type( str ) .. ")", 2 )
    elseif ( str ~= nil and string.match( str, "%d" ) ~= nil ) then
        error( "bad argument #2 to 'string.Comma' (non-numerical values expected, got " .. str .. ")", 2 )
    end

    local replace = str == nil and "%1,%2" or "%1" .. str .. "%2"

    if ( type( number ) == "number" ) then
        number = string.format( "%f", number )
        number = string.match( number, "^(.-)%.?0*$" ) -- Remove trailing zeros
    end

    local index = -1
    while index ~= 0 do number, index = string_gsub( number, "^(-?%d+)(%d%d%d)", replace ) end

    return number
end

function string.Interpolate( str, lookuptable )
    return ( string_gsub( str, "{([_%a][_%w]*)}", lookuptable ) )
end

function string.CardinalToOrdinal( cardinal )
    local basedigit = cardinal % 10
    if ( basedigit == 1 ) then
        if ( cardinal % 100 == 11 ) then
            return cardinal .. "th"
        end
        return cardinal .. "st"
    elseif ( basedigit == 2 ) then
        if ( cardinal % 100 == 12 ) then
            return cardinal .. "th"
        end
        return cardinal .. "nd"
    elseif ( basedigit == 3 ) then
        if ( cardinal % 100 == 13 ) then
            return cardinal .. "th"
        end
        return cardinal .. "rd"
    end
    return cardinal .. "th"
end

function string.NiceName( name )
    name = name:Replace( "_", " " )

    -- Try to split text into words, where words would start with single uppercase character
    local newParts = {}
    for id, str in ipairs( string.Explode( " ", name ) ) do
        local wordStart = 1
        for i = 2, str:len() do
            local c = string.GetChar( str, i )
            if ( c:upper() == c ) then
                local toAdd = str:sub( wordStart, i - 1 )
                if ( toAdd:upper() == toAdd ) then continue end
                table.insert( newParts, toAdd )
                wordStart = i
            end
        end
        table.insert( newParts, str:sub( wordStart, str:len() ) )
    end

    local ret = table.concat( newParts, " " )
    ret = string.upper( string_sub( ret, 1, 1 ) ) .. string_sub( ret, 2 )
    return ret
end

print( "[HL2SB] string extension loaded" )
