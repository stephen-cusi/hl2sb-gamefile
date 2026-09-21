-- HL2SB particle stack test (2026-09-22) -- run: lua_dofile_cl particle_test.lua
local ok, err = pcall(function()
	local e = ParticleEmitter( Vector( 0, 0, 64 ) )
	local p = e:Add( "effects/spark", Vector( 0, 0, 64 ) )

	print( "[ptest] emitter:", e:GetNumActiveParticles(), "is3d:", e:Is3D(), "valid:", e:IsValid() )
	print( "[ptest] particle pos:", p:GetPos(), "color:", p:GetColor() )
	print( "[ptest] velocity:", p:GetVelocity(), "gravity:", p:GetGravity(), "bounce:", p:GetBounce() )

	p:SetVelocity( Vector( 64, 0, 32 ) )
	p:SetVelocityScale( true )
	p:SetStartLength( 1 )
	p:SetEndLength( 2 )
	print( "[ptest] velocityscale ok, lengths:", p:GetStartLength(), p:GetEndLength() )

	p:SetAngles( Angle( 0, 45, 0 ) )
	p:SetAngleVelocity( Angle( 0, 90, 0 ) )
	print( "[ptest] angles:", p:GetAngles(), "angvel:", p:GetAngleVelocity() )

	p:SetCollide( true )
	p:SetCollideCallback( function( part, hitpos, hitnormal )
		print( "[ptest] collide callback! hitpos:", hitpos, "normal:", hitnormal )
	end )

	local mat = p:GetMaterial()
	print( "[ptest] material:", mat, mat and mat:GetName() or "-" )

	p:SetDieTime( 2 )
	print( "[ptest] dietime:", p:GetDieTime(), "particles now:", e:GetNumActiveParticles() )

	local ef = CreateParticleSystemNoEntity( "explosion_huge_g", Vector( 0, 0, 64 ) )
	if ef then
		print( "[ptest] particlesystem:", ef:GetEffectName(), "highestCP:", ef:GetHighestControlPoint(), "autobb:", ef:GetAutoUpdateBBox() )
		local mins, maxs = ef:GetRenderBounds()
		print( "[ptest] renderbounds:", mins, maxs )
		ef:StopEmission( false, true, false )
	else
		print( "[ptest] particlesystem: NIL (pcf not loaded - expected unless a pcf defines explosion_huge_g)" )
	end

	print( "[ptest] util.ParticleTracer:" )
	util.ParticleTracer( "particle_tracer", Vector( 0, 0, 64 ), Vector( 500, 0, 64 ), false )
	util.ParticleTracerEx( "particle_tracer", Vector( 0, 0, 64 ), Vector( 500, 0, 64 ), false, 0, 0 )
	print( "[ptest] ALL OK" )
end )
if not ok then print( "[ptest] FAILED:", err ) end
