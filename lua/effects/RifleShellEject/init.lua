-- HL2SB (2026-09-22): GMod's built-in RifleShellEject effect -- shipped here
-- as a particle stand-in so cf_beast's CallOnClient'd Muzzle() actually shows
-- SOMETHING being ejected (the real one spawns a physics clientside shell
-- model; the engine's ClientsideModel shim makes that possible but expensive,
-- and a brass glint reads correctly at combat distances).

function EFFECT:Init( data )

	local vm = data:GetEntity()
	local attach = data:GetAttachment()

	local pos, ang
	if ( IsValid( vm ) and attach != nil and attach > 0 and vm.GetAttachment ) then
		local ap = vm:GetAttachment( attach )
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

	-- eject to the weapon's right and slightly up, gravity takes it from there
	local vel = ang:Right() * ( 40 + math.random( 0, 30 ) ) + ang:Up() * ( 20 + math.random( 0, 20 ) )

	local p = emitter:Add( "sprites/light_glow02_add", pos )
	if ( p ) then
		p:SetVelocity( vel )
		p:SetDieTime( 0.8 )
		p:SetStartAlpha( 255 )
		p:SetEndAlpha( 100 )
		p:SetStartSize( 2 )
		p:SetEndSize( 2 )
		p:SetGravity( Vector( 0, 0, -600 ) )
		p:SetColor( 200, 160, 90 )   -- brass
	end

	emitter:Finish()

end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
