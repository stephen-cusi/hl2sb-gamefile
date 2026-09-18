local GlowMaterial = CreateMaterial( "arcadiumsoft/glow", "UnlitGeneric", {
[ "$basetexture" ]    = "sprites/light_glow01",
[ "$additive" ]        = "1",
[ "$vertexcolor" ]    = "1",
[ "$vertexalpha" ]    = "1", } );
    
function EFFECT:Init( data )
	local TargetEntity = data:GetEntity()
	if ( !TargetEntity || !TargetEntity:IsValid() ) then return end
	
	local vOffset = TargetEntity:GetPos()
	local Low, High = TargetEntity:WorldSpaceAABB()
	
	self.LifeTime = math.Rand( GetConVar("minecraft_particles_lifetime_min"):GetFloat(), GetConVar("minecraft_particles_lifetime_max"):GetFloat() );    // 0.25, 0.35
	self.DieTime = CurTime() + self.LifeTime;
	
	//create particle emitter and particles
	local emitter = ParticleEmitter( vOffset );
	for i=0, GetConVar("minecraft_particles_count"):GetInt() do
		local vPos = Vector( math.Rand(Low.x,High.x), math.Rand(Low.y,High.y), math.Rand(Low.z,High.z) )
		local particle = emitter:Add( "models/sparkle", vPos );
		
		if (particle) then
			particle:SetVelocity( RandomSpherePoint() * GetConVar("minecraft_particles_outwardforce"):GetInt() )
			//particle:SetVelocity( (vPos - vOffset) * 3 )
			particle:SetDieTime( math.Rand( GetConVar("minecraft_particles_dietime_min"):GetInt(), GetConVar("minecraft_particles_dietime_max"):GetInt() ) );
			particle:SetStartAlpha( 255 );
			particle:SetEndAlpha( 0 );
			local randSize = math.Rand( GetConVar("minecraft_particles_startsize_min"):GetInt(), GetConVar("minecraft_particles_startsize_max"):GetInt() )
			particle:SetStartSize( randSize );
			particle:SetEndSize( randSize );
			particle:SetRoll( 0 );
			particle:SetColor( 255, 255, 255 );
			particle:SetGravity( Vector( 0, 0, -GetConVar("minecraft_particles_gravity"):GetInt() ) );
			particle:SetCollide( true );
			particle:SetBounce( 0.5 );
			particle:SetAirResistance( GetConVar("minecraft_particles_airresistance"):GetInt() );
		end
	end
	emitter:Finish();           
end
    
function EFFECT:Think()
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