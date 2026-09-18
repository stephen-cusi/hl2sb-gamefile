//********************************//
//     		(c) McKay        	  //   Do NOT redistribute!
//********************************//

-- ! All textures and sounds are (c) 2012 Mojang !



//********************************//
//     Shared Helper Functions    //
//********************************//

function GetCSConVarF( convarname, ply)
	if ( ply == nil || ply == NULL ) then
		if ( game.SinglePlayer() ) then
			return ( GetConVar(convarname):GetFloat() )
		else
			print("Minecraft SWEP: GetCSConVarF() ply is nil!!!")
			return 0
		end
	end
	if (SERVER) then
		return ( tonumber( ply:GetInfo(convarname)) )
	else
		return ( GetConVar(convarname):GetFloat() )
	end
end

function GetCSConVarB( convarname, ply)
	if ( ply == nil || ply == NULL ) then
		if ( game.SinglePlayer() ) then
			return ( GetConVar(convarname):GetFloat() == 1 )
		else
			print("Minecraft SWEP: GetCSConVarB() ply is nil!!!")
			return false
		end
	end
	if (SERVER) then
		return ( tonumber( ply:GetInfo(convarname)) == 1 )
	else
		return ( GetConVar(convarname):GetFloat() == 1 )
	end
end

function GetCSConVarI( convarname, ply)
	if ( ply == nil || ply == NULL ) then
		if ( game.SinglePlayer() ) then
			return ( GetConVar(convarname):GetInt() )
		else
			print("Minecraft SWEP: GetCSConVarI() ply is nil!!!")
			return 0
		end
	end
	if (SERVER) then
		return ( tonumber( ply:GetInfo(convarname)) )
	else
		return ( GetConVar(convarname):GetInt() )
	end
end

function ClDebugEnabled()
	if (CLIENT) then
		return true
	else
		return false
	end
end
function SvDebugEnabled()
	if (SERVER) then
		return true
	else
		return false
	end
end



//********************************//
//     Client/Server SWEP init    //
//********************************//

//TODO: make better worldmodel

if ( CLIENT ) then
	SWEP.PrintName			= "Minecraft SWEP"
	SWEP.Slot				= 3
	SWEP.SlotPos			= 1
	SWEP.Author				= "McKay + Dj Lukis.LT"
	SWEP.WepSelectIcon		= surface.GetTextureID("VGUI/entities/minecraft_swep")
	SWEP.BounceWeaponIcon	= true
	SWEP.DrawAmmo			= false
	SWEP.DrawCrosshair		= true
end

if (SERVER) then
	SWEP.Weight			= 5
	SWEP.AutoSwitchTo	= false
	SWEP.AutoSwitchFrom	= false
	SWEP.updateViewmodel = false;
end

SWEP.Category		= "Minecraft"
SWEP.Contact		= ""
SWEP.Purpose		= "Sandboxception - we need to go deeper"
SWEP.Instructions	= "Right-click to place a block, left click to destroy a block, press R to open the menu!"
SWEP.ViewModel		= "models/MCModelPack/blocks/dirt.mdl"
SWEP.HoldType		= "Pistol"
SWEP.AdminSpawnable	= true
SWEP.Spawnable		= true

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "none"
SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"
SWEP.base					= "weapon_base"
SWEP.Precache				= 1

SWEP.WorldModel		= "models/MCModelPack/blocks/dirt.mdl" //needs a valid model here, else DrawWorldModel() isn't called



//********************************//
//   	 Precache all sounds      //
//********************************//

function SWEP:Precache()
	util.PrecacheSound("minecraft/concrete_impact_hard3.wav")
	util.PrecacheSound("minecraft/concrete_impact_hard2.wav")
	util.PrecacheSound("minecraft/concrete_impact_hard1.wav")
	util.PrecacheSound("minecraft/block_break.wav")
	
	util.PrecacheSound("minecraft/cloth1.wav")
	util.PrecacheSound("minecraft/cloth2.wav")
	util.PrecacheSound("minecraft/cloth3.wav")
	util.PrecacheSound("minecraft/cloth4.wav")
	
	util.PrecacheSound("minecraft/door_open.wav")
	util.PrecacheSound("minecraft/door_close.wav")
	
	util.PrecacheSound("minecraft/click.wav")
	
	util.PrecacheSound("minecraft/glass_1.wav")
	util.PrecacheSound("minecraft/glass_2.wav")
	util.PrecacheSound("minecraft/glass_3.wav")
	
	util.PrecacheSound("minecraft/grass1.wav")
	util.PrecacheSound("minecraft/grass2.wav")
	util.PrecacheSound("minecraft/grass3.wav")
	util.PrecacheSound("minecraft/grass4.wav")
	
	util.PrecacheSound("minecraft/gravel1.wav")
	util.PrecacheSound("minecraft/gravel2.wav")
	util.PrecacheSound("minecraft/gravel3.wav")
	util.PrecacheSound("minecraft/gravel4.wav")
	
	util.PrecacheSound("minecraft/sand1.wav")
	util.PrecacheSound("minecraft/sand2.wav")
	util.PrecacheSound("minecraft/sand3.wav")
	util.PrecacheSound("minecraft/sand4.wav")
	
	util.PrecacheSound("minecraft/snow1.wav")
	util.PrecacheSound("minecraft/snow2.wav")
	util.PrecacheSound("minecraft/snow3.wav")
	util.PrecacheSound("minecraft/snow4.wav")
	
	util.PrecacheSound("minecraft/stone1.wav")
	util.PrecacheSound("minecraft/stone2.wav")
	util.PrecacheSound("minecraft/stone3.wav")
	util.PrecacheSound("minecraft/stone4.wav")
	
	util.PrecacheSound("minecraft/wood1.wav")
	util.PrecacheSound("minecraft/wood2.wav")
	util.PrecacheSound("minecraft/wood3.wav")
	util.PrecacheSound("minecraft/wood4.wav")
	return true  
