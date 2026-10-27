-- Remaining entity compatibility helpers.
-- Typed data tables use the native slots and the original Entity installer.

local EntityMeta = FindMetaTable( "Entity" )

if ( EntityMeta == nil ) then return end

-- ---------------------------------------------------------------------------
-- GMod's Angle constructor.  This engine publishes the same thing as QAngle
-- (public/lua/mathlib/lvector.cpp QAngle_funcs); GMod scripts -- env_skypaint's
-- siblings, the sky editor family -- spell it Angle( p, y, r ).
-- ---------------------------------------------------------------------------
if ( Angle == nil and QAngle != nil ) then
	Angle = QAngle
	Msg( "[HL2SB]   Angle() global added (QAngle alias)\n" )
end

-- ---------------------------------------------------------------------------
-- render origin / angles
-- ---------------------------------------------------------------------------
if ( EntityMeta.SetRenderOrigin == nil ) then
	function EntityMeta:SetRenderOrigin( v )
		if ( v == nil ) then return end

		self.m_vHL2SBRenderOrigin = v

		if ( self.SetAbsOrigin ) then self:SetAbsOrigin( v ) end
	end

	function EntityMeta:GetRenderOrigin()
		return self.m_vHL2SBRenderOrigin or self:GetAbsOrigin()
	end

	function EntityMeta:SetRenderAngles( a )
		if ( a == nil ) then return end

		self.m_aHL2SBRenderAngles = a

		if ( self.SetAbsAngles ) then self:SetAbsAngles( a ) end
	end

	function EntityMeta:GetRenderAngles()
		return self.m_aHL2SBRenderAngles or self:GetAbsAngles()
	end

	Msg( "[HL2SB]   Entity:SetRenderOrigin / SetRenderAngles added (applied as Abs*)\n" )
end

