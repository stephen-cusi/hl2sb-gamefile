--===========================================================================
-- HL2SB (2026-09-27): port of GMod's base gamemode animations.lua
-- (garrysmod/gamemodes/base/gamemode/animations.lua, 406 lines) - the Lua
-- side of GMod's player animation.  The fork's C++ dispatches these hooks
-- from the player animation path (CHL2MP_Player::SetAnimation / PostThink,
-- C_HL2MP_Player::PostThink) with the contracts GMod's lua_shared
-- reference pinned down:
--
--   GM:CalcMainActivity( ply, velocity )  -> ( idealActivity, seqOverride )
--   GM:UpdateAnimation( ply, velocity, maxseqgroundspeed )
--   GM:TranslateActivity( ply, act )      -> newAct
--   GM:DoAnimationEvent( ply, event, data ) -> viewmodelActivity
--
-- Adaptations to this fork (all commented inline):
--   * HandlePlayerNoClipping leaves the noclip pose layer to the engine
--     (CPlayerAnimState::UpdateNoclipLayer already runs the exact
--     ACT_GMOD_NOCLIP_LAYER layer, server-side and networked).
--   * FL_ANIMDUCKING is published here under the Source flag name
--     FL_DUCKING_ANIMATION (same value).
--   * list.GetEntry has no binding yet - list.Get(id)[name] fallback.
--   * Weapon:GetHoldType has no binding yet - the SWEP table's HoldType
--     field (what the anim probe reads) is used instead.
--===========================================================================--

-- HL2SB NOTE: GMod tests FL_ANIMDUCKING here, but THIS fork's HL2 movement code
-- never sets that flag - only the cstrike game code does (gamemovement.cpp only
-- ever does AddFlag( FL_DUCKING ), in FinishDuck/FinishUnDuck).  Testing
-- FL_ANIMDUCKING returned false for every crouch, so this branch never ran and
-- the whole Lua crouch pose was dead: crouch showed no animation, and every
-- subsequent crouch activity was never requested.  FL_DUCKING is the flag the
-- fork actually raises, so that is the one to test.
local HL2SB_FL_DUCKING = FL_DUCKING or DUCKING or 2

function GM:HandlePlayerJumping( ply, velocity, plyTable )

	if ( !plyTable ) then plyTable = ply:GetTable() end

	if ( ply:GetMoveType() == MOVETYPE_NOCLIP ) then
		plyTable.m_bJumping = false
		return
	end

	-- airwalk more like hl2mp, we airwalk until we have 0 velocity, then it's the jump animation
	-- underwater we're alright we airwalking
	if ( !plyTable.m_bJumping && !ply:OnGround() && ply:WaterLevel() <= 0 ) then

		if ( !plyTable.m_fGroundTime ) then

			plyTable.m_fGroundTime = CurTime()

		elseif ( ( CurTime() - plyTable.m_fGroundTime ) > 0 && velocity:Length2DSqr() < 0.25 ) then

			plyTable.m_bJumping = true
			plyTable.m_bFirstJumpFrame = false
			plyTable.m_flJumpStartTime = 0

		end
	end

	if ( plyTable.m_bJumping ) then

		if ( plyTable.m_bFirstJumpFrame ) then

			plyTable.m_bFirstJumpFrame = false
			ply:AnimRestartMainSequence()

		end

		if ( ( ply:WaterLevel() >= 2 ) || ( ( CurTime() - plyTable.m_flJumpStartTime ) > 0.2 && ply:OnGround() ) ) then

			plyTable.m_bJumping = false
			plyTable.m_fGroundTime = nil
			ply:AnimRestartMainSequence()

		end

		if ( plyTable.m_bJumping ) then
			plyTable.CalcIdeal = ACT_MP_JUMP
			return true
		end
	end

	return false

end

