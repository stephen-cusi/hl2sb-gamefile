--[[---------------------------------------------------------------------------
    luaerror_lib_test.lua - tests for the GMod error hook + RunString globals.

    How to run (in a map, with the console):
        lua_dofile_cl luaerror_lib_test.lua    (client realm)
        lua_dofile    luaerror_lib_test.lua    (server realm)

    Covers:
      PART 1  RunString / RunStringEx globals (GMod core semantics)
      PART 2  GM:OnLuaError hook (5 args: error, realm, stack, name, id)
      PART 3  the legacy "LuaError" hook still carries (msg, trace, realm, addon)

    Every check prints [LUERRTEST] PASS/FAIL with the label; a summary line at
    the end counts them.
-----------------------------------------------------------------------------]]

local PASS, FAIL = 0, 0
local function ok( cond, label )
    if ( cond ) then
        PASS = PASS + 1
        print( "[LUERRTEST] PASS  " .. label )
    else
        FAIL = FAIL + 1
        print( "[LUERRTEST] FAIL  " .. label )
    end
end

local realm = SERVER and "server" or "client"

print( "[LUERRTEST] ===== luaerror_lib_test (" .. realm .. ") =====" )

-- ---------------------------------------------------------------------------
-- PART 1: RunString / RunStringEx
-- ---------------------------------------------------------------------------
ok( type( RunString ) == "function", "RunString is a global function" )
ok( type( RunStringEx ) == "function", "RunStringEx is a global function" )

-- It should run code and see side effects.
local ran = false
RunString( "LUERRTEST_SIDE = true", "luaerror_test" )
ok( LUERRTEST_SIDE == true, "RunString ran the code (side effect visible)" )
LUERRTEST_SIDE = nil

-- GLua dialect: // comment and != must work through RunString like a file.
local dialectOK = pcall( RunString, "local x = 1 // trailing comment\nLUERRTEST_D = (x != 2)", "luaerror_test" )
ok( dialectOK and LUERRTEST_D == true, "RunString accepts the GLua dialect (// and !=)" )
LUERRTEST_D = nil

-- A handled runtime error returns without throwing; an error is reported.
local threw = false
local okCall = pcall( RunString, "error('LUERRTEST deliberate')", "luaerror_test" )
ok( okCall == true, "RunString handles an error internally (no throw to the caller)" )

-- handleError=false must re-raise.
local threw2 = not pcall( RunString, "error('LUERRTEST deliberate2')", "luaerror_test", false )
ok( threw2, "RunString(..., handleError=false) re-raises the error" )

-- ---------------------------------------------------------------------------
-- PART 2: OnLuaError (GMod shape)
-- ---------------------------------------------------------------------------
local got = nil
hook.Add( "OnLuaError", "luaerror_test_probe", function( err, rlm, stack, name, id )
    got = { err = err, realm = rlm, stack = stack, name = name, id = id }
end )

-- Trigger an error somewhere the engine reports it (a concommand body via
-- RunString with handleError=false throws into pcall, which is not the engine
-- report path; use lua_run-style: RunString reports handled errors itself).
RunString( "local t = nil\nreturn t.field", "luaerror_test_realm" )

ok( got ~= nil, "OnLuaError fired" )
if ( got ) then
    ok( type( got.err ) == "string" and #got.err > 0, "OnLuaError arg1 = error string" )
    ok( got.realm == realm, "OnLuaError arg2 = realm string ('" .. tostring( got.realm ) .. "')" )
    ok( type( got.stack ) == "table", "OnLuaError arg3 = stack table" )
    ok( got.name == nil or type( got.name ) == "string", "OnLuaError arg4 = addon name or nil" )
    ok( got.id == nil, "OnLuaError arg5 = id (nil in this fork)" )
    -- The stack should carry at least one frame table with File/Line.
    local frame = nil
    if ( type( got.stack ) == "table" ) then frame = got.stack[ 1 ] end
    ok( type( frame ) == "table", "OnLuaError stack has a frame table" )
    if ( type( frame ) == "table" ) then
        ok( frame.File ~= nil, "stack frame has File" )
        ok( frame.Line ~= nil, "stack frame has Line" )
    end
end

hook.Remove( "OnLuaError", "luaerror_test_probe" )

-- ---------------------------------------------------------------------------
-- PART 3: legacy LuaError hook still works (backwards compatible extras)
-- ---------------------------------------------------------------------------
local legacy = nil
hook.Add( "LuaError", "luaerror_test_legacy", function( msg, trace, rlm, addon )
    legacy = { msg = msg, trace = trace, realm = rlm, addon = addon }
end )

RunString( "local q = nil\nreturn q.x", "luaerror_test_legacy" )

ok( legacy ~= nil, "legacy LuaError hook fired" )
if ( legacy ) then
    ok( type( legacy.msg ) == "string", "LuaError arg1 = message" )
    ok( type( legacy.trace ) == "string", "LuaError arg2 = traceback" )
    ok( legacy.realm == realm, "LuaError arg3 = realm (added)" )
end

hook.Remove( "LuaError", "luaerror_test_legacy" )

-- ---------------------------------------------------------------------------
-- PART 4: a hook-callback crash must ALSO fire OnLuaError (GMod parity)
-- ---------------------------------------------------------------------------
local hookCrash = nil
hook.Add( "OnLuaError", "luaerror_test_hookcrash", function( err, rlm, stack, name, id )
    hookCrash = { err = err, realm = rlm }
end )

-- This hook throws when it runs; hook.lua reports it through
-- hl2sb_reportluaerror, which must reach the same hook dispatcher.
hook.Add( "LUERRTEST_Boom", "luaerror_test_boom", function()
    error( "LUERRTEST hook crash" )
end )
hook.Run( "LUERRTEST_Boom" )

ok( hookCrash ~= nil, "OnLuaError fired for a hook-callback crash" )
if ( hookCrash ) then
    ok( string.find( tostring( hookCrash.err ), "LUERRTEST hook crash", 1, true ) ~= nil,
        "hook-crash error text reached OnLuaError" )
end

hook.Remove( "OnLuaError", "luaerror_test_hookcrash" )
hook.Remove( "LUERRTEST_Boom", "luaerror_test_boom" )

print( string.format( "[LUERRTEST] ===== done: %d passed, %d failed =====", PASS, FAIL ) )
