--[[----------------------------------------------------------------------------
	hl2sb_animations.lua  -  GMod's player animation logic, ported.

	Source: garrysmod/gamemodes/base/gamemode/animations.lua (GMod, 405 lines).
	HL2SB policy (AGENTS.md 10): do NOT clone GMod - be COMPATIBLE with it.  So:

	  * the four hooks (CalcMainActivity / TranslateActivity / UpdateAnimation /
	    DoAnimationEvent) are the same names, same arguments and same return
	    values as GMod's, and the engine calls them from CHL2MPPlayerAnimState
	    (game/shared/hl2mp/hl2mp_playeranimstate.cpp);
	  * if the active gamemode implements any of them as GM:<name>, this file
	    steps aside and lets the engine's gamemode fallback call it, exactly like
	    a GMod addon would expect;
	  * every optional engine call is probed, and the hook ANSWERS ONLY WHEN IT
	    CAN DECIDE RELIABLY - otherwise it returns nothing and the engine's own
	    CMultiPlayerAnimState logic runs (which is the same logic, in C++);
	  * GMod's `ply:GetTable()` state bag is replaced by a weak table here, and
	    `IdleActivityTranslate` is written out by NAME because GMod's `+1/+2/...`
	    arithmetic is only valid against GMod's own activity enum order.
------------------------------------------------------------------------------]]

local plyStates = setmetatable( {}, { __mode = "k" } )

local function State( ply )
	local t = plyStates[ ply ]
	if ( !t ) then t = {}; plyStates[ ply ] = t end
	return t
end

local function IsFunction( v ) return type( v ) == "function" end
local function GmHas( name ) return _GAMEMODE != nil and IsFunction( _GAMEMODE[ name ] ) end

-- IsValid() is a GMod global; guard it so a missing one cannot throw.
local function IsValidEnt( v )
	if ( IsFunction( IsValid ) ) then return IsValid( v ) end
	return v != nil
end

-- Activity table: GMod's IdleActivityTranslate, by name.
-- GMod uses `ACT_HL2MP_IDLE + n`; our enum order differs, so map explicitly.
-- Entries are only added when BOTH names are published (the engine publishes the
-- activity list as flat ACT_* globals), so a missing one is a no-op instead of a
-- "table index is nil" error at load time.
local IdleActivityTranslate = {}

local function Map( mp, hl2mp )
	if ( mp != nil and hl2mp != nil ) then
		IdleActivityTranslate[ mp ] = hl2mp
	end
end

Map( ACT_MP_STAND_IDLE,					ACT_HL2MP_IDLE )
Map( ACT_MP_WALK,						ACT_HL2MP_WALK )
Map( ACT_MP_RUN,						ACT_HL2MP_RUN )
Map( ACT_MP_CROUCH_IDLE,				ACT_HL2MP_IDLE_CROUCH )
Map( ACT_MP_CROUCHWALK,					ACT_HL2MP_WALK_CROUCH )
Map( ACT_MP_ATTACK_STAND_PRIMARYFIRE,	ACT_HL2MP_GESTURE_RANGE_ATTACK )
Map( ACT_MP_ATTACK_CROUCH_PRIMARYFIRE,	ACT_HL2MP_GESTURE_RANGE_ATTACK )
Map( ACT_MP_RELOAD_STAND,				ACT_HL2MP_GESTURE_RELOAD )
Map( ACT_MP_RELOAD_CROUCH,				ACT_HL2MP_GESTURE_RELOAD )
Map( ACT_MP_JUMP,						ACT_HL2MP_JUMP )
Map( ACT_MP_SWIM,						ACT_HL2MP_SWIM )
Map( ACT_LAND,							ACT_LAND )

-- Optional engine API.  Each returns nil when the engine cannot answer, and the
-- callers below then let the C++ side decide instead of guessing.
local function OnGround( ply )
	if ( IsFunction( ply.IsOnGround ) ) then return ply:IsOnGround() end
	if ( IsFunction( ply.OnGround ) ) then return ply:OnGround() end
	if ( IsFunction( ply.GetFlags ) and FL_ONGROUND != nil ) then
		return bit.band( ply:GetFlags(), FL_ONGROUND ) != 0
	end
	return nil
end

