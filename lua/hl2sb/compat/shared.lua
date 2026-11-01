include( "hl2sb/compat/gamemode.lua" )
include( "hl2sb/compat/motionsensor.lua" )
-- Shared native aliases and scripted-effect compatibility.

if ( _E ~= nil ) then
	local hl2sb_EnumStubs = {
		"ACTIVITY", "BUTTON", "INPUT", "CONTENTS", "COLLISION_GROUP", "FCVAR",
		"EDICT_FLAG", "SOLID_FLAG", "SOLID", "SOUND_CHANNEL", "SURFACE",
		"DAMAGE_TYPE", "HIT_GROUP", "MATERIAL_TYPE", "ENTITY_EFFECT", "ENGINE_FLAG",
	}

	for _, hl2sb_Key in ipairs( hl2sb_EnumStubs ) do
		if ( not _E[ hl2sb_Key ] ) then
			_E[ hl2sb_Key ] = {}
		end
	end
end


include( "hl2sb/compat/enumerations.lua" )
include( "hl2sb/compat/player_manager.lua" )

include( "hl2sb/compat/sandbox.lua" )