-- ---------------------------------------------------------------------------
-- deploy speed (a SWEP method in GMod; the weapon IS an entity, so it lives here and is
-- available on both realms)
--
-- GMod wiki: SWEP:SetDeploySpeed( speed ) -- "Sets the deploy speed of the weapon."
-- The cod_c4 SWEP sets 1 in Initialize and again in Deploy ("something keeps setting
-- deploy speed to 4, this is a workaround").  This fork's weapon_base has no deploy-speed
-- concept, so the value is kept on the entity and read back with GetDeploySpeed(); 1 is
-- the normal speed, i.e. the addon's calls are a no-op in the visible sense.
-- ---------------------------------------------------------------------------
if ( EntityMeta.SetDeploySpeed == nil ) then
	-- GMod: SWEP.DeploySpeed is a FIELD on the weapon table ("SWEP.DeploySpeed = 1.4",
	-- terrortown/entities/weapons/weapon_tttbase.lua:120) and SetDeploySpeed is the method
	-- that consumes it.  Do NOT mirror the value onto self.DeploySpeed: an instance
	-- field shadows the DeploySpeed() method of this metatable, so the next
	-- `self:DeploySpeed( speed )` would try to call a number.
	function EntityMeta:SetDeploySpeed( flSpeed )
		self.m_flHL2SBDeploySpeed = tonumber( flSpeed ) or 1
	end

	function EntityMeta:GetDeploySpeed()
		return self.m_flHL2SBDeploySpeed or 1
	end

	-- GMod's weapon_base exposes the same thing as SWEP:DeploySpeed( speed ).
	function EntityMeta:DeploySpeed( flSpeed )
		if ( flSpeed ~= nil ) then self:SetDeploySpeed( flSpeed ) end

		return self:GetDeploySpeed()
	end

	Msg( "[HL2SB]   Entity:SetDeploySpeed / GetDeploySpeed / DeploySpeed added\n" )
end

-- ---------------------------------------------------------------------------
-- GMod's legacy "Networked" spellings for the NW store.  The engine binds
-- SetNWInt/GetNWInt/SetNWBool/GetNWBool/SetNWEntity/GetNWEntity/... ; GMod
-- keeps the pre-13 names (SetNetworkedInt, GetNetworkedBool, ...) as aliases
-- of the same functions, and older addons (portalgun's info_hpd_controller,
-- the SWEP LastPortal slot) use nothing else.
-- ---------------------------------------------------------------------------
if ( EntityMeta.SetNWInt != nil and EntityMeta.SetNetworkedInt == nil ) then
	local NWAliasTypes = { "Int", "Bool", "Float", "String", "Entity", "Vector", "Angle" }

	for _, t in pairs( NWAliasTypes ) do
		if ( EntityMeta[ "SetNW" .. t ] != nil ) then
			EntityMeta[ "SetNetworked" .. t ] = EntityMeta[ "SetNW" .. t ]
			EntityMeta[ "SetNetworked" .. string.lower( t ) ] = EntityMeta[ "SetNW" .. t ]
		end
		if ( EntityMeta[ "GetNW" .. t ] != nil ) then
			EntityMeta[ "GetNetworked" .. t ] = EntityMeta[ "GetNW" .. t ]
			EntityMeta[ "GetNetworked" .. string.lower( t ) ] = EntityMeta[ "GetNW" .. t ]
		end
	end

	Msg( "[HL2SB]   Entity:SetNetworked*/GetNetworked* aliases added\n" )
end

-- ---------------------------------------------------------------------------
-- CRecipientFilter short spellings.  The engine binds AddRecipientsByPVS /
-- AddRecipientsByPAS; GMod keeps the short forms AddPVS / AddPAS (the
-- portalgun's in-portal footsteps build their recipient filter with them).
-- ---------------------------------------------------------------------------
local RecipientFilterMeta = FindMetaTable( "CRecipientFilter" )
if ( RecipientFilterMeta != nil and RecipientFilterMeta.AddPVS == nil ) then
	if ( RecipientFilterMeta.AddRecipientsByPVS != nil ) then
		RecipientFilterMeta.AddPVS = RecipientFilterMeta.AddRecipientsByPVS
	end
	if ( RecipientFilterMeta.AddRecipientsByPAS != nil ) then
		RecipientFilterMeta.AddPAS = RecipientFilterMeta.AddRecipientsByPAS
	end
	Msg( "[HL2SB]   CRecipientFilter:AddPVS/AddPAS aliases added\n" )
end

-- ---------------------------------------------------------------------------
-- DynamicLight( index ) -> dlight table.  GMod's global drives CL_AllocDlight
-- from the fields an addon writes (Pos/r/g/b/Brightness/Decay/Size/DieTime/
-- Style).  This fork has no Lua dlight surface, so the answer is a plain
-- table: every write is accepted and dropped.  The one consumer in the addon
-- set (the portalgun's portal glow) is opt-in via portal_dynamic_light and
-- defaults OFF, so the degradation is invisible unless the user turns it on -
-- at which point portals simply have no dynamic light, instead of erroring
-- every Think.
-- ---------------------------------------------------------------------------
if ( _G.DynamicLight == nil ) then
	function DynamicLight( index )
		return { Pos = Vector( 0, 0, 0 ), r = 255, g = 255, b = 255,
			Brightness = 0, Decay = 0, Size = 0, DieTime = 0, Style = 0,
			MinLight = 0, style = 0, KeyBind = index }
	end
	Msg( "[HL2SB]   DynamicLight stub added (writes accepted, no light)\n" )
end

-- ---------------------------------------------------------------------------
-- Entity:GetShootPos.  GMod binds it on BOTH the Player and the NPC
-- metatable; this engine binds it on the Player metatable only
-- (CBasePlayer::Weapon_ShootPosition).  The hitnumbers addon traces melee
-- swings from NPC:GetShootPos (sv_hitdamagenumbers.lua:416) and dies with
-- "attempt to call a nil value (method 'GetShootPos')" the first time an NPC
-- clubs or slashes something.  Our NPCs answer EyePos from the Entity
-- metatable (CBaseCombatCharacter's shoot position derives from the eye
-- point), so alias it there -- player userdata carries their own metatable
-- and never reach this.
-- ---------------------------------------------------------------------------
if ( EntityMeta.GetShootPos == nil and EntityMeta.EyePos != nil ) then
	EntityMeta.GetShootPos = EntityMeta.EyePos
	Msg( "[HL2SB]   Entity:GetShootPos shim added (EyePos alias, non-player entities)\n" )
end

-- Legacy spelling alias; bone tracking and widget input are native.
if ( EntityMeta.SetLocalPos == nil and EntityMeta.SetLocalOrigin != nil ) then
	EntityMeta.SetLocalPos = EntityMeta.SetLocalOrigin
	Msg( "[HL2SB]   Entity:SetLocalPos shim added (SetLocalOrigin alias)\n" )
end

if ( EntityMeta.IsWorld == nil ) then
	function EntityMeta:IsWorld()
		-- GMod: the world entity is entindex 0.  (The server realm already
		-- binds this; the client realm did not.)
		return self:entindex() == 0
	end

	Msg( "[HL2SB]   Entity:IsWorld shim added (entindex 0), client realm\n" )
end

-- ---------------------------------------------------------------------------
-- HL2SB (2026-10-16): runtime-registered SENT classes reach the engine's
-- entity layer.
--
-- GMod's CreateEntityByName falls back to the scripted-entity registry, so a
-- class registered at runtime (scripted_ents.Register from an autorun file or
-- from a folder entity file -- widget_bone / widget_axis_arrow /
-- widget_axis_disc / widget_bonemanip_*, or gmod_player_start's ~40 spawn
-- point classes) is immediately creatable.  This fork's ents.Create only
-- knows the per-file factories its entity loader installs, and only
-- lua/entities/*.lua files get one; the stub files added there carry the
-- factory for the widget classes.
--
-- This wrapper is the other half: after every pass has run
-- (scripted_ents.OnLoaded is the loader's own "all scripts loaded" point,
-- dispatched on both realms from HL2SB_RunEntsOnLoaded), each registered
-- class's real table is mirrored into the `entity` module -- which is what a
-- spawned instance's Lua table is copied from.  Without it a runtime-
-- registered class instantiates from whatever stub the loader happened to
-- see (widget_bone's stub runs before widget_bones.lua registers the real
-- table), and a class with no folder file at all gets no entity table.
-- ---------------------------------------------------------------------------
do
	local EntityModule = _G.entity
	local ScriptedEnts = _G.scripted_ents

	if ( EntityModule != nil and ScriptedEnts != nil and EntityModule.register != nil ) then

		local function HL2SBResyncRuntimeClasses()
			local list = ScriptedEnts.GetList()

			if ( type( list ) != "table" ) then return end

			for name, stored in pairs( list ) do
				local t = ( type( stored ) == "table" ) and stored.t or nil

				if ( type( t ) == "table" ) then
					EntityModule.register( t, name, true )
				end
			end
		end

		-- scripted_ents.OnLoaded remains the original GMod function. The engine
		-- invokes it after all classes are registered; wrapping it here could
		-- overwrite inherited instance tables with leaf shim tables.

		Msg( "[HL2SB]   runtime SENT classes -> entity module resync installed\n" )
	end
end

Msg( "[HL2SB] gmod entity shims loaded\n" )