local function Ducking( ply )
	if ( IsFunction( ply.IsFlagSet ) and FL_ANIMDUCKING != nil ) then
		return ply:IsFlagSet( FL_ANIMDUCKING )
	end
	if ( IsFunction( ply.IsDucking ) ) then return ply:IsDucking() end
	return nil
end

local function WaterLevel( ply )
	if ( IsFunction( ply.WaterLevel ) ) then return ply:WaterLevel() end
	return nil
end

local function MoveType( ply )
	if ( IsFunction( ply.GetMoveType ) ) then return ply:GetMoveType() end
	return nil
end

local function InVehicle( ply )
	if ( IsFunction( ply.InVehicle ) ) then return ply:InVehicle() end
	return false
end

local function LookupSequence( ply, name )
	if ( IsFunction( ply.LookupSequence ) ) then return ply:LookupSequence( name ) end
	return -1
end

local function TranslateWeaponActivity( ply, act )
	if ( IsFunction( ply.TranslateWeaponActivity ) ) then return ply:TranslateWeaponActivity( act ) end
	return act
end

--====================================================================
-- GM:HandlePlayerLanding( ply, velocity, wasOnGround )
--====================================================================
local function HandlePlayerLanding( ply, velocity, wasOnGround )
	if ( MoveType( ply ) == MOVETYPE_NOCLIP ) then return end

	local onGround = OnGround( ply )
	if ( onGround == nil ) then
		-- Cannot tell - let the engine's gesture code handle the landing.
		return
	end

	if ( onGround and !wasOnGround and ACT_LAND != nil ) then
		ply:AnimRestartGesture( GESTURE_SLOT_JUMP, ACT_LAND, true )
	end
end

--====================================================================
-- GM:HandlePlayerJumping( ply, velocity, plyTable )
--   airwalk until the horizontal speed is gone, then jump, and stay on the jump
--   activity until we land or hit water.
--====================================================================
local function HandlePlayerJumping( ply, velocity, plyTable )
	local onGround = OnGround( ply )
	if ( onGround == nil ) then return nil end

	local water = WaterLevel( ply )
	if ( water == nil ) then water = 0 end

	if ( MoveType( ply ) == MOVETYPE_NOCLIP ) then
		plyTable.m_bJumping = false
		return false
	end

	if ( !plyTable.m_bJumping and !onGround and water <= 0 ) then
		if ( !plyTable.m_fGroundTime ) then
			plyTable.m_fGroundTime = CurTime()
		elseif ( ( CurTime() - plyTable.m_fGroundTime ) > 0 and velocity:Length2DSqr() < 0.25 ) then
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

		if ( water >= 2 or ( ( CurTime() - plyTable.m_flJumpStartTime ) > 0.2 and onGround ) ) then
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

--====================================================================
-- GM:HandlePlayerDucking( ply, velocity, plyTable )
--   GMod tests FL_ANIMDUCKING (raised when the crouch STARTS), not FL_DUCKING.
--====================================================================
local function HandlePlayerDucking( ply, velocity, plyTable )
	local ducking = Ducking( ply )
	if ( ducking == nil ) then return nil end
	if ( !ducking ) then return false end

	if ( velocity:Length2DSqr() > 0.25 ) then
		plyTable.CalcIdeal = ACT_MP_CROUCHWALK
	else
		plyTable.CalcIdeal = ACT_MP_CROUCH_IDLE
	end

	return true
end

--====================================================================
-- GM:HandlePlayerNoClipping / Vaulting / Swimming
--====================================================================
local function HandlePlayerNoClipping( ply, velocity, plyTable )
	local mt = MoveType( ply )
	if ( mt == nil ) then return nil end

	if ( mt != MOVETYPE_NOCLIP or InVehicle( ply ) ) then
		if ( plyTable.m_bWasNoclipping ) then
			plyTable.m_bWasNoclipping = nil
			ply:AnimResetGestureSlot( GESTURE_SLOT_CUSTOM )
		end
		return false
	end

	if ( !plyTable.m_bWasNoclipping and ACT_GMOD_NOCLIP_LAYER != nil ) then
		ply:AnimRestartGesture( GESTURE_SLOT_CUSTOM, ACT_GMOD_NOCLIP_LAYER, false )
	end

	plyTable.CalcIdeal = ACT_MP_STAND_IDLE
	return true
end