end

	
//****************************************//
//   Viewmodel Animation (client only)    //
//****************************************//

//TODO: use hardcoded values somehow?! calling GetConVar every frame is probably very expensive!
//TODO: optimal values for items
//POS = (80,-75,-50)
//ANG = (8,-4,110)

if (CLIENT) then

SWEP.thepos = Vector(1,1,1)
SWEP.theang = Vector(1,1,1)
SWEP.backuppos = Vector(1,1,1)
SWEP.backupang = Vector(1,1,1):Angle()
SWEP.counter = 0
SWEP.backcheck = false
SWEP.doanim = false
SWEP.animbackup = false

function SWEP:GetViewModelPosition( pos, ang )
	self:GetOwner():GetViewModel():SetSequence(0)
	self:GetOwner():GetViewModel():SetPlaybackRate(2)
	self:GetOwner():GetViewModel():ResetSequence(0)
	self:GetOwner():GetViewModel():SetCycle(0)
	//get base position
	local Pos = Vector( GetCSConVarI( "mc_viewmodel_x", self:GetOwner() ), GetCSConVarI( "mc_viewmodel_y", self:GetOwner() ), GetCSConVarI( "mc_viewmodel_z", self:GetOwner() ) )
	
	//print("posx = "..tostring(Pos.x).." posy = "..tostring(Pos.y).." posz = "..tostring(Pos.z))
	
	//get and apply base rotation
	ang:RotateAroundAxis( ang:Right(), GetCSConVarF( "mc_viewmodel_rot_x", self:GetOwner() ) )
	ang:RotateAroundAxis( ang:Forward(), GetCSConVarF( "mc_viewmodel_rot_y", self:GetOwner() ) )
	ang:RotateAroundAxis( ang:Up(), GetCSConVarF( "mc_viewmodel_rot_z", self:GetOwner() ) )

	//get rotation vectors
	local Right	 	 = ang:Right()
	local Up		 = ang:Up()
	local Forward	 = ang:Forward()
	
	//calculate new position
	local posbackup = pos;
	local angbackup = ang

	pos = pos + Pos.x * Right
	pos = pos + Pos.y * Forward
	pos = pos + Pos.z * Up
	
	//print("posx = "..tostring(ang:Right()).." posy = "..tostring(ang:Up()).." posz = "..tostring(ang:Forward()))
	
	//animate
	if (self.doanim) then
			ang:RotateAroundAxis( ang:Right(), self.theAng.x*self.counter)
			ang:RotateAroundAxis( ang:Forward(), self.theAng.y*self.counter)
			ang:RotateAroundAxis( ang:Up(), self.theAng.z*self.counter)
			
			pos = pos + self.thePos.x * ang:Right() * self.counter
			pos = pos + self.thePos.y * ang:Forward() * self.counter
			pos = pos + self.thePos.z * ang:Up() * self.counter
	else //don't modify anything if we are not animating
		if (self.backuppos != posbackup || self.backupang != angbackup) then
			self.backuppos = posbackup
			self.backupang = angbackup
		end
	end

	return pos, ang
end

end


//********************************//
//  	 World Model Logic	      //
//********************************//

if (CLIENT) then
	SWEP.clientModel = ClientsideModel( "models/MCModelPack/blocks/dirt.mdl", RENDERGROUP_TRANSLUCENT)
	SWEP.worldModelVisible = false;
	if (IsValid(SWEP.clientModel) && SWEP.clientModel != NULL) then
		SWEP.clientModel:SetNoDraw(true);
		SWEP.clientModel:DrawShadow(false)
	end
end

