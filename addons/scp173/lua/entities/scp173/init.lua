-- SCP-173 (From Weeping Angel by Mr. Blue)
-- Original stalking entity by that Tetris guy.
-- Special Thanks to Enclave Soldier for sharing the SCP-173 model
-- Credit to Darth Telac for the code.
-- Thanks to Tardis69 for creating a version for the workshop weeping angel

AddCSLuaFile( 'cl_init.lua' )
AddCSLuaFile( 'shared.lua' )
include('shared.lua')

local CONST_E = 2.718281828459

local ENABLE_THINKING = true
local IGNORE_PLAYERS = false
local COOLDOWN_TIME = 0.2
local THINK_FREQ = 60
local TELEPORT_COOLDOWN = 0.1
--[[
local TELEPORT_MAX_DIST = 700
local TELEPORT_MIN_DIST = 600
]]
local TELEPORT_MAX_TRIES = 75

local CREEP_PROB_RATE = 2
local CREEP_COOLDOWN = 0.5
local CREEP_SPEED = 300

local MOVE_SPEED = 200

local STAB_MAX_DIST = 20
local STAB_PROB_RATE = 2
local STAB_COOLDOWN = 0.001
local STAB_FORCE = 50
local STAB_DAMAGE = 500

sound.Add({
	name = "scp173_move",
	channel = CHAN_BODY,
	volume = 0.25,
	level = 75,
	pitch = { 100, 100 },
	sound = "scp173_moving.wav"
})

local sndDrawKnife = Sound("scp173_attack.wav")
local sndStab = Sound("scp173_necksnap.wav")
local sndMove = "scp173_move"

function ENT:DropToSurface()
	local exclusions = {self}
	
	if (self.Knife and self.Knife:IsValid()) then
		table.insert(exclusions, self.Knife)
	end
	
	local up = self:GetAngles():Up()
	local point1 = self:GetPos()
	local point2 = self:GetPos() - 1000 * up
	local tr = util.TraceEntity({
		start     = point1,
		endpos     = point2,
		filter     = exclusions,
		mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
	}, self)
	if (tr.Hit and (not tr.StartSolid)) then
		self:SetPos(point1 + (point2 - point1) * tr.Fraction + tr.HitNormal * self:BoundingRadius() * 0.01)
	elseif tr.StartSolid then
		point1 = self:GetPos() + up * self:BoundingRadius()
		point2 = self:GetPos()
		tr = util.TraceEntity({
			start     = point1,
			endpos     = point2,
			filter     = exclusions,
			mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
		}, self)
		if (tr.Hit and (not tr.StartSolid)) then
			self:SetPos(point1 + (point2 - point1) * tr.Fraction + tr.HitNormal * self:BoundingRadius() * 0.01)
		end
	end
end

function ENT:DropToSurfaceAtPos(pos)
	local exclusions = {self}
	
	if (self.Knife and self.Knife:IsValid()) then
		table.insert(exclusions, self.Knife)
	end
	
	local up = self:GetAngles():Up()
	local point1 = pos
	local point2 = pos - 1000 * up
	local tr = util.TraceEntity({
		start     = point1,
		endpos     = point2,
		filter     = exclusions,
		mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
	}, self)
	if (tr.Hit and (not tr.StartSolid)) then
		return point1 + (point2 - point1) * tr.Fraction + tr.HitNormal * self:BoundingRadius() * 0.01
	elseif tr.StartSolid then
		point1 = pos + up * self:BoundingRadius()
		point2 = pos
		tr = util.TraceEntity({
			start     = point1,
			endpos     = point2,
			filter     = exclusions,
			mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
		}, self)
		if (tr.Hit and (not tr.StartSolid)) then
			return point1 + (point2 - point1) * tr.Fraction + tr.HitNormal * self:BoundingRadius() * 0.01
		else
			return pos
		end
	else
		return pos
	end
end

function ENT:SpawnFunction(plr, tr)
    if (not tr.Hit) then return end
	
    print("SCP-173")
    
    local ent = ents.Create( ClassName )
	local spawnPos = tr.HitPos + tr.HitNormal * 18
	
	local up = plr:GetAngles():Up()
	local dir = (spawnPos - plr:GetPos()):GetNormalized()
	local vec = (dir - up * dir:Dot(up)):GetNormalized()
	
	ent:SetPos(spawnPos)
	ent:SetAngles(vec:AngleEx(up))
    ent:Spawn()
    ent:Activate()
    ent:DropToSurface()  
    
    return ent
end

