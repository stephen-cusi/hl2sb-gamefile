-- HL2SB probe for GMod's save-table trio.  TEMP file, not shipped.
--   client:  lua_dofile_cl hl2sb_save_probe.lua
--   server:  lua_dofile    hl2sb_save_probe.lua
-- (the command prepends lua/ but does NOT append .lua)

local realm = ( SERVER and "SERVER" ) or ( CLIENT and "CLIENT" ) or "?"
local function say( ... )
	local t = { ... }
	for i = 1, #t do t[i] = tostring( t[i] ) end
	print( "[" .. realm .. "] " .. table.concat( t, " " ) )
end

local function firstEntity()
	if ( CLIENT && LocalPlayer ) then
		local ok, p = pcall( LocalPlayer )
		if ( ok && IsValid( p ) ) then return p end
	end
	-- Entity(1) is the first player on BOTH realms.  Do NOT start at 0: that is
	-- worldspawn, which refuses a health write and made the trio look broken.
	if ( Entity ) then
		local ok, e = pcall( Entity, 1 )
		if ( ok && IsValid( e ) ) then return e end
	end
	if ( ents && ents.GetByIndex ) then
		local ok, e = pcall( function() return ents.GetByIndex( 1 ) end )
		if ( ok && IsValid( e ) ) then return e end
	end
	return nil
end

local ent = firstEntity()
if ( !IsValid( ent ) ) then say( "no entity to probe" ) return end
say( "probing:", ent:GetClass(), "index", ent:EntIndex() )

-- 1. GetSaveTable
local okT, tbl = pcall( function() return ent:GetSaveTable() end )
if ( !okT or type( tbl ) ~= "table" ) then
	say( "GetSaveTable FAILED:", tbl )
else
	local n = 0
	for k in pairs( tbl ) do n = n + 1 end
	say( "GetSaveTable keys =", n )
	for _, key in ipairs( { "m_iHealth", "m_vecOrigin", "m_fFlags", "m_iClassname", "m_MoveType", "m_hOwner" } ) do
		local v = tbl[ key ]
		say( "  table", key, "=", type( v ) == "table" and "Vector/Angle" or v, "(type " .. type( v ) .. ")" )
	end
end

-- 2. GetInternalVariable, and agreement with the normal getters
for _, key in ipairs( { "m_iHealth", "m_vecOrigin", "m_fFlags", "m_iClassname", "m_nopeDoesNotExist" } ) do
	local okV, v = pcall( function() return ent:GetInternalVariable( key ) end )
	say( "GetInternalVariable", key, "->", okV and tostring( v ) or ( "ERROR " .. tostring( v ) ) )
end
say( "Health() =", ent:Health(), " (compare with m_iHealth above)" )

-- 3. SetSaveValue: a real write, then prove it landed both ways
local okS, r = pcall( function() return ent:SetSaveValue( "m_iHealth", 55 ) end )
say( "SetSaveValue(m_iHealth,55) ->", okS and tostring( r ) or ( "ERROR " .. tostring( r ) ) )
local okR, back = pcall( function() return ent:GetInternalVariable( "m_iHealth" ) end )
say( "  re-read via GetInternalVariable:", okR and back or ("ERROR " .. tostring( back )),
	" via Health():", ent:Health() )

-- 4. refusals: unknown name, wrong-typed value, nil value
for _, case in ipairs( { { "m_no_such_field", 1 }, { "m_iHealth", "not-a-number" }, { "m_iHealth", nil } } ) do
	local okC, res = pcall( function() return ent:SetSaveValue( case[ 1 ], case[ 2 ] ) end )
	say( "SetSaveValue(" .. case[ 1 ] .. ", " .. tostring( case[ 2 ] ) .. ") ->",
		okC and tostring( res ) or ( "ERROR " .. tostring( res ) ) )
end
say( "health after the refusal cases:", ent:Health() )
