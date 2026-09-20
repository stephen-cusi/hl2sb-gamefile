AddCSLuaFile()

--SCP-049 Coded by me Yay! Don't download if you don't like Horror Games! :-), Fixed nearly 3 years later, yeesh!

ENT.Base 				=	"base_nextbot"
ENT.Spawnable			=	false

CreateConVar("049_health","500",{FCVAR_ARCHIVE,FCVAR_NOTIFY}) -- SCP-049's Health.
CreateConVar("049_speed","135",{FCVAR_ARCHIVE,FCVAR_NOTIFY}) -- SCP-049's Speed
CreateConVar("049_zombiespawn","1",{FCVAR_ARCHIVE,FCVAR_NOTIFY})  -- Whether SCP-049 spawns zombies or not

if CLIENT then
language.Add( "npc_scp_049", "SCP-049" )
end

function ENT:CheckValid( ent )
	if !ent then
		return false
	end

	if !self:IsValid() then
		return false
	end

	if self:Health() < 0 then
		return false
	end

	if !ent:IsValid() then
		return false
	end

	if ent:Health() < 0 then
		return false
	end

	return true
end

function ENT:NPCTargeting()
	if ( self.RelationTimer or 0 ) < CurTime() then

		local bullseye = self.Bullseye

		if !self:CheckValid( bullseye ) then
			SafeRemoveEntity( bullseye )
		return end

		self.LastPos = self:GetPos( )

		local ents = ents.GetAll()
		table.Add(ents)

		for _,v in pairs(ents) do

			if v:GetClass() != self and v:GetClass() != "npc_bullseye" and v:GetClass() != "npc_grenade_frag" and v:IsNPC() then
					v:AddEntityRelationship( bullseye, 1, 10 )
			elseif v:GetClass() != self and v:GetClass() != "npc_bullseye" and v:GetClass() != "npc_grenade_frag" and v:IsNPC() and IsValid(v:GetActiveWeapon()) then
			v:AddEntityRelationship( bullseye, 3, 10 )
	end

		self.RelationTimer = CurTime() + 2

			if IsValid(self.Enemy) and self.Enemy:IsPlayer() and GetConVar("ai_ignoreplayers"):GetFloat() == 1 then
	self:SetEnemy( nil ) return end
	end

end

end

function ENT:CreateBullseye( height )

	local bullseye = ents.Create("npc_bullseye")
	bullseye:SetPos( self:GetPos() + Vector(0,0,height or 50) )
	bullseye:SetAngles( self:GetAngles() )
	bullseye:SetParent( self )
	bullseye:SetSolid( SOLID_NONE )
	bullseye:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )

	bullseye:SetOwner( self )
	bullseye:Spawn()
	bullseye:Activate()
	bullseye:SetHealth( 999999999 )

	self.Bullseye = bullseye
end

function ENT:Initialize()

local hlth = GetConVar( "049_health" )

	self.Boots = CreateSound(self,"049_footsteps.wav")

	self:SetModel( "models/scp/scp_049.mdl" )
	self:SetHealth( hlth:GetFloat() )
	EnemyRadius	= 1000000000
	self.Entity:SetCollisionBounds( Vector(-4,-4,0), Vector(4,4,64) )
	self:EmitSound("SCP049_Alert")
timer.Create( "SOUNDS" .. self:EntIndex(), 13, 1, function() self:Sounds() end )

end

function ENT:SetEnemy( ent )
	self:CreateBullseye()
	self.Enemy = ent
end

function ENT:GetEnemy()
	return self.Enemy
end


function ENT:HaveEnemy()
	if ( self:GetEnemy() and IsValid( self:GetEnemy() ) ) then
		if ( self:GetRangeTo( self:GetEnemy():GetPos() ) > EnemyRadius ) then
			return self:FindEnemy()
		elseif ( self:GetEnemy():IsPlayer() and !self:GetEnemy():Alive() ) then
			return self:FindEnemy()

		end
		return true
	else
		return self:FindEnemy()
	end
end

