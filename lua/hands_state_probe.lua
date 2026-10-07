-- ===========================================================================
-- hands_state_probe.lua (2026-10-08): death -> respawn c_hands state dump.
--
-- Reproduce "die then respawn loses the hands entity", then run ONCE in each
-- console while the hands are still missing:
--
--   server console:  lua_dofile hands_state_probe.lua
--   client console:  lua_dofile_cl hands_state_probe.lua
--
-- Reads only.  The [HSP] lines answer, per realm:
--   A) does GetHands() still answer the new hands entity (the replicated
--      m_hHands handle), or nil / a dead index  -> handle/network layer;
--   B) does a gmod_hands entity exist here at all -> spawn/transmit layer;
--   C) hands parent vs the live viewmodel (entindex pair) -> attach layer.
-- ===========================================================================

local function H( s ) print( "[HSP] " .. s ) end

local function EntTag( e )
	if ( e == nil or not IsValid( e ) ) then return tostring( e ) end
	return "ent" .. e:EntIndex()
end

local function DumpHands( tag, ply, hands )
	if ( hands == nil or not IsValid( hands ) ) then
		H( tag .. " ply=" .. EntTag( ply ) .. " GetHands=" .. tostring( hands ) .. "  <- INVALID/nil" )
		return
	end

	local parent = hands.GetParent and hands:GetParent() or nil
	local owner = hands.GetOwner and hands:GetOwner() or nil
	local vm = ( ply.GetViewModel ~= nil ) and ply:GetViewModel( 0 ) or nil
	local bonemerge = "?"
	if ( hands.IsEffect ~= nil ) then
		local ok, v = pcall( hands.IsEffect, hands, EF_BONEMERGE )
		bonemerge = ok and tostring( v ) or "?"
	end

	H( string.format(
		"%s ply=%s hands=ent%d model=%s owner=%s parent=%s vm=%s bonemerge=%s parentIsVm=%s bodygroups=%s",
		tag, EntTag( ply ), hands:EntIndex(),
		tostring( hands.GetModel and hands:GetModel() or "?" ),
		EntTag( owner ), EntTag( parent ), EntTag( vm ),
		bonemerge,
		tostring( parent ~= nil and IsValid( parent ) and vm ~= nil and IsValid( vm ) and parent == vm ),
		tostring( hands.GetNumBodyGroups and select( 1, pcall( hands.GetNumBodyGroups, hands ) ) or "?" ) ) )
end

if ( SERVER ) then

	H( "-- server --" )
	for _, ply in ipairs( player.GetAll() ) do
		H( "player ent" .. ply:EntIndex() .. " model=" .. tostring( ply:GetModel() )
			.. " alive=" .. tostring( ply:Alive() ) )
		DumpHands( "sv", ply, ( ply.GetHands ~= nil ) and ply:GetHands() or nil )
	end

	local found = ents.FindByClass( "gmod_hands" )
	H( "ents.FindByClass('gmod_hands') count=" .. #found )
	for i, e in ipairs( found ) do
		local owner = e.GetOwner and e:GetOwner() or nil
		local parent = e.GetParent and e:GetParent() or nil
		H( string.format( "  sv hands[%d] ent%d model=%s owner=%s parent=%s",
			i, e:EntIndex(), tostring( e.GetModel and e:GetModel() or "?" ),
			EntTag( owner ), EntTag( parent ) ) )
	end

else

	H( "-- client --" )
	local ply = LocalPlayer()
	if ( ply == nil or not IsValid( ply ) ) then H( "no LocalPlayer" ) return end

	DumpHands( "cl", ply, ( ply.GetHands ~= nil ) and ply:GetHands() or nil )

	local found = ents.FindByClass( "gmod_hands" )
	H( "client gmod_hands count=" .. #found )
	for i, e in ipairs( found ) do
		DumpHands( "cl[" .. i .. "]", ply, e )
	end

end

H( "done" )
