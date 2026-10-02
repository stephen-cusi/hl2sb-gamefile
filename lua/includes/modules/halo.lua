-- HL2SB (2026-10-03): GMod's halo module, the upstream RT pipeline restored
-- as the primary renderer (garrysmod/lua/includes/modules/halo.lua, verbatim
-- Render below).  The 2026-09-26 rewrite replaced this pipeline with
-- additive glow rings because the scene copy/restore blacked the screen on
-- this engine's DX9 layer back then; every missing piece landed since
-- (CopyRenderTargetToTexture with the correct source rect, the allocation-
-- window screen-effect textures, UpdateScreenEffectTexture, the pp/copy|
-- add|sub materials, real cam.IgnoreZ, BlurRenderTarget) so the original
-- pipeline runs again.  The ring renderer survives behind halo_engine_rt 0
-- as the instant fallback if the copy path ever regresses.
--
-- Fork deltas inside the upstream path, all mechanical:
--   * module-reload guard (this engine's dofolder pass re-appends loaded
--     files instead of honouring package.loaded, which would stack a second
--     PostDrawEffects hook);
--   * STUDIO_SKIP_DECALS keeps its "or 0" tolerance (upstream comment: the
--     value is not defined in this engine);
--   * the PostDrawEffects loop runs each Render behind a fuse that resets
--     the stencil/override state on error (upstream has no fuse).

if ( _G.halo and _G.halo.Add and _G.halo.RenderedEntity ) then
	return _G.halo
end

module( "halo", package.seeall )

local mat_Copy		= Material( "pp/copy" )
local mat_Add		= Material( "pp/add" )
local mat_Sub		= Material( "pp/sub" )
local rt_Store		= render.GetScreenEffectTexture( 0 )
local rt_Blur		= render.GetScreenEffectTexture( 1 )

local List = {}
local RenderEnt = NULL
-- TODO: Remove "or 0" after some update
-- There's no point in filling the real value of STUDIO_SKIP_DECALS as the current client doesn't support it anyway
local modelFlags = bit.bor( STUDIO_RENDER, STUDIO_SKIP_DECALS or 0 )

function Add( entities, color, blurx, blury, passes, add, ignorez )

	if ( table.IsEmpty( entities ) ) then return end
	if ( add == nil ) then add = true end
	if ( ignorez == nil ) then ignorez = false end

	local t =
	{
		Ents = entities,
		Color = color,
		BlurX = blurx or 2,
		BlurY = blury or 2,
		DrawPasses = passes or 1,
		Additive = add,
		IgnoreZ = ignorez
	}

	table.insert( List, t )

end

function RenderedEntity()
	return RenderEnt
end

function Render( entry )

	local rt_Scene = render.GetRenderTarget()

	-- Store a copy of the original scene
	render.CopyRenderTargetToTexture( rt_Store )

	-- Clear our scene so that additive/subtractive rendering with it will work later
	if ( entry.Additive ) then
		render.Clear( 0, 0, 0, 255, false, true )
	else
		render.Clear( 255, 255, 255, 255, false, true )
	end

	-- For certain materials this is necessary to not have the entire screen go pitch black
	-- For example the glass doors in Episode 2 GMan sequence
	render.UpdateRefractTexture()

	-- Render colored props to the scene and set their pixels high
	cam.Start3D()
		render.SetStencilEnable( true )
			render.SuppressEngineLighting( true )
			cam.IgnoreZ( entry.IgnoreZ )

				render.SetStencilWriteMask( 1 )
				render.SetStencilTestMask( 1 )
				render.SetStencilReferenceValue( 1 )

				render.SetStencilCompareFunction( STENCIL_ALWAYS )
				render.SetStencilPassOperation( STENCIL_REPLACE )
				render.SetStencilFailOperation( STENCIL_KEEP )
				render.SetStencilZFailOperation( STENCIL_KEEP )

					for k, v in pairs( entry.Ents ) do
						if ( !IsValid( v ) or v:GetNoDraw() ) then continue end

						RenderEnt = v

						v:DrawModel( modelFlags )
					end

					RenderEnt = NULL

				render.SetStencilCompareFunction( STENCIL_EQUAL )
				render.SetStencilPassOperation( STENCIL_KEEP )
				-- render.SetStencilFailOperation( STENCIL_KEEP )
				-- render.SetStencilZFailOperation( STENCIL_KEEP )

					cam.Start2D()
						local entryColor = entry.Color
						surface.SetDrawColor( entryColor.r, entryColor.g, entryColor.b, entryColor.a )
						surface.DrawRect( 0, 0, ScrW(), ScrH() )
					cam.End2D()

			cam.IgnoreZ( false )
			render.SuppressEngineLighting( false )
		render.SetStencilEnable( false )
	cam.End3D()

	-- Store a blurred version of the colored props in an RT
	render.CopyRenderTargetToTexture( rt_Blur )
	render.BlurRenderTarget( rt_Blur, entry.BlurX, entry.BlurY, 1 )

	-- Restore the original scene
	render.SetRenderTarget( rt_Scene )
	mat_Copy:SetTexture( "$basetexture", rt_Store )
	mat_Copy:SetString( "$color", "1 1 1" )
	mat_Copy:SetString( "$alpha", "1" )
	render.SetMaterial( mat_Copy )
	render.DrawScreenQuad()

	-- Draw back our blured colored props additively/subtractively, ignoring the high bits
	render.SetStencilEnable( true )

		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
		-- render.SetStencilPassOperation( STENCIL_KEEP )
		-- render.SetStencilFailOperation( STENCIL_KEEP )
		-- render.SetStencilZFailOperation( STENCIL_KEEP )

		if ( entry.Additive ) then
			mat_Add:SetTexture( "$basetexture", rt_Blur )
			render.SetMaterial( mat_Add )
		else
			mat_Sub:SetTexture( "$basetexture", rt_Blur )
			render.SetMaterial( mat_Sub )
		end

		for i = 0, entry.DrawPasses do
			render.DrawScreenQuad()
		end

	render.SetStencilEnable( false )

	-- Return original values
	render.SetStencilTestMask( 0 )
	render.SetStencilWriteMask( 0 )
	render.SetStencilReferenceValue( 0 )

