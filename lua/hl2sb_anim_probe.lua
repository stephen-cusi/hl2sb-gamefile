-- ===========================================================================
-- HL2SB player-animation probe (temporary debug helper, not tracked by git).
--
-- Shows exactly what the engine will animate the player with:
--   * which playermodel is in use and which activities it actually has
--     (SelectWeightedSequence() == -1 means "this model has no such sequence")
--   * the active weapon's SWEP.HoldType and the m_acttable rows built from it
--
-- Usage (console):
--   lua_dofile_cl hl2sb_anim_probe.lua            -- dump as-is (client)
--   lua_dofile    hl2sb_anim_probe.lua            -- dump as-is (server)
--   lua_run_cl    HL2SB_AnimProbe( "camera" )     -- pretend the weapon is a camera
--   lua_run_cl    HL2SB_AnimProbe( "fist" )
--   lua_run_cl    HL2SB_AnimProbe( nil, true )    -- 4s per-frame trace, MOVE NOW
--
-- NOTE: HL2SB has no GMod `Entity` global (GMod's is
-- lua/includes/modules/gmod_compatibility/sh_init.lua's `Entity = Entities.Find`,
-- and this engine never loads that folder).  The probe therefore looks the player
-- up via LocalPlayer() / Entity(1) / util.GetLocalPlayer() / player.GetAll().
-- ===========================================================================

local PROBE_ACTIVITIES = {
	"ACT_HL2MP_IDLE",
	"ACT_HL2MP_WALK",
	"ACT_HL2MP_RUN",
	"ACT_HL2MP_IDLE_CROUCH",
	"ACT_HL2MP_WALK_CROUCH",
	"ACT_HL2MP_JUMP",
	"ACT_HL2MP_JUMP_SLAM",
	"ACT_HL2MP_IDLE_CAMERA",
	"ACT_HL2MP_RUN_CAMERA",
	"ACT_HL2MP_IDLE_FIST",
	"ACT_HL2MP_RUN_FIST",
	"ACT_HL2MP_IDLE_REVOLVER",
	"ACT_HL2MP_RUN_REVOLVER",
	"ACT_HL2MP_IDLE_KNIFE",
	"ACT_HL2MP_IDLE_MELEE2",
	"ACT_HL2MP_IDLE_MAGIC",
	"ACT_HL2MP_IDLE_PASSIVE",
	"ACT_HL2MP_IDLE_DUEL",
	"ACT_HL2MP_WALK_PISTOL",
	"ACT_HL2MP_SWIM_PISTOL",
	"ACT_GMOD_NOCLIP_LAYER",
}

local function ProbeNames()
	local byValue = {}
	local enum = _E and _E.ACTIVITY
	if ( enum ) then
		for name, value in pairs( enum ) do
			byValue[ value ] = name
		end
	end
	return byValue
end

-- HL2SB has no GMod `Entity` global (see the note at the bottom of this file),
-- so look the player up through whatever this realm does provide.
local function ProbePlayer()
	if ( LocalPlayer ) then return LocalPlayer() end
	if ( Entity ) then return Entity( 1 ) end
	if ( util and util.GetLocalPlayer ) then return util.GetLocalPlayer() end
	if ( player and player.GetAll ) then return player.GetAll()[ 1 ] end
	return nil
end

local function ProbePlayerName()
	if ( LocalPlayer ) then return "LocalPlayer()" end
	if ( Entity ) then return "Entity(1)" end
	if ( util and util.GetLocalPlayer ) then return "util.GetLocalPlayer()" end
	return "player.GetAll()[1]"
end

local function ProbeValue( name )
	-- The flat global is what the weapon_base HoldType table reads, so prefer it
	-- and fall back to _E.ACTIVITY (the engine publishes both).
	local value = _G[ name ]
	if ( value == nil and _E and _E.ACTIVITY ) then
		value = _E.ACTIVITY[ name ]
	end
	return value
end

local function ProbeNow()
	if ( RealTime ) then return RealTime() end
	if ( CurTime ) then return CurTime() end
	if ( SysTime ) then return SysTime() end
	return os.clock()
end

