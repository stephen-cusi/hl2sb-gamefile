-- HL2SB (2026-10-03): GMod's halo module, the upstream RT pipeline restored
-- as the primary renderer (garrysmod/lua/includes/modules/halo.lua, verbatim
-- Render below).  The 2026-09-26 rewrite replaced this pipeline with
-- additive glow rings because the scene copy/restore blacked the screen on
-- this engine's DX9 layer back then; every missing piece landed since
-- (the plain one-arg CopyRenderTargetToTexture, the allocation-window
-- screen-effect textures, UpdateScreenEffectTexture, the pp/copy|add|sub
-- materials, real cam.IgnoreZ, BlurRenderTarget) so the original pipeline
-- runs again.  The ring renderer survives behind halo_engine_rt 0
-- as the instant fallback if the copy path ever regresses.
--
-- Fork deltas inside the upstream path, all mechanical:
--   * module-reload guard (this engine's dofolder pass re-appends loaded
--     files instead of honouring package.loaded, which would stack a second
--     PostDrawEffects hook);
--   * STUDIO_SKIP_DECALS keeps its "or 0" tolerance (upstream comment: the
--     value is not defined in this engine);
--   * the PostDrawEffects loop runs each Render behind a fuse that resets
--     the stencil/override state on error (upstream has no fuse);
--   * the restore and composite fullscreen quads draw inside an explicit
--     cam.Start2D/End2D view.  GMod's engine-side DrawScreenQuad pushes its
--     own 2D view (IVRenderView::Push2DView with the full render-target
--     rect, decompiled) around every quad, which re-commits render target,
--     viewport and orthographic projection before each draw; this engine's
--     render.DrawScreenQuad is the bare clip-space triangle
--     (CMatRenderContext::DrawScreenSpaceQuad), so whatever state the
--     silhouette pass leaves behind must be re-committed here or the quads
--     never reach the screen and the frame stays at the cleared black.
--     Round 2 of the black-screen hunt ships the P1..P7 probe ladder: each
--     checkpoint draws a solid red rect after one pipeline op, so the first
--     black P names the killer op (A/B above stay as the halo_debug-gated
--     capture canaries; the round-1 C/D one-frames are superseded by P6/P7).
--   * the silhouette pass clears the stencil rectangle first (the clear
--     above keeps the stencil, and this engine's stencil carries leftovers
--     at PostDrawEffects -- the fallback renderer already needed the same
--     ClearStencilBufferRectangle idiom).

if ( _G.halo and _G.halo.Add and _G.halo.RenderedEntity ) then
	return _G.halo
end

module( "halo", package.seeall )

local mat_Copy		= Material( "pp/copy" )
local mat_Add		= Material( "pp/add" )
local mat_Sub		= Material( "pp/sub" )

-- HL2SB (2026-10-03, private targets): the upstream module binds the ENGINE
-- frame-buffer pair here (render.GetScreenEffectTexture(0/1)).  Six probe
-- rounds cornered why that fails on this fork: "$basetexture" materials
-- pointing at the FB pair resolve through the frame-buffer-copy registration
-- slot at bind time, mid-pass engine calls re-point those slots (the
-- UpdateRefractTexture tail hands slot 0 to the power-of-two FB whose
-- content at that moment is the post-clear BLACK copy), and even explicit
-- re-registration did not bring the restore quad back.  The pipeline below
-- is otherwise the upstream verbatim; the ONLY fork delta is that the store
-- and blur targets are PRIVATE named render targets (the same creation the
-- spawnicon snapshot pipeline proves sampleable through plain $basetexture),
-- which no FB-slot machinery can redirect.  Created lazily on the first
-- dispatch, recreated if the resolution changes.
local rt_Store		= nil
local rt_Blur		= nil
local nTargetRetryFrame = 0
local nFrameCounter = 0