local function HandlePlayerVaulting( ply, velocity, plyTable )
	if ( velocity:LengthSqr() < 1000000 ) then return false end
	local onGround = OnGround( ply )
	if ( onGround == nil ) then return nil end
	if ( onGround ) then return false end

	plyTable.CalcIdeal = ACT_MP_SWIM
	return true
end

local function HandlePlayerSwimming( ply, velocity, plyTable )
	local water = WaterLevel( ply )
	if ( water == nil ) then return nil end

	local onGround = OnGround( ply )
	if ( onGround == nil ) then return nil end

	if ( water < 2 or onGround ) then
		plyTable.m_bInSwim = false
		return false
	end

	plyTable.CalcIdeal = ACT_MP_SWIM
	plyTable.m_bInSwim = true
	return true
end

--====================================================================
-- GM:HandlePlayerDriving( ply, plyTable )
--   drive_jeep -> drive_airboat -> drive_pd -> sit_rollercoaster -> sit_<holdtype>
--====================================================================
local function HandlePlayerDriving( ply, plyTable )
	if ( !InVehicle( ply ) ) then return false end
	if ( !IsFunction( ply.GetVehicle ) ) then return false end

	local pVehicle = ply:GetVehicle()
	if ( !IsValidEnt( pVehicle ) ) then return false end

	local class = pVehicle.GetClass and pVehicle:GetClass() or ""
	local seq = -1

	if ( class == "prop_vehicle_jeep" ) then
		seq = LookupSequence( ply, "drive_jeep" )
	elseif ( class == "prop_vehicle_airboat" ) then
		seq = LookupSequence( ply, "drive_airboat" )
	elseif ( class == "prop_vehicle_prisoner_pod" ) then
		seq = LookupSequence( ply, "drive_pd" )
	end

	if ( seq < 0 ) then seq = LookupSequence( ply, "sit_rollercoaster" ) end
	if ( seq < 0 ) then seq = LookupSequence( ply, "sit" ) end
	if ( seq < 0 ) then return false end

	-- "sit_" .. holdtype, but only when the vehicle allows weapons
	if ( ply.GetAllowWeaponsInVehicle and ply:GetAllowWeaponsInVehicle() and
	     IsFunction( ply.GetActiveWeapon ) ) then
		local pWeapon = ply:GetActiveWeapon()
		if ( IsValidEnt( pWeapon ) and IsFunction( pWeapon.GetHoldType ) ) then
			local holdtype = pWeapon:GetHoldType()
			if ( holdtype == "smg" ) then holdtype = "smg1" end

			local seqid = LookupSequence( ply, "sit_" .. tostring( holdtype ) )
			if ( seqid != -1 ) then seq = seqid end
		end
	end

	plyTable.CalcSeqOverride = seq
	return true
end

--====================================================================
-- hook: CalcMainActivity( ply, velocity ) -> activity, seqOverride
--   GMod order: Landing (always), then noclip / driving / vaulting / jumping /
--   swimming / ducking, then walk / run / idle.
--====================================================================
local function CalcMainActivity( ply, velocity )
	if ( GmHas( "CalcMainActivity" ) ) then return end

	local plyTable = State( ply )
	plyTable.CalcIdeal = ACT_MP_STAND_IDLE
	plyTable.CalcSeqOverride = -1

	HandlePlayerLanding( ply, velocity, plyTable.m_bWasOnGround )

	local handled = HandlePlayerNoClipping( ply, velocity, plyTable ) or
	                HandlePlayerDriving( ply, plyTable ) or
	                HandlePlayerVaulting( ply, velocity, plyTable ) or
	                HandlePlayerJumping( ply, velocity, plyTable ) or
	                HandlePlayerSwimming( ply, velocity, plyTable ) or
	                HandlePlayerDucking( ply, velocity, plyTable )

	local onGround = OnGround( ply )

	if ( !handled ) then
		if ( onGround == nil ) then
			-- Not enough information: let the engine decide.
			return
		end

		local len2d = velocity:Length2DSqr()
		if ( len2d > 22500 ) then
			plyTable.CalcIdeal = ACT_MP_RUN
		elseif ( len2d > 0.25 ) then
			plyTable.CalcIdeal = ACT_MP_WALK
		end
	end

	plyTable.m_bWasOnGround = ( onGround == true )
	plyTable.m_bWasNoclipping = ( MoveType( ply ) == MOVETYPE_NOCLIP and !InVehicle( ply ) )

	return plyTable.CalcIdeal, plyTable.CalcSeqOverride
