
module( "halo", package.seeall )
print( "[HL2SB halo] bisect: module() ok\n" )

-- HL2SB (2026-09-24): the halo renderer, three modes behind `halo_render`:
--
--   halo_render 2  (DEFAULT)  RenderRim  -- stencil-free edge ring: the model
--                  is re-drawn 8 times through a flat override material with
--                  FRONT faces culled and the view rotated a fraction of a
--                  degree per pass; the scene depth buffer rejects the offset
--                  hull everywhere except at the silhouette, which reads as a
--                  glow ring around the entity.  No render targets, no frame
--                  copies, no clears -- nothing in it CAN black the screen.
--   halo_render 1  RenderRT   -- the upstream GMod pipeline (stencil + frame
--                  copy + blur + additive composite), ported verbatim from
--                  Facepunch/garrysmod modules/halo.lua.  Adaptations: frame
--                  copies go through render.CopyFrameToTexture (the plain
--                  CopyRenderTargetToTexture came back black here); the whole
--                  pass runs under a pcall fuse.  NOTE: with the pp materials
--                  installed this pipeline RUNS in this engine but the
--                  restore/composite was observed to dim/offset the frame
--                  (2026-09-24 user capture) -- kept for debugging, not the
--                  default.  halo_debug 1 freezes on the RT-copy frame.
--   halo_render 0  RenderSafe -- the old whole-model flat tint.
--
-- The convars are CREATED here (they used to be query-only, so typing
-- halo_debug in the console answered "unknown command").

print( "[HL2SB halo] bisect: before convars\n" )
if ( CreateClientConVar != nil ) then
	-- 2026-09-24 (second pass): halo_render was renamed to halo_draw -- the
	-- archive carried a stale halo_render=2 from an earlier default that kept
	-- re-selecting the broken rim.  halo_draw 1 (RT, the GMod pipeline) is
	-- now usable: the restore/composite quads go through the new
	-- render.DrawScreenQuadWithTexture binding (the old mat_Copy:SetTexture
	-- calls landed on the Material() stub wrapper and did NOTHING -- that was
	-- the real black-screen).
	CreateClientConVar( "halo_draw", "1", true, false, "Halo renderer: 0 = flat tint, 1 = upstream RT pipeline (default), 2 = stencil rim" )
	CreateClientConVar( "halo_debug", "0", true, false, "Halo: freeze after the RT scene copy (halo_draw 1 only)" )
end