function SWEP:DrawWorldModel()
	//if (self.worldModelVisible == true) then

	local matrix = Matrix()
	local BoneIndx = self:GetOwner():LookupBone("ValveBiped.Bip01_R_Hand")
	if (BoneIndx == nil) then return end
	local m = self:GetOwner():GetBoneMatrix(BoneIndx)
	
	if (m == nil) then return end
	if (!IsValid(self.clientModel)) then return end
	
	//get position and angles
	local pos, ang = m:GetTranslation(), m:GetAngles()
	
	//set position
	self.clientModel:SetPos( pos + ang:Up() * 10 + ang:Forward() * 3 )
	
	//set angles
	ang:RotateAroundAxis(ang:Forward(), 180)
	ang:RotateAroundAxis(ang:Up(), 180)
	self.clientModel:SetAngles(ang)
	
	//set bone scale
	for i=0, self.clientModel:GetBoneCount() do
		self.clientModel:ManipulateBoneScale( i, Vector(0.4,0.4,0.4) )
	end
	
	//draw
	self.clientModel:DrawModel()
	
	//end
end


//********************************//
//  	VM and WM update logic    //
//********************************//

function SWEP:UpdateViewmodel()
	if (!m_bUpdateViewmodel) then return end
	if (!IsValid(self:GetOwner())) then return end
	m_bUpdateViewmodel = false
	
	//update viewmodel
	local VM = self:GetOwner():GetViewModel();
	if (IsValid(VM)) then 
		//update viewmodel
		//print("Viewmodel Update! current blocktype = "..tostring(GetCSConVarI( "minecraft_blocktype", self:GetOwner() )))
		VM:SetModel( BlockTypes[ GetCSConVarI( "minecraft_blocktype", self:GetOwner() ) ].model )
		VM:SetSkin( GetCSConVarI( "minecraft_blockskin", self:GetOwner() ) )
		//print("new model = "..tostring(BlockTypes[ GetCSConVarI( "minecraft_blocktype", self:GetOwner() ) ].model))
	end
	
	//update world model
	if (IsValid(self.clientModel)) then
		self.clientModel:SetModel( VM:GetModel() )
		self.clientModel:SetSkin( GetCSConVarI( "minecraft_blockskin", self:GetOwner() ) )
		self.clientModel:SetNoDraw(true)
	end
	
	//HACKHACK: put this somewhere else
	self:DrawShadow(false)
end

function SWEP:ViewmodelCheck()
	//check if any change happened
	if ( m_iLastBlockType != GetCSConVarI( "minecraft_blocktype", self:GetOwner() ) ) then
		m_bUpdateViewmodel = true
	end
	if ( m_iLastBlockSkin != GetCSConVarI( "minecraft_blockskin", self:GetOwner() ) ) then
		m_bUpdateViewmodel = true
	end
	
	//update last values
	m_iLastBlockType = GetCSConVarI( "minecraft_blocktype", self:GetOwner() )
	m_iLastBlockSkin = GetCSConVarI( "minecraft_blockskin", self:GetOwner() )
end




//********************************//
//   	    	Reload  		  //
//********************************//

function SWEP:Reload()
	//multiplayer
	if (CLIENT) then
		if ( !m_bBlockNewPanel ) then
			RunConsoleCommand("mc_menu");
			m_bBlockNewPanel = true
		end
	end
	
	//singleplayer
	if (SERVER) then
	if (self:GetOwner():IsListenServerHost()) then
		if (!m_bMenuCheck) then
			self:GetOwner():ConCommand("mc_menu");
			m_bMenuCheck = true
			timer.Simple( 1, function() m_bMenuCheck = false end )
		end
	end
	end
end



//********************************//
//  			Think  			  //
//********************************//

