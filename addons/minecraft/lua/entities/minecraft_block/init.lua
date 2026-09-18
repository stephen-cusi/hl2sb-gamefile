//********************************//
//     Minecraft Block Entity     //
//			 (c) McKay			  //
//********************************//

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( 'shared.lua')

//Accessor Funcs
function ENT:SetPlayer( ply )
    self.Owner = ply
end

function ENT:GetPlayer( )
    return self.Owner
end

function ENT:GetBlockID( )
	return self.dt.blockID
end

function ENT:SetRotation( rotation )
	self.dt.rotation = rotation
end

function ENT:SetBlockID( ID )
	self.dt.blockID = ID
end


//FUCK THIS    ( lua/includes/extensions/entity.lua:396:  ent[ "Set" .. k ]( ent, tab[ k ] ) )
//duplicator & save/load fix
function ENT:SetblockID( ID )
	self.dt.blockID = ID
end

function ENT:Setrotation( rotation )
	self.dt.rotation = rotation
end

function ENT:SetdoUpdate( DoUpdate )
	self.dt.doUpdate = DoUpdate
end


//***************************************
//	Serverside init
//***************************************

function ENT:Initialize()
	//remove hook
	//hook.Add( "OnRemove", "blockremove", OnRemove )
	//self:CallOnRemove("blockremove",OnRemove)
    //Basic stuff
    self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid( SOLID_VPHYSICS )   
	// Wake the physics object up
	local phys = self.Entity:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:EnableMotion( false ) //freeze the block
		phys:Wake()
	end
	
	self.simpleRemove = false
	self:SetUseType( SIMPLE_USE )
end

//***************************************
//	OnTakeDamage
//***************************************

function ENT:OnTakeDamage( dmginfo )
	// React physically when shot/getting blown
	self.Entity:TakePhysicsDamage( dmginfo )
	
	if (self.health <= 0) then return end;
	self.health = self.health - dmginfo:GetDamage();
	if (self.health <= 0) then
		self:RemoveSpecial();
	end
end

//***************************************
//	Remove with particle effects
//***************************************

function ENT:RemoveSpecial()
	//can't touch this (anymore)
	self:SetNotSolid( true )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetNoDraw( true )
	
	self:OnRemoveSpecial()
	
	if ( self.health != -1 && GetCSConVarB( "minecraft_particles", self:GetPlayer() ) ) then
		//create particle effect
		local effect = EffectData();
		local pos = self:GetPos();
		local aabb_min, aabb_max = self:WorldSpaceAABB();
		local zadd = math.abs(aabb_min.z - aabb_max.z)/2
		pos.z = pos.z + zadd;
		effect:SetOrigin( pos )
		effect:SetNormal( Vector(0,0,1) );
		effect:SetEntity( self )
		util.Effect( "mc-sparkle", effect, true, true );
		
		//properly remove 0.2 seconds
		timer.Simple( 0.2, function() if ( IsValid( self ) ) then self:Remove() end end )
	else
		self:Remove()
	end
end

//***************************************
//	OnSpawn - sounds and health values
//***************************************

