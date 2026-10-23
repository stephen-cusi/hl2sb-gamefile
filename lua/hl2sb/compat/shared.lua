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

local hl2sb_EntityMeta = FindMetaTable( "Entity" )

if ( hl2sb_EntityMeta ~= nil and hl2sb_EntityMeta.SetNoDraw == nil ) then
	local hl2sb_NoDraw = EF_NODRAW or 32

	--- GMod: toggles EF_NODRAW on the entity.
	function hl2sb_EntityMeta:SetNoDraw( b )
		if ( b ) then
			self:AddEffects( hl2sb_NoDraw )
		else
			self:RemoveEffects( hl2sb_NoDraw )
		end
	end

	function hl2sb_EntityMeta:GetNoDraw()
		return self:IsEffectActive( hl2sb_NoDraw )
	end

	Msg( "[HL2SB]   Entity:SetNoDraw / GetNoDraw added (EF_NODRAW=" .. tostring( hl2sb_NoDraw ) .. ")\n" )
end


if ( CLIENT and type( effects ) == "table" and type( effects.Register ) == "function" ) then
	local hl2sb_OldEffectRegister = effects.Register
	local hl2sb_EffectIDs = setmetatable( {}, { __mode = "k" } )
	local hl2sb_NextEffectID = 0

	function effects.Register( t, name )
		if ( type( t ) == "table" ) then
			if ( t.EntIndex == nil ) then
				function t:EntIndex()
					local id = hl2sb_EffectIDs[ self ]
					if ( id == nil ) then
						hl2sb_NextEffectID = ( hl2sb_NextEffectID + 1 ) % 255
						hl2sb_EffectIDs[ self ] = hl2sb_NextEffectID
						id = hl2sb_NextEffectID
					end

					return id
				end
			end

			if ( t.SetRenderMode == nil ) then
				function t:SetRenderMode( mode )
					self.__hl2sb_rendermode = mode
				end
			end

			if ( t.SetRenderFX == nil ) then
				function t:SetRenderFX( fx )
					self.__hl2sb_renderfx = fx
				end
			end
		end

		return hl2sb_OldEffectRegister( t, name )
	end

	Msg( "[HL2SB]   EFFECT:EntIndex / SetRenderMode / SetRenderFX added\n" )
end