function SWEP:Think() 
	//this is bullshit, I know
	//remove all blocks of the client on request
	if (SERVER) then
		if ( GetCSConVarB( "cl_minecraft_removeallblocks", self:GetOwner() ) ) then
			if (!game.SinglePlayer()) then
			for k, v in pairs( ents.FindByName( "mcblock*" ) ) do
				if ( v:IsValid() && (v:GetPlayer() == self:GetOwner()) ) then
					v.Entity.health = -1
					v:Remove()
				end
			end	
			else
				for k, v in pairs( ents.GetAll() ) do
					if ( IsValid(v) && (v:GetClass() == "minecraft_block" || v:GetClass() == "minecraft_block_waterized" || v:GetClass() == "mc_tnt" || v:GetClass() == "mc_cake") ) then
						v.Entity.health = -1
						v:Remove()
					end
				end
			end
		self:GetOwner():ConCommand("cl_minecraft_removeallblocks 0")
		end
		
		if ( GetCSConVarB( "cl_minecraft_removeallselectedblocks", self:GetOwner() ) ) then
			local selectedmodel;
			for i,c in ipairs( BlockTypes ) do
				if (BlockTypes[i].blockID == GetCSConVarI( "minecraft_blocktype", self:GetOwner() ) ) then
					selectedmodel = string.lower( BlockTypes[i].model );
				end
			end
			local selectedskin = GetCSConVarI( "minecraft_blockskin", self:GetOwner() )
			for k, v in pairs( ents.FindByName( "mcblock" ) ) do
				if ( v:IsValid() ) then
					if ( v:GetPlayer() == self:GetOwner() || game.SinglePlayer() ) then
						if v:GetModel() == selectedmodel then
							if v:GetSkin() == selectedskin then
								v.Entity.health = -1
								v:Remove()
							end
						end
					end
				end
			end		
			self:GetOwner():ConCommand("cl_minecraft_removeallselectedblocks 0")
		end
		
		//HACKHACK: temporary solution
		if (m_bUpdateServerViewmodel) then
			m_bUpdateServerViewmodel = false;
			local VM = self:GetOwner():GetViewModel();
			if (IsValid(VM)) then 
				//update viewmodel
				VM:SetModel( BlockTypes[ GetCSConVarI( "minecraft_blocktype", self:GetOwner() ) ].model )
				VM:SetSkin( GetCSConVarI( "minecraft_blockskin", self:GetOwner() ) )
			end
		end
	end

	if (SERVER) then return end

	//check for viewmodel changes and update if necessary
	self:ViewmodelCheck()
	self:UpdateViewmodel()
	
	//the viewmodel animation
	if ( GetCSConVarB( "mc_viewmodel_doanim", self:GetOwner() ) ) then
		self.doanim = true
		self.backcheck = false;
		self.counter = 0;
		self.timer = CurTime();
		RunConsoleCommand( "mc_viewmodel_doanim", "0" )
	end
	
	if (self.doanim || GetCSConVarB( "mc_viewmodel_animtest", self:GetOwner() ) == true ) then
		//back anim
		if (self.backcheck == true) then
			//calculate vectorDiff
			self.thePos = - Vector( GetCSConVarF( "mc_viewmodel_dx", self:GetOwner() ),
									GetCSConVarF( "mc_viewmodel_dy", self:GetOwner() ),
									GetCSConVarF( "mc_viewmodel_dz", self:GetOwner() ) * (self.counter/(2-(self.counter/(2-self.counter)))));
			
			self.theAng = - Vector( GetCSConVarF( "mc_viewmodel_rot_dx", self:GetOwner() ),
									GetCSConVarF( "mc_viewmodel_rot_dy", self:GetOwner() ),
									GetCSConVarF( "mc_viewmodel_rot_dz", self:GetOwner() ) )

			self.counter = (self.timer-CurTime())/GetCSConVarF( "mc_viewmodel_animspeed_back", self:GetOwner() );
			
			//if the animation finished
			if (self.counter < 0) then
				self.backcheck = false;
				self.counter = 0
				self.doanim = false
				self.animbackup = false
				RunConsoleCommand( "mc_viewmodel_doanim", "0" )
			end
		end
		
		//forward anim
		if (self.counter <= 1 && !self.backcheck) then
			//calculate vectorDiff
			self.thePos = - Vector( GetCSConVarF( "mc_viewmodel_dx", self:GetOwner() ),
									GetCSConVarF( "mc_viewmodel_dy", self:GetOwner() ),
									GetCSConVarF( "mc_viewmodel_dz", self:GetOwner() ) )
									
			self.theAng = - Vector( GetCSConVarF( "mc_viewmodel_rot_dx", self:GetOwner() ),
									GetCSConVarF( "mc_viewmodel_rot_dy", self:GetOwner() ),
									GetCSConVarF( "mc_viewmodel_rot_dz", self:GetOwner() ) )

			self.counter = (CurTime()-self.timer)/GetCSConVarF( "mc_viewmodel_animspeed", self:GetOwner() );
		end
		
		//switch from forward to back
		if (self.counter > 1 && !self.backcheck) then
			if (!self.animbackup) then
				self.BackupPos = -self.backuppos
				self.BackupAng = -self.backupang
				self.animbackup = true
			end		
			self.backcheck = true
			self.timer = CurTime() + GetCSConVarF( "mc_viewmodel_animspeed_back", self:GetOwner() )
			self.counter = 1;
		end
	end
end


//********************************//
//  	Main attack functions     //
//********************************//

function SWEP:AttackAnim()
	self:GetOwner():ConCommand("mc_viewmodel_doanim 1")
end

function SWEP:SecondaryAttack()
	m_bBlockNewPanel = false
	//handle left/right mouse swapping
	local swap = GetCSConVarB( "minecraft_swapattack", self:GetOwner() )
	
    if ( swap == true) then
        self:MCPrimaryAttack()
    else
        self:MCSecondaryAttack()
    end
end
function SWEP:PrimaryAttack()
	m_bBlockNewPanel = false
	//handle left/right mouse swapping
	local swap = GetCSConVarB( "minecraft_swapattack", self:GetOwner() )

    if ( swap == true ) then
        self:MCSecondaryAttack()
    else
        self:MCPrimaryAttack()
    end
end

//idk where else to put this
function SWEP:ShouldDropOnDie()
	return false
end



//********************************//
//   Deploy / Holster / Remove    //
//********************************//

function SWEP:BuildWorldModel()
	if (CLIENT) then
		m_bUpdateViewmodel = true
		if (!IsValid(self.clientModel)) then
			self.clientModel = ClientsideModel( "models/MCModelPack/blocks/dirt.mdl", RENDERGROUP_TRANSLUCENT)
		end
		self.clientModel:SetNoDraw(false)
	end
end