end

-- ---------------------------------------------------------------------------
-- FALLBACK: the additive glow-ring renderer (the 2026-09-26 rewrite), kept
-- as the halo_engine_rt 0 path.  It reproduces what the upstream gaussian
-- blur produces around a silhouette without ever touching a render target,
-- so a copy-path regression can never black the screen.
-- ---------------------------------------------------------------------------

if ( CreateClientConVar != nil ) then
	CreateClientConVar( "halo_engine_rt", "1", true, false, "Halo renderer: 1 = upstream RT blur pipeline, 0 = additive glow rings" )
	CreateClientConVar( "halo_draw", "1", true, false, "Fallback renderer detail: 1 = glow rings, 0 = flat tint" )
end

local matGlow = Material( "models/effects/hl2sb_halo_rim" )	-- additive, culls front faces
local matFlat = Material( "models/effects/hl2sb_physgun_glow" )	-- additive, no cull

local function CvInt( name, iDefault )
	local ok, cv = pcall( ConVar, name )
	if ( !ok or cv == nil ) then return iDefault end
	if ( cv.GetInt == nil ) then return iDefault end
	local ok2, v = pcall( cv.GetInt, cv )
	return ( ok2 and type( v ) == "number" ) and v or iDefault
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

	local blur = ( ( entry.BlurX or 2 ) + ( entry.BlurY or 2 ) ) * 0.5
	local baseDeg = 0.16 + 0.05 * blur

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

			cam.IgnoreZ( entry.IgnoreZ == true )
			render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
			render.CullMode( 1 )
			render.SetColorModulation( cr, cg, cb )
			render.ModelMaterialOverride( matGlow )

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

local function RenderUpstream( entry )
	if ( CvInt( "halo_draw", 1 ) == 0 ) then
		return RenderFlat( entry )
	end
	return RenderGlow( entry )
end

-- The public dispatch: upstream RT pipeline unless switched off.
local function RenderDispatch( entry )
	if ( CvInt( "halo_engine_rt", 1 ) == 0 ) then
		return RenderUpstream( entry )
	end
	return Render( entry )
end

hook.Add( "PostDrawEffects", "RenderHalos", function()

	-- Upstream parity: addons (the sandbox physgun halo among them) call
	-- halo.Add from PreDrawHalos -- it must fire EVERY frame, even when
	-- nothing is queued yet, or feed hooks never run.
	hook.Run( "PreDrawHalos" )

	if ( #List == 0 ) then return end

	for k, v in ipairs( List ) do

		-- Fuse: a failure can never leave the frame half-drawn.  Both
		-- renderers leave stencil/override state behind on error; reset
		-- everything the upstream tail restores, plus the override knobs
		-- the fallback uses.
		local ok, err = pcall( RenderDispatch, v )

		if ( !ok ) then
			render.SetStencilEnable( false )
			render.SetStencilTestMask( 0 )
			render.SetStencilWriteMask( 0 )
			render.SetStencilReferenceValue( 0 )
			render.ModelMaterialOverride( nil )
			render.SetBlend( 1 )
			render.SetColorModulation( 1, 1, 1 )
			render.CullMode( 0 )
			render.SuppressEngineLighting( false )
			cam.IgnoreZ( false )
			RenderEnt = NULL

			print( "[HL2SB halo] render failed: " .. tostring( err ) )
		end

	end

	List = {}

end )
