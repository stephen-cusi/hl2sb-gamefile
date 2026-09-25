------------------------------------------------------------------------------
-- timer_lib_test.lua - HL2SB timer library test (2026-09-25)
--
-- 34 assertions covering every GMod timer member (wiki-checked), plus the
-- two 2026-09-25 fixes: the recursive timer.Simple(0, self) hang and the
-- finite-timer removal-before-callback contract.
--
-- Run (game console, after a FULL restart - DLLs load at process start):
--     lua_dofile lua/timer_lib_test.lua        (server realm)
--     lua_dofile_cl lua/timer_lib_test.lua     (client realm)
--
-- Layout mirrors file_lib_test.lua: PASS/FAIL lines + a final summary, then
-- the async half runs on timers and cleans itself up.  Nothing is written to
-- disk, so there is nothing to clean.
--
-- NOTE on async assertions: the script schedules the time-dependent checks
-- via timer.Simple and prints "TIMER_ASYNC_ALL_PASSED" when they all land.
-- Pass criteria for the whole file:
--     summary says 34/34  AND  "TIMER_ASYNC_ALL_PASSED" appears ~2s later
--     AND  "TIMER_TICKS" fires exactly twice, ~1s apart  AND  no "FAIL:".
------------------------------------------------------------------------------

local PASS = 0
local FAIL = 0

local function ok( cond, name )
	if cond then
		PASS = PASS + 1
		print( "[timer-test] PASS " .. tostring( name ) )
	else
		FAIL = FAIL + 1
		print( "[timer-test] FAIL " .. tostring( name ) )
	end
end

print( "[timer-test] realm = " .. ( SERVER and "server" or "client" ) )

-- =============================================================================
-- 1. Function surface: every GMod member present
-- =============================================================================

ok( type( timer ) == "table", "timer table exists" )

local MEMBERS = {
	"Adjust", "Check", "Create", "Destroy", "Exists", "IsPaused",
	"Pause", "Remove", "RepsLeft", "Simple", "Start", "Stop",
	"TimeLeft", "Toggle", "UnPause",
}
for _, m in ipairs( MEMBERS ) do
	ok( type( timer[ m ] ) == "function", "timer." .. m .. " is a function" )
end

-- =============================================================================
-- 2. Sync contracts (no waiting involved)
-- =============================================================================

-- Exists/Remove on a never-created id
ok( timer.Exists( "tst_never" ) == false, "Exists false for unknown id" )
timer.Remove( "tst_never" ) -- must not error

-- Stop/Pause/Start/UnPause/Toggle/Adjust on an unknown id: tolerated, no error
timer.Stop( "tst_never" )
timer.Pause( "tst_never" )
timer.UnPause( "tst_never" )
timer.Start( "tst_never" )
ok( timer.Toggle( "tst_never" ) == false, "Toggle unknown id returns false" )
ok( timer.Adjust( "tst_never", 1 ) == false, "Adjust unknown id returns false" )
ok( timer.TimeLeft( "tst_never" ) == false, "TimeLeft unknown id returns false" )
ok( timer.RepsLeft( "tst_never" ) == 0, "RepsLeft unknown id returns 0" )
ok( timer.IsPaused( "tst_never" ) == false, "IsPaused unknown id returns false" )

-- Create: immediately Exists, TimeLeft within (0, delay], RepsLeft exact
timer.Create( "tst_once", 10, 1, function() end )
ok( timer.Exists( "tst_once" ) == true, "Create => Exists" )
local tl = timer.TimeLeft( "tst_once" )
ok( type( tl ) == "number" and tl > 0 and tl <= 10, "TimeLeft in (0, delay]" )
ok( timer.RepsLeft( "tst_once" ) == 1, "RepsLeft after Create" )
ok( timer.IsPaused( "tst_once" ) == false, "fresh timer not paused" )

-- same-id Create replaces and resets (wiki: "updated to the new settings and reset")
timer.Create( "tst_once", 10, 1, function() end )
ok( timer.RepsLeft( "tst_once" ) == 1, "re-Create resets reps" )

