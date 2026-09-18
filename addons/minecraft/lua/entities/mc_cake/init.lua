AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

ENT.Type            = "anim"
ENT.Base            = "base_anim"
ENT.PrintName       = "Minecraft Cake"
ENT.Author          = "Dj Lukis.LT"
ENT.Information		= "An edible minecraft cake"
ENT.Category		= "Minecraft"

ENT.Spawnable			= true
ENT.AdminSpawnable		= true

local model1 = "models/mcmodelpack/other_blocks/cake.mdl"
local model2 = "models/mcmodelpack/other_blocks/cake-sliced.mdl"
local model3 = "models/mcmodelpack/other_blocks/cake-half.mdl"
local model4 = "models/mcmodelpack/other_blocks/cake-quarter.mdl"

//Accessor Funcs
function ENT:SetPlayer( ply )
    self.Owner = ply
end

function ENT:GetPlayer( )
    return self.Owner
end

function ENT:SpawnFunction( ply, tr )

	if ( !tr.Hit ) then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 10

	local ent = ents.Create( ClassName or "mc_cake" )
		ent:SetPos( SpawnPos )
		ent:Spawn()
		ent:Activate()

	return ent

end

function ENT:Initialize()

    if ( SERVER ) then
        self:SetModel( model1 )
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:SetSolid(SOLID_VPHYSICS)
    end

end

function ENT:Think()

	local phys = self.Entity:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
	end

end

function ENT:OnTakeDamage( dmginfo )

	self:TakePhysicsDamage( dmginfo )

end

function ENT:Use( activator )

	self:SetUseType(SIMPLE_USE)

	local model = self.Entity:GetModel()

// Check what model needs to be set
	if ( model == model4 ) then	
		self.Entity:Remove()
	end
	if ( model == model3 ) then
		self:SetModel( model4 )
	end
	if ( model == model2 ) then
		self:SetModel( model3 )
	end
	if ( model == model1 ) then
		self:SetModel( model2 )
	end

// Give health
	if activator:IsPlayer() then
		local health = activator:Health()
		activator:SetHealth( health + 25 )
	end

end
