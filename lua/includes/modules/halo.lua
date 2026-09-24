
module( "halo", package.seeall )

-- HL2SB (2026-09-24): the halo renderer, three modes behind `halo_draw`:
--
--   halo_draw 1       RenderRT -- the upstream GMod pipeline (stencil
--                  silhouette -> blur -> add/sub composite), ported from
--                  Facepunch/garrysmod modules/halo.lua.  Captures resolve
--                  the framebuffer through render.UpdateScreenEffectTexture
--                  into the ENGINE's _rt_FullFrameFB pair
--                  (GetScreenEffectTexture hands those out) -- the copy
--                  registration is what makes the restore/composite quads
--                  sample a real frame; the unregistered dedicated RTs tried
--                  first drew black.  Restore/composite quads go through
--                  render.DrawScreenQuadWithTexture; blur is the ORIGIN
--                  Source BlurFilterX/Y separable gaussian driven from
--                  lrender.cpp (no GMod g_blurx plugin needed).  The pass
--                  runs under a pcall fuse.
--   halo_draw 2  (DEFAULT)  RenderRim -- stencil-masked edge ring; no render
--                  targets, nothing in it CAN black the screen.
--   halo_draw 0     RenderSafe -- the old whole-model flat tint.
--
-- The convars are CREATED here (they used to be query-only, so typing
-- halo_debug in the console answered "unknown command").

if ( CreateClientConVar != nil ) then
	-- 2026-09-24 (second pass): halo_render was renamed to halo_draw -- the
	-- archive carried a stale halo_render=2 from an earlier default that kept
	-- re-selecting the broken rim.  halo_draw 1 (RT, the GMod pipeline) is
	-- now usable: the restore/composite quads go through the new
	-- render.DrawScreenQuadWithTexture binding (the old mat_Copy:SetTexture
	-- calls landed on the Material() stub wrapper and did NOTHING -- that was
	-- the real black-screen).
	CreateClientConVar( "halo_draw", "1", true, false, "Halo renderer: 0 = flat tint, 1 = upstream RT pipeline (default), 2 = stencil rim" )
end

local matHalo	= Material( "models/effects/hl2sb_physgun_glow" )
local matRim	= Material( "models/effects/hl2sb_halo_rim" )
local List		= {}
local RenderEnt = NULL
local modelFlags = bit.bor( STUDIO_RENDER, STUDIO_SKIP_DECALS or 0 )

-- HL2SB (2026-09-24): convar access that does NOT depend on GetConVar /
-- CreateClientConVar.  Both are entangled in the unfinished gmod_compat
-- convar bridge (the other session's active battle: lconvar.cpp ConVar_IsValid
-- + Lua-convar engine registration landed at 06:05, but GetConVar still
-- answers nil for every name in the running client).  The engine's own
-- ConVar global does not go through that bridge at all: single argument =
-- query (nil when missing, per lconvar.cpp), multi-argument = create with
-- the ENGINE positional layout (name, def, flags, help, bMin, fMin, bMax,
-- fMax) -- the same mapping gmod_globals uses server-side.
local function CvConVar( name, sDefault )
	local ok, cv = pcall( ConVar, name )		-- query, never creates
	if ( ok && cv != nil ) then return cv end
	pcall( ConVar, name, sDefault, 0, "", false, 0, false, 0 )	-- create
	ok, cv = pcall( ConVar, name )
	if ( ok ) then return cv end
	return nil
end

local function CvInt( name, iDefault )
	local cv = CvConVar( name, tostring( iDefault or 0 ) )
	if ( cv != nil && cv.GetInt != nil ) then
		local ok, v = pcall( cv.GetInt, cv )
		if ( ok && type( v ) == "number" ) then return v end
	end
	return iDefault
end