function ENT:OnSpawn( ID, hitEntity )
	if ( GetCSConVarI( "minecraft_blockhealth",self.Owner ) > 0) then
		self.health = GetCSConVarI( "minecraft_blockhealth", self.Owner )
	else
		self.health = -1
	end
	//if (debuginfo == 2) then print("OnSpawn() with ID = " .. tostring(ID)) end
	
	//assign custom health values to all blocks
	if ( GetCSConVarB( "minecraft_blockhealth_auto", self.Owner ) == true) then
		//ice and snow blocks
		if (ID == 40 || ID == 17) then
			self.health = 5;
		end
		//all metal blocks never break (+bedrock,+fire)
		if (ID == 37 || ID == 63 || ID == 14 || ID == 73 || ID == 74 || ID == 75 || ID == 76 || ID == 69) then
			self.health = -1;
		end
		//obsidian
		if (ID == 13) then
			self.health = 500;
		end
		//TODO: add more
	end
	
	if ( !GetCSConVarB( "minecraft_disablesounds", self.Owner ) ) then
		local hasSound = false;
	
		//grass
		if (ID == 38 || ID == 70 || ID == 39 || ID == 108 || ID == 123 || ID == 172 || ID == 173 || ID == 183 || ID == 190 || ID == 191 || ID == 192) then
			local grass = { Sound("minecraft/grass1.wav"),Sound("minecraft/grass2.wav"),Sound("minecraft/grass3.wav"),Sound("minecraft/grass4.wav") }
			self:EmitSound( table.Random( grass ), 510, math.random(60,100))
			hasSound = true;
		end
		
		//stone
		if (ID == 7 || ID == 8 || ID == 9 || ID == 10 || ID == 11 || ID == 12 || ID == 13 || ID == 14 || ID == 15
			|| ID == 16 || ID == 19 || ID == 23 || ID == 24 || ID == 37 || ID == 44 || ID == 45 || ID == 46 || ID == 48 || ID == 50
			|| ID == 51 || ID == 52 || ID == 57 || ID == 63 || ID == 68 || ID == 21 || ID == 22 || ID == 40 || ID == 61 || ID == 53
			|| ID == 57 || ID == 58 || ID == 49 || ID == 94 || ID == 95 || ID == 98 || (ID >= 85 && ID <= 88) || ID == 107 || (ID >= 123 && ID <= 134) 
			|| ID == 174 || ID == 175 || ID == 176 || ID == 177 || ID == 178 || ID == 180 || ID == 181 || ID == 182 || ID == 184 || ID == 185 || ID == 186
			|| ID == 187 || ID == 189 || ID == 197 || ID == 198 || ID == 199 || ID == 200) then
			
			local stone = { Sound("minecraft/stone1.wav"),Sound("minecraft/stone2.wav"),Sound("minecraft/stone3.wav"),Sound("minecraft/stone4.wav") }
			self:EmitSound( table.Random( stone ), 510, math.random(60,100))
			hasSound = true;
		end
		
		//wood
		if (ID == 25 || ID == 26 || ID == 27 || ID == 28 || ID == 29 || ID == 30 || ID == 31 || ID == 47 || ID == 54
			|| ID == 65 || ID == 66 || ID == 67 || ID == 77 || ID == 78 || ID == 62 || ID == 64 || ID == 55 || ID == 34
			|| ID == 32  || ID == 72 || ID == 96 || ID == 97 || (ID >= 99 && ID <= 106) || (ID >= 89 && ID <= 93)  || ID == 109
			|| (ID >= 135 && ID <= 171) || (ID >= 110 && ID <= 116) || ID == 188 || ID == 193 || ID == 194 || ID == 195) then
			
			local wood = { Sound("minecraft/wood1.wav"),Sound("minecraft/wood2.wav"),Sound("minecraft/wood3.wav"),Sound("minecraft/wood4.wav") }
			self:EmitSound( table.Random( wood ), 510, math.random(60,100))
			hasSound = true;
		end
		
		//gravel
		if (ID == 1 || ID == 2 || ID == 3 || ID == 4) then
			local gravel = { Sound("minecraft/gravel1.wav"),Sound("minecraft/gravel2.wav"),Sound("minecraft/gravel3.wav"),Sound("minecraft/gravel4.wav") }
			self:EmitSound( table.Random( gravel ) , 510, math.random(60,100))
			hasSound = true;
		end
		
		//snow
		if (ID == 5 || ID == 17 || ID == 56) then
			local snow = { Sound("minecraft/snow1.wav"),Sound("minecraft/snow2.wav"),Sound("minecraft/snow3.wav"),Sound("minecraft/snow4.wav") }
			self:EmitSound( table.Random( snow ), 510, math.random(60,100))
			hasSound = true;
		end
		
		//cloth
		if (ID == 79 || ID == 80  || ID == 35 || ID == 36) then
			local cloth = { Sound("minecraft/cloth1.wav"),Sound("minecraft/cloth2.wav"),Sound("minecraft/cloth3.wav"),Sound("minecraft/cloth4.wav") }
			self:EmitSound( table.Random( cloth ), 510, math.random(60,100))
			hasSound = true;
		end
		
		//sand
		if (ID == 6 || ID == 20) then
			local sand = { Sound("minecraft/sand1.wav"),Sound("minecraft/sand2.wav"),Sound("minecraft/sand3.wav"),Sound("minecraft/sand4.wav") }
			self:EmitSound( table.Random( sand ), 510, math.random(60,100))
			hasSound = true;
		end
		
		if (hasSound == false) then
			//if (GetConVar("minecraft_debug"):GetBool()) then print("blocks with ID = " .. tostring(ID) .. " have no spawn sounds implemented!!!") end
		end
	end
	
	//init custom variables needed for special block types like vines
	if (ID == 82) then
		self.growtime = CurTime() + GetCSConVarF( "minecraft_vines_growspeed", self:GetPlayer() )
	end
	
	
	self.spawned = true