function GM:HandlePlayerDucking( ply, velocity, plyTable )

	if ( !plyTable ) then plyTable = ply:GetTable() end

	if ( !ply:IsFlagSet( HL2SB_FL_DUCKING ) ) then return false end

	if ( velocity:Length2DSqr() > 0.25 ) then
		plyTable.CalcIdeal = ACT_MP_CROUCHWALK
	else
		plyTable.CalcIdeal = ACT_MP_CROUCH_IDLE
	end

	return true

end

function GM:HandlePlayerNoClipping( ply, velocity, plyTable )

	if ( !plyTable ) then plyTable = ply:GetTable() end

	-- HL2SB: the noclip POSE (ACT_GMOD_NOCLIP_LAYER on GESTURE_SLOT_CUSTOM) is
	-- engine-managed here (CPlayerAnimState::UpdateNoclipLayer - server-side
	-- AddLayeredSequence, networked).  Starting the same layer from Lua would
	-- stack a second copy, so only the CalcIdeal decision is Lua's, exactly
	-- like GMod's ordering ("noclip wins over everything but the main-sequence
	-- decision").

	if ( ply:GetMoveType() != MOVETYPE_NOCLIP || ply:InVehicle() ) then

		if ( plyTable.m_bWasNoclipping ) then

			plyTable.m_bWasNoclipping = nil

		end

		return false

	end

	if ( !plyTable.m_bWasNoclipping ) then
		plyTable.m_bWasNoclipping = true
	end

	-- Noclipping keeps the body in the idle pose; the engine layer plays the
	-- superman pose on top of it.
	plyTable.CalcIdeal = ACT_MP_STAND_IDLE

	return true

end

function GM:HandlePlayerVaulting( ply, velocity, plyTable )

	if ( !plyTable ) then plyTable = ply:GetTable() end

	if ( velocity:LengthSqr() < 1000000 ) then return end
	if ( ply:IsOnGround() ) then return end

	plyTable.CalcIdeal = ACT_MP_SWIM

	return true

end

function GM:HandlePlayerSwimming( ply, velocity, plyTable )

	if ( !plyTable ) then plyTable = ply:GetTable() end

	if ( ply:WaterLevel() < 2 || ply:IsOnGround() ) then
		plyTable.m_bInSwim = false
		return false
	end

	plyTable.CalcIdeal = ACT_MP_SWIM
	plyTable.m_bInSwim = true

	return true

end

function GM:HandlePlayerLanding( ply, velocity, WasOnGround )

	if ( ply:GetMoveType() == MOVETYPE_NOCLIP ) then return end

	if ( ply:IsOnGround() && !WasOnGround ) then
		ply:AnimRestartGesture( GESTURE_SLOT_JUMP, ACT_LAND, true )
	end

end