function ENT:FindEnemy()

	local humans = ents.FindInSphere( self:GetPos(), 99999999 )
		if humans then
				for i = 1, #humans do
					local m = humans[ i ]

			if GetConVar("ai_disabled"):GetInt() == 0 and GetConVar("ai_ignoreplayers"):GetInt() == 0 and m:IsPlayer() and m:Alive() then
							self:SetEnemy( m )
							return true
				else
					if GetConVar("ai_disabled"):GetInt() == 0 and GetConVar("ai_ignoreplayers"):GetInt() == 0 and ( m:IsNPC() and m:GetClass() != self and m:GetClass() != "npc_bullseye" and m:GetClass() != "npc_grenade_frag" and m:GetClass() != "npc_turret_floor" and m:GetClass() != "npc_turret_celing" and m:GetClass() != "npc_clawscanner" and m:GetClass() != "npc_cscanner" and m:GetClass() != "npc_strider" and m:GetClass() != "npc_combinedropship" and m:GetClass() != "npc_helicopter" and m:GetClass() != "npc_barnacle" and m:GetClass() != "npc_combine_camera" and m:GetClass() != "npc_rollermine" and m:GetClass() != "npc_manhack") then
						self:SetEnemy( m )
						return true
			else
						if GetConVar("ai_disabled"):GetInt() == 0 and GetConVar("ai_ignoreplayers"):GetInt() == 1 and ( m:IsNPC() and m:GetClass() != self and m:GetClass() != "npc_bullseye" and m:GetClass() != "npc_grenade_frag" and m:GetClass() != "npc_turret_floor" and m:GetClass() != "npc_turret_celing" and m:GetClass() != "npc_clawscanner" and m:GetClass() != "npc_cscanner" and m:GetClass() != "npc_strider" and m:GetClass() != "npc_combinedropship" and m:GetClass() != "npc_helicopter" and m:GetClass() != "npc_barnacle" and m:GetClass() != "npc_combine_camera" and m:GetClass() != "npc_rollermine" and m:GetClass() != "npc_combinegunship" and m:GetClass() != "npc_sniper" and m:GetClass() != "npc_maker" and m:GetClass() != "npc_manhack") then
						self:SetEnemy( m )
						return true
			else
				if GetConVar("ai_disabled"):GetInt() == 1 and GetConVar("ai_ignoreplayers"):GetInt() == 1 then
					self:SetEnemy( nil )
					return false
			end

		end
	
end

end

end

end

end

function ENT:RunBehaviour()
	while ( true ) do
		if ( self:HaveEnemy() ) then
				self:StartActivity( ACT_HL2MP_SWIM_IDLE_PISTOL )
				self.loco:SetDesiredSpeed( GetConVar( "049_speed" ):GetFloat() )
				self.loco:SetAcceleration( 900 )
				self:ChaseEnemy()
				self:StartActivity( ACT_IDLE )
end
		coroutine.wait( 2 )

	end

end

function ENT:ChaseEnemy( options )
	local options = options or {}
	local cvar = GetConVar( "ai_ignoreplayers" )
	local cvar2 = GetConVar( "ai_disabled" )
	
	local path = Path( "Follow" )
	path:SetMinLookAheadDistance( options.lookahead or 300 )
	path:SetGoalTolerance( options.tolerance or 0 )
	path:Compute( self, self:GetEnemy():GetPos() )

	if ( !path:IsValid() ) then return "failed" end

	while ( path:IsValid() and self:HaveEnemy() and cvar2:GetFloat() == 0 ) do

		if ( path:GetAge() > 0.1 ) then
			path:Compute( self, self:GetEnemy():GetPos() )
		end
		path:Update( self )

		if ( options.draw ) then path:Draw() end
		if ( self.loco:IsStuck() ) then
			self:HandleStuck()
			return "stuck"
		end
		
		coroutine.yield()
	
	
		local door = ents.FindInSphere( self:GetPos(), 40 )
			if door then
				for i = 1, #door do
					local v = door[ i ]
					if v:GetClass() == "func_door" || v:GetClass() == "prop_door_rotating" || v:GetClass() == "func_door_rotating" then
							v:Fire("UnLock")
							v:Fire("Open")
							v:EmitSound( "049_door_open.wav" )
					end
			end
