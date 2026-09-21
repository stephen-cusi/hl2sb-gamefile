--[[----------------------------------------------------------------------------
    hl2sb_field_probe.lua   (TEMPORARY diagnostic - delete once the cod_c4
                             "attempt to get length of a nil value (field 'C4s')"
                             round-trip question is answered)

    2026-09-18 v2: split "write is dropped" from "read chain misses".

      (a) normal read                 - the path the addon uses
      (b) entmeta.__index(obj, key)   - the C++ CBaseEntity___index called
                                        directly, bypassing the player.lua
                                        Lua __index override
      (c) obj:GetTable()              - what the player.lua __index fallback
                                        actually consults (type + rawget)
      (d) identity of Entity.GetTable / Player metatable __newindex
--]]----------------------------------------------------------------------------

local function Probe( tag, obj )

	if ( not IsValid( obj ) ) then
		Msg( "[probe] " .. tag .. ": invalid\n" )
		return
	end

	local plymeta = FindMetaTable( "Player" )
	local entmeta = FindMetaTable( "Entity" )
	local meta = getmetatable( obj )

	-- 1. an ordinary field
	obj.hl2sbProbe = "written"

	local normalRead = obj.hl2sbProbe
	local cppRead = nil
	local cppErr = nil
	do
		local ok, val = pcall( entmeta.__index, obj, "hl2sbProbe" )
		if ( ok ) then cppRead = val else cppErr = val end
	end

	local tab = nil
	local tabType = nil
	local tabHas = nil
	do
		local ok, val = pcall( function() return obj:GetTable() end )
		if ( ok ) then
			tab = val
			tabType = type( tab )
			if ( istable( tab ) ) then tabHas = rawget( tab, "hl2sbProbe" ) end
		else
			tabType = "ERROR: " .. tostring( val )
		end
	end

	Msg( string.format(
		"[probe] %-10s type=%s meta==Player:%s meta==Entity:%s\n" ..
		"[probe] %-10s write->normal read = %s | via C++ Entity.__index = %s%s\n" ..
		"[probe] %-10s GetTable: %s%s | identity: Entity.GetTable==GetRefTable:%s Player.__newindex=%s\n",
		tag, type( obj ), tostring( meta == plymeta ), tostring( meta == entmeta ),
		tag, tostring( normalRead ), tostring( cppRead ), cppErr and (" (ERR " .. tostring( cppErr ) .. ")") or "",
		tag, tabType, tabHas ~= nil and (" hl2sbProbe=" .. tostring( tabHas )) or "",
		tostring( entmeta.GetTable == entmeta.GetRefTable ),
		tostring( type( meta.__newindex ) ) ) )

	-- 2. the addon's exact pattern (write, then read back in a separate statement)
	obj.C4s = obj.C4s or {}
	local c4s = obj.C4s
	Msg( string.format( "[probe] %-10s C4s after write = %s   length ok = %s\n",
		tag, tostring( c4s ), tostring( pcall( function() return #c4s end ) ) ) )

	obj.hl2sbProbe = nil
	obj.C4s = nil

end

if ( SERVER ) then
	hook.Add( "PlayerSpawn", "hl2sb_field_probe_sv", function( ply )

		Probe( "player(sv)", ply )

		local prop = ents.Create( "prop_physics" )
		if ( IsValid( prop ) ) then
			prop:Spawn()
			Probe( "prop(sv)", prop )
			prop:Remove()
		end

	end )
else
	-- the client has no PlayerSpawn hook; run once a few seconds in
	timer.Simple( 3, function()
		Probe( "player(cl)", LocalPlayer() )
	end )
end
