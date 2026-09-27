module( "halo", package.seeall )

-- HL2SB (2026-09-26): GMod halo, reimplemented WITHOUT render targets.
--
-- GMod's upstream modules/halo.lua is a render-target pipeline (copy the
-- scene -> clear black -> draw silhouettes -> blur -> restore the scene ->
-- composite).  Ported 1:1 to this fork it BLACK-SCREENED every hold: the
-- scene-copy/restore steps did not survive this engine's DX9 layer on
-- Windows-on-ARM (the frame went black the moment the pass ran, with zero
-- Lua errors -- every binding returned successfully and the screen still
-- died), and the earlier fork's own note on the CopyFrameToTexture binding
-- records the same class of failure.  Rather than keep guessing at the
-- copy, this renderer reproduces what GMod's blur PRODUCES -- a soft glow
-- halo around the silhouette -- using an approach that provably cannot
-- black the screen:
--
--   * nothing is ever cleared;
--   * no render target is ever bound or copied;
--   * the only operations are additive model draws.
--
-- What GMod's gaussian blur does to a solid silhouette is smear its colour
-- outward in a radial falloff.  The same image is produced by redrawing the
-- silhouette many times at increasing radial offsets with decreasing
-- additive alpha ("accumulation blur").  The silhouette is stencil-marked
-- once so the innermost copies do not over-fill the object; the outer rings
-- are what read as the glow.
--
-- The API and the per-frame contract are GMod's: Add(...), RenderedEntity(),
-- and the PostDrawEffects pass that runs PreDrawHalos first.  The fork's
-- physgun wiring (lua/autorun/client/hl2sb_physgun_halo.lua) is the upstream
-- sandbox block and needs no change.

if ( CreateClientConVar != nil ) then
	CreateClientConVar( "halo_draw", "1", true, false, "Halo renderer: 1 = additive glow rings (default), 0 = flat tint" )
end

local matGlow = Material( "models/effects/hl2sb_halo_rim" )	-- additive, culls front faces
local matFlat = Material( "models/effects/hl2sb_physgun_glow" )	-- additive, no cull

local List = {}
local RenderEnt = NULL
local modelFlags = bit.bor( STUDIO_RENDER, STUDIO_SKIP_DECALS or 0 )

-- Cheapest possible convar read that does not depend on the unfinished
-- gmod_compat convar bridge (see the original 2026-09-24 note).
local function CvInt( name, iDefault )
	local ok, cv = pcall( ConVar, name )
	if ( !ok or cv == nil ) then return iDefault end
	if ( cv.GetInt == nil ) then return iDefault end
	local ok2, v = pcall( cv.GetInt, cv )
	return ( ok2 and type( v ) == "number" ) and v or iDefault
end

function Add( entities, color, blurx, blury, passes, add, ignorez )

	if ( table.IsEmpty( entities ) ) then return end
	if ( add == nil ) then add = true end
	if ( ignorez == nil ) then ignorez = false end

	table.insert( List, {
		Ents		= entities,
		Color		= color,
		BlurX		= blurx or 2,
		BlurY		= blury or 2,
		DrawPasses	= passes or 1,
		Additive	= add,
		IgnoreZ		= ignorez
	} )

end

function RenderedEntity()
	return RenderEnt
end

