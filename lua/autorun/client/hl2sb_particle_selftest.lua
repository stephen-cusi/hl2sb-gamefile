// HL2SB TEMP DIAGNOSTIC 2026-09-29: minimal standalone ParticleEmitter test.
// Console command: hl2sb_particle_test  (client console)
// Spawns 60 long-lived sparkle particles 60 units in front of the camera and
// 60 smoke0 particles at the same spot, so BOTH material families used by the
// Minecraft effects (models/sparkle, particles/minecraft/smoke0) get exercised.
// Remove this file after the particle-render diagnosis.

concommand.Add( "hl2sb_particle_test", function()

	local ply = LocalPlayer()
	local pos = ply:GetPos() + Vector( 0, 0, 60 )
	local fwd = ply:GetAimVector()
	pos = pos + fwd * 80

	local e = ParticleEmitter( pos )
	if ( !e ) then
		print( "[selftest] ParticleEmitter() returned nil" )
		return
	end

	local nSparkle = 0
	local nSmoke = 0

	for i = 1, 30 do
		local p = e:Add( "models/sparkle", pos + Vector( math.Rand( -20, 20 ), math.Rand( -20, 20 ), math.Rand( 0, 40 ) ) )
		if ( p ) then
			nSparkle = nSparkle + 1
			p:SetVelocity( Vector( 0, 0, 60 ) )
			p:SetDieTime( 4 )
			p:SetStartAlpha( 255 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 24 )
			p:SetEndSize( 4 )
			p:SetColor( 255, 255, 255 )
		end
	end

	for i = 1, 30 do
		local p = e:Add( "particles/minecraft/smoke0", pos + Vector( math.Rand( -20, 20 ), math.Rand( -20, 20 ), math.Rand( 0, 40 ) ) )
		if ( p ) then
			nSmoke = nSmoke + 1
			p:SetVelocity( Vector( math.Rand( -20, 20 ), math.Rand( -20, 20 ), 40 ) )
			p:SetDieTime( 4 )
			p:SetStartAlpha( 220 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 30 )
			p:SetEndSize( 6 )
			p:SetColor( 200, 100, 60 )
		end
	end

	e:Finish()
	print( Format( "[selftest] sparkle added=%d smoke added=%d at %s", nSparkle, nSmoke, tostring( pos ) ) )

end )

// Test 2: engine standard effects (no Lua emitter at all) -- if THESE show up,
// the particle rendering pipeline works and only the CLuaEmitter path is dead.
// console:  hl2sb_particle_test2
concommand.Add( "hl2sb_particle_test2", function()

	local ply = LocalPlayer()
	local pos = ply:GetPos() + Vector( 0, 0, 60 )
	local fwd = ply:GetAimVector()
	pos = pos + fwd * 80

	local d = EffectData()
	d:SetOrigin( pos )
	DispatchEffect( "Impact", d )
	DispatchEffect( "JoltEffect", d )
	print( "[selftest2] Impact + JoltEffect dispatched at " .. tostring( pos ) )

end )

print( "[selftest] hl2sb_particle_test + hl2sb_particle_test2 registered" )