function SWEP:Deploy()
	m_bUpdateViewmodel = true
	self:UpdateViewmodel()
	if (CLIENT) then
		self:BuildWorldModel()
		self.worldModelVisible = true;
		if (IsValid(self.clientModel) && self.clientModel != NULL) then
			self.clientModel:SetNoDraw(false)
		end
	end
	return true
end

function SWEP:Holster()
	if (CLIENT) then
		self.worldModelVisible = false;
		if (IsValid(self.clientModel) && self.clientModel != NULL) then
			self.clientModel:SetNoDraw(true)
		end
	end
	return true
end

function SWEP:OnRemove()
	if (CLIENT) then
		//remove world model
		if (IsValid(self.clientModel)) then
			self.clientModel:Remove()
		end
		self.clientModel = nil
	end
end

function SWEP:Initialize()
	if (CLIENT) then
		self:BuildWorldModel()
	end
end



//************************************//
// MCSecondaryAttack (creates blocks) //
//************************************//

function SWEP:MCSecondaryAttack()
	//check if the block is allowed
	if (SERVER) then
		if ( isBlockAllowed(  GetCSConVarI( "minecraft_blocktype", self:GetOwner() ) ) == false ) then
			return
		end
	end

	//allow server owners to set a max block limit per player
	if (SERVER) then
		local blockcount = 0
		for k, v in pairs( ents.GetAll() ) do
			if ( v:IsValid() ) then
				if (v:GetClass() == "minecraft_block" || v:GetClass() == "minecraft_block_waterized" || v:GetClass() == "mc_tnt" || v:GetClass() == "mc_cake") then
					if (v:GetPlayer() == self:GetOwner()) then
						blockcount = blockcount + 1
					end
				end
			end
		end
		self:GetOwner():ConCommand("cl_minecraft_blockcount ".. (blockcount+1))
		if ( blockcount > GetConVar("minecraft_swep_blocklimit"):GetInt() ) then
			self:GetOwner():ConCommand("say reached the max block limit!")
			return
		end
	end
	
	//get eye trace
	local zpos = 0
	local tr = self:GetOwner():GetEyeTrace()
	local startpos = self:GetOwner():GetShootPos()
	local isBlock = false
	
	local tracedata = {}
	tracedata.start = startpos
	tracedata.endpos = tr.HitPos + tr.HitNormal * 20
	tracedata.filter = self.Owner
	
	//check if the trace hit anything
	local checktr = util.TraceLine(tracedata)
	if checktr.HitNonWorld then
		target = checktr.Entity
		if ( target ) then 
			isBlock = true 
		end
	end
	local checkent = 0
	local checkvec = Vector(0,0,0)
	if tr.HitNonWorld then
		checkent = tr.Entity
		checkvec = checkent:GetPos()
		if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then 
			print("checktr hit nonworld!") 
		end
	end

	local SpawnPos = tr.HitPos + tr.HitNormal * 20
	
	local distvec = tr.HitPos - self.Owner:GetPos()
	local length = distvec:Length()
	
	//check for distancelimit
    if ( GetCSConVarB( "minecraft_distancelimit", self:GetOwner() ) == true ) then
        if ( length > GetCSConVarF( "minecraft_maxspawndist", self:GetOwner() ) ) then
            isBlock = true
			if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) 
				then print("too far!") 
			end
        end
    end
	
	if ( isBlock == false && tr.HitWorld == false && ( GetCSConVarI( "minecraft_spawntype", self:GetOwner() ) == 2 || GetCSConVarI( "minecraft_spawntype", self:GetOwner() ) == 1) ) then
		
		//check wether we are placing on top, bottom, or the four sides
		local hitz = tr.HitPos.z
		local checkvecz = checkvec.z
		local hmc = hitz - checkvecz   //hmc should be about '16' when placing on top OR on bottom
		if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("hmc = " .. tostring(hmc)) end
 
		if (hitz < 0) then
			hitz = - hitz
		end
		if (checkvecz <0) then
			checkvecz = - checkvecz
		end
		local hmc2 = hitz - checkvecz
		if (hmc2 < 0) then
			hmc2 = - hmc2
		end
		
		if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("hmc2 = " .. tostring(hmc2)) end
		
		local toporbottom = 0
		if (hmc2 > 15.9 && hmc2 < 16.1) then // top OR bottom
			if (hmc < 0) then
				toporbottom = 2
				if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("bottom = " .. tostring(toporbottom)) end 
			end
			if (hmc > 0) then
				toporbottom = 1
				if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("top = " .. tostring(toporbottom)) end
			end
		end
		
		if (toporbottom == 0) then  //one of the four sides
			if (tr.HitPos.z > checkvec.z) then
				zpos = math.floor( SpawnPos.z / 36.5 ) * 36.5 + 0
				if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("upper half") end
			end
			if (tr.HitPos.z < checkvec.z) then
				zpos = math.floor( SpawnPos.z / 36.5 ) * 36.5 + 0//36.5
				if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("lower half") end
			end
		end
		
		if (toporbottom == 1) then //top
			zpos = math.floor( SpawnPos.z / 36.5 ) * 36.5 + 36.5
			if ((SpawnPos.z - zpos) < -1) then // bug!
				zpos = math.floor( SpawnPos.z / 36.5) * 36.5 + 0
			end
			if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("top->SpawnPos.z = " .. tostring(SpawnPos.z)) end
			if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("top->zpos = " .. tostring(zpos)) end
		end
		
		if (toporbottom == 2) then //bottom
			zpos = math.floor( SpawnPos.z / 36.5 ) * 36.5 + 0
			if ((SpawnPos.z - zpos) > 1) then // bug!
				zpos =math.floor( SpawnPos.z / 36.5 ) * 36.5 + 36.5
			end
			if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("bottom->SpawnPos.z = " .. tostring(SpawnPos.z)) end
			if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("bottom->zpos = " .. tostring(zpos)) end
		end
		
		if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("isBlock == false!!, checkvec.z = " .. tostring(checkvec.z)) end
		if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then print("HitPos.z = " .. tostring(tr.HitPos.z)) end
	end
	
	//debug output if something is blocking the way
	if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) then
		if ( isBlock == true) then //block is blocking the way
			print("isBlock is true!")
		end
	end
	
	//if no block is nearby or blocking
	if ( tr.HitWorld == true && isBlock == false && GetCSConVarI( "minecraft_spawntype", self:GetOwner() ) == 2) then 
		zpos = math.floor( SpawnPos.z / 36.5 ) * 36.5 + 0
		if ( ClDebugEnabled() && GetCSConVarB( "minecraft_debug", self:GetOwner() )) 
			then print("tr.HitWorld & isBlock = false")	
		end
	end  
	
	
	//*******************************//
	//	actual block spawning code	 //
	//*******************************//
	
	//only execute on server
	self.Owner:SetAnimation( PLAYER_ATTACK1 )
	if (CLIENT) then return end
	
	if ( isBlock == false ) then  //pos is ok, block can be created
		
		local ent = 0
		local blockID = GetCSConVarI( "minecraft_blocktype", self:GetOwner() )
		
		//position the block according to a fixed grid which is relative to (0,0,0) in every map
		local xpos = math.floor( SpawnPos.x / 36.5 ) * 36.5 + 18.25
		local ypos = math.floor( SpawnPos.y / 36.5 ) * 36.5 + 18.25
		if ( GetCSConVarI( "minecraft_spawntype", self:GetOwner() ) == 1) then
			zpos = math.floor( SpawnPos.z / 36.5 ) * 36.5 + 18.25
		end
        if ( GetCSConVarI( "minecraft_spawntype", self:GetOwner() ) == 0) then
            zpos = SpawnPos.z
        end

		//handle lava + water (they have their own spawn function)
		local wasWaterized = 0
		if (blockID != 41 && blockID != 42 && blockID != 81) then
			lavaorwater = 0
		else
			wasWaterized = 1
			local damping, density, buoyancy
			if (blockID == 41) then //water
				damping = 15
				density = 70
				buoyancy = 600
				lavaorwater = 0
				ent = SpawnWaterizedBlock( self:GetOwner(), damping, density, buoyancy, 1, Vector(xpos,ypos,zpos),  blockID )
			end
			if (blockID == 42) then //lava
				damping = 40
				density = 90
				buoyancy = 300
				lavaorwater = 1
				ent = SpawnWaterizedBlock( self:GetOwner(), damping, density, buoyancy, 2, Vector(xpos,ypos,zpos), blockID )
			end
			if (blockID == 81) then //cobweb
				damping = 99
				density = 99
				buoyancy = 100
				lavaorwater = 1
				ent = SpawnWaterizedBlock( self:GetOwner(), damping, density, buoyancy, 3, Vector(xpos,ypos,zpos), blockID )
			end
		end
		
		//set all attributes
		/*
		ent:SetModel( BlockTypes[blockID].model )
		ent:SetSkin( GetCSConVarI( "minecraft_blockskin", self:GetOwner() ) )
		ent:SetPos( Vector( xpos, ypos, zpos ) )
		ent:PhysicsInitBox( SpawnPos + Vector( -18.25, -18.25, -18.25 ), SpawnPos + Vector(  18.25,  18.25,  18.25 ) )
		ent:SetKeyValue( "DisableShadows", "1" )
		ent:SetKeyValue( "targetname", "mcblock" )
		*/
		
		
		//finally, spawn the entity (mcblock checks whether we already spawned a WaterizedBlock before)
		if (wasWaterized == 0) then
			local theBlockID = blockID
			ent = SpawnMinecraftBlock( self:GetOwner(), tr.Entity, theBlockID, Vector(xpos,ypos,zpos), GetCSConVarI( "minecraft_blockrotation", self:GetOwner() ) )
			if ( ent != nil ) then
				self:AttackAnim()
			end
		else
			if (ent != nil) then
				self:AttackAnim()
			end
		end

		//create the undo object
		if (ent != nil) then
		undo.Create("MC Block")
			undo.AddEntity( nocl )
			undo.AddEntity( ent )
			undo.SetPlayer( self.Owner )
			undo.SetCustomUndoText( "Undone MC block" )
			undo.Finish()
		end
	end
