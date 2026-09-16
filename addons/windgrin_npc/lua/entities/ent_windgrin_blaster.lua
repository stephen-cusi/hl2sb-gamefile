AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Editable		= true
ENT.PrintName		= "Windgrin"
ENT.Spawnable 		= false
ENT.AdminSpawnable 	= false



local modelAvailible = false
local wcooldown = 0
function ENT:Initialize()
	if( SERVER ) then
	local model = "models/Gibs/HGIBS.mdl"
        
		if CurTime() > wcooldown then
		self:EmitSound("windgrinbot/green.mp3")
	    wcooldown = CurTime() + 2
		end
		
		self:SetModel( model )
		self:SetColor(Color(0,255,0))
		self:SetTrigger( true )
		//self.Entity:PhysicsInit(SOLID_BBOX)
		//self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
		//self.Entity:SetSolid(SOLID_BBOX)
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
		
		self:SetVar( "open", CurTime() + 1 )
		self:SetVar( "CurTime", math.Rand( 0, 60 ) )
		
		self:ManipulateBoneAngles( 2, Angle( 0, 90, 0) )
		
		local phys = self:GetPhysicsObject()
		if( IsValid( phys ) ) then
			phys:Wake()
		end
		
		util.AddNetworkString( "gaster_blaster_shooting" )
	end
	
	if( CLIENT ) then
		self:SetVar( "shootEffect", 0 )
	end
end

function ENT:PhysicsUpdate()
	if( SERVER ) then
	
		local pos = self:GetVar( "position", NULL )
		local dist = pos:Distance( self:GetPos() )
		
		if( self:GetVar( "distance", NULL ) == NULL ) then
			self:SetVar( "distance", dist )
			self:SetVar( "scale", self:GetModelScale() )
		end
		
		local scale = self:GetVar( "scale", NULL )
		local saveDist = self:GetVar( "distance" )
		local curtime = CurTime() - self:GetVar( "CurTime", NULL )
		local vec = Vector( math.cos( curtime ), math.sin( curtime ), math.sin( curtime ) / 2 )
		
		local numb = ( CurTime() - self:GetVar( "open", NULL ) ) * 6
		
		if( numb < 3 ) then
			self:SetPos( self:GetPos() + ( pos - self:GetPos() ) / 10 + vec * math.max( 0.5, dist / 30 ) )
		else
			if( numb > 10 ) then
				self:Remove()
			end
			self:SetPos( self:GetPos() - self:GetForward() * ( dist / 10 + 0.1 ) )
		end
		
		if( dist < 15 ) then
			local value = math.sin( math.max( 0, math.min( 2, numb ) ) ) * 1.1

			if( numb > 0 ) then
			
				if( self:GetVar( "shoot", NULL ) == NULL ) then
					self:SetVar( "shoot", true )
					
					self:EmitSound( "undertale/gaster_blaster/gaster_blaster_end.mp3", 75, 100, 1, CHAN_AUTO )
					
					local tr = util.TraceHull( {
						start = self:GetPos(),
						endpos = self:GetPos() + self:GetForward() * 10000,
						filter = function( ent )
							if ent == self.Owner then return end
							
							if( ent:IsValid() ) then
								ent:TakeDamage( 25, self.Owner, self )
								if( ent:IsValid() ) then
									return false
								end
							end
						end,
						mins = Vector( -20, -20, -20 ),
						maxs = Vector( 20, 20, 20 ),
						mask = MASK_SHOT_HULL
					} )
					
					net.Start( "gaster_blaster_shooting" )
					net.WriteEntity( self )
					net.Broadcast()
				end
			
				if( modelAvailible ) then
					self:SetModelScale( scale )
				else
					self:SetModelScale( scale * 6 )
				end
			end
		else
			if( modelAvailible ) then
				self:SetModelScale( scale * math.max( 0, math.min( 1, ( saveDist - dist ) / saveDist ), 0 ) )
			else
				self:SetModelScale( scale * math.max( 0, math.min( 1, ( saveDist - dist ) / saveDist ), 0 ) * 5 )
			end
		end
	end
end

net.Receive( "gaster_blaster_shooting", function()
	local read = net.ReadEntity()
	read:SetVar( "shootEffect", CurTime() )
end )

function ENT:Draw()
	
	self:DrawModel()
	
	if( self:GetVar( "shootEffect", NULL ) > 0 ) then
		numb = CurTime() - self:GetVar( "shootEffect", NULL ) 
		if( numb > 1 ) then
			self:SetVar( "shootEffect", 0 )
		end
		
		local tr = util.TraceLine( {
			start = self:GetPos(),
			endpos = self:GetPos() + self:GetForward() * 10000,
			filter = function( ent ) if ( ent:GetClass() == "prop_physics" ) then return true end end
		} )
		
		render.SetMaterial( Material( "cable/green" ) )

		local size = math.max( 0, math.min( 1, math.sin( numb * 5 ) * 14 ) )
		local pos = self:GetPos() - self:GetUp() * 20 - self:GetForward() * 10
		local dir = tr.HitPos - pos
		dir:Normalize()
		
		local length = 25
		
		for i = 1, 5 do
			local forw = ( 17 + i * ( length / 5 ) )
			render.DrawBeam( pos + dir * ( forw - ( length / 5 ) ), pos + dir * forw, ( 15 + 3 * i ) * size, 1, 1, Color( 0, 255, 100, 255 ) ) 
		end
		
		render.DrawBeam( pos + dir * ( 16 + length ), tr.HitPos, 30 * size, 1, 1, Color( 0, 255, 100, 255 ) )
	end
end