
-- We don't want this to run in menu state, and render.GetAmbientLightColor doesn't exist in menu state
if ( !render || !render.GetAmbientLightColor ) then return end
--[[---------------------------------------------------------
	Name: GetRenderTarget( name, width, height )
	Desc: GMod's global helper -- returns the named render target
	      texture, creating it the first time.  GMod's own doc comment
	      in gmod_tool/cl_viewscreen.lua:7 spells the contract:
	      "GetRenderTarget returns the texture if it exists, or creates
	      it if it doesn't".  This fork's engine binding with the same
	      create-or-find semantics is render.CreateNamedRenderTarget
	      (game/client/lua/lrender.cpp), so the global is answered on
	      top of it -- the reference file calls it unqualified.
-----------------------------------------------------------]]
function GetRenderTarget( name, wide, tall )

	return render.CreateNamedRenderTarget( name, wide, tall )

end


--[[---------------------------------------------------------
  Short aliases for stencil constants
-----------------------------------------------------------]]

STENCIL_NEVER = STENCILCOMPARISONFUNCTION_NEVER
STENCIL_LESS = STENCILCOMPARISONFUNCTION_LESS
STENCIL_EQUAL = STENCILCOMPARISONFUNCTION_EQUAL
STENCIL_LESSEQUAL = STENCILCOMPARISONFUNCTION_LESSEQUAL
STENCIL_GREATER = STENCILCOMPARISONFUNCTION_GREATER
STENCIL_NOTEQUAL = STENCILCOMPARISONFUNCTION_NOTEQUAL
STENCIL_GREATEREQUAL = STENCILCOMPARISONFUNCTION_GREATEREQUAL
STENCIL_ALWAYS = STENCILCOMPARISONFUNCTION_ALWAYS

STENCIL_KEEP = STENCILOPERATION_KEEP
STENCIL_ZERO = STENCILOPERATION_ZERO
STENCIL_REPLACE = STENCILOPERATION_REPLACE
STENCIL_INCRSAT = STENCILOPERATION_INCRSAT
STENCIL_DECRSAT = STENCILOPERATION_DECRSAT
STENCIL_INVERT = STENCILOPERATION_INVERT
STENCIL_INCR = STENCILOPERATION_INCR
STENCIL_DECR = STENCILOPERATION_DECR

--[[---------------------------------------------------------
   Name:	ClearRenderTarget
   Params: 	<texture> <color>
   Desc:	Clear a render target
-----------------------------------------------------------]]
function render.ClearRenderTarget( rt, color )

	render.PushRenderTarget( rt )
		render.Clear( color.r, color.g, color.b, color.a )
	render.PopRenderTarget()

end


--[[---------------------------------------------------------
   Name:	SupportsHDR
   Params:
   Desc:	Return true if the client supports HDR
-----------------------------------------------------------]]
function render.SupportsHDR( )

	if ( render.GetDXLevel() < 80 ) then return false end

	return true

end


--[[---------------------------------------------------------
   Name:	CopyTexture
   Params: 	<texture from> <texture to>
   Desc:	Copy the contents of one texture to another
-----------------------------------------------------------]]
function render.CopyTexture( from, to )

	render.PushRenderTarget( from )
		render.CopyRenderTargetToTexture( to )
	render.PopRenderTarget()

end

local matColor = Material( "color" )

function render.SetColorMaterial()
	render.SetMaterial( matColor )
end

local matColorIgnoreZ = Material( "color_ignorez" )

function render.SetColorMaterialIgnoreZ()
	render.SetMaterial( matColorIgnoreZ )
end

-- HL2SB (2026-10-16): render.DrawBox( pos, angles, mins, maxs, color ) -- the
-- wireframe-widget cube of the GMod bone tool (lua/entities/widget_base.lua
-- OverlayRender) needs it, and this engine binds no box primitive.  GMod's
-- render.DrawBox is a FILLED box (its separate render.DrawWireframeBox is the
-- outline one; the binding at client.dll 0x1800bddf0 submits a 36-vertex --
-- 12 triangles, 6 quads -- mesh through the currently bound material).
--
-- Implemented here as the six faces through render.DrawQuadEasy, each face
-- drawn twice (front + back normal) because DrawQuadEasy is single-sided and
-- the caller's material decides culling: the widget's cube must be visible
-- from inside as well as outside, and both callers bind an unlit color
-- material whose two-sidedness is not guaranteed.
local function DrawBoxFace( center, normal, wide, tall, color )
	render.DrawQuadEasy( center, normal, wide, tall, color, 0 )
	render.DrawQuadEasy( center, -normal, wide, tall, color, 0 )
end

