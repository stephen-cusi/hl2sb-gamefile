-- Remaining entity compatibility helpers.
-- Typed data tables use the native slots and the original Entity installer.

local EntityMeta = FindMetaTable( "Entity" )

if ( EntityMeta == nil ) then return end

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




Msg( "[HL2SB] gmod entity shims loaded\n" )