local function EnsureTargets()
	local nW, nH = ScrW(), ScrH()
	if ( rt_Store != nil and rt_Blur != nil
		and rt_Store:GetActualWidth() == nW and rt_Store:GetActualHeight() == nH ) then
		return true
	end
	-- throttle a failing creation (the material system refuses named RT
	-- creation outside allocation windows with a Warning per attempt) to
	-- one attempt per ~60 halo frames
	nFrameCounter = nFrameCounter + 1
	if ( nFrameCounter < nTargetRetryFrame ) then return rt_Store != nil end
	nTargetRetryFrame = nFrameCounter + 60
	rt_Store = render.CreateNamedRenderTarget( "hl2sb_halo_store", nW, nH )
	rt_Blur = render.CreateNamedRenderTarget( "hl2sb_halo_blur", nW, nH )
	if ( rt_Store == nil or rt_Blur == nil ) then
		rt_Store = nil
		rt_Blur = nil
		Warning( "[HL2SB halo] private store/blur render targets not creatable - RT pipeline skipped\n" )
		return false
	end
	MsgN( "[HL2SB halo] private targets created: " .. rt_Store:GetName() .. " / " ..
		rt_Blur:GetName() .. " " .. rt_Store:GetActualWidth() .. "x" .. rt_Store:GetActualHeight() )
	return true
end

-- The convars CANNOT be created at file load: this module loads in the
-- modules pass, before CreateClientConVar exists in this engine (the same
-- ordering that forced gmod_language engine-side).  Create them lazily on
-- the first dispatch -- by then the client realm is fully up.
local bConvarsReady = false
local function EnsureConvars()
	if ( bConvarsReady ) then return end
	bConvarsReady = true
	if ( CreateClientConVar != nil ) then
		CreateClientConVar( "halo_engine_rt", "1", true, false, "Halo renderer: 1 = upstream RT blur pipeline, 0 = additive glow rings" )
		CreateClientConVar( "halo_draw", "1", true, false, "Fallback renderer detail: 1 = glow rings, 0 = flat tint" )
		CreateClientConVar( "halo_debug", "0", true, false, "Print the upstream halo pipeline stages as they run" )
	end
end

-- Cheapest possible convar read that does not depend on the unfinished
-- gmod_compat convar bridge (see the original 2026-09-24 note).
local function CvInt( name, iDefault )
	local ok, cv = pcall( ConVar, name )
	if ( !ok or cv == nil ) then return iDefault end
	if ( cv.GetInt == nil ) then return iDefault end
	local ok2, v = pcall( cv.GetInt, cv )
	return ( ok2 and type( v ) == "number" ) and v or iDefault
end

local function Stage( name )
	if ( CvInt( "halo_debug", 0 ) == 1 ) then
		MsgN( "[HL2SB halo] " .. name )
	end