print( "[HL2SB halo] bisect: convars ok\n" )
local matHalo	= Material( "models/effects/hl2sb_physgun_glow" )
local matRim	= Material( "models/effects/hl2sb_halo_rim" )
local List		= {}
local RenderEnt = NULL
local modelFlags = bit.bor( STUDIO_RENDER, STUDIO_SKIP_DECALS or 0 )

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
	local deg = 0.30 + 0.14 * ( size - 1 )		-- ~0.3..0.44 degrees per pass

	local targets = CollectValid( entry )
	if ( #targets == 0 ) then return end

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

		render.ModelMaterialOverride( matRim )
		render.SetBlend( 0 )		-- invisible, stencil still written
		for k = 1, #targets do
			RenderEnt = targets[ k ]
			targets[ k ]:DrawModel( modelFlags )
		end

		-- the ring: rotated hulls, front faces culled, only outside the true
		-- silhouette
		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
		render.CullMode( 1 )	-- MATERIAL_CULLMODE_CW: front faces culled
		render.SetColorModulation( ( entryColor.r or 255 ) / 255, ( entryColor.g or 255 ) / 255, ( entryColor.b or 255 ) / 255 )
		render.SetBlend( ( ( entryColor.a or 255 ) / 255 ) * 0.9 )

		for i = 1, #RIM_DIRS do

			local d = RIM_DIRS[ i ]
			local jitter = ( math.random() - 0.5 ) * 0.05
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

-- Upstream stencil/blur renderer (halo_render 1).  Ported verbatim from
-- Facepunch/garrysmod modules/halo.lua with the CopyFrameToTexture
-- adaptation; kept for debugging/reference, not the default (see header).
-- halo_debug 1 renders ONLY the scene copy after the first RT copy: scene
-- visible = the DX9 copy works; black = the copy is the broken step.
-- 2026-09-24: the pp materials are driven through
-- render.DrawScreenQuadWithTexture now -- Material() is a stub wrapper in
-- this fork (SetTexture/SetString on it were silent no-ops, which is what
-- actually black-screened this pipeline), so we never touch it from Lua.
print( "[HL2SB halo] bisect: materials ok\n" )
local rt_Store		= render.GetScreenEffectTexture( 0 )
local rt_Blur		= render.GetScreenEffectTexture( 1 )

local function RenderRT( entry )

	local rt_Scene = render.GetRenderTarget()

	-- HL2SB: the engine-proven frame copy (CopyRenderTargetToTextureEx with
	-- the view rect, same as the engine's freeze frame).  The plain
	-- CopyRenderTargetToTexture came back BLACK in this DX9 layer.
	render.CopyFrameToTexture( rt_Store )

	-- halo_debug 1: show what the RT copy actually captured, then stop.
	local cvarDbg = GetConVar( "halo_debug" )
	if ( cvarDbg != nil and cvarDbg:GetInt() == 1 ) then
		render.SetRenderTarget( rt_Scene )
		render.DrawScreenQuadWithTexture( rt_Store, "pp/copy" )
		return
	end

	if ( entry.Additive ) then
		render.Clear( 0, 0, 0, 255, false, true )
	else
		render.Clear( 255, 255, 255, 255, false, true )
	end

	render.UpdateRefractTexture()

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

					cam.Start2D()
						local entryColor = entry.Color
						surface.SetDrawColor( entryColor.r, entryColor.g, entryColor.b, entryColor.a )
						surface.DrawRect( 0, 0, ScrW(), ScrH() )
					cam.End2D()

			cam.IgnoreZ( false )
			render.SuppressEngineLighting( false )
		render.SetStencilEnable( false )
	cam.End3D()

	render.CopyFrameToTexture( rt_Blur )
	render.BlurRenderTarget( rt_Blur, entry.BlurX, entry.BlurY, 1 )

	render.SetRenderTarget( rt_Scene )
	render.DrawScreenQuadWithTexture( rt_Store, "pp/copy" )

	render.SetStencilEnable( true )

		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )

		if ( entry.Additive ) then
			render.DrawScreenQuadWithTexture( rt_Blur, "pp/add" )
		else
			render.DrawScreenQuadWithTexture( rt_Blur, "pp/sub" )
		end

		for i = 1, entry.DrawPasses do
			render.DrawScreenQuadWithTexture( rt_Blur, "pp/add" )
		end

	render.SetStencilEnable( false )

	render.SetStencilTestMask( 0 )
	render.SetStencilWriteMask( 0 )
	render.SetStencilReferenceValue( 0 )

end

local cvarDraw

function Render( entry )
	-- HL2SB (2026-09-24): default 1 = the upstream RT pipeline, now that the
	-- restore/composite quads work (DrawScreenQuadWithTexture).  0 = flat
	-- tint, 2 = stencil rim.
	cvarDraw = cvarDraw or GetConVar( "halo_draw" )
	local mode = ( cvarDraw != nil ) and cvarDraw:GetInt() or 1

	if ( mode == 0 ) then
		return RenderSafe( entry )
	end
	if ( mode == 2 ) then
		return RenderRim( entry )
	end
	return RenderRT( entry )
end

print( "[HL2SB halo] bisect: RT locals ok\n" )
-- load banner (2026-09-24): halo.lua was silently dying at load on the
-- ConsoleVariables nil-index; this line proves the module reached its end.
local cvDraw = GetConVar( "halo_draw" )
print( "[HL2SB] halo.lua loaded OK (halo_draw=" .. ( ( cvDraw != nil ) and cvDraw:GetInt() or "nil" ) .. ")\n" )

hook.Add( "PostDrawEffects", "RenderHalos", function()

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

		end

	end

	List = {}

end )
