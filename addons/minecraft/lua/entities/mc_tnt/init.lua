AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

CreateConVar( "sbox_maxmc_tnts", 5 )
CreateConVar( "minecraft_tnt_timer", 3 )
CreateConVar( "minecraft_tnt_damage", 150 )

local material = "models/MCModelPack/animated/tnt-active"

local timeadd = 0

//Accessor Funcs
function ENT:SetPlayer( ply )
    self.Owner = ply
end

function ENT:GetPlayer( )
    return self.Owner
end

function ENT:SpawnFunction( ply, tr )

	if ( !tr.Hit ) then return nil end
	if not ply:CheckLimit("mc_tnts") then return nil end
	
	local SpawnPos = tr.HitPos + tr.HitNormal * 8

	local ent = ents.Create( "mc_tnt" )
		ent:SetPos( SpawnPos )
		ent:Spawn()
		ent:Activate()

	ply:AddCount("mc_tnts", ent)
	ply:AddCleanup("mc_tnts", ent)
	self:SetPlayer( ply )

	return ent
end

function ENT:Initialize()
	self:SetModel( "models/MCModelPack/blocks/tnt.mdl" )
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
end

function ENT:Think()
	if (CLIENT) then return end
	if (self.ignited == 0) then return end
	
	if (CurTime() > self.timer) then
		self:Explode()
	end
	
	local phys = self.Entity:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
	end
end

function ENT:OnTakeDamage( dmginfo )
	self:TakePhysicsDamage( dmginfo )
	if (math.random(0,1) == 1) then
		timeadd = math.random(0,2)
	else
		timeadd = -math.random(1,2)
	end

	
	if (self.ignited == 1) then return end
	
	local effectdata2 = EffectData()
		effectdata2:SetOrigin( self:GetPos() )
		effectdata2:SetMagnitude( 1 )
		effectdata2:SetScale( 1 )
		effectdata2:SetRadius( 5 )
		effectdata2:SetEntity( self )

	util.Effect( "mc-ignite", effectdata2, true, true )
	self:EmitSound( "minecraft/ignite.wav", 100, 100 )
	self:SetMaterial( material )
	
	//on activation, re-enable physics! (like in minecraft)
	local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:EnableMotion( true )
		phys:Wake()
	end
	
	//set time
	self.timer = CurTime() + GetConVar("minecraft_tnt_timer"):GetFloat()+timeadd
	
	self.ignited = 1
end

function ENT:Explode()
	local effectdata = EffectData()			// Explosion EffectData()
		effectdata:SetOrigin( self.Entity:GetPos() )
		effectdata:SetMagnitude( 1 )
		effectdata:SetScale( 2 )
		effectdata:SetRadius( 5 )
			
	local radius = 300
	util.Effect( "mc-explosion", effectdata, true, true )
	util.BlastDamage( self, self, self:GetPos(), radius, GetConVar("minecraft_tnt_damage"):GetInt() )
	
	if (self:GetPlayer() != nil && SERVER) then
		if (self:GetPlayer().GetInfoNum ~= nil) then
			self:GetPlayer():ConCommand("cl_minecraft_blockcount ".. (self:GetPlayer():GetInfoNum("cl_minecraft_blockcount", 0))-1)
		end
	end
	
	self:Remove()
end

function ENT:Ignite()
	if (self.ignited == 1) then return end
	
	local effectdata2 = EffectData()
		effectdata2:SetOrigin( self:GetPos() )
		effectdata2:SetMagnitude( 1 )
		effectdata2:SetScale( 1 )
		effectdata2:SetRadius( 5 )
		effectdata2:SetEntity( self )

	util.Effect( "mc-ignite", effectdata2, true, true )
	self:EmitSound( "minecraft/ignite.wav", 100, 100 )
	self:SetMaterial( material )
	
	//on activation, re-enable physics! (like in minecraft)
	local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:EnableMotion( true )
		phys:Wake()
	end
	
	//set time
	self.timer = CurTime() + GetConVar("minecraft_tnt_timer"):GetFloat()+timeadd
	
	self.ignited = 1
end

function ENT:Use( activator, caller )
	if (self.ignited == 1) then return end
	
	local effectdata2 = EffectData()
		effectdata2:SetOrigin( self:GetPos() )
		effectdata2:SetMagnitude( 1 )
		effectdata2:SetScale( 1 )
		effectdata2:SetRadius( 5 )
		effectdata2:SetEntity( self )

	util.Effect( "mc-ignite", effectdata2, true, true )
	self:EmitSound( "minecraft/ignite.wav", 100, 100 )
	self:SetMaterial( material )
	
	//on activation, re-enable physics! (like in minecraft)
	local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:EnableMotion( true )
		phys:Wake()
	end
	
	//set time
	self.timer = CurTime() + GetConVar("minecraft_tnt_timer"):GetFloat()+timeadd
	
	self.ignited = 1
end

function ENT:OnRemove()
	if (self.health < 0) then
		local grass = { Sound("minecraft/grass1.wav"),Sound("minecraft/grass2.wav"),Sound("minecraft/grass3.wav"),Sound("minecraft/grass4.wav") }
		self:EmitSound( table.Random( grass ), 511, math.random(60,100) )
	end
	timeadd = 0
end
