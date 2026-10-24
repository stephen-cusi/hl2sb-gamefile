module( "halo", package.seeall )

local mat_Copy = Material( "pp/copy" )
local mat_Add = Material( "pp/add" )
local mat_Sub = Material( "pp/sub" )
local rt_Store = render.GetScreenEffectTexture( 0 )
local rt_Blur = render.GetScreenEffectTexture( 1 )

local List = {}
local RenderEnt = NULL
local modelFlags = bit.bor( STUDIO_RENDER, STUDIO_SKIP_DECALS or 0 )

function Add( entities, color, blurx, blury, passes, add, ignorez )
	if ( table.IsEmpty( entities ) ) then return end
	if ( add == nil ) then add = true end
	if ( ignorez == nil ) then ignorez = false end
	table.insert( List, {
		Ents = entities,
		Color = color,
		BlurX = blurx or 2,
		BlurY = blury or 2,
		DrawPasses = passes or 1,
		Additive = add,
		IgnoreZ = ignorez
	} )
end

function RenderedEntity()
	return RenderEnt
end

function Render( entry )
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

hook.Add( "PostDrawEffects", "RenderHalos", function()
	hook.Run( "PreDrawHalos" )
	if ( #List == 0 ) then return end
	for k, v in ipairs( List ) do
		Render( v )
	end
	List = {}
end )
