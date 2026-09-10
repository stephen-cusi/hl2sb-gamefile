--========== HL2SB - GMod compat ==========--
--
-- Purpose: Timer library (GMod API).
--
--   GMod implements timer.* in C++; HL2SB does not have it at all, so this is a
--   pure Lua implementation driven by the engine's per-frame hooks:
--     server -> the "Think" gamemode hook
--     client -> the "HudViewportPaint" hook
--
--   Same surface as GMod: Create / Remove / Exists / Simple / Start / Stop /
--   Pause / UnPause / Adjust / TimeLeft / RepsLeft / Persistence.
--
--===========================================================================--

module( "timer", package.seeall )

local timers = {}

local function Now()
	if ( _G.CurTime ~= nil ) then return CurTime() end
	if ( gpGlobals ~= nil and gpGlobals.curtime ~= nil ) then return gpGlobals.curtime() end
	return 0
end

local function Warn( msg )
	if ( dbg ~= nil and dbg.Warning ~= nil ) then
		dbg.Warning( "[timer] " .. tostring( msg ) .. "\n" )
	end
end

local function New( id, delay, reps, fn )
	timers[ id ] = {
		delay    = delay,
		reps     = reps,
		func     = fn,
		next     = Now() + delay,
		running  = true,
		paused   = false,
	}
end

-------------------------------------------------------------------------------
-- Purpose: Creates a timer
-- Input  : identifier  - unique name
--          delay       - seconds between calls
--          repetitions - number of calls; 0 means forever
--          func        - callback
-------------------------------------------------------------------------------
function Create( identifier, delay, repetitions, func )
	if ( type( identifier ) ~= "string" or identifier == "" ) then
		Warn( "Create needs a non-empty identifier" )
		return
	end

	delay       = tonumber( delay ) or 0
	repetitions = tonumber( repetitions ) or 0

	if ( type( func ) ~= "function" ) then
		Warn( "Create('" .. identifier .. "') needs a function" )
		return
	end

	New( identifier, delay, repetitions, func )
end

-------------------------------------------------------------------------------
-- Purpose: Creates a one-shot timer
-------------------------------------------------------------------------------
function Simple( delay, func )
	if ( type( func ) ~= "function" ) then return end

	-- Unique enough for script use.
	local id = "hl2sb_simple_" .. tostring( Now() ) .. "_" .. tostring( math.random( 1, 1e6 ) )
	New( id, tonumber( delay ) or 0, 1, func )
end

-------------------------------------------------------------------------------
-- Purpose: Removes a timer
-------------------------------------------------------------------------------
function Remove( identifier )
	timers[ identifier ] = nil
end

-------------------------------------------------------------------------------
-- Purpose: True when the timer exists
-------------------------------------------------------------------------------
function Exists( identifier )
	return timers[ identifier ] ~= nil
end

function Start( identifier )
	local t = timers[ identifier ]
	if ( t == nil ) then return end

	t.running = true
	t.paused  = false
	t.next    = Now() + t.delay
end

function Stop( identifier )
	local t = timers[ identifier ]
	if ( t == nil ) then return end

	t.running = false
end

function Pause( identifier )
	local t = timers[ identifier ]
	if ( t == nil ) then return end

	t.paused = true
end

function UnPause( identifier )
	local t = timers[ identifier ]
	if ( t == nil ) then return end

	t.paused = false
	t.next   = Now() + t.delay
end

-------------------------------------------------------------------------------
-- Purpose: Changes delay / repetitions of a running timer
-------------------------------------------------------------------------------
function Adjust( identifier, delay, repetitions )
	local t = timers[ identifier ]
	if ( t == nil ) then return end

	if ( delay ~= nil ) then t.delay = tonumber( delay ) or t.delay end
	if ( repetitions ~= nil ) then t.reps = tonumber( repetitions ) or t.reps end

	t.next = Now() + t.delay
end

function TimeLeft( identifier )
	local t = timers[ identifier ]
	if ( t == nil ) then return 0 end

	local left = t.next - Now()
	if ( left < 0 ) then left = 0 end
	return left
end

function RepsLeft( identifier )
	local t = timers[ identifier ]
	if ( t == nil ) then return 0 end

	return t.reps
end

-------------------------------------------------------------------------------
-- Purpose: Per-frame driver. Registered on whichever hook this realm has.
-------------------------------------------------------------------------------
local function Tick()
	local now = Now()

	-- Snapshot first: a callback is allowed to create/remove timers.
	local fire = nil

	for id, t in pairs( timers ) do
		if ( t.running and not t.paused and now >= t.next ) then
			fire = fire or {}
			fire[ #fire + 1 ] = id
		end
	end

	if ( fire == nil ) then return end

	for i = 1, #fire do
		local id = fire[ i ]
		local t  = timers[ id ]
		if ( t ~= nil ) then
			if ( t.reps > 0 ) then
				t.reps = t.reps - 1
			end

			t.next = now + t.delay

			local last = ( t.reps == 0 )

			if ( last ) then
				timers[ id ] = nil
			end

			local ok, err = pcall( t.func )
			if ( not ok ) then
				Warn( "timer '" .. id .. "' failed: " .. tostring( err ) )
				timers[ id ] = nil
			end
		end
	end
end

if ( _G.hook ~= nil ) then
	if ( _G._GAME ) then
		hook.add( "Think", "hl2sb_timer", Tick )
	else
		-- Client has no gamemode Think; HudViewportPaint runs every frame.
		hook.add( "HudViewportPaint", "hl2sb_timer", Tick )
	end
end