-- HL2SB (2026-09-24): the engine's whole-body glow shell (physgun_halo_shell,
-- c_baseanimating.cpp) double-draws against the Lua outline -- a second tint
-- in the same colour family that saturates to a flat fill on bright
-- backgrounds, i.e. the second colour of the 20:43 flicker.  Editing
-- cfg/config.cfg does not hold: archived convars are written back at shutdown
-- with their LIVE values, and the shell booted "1" again overnight.  Force it
-- off where the ring lives instead.  SetInt is bound on the ConVar userdata
-- (lconvar.cpp ConVar_SetInt); pcall in case the convar bridge changes.
do
	local cv = CvConVar( "physgun_halo_shell", "0" )
	if ( cv != nil && cv.SetInt != nil ) then
		pcall( cv.SetInt, cv, 0 )
	end
end

function Add( entities, color, blurx, blury, passes, add, ignorez )

	if ( table.IsEmpty( entities ) ) then return end

	local t =
	{
		Ents		= entities,
		Color		= color,
		BlurX		= blurx or 2,
		BlurY		= blury or 2,
		DrawPasses	= passes or 1,
		Additive	= ( add == nil ) and true or add,
		IgnoreZ		= ignorez
	}

	table.insert( List, t )

end

function RenderedEntity()
	return RenderEnt
end

local function CollectValid( entry )

	local targets = {}
	for k, v in pairs( entry.Ents ) do
		-- HL2SB: GetNoDraw is not bound in this engine -- duck-type it.
		local bNoDraw = false
		if ( IsValid( v ) and type( v.GetNoDraw ) == "function" ) then
			bNoDraw = v:GetNoDraw() and true or false
		end
		if ( IsValid( v ) and !bNoDraw ) then
			targets[ #targets + 1 ] = v
		end
	end
	return targets

end

local function RenderSafe( entry )

	-- HL2SB (2026-09-22): the silhouette MUST be drawn inside a 3D camera.
	-- PostDrawEffects runs after the engine cleaned up the main 3D view, so
	-- without cam.Start3D the matrices are stale/identity and the shell draws
	-- off-screen -- the "chain works but nothing glows" symptom.
	cam.Start3D()

	render.SuppressEngineLighting( true )

	local entryColor = entry.Color
	render.SetColorModulation( ( entryColor.r or 255 ) / 255, ( entryColor.g or 255 ) / 255, ( entryColor.b or 255 ) / 255 )
	render.SetBlend( ( ( entryColor.a or 255 ) / 255 ) * 0.85 )

	render.ModelMaterialOverride( matHalo )

	for k, v in pairs( entry.Ents ) do
		if ( IsValid( v ) ) then
			RenderEnt = v
			v:DrawModel( modelFlags )
		end
	end

	render.ModelMaterialOverride( nil )
	render.SetBlend( 1 )
	render.SetColorModulation( 1, 1, 1 )
	render.SuppressEngineLighting( false )

	cam.End3D()

	RenderEnt = NULL

end

local RIM_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 0.71, 0.71 }, { -0.71, 0.71 }, { 0.71, -0.71 }, { -0.71, -0.71 } }