end

			for k, enemy in pairs( ents.FindInSphere( self:GetPos(), 45 ) ) do
			if enemy then
					if enemy:IsPlayer() || enemy:IsNPC() == true then
						if IsValid(enemy) and enemy:Health() > 0 then
							if ( ( self:GetRangeTo( enemy:GetPos() ) ) < 45 ) then do
								enemy:TakeDamage( 40000, self, enemy ) end
							for k, ply in pairs( player.GetAll() ) do
									if enemy:IsNPC() and IsValid(enemy) then
										if enemy:Health() > 0 then return end
										ply:ChatPrint( "SCP-049 Has Infected " .. enemy:GetClass() .. "!")
										self:CreateZombie()
									elseif enemy:IsPlayer() and enemy:Alive() and IsValid(enemy) then return end
										if !enemy:IsNPC() then
										ply:ChatPrint( "SCP-049 Has Infected " .. enemy:GetName() .. "!" )
										self:CreateZombie()
										end
								end
							end
						end
					end
				end
			end
end
		
	return "ok"
end

function ENT:CreateZombie()
local cvar3 = GetConVar( "049_zombiespawn" )

if cvar3:GetFloat() == 0 then do
if self.Enemy == nil then return end
self:SetEnemy( nil )
self:EmitSound("049_death.wav")
self:PlaySequenceAndWait( "pickup" )
self:StartActivity( ACT_HL2MP_SWIM_IDLE_PISTOL)
return end

elseif cvar3:GetFloat() == 1 then do
if self.Enemy == nil then return end
		self:SetEnemy( nil )
		self:EmitSound("049_death.wav")
		self:PlaySequenceAndWait( "pickup" )
		self:StartActivity( ACT_HL2MP_SWIM_IDLE_PISTOL)
		local enemyalien = ents.Create( "npc_scp_049-2" )
			enemyalien:SetPos( self:GetPos() + self:GetForward() * 30 )
			enemyalien:SetAngles( self:GetAngles() )
			enemyalien:Spawn()
			enemyalien:Activate()

end

end

end

function ENT:OnKilled( dmginfo )

	hook.Call( "OnNPCKilled", GAMEMODE, self, dmginfo:GetAttacker(), dmginfo:GetInflictor() )
	self:BecomeRagdoll( dmginfo )
	self.Boots:Stop()
	timer.Stop( "SOUNDS" .. self:EntIndex() )
	timer.Stop( "MoarSounds" .. self:EntIndex() )
	self:StopSound("SCP049_Alert")
	self:StopSound("SCP049_Combat")

end

function ENT:OnStuck()
self:SetEnemy(nil)
end

function ENT:OnLeaveGround()
	self:StartActivity( ACT_JUMP )
	self.Boots:Stop()
end

function ENT:OnLandOnGround()
	if self:HaveEnemy() then
			self:StartActivity( ACT_HL2MP_SWIM_IDLE_PISTOL )
	else
		self:StartActivity( ACT_IDLE )
	end
end

function ENT:OnRemove()
timer.Stop( "SOUNDS" .. self:EntIndex() )
timer.Stop( "MoarSounds" .. self:EntIndex() )
self.Boots:Stop()
self:StopSound("SCP049_Alert")
self:StopSound("SCP049_Combat")
end

function ENT:Sounds()
self:EmitSound("SCP049_Combat")
timer.Create( "MoarSounds" .. self:EntIndex(), 26, 1, function() self:Sounds() end )
end

function ENT:Think()
	if !IsValid(self) then return end

	self:NPCTargeting()

	if self:GetVelocity():Length() > 30 and self:IsOnGround() then
	self.Boots:Play()
	elseif self:GetVelocity():Length() < 30 then
	self.Boots:Stop()
end

end