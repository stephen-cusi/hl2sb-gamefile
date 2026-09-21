
module( "halo", package.seeall )

-- HL2SB (2026-09-22): SAFE halo renderer.
--
-- Upstream GMod renders halos through a stencil + screen-copy + blur pipeline
-- (pp/copy, pp/add, render.BlurRenderTarget ...).  This engine branch cannot
-- support that faithfully yet:
--   * there are no screenspace blur pixel shaders, so the blur is a
--     downsample-upsample approximation;
--   * copying the BACKBUFFER into a render target does not survive this
--     DX9 layer (the copy comes back black/garbage), which black-screened the
--     whole frame for as long as the beam was held.
--
-- So halos here are drawn the way the physgun's held-entity glow already
-- works: an additive flat material forced over the entity's own DrawModel
-- (render.ModelMaterialOverride + render.SetColorModulation/SetBlend).
-- No render targets, no copies, no clears -- nothing that CAN black the
-- screen.  The visual is a crisp colored glow rather than a blurred ring;
-- the RT pipeline can return behind halo_use_rt once the DX9 copy path is
-- proven, so the upstream renderer is kept below behind that flag.

local matHalo	= Material( "models/effects/hl2sb_physgun_glow" )
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

local function RenderSafe( entry )

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

	RenderEnt = NULL

end

-- Upstream stencil/blur renderer, kept for halo_use_rt 1.  Do not enable
-- until the backbuffer->RT copy is proven in this DX9 layer (see the black
-- screen of 2026-09-22).
local mat_Copy		= Material( "pp/copy" )
local mat_Add		= Material( "pp/add" )
local mat_Sub		= Material( "pp/sub" )
local rt_Store		= render.GetScreenEffectTexture( 0 )
local rt_Blur		= render.GetScreenEffectTexture( 1 )

local function RenderRT( entry )

	local rt_Scene = render.GetRenderTarget()

	render.CopyRenderTargetToTexture( rt_Store )

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

	render.CopyRenderTargetToTexture( rt_Blur )
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

local function Render( entry )
	cvarUseRT = cvarUseRT or GetConVar( "halo_use_rt" )
	if ( cvarUseRT != nil and cvarUseRT:GetInt() == 1 ) then
		return RenderRT( entry )
	end
	return RenderSafe( entry )
end

hook.Add( "PostDrawEffects", "RenderHalos", function()

	hook.Run( "PreDrawHalos" )

	if ( #List == 0 ) then return end

	for k, v in ipairs( List ) do

		-- The fuse: a failure inside Render must never leave the frame
		-- half-rendered (that is the black screen of 2026-09-22).
		local rt_Scene = render.GetRenderTarget()

		local ok, err = pcall( Render, v )

		if ( !ok ) then

			render.SetRenderTarget( rt_Scene )
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
