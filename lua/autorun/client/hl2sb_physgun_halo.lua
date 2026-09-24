-- HL2SB GMod compat: the physgun held-entity OUTLINE glow -- the wiki
-- halo.Add reference image (carried prop ringed in the weapon colour) --
-- ported from the REAL sandbox gamemode (garrysmod/gamemodes/sandbox/
-- gamemode/cl_init.lua, the PhysgunHalos block), because this fork has no
-- sandbox gamemode of its own.
--
-- Chain:
--   1. the physgun weapon dispatches the DrawPhysgunBeam hook every frame
--      the beam is drawn (weapon_physgun.cpp, both call sites);
--      we record targets[ply] and return true -- the engine contract is
--      that only a LITERAL false suppresses the default beam;
--   2. halo.lua's PostDrawEffects pass fires PreDrawHalos BEFORE it
--      renders (upstream ordering, restored 2026-09-24); our handler
--      feeds halo.Add the WHOLE table (sandbox passes the table, not one
--      entity) and clears it, so the ring lives exactly as long as the
--      hold and dies the frame the beam stops coming.
--
-- Three fork adaptations (all documented in AGENTS.md):
--   * VectorRand() does not exist here -- GMod's +-0.3 colour jitter
--     (VectorRand()*0.3) becomes (math.random() - 0.5) * amplitude; the
--     amplitude itself is now 0.1, not 0.6 -- see RingColor below for why.
--   * Color() is not required: halo only reads .r/.g/.b/.a off the entry,
--     so a plain field table is passed (immune to constructor availability);
--   * the sandbox gate reads the AUTO-GLOBAL physgun_halo convar object;
--     here it goes through GetConVar, and a nil answer reads as ON (the
--     shipped configs set physgun_halo 1).
--
-- The earlier "final" revision of this file stopped feeding halo.Add and
-- relied on a native C++ glow shell instead -- with nothing ever calling
-- halo.Add, the RT/gaussian pipeline built on 2026-09-24 never executed a
-- single frame (engine.log: zero "render failed" lines, because the halo
-- List stayed empty).  Feeding it is the fix.

local PhysgunHalos = {}
-- HL2SB (2026-09-24): retain each held target briefly instead of clearing the
-- table every frame like upstream sandbox.  The beam-hook dispatch drops
-- frames on this fork (its two call sites are under active physgun work), and
-- an upstream-style clear-after-add made the ring BLINK on every dropped
-- frame ("npc prop... 但是会闪").  A0.2s TTL absorbs single-frame gaps while
-- release still reads as instant-off.
local PHYSGUN_HALO_TTL = 0.2

-- HL2SB (2026-09-24): ONE colour source for the ring.  The "两种颜色的闪烁"
-- report (20:43 video) had two contributors:
--   * Player:GetWeaponColor routes through a per-userid cache that the
--     SERVER fills only on spawn (hl2sb_player_color.lua), so a weapon
--     colour picked in the player-model menu mid-session left cache readers
--     on the OLD colour while convar readers showed the new one -- ring and
--     beam flashing between the two;
--   * the per-frame jitter was GMod's exact +-0.3 (VectorRand()*0.3,
--     sandbox cl_init.lua:148) -- subtle on GMod's own default
--     "0.30 1.80 2.10" whose channels exceed 1.0, but up to +-140% on a
--     0-1 palette like ours: the ring hue visibly swung every frame.
-- So the LOCAL player's ring reads the LIVE cl_weaponcolor convar
-- (GetConVarString -- proven in this state, hl2sb_playermodel_gmod.lua
-- writes the picker through it); remote players keep the networked meta
-- (their convar is not ours).  The jitter is cut to +-0.05: the living
-- shimmer stays, the hue swing goes.
local function RingColor( ply )

	if ( ply == LocalPlayer() && type( GetConVarString ) == "function" ) then
		local s = GetConVarString( "cl_weaponcolor" )
		if ( type( s ) == "string" && s != "" ) then
			local x, y, z = string.match( s, "^%s*(%-?[%d%.eE+]+)%s+(%-?[%d%.eE+]+)%s+(%-?[%d%.eE+]+)%s*$" )
			if ( x != nil ) then
				return Vector( tonumber( x ), tonumber( y ), tonumber( z ) )
			end
		end
	end

	local colr = ply:GetWeaponColor()		-- normalized Vector, GMod contract
	if ( colr == nil ) then colr = Vector( 0.3, 1, 1 ) end
	return colr

end

hook.Add( "DrawPhysgunBeam", "HL2SB_PhysgunHaloCapture", function( ply, weapon, bOn, target, boneid, pos )

	local cvar = ( type( GetConVar ) == "function" ) and GetConVar( "physgun_halo" ) or nil
	if ( cvar != nil && cvar:GetInt() == 0 ) then return true end

	if ( IsValid( target ) ) then
		PhysgunHalos[ ply ] = { ent = target, t = CurTime() }
	end

	return true		-- literal false would suppress the default beam

end )

hook.Add( "PreDrawHalos", "HL2SB_AddPhysgunHalos", function()

	if ( PhysgunHalos == nil || table.IsEmpty( PhysgunHalos ) ) then return end

	local now = CurTime()
	local size = math.random( 1, 2 )

	for ply, rec in pairs( PhysgunHalos ) do

		if ( !IsValid( ply ) || rec == nil || rec.ent == nil || !IsValid( rec.ent )
				|| ( now - rec.t ) > PHYSGUN_HALO_TTL ) then
			PhysgunHalos[ ply ] = nil		-- released / gone / stale
			continue
		end

		-- collect every still-fresh target into one ring pass (upstream adds
		-- the whole ply-keyed table per player; single-player = one pass)
		local glow = {}
		for _, r in pairs( PhysgunHalos ) do
			if ( r != nil && r.ent != nil && IsValid( r.ent ) && ( now - r.t ) <= PHYSGUN_HALO_TTL ) then
				glow[ #glow + 1 ] = r.ent
			end
		end
		if ( #glow == 0 ) then continue end

		local colr = RingColor( ply )

		local function jit( c )
			return math.Clamp( ( c + ( math.random() - 0.5 ) * 0.1 ) * 255, 0, 255 )
		end

		halo.Add( glow,
			{ r = jit( colr.x ), g = jit( colr.y ), b = jit( colr.z ), a = 255 },
			size, size, 1, true, false )

	end

end )