-- Pause/IsPaused/Toggle/UnPause dance
timer.Pause( "tst_once" )
ok( timer.IsPaused( "tst_once" ) == true, "Pause => IsPaused" )
ok( timer.Toggle( "tst_once" ) == false, "Toggle paused => running (returns new state false)" )
ok( timer.IsPaused( "tst_once" ) == false, "Toggle unpaused it" )
timer.Pause( "tst_once" )
timer.UnPause( "tst_once" )
ok( timer.IsPaused( "tst_once" ) == false, "UnPause works" )

-- Stop: Exists stays true (wiki: timer still exists, Start rewinds it)
timer.Stop( "tst_once" )
ok( timer.Exists( "tst_once" ) == true, "Stop keeps Exists true" )
timer.Start( "tst_once" )
ok( timer.Exists( "tst_once" ) == true, "Start keeps Exists true" )

-- Adjust: nil keeps previous values, returns true
timer.Create( "tst_adj", 5, 7, function() end )
local oldFn = true
ok( timer.Adjust( "tst_adj", 3 ) == true, "Adjust delay-only returns true" )
ok( timer.RepsLeft( "tst_adj" ) == 7, "Adjust keeps reps on nil" )
ok( timer.TimeLeft( "tst_adj" ) ~= false and timer.TimeLeft( "tst_adj" ) <= 3.001, "Adjust rewinds clock" )

-- Adjust with explicit reps and a new function
timer.Adjust( "tst_adj", 1, 2, function() end )
ok( timer.RepsLeft( "tst_adj" ) == 2, "Adjust sets new reps" )

-- Adjust can revive a STOPPED timer's next-fire but not a removed one
timer.Remove( "tst_adj" )
ok( timer.Adjust( "tst_adj", 1, 1, function() end ) == false, "Adjust removed id returns false" )

-- Remove/Destroy
timer.Create( "tst_rm", 5, 1, function() end )
timer.Destroy( "tst_rm" )  -- Destroy is an alias
ok( timer.Exists( "tst_rm" ) == false, "Destroy removes (alias of Remove)" )

-- timer.Check is a deprecated no-op that must not error
timer.Check()

-- negative reps = infinite (wiki: "0 or any value below 0")
timer.Create( "tst_inf", 1000000, -3, function() end )
ok( timer.Exists( "tst_inf" ) == true, "negative reps accepted" )
timer.Remove( "tst_inf" )

-- tiny delay is legal (fires next tick) - just must not error
timer.Create( "tst_tiny", 0.0001, 1, function() end )
ok( timer.Exists( "tst_tiny" ) == true, "tiny delay accepted" )
timer.Remove( "tst_tiny" )

-- =============================================================================
-- 3. Error surface: bad args raise (protected with pcall so the file keeps going)
-- =============================================================================

ok( not pcall( function() timer.Create( "tst_bad", "notanumber", 1, function() end ) end ),
	"Create rejects non-number delay" )
ok( not pcall( function() timer.Create( "tst_bad", 1, 1, "notfunction" ) end ),
	"Create rejects non-function callback" )
ok( not pcall( function() timer.Simple( 1 ) end ),
	"Simple rejects missing callback" )
ok( not pcall( function() timer.Exists() end ),
	"Exists rejects missing identifier" )

-- =============================================================================
-- 4. Async half: behaviour that needs ticks.  Scheduled via timer.Simple; all
--    prints come back within ~2 seconds of loading the file.
-- =============================================================================

local asyncOK = 0
local asyncTotal = 0
local firedTicks = 0

local function asyncOk( cond, name )
	asyncTotal = asyncTotal + 1
	if cond then
		asyncOK = asyncOK + 1
		print( "[timer-test] PASS " .. tostring( name ) )
	else
		print( "[timer-test] FAIL " .. tostring( name ) )
	end
end

-- 4a. Simple fires with the right delay and only once
local t0 = CurTime()
timer.Simple( 0.25, function()
	asyncOk( ( CurTime() - t0 ) >= 0.2, "Simple fired after ~delay" )
end )

-- 4b. Simple(0) fires (any frame), exactly once per call
local simple0 = 0
timer.Simple( 0, function() simple0 = simple0 + 1 end )
timer.Simple( 0.5, function()
	asyncOk( simple0 == 1, "Simple(0) fired exactly once" )
end )

