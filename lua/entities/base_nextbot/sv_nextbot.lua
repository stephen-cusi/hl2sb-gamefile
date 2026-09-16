--========== HL2SB - GMod compat ==========--
--
-- Purpose: the server half of base_nextbot - the behaviour coroutine and the
--          callbacks the engine dispatches into.
--
--   The engine side is game/server/lua/luanextbot.cpp.  What matters here is
--   the contract between the two:
--
--     BehaveStart()     <- called once, by the intention's Reset()
--     BehaveUpdate( dt )<- called every frame, resumes the coroutine
--     BodyUpdate()      <- called every frame, right after the bot update
--     MoveToPos()       <- YOUR code, runs INSIDE the coroutine
--
--   ⚠️ A nextbot's scripts run on the SERVER, and this fork's Lua has no
--   GMod-only globals: Msg() is printf-style here (never pass self as its first
--   argument), and FrameAdvance() is bound for the server as an alias of
--   StudioFrameAdvance() precisely because base_nextbot calls it.
--===========================================================================--

--[[---------------------------------------------------------
	Name: NEXTBOT:BehaveStart
	Desc: Starts the behaviour coroutine.  The engine calls this once, when the
	      bot is created; you should not call or override it.
-----------------------------------------------------------]]
function ENT:BehaveStart()
	self.BehaveThread = coroutine.create( function() self:RunBehaviour() end )
end

--[[---------------------------------------------------------
	Name: NEXTBOT:RunBehaviour
	Desc: YOUR behaviour.  Ticked by the engine; call self:MoveToPos() and
	      coroutine.wait() here.
-----------------------------------------------------------]]
function ENT:RunBehaviour()
end

--[[---------------------------------------------------------
	Name: NEXTBOT:BehaveUpdate
	Desc: Called every frame with the time since the last update.  Resumes
	      RunBehaviour's coroutine.
-----------------------------------------------------------]]
function ENT:BehaveUpdate( fInterval )
	-- The engine calls BehaveStart() once, when the bot is created.  Start the
	-- coroutine here as well if that did not happen: without it every callback
	-- below is a no-op forever, and the symptom is indistinguishable from a bot
	-- whose script does nothing (it just stands there).  Idempotent: only runs
	-- while there is no thread.
	if ( !self.BehaveThread ) then
		self:BehaveStart()
	end

	local thread = self.BehaveThread

	if ( !thread ) then return end

	if ( coroutine.status( thread ) == "dead" ) then
		-- RunBehaviour returned: keep the bot alive but stop ticking it.
		self.BehaveThread = nil
		Msg( "[HL2SB] nextbot " .. tostring( self ) .. ": RunBehaviour() has finished\n" )
		return
	end

	local ok, message = coroutine.resume( thread )

	if ( ok == false ) then
		self.BehaveThread = nil
		-- Both sinks on purpose: ErrorNoHalt() is what GMod's base does and it
		-- reaches the console, but it does NOT reach ds_debug.log -- and a
		-- behaviour error is exactly the thing that shows up as "the bot just
		-- stands there", with nothing in the log to explain it.
		local text = "[HL2SB] nextbot behaviour error: " .. tostring( message ) .. "\n"
		Msg( text )
		ErrorNoHalt( text )
	end
end

--[[---------------------------------------------------------
	Name: NEXTBOT:BodyUpdate
	Desc: Called every frame to update the animation.  While the bot is walking
	      or running the move_x / move_y pose parameters come from the ground
	      speed; otherwise the animation frame is advanced.
-----------------------------------------------------------]]
function ENT:BodyUpdate()
	local act = self:GetActivity()

	if ( act == ACT_RUN || act == ACT_WALK ) then
		-- BodyMoveXY() calls FrameAdvance() itself, so returning here is the
		-- point: advancing twice would corrupt layered playback.
		self:BodyMoveXY()
		return
	end

	self:FrameAdvance()
end

--[[---------------------------------------------------------
	Name: NextBot:MoveToPos
	Desc: Walk to a position.  ONLY call this from RunBehaviour (it yields).
	      Returns "ok", "failed", "stuck" or "timeout".
-----------------------------------------------------------]]
function ENT:MoveToPos( pos, options )
	options = options or {}

	local path = Path( "Follow" )
	path:SetMinLookAheadDistance( options.lookahead or 300 )
	path:SetGoalTolerance( options.tolerance or 20 )
	path:Compute( self, pos )

	if ( !path:IsValid() ) then return "failed" end

	while ( path:IsValid() ) do

		path:Update( self )

		if ( options.draw ) then
			path:Draw()
		end

		if ( self.loco:IsStuck() ) then
			self:HandleStuck()
			return "stuck"
		end

		if ( options.maxage && path:GetAge() > options.maxage ) then
			return "timeout"
		end

		-- rebuild the path every options.repath seconds
		if ( options.repath && path:GetAge() > options.repath ) then
			path:Compute( self, pos )
		end

		coroutine.yield()
	end

	return "ok"
