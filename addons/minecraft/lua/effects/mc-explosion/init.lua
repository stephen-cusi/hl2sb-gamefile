function EFFECT:Init( data )
	
	local pos = data:GetOrigin()
	local color1 = math.random( 200, 255 )
	local color2 = math.random( 200, 240 )
	local color3 = math.random( 1, 50 )
	
	sound.Play("minecraft/explode.wav",pos,100,math.random(60,120))
	
	local emitter = ParticleEmitter( pos )
	if (pos.z * GetConVar("mc_explosion_height"):GetFloat() > pos.z) then
		pos.z = pos.z * GetConVar("mc_explosion_height"):GetFloat();
	end
	
		for i=0, 400 do

			local particle1 = emitter:Add( "particles/minecraft/smoke"..math.random(0,1), pos )
			if (particle1) then
				if (GetConVar("mc_explosion_spherical"):GetInt() == 1) then
					particle1:SetVelocity( RandomSpherePoint() * 1000 )
				else
					particle1:SetVelocity( VectorRand() * 1000 )
				end
				particle1:SetLifeTime( 0 )
				particle1:SetDieTime( math.random( 3, 5 ) )
				particle1:SetStartSize( math.random( 13, 15 ) )
				particle1:SetEndSize( 3 )
				particle1:SetCollide( 1 )
				particle1:SetAirResistance( 500 )
				particle1:SetColor( color1, color1, color1 )
			end

			local particle3 = emitter:Add( "particles/minecraft/smoke"..math.random(4,5), pos )
			if (particle3) then
				if (GetConVar("mc_explosion_spherical"):GetInt() == 1) then
					particle3:SetVelocity( RandomSpherePoint() * 1000 )
				else
					particle3:SetVelocity( VectorRand() * 1000 )
				end
				particle3:SetLifeTime( 0 )
				particle3:SetDieTime( math.random( 3, 5 ) )
				particle3:SetStartSize( math.random( 9, 10 ) )
				particle3:SetEndSize( 3 )
				particle3:SetCollide( 1 )
				particle3:SetAirResistance( 500 )
				particle3:SetColor( color2, color2, color2 )
			end

		end
		
		for il=0, 300 do

			local particle2 = emitter:Add( "particles/minecraft/smoke"..math.random(2,3), pos )
			if (particle2) then
				if (GetConVar("mc_explosion_spherical"):GetInt() == 1) then
					particle2:SetVelocity( RandomSpherePoint() * 700 )
				else
					particle2:SetVelocity( VectorRand() * 700 )
				end
				particle2:SetLifeTime( 0 )
				particle2:SetDieTime( math.random( 5, 6 ) )
				particle2:SetStartSize( math.random( 10, 12 ) )
				particle2:SetEndSize( 3 )
				particle2:SetCollide( 1 )
				particle2:SetAirResistance( 180 )
				particle2:SetColor( color3, color3, color3 )
			end

		end

	emitter:Finish()
	
end

function EFFECT:Think( )
	return false
end

function EFFECT:Render()
end

function RandomSpherePoint()
	local azimuthal = 2*math.pi*math.random();
	local sin2_zenith = math.random();
	local sin_zenith = math.sqrt(sin2_zenith);
	local zrand = math.random(1,2)
	if (zrand == 2) then zrand = -1 else zrand = 1 end
		
	local final = Vector( sin_zenith*math.cos(azimuthal) , sin_zenith*math.sin(azimuthal) , zrand*math.sqrt(1-sin2_zenith) );
	final:Normalize();
	
	return final;
end

CreateConVar( "mc_explosion_spherical", "1", { FCVAR_REPLICATED } )
CreateConVar( "mc_explosion_height", "0.7", { FCVAR_REPLICATED } )