end


//**********************************//
// MCPrimaryAttack (deletes blocks) //
//**********************************//

function SWEP:MCPrimaryAttack()
	//get eye trace
	local tr = self.Owner:GetEyeTrace()
	local distvec = tr.HitPos - self.Owner:GetPos()
	local length = distvec:Length()
	if ( !tr.Entity:IsValid() ) then return end
	
	//only delete minecraft blocks?
	if ( GetCSConVarB( "minecraft_deletemconly", self:GetOwner() ) == true && !( tr.Entity:GetClass() == "minecraft_block"
																			|| tr.Entity:GetClass() == "minecraft_block_waterized"
																			|| tr.Entity:GetClass() == "mc_cake"
																			|| tr.Entity:GetClass() == "mc_tnt" ) ) then return end

	//handle distancelimit, particles and deletion
	if ( GetCSConVarB( "minecraft_distancelimit", self:GetOwner() ) == false || length < GetCSConVarF( "minecraft_maxspawndist", self:GetOwner() )) then
		if tr.HitNonWorld then
			target = tr.Entity  
			if (target) then
				self:ShootEffects( self )

				//particle effect
				/*
				local effectdata = EffectData()
				effectdata:SetOrigin( target:GetPos() )
				effectdata:SetNormal( tr.HitNormal )
				effectdata:SetMagnitude( 8 )
				effectdata:SetScale( 1 )
				effectdata:SetRadius( 16 )
				util.Effect( "GlassImpact", effectdata )
				*/
			end
		end

		// The rest is only done on the server
		if (!SERVER) then return end
	 
		local trace = self.Owner:GetEyeTrace();
		if( not trace.HitWorld ) then // if you hit an entity
			if (tr.Entity:GetClass() == "minecraft_block" || tr.Entity:GetClass() == "mc_tnt" || tr.Entity:GetClass() == "mc_cake" || tr.Entity:GetClass() == "minecraft_block_waterized") then
				trace.Entity.health = -2; //change -2 to -1 to disable particle effects and sounds on block destroy
				if ( game.SinglePlayer() || tr.Entity:GetPlayer() == self:GetOwner()) then
					//this is a minecraft block and we own it
					if ( tr.Entity:GetClass() == "minecraft_block" ) then
						trace.Entity:RemoveSpecial()
					else
						trace.Entity:Remove()
					end
					self:AttackAnim()
					self:GetOwner():ConCommand("cl_minecraft_blockcount "..(GetCSConVarI( "cl_minecraft_blockcount", self:GetOwner() ) - 1))
				end
			else
				//any entity
				self:AttackAnim()
				trace.Entity:Remove()
			end
		end
	end
