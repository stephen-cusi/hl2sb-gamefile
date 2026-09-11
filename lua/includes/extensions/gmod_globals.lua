--[[----------------------------------------------------------------------------
    gmod_globals.lua

    GMod-style global helpers for HL2SB.

    The Team Sandbox Lua SDK exposes most things as *libraries* (gpGlobals.curtime,
    surface.GetScreenSize, global ConVar(...)), while GMod scripts call plain free
    functions (CurTime, ScrW, GetConVar, ...).  This file bridges just the ones
    that are pure Lua / already-backend and can be done without touching an
    entity binding, so stock GMod scripts load without "attempt to call global
    'CurTime' (a nil value)".

    Note: LocalPlayer() / IsValid() in their Entity form need a client entity
    binding and the entity-iteration set (ents.GetAll / player.GetAll), which are
    intentionally NOT defined here - they belong with the C++ entity work.

    Loaded every level from lua/includes/extensions/.
-----------------------------------------------------------------------------]]--

-- ===========================================================================
-- HL2SB GMod SWEP compat: activity / player-animation constants + Angle
-- constructor.  These must exist before any weapon script loads (weapons are
-- walked after includes/), and GMod SWEPs use the ACT_VM_* / ACT_MP_* / PLAYER_*
-- symbols directly.  Values come from Source's ai_activity.h / shareddefs.h
-- Activity + PLAYER_ANIM enums.
-- ===========================================================================
Angle = Angle or QAngle

-- ===========================================================================
-- Sound( path )  (GMod global, both realms)
--
-- GMod's Sound() returns a sound object that EmitSound/PlaySound accept.  HL2SB
-- has no such global and its EmitSound takes the PATH STRING directly, so a
-- stock GMod SWEP doing `self:EmitSound( Sound( self.Primary.Sound ) )` died on
-- "attempt to call a nil value (global 'Sound')" -- a red error in the console
-- that also skipped everything after it in that function (pist_weagon's
-- SetNextPrimaryFire, so its fire rate was never armed).
--
-- Returning the path is exactly what AGENTS.md 9.6 tells hand-ported scripts to
-- do by hand; providing the global means the pristine addon works unmodified.
-- ===========================================================================
if ( Sound == nil ) then
	function Sound( path )
		return path
	end
end

ACT_INVALID			= -1
ACT_VM_DRAW			= 171
ACT_VM_HOLSTER		= 172
ACT_VM_IDLE			= 173
ACT_VM_FIDGET		= 174
ACT_VM_PRIMARYATTACK	= 180
ACT_VM_SECONDARYATTACK	= 181
ACT_VM_RELOAD		= 182
ACT_VM_DRYFIRE		= 185

ACT_HL2MP_IDLE		= 988
ACT_HL2MP_RUN		= 989
ACT_HL2MP_IDLE_CROUCH	= 990
ACT_HL2MP_WALK_CROUCH	= 991
ACT_HL2MP_GESTURE_RANGE_ATTACK	= 992
ACT_HL2MP_GESTURE_RELOAD	= 993
ACT_HL2MP_JUMP		= 994

ACT_HL2MP_IDLE_PISTOL	= 995
ACT_HL2MP_RUN_PISTOL	= 996
ACT_HL2MP_IDLE_CROUCH_PISTOL	= 997
ACT_HL2MP_WALK_CROUCH_PISTOL	= 998
ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL	= 999
ACT_HL2MP_GESTURE_RELOAD_PISTOL	= 1000
ACT_HL2MP_JUMP_PISTOL	= 1001
ACT_RANGE_ATTACK1	= 16
ACT_RANGE_ATTACK_PISTOL	= 288

ACT_MP_STAND_PRIMARY	= 1119
ACT_MP_RELOAD_STAND	= 1100
ACT_MP_STAND_SECONDARY	= 1184

PLAYER_IDLE	= 0
PLAYER_WALK	= 1
PLAYER_JUMP	= 2
PLAYER_SUPERJUMP	= 3
PLAYER_DIE	= 4
PLAYER_ATTACK1	= 5
PLAYER_IN_VEHICLE	= 6
PLAYER_RELOAD	= 8
PLAYER_START_AIMING	= 9
PLAYER_LEAVE_AIMING	= 10

-- HL2SB GMod SWEP compat: stock SWEPs call Sound("...") (identity in GMod's
-- C binding) and AddCSLuaFile (HL2SB ships all Lua to both sides already).
Sound = Sound or function( s ) return s end
AddCSLuaFile = AddCSLuaFile or function( ... ) return true end

-- GMod: Model("path") precaches the model on the server and returns the path
-- (identity on the client).  gmod_camera and many workshop SWEPs wrap their
-- ViewModel/WorldModel in Model(...), which used to die with
-- "attempt to call global 'Model' (a nil value)".
Model = Model or function( s )
	if ( not _CLIENT and util and util.PrecacheModel ) then
		util.PrecacheModel( s )
	end
	return s
end

