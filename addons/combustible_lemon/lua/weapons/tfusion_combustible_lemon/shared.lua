--///// ==============================  SWEP Description  ==============================/////--

--// Spawnmenu properties
SWEP.PrintName 				= "Combustible Lemon"
SWEP.Category 				= "Aperture Laboratories"
SWEP.Author 				= "TiberiumFusion"
SWEP.Contact 				= ""
SWEP.Purpose 				= "For burning down houses."
SWEP.Instructions 			= "Left-click and release to throw a Combustible Lemon™ with a 3 second fuse. Hold left-click to cook the Combustible Lemon™. Right-click to throw a Combustible Lemon™ that will detonate on impact. Reload to rant about lemons."
SWEP.Spawnable 				= true
SWEP.AdminOnly 				= false
SWEP.IconOverride			= "materials/vgui/tfusion/dumbthings/combustible_lemon_swep/spawnmenu_icon.png"

--// Weapon slot properties
SWEP.Slot					= 4
SWEP.SlotPos				= 5
SWEP.Weight					= 100
SWEP.DrawWeaponInfoBox		= true
SWEP.BounceWeaponIcon 		= false
SWEP.AutoSwitchTo 			= true
SWEP.AutoSwitchFrom 		= true
if CLIENT then
	SWEP.WepSelectIcon		= surface.GetTextureID("vgui/tfusion/dumbthings/combustible_lemon_swep/hotbar_icon")
end

--// Appearance
SWEP.WorldModel 			= "models/weapons/tfusion/dumbthings/combustible_lemon_swep_w.mdl"
SWEP.ViewModel 				= "models/weapons/tfusion/dumbthings/combustible_lemon_swep_v.mdl"
SWEP.ViewModelFOV 			= 65
SWEP.UseHands 				= true
SWEP._HoldTypeIdle			= "slam"
SWEP._HoldTypeAttack		= "grenade"

SWEP.DrawCrosshair 			= true
SWEP.DrawAmmo 				= true
SWEP.BobScale				= 1
SWEP.SwayScale				= 0.5

--// Ammo setup
SWEP.Primary.ClipSize		= 1
SWEP.Primary.DefaultClip	= 1
SWEP.Primary.Automatic 		= false
SWEP.Primary.Ammo			= "tfusion_combustible_lemon"
 
SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic 	= false
SWEP.Secondary.Ammo			= "none"

SWEP._AllowEmptyAmmo 		= false -- If true, we WONT strip the weapon once all ammo runs out
SWEP._ThrowPower			= 3700 -- Physics force to apply to thrown projectiles
SWEP._FuseTime				= 3 -- How long the fuse lasts, in seconds


--///// ==============================  Main SWEP Functionality  ==============================/////--

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Float", 0, "StateEntryTime")
	self:NetworkVar("Int", 1, "NextState")
	self:NetworkVar("Float", 1, "NextStateTime")
	
	self:NetworkVar("Int", 2, "NextVmSeqActId")
	self:NetworkVar("Float", 2, "NextVmSeqTime")
	
	self:NetworkVar("Int", 3, "NextHoldType")
	self:NetworkVar("Float", 3, "NextHoldTypeTime")
end


function SWEP:FullReset()
	self:SetState(-1)
	self:SetStateEntryTime(CurTime())
	self:SetNextState(0)
	self:SetNextStateTime(-1)
	
	self:SetNextVmSeqTime(-1)
	self:SetNextVmSeqActId(-1)
	
	self:SetNextHoldTypeTime(-1)
	self:SetNextHoldType(-1)
	
	self:SetHoldType(self._HoldTypeIdle)
	
	if SERVER then
		self:SetMaxHealth(5)
		self:SetHealth(5)
	end
	
	self._FuseStartTime = nil
	self._FuseDuration = nil
	self._NextThrowDetonateOnImpact = nil
	self._NextThrowFuseTime = nil
end

function SWEP:Initialize()
	self:FullReset()
	
	--// Manually call these hooks clientside because they don't happen automatically on weapon pickup
	--// Note that this just calls the Lua side of things. Anything C++ side in Equip() or Deploy() wont happen.
	if CLIENT then
		if (IsValid(self:GetOwner()) == true) then
			self:Equip(self:GetOwner())
			self:Deploy()
		end
	end
