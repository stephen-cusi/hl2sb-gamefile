-- ===========================================================================
-- HL2SB player animation port test (2026-09-27).
--   Server: lua_dofile player_anim_test.lua
--   Client: lua_dofile_cl player_anim_test.lua   (or _cl variant)
-- Prints PASS/FAIL lines and PLAYER_ANIM_TEST_DONE.
-- ===========================================================================--

local nPass, nFail = 0, 0
local function Check( name, ok )
	if ( ok ) then nPass = nPass + 1; print( "[PASS] " .. name )
	else nFail = nFail + 1; print( "[FAIL] " .. name ) end
end

local ply
if ( CLIENT ) then
	ply = LocalPlayer()
else
	-- server: player.GetAll() exists; the guard keeps the client chunk from
	-- touching it (client has no player library table at all).
	ply = ( player ~= nil and player.GetAll ~= nil ) and player.GetAll()[1] or nil
end

Check( "player found", ply ~= nil )

-- Enum publication (luaopen_GESTURE_SLOT extension)
Check( "enum GESTURE_SLOT_VCD", GESTURE_SLOT_VCD ~= nil )
Check( "enum PLAYERANIMEVENT_ATTACK_PRIMARY", PLAYERANIMEVENT_ATTACK_PRIMARY ~= nil )
Check( "enum PLAYERANIMEVENT_CANCEL_RELOAD", PLAYERANIMEVENT_CANCEL_RELOAD ~= nil )
Check( "enum PLAYERANIMEVENT_CUSTOM_SEQUENCE", PLAYERANIMEVENT_CUSTOM_SEQUENCE ~= nil )

-- Movement speed bindings
Check( "GetRunSpeed default 400", ply:GetRunSpeed() == 400 )
Check( "GetWalkSpeed default 150", ply:GetWalkSpeed() == 150 )
ply:SetRunSpeed( 510 )
ply:SetWalkSpeed( 130 )
Check( "SetRunSpeed roundtrip", ply:GetRunSpeed() == 510 )
Check( "SetWalkSpeed roundtrip", ply:GetWalkSpeed() == 130 )
ply:SetRunSpeed( 400 )
ply:SetWalkSpeed( 150 )

Check( "GetSlowWalkSpeed", ply:GetSlowWalkSpeed() == 100 )
Check( "GetJumpPower default 0", ply:GetJumpPower() == 0 )
ply:SetJumpPower( 300 )
Check( "SetJumpPower roundtrip", ply:GetJumpPower() == 300 )
ply:SetJumpPower( 0 )
Check( "GetStepSize", ply:GetStepSize() ~= nil )
Check( "GetAllowWeaponsInVehicle false", ply:GetAllowWeaponsInVehicle() == false )
Check( "GetLadderClimbSpeed", ply:GetLadderClimbSpeed() ~= nil )

-- Gesture bindings must not error (server runs the layer work)
ply:AnimRestartMainSequence()
Check( "AnimRestartMainSequence no error", true )

if ( SERVER ) then
	ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_STAND_PRIMARYFIRE, true )
	Check( "AnimRestartGesture no error", true )
	ply:AnimSetGestureWeight( GESTURE_SLOT_ATTACK_AND_RELOAD, 0.5 )
	Check( "AnimSetGestureWeight no error", true )
	ply:AnimResetGestureSlot( GESTURE_SLOT_ATTACK_AND_RELOAD )
	Check( "AnimResetGestureSlot no error", true )
end

Check( "IsPlayingTaunt boolean", isbool( ply:IsPlayingTaunt() ) )
Check( "IsTyping boolean", isbool( ply:IsTyping() ) )
Check( "IsSpeaking boolean", isbool( ply:IsSpeaking() ) )
Check( "VoiceVolume number", isnumber( ply:VoiceVolume() ) )
Check( "TranslateWeaponActivity number", isnumber( ply:TranslateWeaponActivity( ACT_MP_RUN ) ) )

-- Programmatic animation event (server: hook + stock mapping; client: no-op)
ply:DoAnimationEvent( PLAYERANIMEVENT_ATTACK_PRIMARY )
Check( "DoAnimationEvent no error", true )

-- Gamemode glue loaded (animations.lua port)
Check( "GM:CalcMainActivity defined", isfunction( GAMEMODE.CalcMainActivity ) )
Check( "GM:UpdateAnimation defined", isfunction( GAMEMODE.UpdateAnimation ) )
Check( "GM:TranslateActivity defined", isfunction( GAMEMODE.TranslateActivity ) )
Check( "GM:DoAnimationEvent defined", isfunction( GAMEMODE.DoAnimationEvent ) )

-- Direct gamemode call: CalcMainActivity answers ACT_MP_* + override
if ( GAMEMODE.CalcMainActivity ~= nil ) then
	local ideal, ovr = GAMEMODE:CalcMainActivity( ply, Vector( 0, 0, 0 ) )
	Check( "CalcMainActivity idle ACT_MP_STAND_IDLE", ideal == ACT_MP_STAND_IDLE )
	Check( "CalcMainActivity override -1", ovr == -1 )
