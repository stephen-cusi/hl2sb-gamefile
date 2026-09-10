--[[---------------------------------------------------------------------------
    HL2SB net extension (GMod-compatible sugar).

    Sits on top of the engine `net` library (game/shared/lua/lnet.cpp), which
    provides the primitives net.Start / net.WriteInt/UInt/String/Bit/Float/
    Double/Vector/Angle/Entity / net.Send / net.Broadcast (server) and
    net.Receive / net.ReadInt/UInt/String/Bit/Float/Double/Vector/Angle/Entity
    / ReadHeader (client).

    This file adds the GMod-style helpers that are pure Lua: WriteBool/ReadBool,
    WriteColor/ReadColor, WriteEntity/ReadEntity, WritePlayer/ReadPlayer,
    WriteType/ReadType, WriteTable/ReadTable.  GMod-only global type predicates
    (istable/isstring/isnumber/IsColor) are replaced with type() checks.

    Loaded every level from lua/includes/extensions/.
-----------------------------------------------------------------------------]]

local net = net
local type = type
local tostring = tostring

-- net.Receivers map (recreated by the engine lib).
net.Receivers = net.Receivers or {}

--[[---------------------------------------------------------
    WriteBool / ReadBool
-----------------------------------------------------------]]
net.WriteBool = net.WriteBit
function net.ReadBool()
    return net.ReadBit() == 1
end

--[[---------------------------------------------------------
    WriteEntity / ReadEntity (index as a signed short)
-----------------------------------------------------------]]
function net.WriteEntity( ent )
    net.WriteInt( IsValid( ent ) and ent:entindex() or 0 )
end

function net.ReadEntity()
    local i = net.ReadInt()
    if not i or i <= 0 then return nil end
    return ents and ents.GetByIndex and ents.GetByIndex( i ) or nil
end

--[[---------------------------------------------------------
    WriteColor / ReadColor (r,g,b,a bytes)
-----------------------------------------------------------]]
function net.WriteColor( col, writeAlpha )
    if writeAlpha == nil then writeAlpha = true end

    local r, g, b, a
    if type( col.r ) == "function" then
        r, g, b, a = col.r, col.g, col.b, col.a
    else
        r, g, b, a = col.r, col.g, col.b, col.a
    end

    net.WriteUInt( r or 255, 8 )
    net.WriteUInt( g or 255, 8 )
    net.WriteUInt( b or 255, 8 )
    if writeAlpha then
        net.WriteUInt( a or 255, 8 )
    end
end

function net.ReadColor( readAlpha )
    if readAlpha == nil then readAlpha = true end

    local r = net.ReadUInt( 8 )
    local g = net.ReadUInt( 8 )
    local b = net.ReadUInt( 8 )
    local a = readAlpha and net.ReadUInt( 8 ) or 255

    return Color( r, g, b, a )
end

--[[---------------------------------------------------------
    WritePlayer / ReadPlayer (via WriteUInt/ReadUInt with MAX_PLAYER_BITS)
-----------------------------------------------------------]]
local MAX_PLAYER_BITS = 10
function net.WritePlayer( ply )
    net.WriteUInt( ( IsValid( ply ) and ply:IsPlayer() and ply:entindex() ) or 0, MAX_PLAYER_BITS )
end

function net.ReadPlayer()
    local i = net.ReadUInt( MAX_PLAYER_BITS )
    if i <= 0 then return nil end
    return ents and ents.GetByIndex and ents.GetByIndex( i ) or nil
end

