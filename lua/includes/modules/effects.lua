local ents = ents
local pairs = pairs
local ipairs = ipairs
local string = string
local table = table
-- HL2SB: effects.TracerSound needs these; module() below replaces the chunk
-- environment with the module table, so globals must be captured as upvalues
-- before it runs.
local util = util
local EffectData = EffectData
local Msg = Msg

--[[---------------------------------------------------------
   Name: effects
   Desc: Engine effects hooking
-----------------------------------------------------------]]
module( "effects" )

local EffectList = {}

function Register( t, name )

	name = string.lower( name )

	local old = EffectList[ name ]

	EffectList[ name ] = t

	--
	-- If we're reloading this entity class
	-- then refresh all the existing entities.
	--
	if ( old != nil ) then

		--
		-- For each entity using this class
		--
		for _, entity in ipairs( ents.FindByClass( name ) ) do

			--
			-- Replace the contents with this entity table
			--
			table.Merge( entity, t )

		end

	end

end

function Create( name, retval )

	name = string.lower( name )

	--Msg( "Create.. ".. name .. "\n" )

	if ( EffectList[ name ] == nil ) then return nil end

	local NewEffect = retval or {}

	for k, v in pairs( EffectList[ name ] ) do

		NewEffect[ k ] = v

	end

	table.Merge( NewEffect, EffectList[ "base" ] )

	return NewEffect

end

function GetList()

	local result = {}

	for k, v in pairs( EffectList ) do
		table.insert( result, v )
	end

	return result

end

--[[---------------------------------------------------------
   Name: TracerSound( startPos, endPos, tracertype, soundOverride )
   Desc: Imitates the "near miss" tracer sound.
         tracertype: 1 = normal bullet, 2 = gunship, 4 = strider, 8 = underwater
         (shareddefs.h's TRACER_TYPE_*, passed through EffectData flags).
         soundOverride is accepted for GMod signature compatibility but NOT
         supported: this engine's TracerSound callback (fx_tracer.cpp) picks
         its own sounds.
-----------------------------------------------------------]]
function TracerSound( startPos, endPos, tracertype, soundOverride )

	local data = EffectData()
	data:SetStart( startPos )
	data:SetOrigin( endPos )
	data:SetFlags( tracertype or 1 )

	util.Effect( "TracerSound", data )

	if ( soundOverride != nil ) then
		Msg( "effects.TracerSound: soundOverride is not supported by this engine\n" )
	end

end
