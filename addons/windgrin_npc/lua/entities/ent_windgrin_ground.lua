AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Editable		= true
ENT.PrintName		= "Undertale Bone"
ENT.Spawnable 		= false
ENT.AdminSpawnable 	= false



function ENT:Initialize()
	if( SERVER ) then
	    self:SetNWInt( "wb", math.random(1,3) )
		self:SetModel( "models/hunter/misc/shell2x2a.mdl" )
	
		self:SetColor(Color(0,255,0,0))
		self:SetTrigger( true )
		//self.Entity:PhysicsInit(SOLID_BBOX)
		//self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
		//self.Entity:SetSolid(SOLID_BBOX)
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )

		self:SetVar( "value", -50 )
		self:SetVar( "position", self:GetPos() - Vector(0,0,70)  )
		self:SetVar( "seed", math.Rand( 0, 1 ) )
		self:SetVar( "reverse", false )
		
		local phys = self:GetPhysicsObject()
		if( IsValid( phys ) ) then
			phys:Wake()
		end
	end
end

local sound1 = false
function ENT:PhysicsUpdate()
	if( SERVER ) then
		local value = math.min( self:GetVar( "value" ), 35 )
		local counter = self:GetVar( "value" )
		
		local seed = self:GetVar( "seed", NULL )
		
		if( self:GetVar( "reverse", NULL ) ) then
			self:SetVar( "value", counter - 2 )
			if( value < -20 ) then
				self:Remove()
			end
		else
			self:SetVar( "value", counter + 2 )
		end
		
		if( value > 10 ) then
			if( value < 15 ) && !self:GetVar( "reverse", NULL ) && !sound1 then
				local pos = self:GetVar( "pos", NULL )
				local normal = self:GetVar( "normal", NULL )

				sound.Play( Sound( "undertale/bone_end.wav" ), pos + normal * 50 )

				sound1 = true
				
				util.TraceHull( {
					start = pos,
					endpos = pos + normal * 50,
					filter = function( ent )
						if( ent:IsValid() ) then
						if( ent:GetClass() == "ent_undertale_bone_ground") then return end
							if ent == self.Owner then return end
							
							
							ent:SetVelocity( ent:GetUp() * 1000 )
						 timer.Simple(0.2,function() ent:TakeDamage( 1e8, self.Owner, self )
						 end)
							
							
							
							 if self:GetNWInt( "wb", 0 ) == 1  then 
							ent:EmitSound("windgrinbot/spring.mp3")
							 elseif self:GetNWInt( "wb", 0 ) == 2  then 
							  ent:EmitSound("windgrinbot/jump1.mp3")
							  elseif self:GetNWInt( "wb", 0 ) == 3  then 
							 	ent:EmitSound("windgrinbot/stepitup.mp3")
							  end
							if( ent:IsValid() ) then
								return false
							end
						end
					end,
					ignoreworld = true,
					mins = -Vector( 30, 30, 30 ),
					maxs = Vector( 30, 30, 30 ),
					mask = MASK_SHOT_HULL
				} )
			end
			
			if( self:GetVar( "do", NULL ) == NULL ) then
				self:SetVar( "do", true )
				self:SetSolid( SOLID_VPHYSICS )
			end
		end
		
		if( counter > 100 ) then
			self:SetVar( "reverse", true )
			sound1 = false
		end
		
		local phys = self:GetPhysicsObject()
		local position = self:GetVar( "position", NULL )
		
		local val1 = math.sin( ( math.max( 0, value ) + 50 ) / 10 ) * 90
		local val2 = ( seed - 0.5 ) * 13
		
		self:SetPos( position + self:GetUp() * ( val1 - val2 - 5 ) )
		
		phys:Wake()
	end
end

local windgrinbotMaterial = Material("windgrinbot/npc_windgrinbot.png", "smooth mips")
local windgrinbotMaterial1 = Material("windgrinbot/npc_windgrinbot1.png", "smooth mips")
local windgrinbotMaterial2 = Material("windgrinbot/npc_windgrinbot2.png", "smooth mips")
local drawOffset = Vector(0, 0, 64)


function ENT:RenderOverride()


   if self:GetNWInt( "wb", 0 ) == 1  then 
	render.SetMaterial(windgrinbotMaterial1)
	render.DrawSprite(self:GetPos() + drawOffset, 128, 128)
	elseif self:GetNWInt( "wb", 0 ) == 2  then
	render.SetMaterial(windgrinbotMaterial2)
	render.DrawSprite(self:GetPos() + drawOffset, 128, 128)

	elseif self:GetNWInt( "wb", 0 ) == 3  then
	render.SetMaterial(windgrinbotMaterial)
	render.DrawSprite(self:GetPos() + drawOffset, 128, 128)
	end
end