end

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

	-- HL2SB (2026-10-03, private targets): the store/blur targets are lazy
	-- private render targets; without them there is nothing to draw into.
	if ( !EnsureTargets() ) then return end

	local rt_Scene = render.GetRenderTarget()

	-- Store a copy of the original scene.  Reference behaviour: the PLAIN
	-- full-surface copy -- the binding is the one-arg engine call whose
	-- source is the current render target (the backbuffer at
	-- PostDrawEffects) with NULL source/dest rects.
	-- (No SetFrameBufferCopyTexture here: private targets are NOT
	-- frame-buffer textures, no slot can redirect them, and registering a
	-- private texture into an engine slot would hijack the slot for every
	-- other engine material that expects the real FB pair.)
	Stage( "1: copy scene -> store" )
	render.CopyRenderTargetToTexture( rt_Store )

	-- Clear our scene so that additive/subtractive rendering with it will work later
	if ( entry.Additive ) then
		render.Clear( 0, 0, 0, 255, false, true )
	else
		render.Clear( 255, 255, 255, 255, false, true )
	end

	Stage( "2: clear done, update refract" )
	-- For certain materials this is necessary to not have the entire screen go pitch black
	-- For example the glass doors in Episode 2 GMan sequence
	render.UpdateRefractTexture()
	-- HL2SB (2026-10-03, private targets): the engine inline re-points
	-- FB-copy slot 0 at the power-of-two FB here (view_scene.h), which was
	-- the mid-pass killer while the store lived in the FB pair.  The private
	-- targets are invisible to that machinery -- nothing to re-assert.

	-- Render colored props to the scene and set their pixels high
	cam.Start3D()
		-- Fork delta: the clear above keeps the stencil (upstream behaviour),
		-- but this engine's stencil buffer carries leftovers at
		-- PostDrawEffects -- the fallback renderer below already proves the
		-- ClearStencilBufferRectangle idiom is needed here.  Without it the
		-- NOTEQUAL composite skips every garbage-marked pixel.
		render.ClearStencilBufferRectangle( 0, 0, ScrW(), ScrH(), 0 )
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

	Stage( "3: silhouettes drawn, copy -> blur" )
	-- Store a blurred version of the colored props in an RT (the plain
	-- full-surface copy, as above)
	render.CopyRenderTargetToTexture( rt_Blur )
	-- HL2SB (2026-10-03, private targets): slot 1 used to be sampled by the
	-- composite without ever being registered; with a private blur target
	-- the bind is direct and the slot machinery is out of the picture.

	render.BlurRenderTarget( rt_Blur, entry.BlurX, entry.BlurY, 1 )

	Stage( "4: blur done, restore scene" )
	-- Restore the original scene
	render.SetRenderTarget( rt_Scene )
	mat_Copy:SetTexture( "$basetexture", rt_Store )
	-- HL2SB (2026-10-03): these two MUST stay typed float writes.  SetString
	-- stores the raw text and flips the var to MATERIAL_VAR_TYPE_STRING - it
	-- does NOT parse the VMT "[1 1 1]" vector form - and a shader colour read
	-- of a STRING-typed var falls into the untyped default of
	-- CMaterialVar::GetVecValue, so the restore quad painted BLACK and the
	-- whole pass blacked the screen.  SetFloat writes m_VecVal = (1,1,1,1)
	-- typed FLOAT, which every colour/alpha getter answers full white and
	-- fully opaque.
	mat_Copy:SetFloat( "$color", 1 )
	mat_Copy:SetFloat( "$alpha", 1 )

	-- The restore quad, inside an explicit 2D view (header note: this engine
	-- must re-commit RT + viewport + ortho projection here; GMod's engine
	-- DrawScreenQuad does the same push internally on every quad).
	cam.Start2D()
		render.SetRenderTarget( rt_Scene )
		render.SetMaterial( mat_Copy )
		render.DrawScreenQuad()
	cam.End2D()

	-- Draw back our blured colored props additively/subtractively, ignoring the high bits
	-- (also inside the explicit 2D view: same re-commit as the restore quad,
	-- so the NOTEQUAL stencil composite lands on the backbuffer at fullscreen
	-- viewport no matter what the blur ping-pong left behind).
	cam.Start2D()
		render.SetRenderTarget( rt_Scene )

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

	cam.End2D()
	Stage( "5: composite done" )

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

local matGlow = Material( "models/effects/hl2sb_halo_rim" )	-- additive, culls front faces
local matFlat = Material( "models/effects/hl2sb_physgun_glow" )	-- additive, no cull

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
-- The upstream pipeline cannot be allowed to run with error materials: the
-- Clear blackens the frame and a failed restore quad never brings it back
-- (the black screen).  Every material the path touches is checked; anything
-- unresolved falls back to the ring renderer, which cannot black the screen.
local function MaterialsReady( entry )
	-- NOTE: IsValid is the ENTITY global here (it answers false for
	-- materials and textures), so every check is a plain nil test plus the
	-- IsErrorMaterial method.
	local need = { mat_Copy, entry.Additive and mat_Add or mat_Sub }
	for i = 1, #need do
		local m = need[ i ]
		if ( m == nil or m.IsErrorMaterial == nil or m:IsErrorMaterial() ) then
			return false
		end
	end
	if ( rt_Store == nil or rt_Blur == nil ) then
		return false
	end
	return true
end

local function RenderDispatch( entry )
	EnsureConvars()
	if ( CvInt( "halo_engine_rt", 1 ) == 0 or not MaterialsReady( entry ) ) then
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
