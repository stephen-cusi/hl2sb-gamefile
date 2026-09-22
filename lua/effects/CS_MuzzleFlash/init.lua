-- HL2SB (2026-09-22): GMod's built-in CS_MuzzleFlash effect.  This engine's
-- lua/effects shipped WITHOUT it, so every CS-style weapon (cf_beast fires
-- util.Effect( "CS_MuzzleFlash", fx ) from its CallOnClient'd Muzzle()) drew
-- no muzzle flash at all.  Particle reimplementation: a bright glow at the
-- muzzle attachment plus a short directional streak.

function EFFECT:Init( data )

	local ent = data:GetEntity()
	local attach = data:GetAttachment()
	local scale = data:GetScale()
	if ( scale == nil or scale <= 0 ) then scale = 1 end

	local pos, ang
	if ( IsValid( ent ) and attach != nil and attach > 0 and ent.GetAttachment ) then
		local ap = ent:GetAttachment( attach )
		if ( ap and ap.Pos ) then pos, ang = ap.Pos, ap.Ang end
	end
	if ( pos == nil ) then
		pos = data:GetOrigin()
		ang = data:GetAngles()
	end
	if ( pos == nil ) then return end
	ang = ang or angle_zero

	local emitter = ParticleEmitter( pos )
	if ( emitter == nil ) then return end

	local fwd = ang:Forward()

	local p = emitter:Add( "sprites/light_glow02_add", pos )
	if ( p ) then
		p:SetVelocity( fwd * 24 * scale )
		p:SetDieTime( 0.05 )
		p:SetStartAlpha( 255 )
		p:SetEndAlpha( 0 )
		p:SetStartSize( 16 * scale )
		p:SetEndSize( 4 * scale )
		p:SetColor( 255, 225, 150 )
	end

	-- a short forward streak so the flash reads as directional
	local p2 = emitter:Add( "sprites/light_glow02_add", pos + fwd * 6 * scale )
	if ( p2 ) then
		p2:SetVelocity( fwd * 60 * scale )
		p2:SetDieTime( 0.04 )
		p2:SetStartAlpha( 200 )
		p2:SetEndAlpha( 0 )
		p2:SetStartSize( 8 * scale )
		p2:SetEndSize( 2 * scale )
		p2:SetColor( 255, 240, 200 )
	end

	emitter:Finish()

end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