end

--====================================================================
-- hook: TranslateActivity( ply, act ) -> act
--   GMod: through the weapon first; if the weapon had no opinion, use the idle
--   activity table above.
--====================================================================
local function TranslateActivity( ply, act )
	if ( GmHas( "TranslateActivity" ) ) then return end

	-- The WEAPON decides first, and that step needs the engine
	-- (Player:TranslateWeaponActivity).  Without it the model would fall back to the
	-- bare - i.e. UNARMED - ACT_HL2MP_* activity, which is exactly the
	-- "holding a gun but playing the no-weapon animation" report.  If the engine
	-- cannot do it, stay silent and let the C++ translation do the whole job.
	if ( !IsFunction( ply.TranslateWeaponActivity ) ) then return end

	local newact = ply:TranslateWeaponActivity( act )

	if ( act == newact ) then
		return IdleActivityTranslate[ act ]
	end

	return newact
end

--====================================================================
-- hook: UpdateAnimation( ply, velocity, maxseqgroundspeed )
--   playback rate, and the vehicle pose parameters.
--====================================================================
local function UpdateAnimation( ply, velocity, maxseqgroundspeed )
	if ( GmHas( "UpdateAnimation" ) ) then return end

	local len = velocity:Length()
	local movement = 1.0

	if ( len > 0.2 and maxseqgroundspeed and maxseqgroundspeed > 0 ) then
		movement = ( len / maxseqgroundspeed )
	end

	local rate = math.min( movement, 2 )

	local water = WaterLevel( ply )
	if ( water != nil and water >= 2 ) then
		rate = math.max( rate, 0.5 )
	elseif ( OnGround( ply ) == false and len >= 1000 ) then
		rate = 0.1
	end

	if ( IsFunction( ply.SetPlaybackRate ) ) then
		ply:SetPlaybackRate( rate )
	end
end

--====================================================================
-- hook: DoAnimationEvent( ply, event, data ) -> activity (for the view model)
--   GMod plays the gesture on the attack/reload slot; the engine still runs its
--   own CMultiPlayerAnimState::DoAnimationEvent() afterwards.
--====================================================================
local function DoAnimationEvent( ply, event, data )
	if ( GmHas( "DoAnimationEvent" ) ) then return end

	local ducking = Ducking( ply ) and true or false

	if ( event == PLAYERANIMEVENT_ATTACK_PRIMARY ) then
		if ( ducking ) then
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_CROUCH_PRIMARYFIRE, true )
		else
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_STAND_PRIMARYFIRE, true )
		end

		return ACT_VM_PRIMARYATTACK

	elseif ( event == PLAYERANIMEVENT_ATTACK_SECONDARY ) then
		-- no gesture of its own, just the view model event
		return ACT_VM_SECONDARYATTACK

	elseif ( event == PLAYERANIMEVENT_RELOAD ) then
		if ( ducking ) then
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_CROUCH, true )
		else
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_STAND, true )
		end

		return ACT_INVALID

	elseif ( event == PLAYERANIMEVENT_JUMP ) then
		local plyTable = State( ply )
		plyTable.m_bJumping = true
		plyTable.m_bFirstJumpFrame = true
		plyTable.m_flJumpStartTime = CurTime()

		ply:AnimRestartMainSequence()

		return ACT_INVALID

	elseif ( event == PLAYERANIMEVENT_CANCEL_RELOAD ) then
		ply:AnimResetGestureSlot( GESTURE_SLOT_ATTACK_AND_RELOAD )

		return ACT_INVALID
	end
end

hook.add( "CalcMainActivity", "hl2sb_animations", CalcMainActivity )
-- NOTE: TranslateActivity is deliberately NOT hooked: our engine's own
-- CMultiPlayerAnimState translation already does GMod's order correctly
-- (ACT_MP_* -> ACT_HL2MP_* by name, THEN the weapon hold type), while the weapon
-- table is keyed on ACT_HL2MP_* - translating the ACT_MP_* value first never
-- matches and left the model in the bare/unarmed pose. See hl2mp_playeranimstate.cpp.
hook.add( "UpdateAnimation", "hl2sb_animations", UpdateAnimation )
hook.add( "DoAnimationEvent", "hl2sb_animations", DoAnimationEvent )