end

//**********************************************
//	Remove all entities with the name "mcblock"
//**********************************************

function removeall()
	for k, v in pairs( ents.FindByClass( "minecraft_block*" ) ) do
		if ( v:IsValid() ) then
			v:Remove()
		end
	end
end

//*******************************************
//	Remove all blocks of the selected type
//*******************************************

function removeselected( ply, cmd, arg )
	local selectedmodel;
	for i,c in ipairs( BlockTypes ) do
		if (BlockTypes[i].blockID == GetCSConVarI( "minecraft_blocktype", ply) ) then
			selectedmodel = string.lower( BlockTypes[i].model );
		end
	end
	local selectedskin = GetCSConVarI( "minecraft_blockskin", ply )
	for k, v in pairs( ents.FindByName( "mcblock" ) ) do
		if ( v:IsValid() ) then
			if (v:GetOwner() == ply) then
				if (SERVER) then
					if v:GetModel() == selectedmodel then
						if v:GetSkin() == selectedskin then
							v.Entity.health = -1
							v:Remove()
						end
					end
				end
			end
		end
	end
end

//*******************************************
//	update ALL the blocks!
//*******************************************

function forceblockupdate()
	for k, v in pairs( ents.FindByClass( "minecraft_block*") ) do
		if ( v:IsValid() ) then
			if (SERVER) then
				v:SetNWBool("doUpdate",true)
			end
		end
	end
end

//*******************************************************
//	Spawn a waterized entity (used in MCSecondaryAttack)
//*******************************************************