-- ===========================================================================
-- HL2SB_AnimActivityTest( activityName )
--
-- Calls SelectWeightedSequence() 40 times for ONE activity.  If it comes back
-- with more than one distinct sequence, that activity is a "multi-sequence"
-- activity, and any code that re-selects it every frame (which is exactly what
-- CHL2MP_Player::SetAnimation() does while the player moves) used to
-- ResetSequence() + SetCycle( 0 ) the player every frame -- the walk cycle then
-- shows frame 0 forever, i.e. "the legs move a bit and then go static".
--
-- With no argument it tests the current weapon's own WALK / RUN / IDLE rows.
-- ===========================================================================
local function ProbeActivityReport( ply, activityName, value )
	local counts = {}
	local order = {}
	for _ = 1, 40 do
		local seq = ply:SelectWeightedSequence( value )
		if ( counts[ seq ] == nil ) then
			counts[ seq ] = 0
			order[ #order + 1 ] = seq
		end
		counts[ seq ] = counts[ seq ] + 1
	end

	for _, seq in ipairs( order ) do
		print( ("[animact] %-30s -> seq %4d '%s' act='%s'  %2d/40  groundspeed=%s duration=%s"):format(
			activityName, seq,
			tostring( ply:GetSequenceName( seq ) ),
			tostring( ply:GetSequenceActivityName( seq ) ),
			counts[ seq ],
			tostring( ply:GetSequenceGroundSpeed( seq ) ),
			tostring( ply:SequenceDuration( seq ) ) ) )
	end

	if ( #order > 1 ) then
		print( ("[animact]   ^^ %s is satisfied by %d sequences - a per-frame re-select resets the cycle"):format(
			activityName, #order ) )
	end
	return #order
end

function HL2SB_AnimActivityTest( activityName )
	local ply = ProbePlayer()
	if ( not IsValid( ply ) ) then
		print( "[animact] could not find the local player (tried "
			.. ProbePlayerName() .. ")" )
		return
	end

	local realm = CLIENT and "cl" or "sv"
	print( ("[animact/%s] model=%s"):format( realm, tostring( ply:GetModel() ) ) )

	if ( activityName ~= nil ) then
		local value = ProbeValue( activityName )
		if ( value == nil ) then
			print( "[animact] unknown activity: " .. tostring( activityName ) )
			return
		end
		ProbeActivityReport( ply, activityName, value )
		return
	end

	local wep = ply:GetActiveWeapon()
	if ( not IsValid( wep ) ) then
		print( "[animact] no active weapon - pass an activity name instead" )
		return
	end

	local byValue = ProbeNames()
	local interesting = {}
	for _, row in ipairs( wep.m_acttable or {} ) do
		local base = byValue[ row[ 1 ] ]
		if ( base == "ACT_HL2MP_IDLE" or base == "ACT_HL2MP_WALK"
				or base == "ACT_HL2MP_RUN" or base == "ACT_HL2MP_IDLE_CROUCH"
				or base == "ACT_HL2MP_WALK_CROUCH" ) then
			interesting[ #interesting + 1 ] = base
		end
	end

	for _, name in ipairs( { "ACT_HL2MP_IDLE", "ACT_HL2MP_WALK", "ACT_HL2MP_RUN",
	                         "ACT_HL2MP_IDLE_CROUCH", "ACT_HL2MP_WALK_CROUCH" } ) do
		local value = ProbeValue( name )
		if ( value ) then
			ProbeActivityReport( ply, name, value )
		end
	end
end


-- ===========================================================================
-- HL2SB_AnimClientWatch( seconds )
--
-- CLIENT-side watcher: prints the LOCAL player's own main sequence, loop flag,
-- cycle, playback rate and movement pose parameters ~10x a second for a while.
-- This is the realm that actually renders the playermodel, and unlike the
-- convar it cannot be left unset by the listen server's console.
--
-- Run it while walking / strafing / running and it answers:
--   * loops=false  -> the sequence is clamped at its last frame by
--     CBaseAnimating::StudioFrameAdvanceInternal(), i.e. the legs play one
--     cycle and then pause;
--   * mx / my stay 0 -> the movement blend has no input on this realm;
--   * cycle frozen    -> the cycle is not advancing at all.
-- ===========================================================================
function HL2SB_AnimClientWatch( seconds )
	local ply = ProbePlayer()
	if ( not IsValid( ply ) ) then
		print( "[clanim] no local player yet" )
		return
	end

	seconds = seconds or 15
	local stopAt = ProbeNow() + seconds
	local frames = 0
	local iMoveX = ply:LookupPoseParameter( "move_x" )
	local iMoveY = ply:LookupPoseParameter( "move_y" )
	local iMoveYaw = ply:LookupPoseParameter( "move_yaw" )

	print( ("[clanim] watching for %g seconds - MOVE THE PLAYER NOW"):format( seconds ) )

	hook.Add( "HudViewportPaint", TRACE_HOOK_NAME, function()
		frames = frames + 1
		if ( frames % 20 ~= 0 ) then
			return
		end
		if ( ProbeNow() >= stopAt ) then
			hook.Remove( "HudViewportPaint", TRACE_HOOK_NAME )
			print( "[clanim] done" )
			return
		end
		if ( not IsValid( ply ) ) then return end

		local seq = ply:GetSequence()
		print( ("[clanim] seq=%d '%s' act='%s' loops=%s cycle=%.3f rate=%.2f moveYaw=%s moveX=%s moveY=%s"):format(
			seq,
			tostring( ply:GetSequenceName( seq ) ),
			tostring( ply:GetSequenceActivityName( seq ) ),
			tostring( ply:SequenceLoops() ),
			ply:GetCycle(), ply:GetPlaybackRate(),
			tostring( iMoveYaw >= 0 and ("%+.2f"):format( ply:GetPoseParameter( iMoveYaw ) ) or "n/a" ),
			tostring( iMoveX >= 0 and ("%+.2f"):format( ply:GetPoseParameter( iMoveX ) ) or "n/a" ),
			tostring( iMoveY >= 0 and ("%+.2f"):format( ply:GetPoseParameter( iMoveY ) ) or "n/a" ) ) )
	end )
end


-- ===========================================================================
-- HL2SB_AnimTrace( seconds )
--
-- Logs the main sequence, its cycle / playback rate and the movement pose
-- parameters ~10 times a second.  This is what separates the two ways a walk
-- cycle can look frozen:
--   * sequence number keeps CHANGING and cycle stays near 0
--       -> something re-selects and ResetSequence()/SetCycle(0)s every frame
--   * sequence is stable, cycle advances, rate is sane, but move_x/move_y are 0
--       -> the 9-way blend has no input
-- ===========================================================================
local TRACE_HOOK_NAME = "hl2sb_anim_probe_trace"

function HL2SB_AnimTrace( seconds )
	local ply = ProbePlayer()
	if ( not IsValid( ply ) ) then
		print( "[animtrace] could not find the local player (tried "
			.. ProbePlayerName() .. ")" )
		return
	end

	seconds = seconds or 4
	local realm = CLIENT and "cl" or "sv"
	local deadline = ProbeNow() + seconds
	local nextPrint = 0

	local iMoveX = ply:LookupPoseParameter( "move_x" )
	local iMoveY = ply:LookupPoseParameter( "move_y" )
	local iMoveYaw = ply:LookupPoseParameter( "move_yaw" )

	print( ("[animtrace/%s] logging %g seconds via %s - MOVE THE PLAYER NOW"):format(
		realm, seconds, ProbePlayerName() ) )

	local function Sample()
		local now = ProbeNow()
		if ( now >= deadline ) then
			hook.Remove( "Think", TRACE_HOOK_NAME )
			hook.Remove( "HudViewportPaint", TRACE_HOOK_NAME )
			print( ("[animtrace/%s] done"):format( realm ) )
			return
		end
		if ( now < nextPrint ) then return end
		nextPrint = now + 0.1

		local seq = ply:GetSequence()
		local velocity = ply:GetVelocity()
		print( ("[animtrace/%s] t=%6.2f speed=%7.1f seq=%4d '%s' act='%s' cycle=%.3f rate=%.2f moveX=%s moveY=%s moveYaw=%s"):format(
			realm, now, velocity:Length2D(), seq,
			tostring( ply:GetSequenceName( seq ) ),
			tostring( ply:GetSequenceActivityName( seq ) ),
			ply:GetCycle(), ply:GetPlaybackRate(),
			tostring( iMoveX >= 0 and ply:GetPoseParameter( iMoveX ) or "n/a" ),
			tostring( iMoveY >= 0 and ply:GetPoseParameter( iMoveY ) or "n/a" ),
			tostring( iMoveYaw >= 0 and ply:GetPoseParameter( iMoveYaw ) or "n/a" ) ) )
	end

	-- The two per-frame hooks this engine has, one per realm.
	hook.Add( "Think", TRACE_HOOK_NAME, Sample )            -- server: gamerules Think
	hook.Add( "HudViewportPaint", TRACE_HOOK_NAME, Sample ) -- client: HUD viewport
end

function HL2SB_AnimProbe( holdType, trace )
	local ply = ProbePlayer()
	if ( not IsValid( ply ) ) then
		print( "[animprobe] could not find the local player (tried "
			.. ProbePlayerName() .. ")" )
		return
	end

	-- Optional frame-by-frame trace: HL2SB_AnimProbe( nil, true ) logs
	-- sequence / cycle / rate / move_x / move_y for ~4 seconds, which is what
	-- tells a "sequence keeps getting reset" apart from "the blend has no input".
	if ( trace == true or holdType == true ) then
		HL2SB_AnimTrace( 4 )
		return
	end

	local byValue = ProbeNames()
	local realm = CLIENT and "cl" or "sv"

	local enumCount = 0
	if ( _E and _E.ACTIVITY ) then
		for _ in pairs( _E.ACTIVITY ) do enumCount = enumCount + 1 end
	end

	print( ("[animprobe/%s] model=%s"):format( realm, tostring( ply:GetModel() ) ) )
	print( ("[animprobe/%s] _E.ACTIVITY entries=%d (expect 1951 names + ACTIVITY itself)"):format(
		realm, enumCount ) )

	-- Does this model carry the activities at all?
	for _, name in ipairs( PROBE_ACTIVITIES ) do
		local value = ProbeValue( name )
		local seq = "n/a"
		if ( value ) then
			seq = tostring( ply:SelectWeightedSequence( value ) )
		end
		print( ("[animprobe/%s]   %-28s = %-6s sequence %s%s"):format(
			realm, name, tostring( value ), seq,
			( seq == "-1" ) and "   <-- model has no such sequence" or "" ) )
	end

	-- Movement blend parameters.  A classic HL2MP anim model blends its
	-- walk/run cycles on "move_yaw"; GMod's models use "move_x"/"move_y" and
	-- have no move_yaw at all - if those two stay 0 the legs never move.
	for _, name in ipairs( { "move_yaw", "move_x", "move_y", "body_yaw",
	                         "aim_yaw", "aim_pitch", "vertical_velocity" } ) do
		local index = ply:LookupPoseParameter( name )
		if ( index and index >= 0 ) then
			print( ("[animprobe/%s]   pose %-16s index=%-3d value=%s"):format(
				realm, name, index, tostring( ply:GetPoseParameter( index ) ) ) )
		else
			print( ("[animprobe/%s]   pose %-16s MISSING from this model"):format( realm, name ) )
		end
	end

	local seq = ply:GetSequence()
	print( ("[animprobe/%s]   main sequence=%d '%s' activity='%s' cycle=%s rate=%s"):format(
		realm, seq, tostring( ply:GetSequenceName( seq ) ),
		tostring( ply:GetSequenceActivityName( seq ) ),
		tostring( ply:GetCycle() ), tostring( ply:GetPlaybackRate() ) ) )

	local wep = ply:GetActiveWeapon()
	if ( not IsValid( wep ) ) then
		print( ("[animprobe/%s] active weapon: NONE (engine uses the bare ACT_HL2MP_* set)"):format( realm ) )
		return
	end

	local original = wep.HoldType
	if ( holdType ~= nil and wep.SetHoldType ) then
		wep:SetHoldType( holdType )
		wep.m_acttable = wep.m_acttable or {}
	end

	print( ("[animprobe/%s] active weapon=%s  HoldType=%s  m_acttable rows=%d"):format(
		realm, wep:GetClass(), tostring( wep.HoldType ), #( wep.m_acttable or {} ) ) )

	for i, row in ipairs( wep.m_acttable or {} ) do
		local base, act = row[ 1 ], row[ 2 ]
		print( ("[animprobe/%s]   row %2d  %-34s -> %-36s  base seq=%-4s weapon seq=%-4s"):format(
			realm, i,
			tostring( byValue[ base ] or base ),
			tostring( byValue[ act ] or act ),
			tostring( ply:SelectWeightedSequence( base ) ),
			tostring( ply:SelectWeightedSequence( act ) ) ) )
	end

	if ( holdType ~= nil and original and wep.SetHoldType ) then
		wep:SetHoldType( original )
		print( ("[animprobe/%s] restored HoldType=%s"):format( realm, tostring( original ) ) )
	end
end

HL2SB_AnimProbe()
print( "[animprobe] done.  Try: lua_run_cl HL2SB_AnimProbe( \"camera\" )" )