function render.DrawBox( position, angles, mins, maxs, color )

	position = position or vector_origin
	angles = angles or angle_zero
	mins = mins or Vector( -1, -1, -1 )
	maxs = maxs or Vector( 1, 1, 1 )
	color = color or color_white

	local fwd = angles:Forward()
	local right = angles:Right()
	local up = angles:Up()

	local size = maxs - mins

	-- +x / -x faces: normal along right; the plane spans fwd (size.y) by up (size.z)
	DrawBoxFace( position + right * maxs.x, right, size.y, size.z, color )
	DrawBoxFace( position + right * mins.x, right, size.y, size.z, color )

	-- +y / -y faces: normal along fwd; the plane spans right (size.x) by up (size.z)
	DrawBoxFace( position + fwd * maxs.y, fwd, size.x, size.z, color )
	DrawBoxFace( position + fwd * mins.y, fwd, size.x, size.z, color )

	-- +z / -z faces: normal along up; the plane spans right (size.x) by fwd (size.y)
	DrawBoxFace( position + up * maxs.z, up, size.x, size.y, color )
	DrawBoxFace( position + up * mins.z, up, size.x, size.y, color )

end

-- HL2SB: render.BlurRenderTarget is a C binding (lrender.cpp) -- a
-- downsample-upsample chain on real render targets.  The upstream Lua version
-- drives pp/blurx + pp/blury, screenspace blur pixel-shader materials this
-- engine branch does not ship, so leaving the Lua version here would replace
-- the real blur with an unblurred copy drawn from an error material.

local camera2DTable = { type = "2D" }
function cam.Start2D()

	return cam.Start( camera2DTable )

end

function cam.Start3D( pos, ang, fov, x, y, w, h, znear, zfar )

	local tab = {}

	tab.type = "3D"
	tab.origin = pos
	tab.angles = ang

	if ( fov != nil ) then tab.fov = fov end

	if ( x != nil && y != nil && w != nil && h != nil ) then

		tab.x			= x
		tab.y			= y
		tab.w			= w
		tab.h			= h
		tab.aspect		= ( w / h )

	end

	if ( znear != nil && zfar != nil ) then

		tab.znear	= znear
		tab.zfar	= zfar

	end

	return cam.Start( tab )

end

-- HL2SB (2026-09-22): the shim shipped Start2D/Start3D but never their
-- closers.  halo.lua's PostDrawEffects pass calls cam.Start3D() then
-- cam.End3D(); with End3D missing every halo frame PUSHED a 3D view onto the
-- renderer's view stack and never popped it -- the stack leaked one level per
-- frame, the view matrices drifted, and rendering (animations, muzzle flashes,
-- tracers) went visibly wrong game-wide.
-- HL2SB (2026-10-20): the closers are engine functions now, and they are
-- TYPED (cam.End2D / cam.End3D, matching GMod's library): an unbalanced
-- closer only affects its own kind instead of swallowing the other kind's
-- view.  The old Lua wrappers folded both into cam.End, which is exactly the
-- cross-poisoning shape - do not bring them back.

local matFSB = Material( "pp/motionblur" )

function render.DrawTextureToScreen( tex )

	matFSB:SetFloat( "$alpha", 1.0 )
	matFSB:SetTexture( "$basetexture", tex )

	render.SetMaterial( matFSB )
	render.DrawScreenQuad()

end

function render.DrawTextureToScreenRect( tex, x, y, w, h )

	matFSB:SetFloat( "$alpha", 1.0 )
	matFSB:SetTexture( "$basetexture", tex )

	render.SetMaterial( matFSB )
	render.DrawScreenQuadEx( x, y, w, h )

end


--
-- This isn't very fast. If you're doing something every frame you should find a way to
-- cache a ClientsideModel and keep it around! This is fine for rendering to a render
-- target once - or something.
--

function render.Model( tbl, ent )

	local inent = ent

	if ( ent == nil ) then
		ent = ClientsideModel( tbl.model or "error.mdl", RENDERGROUP_OTHER )
	end

	if ( !IsValid( ent ) ) then return end

	ent:SetModel( tbl.model or "error.mdl" )
	ent:SetNoDraw( true )

	ent:SetPos( tbl.pos or vector_origin )
	ent:SetAngles( tbl.angle or angle_zero )
	ent:DrawModel()

	--
	-- If we created the model, then remove it!
	--
	if ( inent != ent ) then
		ent:Remove()
	end

end

-- HL2SB (2026-10-02) GMod compat: capability query used by GMod's
-- lua/postprocess/toytown.lua (and stock addons) before drawing.  This fork
-- is DX9-class only, which already satisfies the pixel-shader 2.0 bar, so
-- the answer is always true.
function render.SupportsPixelShaders_2_0()
	return true
end