function GM:HandlePlayerDriving( ply, plyTable )

	if ( !plyTable ) then plyTable = ply:GetTable() end

	-- The player must have a parent to be in a vehicle. If there's no parent, we are in the exit anim, so don't do sitting in 3rd person anymore
	if ( !ply:InVehicle() || !IsValid( ply:GetParent() ) ) then return false end

	local pVehicle = ply:GetVehicle()

	-- list.GetEntry( listid, key ) is the GMod spelling (list.lua:86).
	if ( !pVehicle.HandleAnimation && pVehicle.GetVehicleClass ) then
		local listEntr = list.GetEntry( "Vehicles", pVehicle:GetVehicleClass() )
		if ( listEntr && listEntr.Members && listEntr.Members.HandleAnimation ) then
			pVehicle.HandleAnimation = listEntr.Members.HandleAnimation
		else
			pVehicle.HandleAnimation = true -- Prevent this if block from trying to assign HandleAnimation again.
		end
	end

	if ( isfunction( pVehicle.HandleAnimation ) ) then
		local seq = pVehicle:HandleAnimation( ply )
		if ( seq != nil ) then
			plyTable.CalcSeqOverride = seq
		end
	end

	if ( plyTable.CalcSeqOverride == -1 ) then -- pVehicle.HandleAnimation did not give us an animation
		local class = pVehicle:GetClass()
		if ( class == "prop_vehicle_jeep" ) then
			plyTable.CalcSeqOverride = ply:LookupSequence( "drive_jeep" )
		elseif ( class == "prop_vehicle_airboat" ) then
			plyTable.CalcSeqOverride = ply:LookupSequence( "drive_airboat" )
		elseif ( class == "prop_vehicle_prisoner_pod" && pVehicle:GetModel() == "models/vehicles/prisoner_pod_inner.mdl" ) then
			-- HACK!!
			plyTable.CalcSeqOverride = ply:LookupSequence( "drive_pd" )
		else
			plyTable.CalcSeqOverride = ply:LookupSequence( "sit_rollercoaster" )
		end
	end

	local use_anims = ( plyTable.CalcSeqOverride == ply:LookupSequence( "sit_rollercoaster" ) || plyTable.CalcSeqOverride == ply:LookupSequence( "sit" ) )
	if ( use_anims && ply:GetAllowWeaponsInVehicle() && IsValid( ply:GetActiveWeapon() ) ) then

		-- HL2SB: Weapon:GetHoldType has no binding yet; SWEPs carry HoldType in
		-- their script table, which the weapon entity's __index resolves.
		local wep = ply:GetActiveWeapon()
		local holdtype = wep.HoldType || "passive"
		if ( holdtype == "smg" ) then holdtype = "smg1" end

		local seqid = ply:LookupSequence( "sit_" .. holdtype )
		if ( seqid != -1 ) then
			plyTable.CalcSeqOverride = seqid
		end
	end

	return true

end

--[[---------------------------------------------------------
   Name: gamemode:UpdateAnimation()
   Desc: Animation updates (pose params etc) should be done here
-----------------------------------------------------------]]
function GM:UpdateAnimation( ply, velocity, maxseqgroundspeed )

	local len = velocity:Length()
	local movement = 1.0

	if ( len > 0.2 ) then
		movement = ( len / maxseqgroundspeed )
	end

	local rate = math.min( movement, 2 )

	-- if we're under water we want to constantly be swimming..
	if ( ply:WaterLevel() >= 2 ) then
		rate = math.max( rate, 0.5 )
	elseif ( !ply:IsOnGround() && len >= 1000 ) then
		rate = 0.1
	end

	ply:SetPlaybackRate( rate )

	if ( ply:InVehicle() ) then
		--
		-- This is used for the 'rollercoaster' arms
		--
		local Vehicle = ply:GetVehicle()
		local Velocity = Vehicle:GetVelocity()
		local fwd = Vehicle:GetUp()
		local dp = fwd:Dot( Vector( 0, 0, 1 ) )
		ply:SetPoseParameter( "vertical_velocity", ( dp < 0 && dp || 0 ) + fwd:Dot( Velocity ) * 0.005 )

		-- Pass the vehicles steer param down to the player
		local steer = Vehicle:GetPoseParameter( "vehicle_steer" )

		if ( Vehicle:GetClass() == "prop_vehicle_prisoner_pod" ) then
			-- No steering in seats (when overridden to use jeep animations)
			-- So that it doesn't stick to random value it had before
			steer = 0.5

			-- Fix weapon aiming poseparam in vehicle
			ply:SetPoseParameter( "aim_yaw", math.NormalizeAngle( ply:GetAimVector():Angle().y - Vehicle:GetAngles().y - 90 ) )
		end

		-- Gotta convert from 0..1 (network range) to -1..1 (pose param range) on client
		if ( CLIENT ) then steer = steer * 2 - 1 end
		ply:SetPoseParameter( "vehicle_steer", steer )

	end

	GAMEMODE:GrabEarAnimation( ply )

	-- We only need to do this clientside..
	if ( CLIENT ) then
		GAMEMODE:MouthMoveAnimation( ply )
	end

end