local function RenderRim( entry )

	local entryColor = entry.Color
	local size = ( ( entry.BlurX or 2 ) + ( entry.BlurY or 2 ) ) * 0.5

	local targets = CollectValid( entry )
	if ( #targets == 0 ) then return end

	-- HL2SB (2026-09-24): heavy models pay SetupBones + a full DrawModel PER
	-- PASS -- nine draws per frame of an airboat, on top of this fork running
	-- under x64 emulation on ARM, was the "抓载具掉帧很严重" cliff.  Vehicles
	-- drop to FOUR cardinal passes with a 1.5x wider step (same
	-- thickness/coverage ratio as the 8-pass ring, so it still reads
	-- continuous); props/NPCs keep the full 8.
	local dirs = RIM_DIRS
	local degMul = 1
	local t1 = targets[ 1 ]
	if ( t1 != nil && t1.IsVehicle != nil && t1:IsVehicle() ) then
		dirs = { RIM_DIRS[ 1 ], RIM_DIRS[ 2 ], RIM_DIRS[ 3 ], RIM_DIRS[ 4 ] }
		degMul = 1.5
	end
	-- HL2SB (2026-09-24): "轮廓线条不应该是这么粗的应该是线条" -- the 0.30
	-- base read as a band, not a line.  Halved to ~0.16 deg (x1.5 on
	-- vehicles); the angular jitter below shrank with it, +-0.025 deg was
	-- +-15% of the new step and made the thin line crawl.
	local deg = ( 0.16 + 0.07 * ( size - 1 ) ) * degMul		-- ~0.16..0.23 deg (x1.5 on vehicles)

	-- HL2SB (2026-09-24): view base.  render.MainViewOrigin/Angles were tried
	-- here and the ring went INVISIBLE (user capture 02:01) -- what that
	-- returns at PostDrawEffects time does not match the live frame view.
	-- LocalPlayer's eye is the variant PROVEN to render (00:44 capture); its
	-- small interpolation offset beats no ring at all.
	local ply = ( type( LocalPlayer ) == "function" ) and LocalPlayer() or NULL
	local eyePos, eyeAng
	if ( IsValid( ply ) ) then
		eyePos = ply:EyePos()
		eyeAng = ply:EyeAngles()
	end

	cam.Start3D()

		-- The rotated hull passes displace the WHOLE silhouette on screen, not
		-- just the rim -- the background behind the object is farther away, so
		-- depth alone cannot clip the displaced hulls, and 8 additive passes
		-- saturate to the solid-white blob of the 02:51 capture.  Stencil mask
		-- fixes it: mark the TRUE silhouette with an invisible draw (blend 0
		-- still writes stencil), then the rotated hulls draw only OUTSIDE it
		-- (STENCIL_NOTEQUAL) -- what survives is exactly the ring.
		-- ⚠️ render.Clear is NOT usable here: this branch's Clear binding
		-- unconditionally clears the COLOR buffer too (ClearBuffers(true,...)),
		-- which blacked the frame every hold.  Clear the stencil through the
		-- rectangle helper instead.
		render.ClearStencilBufferRectangle( 0, 0, ScrW(), ScrH(), 0 )

		render.SetStencilEnable( true )
		render.SetStencilWriteMask( 1 )
		render.SetStencilTestMask( 1 )
		render.SetStencilReferenceValue( 1 )
		render.SetStencilCompareFunction( STENCIL_ALWAYS )
		render.SetStencilPassOperation( STENCIL_REPLACE )
		render.SetStencilFailOperation( STENCIL_KEEP )
		render.SetStencilZFailOperation( STENCIL_KEEP )

			-- HL2SB (2026-09-24): the stencil MARK draws with depth IGNORED.
			-- Vehicles (and any interpolation frame) failed the LEQUAL test
			-- against the scene's own depth, left their silhouette UNMARKED,
			-- and STENCIL_NOTEQUAL then let all eight offset hull passes
			-- paint the whole body ("对车辆是错误全覆盖效果"); the same
			-- tie also dropped marks at random frames ("会闪").  A blind
			-- mark writes a stable screen-space silhouette every frame.
			-- The hull passes below keep normal depth so rings still hide
			-- behind foreground geometry.
			render.ModelMaterialOverride( matRim )
			render.SetBlend( 0 )		-- invisible, stencil still written
			cam.IgnoreZ( true )
			for k = 1, #targets do
				RenderEnt = targets[ k ]
				targets[ k ]:DrawModel( modelFlags )
			end

			-- the ring: rotated hulls, front faces culled, only outside the true
			-- silhouette
			cam.IgnoreZ( entry.IgnoreZ == true )
			render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
		render.CullMode( 1 )	-- MATERIAL_CULLMODE_CW: front faces culled
		render.SetColorModulation( ( entryColor.r or 255 ) / 255, ( entryColor.g or 255 ) / 255, ( entryColor.b or 255 ) / 255 )
		render.SetBlend( ( ( entryColor.a or 255 ) / 255 ) * 0.9 )

		for i = 1, #dirs do

			local d = dirs[ i ]
			local jitter = ( math.random() - 0.5 ) * 0.02
			local dp = d[ 2 ] * ( deg + jitter )
			local dy = d[ 1 ] * ( deg + jitter )

			local p, y, r = 0, 0, 0
			if ( eyeAng != nil ) then p, y, r = eyeAng.p, eyeAng.y, eyeAng.r end

			cam.Start3D( eyePos, Angle( p + dp, y + dy, r ) )

			for k = 1, #targets do
				RenderEnt = targets[ k ]
				targets[ k ]:DrawModel( modelFlags )
			end

			cam.End3D()

		end

		RenderEnt = NULL
		render.ModelMaterialOverride( nil )
		render.SetBlend( 1 )
		render.SetColorModulation( 1, 1, 1 )
		render.CullMode( 0 )	-- MATERIAL_CULLMODE_CCW: engine default
		render.SetStencilEnable( false )
		render.SetStencilTestMask( 0 )
		render.SetStencilWriteMask( 0 )
		render.SetStencilReferenceValue( 0 )

	cam.End3D()

end

-- Upstream stencil/blur renderer (halo_draw 1), ported from
-- Facepunch/garrysmod modules/halo.lua.  Captures go through
-- render.UpdateScreenEffectTexture (resolve + SetFrameBufferCopyTexture
-- registration) into the engine FB pair handed out by
-- render.GetScreenEffectTexture; blur is the origin BlurFilterX/Y gaussian.
local rt_Store		= render.GetScreenEffectTexture( 0 )
local rt_Blur		= render.GetScreenEffectTexture( 1 )

local function RenderRT( entry )

	local rt_Scene = render.GetRenderTarget()

	-- HL2SB (2026-09-24): the engine's own screen-effect capture -- resolve
	-- FB into the engine texture + register the copy for samplers.
	render.UpdateScreenEffectTexture( 0 )

	if ( entry.Additive ) then
		render.Clear( 0, 0, 0, 255, false, true )
	else
		render.Clear( 255, 255, 255, 255, false, true )
	end
	-- Upstream relies on a clean stencil from Clear's flag; this fork's Clear
	-- binding always wipes COLOR and the stencil flag was not trustworthy
	-- (same finding as RenderRim), so zero it through the rectangle helper.
	render.ClearStencilBufferRectangle( 0, 0, ScrW(), ScrH(), 0 )

	-- For certain materials this is necessary to not have the entire screen
	-- go pitch black (upstream: the Episode 2 GMan glass doors).
	render.UpdateRefractTexture()

	cam.Start3D()
		render.SetStencilEnable( true )
			render.SuppressEngineLighting( true )
			cam.IgnoreZ( entry.IgnoreZ == true )

				render.SetStencilWriteMask( 1 )
				render.SetStencilTestMask( 1 )
				render.SetStencilReferenceValue( 1 )

				render.SetStencilCompareFunction( STENCIL_ALWAYS )
				render.SetStencilPassOperation( STENCIL_REPLACE )
				render.SetStencilFailOperation( STENCIL_KEEP )
				render.SetStencilZFailOperation( STENCIL_KEEP )

					-- CollectValid duck-types GetNoDraw (not bound in this
					-- engine) -- the raw v:GetNoDraw() below died in pcall
					-- every frame and silently ate the whole pass.
					local targets = CollectValid( entry )
					for k = 1, #targets do
						RenderEnt = targets[ k ]
						targets[ k ]:DrawModel( modelFlags )
					end

					RenderEnt = NULL

				render.SetStencilCompareFunction( STENCIL_EQUAL )
				render.SetStencilPassOperation( STENCIL_KEEP )

					cam.Start2D()
						local entryColor = entry.Color
						surface.SetDrawColor( entryColor.r, entryColor.g, entryColor.b, entryColor.a )
						surface.DrawRect( 0, 0, ScrW(), ScrH() )
					cam.End2D()

			cam.IgnoreZ( false )
			render.SuppressEngineLighting( false )
		render.SetStencilEnable( false )
	cam.End3D()

	-- Store a blurred version of the colored silhouettes (engine FB -> FB1
	-- resolve, the same registered-copy path as the first capture).
	render.UpdateScreenEffectTexture( 1 )
	render.BlurRenderTarget( rt_Blur, entry.BlurX, entry.BlurY, 1 )

	-- Restore the original scene.  Blend/modulation are forced sane first --
	-- an invisible-restore bug looks identical to a black capture.
	render.SetBlend( 1 )
	render.SetColorModulation( 1, 1, 1 )
	render.SetRenderTarget( rt_Scene )
	render.DrawScreenQuadWithTexture( rt_Store, "pp/copy" )

	-- Draw back our blurred colored props additively/subtractively, ignoring
	-- the high bits.  Upstream picks the blend material ONCE then draws
	-- passes+1 times.
	render.SetStencilEnable( true )

		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )

		local szBlend = entry.Additive and "pp/add" or "pp/sub"
		for i = 0, entry.DrawPasses do
			render.DrawScreenQuadWithTexture( rt_Blur, szBlend )
		end

	render.SetStencilEnable( false )

	render.SetStencilTestMask( 0 )
	render.SetStencilWriteMask( 0 )
	render.SetStencilReferenceValue( 0 )