end

-- ==========================================================================
-- Attack / reload event contract.  GM:DoAnimationEvent must return the
-- viewmodel activity for a fire (ACT_VM_PRIMARYATTACK) and answer (not error)
-- for a reload, and must call AnimRestartGesture on the player - that call is
-- what puts the gesture on GESTURE_SLOT_ATTACK_AND_RELOAD.  The engine gates the
-- whole dispatch on this returning a number, so a nil here means fire/reload
-- animate nothing (the report this covers).
-- ==========================================================================
if ( GAMEMODE.DoAnimationEvent ~= nil ) then
	Check( "DoAnimationEvent(attack) -> ACT_VM_PRIMARYATTACK",
		GAMEMODE:DoAnimationEvent( ply, PLAYERANIMEVENT_ATTACK_PRIMARY, 0 ) == ACT_VM_PRIMARYATTACK )
	Check( "DoAnimationEvent(attack secondary) -> ACT_VM_SECONDARYATTACK",
		GAMEMODE:DoAnimationEvent( ply, PLAYERANIMEVENT_ATTACK_SECONDARY, 0 ) == ACT_VM_SECONDARYATTACK )
	Check( "DoAnimationEvent(reload) -> ACT_INVALID",
		GAMEMODE:DoAnimationEvent( ply, PLAYERANIMEVENT_RELOAD, 0 ) == ACT_INVALID )
	Check( "DoAnimationEvent(jump) -> ACT_INVALID",
		GAMEMODE:DoAnimationEvent( ply, PLAYERANIMEVENT_JUMP, 0 ) == ACT_INVALID )
end

-- ==========================================================================
-- Crouch path (the "some weapons lose their crouch animation" report).
-- FL_ANIMDUCKING is published by the fork as FL_ANIMDUCKING / DUCKING_ANIMATION.
-- ==========================================================================
-- The fork raises FL_DUCKING (FL_ANIMDUCKING is never set by HL2 movement).
local FL_ANIMDUCK = FL_DUCKING or DUCKING or 2

if ( SERVER and GAMEMODE.HandlePlayerDucking ~= nil ) then
	ply:AddFlag( FL_ANIMDUCK )

	-- not moving -> crouch idle, moving -> crouch walk
	GAMEMODE:HandlePlayerDucking( ply, Vector( 0, 0, 0 ), nil )
	local t1 = ply:GetTable()
	Check( "duck idle -> ACT_MP_CROUCH_IDLE", t1.CalcIdeal == ACT_MP_CROUCH_IDLE )

	GAMEMODE:HandlePlayerDucking( ply, Vector( 100, 0, 0 ), nil )
	local t2 = ply:GetTable()
	Check( "duck moving -> ACT_MP_CROUCHWALK", t2.CalcIdeal == ACT_MP_CROUCHWALK )

	-- the whole CalcMainActivity chain with the duck flag set
	local idealDuck = GAMEMODE:CalcMainActivity( ply, Vector( 100, 0, 0 ) )
	Check( "CalcMainActivity ducking -> crouchwalk", idealDuck == ACT_MP_CROUCHWALK )

	-- ... and the activity that reaches the C++ sequence pin resolves to the
	-- HL2MP crouch family (the hold-type suffix is added by the weapon acttable;
	-- a result still equal to ACT_MP_* means the weapon/fallback chain is broken,
	-- which is what drops cwalk_<holdtype> and hides the crouch animation).
	local crouchAct = GAMEMODE:TranslateActivity( ply, ACT_MP_CROUCHWALK )
	Check( "TranslateActivity crouchwalk resolves to HL2MP family", crouchAct ~= nil and crouchAct ~= ACT_MP_CROUCHWALK )

	-- ... and it must land in the CROUCH family.  GMod's original
	-- IdleActivityTranslate used ARITHMETIC (ACT_HL2MP_IDLE + 4), but this fork's
	-- HL2MP enum head is IDLE, RUN, IDLE_CROUCH, WALK_CROUCH,
	-- GESTURE_RANGE_ATTACK (ACT_HL2MP_WALK is appended at the very end of the
	-- enum), so +4 selected ACT_HL2MP_GESTURE_RANGE_ATTACK - an attack gesture with
	-- no crouch sequence: the "some weapons lose their crouch animation" report.
	-- It only hit weapons that reached the fallback (addon SWEPs with no ACT_MP_*
	-- acttable), which is why it was "some" weapons.
	local names = {}
	if ( _E ~= nil and _E.ACTIVITY ~= nil ) then
		for k, v in pairs( _E.ACTIVITY ) do names[ v ] = k end
	end
	local nm = names[ crouchAct ] or "?"
	Check( "crouchwalk activity is a crouch pose (got " .. nm .. ")", nm:find( "CROUCH" ) ~= nil )

	ply:RemoveFlag( FL_ANIMDUCK )
end

print( string.format( "PLAYER_ANIM_TEST_RESULT %d passed / %d failed", nPass, nFail ) )
print( "PLAYER_ANIM_TEST_DONE" )
