AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

ENT.Base				= "base_nextbot"
ENT.Spawnable			= true
ENT.AdminOnly			= false
ENT.PrintName		= "SCP 096"
ENT.Author			= "Shaklin"
ENT.Information		= ""

---------------------SOUNDFILES---------------------
ENT.playAlert1 = 0
ENT.playLost1 = 0
ENT.playMusic1 = 0
ENT.playStart1 = 0

ENT.Alert1 = Sound("shaklin/scp/096/alert.mp3")
ENT.Lost1 = Sound("shaklin/scp/096/idle.mp3")
ENT.Music1 = Sound("shaklin/scp/096/chase.wav")
ENT.Start1 = Sound("shaklin/scp/096/start.mp3")

ENT.DoorBreak = Sound("npc/zombie/zombie_pound_door.wav")

ENT.Hit = Sound("shaklin/scp/096/hit.mp3")
ENT.Miss = Sound("npc/zombie/claw_miss1.wav")

ENT.Stucks = 0
---------------------PRECACHE---------------------
function ENT:Precache()
if SERVER then
util.PrecacheModel(self.Model)

util.PrecacheSound(self.Alert1)
util.PrecacheSound(self.Lost1)
util.PrecacheSound(self.Music1)
util.PrecacheSound(self.Start1)

util.PrecacheSound(self.DoorBreak)

util.PrecacheSound(self.Hit)
util.PrecacheSound(self.Miss)

end
end

---------------------MODEL-----------------------------
ENT.Model = "models/shaklin/scp/096/scp_096.mdl"

---------------------SCP 096 SETTINGS---------------------
ENT.Damage = 1000
ENT.health = 5550
ENT.FallDamage = 0
ENT.FlinchSpeed = 110
ENT.Speed = 40
ENT.AttackWaitTime = 0.01
ENT.AttackFinishTime = 0.7
ENT.Count = 0
ENT.CountProp = 0
ENT.StartPos  = 0
ENT.StartPosx = 0

ENT.MusicCount = 0
---------------------ANIM SETTINGS---------------------
//ENT.AttackAnim = (ACT_GESTURE_MELEE_ATTACK_SWING)
//ENT.AttackDoorAnim = "witch_attack_stand"
ENT.FallAnim = (ACT_RUN_CROUCH)
ENT.FlinchAnim = (ACT_GESTURE_MELEE_ATTACK1)
ENT.WalkAnim = (ACT_WALK)
ENT.RunAnim = (ACT_RUN)
--------------------------------------------------------------------------------------------------
----------------------------------------Initialize------------------------------------------------
--------------------------------------------------------------------------------------------------

function ENT:Initialize()

	---------------------SCP096 SETTINGS---------------------
	self.Entity:SetCollisionBounds( Vector(-4,-4,0), Vector(4,4,64) ) -- make sure the zombie doesn't get stuck
	//self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	//self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
	//self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	self:SetModel( "models/shaklin/scp/096/scp_096.mdl" );
	//self:StopParticles()
	
	local model = self:SetModel(self.Model)
	
	self.LoseTargetDist	= 200	-- How far the enemy has to be before we lose them
	self.SearchRadius 	= 2	-- How far to search for enemies
	
	self.loco:SetStepHeight(35)	
	self.loco:SetAcceleration(900)
	self.loco:SetDeceleration(900)
	
	self:SetHealth(self.health)
	
	self:Precache()
	self.LastPos = self:GetPos()
	self.StartPos = self:GetPos()
	self.StartPosx = self:GetAngles()
	self.nextbot = true
	//self.Width = self:BoundingRadius() * 0.5
	//self:StartActivity( ACT_IDLE_STIMULATED )
	self:StartActivity( ACT_IDLE_ANGRY )
	//local SpawnPos = self.Entity:GetPos() 
	//self:SetPos(SpawnPos + Vector(0,0,-100))
	//self:SetAngles(Angle(-1, 0,0))
	self.Width = self:BoundingRadius() * 0.5
	
	self.playLost1 = CreateSound(self.Entity, self.Lost1)
	self.playLost1:Play()
