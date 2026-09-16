--========== HL2SB - GMod compat ==========--
--
-- Purpose: ENT.Type = "nextbot" - the Lua base class a GMod nextbot addon
--          derives from, the counterpart of gamemodes/base/entities/entities/
--          base_nextbot in Garry's Mod.
--
--   THIS FILE IS THE START OF EVERY GMod NEXTBOT.  An addon says
--
--       ENT.Base = "base_nextbot"
--       ENT.Type = "nextbot"
--
--   and gets: a real INextBot in the engine (game/server/lua/luanextbot.cpp,
--   reached through the __factory below), a behaviour coroutine that the engine
--   resumes every frame, a locomotion object on self.loco, and the ENT:On*
--   callbacks the engine raises.
--
--   The API implemented here is the one documented for base_nextbot (and the
--   one real addons use, e.g. SCP-096's MoveToPos/BehaveUpdate/hook calls).  The
--   code is written against this fork's engine surface - see the notes where a
--   name differs.
--===========================================================================--

ENT.__base			= "base_nextbot"
ENT.PrintName		= "NextBot base"
ENT.Author			= ""
ENT.Contact			= ""
ENT.Purpose			= ""
ENT.Instructions	= ""

-- HL2SB: the engine factory.  luamanager.cpp reads ENT.__factory after loading
-- the script and calls into the engine with that name; "CLuaNextBot" is what
-- gives the entity a real INextBot (NextBotCombatCharacter + locomotion +
-- intention + event responders).  prop_scripted uses the same mechanism to ask
-- for plain scripted entities ("CBaseAnimating").
ENT.__factory		= "CLuaNextBot"
ENT.Type			= "nextbot"

-- Server side: all of the AI lives there (see sv_nextbot.lua).
if ( SERVER ) then
	include( "sv_nextbot.lua" )
else
	--[[---------------------------------------------------------
		Name: Draw
		Desc: Draw the bot's model on the client
	-----------------------------------------------------------]]
	function ENT:Draw( flags )
		self:DrawModel( flags )
	end

	--[[---------------------------------------------------------
		Name: DrawTranslucent
		Desc: Kept for backwards compatibility with GMod addons
	-----------------------------------------------------------]]
	function ENT:DrawTranslucent( flags )
		self:Draw( flags )
	end

	--[[---------------------------------------------------------
		Name: FireAnimationEvent
		Desc: Called for every animation event; return true to suppress it
	-----------------------------------------------------------]]
	function ENT:FireAnimationEvent( pos, ang, event, options )
	end
end