end

//***************************************
//	PostSpawn - update nearby blocks
//***************************************

function ENT:PostSpawn ( ID )
	//notify all nearby blocks to update themselves
	//i think it's more efficient to update the blocks on spawn instead of every Think() cycle?
	//even though we are calling the function 6 times.. (idk)
	local t1 = self:GetNearbyBlock( 1 );
	local t2 = self:GetNearbyBlock( 2 );
	local t3 = self:GetNearbyBlock( 3 );
	local t4 = self:GetNearbyBlock( 4 );
	local t5 = self:GetNearbyBlock( 5 );
	local t6 = self:GetNearbyBlock( 6 );
	
	if (t1 != nil) then
		if (t1:IsValid()) then
			t1:SetNetworkedBool("doUpdate", true);
		end
	end
	if (t2 != nil) then
		if (t2:IsValid()) then
			t2:SetNetworkedBool("doUpdate", true);
		end
	end
	if (t3 != nil) then
		if (t3:IsValid()) then
			t3:SetNetworkedBool("doUpdate", true);
		end
	end
	if (t4 != nil) then
		if (t4:IsValid()) then
			t4:SetNetworkedBool("doUpdate", true);
		end
	end
	if (t5 != nil) then
		if (t5:IsValid()) then
			t5:SetNetworkedBool("doUpdate", true);
		end
	end
	if (t6 != nil) then
		if (t6:IsValid()) then
			t6:SetNetworkedBool("doUpdate", true);
		end
	end
end

//***********************************************
//	OnRemove - sounds, particles and other stuff
//***********************************************

//all blocks added to both these will get autodestroyed when the block they were placed on gets destroyed
//TODO: why doesn't   !(blockID >= 135 && blockID <= 171)    work ???
function notBlockToDestroy( blockID )
	if ( blockID != 56 && blockID != 65 && blockID != 66 && blockID != 67 && blockID != 68 && blockID != 98 && blockID != 109 && blockID != 110
		&& blockID != 89 && blockID != 90 && blockID != 91) then
		return true
	else
		return false
	end
end

function orBlockToDestroy( blockID )
	if ( blockID == 56 || blockID == 65 || blockID == 66 || blockID == 67 || blockID == 68 || blockID == 98 || blockID == 109 || blockID == 110
		|| blockID == 89 || blockID == 90 || blockID == 91) then
		return true
	else
		return false
	end
end

