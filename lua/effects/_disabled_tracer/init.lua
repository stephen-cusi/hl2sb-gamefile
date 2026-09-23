-- HL2SB (2026-09-22): GMod's built-in tracer effect (FireBullets'
-- TracerName defaults to "Tracer"; the lookup lowercases the name, so this
-- file registers as "tracer" and answers both spellings).  A fast-fading
-- beam from the muzzle to the impact point.  Without it CF-style weapons
-- fired with no visible bullet at all.

-- 2026-09-23: was "effects/bluelaser1" - a literal BLUE LASER texture, which
-- read as a stray blue line at the muzzle (user report).  GMod's own
-- materials/effects/tool_tracer (verified in garrysmod_dir.vpk) is the
-- correct tracer look; the warm vertex color tints it.
local matBeam = Material( "effects/tool_tracer" )

local LIFETIME = 0.07

function EFFECT:Init( data )

	local ent = data:GetEntity()
	local start = data:GetStart()
	local hit = data:GetOrigin()

	-- GMod fills GetStart from the trace's muzzle position; when it comes
	-- back zeroed fall back to the shooter's eye position.
	if ( start == nil or start:IsZero() ) then
		if ( IsValid( ent ) and ent.GetShootPos ) then
			start = ent:GetShootPos()
		elseif ( IsValid( ent ) and ent.EyePos ) then
			start = ent:EyePos()
		else
			return false
		end
	end
	if ( hit == nil ) then return false end

	self.StartPos = start
	self.EndPos = hit
	self.DieTime = CurTime() + LIFETIME

	return true

end

function EFFECT:Think()
	return CurTime() < self.DieTime
end

function EFFECT:Render()
	local frac = math.Clamp( ( self.DieTime - CurTime() ) / LIFETIME, 0, 1 )
	render.SetMaterial( matBeam )
	render.DrawBeam( self.StartPos, self.EndPos, 1 + 2 * frac, 0, 1, Color( 255, 255, 210, 180 * frac ) )
end