--
-- If you don't want the player to grab his ear in your gamemode then
-- just override this.
--
function GM:GrabEarAnimation( ply, plyTable )

	if ( !plyTable ) then plyTable = ply:GetTable() end

	plyTable.ChatGestureWeight = plyTable.ChatGestureWeight || 0

	-- Don't show this when we're playing a taunt!
	if ( ply:IsPlayingTaunt() ) then return end

	if ( ply:IsTyping() ) then
		plyTable.ChatGestureWeight = math.Approach( plyTable.ChatGestureWeight, 1, FrameTime() * 5.0 )
	else
		plyTable.ChatGestureWeight = math.Approach( plyTable.ChatGestureWeight, 0, FrameTime() * 5.0 )
	end

	if ( plyTable.ChatGestureWeight > 0 ) then

		ply:AnimRestartGesture( GESTURE_SLOT_VCD, ACT_GMOD_IN_CHAT, true )
		ply:AnimSetGestureWeight( GESTURE_SLOT_VCD, plyTable.ChatGestureWeight )

	end

end

--
-- Moves the mouth when talking on voicecom
--
function GM:MouthMoveAnimation( ply )

	local flexes = {
		ply:GetFlexIDByName( "jaw_drop" ),
		ply:GetFlexIDByName( "left_part" ),
		ply:GetFlexIDByName( "right_part" ),
		ply:GetFlexIDByName( "left_mouth_drop" ),
		ply:GetFlexIDByName( "right_mouth_drop" )
	}

	local weight = ply:IsSpeaking() && math.Clamp( ply:VoiceVolume() * 2, 0, 2 ) || 0

	for k, v in ipairs( flexes ) do

		ply:SetFlexWeight( v, weight )

	end

end

function GM:CalcMainActivity( ply, velocity )

	local plyTable = ply:GetTable()
	plyTable.CalcIdeal = ACT_MP_STAND_IDLE
	plyTable.CalcSeqOverride = -1

	self:HandlePlayerLanding( ply, velocity, plyTable.m_bWasOnGround )

	if !( self:HandlePlayerNoClipping( ply, velocity, plyTable ) ||
		self:HandlePlayerDriving( ply, plyTable ) ||
		self:HandlePlayerVaulting( ply, velocity, plyTable ) ||
		self:HandlePlayerJumping( ply, velocity, plyTable ) ||
		self:HandlePlayerSwimming( ply, velocity, plyTable ) ||
		self:HandlePlayerDucking( ply, velocity, plyTable ) ) then

		local len2d = velocity:Length2DSqr()
		if ( len2d > 22500 ) then plyTable.CalcIdeal = ACT_MP_RUN elseif ( len2d > 0.25 ) then plyTable.CalcIdeal = ACT_MP_WALK end

	end

	plyTable.m_bWasOnGround = ply:IsOnGround()
	plyTable.m_bWasNoclipping = ( ply:GetMoveType() == MOVETYPE_NOCLIP && !ply:InVehicle() )

	return plyTable.CalcIdeal, plyTable.CalcSeqOverride

end