local function SCP173_Error(str)
	local errorTable = {}
	
	for i = 1, (#str / 511 + 1) do
		table.insert(errorTable, (#errorTable + 1), string.sub(str, ((i - 1) * 511 + 1), math.min((i * 511), #str)))
	end
	
	if (#errorTable > 0) then
		errorTable[#errorTable] = errorTable[#errorTable] .. "\n"
	end
	
	ErrorNoHalt(unpack(errorTable))
end

local function SCP173_Coroutine(ent)
	local self = ent
	
	while true do
		if (not (self and self:IsValid())) then return end
		
		local deltaTime = self:SCP173_Think()
		
		if (not isnumber(deltaTime)) then
			if (THINK_FREQ > 0) then
				deltaTime = 1 / THINK_FREQ
			else
				deltaTime = engine.TickInterval()
			end
			
			self.DeltaTime = deltaTime
		end
		
		coroutine.wait(deltaTime)
	end
end

function ENT:Initialize()
    self:SetModel("models/scp173_new/scp173_new.mdl")
	
    self:PhysicsInit(SOLID_VPHYSICS)
    
    self.CurSound = ""
    
    self.NextCreep = 0
    self.NextStab = 0
	self.Moving = false
	self.CanThink = ENABLE_THINKING
	self.CreepProbRate = CREEP_PROB_RATE
	
    self.Knife = NULL
	self.Victim = NULL
    
    self.IsBeingCreepy = false
    
    self:SetMoveType(MOVETYPE_FLY)
	
	self.SCP173_Initialized = true
	
	self.SCP173_Coroutine = coroutine.create(SCP173_Coroutine)
	
	local hadNoErrors, args = coroutine.resume(self.SCP173_Coroutine, self)
	
	if (not hadNoErrors) then
		SCP173_Error("[ERROR] " .. args)
	end
end

function ENT:OpenDoor(door)
	if (not door:IsValid()) then return end
	
	local class = door:GetClass()
	
	if ((class != "prop_door_rotating") and (class != "func_door") and (class != "func_door_rotating")) then return end
	
	if (class == "prop_door_rotating") then
		local doorFlags = door:GetFlags()
		
		if (bit.band(doorFlags, 32768) == 0) then
			local saveTab = door:GetSaveTable()
			
			if ((not saveTab.m_bLocked) and (saveTab.m_eDoorState == 0)) then
				door:Fire("Open")
			end
		end
	else
		local doorFlags = door:GetFlags()
		
		if ((bit.band(doorFlags, 512) == 0) and ((bit.band(doorFlags, 256) != 0) or (bit.band(doorFlags, 1024) != 0))) then
			local saveTab = door:GetSaveTable()
			
			if ((not saveTab.m_bLocked) and (saveTab.m_toggle_state != 0)) then
				door:Fire("Open")
			end
		end
	end
end

function ENT:HasEntLOS(ent)
	local currVictim = ent
	
	if ((not currVictim:IsValid()) or ((not currVictim:IsPlayer()) and (not currVictim:IsNPC()))) then
		return false
	end
	
	local posOffset = self:GetAngles():Up() * self:BoundingRadius()
	
	local traceBlocked = false
	
	local exclusions = {self}
	
	if (self.Knife and self.Knife:IsValid()) then
		table.insert(exclusions, self.Knife)
	end
	
	if (currVictim and currVictim:IsValid()) then
		table.insert(exclusions, currVictim)
	end
	
	if (GetConVarNumber("scp173_useRenderGroups") != 0) then
		local tr = util.TraceLineEx(
		{
			start     = currVictim:EyePos(),
			endpos     = self:GetPos() + posOffset,
			filter     = exclusions,
			mask     = MASK_SOLID
		})
		
		for k, v in ipairs(tr) do
			if v.Hit then
				if v.Entity then
					if (v.Entity:IsValid() and (not v.Entity:IsWorld())) then
						if ((v.Entity != self) and (v.Entity != ent)) then
							local renderGroup = v.Entity.SCP173_RenderGroup
							
							if renderGroup then
								if ((renderGroup == RENDERGROUP_OPAQUE) or (renderGroup == RENDERGROUP_OPAQUE_BRUSH)) then
									traceBlocked = true
									
									break
								end
							end
						end
					elseif v.Entity:IsWorld() then
						traceBlocked = true
					end
				end
			end
		end
	else
		local tr = util.TraceLineEx(
		{
			start     = currVictim:EyePos(),
			endpos     = self:GetPos() + posOffset,
			filter     = exclusions,
			mask     = MASK_OPAQUE
		})
		
		traceBlocked = tr.Hit
	end
	
	return (not traceBlocked)
end

function ENT:HasEntLOSAtPos(ent, pos)
	local currVictim = ent
	
	if ((not currVictim:IsValid()) or ((not currVictim:IsPlayer()) and (not currVictim:IsNPC()))) then
		return false
	end
	
	local posOffset = self:GetAngles():Up() * self:BoundingRadius()
	
	local traceBlocked = false
	
	local exclusions = {self}
	
	if (self.Knife and self.Knife:IsValid()) then
		table.insert(exclusions, self.Knife)
	end
	
	if (currVictim and currVictim:IsValid()) then
		table.insert(exclusions, currVictim)
	end
	
	if (GetConVarNumber("scp173_useRenderGroups") != 0) then
		local tr = util.TraceLineEx(
		{
			start     = currVictim:EyePos(),
			endpos     = pos + posOffset,
			filter     = exclusions,
			mask     = MASK_SOLID
		})
		
		for k, v in ipairs(tr) do
			if v.Hit then
				if v.Entity then
					if (v.Entity:IsValid() and (not v.Entity:IsWorld())) then
						if ((v.Entity != self) and (v.Entity != ent) and (not v.Entity:IsWorld())) then
							local renderGroup = v.Entity.SCP173_RenderGroup
							
							if renderGroup then
								if ((renderGroup == RENDERGROUP_OPAQUE) or (renderGroup == RENDERGROUP_OPAQUE_BRUSH)) then
									traceBlocked = true
									
									break
								end
							end
						end
					elseif v.Entity:IsWorld() then
						traceBlocked = true
					end
				end
			end
		end
	else
		local tr = util.TraceLineEx(
		{
			start     = currVictim:EyePos(),
			endpos     = pos + posOffset,
			filter     = exclusions,
			mask     = MASK_OPAQUE
		})
		
		traceBlocked = tr.Hit
	end
	
	return (not traceBlocked)
end

function ENT:CanEntSeeUs(ent)
	local function crossDist(vec1, vec2)
		return math.sqrt(vec1:LengthSqr() * vec2:LengthSqr() - vec1:Dot(vec2)^2)
	end
	
	local function arctan2(y, x)
		if ((x != 0) or (y != 0)) then
			if (math.abs(x) >= math.abs(y)) then
				if (x >= 0) then
					return math.atan(y / x)
				elseif (y >= 0) then
					return math.atan(y / x) + math.pi
				else
					return math.atan(y / x) - math.pi
				end
			elseif (y >= 0) then
				return math.pi / 2 - math.atan(x / y)
			else
				return -math.pi / 2 - math.atan(x / y)
			end
		else
			return 0.0
		end
	end
	
	local currVictim = ent
	
	if ((not currVictim:IsValid()) or ((not currVictim:IsPlayer()) and (not currVictim:IsNPC()))) then
		return false
	end
	
	local proceed = false
	
	if (currVictim:IsPlayer() or currVictim:IsNPC()) then
		local allBlinkStates = SCP_Mod_BlinkStates
		
		if istable(allBlinkStates) then
			if (not allBlinkStates[currVictim:EntIndex()]) then
				proceed = true
			end
		else
			proceed = true
		end
	else
		proceed = true
	end
	
	if proceed then
		if self:HasEntLOS(currVictim) then
			local posOffset = self:GetAngles():Up() * self:BoundingRadius()
			
			if currVictim:IsPlayer() then
				if currVictim:Alive() then
					local disp = self:GetPos() + posOffset - currVictim:EyePos()
					local radius = self:BoundingRadius()
					
					if ((disp:LengthSqr() > (radius^2)) and (disp:LengthSqr() > 0)) then
						local fov
						
						if (GetConVarNumber("scp173_useScreenDims") != 0) then
							if istable(SCP173_ScreenDimensions) then
								if istable(SCP173_ScreenDimensions[currVictim:EntIndex()]) then
									local screenDims = SCP173_ScreenDimensions[currVictim:EntIndex()]
									fov = 360 * math.atan(math.sqrt(math.tan(math.pi * currVictim:GetFOV() / 360)^2 * (screenDims.x^2 / screenDims.y^2 + 1))) / math.pi
								else
									fov = currVictim:GetFOV() * 1.5
								end
							else
								fov = currVictim:GetFOV() * 1.5
							end
						else
							fov = currVictim:GetFOV() * 1.5
						end
						
						local distSqr = disp:LengthSqr()
						local aimVec = currVictim:GetEyeTraceNoCursor().Normal
						
						local dir = disp:GetNormalized()
						local viewRadius = arctan2(radius/math.sqrt(distSqr), math.sqrt(1 - radius^2/distSqr)) * 180 / math.pi
						local viewOffset = arctan2(crossDist(dir, aimVec), dir:Dot(aimVec)) * 180 / math.pi
						
						if (viewOffset <= (fov / 2 + viewRadius)) then
							return true
						end
					else
						return true
					end
				end
			elseif (currVictim:GetNPCState() != NPC_STATE_DEAD) then
				local disp = self:GetPos() + posOffset - currVictim:EyePos()
				local radius = self:BoundingRadius()
				
				if ((disp:LengthSqr() > (radius^2)) and (disp:LengthSqr() > 0)) then
					local fov = 90
					local distSqr = disp:LengthSqr()
					local aimVec = currVictim:GetAimVector()
					local dir = disp:GetNormalized()
					local viewRadius = arctan2(radius/math.sqrt(distSqr), math.sqrt(1 - radius^2/distSqr)) * 180 / math.pi
					local viewOffset = arctan2(crossDist(dir, aimVec), dir:Dot(aimVec)) * 180 / math.pi
					
					if (viewOffset <= (fov / 2 + viewRadius)) then
						return true
					end
				else
					return true
				end
			end
		end
	end
	
	return false
end

function ENT:CanEntSeeUsAtPos(ent, pos)
	local function crossDist(vec1, vec2)
		return math.sqrt(vec1:LengthSqr() * vec2:LengthSqr() - vec1:Dot(vec2)^2)
	end
	
	local function arctan2(y, x)
		if ((x != 0) or (y != 0)) then
			if (math.abs(x) >= math.abs(y)) then
				if (x >= 0) then
					return math.atan(y / x)
				elseif (y >= 0) then
					return math.atan(y / x) + math.pi
				else
					return math.atan(y / x) - math.pi
				end
			elseif (y >= 0) then
				return math.pi / 2 - math.atan(x / y)
			else
				return -math.pi / 2 - math.atan(x / y)
			end
		else
			return 0.0
		end
	end
	
	local currVictim = ent
	
	if ((not currVictim:IsValid()) or ((not currVictim:IsPlayer()) and (not currVictim:IsNPC()))) then
		return false
	end
	
	local proceed = false
	
	if (currVictim:IsPlayer() or currVictim:IsNPC()) then
		local allBlinkStates = SCP_Mod_BlinkStates
		
		if istable(allBlinkStates) then
			if (not allBlinkStates[currVictim:EntIndex()]) then
				proceed = true
			end
		else
			proceed = true
		end
	else
		proceed = true
	end
	
	if proceed then
		if self:HasEntLOSAtPos(currVictim, pos) then
			local posOffset = self:GetAngles():Up() * self:BoundingRadius()
			
			if currVictim:IsPlayer() then
				if currVictim:Alive() then
					local disp = pos + posOffset - currVictim:EyePos()
					
					local radius = self:BoundingRadius()
					if ((disp:LengthSqr() > (radius^2)) and (disp:LengthSqr() > 0)) then
						local fov
						
						if (GetConVarNumber("scp173_useScreenDims") != 0) then
							if istable(SCP173_ScreenDimensions) then
								if istable(SCP173_ScreenDimensions[currVictim:EntIndex()]) then
									local screenDims = SCP173_ScreenDimensions[currVictim:EntIndex()]
									fov = 360 * math.atan(math.sqrt(math.tan(math.pi * currVictim:GetFOV() / 360)^2 * (screenDims.x^2 / screenDims.y^2 + 1))) / math.pi
								else
									fov = currVictim:GetFOV() * 1.5
								end
							else
								fov = currVictim:GetFOV() * 1.5
							end
						else
							fov = currVictim:GetFOV() * 1.5
						end
						
						local distSqr = disp:LengthSqr()
						local aimVec = currVictim:GetEyeTraceNoCursor().Normal
						
						local dir = disp:GetNormalized()
						local viewRadius = arctan2(radius/math.sqrt(distSqr), math.sqrt(1 - radius^2/distSqr)) * 180 / math.pi
						local viewOffset = arctan2(crossDist(dir, aimVec), dir:Dot(aimVec)) * 180 / math.pi
						
						if (viewOffset <= (fov / 2 + viewRadius)) then
							return true
						end
					else
						return true
					end
				end
			elseif (currVictim:GetNPCState() != NPC_STATE_DEAD) then
				local disp = pos + posOffset - currVictim:EyePos()
				local radius = self:BoundingRadius()
				if ((disp:LengthSqr() > (radius^2)) and (disp:LengthSqr() > 0)) then
					local fov = 90
					local distSqr = disp:LengthSqr()
					local aimVec = currVictim:GetAimVector()
					local dir = disp:GetNormalized()
					local viewRadius = arctan2(radius/math.sqrt(distSqr), math.sqrt(1 - radius^2/distSqr)) * 180 / math.pi
					local viewOffset = arctan2(crossDist(dir, aimVec), dir:Dot(aimVec)) * 180 / math.pi
					
					if (viewOffset <= (fov / 2 + viewRadius)) then
						return true
					end
				else
					return true
				end
			end
		end
	end
	
	return false
end

function ENT:HasAnyLOS()
	local allEnts = ents.GetAll()
	
	local canBeSeen = false
	for k, v in pairs(allEnts) do
		if ((v:IsPlayer() or v:IsNPC()) and (v:GetClass() != self:GetClass())) then
			canBeSeen = canBeSeen or self:HasEntLOS(v)
			
			if canBeSeen then
				break
			end
		end
	end
	
	return canBeSeen
end

function ENT:CanAnyoneSeeUs()
	local allEnts = ents.GetAll()
	
	local canBeSeen = false
	for k, v in pairs(allEnts) do
		if ((v:IsPlayer() or v:IsNPC()) and (v:GetClass() != self:GetClass())) then
			canBeSeen = canBeSeen or self:CanEntSeeUs(v)
			
			if canBeSeen then
				break
			end
		end
	end
	
	return canBeSeen
end

function ENT:CanAnyoneSeeUsAtPos(pos)
	local allEnts = ents.GetAll()
	
	local canBeSeen = false
	for k, v in pairs(allEnts) do
		if ((v:IsPlayer() or v:IsNPC()) and (v:GetClass() != self:GetClass())) then
			canBeSeen = canBeSeen or self:CanEntSeeUsAtPos(v, pos)
			
			if canBeSeen then
				break
			end
		end
	end
	
	return canBeSeen
end

function ENT:PrepareAttack(vec)
	if (self.Knife and self.Knife:IsValid()) then
		self.Knife:Remove()
	end
	
	local vec2 = vec + Vector(0, 0, 0)
	
	vec2 = vec2 - self:GetAngles():Up() * vec2:Dot(self:GetAngles():Up())
    vec2:Normalize()
	
    local knifepos = self:GetPos() + 1.25 * vec2 * self:BoundingRadius() + self:GetAngles():Up() * self:BoundingRadius() * 0.5
	
    self.Knife = ents.Create( "scp173_knife" )
    self.Knife:SetPos( knifepos )
    self.Knife:Spawn()
    self.Knife:SetColor(Color(0, 0, 0, 0))
    self.Knife:SetParent(self)
    
    self:EmitSound( sndDrawKnife, 300, 100 )
end

function ENT:FaceVictim()
	if (self.Victim and self.Victim:IsValid()) then
		local up = self:GetAngles():Up()
		local dir = (self.Victim:LocalToWorld(self.Victim:OBBCenter()) - self:GetPos()):GetNormalized()
		local vec = (dir - up * dir:Dot(up)):GetNormalized()
		
		self:SetAngles(vec:AngleEx(up))
	end
end

function ENT:FacePoint(point)
	local up = self:GetAngles():Up()
	local dir = (point - self:GetPos()):GetNormalized()
	local vec = (dir - up * dir:Dot(up)):GetNormalized()
	
	self:SetAngles(vec:AngleEx(up))
end

function ENT:TeleportToPos(pos)
	local function randSphere(radius)
		if (radius == 0) then return Vector(0, 0, 0) end
		
		local x = 2 * radius * math.asin(2 * math.asin(math.Rand(-1.0, 1.0)) / math.pi) / math.pi
		local y = 2 * math.sqrt(radius^2 - x^2) * math.asin(math.Rand(-1.0, 1.0)) / math.pi
		local z = math.sqrt(radius^2 - x^2 - y^2) * math.Rand(-1.0, 1.0)
		
		return Vector(x, y, z)
	end
	
	local pos2 = pos + Vector(0, 0, 0)
	
	local offset = self:LocalToWorld(self:OBBCenter()) - self:GetPos()
	
	local exclusions = {self}
	
	if (self.Knife and self.Knife:IsValid()) then
		table.insert(exclusions, self.Knife)
	end
	
	if (self.Victim and self.Victim:IsValid()) then
		table.insert(exclusions, self.Victim)
	end
	
    for i = 1, TELEPORT_MAX_TRIES do
		local spawnPos = self:DropToSurfaceAtPos(pos2)
		
		local tr = util.TraceLine({
			start     = (self:GetPos() + offset),
			endpos     = (spawnPos + offset),
			filter     = exclusions,
			mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
		})
		
		if (not tr.StartSolid) then
			local tr2 = util.TraceEntity({
				start     = spawnPos,
				endpos     = spawnPos,
				filter     = exclusions,
				mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
			}, self)
			
			if ((not tr2.StartSolid) and (not tr.Hit) and (not self:CanAnyoneSeeUsAtPos(spawnPos))) then
				self:FacePoint(spawnPos)
				self:SetPos(spawnPos)
				break
			else
				local deltaRand = randSphere(2 * self:BoundingRadius())
				pos2 = pos2 + (deltaRand - self:GetAngles():Up() * deltaRand:Dot(self:GetAngles():Up()) * 2 / 3)
			end
		else
			break
		end
    end
end

function ENT:PathToVictimClear(...)
	if (not self.Victim) then return false end
	if (not self.Victim:IsValid()) then return false end
	
	local exclusions = {self}
	
	if (self.Knife and self.Knife:IsValid()) then
		table.insert(exclusions, self.Knife)
	end
	
	table.insert(exclusions, self.Victim)
	
	local addedExclusions = {...}
	
	for k, v in ipairs(addedExclusions) do
		if (v and v:IsValid()) then
			table.insert(exclusions, v)
		end
	end
	
	local tr = util.TraceLine({
		start     = self.Victim:LocalToWorld(self.Victim:OBBCenter()),
		endpos     = self:LocalToWorld(self:OBBCenter()),
		filter     = exclusions,
		mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
	})
	
	return (not tr.Hit)
end

function ENT:PathToPosClear(pos, ...)
	local offset = self:LocalToWorld(self:OBBCenter()) - self:GetPos()
	
	local exclusions = {self}
	
	if (self.Knife and self.Knife:IsValid()) then
		table.insert(exclusions, self.Knife)
	end
	
	local addedExclusions = {...}
	
	for k, v in ipairs(addedExclusions) do
		if (v and v:IsValid()) then
			table.insert(exclusions, v)
		end
	end
	
	local tr = util.TraceLine({
		start     = (pos + offset),
		endpos     = (self:GetPos() + offset),
		filter     = exclusions,
		mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
	})
	
	return (not tr.Hit)
end

--[[
function ENT:TeleportBehindVictim()
	if (self.Victim and self.Victim:IsValid()) then
		if (CurTime() < self.NextTeleport) then return end
		
		local plraim = self.Victim:GetAngles():Forward()
		
		local plrpos = self.Victim:LocalToWorld(self.Victim:OBBCenter())
		
		local exclusions = {self}
		
		if (self.Knife and self.Knife:IsValid()) then
			table.insert(exclusions, self.Knife)
		end
		
		table.insert(exclusions, self.Victim)
		
		local tr = util.TraceLine({
			start     = plrpos - plraim * TELEPORT_MIN_DIST,
			endpos     = plrpos - plraim * TELEPORT_MAX_DIST,
			filter     = exclusions,
			mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
		})
		
		
		self:TeleportToPos( tr.HitPos + (self.Victim:GetPos() - plrpos) - 1.125 * plraim * self:BoundingRadius() )
		
		self.NextTeleport = CurTime() + TELEPORT_COOLDOWN
	end
end
]]

function ENT:CreepForward(disp)
	if (CurTime() < self.NextCreep) then return end
	
	self:TeleportToPos(self:GetPos() + disp:GetNormalized() * math.min(CREEP_SPEED, disp:Length()))
	
	self.NextCreep = CurTime() + CREEP_COOLDOWN
end

function ENT:Attack(vec)
    if ((not self.Victim) or (not self.Victim:IsValid())) then return end
    if (CurTime() < self.NextStab) then return end
    
	local exclusions = {self}
	
	if (self.Knife and self.Knife:IsValid()) then
		table.insert(exclusions, self.Knife)
	end
	
	table.insert(exclusions, self.Victim)
	
	local tr = util.TraceLine(
	{
		start     = self:GetPos(),
		endpos     = self.Victim:LocalToWorld(self.Victim:OBBCenter()),
		filter     = exclusions,
		mask     = bit.bor(MASK_NPCSOLID, MASK_NPCWORLDSTATIC)
	})
	
	if (not tr.Hit) then
		if ((not self.Knife) or (not self.Knife:IsValid())) then
			self:PrepareAttack(vec)
		end
		
		local forceVec = vec * STAB_FORCE
		
		local dmgInfo = DamageInfo()
		
		dmgInfo:SetDamage(STAB_DAMAGE)
		dmgInfo:SetDamageType(DMG_CLUB)
		dmgInfo:SetDamageForce(forceVec)
		dmgInfo:SetAttacker(self)
		dmgInfo:SetInflictor(self.Knife)
		dmgInfo:SetMaxDamage(self.Victim:Health())
		
		local dmgPos
		local targetBone = self.Victim:LookupBone("ValveBiped.Bip01_Head1")
		
		if targetBone then
			local bonePos, _ = self.Victim:GetBonePosition(targetBone)
			
			dmgPos = bonePos
		else
			dmgPos = self.Victim:LocalToWorld(self.Victim:OBBCenter())
		end
		
		dmgInfo:SetDamagePosition(dmgPos)
		dmgInfo:SetReportedPosition(dmgPos)
		
		self.Victim:TakeDamageInfo(dmgInfo)
		
		self.Victim:EmitSound(sndStab, 65, 100)
		
		self.Knife:Remove()
		
		self.NextStab = CurTime() + STAB_COOLDOWN
	end
end

function ENT:KillSounds()
	self:StopSound(self.CurSound)
end

function ENT:PlayDead()
    if (not self.IsBeingCreepy) then return end
    
    -- Face the victim!
    self:FaceVictim()
    
    -- Act normal!
    self.IsBeingCreepy = false

    -- Be quiet!
    self:KillSounds()
        
    -- Hide your knife!
    if self.Knife:IsValid() then self.Knife:Remove() end
    
    -- Reset everything since we stopped doing them
    self.NextCreep = 0
    self.NextStab = 0
end

function ENT:BeCreepy()
	if (self.Victim and self.Victim:IsValid()) then
		self.IsBeingCreepy = true
		
		local deltaTime = self.DeltaTime
		
		if (not isnumber(deltaTime)) then
			deltaTime = 0
			self.DeltaTime = 0
		end
		
		local PreDisp = self.Victim:GetPos() - self:GetPos()
		local Vec = PreDisp:GetNormalized()
		local Disp = PreDisp - 1.5 * Vec * self:BoundingRadius()
		local Dist = Disp:Length()
		
		-- Randomly decide what creepy things we should do.
		local randnum = math.Rand(0, 1)
		
		if Dist > STAB_MAX_DIST then
			if (1 - CONST_E ^ (-CREEP_PROB_RATE * deltaTime)) > randnum then
				self:CreepForward(Disp)
			end
		else -- We're close enough to attack!
			if (not self.Knife:IsValid()) then
				self:PrepareAttack(Vec)
			end
			
			if STAB_PROB_RATE > randnum then
				self:Attack(Vec)
			end
		end
		
		self:FaceVictim()
	end
end

function ENT:SCP173_Think()
	if (not self.SCP173_Initialized) then return end
	
	self.MoveSpeed = MOVE_SPEED
	self.CanThink = ENABLE_THINKING
	self.CreepProbRate = CREEP_PROB_RATE
	
	if (not ENABLE_THINKING) then
		local deltaTime
		
		if (THINK_FREQ > 0) then
			deltaTime = 1 / THINK_FREQ
		else
			deltaTime = engine.TickInterval()
		end
		
		self.DeltaTime = deltaTime
		
		if self.Moving then
			self:StopSound("scp173_moving")
			self.Moving = false
		end
		
		return deltaTime
	end
	
	local allVictims = {}
	local allEnts = ents.GetAll()
	
	for i = 1, #allEnts do
		local currEnt = allEnts[i]
		if (((currEnt:IsPlayer() and (not IGNORE_PLAYERS)) or currEnt:IsNPC()) and (currEnt:GetClass() != self:GetClass())) then
			table.insert(allVictims, currEnt)
		end
	end
	
	local closestVictim = allVictims[1]
	
	for i = 2, #allVictims do
		local currVictim = allVictims[i]
		if currVictim:IsValid() then
			local proceed = false
			
			if (currVictim:IsPlayer()) then
				if currVictim:Alive() then
					proceed = true
				end
			else
				if (currVictim:GetNPCState() != NPC_STATE_DEAD) then
					proceed = true
				end
			end
			
			if proceed then
				if closestVictim:IsValid() then
					local distSqr1 = (currVictim:LocalToWorld(currVictim:OBBCenter()) - self:GetPos()):LengthSqr()
					local distSqr2 = (closestVictim:LocalToWorld(closestVictim:OBBCenter()) - self:GetPos()):LengthSqr()
					
					if (distSqr1 < distSqr2) then
						closestVictim = currVictim
					end
				else
					closestVictim = currVictim
				end
			end
		end
	end
	
	if closestVictim then
		if closestVictim:IsValid() then
			if closestVictim:IsPlayer() then
				if closestVictim:Alive() then
					self.Victim = closestVictim
				else
					self.Victim = NULL
				end
			else
				if (closestVictim:GetNPCState() != NPC_STATE_DEAD) then
					self.Victim = closestVictim
				else
					self.Victim = NULL
				end
			end
		else
			self.Victim = NULL
		end
	else
		self.Victim = NULL
	end
	
	if self:IsNPC() then
		if (self.Victim and self.Victim:IsValid()) then
			self:SetEnemy(self.Victim)
		end
	end
	
	if self:CanAnyoneSeeUs() then
		self.DeltaTime = COOLDOWN_TIME
		
		self:PlayDead()
		
		if self.Moving then
			self:StopSound(sndMove)
			self.Moving = false
		end
		
		return COOLDOWN_TIME
	else
		local deltaTime
		
		if ((not self:IsNPC()) or self.PathClear) then
			if (THINK_FREQ > 0) then
				deltaTime = 1 / THINK_FREQ
			else
				deltaTime = engine.TickInterval()
			end
			
			self.DeltaTime = deltaTime
			
			self:BeCreepy()
		else
			deltaTime = COOLDOWN_TIME
			self.DeltaTime = COOLDOWN_TIME
			self:PlayDead()
		end
		
		local tracePos = self:LocalToWorld(self:OBBCenter())
		local boundingRad = self:BoundingRadius()
		
		local hullTrace = {
			start = tracePos,
			endpos = tracePos,
			mins = (1.5 * Vector(-boundingRad, -boundingRad, -boundingRad)),
			maxs = (1.5 * Vector(boundingRad, boundingRad, boundingRad)),
			mask = MASK_NPCSOLID,
			filter = self
		}
		
		local traceTab = util.TraceHullEx(hullTrace)
		
		for k, tr in ipairs(traceTab) do
			if (tr.Hit and tr.Entity and tr.Entity:IsValid()) then
				if ((tr.HitPos - tracePos):LengthSqr() <= ((1.5 * boundingRad) ^ 2)) then
					self:OpenDoor(tr.Entity)
				end
			end
		end
		
		if (not self.Moving) then
			self:EmitSound(sndMove, 75, 100, 1, CHAN_BODY)
			self.Moving = true
		end
		
		return deltaTime
	end
end

function ENT:Think()
	if (not self.SCP173_Initialized) then
		self:NextThink(CurTime())
		
		return
	end
	
	if ((not self.SCP173_Coroutine) or (coroutine.status(self.SCP173_Coroutine) == "dead")) then
		self.SCP173_Coroutine = coroutine.create(SCP173_Coroutine)
	end
	
	local hadNoErrors, args = coroutine.resume(self.SCP173_Coroutine, self)
	
	if (not hadNoErrors) then
		SCP173_Error("[ERROR] " .. args)
	end
	
	self:NextThink(CurTime())
end

function ENT:OnRemove()
	self:KillSounds()
	self:StopSound(sndMove)   
end

local function UpdateParams()
	if ConVarExists("scp173_enableThinking") then
		if (GetConVarNumber("scp173_enableThinking") != 0) then
			ENABLE_THINKING = true
		else
			ENABLE_THINKING = false
		end
	end
	
	if ConVarExists("scp173_ignorePlayers") then
		if (GetConVarNumber("scp173_ignorePlayers") != 0) then
			IGNORE_PLAYERS = true
		else
			IGNORE_PLAYERS = false
		end
	end
	
	if ConVarExists("scp173_cooldownTime") then
		COOLDOWN_TIME = GetConVarNumber("scp173_cooldownTime")
	end
	
	if ConVarExists("scp173_thinkDelay") then
		THINK_FREQ = GetConVarNumber("scp173_thinkFreq")
	end
	
	if ConVarExists("scp173_teleportCooldown") then
		TELEPORT_COOLDOWN = GetConVarNumber("scp173_teleportCooldown")
	end
	
	if ConVarExists("scp173_teleportMaxTries") then
		TELEPORT_MAX_TRIES = GetConVarNumber("scp173_teleportMaxTries")
	end
	
	if ConVarExists("scp173_creepProb") then
		CREEP_PROB_RATE = GetConVarNumber("scp173_creepProbRate")
	end
	
	if ConVarExists("scp173_creepCooldown") then
		CREEP_COOLDOWN = GetConVarNumber("scp173_creepCooldown")
	end
	
	if ConVarExists("scp173_creepSpeed") then
		CREEP_SPEED = GetConVarNumber("scp173_creepSpeed")
	end
	
	if ConVarExists("scp173_moveSpeed") then
		MOVE_SPEED = GetConVarNumber("scp173_moveSpeed")
	end
	
	if ConVarExists("scp173_stabMaxDist") then
		STAB_MAX_DIST = GetConVarNumber("scp173_stabMaxDist")
	end
	
	if ConVarExists("scp173_stabProb") then
		STAB_PROB_RATE = GetConVarNumber("scp173_stabProbRate")
	end
	
	if ConVarExists("scp173_stabCooldown") then
		STAB_COOLDOWN = GetConVarNumber("scp173_stabCooldown")
	end
	
	if ConVarExists("scp173_stabForce") then
		STAB_FORCE = GetConVarNumber("scp173_stabForce")
	end
	
	if ConVarExists("scp173_stabDamage") then
		STAB_DAMAGE = GetConVarNumber("scp173_stabDamage")
	end
end

hook.Add("Think", "SCP173_UpdateParams", UpdateParams)