function SpawnWaterizedBlock( ply, damping, density, buoyancy, btype, pos, blockID )
	ent = ents.Create( "minecraft_block_waterized" )
	if not IsValid( ent ) then print("SpawnWaterizedBlock() ent is not valid!!!") return end
	ent:SetPlayer( ply )
	
	//set attributes
	ent:SetModel( BlockTypes[blockID].model )
	ent:SetSkin( GetCSConVarI( "minecraft_blockskin", ply ) )
	ent:SetPos( pos )
	//ent:PhysicsInitBox( SpawnPos + Vector( -18.25, -18.25, -18.25 ), SpawnPos + Vector(  18.25,  18.25,  18.25 ) )
	ent:SetKeyValue( "DisableShadows", "1" )
	ent:SetKeyValue( "targetname", "mcblock" )

	ent:SetDamping( damping )
	ent.damping = damping
	ent:SetDensity( density )
	ent.density = density
	ent:SetBuoyancy( buoyancy )
	ent.buoyancy = buoyancy
	
	ent:SetKeyValue( "DisableShadows", "1" )
	ent:SetKeyValue( "targetname", "mcblock" )
	
	if (btype == 1) then
		ent:SetNetworkedString( "water", "true" )
		ent:SetNetworkedString( "lava", "false" )
		ent.maxspread = GetCSConVarI( "minecraft_water_maxspread", ply )
		ent:SetNetworkedInt("blockID",blockID)
		ent.parent = 1
		ent.dt.blockID = 41
	end
	if (btype == 2) then
		ent:SetNetworkedString( "lava", "true" )
		ent:SetNetworkedString( "water", "false" )
		ent.maxspread = GetCSConVarI("minecraft_lava_maxspread", ply )
		ent:SetNetworkedInt("blockID",blockID)
		ent.parent = 1
		ent.dt.blockID = 42
	end
	if (btype == 3) then
		ent:SetNetworkedString( "lava", "false" )
		ent:SetNetworkedString( "water", "false" )	
		ent:SetNetworkedInt("blockID",blockID)
		ent.maxspread = 0
		ent.parent = 0
	end
	
	ent:SetNetworkedBool("doUpdate",true)
	
	if ( GetCSConVarB( "minecraft_debug", ply ) && GetCSConVarB( "minecraft_water_spread", ply) && btype != 3) then 
		ent:SetColor(255,0,0,255)
	end

	ent:Spawn()
	ent:PostSpawn()
	
	return ent
end

//*******************************************************//
//	Spawn a minecraft block (used in MCSecondaryAttack)  //
//*******************************************************//

function SpawnMinecraftBlock( ply, hitEntity, blocktype, pos, rotation )
	ent = ents.Create( "minecraft_block" ) 
	if not IsValid(ent) then print("SpawnMinecraftBlock() ent is not valid!!!") return end
	ent:SetPlayer( ply )
	
	//set attributes
	ent:SetModel( BlockTypes[blocktype].model )
	ent:SetSkin( GetCSConVarI( "minecraft_blockskin", ply ) )
	ent:SetPos( pos )
	//ent:PhysicsInitBox( SpawnPos + Vector( -18.25, -18.25, -18.25 ), SpawnPos + Vector(  18.25,  18.25,  18.25 ) )
	ent:SetKeyValue( "DisableShadows", "1" )
	ent:SetKeyValue( "targetname", "mcblock" )
	
	ent:SetBlockID( blocktype )
	ent:SetRotation( rotation )
	ent:BlockInit( blocktype, hitEntity )
	
	if ( !GetCSConVarB( "minecraft_force_block_spawn", ply ) ) then
		local check = ent:CheckPos( blocktype )
		if (!check) then 
			//if ( GetCSConVarB( "minecraft_debug", ply ) ) then ply:ConCommand("echo [CheckPos()] blocks would overlap!") end
			ent:Remove() 
			return nil
		end
	
		//check for already existing blocks (to avoid overlapping)
		for k, v in pairs( ents.FindByClass( "minecraft_block" ) ) do
			if ( v:IsValid() ) then
				if ( v:GetPos() == ent:GetPos() && v != ent ) then
					//if ( GetCSConVarB( "minecraft_debug", ply ) ) then ply:ConCommand("echo [CheckPos()] blocks would overlap!") end
					ent:Remove()
					return nil
				end
			end
		end
	end
	
	//force block rotation
	if ( GetCSConVarB( "minecraft_blockrotation_force", ply ) ) then
		ent:SetAngles( Angle( 0, GetCSConVarI( "minecraft_blockrotation", ply ), 0 ))
	end
	
	//force block update
	ent:SetNetworkedBool("doUpdate",true)
	
	//call spawn functions in correct order
	ent:OnSpawn( blocktype, hitEntity )
	ent:Spawn()
	ent:PostSpawn( blocktype )
	
	return ent
end

//duplicator.RegisterEntityClass( "minecraft_block_waterized", SpawnWaterizedBlock, "damping", "density", "buoyancy", "btype", "pos", "blockID" )
//duplicator.RegisterEntityClass( "minecraft_block", SpawnMinecraftBlock, "hitEntity", "blocktype", "pos", "rotation" )

//check if block is allowed (used for multiplayer only)
function isBlockAllowed( ID )
	local cvarstring = GetConVar( "minecraft_swep_blacklist" ):GetString()
	if (string.len( cvarstring ) <= 0) then
		return true
	end
	local blacklist = string.Explode( ",", cvarstring )
	for i,c in ipairs( blacklist ) do
		if ( blacklist[i] == tostring(ID) ) then
			return false
		end
	end
	return true
end