-- HL2SB NOTE: GMod's original table derives the HL2MP activity arithmetically
-- (IdleActivity + 1/2/3/4/5/6/9).  That assumes GMod's engine enum order
--
--     ACT_HL2MP_IDLE, ACT_HL2MP_WALK, ACT_HL2MP_RUN, ACT_HL2MP_IDLE_CROUCH,
--     ACT_HL2MP_WALK_CROUCH, ACT_HL2MP_GESTURE_RANGE_ATTACK, ...
--
-- but THIS fork's ai_activity.h was built from an older HL2MP enum that has no
-- ACT_HL2MP_WALK in the head block at all (it is appended at the very END of the
-- enum, ai_activity.h:1349).  Its order is
--
--     ACT_HL2MP_IDLE, ACT_HL2MP_RUN, ACT_HL2MP_IDLE_CROUCH, ACT_HL2MP_WALK_CROUCH,
--     ACT_HL2MP_GESTURE_RANGE_ATTACK, ACT_HL2MP_GESTURE_RELOAD, ACT_HL2MP_JUMP, ...
--
-- so the arithmetic was off by one from ACT_MP_WALK onward: crouchwalk landed on
-- ACT_HL2MP_GESTURE_RANGE_ATTACK (an attack gesture with no crouch sequence ->
-- "some weapons lose their animation when crouching"), run landed on crouch idle,
-- reload on jump.  Map by NAME, so the divergent enum can never skew it again.
local IdleActivityTranslate = {}
IdleActivityTranslate[ ACT_MP_STAND_IDLE ]					= ACT_HL2MP_IDLE
IdleActivityTranslate[ ACT_MP_WALK ]						= ACT_HL2MP_WALK
IdleActivityTranslate[ ACT_MP_RUN ]							= ACT_HL2MP_RUN
IdleActivityTranslate[ ACT_MP_CROUCH_IDLE ]					= ACT_HL2MP_IDLE_CROUCH
IdleActivityTranslate[ ACT_MP_CROUCHWALK ]					= ACT_HL2MP_WALK_CROUCH
IdleActivityTranslate[ ACT_MP_ATTACK_STAND_PRIMARYFIRE ]	= ACT_HL2MP_GESTURE_RANGE_ATTACK
IdleActivityTranslate[ ACT_MP_ATTACK_CROUCH_PRIMARYFIRE ]	= ACT_HL2MP_GESTURE_RANGE_ATTACK
IdleActivityTranslate[ ACT_MP_RELOAD_STAND ]				= ACT_HL2MP_GESTURE_RELOAD
IdleActivityTranslate[ ACT_MP_RELOAD_CROUCH ]				= ACT_HL2MP_GESTURE_RELOAD
IdleActivityTranslate[ ACT_MP_JUMP ]						= ACT_HL2MP_JUMP_SLAM
IdleActivityTranslate[ ACT_MP_SWIM ]						= ACT_HL2MP_SWIM
IdleActivityTranslate[ ACT_LAND ]							= ACT_LAND

-- it is preferred you return ACT_MP_* in CalcMainActivity, and if you have a specific need to not translate through the weapon do it here
function GM:TranslateActivity( ply, act )

	-- GMod original: ask the weapon first (this fork's HL2MP weapon acttables
	-- are keyed on ACT_MP_*, weapon_pistol.cpp:147), and only when the weapon
	-- has no opinion fall back to the hold-type-less HL2MP activity.
	local newact = ply:TranslateWeaponActivity( act )

	-- select idle anims if the weapon didn't decide
	if ( act == newact ) then
		return IdleActivityTranslate[ act ] or act
	end

	return newact

end

function GM:DoAnimationEvent( ply, event, data )

	if ( event == PLAYERANIMEVENT_ATTACK_PRIMARY ) then

		if ply:IsFlagSet( HL2SB_FL_DUCKING ) then
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_CROUCH_PRIMARYFIRE, true )
		else
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_STAND_PRIMARYFIRE, true )
		end

		return ACT_VM_PRIMARYATTACK

	elseif ( event == PLAYERANIMEVENT_ATTACK_SECONDARY ) then

		-- there is no gesture, so just fire off the VM event
		return ACT_VM_SECONDARYATTACK

	elseif ( event == PLAYERANIMEVENT_RELOAD ) then

		if ply:IsFlagSet( HL2SB_FL_DUCKING ) then
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_CROUCH, true )
		else
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_STAND, true )
		end

		return ACT_INVALID

	elseif ( event == PLAYERANIMEVENT_JUMP ) then

		ply.m_bJumping = true
		ply.m_bFirstJumpFrame = true
		ply.m_flJumpStartTime = CurTime()

		ply:AnimRestartMainSequence()

		return ACT_INVALID

	elseif ( event == PLAYERANIMEVENT_CANCEL_RELOAD ) then

		ply:AnimResetGestureSlot( GESTURE_SLOT_ATTACK_AND_RELOAD )

		return ACT_INVALID
	end

end