-- Keep only drawable STUDIO models: brush models (gm_construct's mirror) and
-- sprites have no studio header and crashed the studio path (2026-09-24).
local function CollectValid( entry )
	local targets = {}
	for k, v in pairs( entry.Ents ) do
		if ( !IsValid( v ) ) then continue end

		if ( type( v.GetNoDraw ) == "function" && v:GetNoDraw() ) then continue end

		if ( type( v.GetModel ) == "function" ) then
			local ok, sMdl = pcall( v.GetModel, v )
			if ( ok && type( sMdl ) == "string" && sMdl != "" && string.sub( sMdl, -4 ) != ".mdl" ) then
				continue
			end
		end

		targets[ #targets + 1 ] = v
	end
	return targets
end

-- A ring of radial offsets, angle-indexed, so the accumulated copies read as
-- a smooth circular falloff rather than a cross.
local RING_DIRS = {}
do
	local N = 12
	for i = 0, N - 1 do
		local a = ( i / N ) * math.pi * 2
		RING_DIRS[ #RING_DIRS + 1 ] = { math.cos( a ), math.sin( a ) }
	end
end

local VEHICLE_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 0.71, 0.71 }, { -0.71, 0.71 } }

-- rings: { radius multiplier, alpha multiplier } -- inner bright, outer faint.
local RINGS = { { 1.0, 1.0 }, { 2.1, 0.5 }, { 3.3, 0.25 } }

local function RenderGlow( entry )

	local entryColor = entry.Color
	local targets = CollectValid( entry )
	if ( #targets == 0 ) then return end

	-- Radius step scales with the requested blur (GMod's blurx/blury): the
	-- upstream defaults 2/2 give the classic tight physgun halo; bigger
	-- values widen it.  The step is in degrees of camera rotation, the
	-- screen-space offset an angular shift produces for a nearby object.
	local blur = ( ( entry.BlurX or 2 ) + ( entry.BlurY or 2 ) ) * 0.5
	local baseDeg = 0.16 + 0.05 * blur

	-- Heavy models pay SetupBones + DrawModel per pass; vehicles get the
	-- four/six-cardinal ring with a wider step (same coverage, far fewer
	-- draws) -- the 2026-09-24 finding that nine draws of an airboat was the
	-- frame-time cliff on this x64-on-ARM build.
	local dirs, rings = RING_DIRS, RINGS
	local t1 = targets[ 1 ]
	if ( t1 != nil && type( t1.IsVehicle ) == "function" && t1:IsVehicle() ) then
		dirs, rings = VEHICLE_DIRS, { { 1.0, 1.0 }, { 2.1, 0.45 } }
	end

	local cr = ( entryColor.r or 255 ) / 255
	local cg = ( entryColor.g or 255 ) / 255
	local cb = ( entryColor.b or 255 ) / 255
	local ca = ( entryColor.a or 255 ) / 255

	local ply = ( type( LocalPlayer ) == "function" ) and LocalPlayer() or NULL
	local eyePos, eyeAng
	if ( IsValid( ply ) ) then
		eyePos = ply:EyePos()
		eyeAng = ply:EyeAngles()
	end
	local p, y, r = 0, 0, 0
	if ( eyeAng != nil ) then p, y, r = eyeAng.p, eyeAng.y, eyeAng.r end

	cam.Start3D()

		-- Mark the TRUE silhouette in the stencil with an invisible additive
		-- draw (blend 0 still writes stencil), depth ignored so it is stable
		-- every frame.  The glow passes then skip these pixels so the object
		-- itself is not filled in.
		render.ClearStencilBufferRectangle( 0, 0, ScrW(), ScrH(), 0 )
		render.SetStencilEnable( true )
		render.SetStencilWriteMask( 1 )
		render.SetStencilTestMask( 1 )
		render.SetStencilReferenceValue( 1 )
		render.SetStencilCompareFunction( STENCIL_ALWAYS )
		render.SetStencilPassOperation( STENCIL_REPLACE )
		render.SetStencilFailOperation( STENCIL_KEEP )
		render.SetStencilZFailOperation( STENCIL_KEEP )

			render.ModelMaterialOverride( matFlat )
			render.SetBlend( 0 )
			cam.IgnoreZ( true )
			for k = 1, #targets do
				RenderEnt = targets[ k ]
				targets[ k ]:DrawModel( modelFlags )
			end

			-- Glow rings: additive, outside the silhouette only.
			cam.IgnoreZ( entry.IgnoreZ == true )
			render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
			render.CullMode( 1 )		-- MATERIAL_CULLMODE_CW: cull front faces so the offset copy is a shell
			render.SetColorModulation( cr, cg, cb )
			render.ModelMaterialOverride( matGlow )

			-- 2026-09-27: user report "生效但微乎其微".  The old math divided the
			-- total by EVERY draw (12 dirs x 3 rings = 36), leaving ~0.07
			-- additive per copy -- but the angular offsets are tiny, so most
			-- copies land on the same edge pixels and the accumulated ring
			-- read at a fraction of GMod's outline strength.  Per-draw alpha
			-- is now a constant (~4x the old accumulated result); the ring
			-- brightness then scales naturally with how many copies overlap.
			local perPass = math.min( ca * ( entry.Additive and 0.25 or 0.15 ), 1 )

			for ri = 1, #rings do
				local ring = rings[ ri ]
				local deg = baseDeg * ring[ 1 ]
				local alpha = perPass * ring[ 2 ]
				if ( alpha > 0.01 ) then
					render.SetBlend( math.min( alpha, 1 ) )

					for i = 1, #dirs do
						local d = dirs[ i ]
						local jitter = ( math.random() - 0.5 ) * 0.02
						local dp = d[ 2 ] * ( deg + jitter )
						local dy = d[ 1 ] * ( deg + jitter )

						cam.Start3D( eyePos, Angle( p + dp, y + dy, r ) )
							for k = 1, #targets do
								RenderEnt = targets[ k ]
								targets[ k ]:DrawModel( modelFlags )
							end
						cam.End3D()
					end
				end
			end

			RenderEnt = NULL
			render.ModelMaterialOverride( nil )
			render.SetBlend( 1 )
			render.SetColorModulation( 1, 1, 1 )
			render.CullMode( 0 )
			render.SetStencilEnable( false )
			render.SetStencilTestMask( 0 )
			render.SetStencilWriteMask( 0 )
			render.SetStencilReferenceValue( 0 )

	cam.End3D()

end

-- halo_draw 0 = the old flat whole-model tint (no offsets), kept as a
-- fallback switch.
local function RenderFlat( entry )
	local entryColor = entry.Color
	local targets = CollectValid( entry )
	if ( #targets == 0 ) then return end

	cam.Start3D()
		render.SuppressEngineLighting( true )
		render.SetColorModulation( ( entryColor.r or 255 ) / 255, ( entryColor.g or 255 ) / 255, ( entryColor.b or 255 ) / 255 )
		render.SetBlend( ( ( entryColor.a or 255 ) / 255 ) * 0.85 )
		render.ModelMaterialOverride( matFlat )

		for k = 1, #targets do
			RenderEnt = targets[ k ]
			targets[ k ]:DrawModel( modelFlags )
		end

		render.ModelMaterialOverride( nil )
		render.SetBlend( 1 )
		render.SetColorModulation( 1, 1, 1 )
		render.SuppressEngineLighting( false )
	cam.End3D()
	RenderEnt = NULL
end

function Render( entry )
	if ( CvInt( "halo_draw", 1 ) == 0 ) then
		return RenderFlat( entry )
	end
	return RenderGlow( entry )
end

hook.Add( "PostDrawEffects", "RenderHalos", function()

	-- Upstream parity: addons (the sandbox physgun halo among them) call
	-- halo.Add from PreDrawHalos -- it must fire EVERY frame, even when
	-- nothing is queued yet, or feed hooks never run.
	hook.Run( "PreDrawHalos" )

	if ( #List == 0 ) then return end

	for k, v in ipairs( List ) do

		-- Fuse: a failure can never leave the frame half-drawn.  This
		-- renderer opens no render targets, so recovery is just resetting
		-- the state it touches.
		local ok, err = pcall( Render, v )

		if ( !ok ) then
			render.SetStencilEnable( false )
			render.SetStencilTestMask( 0 )
			render.SetStencilWriteMask( 0 )
			render.SetStencilReferenceValue( 0 )
			render.ModelMaterialOverride( nil )
			render.SetBlend( 1 )
			render.SetColorModulation( 1, 1, 1 )
			render.CullMode( 0 )
			RenderEnt = NULL

			print( "[HL2SB halo] render failed: " .. tostring( err ) )
		end

	end

	List = {}

end )