if ( not _CLIENT ) then
	-- Server side has no surface / skin; still bridge time + convar.
	gpGlobals = gpGlobals or _G.gpGlobals

	CurTime  = CurTime  or function() return gpGlobals.curtime() end
	RealTime = RealTime or function() return gpGlobals.realtime() end

	CreateConVar = CreateConVar or function( name, def, flags, help, min, max )
		-- HL2SB: GMod passes FLAGS AS A TABLE, and the engine ConVar takes a
		-- number plus a DIFFERENT positional layout:
		--     GMod    ( name, default, flags, helptext, min, max )
		--     engine  ( name, default, flags, help, bMin, fMin, bMax, fMax )
		-- Passing GMod's min/max straight through put them in boolean slots, and
		-- a flags table produced
		--     gmod_globals.lua:115: bad argument #3 to 'ConVar' (number expected, got table)
		-- which is exactly what killed modules/constraint.lua (52 KB).
		local iFlags = flags
		if ( type( flags ) == "table" ) then
			iFlags = 0
			for _, flag in ipairs( flags ) do
				iFlags = bit.bor( iFlags, flag )
			end
		end

		return ConVar( name, def, iFlags or 0, help, min ~= nil, min or 0, max ~= nil, max or 0 )
	end

	GetConVar = GetConVar or function( name )
		return ConVar( name )
	end

	GetConVarNumber = GetConVarNumber or function( name )
		local c = ConVar( name )
		return c and c:GetFloat() or 0
	end

	GetConVarString = GetConVarString or function( name )
		local c = ConVar( name )
		return c and c:GetString() or ""
	end

	GetConVarBool = GetConVarBool or function( name )
		local c = ConVar( name )
		return c and c:GetBool() or false
	end

	return
end

-- ===========================================================================
-- Client side
-- ===========================================================================

local gpGlobals = gpGlobals

-- Time
CurTime  = CurTime  or function() return gpGlobals.curtime() end
RealTime = RealTime or function() return gpGlobals.realtime() end
FrameTime = FrameTime or function() return gpGlobals.frametime() end

-- Screen size
ScrW = ScrW or function()
	local w = surface.GetScreenSize()
	return w or 0
end
ScrH = ScrH or function()
	local _, h = surface.GetScreenSize()
	return h or 0
end

-- HL2SB: GMod's ScreenScale family.  These are ENGINE globals in GMod (C++),
-- not util.lua helpers -- GMod's own lua/includes/util.lua (ours, byte for
-- byte) does not define them, and lua/includes/notification.lua needs them on
-- line 2:
--
--     local textH = math.max( 12, math.ceil( ScreenScaleH( 9 ) ) )
--
-- Without them that file fails to load completely, which shows up as exactly
-- one [Lua] FAILED line -- that is how the undo notification vanished.
--
-- GMod semantics: ScreenScale and ScreenScaleH scale by height against the
-- 480-unit baseline, ScreenScaleW scales by width against 640.
ScreenScale = ScreenScale or function( size )
	return size * ( ScrH() / 480 )
end

ScreenScaleH = ScreenScaleH or function( size )
	return size * ( ScrH() / 480 )
end

ScreenScaleW = ScreenScaleW or function( size )
	return size * ( ScrW() / 640 )
end

-- ConVar access (see above for the shape)
CreateConVar = CreateConVar or function( name, def, flags, help, min, max )
		-- HL2SB: GMod passes FLAGS AS A TABLE, and the engine ConVar takes a
		-- number plus a DIFFERENT positional layout:
		--     GMod    ( name, default, flags, helptext, min, max )
		--     engine  ( name, default, flags, help, bMin, fMin, bMax, fMax )
		-- Passing GMod's min/max straight through put them in boolean slots, and
		-- a flags table produced
		--     gmod_globals.lua:115: bad argument #3 to 'ConVar' (number expected, got table)
		-- which is exactly what killed modules/constraint.lua (52 KB).
		local iFlags = flags
		if ( type( flags ) == "table" ) then
			iFlags = 0
			for _, flag in ipairs( flags ) do
				iFlags = bit.bor( iFlags, flag )
			end
		end

		return ConVar( name, def, iFlags or 0, help, min ~= nil, min or 0, max ~= nil, max or 0 )
	end

GetConVar = GetConVar or function( name )
	return ConVar( name )
end

GetConVarNumber = GetConVarNumber or function( name )
	local c = ConVar( name )
	return c and c:GetFloat() or 0
end

GetConVarString = GetConVarString or function( name )
	local c = ConVar( name )
	return c and c:GetString() or ""
end

GetConVarBool = GetConVarBool or function( name )
	local c = ConVar( name )
	return c and c:GetBool() or false
end

-- ===========================================================================
-- HL2SB: GMod's SysTime() and RealFrameTime()
--
-- lua/includes/notification.lua uses SysTime() for every notice lifetime --
-- Panel.StartTime = SysTime() (line 83), the timeleft/velocity maths that drives
-- the whole slide-in animation, and KillSelf's StartTime + Length test -- and
-- RealFrameTime() for the friction term and the spring step.
--
-- Neither existed in this fork, so the GMod undo notice died at
--
--     notification.lua:83: attempt to call a nil value (global 'SysTime')
--
-- RealTime() and FrameTime() (defined above, on gpGlobals) are the same
-- quantities here.  Aliased rather than wrapped so a real high-precision
-- SysTime can replace it later without touching notification.lua.
-- ===========================================================================
SysTime = SysTime or RealTime
RealFrameTime = RealFrameTime or FrameTime
