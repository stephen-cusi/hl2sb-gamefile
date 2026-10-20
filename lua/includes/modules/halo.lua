-- GMod's stencil silhouette, separable blur and exterior composite.
-- Build the silhouette offscreen so a failed pass preserves the scene color.
if ( _G.halo and _G.halo.Add and _G.halo.RenderedEntity ) then
	return _G.halo
end

module( "halo", package.seeall )

local mat_Add = Material( "pp/add" )
local mat_Sub = Material( "pp/sub" )
local mat_BlurX = Material( "pp/blurx" )
local mat_BlurY = Material( "pp/blury" )
local List = {}
local RenderEnt = NULL
local rendering = false
local lastError
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

local function CheckResources( entry )
	local composite = entry.Additive and mat_Add or mat_Sub
	for _, mat in ipairs( { composite, mat_BlurX, mat_BlurY } ) do
		if ( mat == nil or mat:IsErrorMaterial() ) then
			error( "halo material unavailable" )
		end
	end

	-- Engine frame buffers resize with the backbuffer and share its depth and
	-- stencil. A target with a separate depth buffer would lose scene occlusion.
	local mask = render.GetScreenEffectTexture( 1 )
	local ping = render.GetBloomTex1()
	if ( mask == nil or mask:IsError() or ping == nil or ping:IsError() ) then
		error( "halo render target unavailable" )
	end
	if ( mask:GetActualWidth() != ScrW() or mask:GetActualHeight() != ScrH() ) then
		error( "halo render target does not match the screen size" )
	end
	return mask, composite
end

local function ResetState()
	RenderEnt = NULL
	render.SetStencilEnable( false )
	render.SetStencilTestMask( 0 )
	render.SetStencilWriteMask( 0 )
	render.SetStencilReferenceValue( 0 )
	render.ModelMaterialOverride( nil )
	render.SetBlend( 1 )
	render.SetColorModulation( 1, 1, 1 )
	render.SuppressEngineLighting( false )
	cam.IgnoreZ( false )
end

function Render( entry )
	if ( rendering ) then return end
	rendering = true

	local scene = render.GetRenderTarget()
	local inTarget, in3D, in2D = false, false, false
	local ok, err = pcall( function()
		local mask, composite = CheckResources( entry )
		if ( scene != nil and scene:GetName() == mask:GetName() ) then return end

		render.PushRenderTarget( mask )
		inTarget = true
		render.SetStencilEnable( false )
		render.SetStencilWriteMask( 255 )
		if ( entry.Additive ) then
			render.Clear( 0, 0, 0, 255, false, true )
		else
			render.Clear( 255, 255, 255, 255, false, true )
		end
		render.UpdateRefractTexture()

		cam.Start3D()
		in3D = true
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

		for _, ent in pairs( entry.Ents ) do
			if ( !IsValid( ent ) or ent:GetNoDraw() ) then continue end
			RenderEnt = ent
			ent:DrawModel( modelFlags )
		end
		RenderEnt = NULL

		render.SetStencilCompareFunction( STENCIL_EQUAL )
		render.SetStencilPassOperation( STENCIL_KEEP )
		cam.Start2D()
		in2D = true
		local color = entry.Color
		surface.SetDrawColor( color.r, color.g, color.b, color.a )
		surface.DrawRect( 0, 0, ScrW(), ScrH() )
		cam.End2D()
		in2D = false
		cam.IgnoreZ( false )
		render.SuppressEngineLighting( false )
		render.SetStencilEnable( false )
		cam.End3D()
		in3D = false
		render.PopRenderTarget()
		inTarget = false

		-- This is the original pp/blurx + pp/blury ping-pong implementation.
		render.BlurRenderTarget( mask, entry.BlurX, entry.BlurY, 1 )
		render.SetRenderTarget( scene )
		composite:SetTexture( "$basetexture", mask )
		render.SetMaterial( composite )
		render.SetStencilEnable( true )
		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
		for i = 0, entry.DrawPasses do
			render.DrawScreenQuad()
		end
	end )

	-- Unwind each owned scope before restoring state, including on Lua errors.
	if ( in2D ) then cam.End2D() end
	if ( in3D ) then cam.End3D() end
	if ( inTarget ) then render.PopRenderTarget() end
	render.SetRenderTarget( scene )
	ResetState()
	rendering = false
	if ( !ok and err != lastError ) then
		lastError = err
		print( "[HL2SB halo] " .. tostring( err ) )
	elseif ( ok ) then
		lastError = nil
	end
end

hook.Add( "PostDrawEffects", "RenderHalos", function()
	hook.Run( "PreDrawHalos" )
	local entries = List
	List = {}
	for _, entry in ipairs( entries ) do
		Render( entry )
	end
end )