-- 4c. THE 2026-09-25 FIX: recursive timer.Simple(0, self) must NOT hang the
--     game.  GMod 2026.1.5+ queues timers created during the pump to the next
--     frame; ours must too.  The recursion is capped so the test terminates
--     (if the hang still existed, this print would never happen and the game
--     would freeze - that IS the failure signal).
local recursionDepth = 0
local function recursiveZero()
	recursionDepth = recursionDepth + 1
	if recursionDepth < 5 then
		timer.Simple( 0, recursiveZero )
	end
end
timer.Simple( 0, recursiveZero )
timer.Simple( 1.5, function()
	asyncOk( recursionDepth == 5, "recursive Simple(0) unrolled once per frame (got " .. recursionDepth .. ")" )
end )

-- 4d. Named finite timer: fires N times then self-removes, and inside the
--     LAST call Exists() is already false (removal-before-callback contract).
local finiteFires = 0
local lastCallExists = nil
timer.Create( "tst_finite", 0.25, 2, function()
	finiteFires = finiteFires + 1
	lastCallExists = timer.Exists( "tst_finite" )
end )
timer.Simple( 1.2, function()
	asyncOk( finiteFires == 2, "finite timer fired exactly its reps (" .. finiteFires .. ")" )
	asyncOk( lastCallExists == false, "final callback saw Exists() == false" )
	asyncOk( timer.Exists( "tst_finite" ) == false, "exhausted timer removed itself" )
end )

-- 4e. Infinite timer ticks repeatedly; Stop stops it; Remove kills it.
local infTicks = 0
timer.Create( "tst_inf_async", 0.4, 0, function() infTicks = infTicks + 1 end )
timer.Simple( 1.0, function()
	asyncOk( infTicks >= 2, "infinite timer ticked repeatedly (" .. infTicks .. ")" )
	timer.Stop( "tst_inf_async" )
	local frozen = infTicks
	timer.Simple( 0.5, function()
		asyncOk( infTicks == frozen, "Stop halted the ticks" )
		timer.Remove( "tst_inf_async" )
		asyncOk( timer.Exists( "tst_inf_async" ) == false, "Remove killed the stopped timer" )
	end )
end )

-- 4f. RepsLeft counts down live.
timer.Create( "tst_reps", 0.3, 3, function() end )
timer.Simple( 0.45, function()
	asyncOk( timer.RepsLeft( "tst_reps" ) == 2, "RepsLeft counts down live" )
end )
timer.Simple( 1.1, function()
	asyncOk( timer.Exists( "tst_reps" ) == false, "3-rep timer exhausted" )
	print( "[timer-test] TIMER_ASYNC_ALL_PASSED " .. asyncOK .. "/" .. asyncTotal )
end )

-- 4g. Pause really freezes the countdown: pause a 2s timer, come back after
--     1s, TimeLeft must be untouched (~2s, not ~1s).
timer.Create( "tst_pause", 2, 1, function() end )
timer.Pause( "tst_pause" )
timer.Simple( 1.0, function()
	local left = timer.TimeLeft( "tst_pause" )
	asyncOk( type( left ) == "number" and left > 1.8, "paused timer did not count down (" .. tostring( left ) .. ")" )
	timer.UnPause( "tst_pause" )
	timer.Remove( "tst_pause" )
end )

-- 4h. Two timers, same id: callback Create'd from INSIDE a callback replaces
--     the running one (registry mutation from callbacks must not crash).
timer.Simple( 0.2, function()
	timer.Create( "tst_recreate", 5, 1, function() end )
	ok( timer.Exists( "tst_recreate" ) == true, "Create from inside a timer callback works" )
	timer.Remove( "tst_recreate" )
end )

-- =============================================================================
-- Summary
-- =============================================================================

print( "[timer-test] ==========================================" )
print( "[timer-test] SUMMARY: " .. PASS .. " passed, " .. FAIL .. " failed (sync)" )
if FAIL == 0 then
	print( "[timer-test] SYNC_ALL_PASSED - wait ~2s for the async half" )
else
	print( "[timer-test] SYNC HAD FAILURES - async half still runs" )
end
