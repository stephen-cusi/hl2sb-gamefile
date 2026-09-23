-- HL2SB CS_MuzzleFlash (2026-09-23, v3): the CS-style muzzle flash for
-- util.Effect( "CS_MuzzleFlash", fx ) (cf_beast fires it from event 21).
--
-- History: v1 particle version drew nothing (CLuaParticle pipeline does not
-- render here); the engine-native callback (fx_cs_muzzleflash.cpp) drew a
-- BLACK SQUARE (its SimpleParticle path alpha-blends the sprite instead of
-- additively blending it, so the texture's black background showed); v2 glow
-- quads drew but looked unlike a real flash; v3's CreateMaterial produced a
-- checkerboard (the sh_init shim's Materials.Create silently swallowed the
-- GMod 3-arg form and left the material textureless).  v4 uses the stock
-- sprites/muzzleflash4 VMT directly - the engine precaches it at load
-- (fx_cs_muzzleflash.cpp CLIENTEFFECT_MATERIAL), it is a stock additive
-- sprite, and render.SetMaterial(Material(path)) is the chain the nyan
-- effect is verified on.

-- v7 (2026-09-23): the engine-side SetMaterialVarFlag force was confirmed
-- ineffective BY THE LOG (flag reported set, black square stayed) - whether a
-- material blends additively is decided inside ITS OWN shader, and this
-- material's shader never checks MATERIAL_VAR_ADDITIVE.  Also CreateMaterial
-- eagerly resolves $basetexture and errored ("mat=___error") on a wrong path.
--
-- v7 graft instead - every API below is production-proven in this fork (halo:
-- mat_Copy:SetTexture("$basetexture", rt_Store)):
--   1. CreateMaterial makes a TEXTURELESS UnlitGeneric shell with $additive 1
--      (no $basetexture key -> nothing to mis-resolve); its shader DOES honour
--      the additive flag.
--   2. The stock effects/muzzleflash4 material resolves its own texture fine
--      (its art has been visible all along), so read the ITexture object off it
--      and graft it onto the shell.
-- Fallback if anything fails: plain light_glow02_add (runtime-proven additive)
-- so the flash is never invisible again.  Lua template priority keeps the
-- engine's native callback (the black-square renderer) out of the picture.

local matCore = Material( "sprites/light_glow02_add" )
local matFlash = matCore
do
	local okCreate = pcall( CreateMaterial, "hl2sb_csflash", "UnlitGeneric", {
		[ "$additive" ] = "1",
		[ "$vertexalpha" ] = "1",
		[ "$translucent" ] = "1",
	} )
	if ( okCreate ) then
		local m = Material( "hl2sb_csflash" )
		if ( m ~= nil and m.SetTexture ~= nil ) then
			matFlash = m
		end
	end

	local graft = false
	local src = Material( "effects/muzzleflash4" )
	-- Only graft onto OUR shell - mutating the shared light_glow02_add (the
	-- fallback) would corrupt every other effect that uses it.
	if ( matFlash ~= matCore and matFlash ~= src and src ~= nil and src.GetTexture ~= nil and matFlash.SetTexture ~= nil ) then
		local okGet, tex = pcall( src.GetTexture, src, "$basetexture" )
		if ( okGet and tex ~= nil ) then
			graft = select( 1, pcall( matFlash.SetTexture, matFlash, "$basetexture", tex ) )
		end
	end

	local iserr = "?"
	if ( matFlash ~= nil and matFlash.IsError ~= nil ) then
		local okE, v = pcall( matFlash.IsError, matFlash )
		if ( okE ) then iserr = tostring( v ) end
	end
	print( string.format( "[HL2SB] CS_MuzzleFlash v7 create=%s graft=%s iserror=%s fallback=%s",
		tostring( okCreate ), tostring( graft ), iserr, tostring( matFlash == matCore ) ) )
end

local LIFE = 0.06

function EFFECT:Init( data )

	local ent = data:GetEntity()
	local attach = data:GetAttachment()
	local scale = data:GetScale()
	if ( scale == nil or scale <= 0 ) then scale = 1 end

	local pos, ang
	if ( IsValid( ent ) and attach ~= nil and attach > 0 and ent.GetAttachment ) then
		local ap = ent:GetAttachment( attach )
		if ( ap and ap.Pos ) then pos, ang = ap.Pos, ap.Ang end
	end
	if ( pos == nil ) then
		pos = data:GetOrigin()
		ang = data:GetAngles()
	end
	-- Zero origin = attachment lookup failed; never draw at world origin.
	if ( pos ~= nil and pos.x == 0 and pos.y == 0 and pos.z == 0 and IsValid( ent ) and ent.GetPos ) then
		pos = ent:GetPos()
	end
	if ( pos == nil ) then return end
	ang = ang or angle_zero

	self.Pos = pos
	self.Fwd = ang:Forward()
	self.Scale = scale
	self.DieTime = CurTime() + LIFE
	-- engine CS callback style: three flashes with a random roll
	self.Roll = math.random( 0, 359 )

end

function EFFECT:Think()
	return self.Pos ~= nil and CurTime() < ( self.DieTime or 0 )
end

function EFFECT:Render()

	local pos = self.Pos
	if ( pos == nil ) then return end

	local frac = math.Clamp( ( ( self.DieTime or 0 ) - CurTime() ) / LIFE, 0, 1 )
	local scale = self.Scale or 1

	-- Billboard at the camera so the star is visible from any angle.
	local normal
	local lp = LocalPlayer()
	if ( lp and lp.EyePos ) then
		normal = pos - lp:EyePos()
	end
	if ( normal == nil or normal:Length() < 1 ) then
		normal = -( self.Fwd or Vector( 0, 0, 1 ) )
	end
	normal:Normalize()

	render.SetMaterial( matFlash )

	-- Three stars like the engine callback (sizes 3/6/9 * scale), alpha
	-- 80->30 matching GMod's particle version, shrink *0.8, random roll.
	-- Alphas are FLOORED to integers - lua_color_field uses lua_tointeger and
	-- Lua 5.4 reads any non-integer float back as 0 (the invisible flash bug).
	for i = 0, 2 do
		local w = ( 3 + 3 * i ) * scale * ( 1 - 0.2 * frac )
		local col = Color( 255, 255, 255, math.floor( 30 + 50 * frac + 0.5 ) )
		local roll = self.Roll + i * 120
		render.DrawQuadEasy( pos, normal, w, w, col, roll )
		render.DrawQuadEasy( pos, -normal, w, w, col, roll )
	end

	-- Warm bright core: stands in for the orange dynamic light GMod's engine
	-- callback adds (no Lua API for TE_DynamicLight here).  Proven additive.
	render.SetMaterial( matCore )
	local cw = 4.5 * scale * ( 1 - 0.3 * frac )
	local ca = math.floor( 220 * frac + 0.5 )
	render.DrawQuadEasy( pos, normal, cw, cw, Color( 255, 210, 130, ca ) )
	render.DrawQuadEasy( pos, -normal, cw, cw, Color( 255, 210, 130, ca ) )

end
