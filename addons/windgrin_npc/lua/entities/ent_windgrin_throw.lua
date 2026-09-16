AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Editable		= true
ENT.PrintName		= "Windgrin greenhat"
ENT.Spawnable 		= false
ENT.AdminSpawnable 	= false


function ENT:Initialize()
	if( SERVER ) then
		self:SetModel( "models/props/de_nuke/hr_nuke/nuke_hard_hat/nuke_hard_hat.mdl" )
	
		self:SetColor(Color(0,255,0))
		self:SetTrigger( true )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetModelScale( self:GetModelScale() * 1.5, 0 )
		self:SetVar( "hit", false )
		
		local phys = self:GetPhysicsObject()
		phys:EnableGravity( false )
	end
	
	if( CLIENT ) then
		local vec = self:GetPos()
		local emitter = ParticleEmitter( vec, false )
		
		//effects/fire_cloud1
		for cycles = 1, 10 do
			local particle = emitter:Add( Material( "effects/fire_cloud1" ), vec )
			if( particle ) then
				particle:SetVelocity( VectorRand() * 40 )
				particle:SetColor( 50, 200, 100 ) 
				particle:SetLifeTime( 0 )
				particle:SetDieTime( 1 )
				particle:SetAngles( Angle( math.Rand( 0, 360 ), 0, 0 ) )
				particle:SetAngleVelocity( Angle( math.Rand( -1, 1 ), 0, 0 ) )
				particle:SetStartSize( 20 )
				particle:SetEndSize( 10 )
				particle:SetStartAlpha( 255 )
				particle:SetEndAlpha( 0 )
				particle:SetGravity( Vector( 0, 0, 60 ) )
			end
		end
		
		emitter:Finish()
	end
end

if( SERVER ) then
	function ENT:Think()
		local parent = self:GetParent()
		
		if( parent:IsValid() ) then
			if( parent:IsPlayer() ) then
				if( parent:Health() <= 0 ) then
					self:Remove()
				end
			end
		end
	end

	function ENT:PhysicsUpdate( )
		if( !self:GetVar( "hit", NULL ) ) then
			if( self:GetVelocity():Length() < 1000 ) then
				self:SetVar( "hit", true )
				self:Fire( "Kill", "", 10 )
				local phys = self:GetPhysicsObject()
				phys:EnableGravity( true )
			end
		end
	end

	function ENT:PhysicsCollide( data, phys )
		if( !self:GetVar( "hit", NULL ) ) then
			if( data.Speed > 100 ) then
				local hitEnt = data.HitEntity
				
				if( hitEnt:GetClass() != "ent_windgrin_throw" && hitEnt != self.Owner ) then
					self:SetMoveType( MOVETYPE_NONE )
					self:SetPos( data.HitPos )
					self:SetSolid( SOLID_NONE )
					
					if( hitEnt:IsValid()) then
						//if hitEnt:Health() > 0 then
							hitEnt:TakeDamage( 25, self.Owner, self )
							hitEnt:SetColor(Color(0,255,0))
							self:SetParent( hitEnt, -1 )
							if( CLIENT ) then return end

	
	
		
		local ent = ents.Create( "ent_windgrin_blaster" )
		local rand = math.Rand( -math.pi, math.pi ) / 2
		local vec = Vector( 0, math.sin( rand ) * 70, 100 + math.cos( rand ) * 50 )
		
		vec:Rotate( Angle( 0, self.Owner:GetAngles().y, 0 ) )
		local pos = self.Owner:GetPos() + Vector(0,-100,0) + vec

		ent:SetAngles( ( self.Owner:GetEyeTrace().HitPos - pos ):Angle() )
		ent:SetPos( self.Owner:GetPos() )
		ent:EmitSound( Sound( "undertale/gaster_blaster/gaster_blaster_start.mp3" ), 75, 100, 1, CHAN_AUTO )
		ent:SetOwner( self.Owner )
		ent:Spawn()
		ent:SetVar( "position", pos )
	
						//end
					end
					
					self:SetVar( "hit", true )
					self:Fire( "Kill", "", 10 )
					sound.Play( Sound( "undertale/sans/smash.wav" ), self:GetPos() )
				end
			end
		end
	end
end