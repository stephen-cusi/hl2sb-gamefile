ENT.Type			= "ai"
ENT.Base 			= "base_ai"
ENT.Spawnable		= true
ENT.AdminSpawnable      = true

ENT.Category            = "SCPs"
ENT.PrintName		= "SCP-173"
ENT.Author			= "Tamiya / $@ⓊḈγ $@ȵĐω1€ℏ"
ENT.Contact    		= "D-Class"
ENT.Purpose 		= "To creep you out."
ENT.Instructions 	= "Don't lose direct eye contact with it."

ENT.AutomaticFrameAdvance = true

DEFINE_BASECLASS("scp173")

local CONST_E = 2.718281828459

function ENT:Initialize()
	if BaseClass.Initialize then
		BaseClass.Initialize(self)
	end
	
	if (not SERVER) then return end
	
	function self:DropToSurface(...) return BaseClass.DropToSurface(self, ...) end
	function self:DropToSurfaceAtPos(...) return BaseClass.DropToSurfaceAtPos(self, ...) end
	function self:SpawnFunction(...) return BaseClass.SpawnFunction(self, ...) end
	function self:OpenDoor(...) return BaseClass.OpenDoor(self, ...) end
	function self:HasEntLOS(...) return BaseClass.HasEntLOS(self, ...) end
	function self:HasEntLOSAtPos(...) return BaseClass.HasEntLOSAtPos(self, ...) end
	function self:CanEntSeeUs(...) return BaseClass.CanEntSeeUs(self, ...) end
	function self:CanEntSeeUsAtPos(...) return BaseClass.CanEntSeeUsAtPos(self, ...) end
	function self:HasAnyLOS(...) return BaseClass.HasAnyLOS(self, ...) end
	function self:CanAnyoneSeeUs(...) return BaseClass.CanAnyoneSeeUs(self, ...) end
	function self:CanAnyoneSeeUsAtPos(...) return BaseClass.CanAnyoneSeeUsAtPos(self, ...) end
	function self:PrepareAttack(...) return BaseClass.PrepareAttack(self, ...) end
	function self:TeleportToPos(...) return BaseClass.TeleportToPos(self, ...) end
	function self:PathToVictimClear(...) return BaseClass.PathToVictimClear(self, ...) end
	function self:PathToPosClear(...) return BaseClass.PathToPosClear(self, ...) end
	--function self:TeleportBehindVictim(...) return BaseClass.TeleportBehindVictim(self, ...) end
	function self:CreepForward(...) return BaseClass.CreepForward(self, ...) end
	function self:Attack(...) return BaseClass.Attack(self, ...) end
	function self:KillSounds(...) return BaseClass.KillSounds(self, ...) end
	function self:FaceVictim(...) return BaseClass.FaceVictim(self, ...) end
	function self:PlayDead(...) return BaseClass.PlayDead(self, ...) end
	function self:BeCreepy(...) return BaseClass.BeCreepy(self, ...) end
	function self:OnRemove(...) return BaseClass.OnRemove(self, ...) end
	
	self.PrevNPCUpdate = CurTime()
	self.PathClear = false
	self.DoingSchedule = false
	
	self:SetSolid(SOLID_BBOX)
	self:SetMoveType(MOVETYPE_STEP)
	
	self:SetHullType(HULL_MEDIUM_TALL)
	self:SetHullSizeNormal()
	
	self:CapabilitiesAdd(bit.bor(CAP_MOVE_GROUND, CAP_OPEN_DOORS, CAP_AUTO_DOORS, CAP_USE))
	
	self:SetHealth(100)
end

function ENT:OnTakeDamage(dmg)
end

--[[
local SCP173Schd

if SERVER then
	SCP173Schd = ai_schedule.New("SCP-173 Schedule")

	SCP173Schd:EngTask("TASK_GET_PATH_TO_RANDOM_NODE", 200)
	SCP173Schd:EngTask("TASK_RUN_PATH", 0)
	SCP173Schd:EngTask("TASK_WAIT_FOR_MOVEMENT", 0)
	SCP173Schd:AddTask("FindEnemy", {
		Radius = 2000
	})
	SCP173Schd:EngTask("TASK_GET_PATH_TO_RANGE_ENTITY_LKP_LOS", 0)
	SCP173Schd:EngTask("TASK_RUN_PATH", 0)
end
]]

function ENT:SCP173_Think()
	if (not SERVER) then return end
	
	local deltaTime = BaseClass.SCP173_Think(self)
	
	if (not self.SCP173_Initialized) then return end
	
	self.PathClear = self:PathToVictimClear()
	
	local randnum = math.Rand(0, 1)
	local probRate = self.CreepProbRate
	
	if (not isnumber(probRate)) then
		probRate = 2
	end
	
	if ((1 - CONST_E ^ (-probRate * deltaTime)) > randnum) then
		if self.CanThink then
			if (not self.PathClear) then
				if (not self:CanAnyoneSeeUs()) then
					
					if (not self.DoingSchedule) then
						self:SetCondition(68)
						self:SetEnemy(self.Victim)
						self:SetSchedule(SCHED_CHASE_ENEMY)
						
						self.DoingSchedule = true
					end
					
					self:TeleportToPos(self:GetPos() + self:GetAngles():Forward() * self.MoveSpeed * (CurTime() - self.PrevNPCUpdate))
				elseif self.DoingSchedule then
					self:StopMoving()
					self:SetSchedule(SCHED_NPC_FREEZE)
					
					self.DoingSchedule = false
				end
			elseif self.DoingSchedule then
				self:StopMoving()
				self:SetSchedule(SCHED_NPC_FREEZE)
				
				self.DoingSchedule = false
			end
		end
		
		self.PrevNPCUpdate = CurTime()
	end
	
	return deltaTime
end

function ENT:ScheduleFinished()
	self.DoingSchedule = (not self.DoingSchedule)
end

function ENT:EngineScheduleFinish()
	self.DoingSchedule = (not self.DoingSchedule)
end

function ENT:Draw()
	self:DrawModel()
end
