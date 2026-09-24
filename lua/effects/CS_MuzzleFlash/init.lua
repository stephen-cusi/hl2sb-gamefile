-- HL2SB CS_MuzzleFlash: the CS-style muzzle flash for util.Effect(
-- "CS_MuzzleFlash", fx ) (cf_beast fires it from event 21; weapon_base
-- reaches the engine-native callback only when no Lua template exists).
--
-- History: v1 particle version drew nothing (CLuaParticle pipeline does not
-- render here); the engine-native callback (fx_cs_muzzleflash.cpp) drew a
-- BLACK BLOCK because HL2's sprites/muzzleflash4.vmt ships without
-- $additive (alpha-blended black background) - that VMT now has a loose
-- additive override in hl2sb/materials/sprites/; v3/v7 CreateMaterial
-- shells never materialised either: engine.log logged
-- "create=true ... iserror=true" every load, so Material("hl2sb_csflash")
-- handed back the engine ERROR material and the quads drew it - the dark
-- block at the muzzle on 2026-09-24.
--
-- v8 draws the stock CS flash sprite directly: every candidate is a
-- mounted UnlitGeneric+$additive material (black background adds out to
-- nothing), the first that resolves wins, and the warm light_glow02_add
-- core below doubles as last-resort flash.
local function firstGoodMaterial( paths )
	for _, path in ipairs( paths ) do
		local ok, m = pcall( Material, path )
		if ( ok and m ~= nil and m.IsError ~= nil ) then
			local okE, isErr = pcall( m.IsError, m )
			if ( okE and not isErr ) then
				return m, path
			end
		end
	end
	return nil, nil
end

local matFlash, matFlashPath = firstGoodMaterial( {
	"sprites/muzzleflash_cs",	-- CS:S original (loose copy + GMod fallbacks)
	"effects/muzzleflash4",		-- HL2's own copy, identical flags/art
} )
local matCore, matCorePath = firstGoodMaterial( {
	"sprites/light_glow02_add",	-- runtime-proven additive glow
} )
if ( matFlash == nil ) then matFlash = matCore end
if ( matCore == nil ) then matCore = matFlash end

print( string.format( "[HL2SB] CS_MuzzleFlash v8 flash=%s core=%s",
	tostring( matFlashPath or "nil" ), tostring( matCorePath or "nil" ) ) )

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
	if ( pos == nil or matFlash == nil ) then return end

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
	-- Alphas are FLOORED to integers - lua_color_field reads floats and a
	-- non-integer alpha must stay an integer end to end.
	for i = 0, 2 do
		local w = ( 3 + 3 * i ) * scale * ( 1 - 0.2 * frac )
		local col = Color( 255, 255, 255, math.floor( 30 + 50 * frac + 0.5 ) )
		local roll = self.Roll + i * 120
		render.DrawQuadEasy( pos, normal, w, w, col, roll )
		render.DrawQuadEasy( pos, -normal, w, w, col, roll )
	end

	-- Warm bright core: stands in for the orange dynamic light GMod's engine
	-- callback adds (no Lua API for TE_DynamicLight here).  Proven additive.
	if ( matCore ~= nil ) then
		render.SetMaterial( matCore )
		local cw = 4.5 * scale * ( 1 - 0.3 * frac )
		local ca = math.floor( 220 * frac + 0.5 )
		render.DrawQuadEasy( pos, normal, cw, cw, Color( 255, 210, 130, ca ) )
		render.DrawQuadEasy( pos, -normal, cw, cw, Color( 255, 210, 130, ca ) )
	end

end
