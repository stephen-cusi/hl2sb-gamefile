-- Remaining entity compatibility helpers.
-- Typed data tables use the native slots and the original Entity installer.

local EntityMeta = FindMetaTable( "Entity" )

if ( EntityMeta == nil ) then return end

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

Msg( "[HL2SB] gmod entity shims loaded\n" )