--[[---------------------------------------------------------
    Type tags (mirror GMod's TypeID values for the common types)
-----------------------------------------------------------]]
local TYPE_NIL     = 0
local TYPE_STRING  = 1
local TYPE_NUMBER  = 2
local TYPE_TABLE   = 3
local TYPE_BOOL    = 4
local TYPE_ENTITY  = 5
local TYPE_VECTOR  = 6
local TYPE_ANGLE   = 7
local TYPE_COLOR   = 255

local function TypeID( v )
    local tv = type( v )
    if tv == "nil" then return TYPE_NIL end
    if tv == "string" then return TYPE_STRING end
    if tv == "number" then return TYPE_NUMBER end
    if tv == "boolean" then return TYPE_BOOL end
    if tv == "table" then return TYPE_TABLE end
    if tv == "userdata" then
        -- entity / vector / angle / color userdata are distinguishable via
        -- their metatable; treat anything else as nil-ish for safety.
        return TYPE_ENTITY
    end
    return TYPE_NIL
end

local function IsColor( v )
    return type( v ) == "userdata" and getmetatable( v ) ~= nil and type( v.r ) == "function"
end

net.WriteVars = {
    [TYPE_NIL]     = function( t, v ) net.WriteUInt( t, 8 ) end,
    [TYPE_STRING]  = function( t, v ) net.WriteUInt( t, 8 ) net.WriteString( v ) end,
    [TYPE_NUMBER]  = function( t, v ) net.WriteUInt( t, 8 ) net.WriteDouble( v ) end,
    [TYPE_TABLE]   = function( t, v ) net.WriteUInt( t, 8 ) net.WriteTable( v ) end,
    [TYPE_BOOL]    = function( t, v ) net.WriteUInt( t, 8 ) net.WriteBool( v ) end,
    [TYPE_ENTITY]  = function( t, v ) net.WriteUInt( t, 8 ) net.WriteEntity( v ) end,
    [TYPE_VECTOR]  = function( t, v ) net.WriteUInt( t, 8 ) net.WriteVector( v ) end,
    [TYPE_ANGLE]   = function( t, v ) net.WriteUInt( t, 8 ) net.WriteAngle( v ) end,
    [TYPE_COLOR]   = function( t, v ) net.WriteUInt( t, 8 ) net.WriteColor( v ) end,
}

function net.WriteType( v )
    local typeid = IsColor( v ) and TYPE_COLOR or TypeID( v )
    local wv = net.WriteVars[ typeid ]
    if wv then return wv( typeid, v ) end
    error( "net.WriteType: Couldn't write " .. type( v ) .. " (type " .. tostring( typeid ) .. ")" )
end

net.ReadVars = {
    [TYPE_NIL]    = function() return nil end,
    [TYPE_STRING] = function() return net.ReadString() end,
    [TYPE_NUMBER] = function() return net.ReadDouble() end,
    [TYPE_TABLE]  = function() return net.ReadTable() end,
    [TYPE_BOOL]   = function() return net.ReadBool() end,
    [TYPE_ENTITY] = function() return net.ReadEntity() end,
    [TYPE_VECTOR] = function() return net.ReadVector() end,
    [TYPE_ANGLE]  = function() return net.ReadAngle() end,
    [TYPE_COLOR]  = function() return net.ReadColor() end,
}

function net.ReadType( typeid )
    typeid = typeid or net.ReadUInt( 8 )
    local rv = net.ReadVars[ typeid ]
    if rv then return rv() end
    error( "net.ReadType: Couldn't read type " .. tostring( typeid ) )
end

--[[---------------------------------------------------------
    WriteTable / ReadTable
-----------------------------------------------------------]]
local function HasCyclicReferences( tab )
    local function check( t, visited )
        if visited[ t ] then return true end
        visited[ t ] = true
        for k, v in pairs( t ) do
            if type( k ) == "table" then
                if check( k, visited ) then return true end
            end
            if type( v ) == "table" then
                if check( v, visited ) then return true end
            end
        end
        visited[ t ] = nil
        return false
    end
    return check( tab, {} )
end

function net.WriteTable( tab, seq )
    if HasCyclicReferences( tab ) then
        error( "net.WriteTable: Cyclic table detected.", 2 )
    end

    if seq then
        local len = #tab
        net.WriteUInt( len, 32 )
        for i = 1, len do
            net.WriteType( tab[ i ] )
        end
    else
        for k, v in pairs( tab ) do
            net.WriteType( k )
            net.WriteType( v )
        end
        net.WriteType( nil )
    end
end

function net.ReadTable( seq )
    local tab = {}
    if seq then
        for i = 1, net.ReadUInt( 32 ) do
            tab[ i ] = net.ReadType()
        end
    else
        while true do
            local k = net.ReadType()
            if k == nil then break end
            tab[ k ] = net.ReadType()
        end
    end
    return tab
end

print( "[HL2SB] net extension loaded" )
