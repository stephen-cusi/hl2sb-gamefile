EFFECT.timer = 0
EFFECT.max = 40
EFFECT.emit = 0
EFFECT.ent = 0


function EFFECT:Init( data )
	local ent = data:GetEntity()
	if (ent != NULL) then
		self.ent = ent;
		self.emit = 1
	end
end

function EFFECT:Emit()
	local BonePos , BoneAng = self.ent:GetBonePosition( 0 ) //hardcoded bone index because gmod 13 is being a bitch

	local color = math.random( 1, 40 )
	local emitter = ParticleEmitter( BonePos )
	local particle = emitter:Add( "particles/minecraft/smoke"..math.random(2,4), BonePos )
	if (particle) then
		particle:SetLifeTime( 1 )
		particle:SetDieTime( math.random( 1, 2 ) )
		particle:SetStartSize( math.random( 10, 11 ) )
		particle:SetEndAlpha( math.random( 200, 255 ) )
		particle:SetEndSize( 2 )
		particle:SetCollide( 1 )
		particle:SetGravity( Vector(math.random(-7,7),math.random(-7,7),40) )
		particle:SetColor( color, color, color )
	end
	
	self.timer = CurTime() + 0.06;
	self.max = self.max - 1;
end


function EFFECT:Think()
	if (self.ent == NULL) then return false end
	
	if (self.emit == 1 && self.max > 0 && CurTime() > self.timer) then
		self:Emit()
	end
	return true
end

function EFFECT:Render()
end