end

--[[---------------------------------------------------------
	Name: NextBot:PlaySequenceAndWait
	Desc: Plays a sequence and yields until it has finished.
-----------------------------------------------------------]]
function ENT:PlaySequenceAndWait( name, speed )
	local length = self:SetSequence( name )

	speed = speed or 1

	self:ResetSequenceInfo()
	self:SetCycle( 0 )
	self:SetPlaybackRate( speed )

	coroutine.wait( length / speed )
end

--[[---------------------------------------------------------
	Name: NextBot:HandleStuck
	Desc: Called when the locomotion thinks the bot is stuck.  The default
	      clears the status so the bot can try again; override it for anything
	      that yields.
-----------------------------------------------------------]]
function ENT:HandleStuck()
	self.loco:ClearStuck()
end

--[[---------------------------------------------------------
	Name: NextBot:FindSpots
	Desc: Hiding spots near a position, with the path distance to each.
-----------------------------------------------------------]]
function ENT:FindSpots( tbl )
	tbl = tbl or {}

	tbl.pos			= tbl.pos		or self:WorldSpaceCenter()
	tbl.radius		= tbl.radius	or 1000
	tbl.stepdown	= tbl.stepdown	or 20
	tbl.stepup		= tbl.stepup	or 20
	tbl.type		= tbl.type		or "hiding"

	local path = Path( "Follow" )
	local areas = navmesh.Find( tbl.pos, tbl.radius, tbl.stepdown, tbl.stepup )
	local found = {}

	for _, area in ipairs( areas ) do

		local spots

		if ( tbl.type == "hiding" ) then
			spots = area:GetHidingSpots()
		end

		for _, vec in ipairs( spots or {} ) do

			path:Invalidate()
			path:Compute( self, vec )

			table.insert( found, { vector = vec, distance = path:GetLength() } )

		end

	end

	return found
end

--[[---------------------------------------------------------
	Name: NextBot:FindSpot
	Desc: One spot of a given kind: "near", "far" or random.
-----------------------------------------------------------]]
function ENT:FindSpot( kind, options )
	local spots = self:FindSpots( options )

	if ( !spots || #spots == 0 ) then return end

	if ( kind == "near" ) then
		table.SortByMember( spots, "distance", true )
		return spots[ 1 ].vector
	end

	if ( kind == "far" ) then
		table.SortByMember( spots, "distance", false )
		return spots[ 1 ].vector
	end

	return spots[ math.random( 1, #spots ) ].vector
end

--===========================================================================
-- The callbacks the engine raises.  Derive and override the ones you need;
-- the defaults are intentionally empty.
--===========================================================================

-- The bot's feet left the ground (jumping, walking off an edge, ...)
function ENT:OnLeaveGround( ent ) end

-- The bot landed on something
function ENT:OnLandOnGround( ent ) end

-- The locomotion thinks the bot is stuck (and is no longer)
function ENT:OnStuck() end
function ENT:OnUnStuck() end

-- The bot was hurt
function ENT:OnInjured( dmginfo ) end

--[[---------------------------------------------------------
	Name: NEXTBOT:OnTakeDamage
	Desc: Return a number to replace the engine's damage handling
	      (0 makes the bot invulnerable).
-----------------------------------------------------------]]
function ENT:OnTakeDamage( dmginfo ) end

--[[---------------------------------------------------------
	Name: NEXTBOT:OnKilled
	Desc: The bot died.  Default: announce it, then ragdoll, which is what
	      GMod's base does (hook "OnNPCKilled" first, so gamemodes see it).
-----------------------------------------------------------]]
function ENT:OnKilled( dmginfo )
	hook.Run( "OnNPCKilled", self, dmginfo:GetAttacker(), dmginfo:GetInflictor() )

	self:BecomeRagdoll( dmginfo )
end

-- Somebody else died nearby
function ENT:OnOtherKilled( victim, info ) end

-- The bot touched something
function ENT:OnContact( ent ) end

-- The bot caught fire
function ENT:OnIgnite() end

-- The bot walked into a different nav area
function ENT:OnNavAreaChanged( old, new ) end

-- Server-side animation events
function ENT:HandleAnimEvent( event, eventtime, cycle, type, options ) end

--[[---------------------------------------------------------
	Name: NEXTBOT:OnTraceAttack
	Desc: Called when the bot is attacked, before the damage is applied.
-----------------------------------------------------------]]
function ENT:OnTraceAttack( dmginfo, dir, trace )
	hook.Run( "ScaleNPCDamage", self, trace.HitGroup, dmginfo )
end

-- The bot can see (or lost sight of) an entity - only raised if the bot has a
-- vision interface, which a Lua nextbot does not install by default.
function ENT:OnEntitySight( subject ) end
function ENT:OnEntitySightLost( subject ) end

-- Player use, and the periodic think (this is NOT the behaviour tick - that is
-- BehaveUpdate).
function ENT:Use( activator, caller, type, value ) end
function ENT:Think() end
