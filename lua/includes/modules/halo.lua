
module( "halo", package.seeall )

-- HL2SB (2026-09-23): the halo renderer.
--
-- DEFAULT (2026-09-23): the upstream stencil + screen-copy + blur pipeline
-- (RenderRT below), ported verbatim from Facepunch/garrysmod
-- lua/includes/modules/halo.lua and re-verified against it line by line.
-- Fork adaptations, forced by this DX9 layer, all verified 2026-09-22/23:
--   * the frame copies use the engine-proven render.CopyFrameToTexture
--     (the plain CopyRenderTargetToTexture came back black here);
--   * every Render call runs under a pcall fuse so a mid-pipeline failure
--     can never leave the frame half-rendered (the 2026-09-22 black screen);
--   * halo_debug 1 freezes on the RT-copy diagnostic frame.
--
-- The old safe whole-model tint (RenderSafe) survives as the explicit
-- fallback behind `halo_use_rt 0`.  That look wraps the entity in ONE flat
-- color -- it is NOT the wiki edge-ring and must not be the default.

local matHalo	= Material( "models/effects/hl2sb_physgun_glow" )
local List		= {}
local RenderEnt = NULL
local modelFlags = bit.bor( STUDIO_RENDER, STUDIO_SKIP_DECALS or 0 )
local bDbgAlive, bDbgFeed2 = false, false

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
		-- HL2SB: GetNoDraw is not bound in this engine -- duck-type it.
		local bNoDraw = false
		if ( IsValid( v ) and type( v.GetNoDraw ) == "function" ) then
			bNoDraw = v:GetNoDraw() and true or false
		end
		if ( IsValid( v ) and !bNoDraw ) then
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

-- Upstream stencil/blur renderer (the ONLY way to the wiki's edge-ring look),
-- ported verbatim from Facepunch/garrysmod modules/halo.lua with the
-- CopyFrameToTexture adaptation.  This is the DEFAULT renderer since
-- 2026-09-23; `halo_use_rt 0` falls back to RenderSafe.
-- halo_debug 1 renders ONLY the scene copy after the first RT copy: scene
-- visible = the DX9 copy works; black = the copy is the broken step.
local mat_Copy		= Material( "pp/copy" )
local mat_Add		= Material( "pp/add" )
local mat_Sub		= Material( "pp/sub" )
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
		mat_Copy:SetTexture( "$basetexture", rt_Store )
		mat_Copy:SetString( "$color", "1 1 1" )
		mat_Copy:SetString( "$alpha", "1" )
		render.SetMaterial( mat_Copy )
		render.DrawScreenQuad()
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
	mat_Copy:SetTexture( "$basetexture", rt_Store )
	mat_Copy:SetString( "$color", "1 1 1" )
	mat_Copy:SetString( "$alpha", "1" )
	render.SetMaterial( mat_Copy )
	render.DrawScreenQuad()

	render.SetStencilEnable( true )

		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )

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

	render.SetStencilTestMask( 0 )
	render.SetStencilWriteMask( 0 )
	render.SetStencilReferenceValue( 0 )

end

local cvarUseRT

function Render( entry )
	-- HL2SB (2026-09-23): default is the UPSTREAM RT edge-ring pipeline
	-- (verified verbatim against Facepunch/garrysmod modules/halo.lua), which
	-- is what the whole halo library exists for.  The safe whole-model tint
	-- (RenderSafe) is the explicit fallback behind `halo_use_rt 0` -- that is
	-- the "whole object wrapped in one flat color" look, NOT the wiki look.
	-- halo_debug 1 still freezes on the RT-copy diagnostic frame.
	cvarUseRT = cvarUseRT or GetConVar( "halo_use_rt" )
	if ( cvarUseRT != nil and cvarUseRT:GetInt() == 0 ) then
		return RenderSafe( entry )
	end
	return RenderRT( entry )
end

hook.Add( "PostDrawEffects", "RenderHalos", function()

	-- HL2SB diagnostic one-shot: is the engine even firing this hook?
	if ( !bDbgAlive ) then
		bDbgAlive = true
		Msg( "[HL2SB halo] link3 PostDrawEffects alive\n" )
	end

	hook.Run( "PreDrawHalos" )

	if ( #List == 0 ) then return end

	if ( !bDbgFeed2 ) then
		bDbgFeed2 = true
		Msg( "[HL2SB halo] link4 render: " .. #List .. " halo entry(ies)\n" )
	end

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

			local Write = ErrorNoHalt or Msg or print
			if ( Write != nil ) then
				Write( "[HL2SB halo] render failed: " .. tostring( err ) )
			end

		end

	end

	List = {}

end )
