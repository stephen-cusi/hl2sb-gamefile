-- HL2SB ConVar-linkage in-game probe.
-- Run from the console:   lua_dofile_cl hl2sb_convar_probe.lua
-- (lua_dofile_cl prefixes lua/ itself, so do NOT type lua/ here.)

-- Use a convar that always exists on the client and is freely settable.
local name = "m_pitch"
local cv = GetConVar( name )
if ( not cv ) then
	print( "[convar-probe] RESULT: SKIP - GetConVar('" .. name .. "') is nil (pick another cvar)" )
	return
end

local original = cv:GetString()
local fired, lastOld, lastNew = 0, nil, nil

print( "[convar-probe] cvars table present = " .. tostring( istable( cvars ) )
	.. "  AddChangeCallback = " .. tostring( cvars and cvars.AddChangeCallback ) )

cvars.AddChangeCallback( name, function( cvarName, old, new )
	fired = fired + 1
	lastOld, lastNew = old, new
	print( "[convar-probe] FIRED: name=" .. tostring( cvarName )
		.. " old=" .. tostring( old ) .. " new=" .. tostring( new )
		.. "  (both string? " .. tostring( type( old ) == "string" and type( new ) == "string" ) .. ")" )
end, "hl2sb_probe" )

-- a value guaranteed to differ from m_pitch's default
local target = ( original == "0.45" ) and "0.46" or "0.45"
print( "[convar-probe] current=" .. tostring( original ) .. "  -> SetString('" .. target .. "')" )
cv:SetString( target )

print( "[convar-probe] after: value=" .. tostring( cv:GetString() )
	.. "  fired=" .. fired .. "  lastNew=" .. tostring( lastNew ) )

if ( fired >= 1 and lastNew == target ) then
	print( "[convar-probe] RESULT: PASS - engine bridge reached cvars.OnConVarChanged" )
else
	print( "[convar-probe] RESULT: FAIL - callback did NOT fire (fired=" .. fired .. ")" )
end

cvars.RemoveChangeCallback( name, "hl2sb_probe" )
cv:SetString( original )   -- restore