end

function ENT:BehaveAct()

end

function ENT:Think()
self.LastPos = self.Entity:GetPos()
end

function ENT:SetEnemy()
	ent = player.GetAll()[math.random(1,#player.GetAll())]
	self.Enemy = ent
end

function ENT:GetEnemy()
	return self.Enemy
end

function ENT:OnStuck()
	if self.LastPos:Distance( self.Entity:GetPos() ) < 100 then
		self.Entity:SetPos( self.LastPos + Vector(60, 60, 60))
		//print ("stuck")
	end
end

function ENT:OnUnStuck()
end

function ENT:GetDoor(ent)

	local doors = {}
	doors[1] = "models/props_c17/door01_left.mdl"
	doors[2] = "models/props_c17/door02_double.mdl"
	doors[3] = "models/props_c17/door03_left.mdl"
	doors[4] = "models/props_doors/door01_dynamic.mdl"
	doors[5] = "models/props_doors/door03_slotted_left.mdl"
	doors[6] = "models/props_interiors/elevatorshaft_door01a.mdl"
	doors[7] = "models/props_interiors/elevatorshaft_door01b.mdl"
	doors[8] = "models/props_silo/silo_door01_static.mdl"
	doors[9] = "models/props_wasteland/prison_celldoor001b.mdl"
	doors[10] = "models/props_wasteland/prison_celldoor001a.mdl"
	
	doors[11] = "models/props_radiostation/radio_metaldoor01.mdl"
	doors[12] = "models/props_radiostation/radio_metaldoor01a.mdl"
	doors[13] = "models/props_radiostation/radio_metaldoor01b.mdl"
	doors[14] = "models/props_radiostation/radio_metaldoor01c.mdl"
	
	
	for k,v in pairs( doors ) do
		if ent:GetModel() == v and string.find(ent:GetClass(), "door") then
			return "door"
		end
	end
	
end
--------------------------------------------------------------------------------------------------
--------------------------------------------Enemy-------------------------------------------------
--------------------------------------------------------------------------------------------------

function ENT:HaveEnemy()
-- If our current enemy is valid
local st = GetConVarNumber("ai_ignoreplayers")
if st == 0 then
	if ( self:GetEnemy() and IsValid( self:GetEnemy() ) ) then
		if ( self:GetRangeTo( self:GetEnemy():GetPos() ) > self.LoseTargetDist ) then
		self.Count = self.Count -1
		
			return self:FindEnemy()
		elseif ( self:GetEnemy():IsPlayer() and !self:GetEnemy():Alive() ) then
			return self:FindEnemy()
		end	
		//self.loco:FaceTowards( self:GetEnemy():GetPos() )
		//self:SetAngles(self.GetEnemy:Angle())
		return true
	else
		return self:FindEnemy()
	end
end
end

----------------------------------------------------
-- ENT:FindEnemy()
-- Returns true and sets our enemy if ( we find one
----------------------------------------------------

function ENT:FindEnemy()
local st = GetConVarNumber("ai_ignoreplayers")
if st == 0 then
	local _ents = ents.FindInSphere( self:GetPos(), self.SearchRadius )
	for k,v in pairs( _ents ) do
		if ( v:IsPlayer() && v:Health() > 0 ) then
			self:SetEnemy( v )
			return true
		end
	end
-- We found nothing so we will set our enemy as nil ( nothing ) and return false
	self:SetEnemy( nil )
	return false
end
end

----------------------------------------------------
-- ENT:ChaseEnemy()
-- Works similarly to Garry's MoveToPos function
--  except it will constantly follow the
--  position of the enemy until there no longer
--  is an enemy.
----------------------------------------------------

function ENT:ChaseEnemy( options )
	self.Damage = 1000
	local options = options or {}
	local path = Path( "Follow" )
	path:SetMinLookAheadDistance( options.lookahead or 300 )
	path:SetGoalTolerance( options.tolerance or 20 )
	path:Compute( self, self:GetEnemy():GetPos() )
	if (  !path:IsValid() ) then return "failed" end
	while ( path:IsValid() and self:HaveEnemy() ) do

		if ( path:GetAge() > 0.1 ) then	
			path:Compute( self, self:GetEnemy():GetPos() )
		end
		path:Update( self )	
		if ( options.draw ) then path:Draw() end
		if ( self.loco:IsStuck() ) then
			self:HandleStuck()
			return "stuck"
		end

if SERVER then
				//Sound before Attack
	self:stopAlert1()
	self:stopLost1()
		if (self.playMusic1 == 0) then
		
		self.playMusic1 = CreateSound(self.Entity, self.Music1)
		self.playMusic1:Play() 
		self.playStart1 = CreateSound(self.Entity, self.Start1)
		self.playStart1:Play() end
		if self.playMusic1:IsPlaying()  then
		
		else self.playMusic1 = CreateSound(self.Entity, self.Music1)
		self.playMusic1:Play() -- Starts the attack music 
		end
end
		
		//local EnemyP = self:GetEnemy():GetPos()
		//if (self:GetRangeTo(EnemyP) < 95) then
		//self.RunAnim =( ACT_RUN_CROUCH )
		//else
		//self.RunAnim =( ACT_RUN )
		//end
		
		local func_door = ents.FindInSphere(self:GetPos(),40)
		if func_door then
			for i = 1, #func_door do
				local v = func_door[i]
				if v:GetClass() == "func_door" then
				v:Fire("Unlock", "", 0)
				v:Fire("Open", "", 0.01)
				//print ("func_door")
				end
				end
				end
				
		local door = ents.FindInSphere(self:GetPos(),40)
		if door then
			for i = 1, #door do
				local v = door[i]
				if !v:IsPlayer() and v != self and IsValid( v ) then
				
					if self:GetDoor( v ) == "door" then
					
						if v.Hitsleft == nil then
							v.Hitsleft = 10
						end
						
						if v != NULL and v.Hitsleft > 0 then
							if (self:GetRangeTo(v) < 45) then
							
							function BreakSounds()
							if not ( v:IsValid() ) then return end
							v:EmitSound(self.DoorBreak)
							end
							
								timer.Create("Break Sounds", 0.6, 2, BreakSounds ) 
								self.loco:SetDesiredSpeed(0)
								self:StartActivity( ACT_RUN_CROUCH )
								//self:StartActivity(self.AttackAnim)
								if v != NULL and v.Hitsleft != nil then
									if v.Hitsleft > 0 then
									v.Hitsleft = v.Hitsleft - 1
									
									end
								end
							end
						end
						if v != NULL and v.Hitsleft < 1 then
							v:Remove()
							
						local door = ents.Create("prop_physics")
						door:SetModel(v:GetModel())
						door:SetPos(v:GetPos())
						door:SetAngles(v:GetAngles())
						door:Spawn()
						door:EmitSound("Wood_Plank.Break")
						
						local phys = door:GetPhysicsObject()
						if (phys != nil && phys != NULL && phys:IsValid()) then
						phys:ApplyForceCenter(self:GetForward():GetNormalized()*20000 + Vector(0, 0, 2))
						end
						
						door:SetSkin(v:GetSkin())
						door:SetColor(v:GetColor())
						door:SetMaterial(v:GetMaterial())
					end
						/////////
						if self.Count <= 0 then
						self:StartActivity( self.WalkAnim )
						self.loco:SetDesiredSpeed(self.Speed)
						end
		
						if self.Count > 2 then
						self.loco:SetDesiredSpeed( 450 )
						self:StartActivity( self.RunAnim )
						end
						
						end
						end
						end
						end
						
	///////////////
	
	local ent = ents.FindInSphere( self:GetPos(), 55) 
		for k,v in pairs( ent ) do
		
		if ((v:IsNPC() || (v:IsPlayer() && v:Alive() && !self.IgnorePlayer))) then
		if not ( v:IsValid() && v:Health() > 0 ) then return end
		
		//
		self:StartActivity( ACT_RUN_CROUCH )
		//self:AttackAnimation()
		//self:StartActivity(self.AttackAnim)
		coroutine.wait(self.AttackWaitTime)
		self:EmitSound(self.Miss)
		
		if (self:GetRangeTo(v) < 65) then

		if ( v:IsPlayer() && v:Health() > 0 ) then
			self.Damage = 1000
			v:EmitSound(self.Hit)
			v:TakeDamage(self.Damage, self)			
			v:ViewPunch(Angle(math.random(-1, 1)*self.Damage, math.random(-1, 1)*self.Damage, math.random(-1, 1)*self.Damage))
			
			local moveAdd=Vector(0,0,150)
		if not v:IsOnGround() then
		moveAdd=Vector(0,0,0)
		end
		v:SetVelocity(moveAdd+((self.Enemy:GetPos()-self:GetPos()):GetNormal()*100)) -- apply the velocity
		
			end

		if v:IsNPC() then
			v:EmitSound(self.Hit)
			v:TakeDamage(self.Damage, self)	
			end
		

		end
		coroutine.wait(self.AttackFinishTime)	
		self:StartActivity( self.RunAnim )
		self.loco:SetDesiredSpeed( 450 )
		//self:PlayChaseMusic()
		
		///////////////player dead, go back
		if ( v:IsPlayer() && v:Health() <= 0 ) then
		self:stopMusic1()
		//self:StartActivity( self.WalkAnim )
		//self.loco:SetDesiredSpeed(self.Speed)
		self.Enemy = nil
		
		self:StartActivity( ACT_GESTURE_FLINCH_HEAD )
		coroutine.wait( 6.5 )
	
		self:WaitAfterKill()
		self:WaitAfterKill()
		self:WaitAfterKill()
		self:WaitAfterKill()
		self:WaitAfterKill()
		self:WaitAfterKill()
		
		self.Enemy = nil
		self.Count = 0
		self:StartActivity( self.RunAnim )
		self.loco:SetDesiredSpeed(700)
		self:MoveToPos(self.StartPos)
		self:SetAngles(self.StartPosx)
		self:SCP096Reset()
		end
		
		end
		end
		////////////////////
		if (self:GetEnemy() != nil) then
			if (self:GetEnemy():GetPos():Distance(self:GetPos()) < 50 || self:AttackProp()) then
			else
			if (self:GetEnemy():GetPos():Distance(self:GetPos()) < 50 || self:AttackBreakable()) then
			end
			end
		end
		//////////////////
		

		coroutine.yield()
	end
	return "ok"
end

function ENT:WaitAfterKill()
local st = GetConVarNumber("ai_ignoreplayers")
if st == 0 then
if self.Enemy == nil then
	self:StartActivity( ACT_CROUCHIDLE )
	coroutine.wait( 2 )
	end

if self.Enemy != nil then
	self.LoseTargetDist	= 9999999999	-- How far the enemy has to be before we lose them
	self.SearchRadius 	= 9999999999	-- How far to search for enemies
	self.loco:SetDesiredSpeed( 450 )
	self:StartActivity( self.RunAnim )
	self:ChaseEnemy()
	self.CountProp = 0
	self.Enemy = nil
	end
end

if st != 0 then
	self:StartActivity( ACT_CROUCHIDLE )
	coroutine.wait( 2 )
end
end
--------------------------------------------------------------------------------------------------
--------------------------------------------Sounds------------------------------------------------
--------------------------------------------------------------------------------------------------
function ENT:PlayChaseMusic()
if SERVER then

		self.playMusic1 = CreateSound(self.Entity, self.Music1)
		self.playMusic1:Play() -- Starts the attack music
	end
end
	
function ENT:AlertSound()
if self.Count != 99 then
local st = GetConVarNumber("ai_ignoreplayers")
	if st == 0 then
if SERVER then
		//lost sound
		//local ply = self:GetEnemy()	
		if (self.playAlert1 == 0) then
		
		self.playAlert1 = CreateSound(self.Entity, self.Alert1)
		self.playAlert1:Play() end
		if self.playAlert1:IsPlaying()  then
		
		else self.playAlert1 = CreateSound(self.Entity, self.Alert1)
		self.playAlert1:Play()
		end
	end
end
end
end

function ENT:LostSound()
//local st = GetConVarNumber("ai_ignoreplayers")
	//if st == 0 then
if SERVER then
		//lost sound
		self.MusicCount = self.MusicCount +1
		//print( "+1" )
		if self.MusicCount >= 7 then 
		//print( "7" )
		self.MusicCount = 0
		if self.playLost1:IsPlaying()  then
		self.playLost1:Stop()
		self.playLost1 = CreateSound(self.Entity, self.Lost1)
		self.playLost1:Play()
		else
		self.playLost1 = CreateSound(self.Entity, self.Lost1)
		self.playLost1:Play()
		end
	end
end
end

function ENT:LostSound2()
local st = GetConVarNumber("ai_ignoreplayers")
	if st == 0 then
if SERVER then
		//lost sound
		if (self.playLost1 == 0) then
		
		self.playLost1 = CreateSound(self.Entity, self.Lost1)
		self.playLost1:Play() end
		if self.playLost1:IsPlaying()  then
		
		else self.playLost1 = CreateSound(self.Entity, self.Lost1)
		self.playLost1:Play()
		end
	end
end
end


--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
----------------------------------RunBehaviour----------------------------------------------------
--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------

function ENT:RunBehaviour()
-- Here is the loop, it will run forever
	while ( true ) do
	self:FindEnemy()
		if ( self:HaveEnemy() && self.Count > 2 or self:SeeMe() or self:SeeMe2() ) then
		
			//self.loco:FaceTowards( self:GetEnemy():GetPos() )	-- Face our enemy
			//self:SetAngles(self.Enemy:Angle())
			//ent:SetAngles(Angle(0, Enemy:EyeAngles().yaw+180, 0))
			//self:AlertSound()
			
			self:warnplayer()
			//coroutine.wait( 1 )
			
			if self.Count > 2 then --How many times before angry
			self.LoseTargetDist	= 9999999999	-- How far the enemy has to be before we lose them
			self.SearchRadius 	= 9999999999	-- How far to search for enemies
			self.loco:SetDesiredSpeed( 450 )
			self:StartActivity( self.RunAnim )
			self:ChaseEnemy()
			self.CountProp = 0
			end
			
			
			
		else
		
		self:playernear()
		self:GoHome()
			-- Sit around
			//self:SetEyeAngles(Angle(0, self:EyeAngles().yaw+180, 0));
			
			self:SCP096Reset()
			self:stopMusic1() -- stops the music
			self:stopAlert1()
			//self:stopLost1()
			//self:StartActivity( ACT_WALK )
			//self.loco:SetDesiredSpeed( self.Speed )
			// Sit idle animation
			local idletype
			idletyp = (math.random(0,4))
			if idletyp == 0 then
			self:StartActivity( ACT_COWER )
			coroutine.wait( 6 )
			else self:StartActivity( ACT_CROUCHIDLE )
			coroutine.wait( 2 )
			end
			
		end
		
		coroutine.wait( 2 )
	end
end	

--------------------------------------------------------------------------------------------------
---------------------------------------------AI---------------------------------------------------
--------------------------------------------------------------------------------------------------

function ENT:MoveToPos( pos, options )
	local options = options or {}

	local path = Path( "Follow" )
	path:SetMinLookAheadDistance( options.lookahead or 300 )
	path:SetGoalTolerance( options.tolerance or 20 )
	path:Compute( self, pos )

	if ( !path:IsValid() ) then return "failed" end

	while ( path:IsValid() ) do

		path:Update( self )
		local st = GetConVarNumber("ai_ignoreplayers")
		if st == 0 && self.Count <= 0 then
		local _ents = ents.FindInSphere( self:GetPos(), 20 )
		for k,v in pairs( _ents ) do
		if ( v:IsPlayer() && v:Alive() ) then
			coroutine.yield()
			return "ok"
		end
		end
		end
		
		-- Draw the path (only visible on listen servers or single player)
		if ( options.draw ) then
			path:Draw()
		end

		-- If we're stuck then call the HandleStuck function and abandon
		if ( self.loco:IsStuck() ) then

			self:HandleStuck();
			
			return "stuck"

		end

		--
		-- If they set maxage on options then make sure the path is younger than it
		--
		if ( options.maxage ) then
			if ( path:GetAge() > options.maxage ) then return "timeout" end
		end

		--
		-- If they set repath then rebuild the path every x seconds
		--
		if ( options.repath ) then
			if ( path:GetAge() > options.repath ) then path:Compute( self, pos ) end
		end
		
		if self.Count == 99 then
		return "ok"
		end
		
		coroutine.yield()

	end

	return "ok"
	
end

function ENT:playernear()

	if self.Count <= 0 then
	local _ents = ents.FindInSphere( self:GetPos(), 500 )
	for k,v in pairs( _ents ) do
		if ( v:IsPlayer() && v:Alive() ) then
		//local headpos = v:GetBonePosition( v:LookupBone( "ValveBiped.Bip01_Head1" ) )
		//self:SetEyeTarget( headpos )
		//self:SetEyeTarget( v:EyePos() )
		
			if SERVER then
				self:LostSound()
		end
		
		end
		end
end
end
///////////////////////////////

function ENT:SeeMe()
local st = GetConVarNumber("ai_ignoreplayers")
	if st == 0 && self.Count <= 0 then
local ok1 = 0
local ok2 = 0
local _ents = ents.FindInSphere( self:GetPos(), 100 )
	for k,v in pairs( _ents ) do
		if ( v:IsPlayer() && v:Alive() ) then
		//self:SetEyeTarget( v:EyePos() )
		//print( self:EyePos()) 
local tr = util.TraceLine( {
	start = self:EyePos(), 
	endpos = self:EyePos() + self:EyeAngles():Forward() * 10000,
	filter = function( ent )
	if ( ent:IsPlayer() && ent:Alive() && ent:EyeAngles():Forward() ) then
	ok1 = 1
	//print( "ok1 i see a player" )
	return true
	else
	//print( "false1" )
	return false
	end
	end
} )


if ( IsValid( tr.Entity ) )then 
//print( "valid" )
local tr2 = util.TraceLine( {
	start = v:EyePos(), 
	endpos = v:EyePos() + v:EyeAngles():Forward() * 10000, 
	filter = function( ent2 )
	if ent2 == self then
	ok2 = 1
	//print( "ok2 player can see me" )
	return true
	else
	//print( "false2" )
	return false
	end
	end
} )

end
if ok1 == 1 && ok2 == 1 then
self.Enemy = v
//print ("successful")
return true
else
//print( "fail" )
return false
end

end
end

end
end

function ENT:SeeMe2()
local st = GetConVarNumber("ai_ignoreplayers")
	if st == 0 && self.Count <= 0 then
local _ents = ents.FindInSphere( self:GetPos(), 100 )
	for k,v in pairs( _ents ) do
		if ( v:IsPlayer() && v:Alive() ) then
local tr = util.TraceLine( util.GetPlayerTrace( v ) )
local target = tr.Entity
local targetb = tr.HitBox
if target == self && targetb == 0 then
if ( IsValid( tr.Entity ) )then 
self.Enemy = v
//print( "I saw a "..tr.Entity:GetModel() )
return true
end
end
//print( "I saw a nix" )
return false
end
end
end
end

function ENT:warnplayer()

///////////////////////
		if SERVER then
		if self.Count != 99 then
		self:stopLost1()
		self:AlertSound()
		end
	end
		////////////////////

local st = GetConVarNumber("ai_ignoreplayers")
if st == 0 then
	if self.Count == 0 then
	local immun = self.Health
	self:SetHealth(99999999)
	//local SpawnPos = self.Entity:GetPos() 
	//self:SetPos(SpawnPos + Vector(0,0,-10))
	//self:SetAngles(Angle(-1, 0,0))
	//self:StartActivity( ACT_IDLE_STIMULATED )
	//coroutine.wait( 11 )
	self:crazyAnimStand()
	self:crazyAnimStart()
	self:crazyAnim()
	self:crazyAnim()
	self:crazyAnim()
	self:crazyAnim()
	self:crazyAnim()
	self:crazyAnim()
	self:crazyAnim()
	self:crazyAnim()
	self:crazyAnim()
	self:crazyAnim()
	self:StartActivity( ACT_IDLETORUN )
	self.Count = self.Count +3
	self.Health = immun
	self:SetHealth(self.health)
	self.Count = 99
	end
	

end



end


function ENT:GoHome()
	if self.StartPos:Distance( self.Entity:GetPos() ) > 100 then
		self:StartActivity( self.RunAnim )
		self.loco:SetDesiredSpeed(700)
		self:MoveToPos(self.StartPos)
		self:SetAngles(self.StartPosx)
		self.Stucks = self.Stucks +1
		if self.Stucks > 5 then
		//print ("help")
		self:SetPos(self.StartPos)
		self:SetAngles(self.StartPosx)
		self.Stucks = 0
		end
	end
end



function ENT:beattacked()
		self.LoseTargetDist	= 9999999999	-- How far the enemy has to be before we lose them
		self.SearchRadius 	= 9999999999	-- How far to search for enemies
		self.Count = 99
end

function ENT:AttackProp()
	local entstoattack = ents.FindInSphere(self:GetPos(), 55)
	for _,v in pairs(entstoattack) do
	
		if (v:GetClass() == "prop_physics" && self.CountProp < 6) then
		self.CountProp = self.CountProp + 1
		if SERVER then
		self:EmitSound(self.Hit)
		end
		self:StartActivity( ACT_RUN_CROUCH )
		//self:AttackPropAnimation()
		//self:StartActivity(self.AttackAnim)
		coroutine.wait(self.AttackWaitTime)
		self:EmitSound(self.Miss)
		
		if not ( v:IsValid() ) then return end
		if (self:GetRangeTo(v) < 60) then
		if not ( v:IsValid() ) then return end
		
		if not ( v:IsValid() ) then return end
		local phys = v:GetPhysicsObject()
			if (phys != nil && phys != NULL && phys:IsValid()) then
			phys:ApplyForceCenter(self:GetForward():GetNormalized()*30000 + Vector(0, 0, 2))
			v:EmitSound(self.DoorBreak)
			v:TakeDamage(self.Damage, self)	
			end
			
		end
		coroutine.wait(self.AttackFinishTime)	
		if self.Count <= 0 then
		self:StartActivity( self.WalkAnim )
		end
		
		if self.Count > 2 then
		self.loco:SetDesiredSpeed( 450 )
		self:StartActivity( self.RunAnim )
		end
			return true
		end
	end
	return false
end

function ENT:AttackBreakable()
	local entstoattack = ents.FindInSphere(self:GetPos(), 55)
	for _,v in pairs(entstoattack) do
	
		if (v:GetClass() == "func_breakable") then
		
		if SERVER then
		self:EmitSound(self.Hit)
		end
	self:StartActivity( ACT_RUN_CROUCH )
	//self:AttackPropAnimation()
	//self:StartActivity(self.AttackAnim)
		
		coroutine.wait(self.AttackWaitTime)
		self:EmitSound(self.Miss)
		
		if not ( v:IsValid() ) then return end
			v:EmitSound(self.DoorBreak)
			v:TakeDamage(self.Damage, self)	
			
		coroutine.wait(self.AttackFinishTime)	
		self:StartActivity( self.WalkAnim )
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------------------------
-------------------------------------ANIMATIONS---------------------------------------------------
--------------------------------------------------------------------------------------------------
function ENT:crazyAnimStand()
if self.Count == 99 then
self:stopAlert1()
else
 self:StartActivity( ACT_IDLE_RELAXED )
 coroutine.wait( 8 )
end
end

function ENT:crazyAnimStart()
if self.Count == 99 then
self:stopAlert1()
else
 self:StartActivity( ACT_IDLE_AGITATED )
 coroutine.wait( 3 )
end
end

function ENT:crazyAnim()
if self.Count == 99 then
self:stopAlert1()
else
 self:StartActivity( ACT_IDLE_ANGRY )
 coroutine.wait( 2 )
end
end
--------------------------------------------------------------------------------------------------
------------------------------------ON-KILLED-OR-REMOVE---------------------------------------------
--------------------------------------------------------------------------------------------------

function ENT:OnRemove()
if SERVER then
self:stopMusic1()
	self:stopAlert1()
	self:stopLost1()
end
end

function ENT:OnLeaveGround() 
self:StartActivity(self.FallAnim)
if self.Count > 2 then
self.loco:SetDesiredSpeed( 450 )
self:StartActivity( self.RunAnim )
end
end

function ENT:OnLandOnGround() 
self:StartActivity( self.WalkAnim )
if self.Count > 2 then
self.loco:SetDesiredSpeed( 450 )
self:StartActivity( self.RunAnim )
end
end

if SERVER then
function ENT:OnKilled( dmginfo )
	
	self:stopMusic1()
	self:stopAlert1()
	self:stopLost1()
	self:BecomeRagdoll( dmginfo )
	
end

function ENT:OnInjured( dmginfo )
//if self:Health() < 139 then
//self.Health = 99999999999
//self:StartActivity( ACT_DYINGTODEAD )
//self.Health = 0
//end

local st = GetConVarNumber("ai_ignoreplayers")
if st == 0 then

	self:beattacked()
	local ent = dmginfo:GetAttacker()
	if IsValid(ent) then self.Enemy = ent end
	end
	
	if st == 1 then
	
	//
	end
	end
	end
	
function ENT:OnOtherKilled()
//for _,v in pairs ( player.GetAll()) do v:SendLua([[RunConsoleCommand("stopsound")]]) end
if SERVER then
self:stopMusic1()
	self:stopAlert1()
	self:stopLost1()
end
end

--------------------------------------------------------------------------------------------------
-----------------------------------------OTHER----------------------------------------------------
--------------------------------------------------------------------------------------------------

function ENT:stopMusic1()
//playMusic1:FadeOut(10)
if (self.playMusic1 != 0) then
self.playMusic1:Stop() -- stops the sound
self.playStart1:Stop()
end
end

function ENT:stopLost1()
//playMusic1:FadeOut(10)
if (self.playLost1 != 0) then
self.playLost1:Stop() -- stops the sound
end
end

function ENT:stopAlert1()
//playMusic1:FadeOut(10)
if (self.playAlert1 != 0) then
self.playAlert1:Stop() -- stops the sound
end
end

function ENT:SCP096Reset()
self.Count = 0
self.Enemy = nil
self.LoseTargetDist	= 200
self.SearchRadius 	= 2
end


--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------