end


function SWEP:OnRemove()
	
end



function SWEP:Equip(owner)
	self:FullReset()
end

function SWEP:Deploy()
	self:FullReset()
	
	self:ChangeState(0)
	
	local owner = self:GetOwner()
	if (IsValid(owner)) then
		local vm = owner:GetViewModel()
		if (IsValid(vm)) then
			
			--// Available ammo determines what anim plays and what state we go to
			if (self:HasAmmo()) then
				if (self:Clip1() == 0) then -- needs to reload
					self:DefaultReload(ACT_VM_DRAW)
					self:SendWeaponAnim(ACT_VM_DRAW)
				else -- dont need to reload
					self:SendWeaponAnim(ACT_VM_DRAW)
				end
				
				local animTime = vm:SequenceDuration() / vm:GetPlaybackRate()
				self:SetNextPrimaryFire(CurTime() + animTime)
				self:SetNextVmSeqActId(ACT_VM_IDLE)
				self:SetNextVmSeqTime(CurTime() + animTime)
				
				self:QueueState(1, CurTime() + animTime)
			else
				self:SendWeaponAnim(ACT_VM_IDLE_EMPTY)
				local animTime = vm:SequenceDuration() / vm:GetPlaybackRate()
				self:QueueState(6, CurTime() + animTime)
			end
			
		end
	end
	
	return true
end


function SWEP:Holster()
	if (IsValid(self) == false) then return end
	
	local state = self:GetState()
	if (state == 2) then -- dont allow holster while cooking grenades
		return false
	else
		return true
	end
end



function SWEP:PrimaryAttack()
	self._NextThrowDetonateOnImpact = false
	self._NextThrowFuseTime = self._FuseTime
	self:TryThrow()
end

function SWEP:SecondaryAttack()
	self._NextThrowDetonateOnImpact = true
	self._NextThrowFuseTime = self._FuseTime
	self:TryThrow()
end

function SWEP:TryThrow()
	local state = self:GetState()
	if (state == 1) then-- only allow attack during idle state
		
		local owner = self:GetOwner()
		if (IsValid(owner) and owner:Alive() and owner:IsNPC() == false) then
			
			if (self:Clip1() > 0) then
				self:SetHoldType(self._HoldTypeAttack)
				
				--// Left mouse can be held down to cook the grenade. Releasing left click throws it. Think() handles all of that.
				self:ChangeState(2)
				
				--// Play pull pin animation
				self:SendWeaponAnim(ACT_VM_PULLPIN)
				self:SetNextPrimaryFire(CurTime() + 999) -- prevent more PrimaryAttack() calls while we are still processing this attack
				
				--// Start fuse timer
				if (self._NextThrowFuseTime >= 0) then
					self._FuseStartTime = CurTime()
					self._FuseDuration = self._NextThrowFuseTime
					local vm = owner:GetViewModel()
					if (IsValid(vm)) then
						self._FuseDuration = self._FuseDuration + ((vm:SequenceDuration() / vm:GetPlaybackRate()) * 0.2)
					end
				end
			end
			
		end
		
	end
end


function SWEP:ShootEffects()
	
end


function SWEP:Reload()
	
end



function SWEP:ChangeState(state)
	self:SetState(state)
	self:SetStateEntryTime(CurTime())
end

function SWEP:QueueState(state, stateTime)
	self:SetNextState(state)
	self:SetNextStateTime(stateTime)
end