function ENT:OnRemoveSpecial( )
	if (self.spawned == false) then return end
	if (self:GetPlayer() == "NULL" || self:GetPlayer() == nil) then return end
	if (self.simpleRemove == true) then return end //to get rid of NULL entity bugs because self:GetPlayer = "Player [NULL]"
		
	local ID = self:GetBlockID();
	//if (GetConVar("minecraft_debug"):GetBool()) then print("block with ID = " .. tostring(ID) .. " removed!") end
	 
	//test: spawn a water block if an ice block breaks
	if (ID == 40) then
		if (self.health <= 0 && self.health != -1 && self.health != -2) then //if we were killed by taking damage
			//if (GetConVar("minecraft_debug"):GetBool()) then print("spawning water block in place of ice block...") end
			local ent = ents.Create( "minecraft_block_waterized" )
			
			ent:SetModel( "models/MCModelPack/blocks/water.mdl" )
			ent:PhysicsInitBox( self:GetPos() + Vector( -18.25, -18.25, -18.25 ), self:GetPos() + Vector(  18.25,  18.25,  18.25 ) )
			ent:SetKeyValue( "DisableShadows", "1" )
			ent:SetKeyValue( "targetname", "mcblock" )
			ent:SetPos( self:GetPos() )
			ent:SetPlayer( self:GetPlayer() )
		
			ent:SetDamping( 15 )
			ent.damping = 15
			ent:SetDensity( 70 )
			ent.density = 70
			ent:SetBuoyancy( 600 )
			ent.buoyancy = 600
		
			ent:SetNetworkedString( "water", "true" )
			ent:SetNetworkedString( "lava", "false" )
		
			ent.parent = 1
			//ent.maxspread = GetCSConVarI( "minecraft_water_maxspread", self:GetPlayer() )
			ent.maxspread = 2
			ent:SetNWInt("blockID",41)
			ent:SetNetworkedBool("doUpdate",true)
			//if (GetConVar("minecraft_debug"):GetBool()) then ent:SetColor(255,0,0,255) end
			ent:Spawn()
		end
	end
	
	if (!GetCSConVarB( "minecraft_disablesounds", self.Owner ) && self.health <= 0 && self.health != -1) then
		local hasSound = false;
	
		//grass
		if (ID == 38 || ID == 70 || ID == 71 || ID == 39 || ID == 2 || ID == 82 || ID == 108 || ID == 123 || ID == 172 || ID == 173 || ID == 183  || ID == 190 || ID == 191 || ID == 192) then
			local grass = { Sound("minecraft/grass1.wav"),Sound("minecraft/grass2.wav"),Sound("minecraft/grass3.wav"),Sound("minecraft/grass4.wav") }
			self:EmitSound( table.Random( grass ), 510, math.random(60,100) )
			hasSound = true;
		end
		
		//stone
		if (ID == 7 || ID == 8 || ID == 9 || ID == 10 || ID == 11 || ID == 12 || ID == 13 || ID == 14 || ID == 15
			|| ID == 16 || ID == 19 || ID == 23 || ID == 24 || ID == 37 || ID == 44 || ID == 45 || ID == 46 || ID == 48 || ID == 50
			|| ID == 51 || ID == 52 || ID == 53 || ID == 57 || ID == 58 || ID == 63 || ID == 68 || ID == 34 || ID == 49
			|| ID == 94 || ID == 95 || ID == 98 || (ID >= 86 && ID <= 88)  || ID == 107 || (ID >= 123 && ID <= 134) || ID == 174 || ID == 175 
			|| ID == 176 || ID == 177 || ID == 178 || ID == 180 || ID == 181 || ID == 184 || ID == 185 || ID == 186 || ID == 187 || ID == 197 || ID == 200) then
			
			local stone = { Sound("minecraft/stone1.wav"),Sound("minecraft/stone2.wav"),Sound("minecraft/stone3.wav"),Sound("minecraft/stone4.wav") }
			self:EmitSound( table.Random( stone ), 511, math.random(60,100) )
			hasSound = true;
		end
		
		//wood
		if (ID == 25 || ID == 26 || ID == 27 || ID == 28 || ID == 29 || ID == 30 || ID == 31 || ID == 47 || ID == 54
			|| ID == 62 || ID == 64 || ID == 65 || ID == 66 || ID == 67 || ID == 77 || ID == 78 || ID == 55 || ID == 32
			|| ID == 72 || ID == 96 || ID == 97 || (ID >= 99 && ID <= 106) || (ID >= 89 && ID <= 93) || ID == 109
			|| (ID >= 135 && ID <= 171) || (ID >= 110 && ID <= 116) || ID == 188 || ID == 193 || ID == 194 || ID == 195 || ID == 199) then
			
			local wood = { Sound("minecraft/wood1.wav"),Sound("minecraft/wood2.wav"),Sound("minecraft/wood3.wav"),Sound("minecraft/wood4.wav") }
			self:EmitSound( table.Random( wood ), 511, math.random(60,100) )
			hasSound = true;
		end
		
		//gravel
		if (ID == 1 || ID == 3 || ID == 4) then
			local gravel = { Sound("minecraft/gravel1.wav"),Sound("minecraft/gravel2.wav"),Sound("minecraft/gravel3.wav"),Sound("minecraft/gravel4.wav") }
			self:EmitSound( table.Random( gravel ), 511, math.random(60,100) )
			hasSound = true;
		end
		
		//snow
		if (ID == 5 || ID == 17 || ID == 56) then
			local snow = { Sound("minecraft/snow1.wav"),Sound("minecraft/snow2.wav"),Sound("minecraft/snow3.wav"),Sound("minecraft/snow4.wav") }
			self:EmitSound( table.Random( snow ), 511, math.random(60,100) )
			hasSound = true;
		end
		
		//cloth
		if (ID == 79 || ID == 80 || ID == 35 || ID == 36) then
			local cloth = { Sound("minecraft/cloth1.wav"),Sound("minecraft/cloth2.wav"),Sound("minecraft/cloth3.wav"),Sound("minecraft/cloth4.wav") }
			self:EmitSound( table.Random( cloth ), 511, math.random(60,100) )
			hasSound = true;
		end
		
		//sand
		if (ID == 6 || ID == 20 || ID == 189) then
			local sand = { Sound("minecraft/sand1.wav"),Sound("minecraft/sand2.wav"),Sound("minecraft/sand3.wav"),Sound("minecraft/sand4.wav") }
			self:EmitSound( table.Random( sand ), 510, math.random(60,100))
			hasSound = true;
		end		
		
		//glass
		if (ID == 21 || ID == 22 || ID == 40 || ID == 61 || ID == 85 || ID == 182 || ID == 198) then
			local glass = { Sound("minecraft/glass_1.wav"),Sound("minecraft/glass_2.wav"),Sound("minecraft/glass_3.wav") }
			self:EmitSound( table.Random( glass ), 510, math.random(90,110))
			hasSound = true;
		end
		
		if (hasSound == false) then
			//if (GetConVar("minecraft_debug"):GetBool()) then print("blocks with ID = " .. tostring(ID) .. " have no remove sounds implemented!!!") end
		end
	end
	
	//update all nearby blocks
	local t1 = self:GetNearbyBlock( 1 );
	local t2 = self:GetNearbyBlock( 2 );
	local t3 = self:GetNearbyBlock( 3 );
	local t4 = self:GetNearbyBlock( 4 );
	local t5 = self:GetNearbyBlock( 5 );
	local t6 = self:GetNearbyBlock( 6 );
	
	if (t1 != nil) then
		if (t1:IsValid()) then
			t1:SetNetworkedBool("doUpdate", true);
			//remove torches if their base block is removed
			//HACKHACK: when deleting other blocks nearby, torches may also get removed
			//HACKHACK: I'm too lazy to fix that now
			if (notBlockToDestroy(ID)) then
			local ID2 = t1:GetBlockID()
			if (orBlockToDestroy(ID2)) then
				t1.Entity.health = -2
				t1:Remove()
			end
			end
		end
	end
	if (t2 != nil) then
		if (t2:IsValid()) then
			t2:SetNetworkedBool("doUpdate", true);
		end
	end
	if (t3 != nil) then
		if (t3:IsValid()) then
			t3:SetNetworkedBool("doUpdate", true);
			if (notBlockToDestroy(ID)) then
			local ID2 = t3:GetBlockID()
			if (orBlockToDestroy(ID2)) then
				t3.Entity.health = -2
				t3:Remove()
			end
			end
		end
	end
	if (t4 != nil) then
		if (t4:IsValid()) then
			t4:SetNetworkedBool("doUpdate", true);
			if (notBlockToDestroy(ID)) then
			local ID2 = t4:GetBlockID()
			if (orBlockToDestroy(ID2)) then
				t4.Entity.health = -2
				t4:Remove()
			end
			end
		end
	end
	if (t5 != nil) then
		if (t5:IsValid()) then
			t5:SetNetworkedBool("doUpdate", true);
			if (notBlockToDestroy(ID)) then
			local ID2 = t5:GetBlockID()
			if (orBlockToDestroy(ID2)) then
				t5.Entity.health = -2
				t5:Remove()
			end
			end
		end
	end
	if (t6 != nil) then
		if (t6:IsValid()) then
			t6:SetNetworkedBool("doUpdate", true);
			if (notBlockToDestroy(ID)) then
			local ID2 = t6:GetBlockID()
			if (orBlockToDestroy(ID2)) then
				t6.Entity.health = -2
				t6:Remove()
			end
			end
		end
	end
end