end

function Render( entry )
	-- HL2SB (2026-09-24): DEFAULT = 2 (stencil rim outline) -- it needs no
	-- render targets, no frame copies and no composite quads, so it delivers
	-- the physgun outline TODAY while the RT pipeline's last display bug is
	-- being bisected.  halo_draw 1 = the upstream RT+gaussian pipeline,
	-- halo_draw 0 = flat tint.  Read through CvInt (see top of file).
	local mode = CvInt( "halo_draw", 2 )

	if ( mode == 0 ) then
		return RenderSafe( entry )
	end
	if ( mode == 1 ) then
		return RenderRT( entry )
	end
	return RenderRim( entry )
end

hook.Add( "PostDrawEffects", "RenderHalos", function()

	-- Upstream parity: addons (the sandbox physgun halo among them) call
	-- halo.Add from PreDrawHalos -- it must fire EVERY frame, even when
	-- nothing is queued yet, or feed hooks never run.
	hook.Run( "PreDrawHalos" )

	if ( #List == 0 ) then return end

	for k, v in ipairs( List ) do

		-- The fuse: a failure inside Render must never leave the frame
		-- half-rendered (that is the black screen of 2026-09-22).
		local rt_Scene = render.GetRenderTarget()

		local ok, err = pcall( Render, v )

		if ( !ok ) then

			-- rt_Scene is nil when the current target is the backbuffer.
			if ( rt_Scene != nil ) then
				render.SetRenderTarget( rt_Scene )
			end
			render.SetStencilEnable( false )
			render.SetStencilTestMask( 0 )
			render.SetStencilWriteMask( 0 )
			render.SetStencilReferenceValue( 0 )
			render.ModelMaterialOverride( nil )
			render.SetBlend( 1 )
			render.SetColorModulation( 1, 1, 1 )
			render.CullMode( 0 )

			local Write = ErrorNoHalt or Msg or print
			if ( Write != nil ) then
				Write( "[HL2SB halo] render failed: " .. tostring( err ) )
			end
			-- print() is proven to land in BOTH engine.log and the lua log
			-- (the banner rides the same path); ErrorNoHalt alone has been
			-- console-only in practice, which made earlier failures invisible
			-- to post-mortem greps.
			print( "[HL2SB halo] render failed: " .. tostring( err ) )

		end

	end

	List = {}

end )