function SWEP:Think()
	if (IsValid(self) == false) then return end
	
	local owner = self:GetOwner()
	if (IsValid(owner) == false) then return end
	
	--// Update queued states
	local nextStateTime = self:GetNextStateTime()
	if (nextStateTime >= 0 and CurTime() >= nextStateTime) then
		self:ChangeState(self:GetNextState())
		self:SetNextStateTime(-1)
	end
	
	--// Update queued sequences
	local vm = owner:GetViewModel()
	if (IsValid(vm)) then
		local nextVmSeqTime = self:GetNextVmSeqTime()
		if (nextVmSeqTime >= 0 and CurTime() >= nextVmSeqTime) then
			self:SendWeaponAnim(self:GetNextVmSeqActId())
			self:SetNextVmSeqTime(-1)
		end
	end
	
	--// Cave Johnson lemons VO
	if CLIENT then
		if (owner:KeyDown(IN_RELOAD) == false and owner:KeyDownLast(IN_RELOAD) == true) then
			local allowVo = true
			local allowVoCvar = GetConVar("CombustibleLemonSwep_AllowCaveJohnsonVO")
			if (allowVoCvar ~= nil) then
				if (allowVoCvar:GetInt() == 0) then allowVo = false end
			end
			if (allowVo) then
				hook.Run("CombustibleLemonSWEP_StartCaveJohnsonVO", owner)
			end
		end
	end
	
	--// Update per state
	local state = self:GetState()
	local stateEntryTime = self:GetStateEntryTime()
	local stateDuration = CurTime() - stateEntryTime
	
	if (state == 0) then -- Deploying
		
		self:SetHoldType(self._HoldTypeIdle)
		
		
	elseif (state == 1) then -- Idle
		
		self:SetHoldType(self._HoldTypeIdle)
		
		
	elseif (state == 2) then -- Pin pulled, cooking
		
		self:SetHoldType(self._HoldTypeAttack)
		
		self:SetNextPrimaryFire(CurTime() + 999) -- prevent more PrimaryAttack() calls while we are still processing this attack
		
		--// Wait until the pin pull anim is (mostly) complete before allowing the grenade to be released and thrown
		local pinpullAnimDur = vm:SequenceDuration() / vm:GetPlaybackRate()
		if (stateDuration > pinpullAnimDur * 0.75) then
			if (owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2)) then -- holding down attack key
				
				--// If the grenade has a fuse, cook it
				if SERVER then
					if (self._NextThrowFuseTime >= 0) then
						if (CurTime() >= self._FuseStartTime + self._FuseDuration) then
							--// Blow up in the player's hand
							self._NextThrowFuseTime = -1
							
							self:TakePrimaryAmmo(1)
							
							local proj = ents.Create("tfusion_combustible_lemon_projectile")
							if (IsValid(proj) == false) then return end -- this shouldn't happen, but just in case
							
							--// If the player is close to the ground, move the explosion down a bit to make it look better
							local pos = owner:GetShootPos()
							local tr = util.TraceLine({
								start = pos,
								endpos = pos + Vector(0, 0, -100),
								filter = { self, owner },
								mask = MASK_SOLID,
							})
							if (tr.Hit) then
								pos = LerpVector(0.5, pos, tr.HitPos)
							end
							
							proj:SetPos(pos)
							proj:SetAngles(owner:EyeAngles())
							proj._ThrownByPlayer = owner
							proj._FuseEndTime = CurTime()
							proj:Spawn()
							
							--// Soften up the player so that the blast damage should kill them
							--owner:TakeDamage(proj._InitialBlastDamageAmount * 1, owner, owner)
							
							--// To reload state
							self:ChangeState(6)
						end
					end
				end
				
			else -- left & right mouse released
				
				--// Release the grenade
				self:TakePrimaryAmmo(1)
				
				self:ChangeState(3)
				
				--// Play throw animation
				self:SendWeaponAnim(ACT_VM_THROW)
				owner:SetAnimation(PLAYER_ATTACK1)
				
				--// Queue initiate reload / empty idle
				local throwAnimDur = vm:SequenceDuration() / vm:GetPlaybackRate()
				if (self:Ammo1() > 0) then
					self:QueueState(4, CurTime() + throwAnimDur)
				else
					self:SetNextVmSeqActId(ACT_VM_IDLE_EMPTY)
					self:SetNextVmSeqTime(CurTime() + throwAnimDur)
					self:QueueState(6, CurTime() + throwAnimDur)
				end
				
				--// Queue thrown projectile spawn
				if SERVER then
					local wep = self
					local wepOwner = wep:GetOwner()
					timer.Simple(throwAnimDur * 0.15, function()
						--// Setup desired projectile initial pos
						eyeAngles = wepOwner:EyeAngles()
						local forward = eyeAngles:Forward()
						local right = eyeAngles:Right()
						local up = eyeAngles:Up()
						local shootPos = owner:GetShootPos()
						local idealPos = shootPos + (right * 4) + (up * 0.6)
						
						--// Trace from the player's shoot pos to the desired pos so we dont throw grenades through solid things like ceiling or walls
						local radius = 2
						local tr = util.TraceHull({
							start = shootPos,
							endpos = idealPos,
							mins = Vector(-radius, -radius, -radius),
							maxs = Vector(radius, radius, radius),
							filter = { wep, wepOwner },
							mask = MASK_SOLID,
						})
						local finalPos = idealPos
						if (tr.Hit) then
							finalPos = LerpVector(tr.Fraction, shootPos, idealPos)
						end
						
						local proj = ents.Create("tfusion_combustible_lemon_projectile")
						if (IsValid(proj) == false) then return end -- this shouldn't happen, but just in case
						
						proj:SetPos(finalPos)
						proj:SetAngles(eyeAngles + Angle(0, 0, math.Rand(-90, -30)))
						proj._ThrownByPlayer = wepOwner
						proj._DetonateOnImpact = wep._NextThrowDetonateOnImpact
						if (wep._NextThrowFuseTime >= 0) then -- grenade has a fuse
							local remainingFuse = math.max(0, (wep._FuseStartTime + wep._FuseDuration) - CurTime())
							proj._FuseEndTime = CurTime() + remainingFuse
						end
						
						proj:Spawn()
						
						local phys = proj:GetPhysicsObject()
						if (IsValid(phys) == false) then return end -- sanity
						
						local aim = owner:GetAimVector()
						local worldUp = Vector(0, 0, 1)
						local upDownFactor = math.abs(aim:Dot(worldUp))
						local hopUp = Vector(0, 0, 0.1) * (1 - upDownFactor)
						local inaccuracy = (worldUp * math.Rand(-0.0075, 0.0075)) + (right * math.Rand(-0.0075, 0.0075))
						local finalAim = aim + hopUp + inaccuracy
						finalAim:Normalize()
						phys:ApplyForceCenter(finalAim * wep._ThrowPower * math.Rand(0.9, 1.05))
						phys:SetAngleVelocity(((up * math.Rand(-5, 5)) + (right * -1 * math.Rand(3, 9)) + (forward * 1 * math.Rand(4, 10))) * math.Rand(40, 65))
					end)
				end
				
			end
		end
		
		
	elseif (state == 3) then -- Throwing grenade
		
		self:SetHoldType(self._HoldTypeAttack)
		
	
	elseif (state == 4) then -- Initiate reload
		
		self:SetHoldType(self._HoldTypeIdle)
		
		--// Play draw animation
		self:SendWeaponAnim(ACT_VM_DRAW)
		
		--// Queue return to idle
		local drawAnimDur = vm:SequenceDuration() / vm:GetPlaybackRate()
		self:QueueState(1, CurTime() + drawAnimDur)
		
		--// Do the reload
		self:DefaultReload(ACT_VM_DRAW)
		self:ChangeState(5)
		self:SetStateEntryTime(CurTime())
		
		
	elseif (state == 5) then -- Reloading
		
		self:SetHoldType(self._HoldTypeIdle)
		
		
	elseif (state == 6) then -- Empty idle
		
		self:SetHoldType(self._HoldTypeIdle)
		
		--// Remove weapon if out of ammo
		if SERVER then
			if (self:Clip1() == 0 and self:Ammo1() == 0 and owner:GetAmmoCount(self:GetPrimaryAmmoType()) == 0 and self._AllowEmptyAmmo == false) then
				owner:StripWeapon(self.ClassName)
				return
			end
		end
		
		--// Switch to initiate reload if we acquire ammo
		if (self:Ammo1() > 0) then
			self:ChangeState(4)
		end
		
		
	end
	
end


function SWEP:GetCapabilities()
	return 0
end
