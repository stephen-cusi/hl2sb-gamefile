//********************************//
//     Minecraft Block Entity     //
//			 (c) McKay			  //
//********************************//

ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.health			= 100
ENT.spawned 		= false
ENT.blockID			= 0

blockNewPanel = 1

//Setup datatable hook
function ENT:SetupDataTables()
    self:DTVar( "Int", 0, "blockID" )
	self:DTVar( "Int", 1, "rotation" )
	self:DTVar( "Bool", 1, "doUpdate" )
end

//Accessor Funcs
function ENT:GetBlockID( )
    return self.blockID
end

//*******************************************
//	CheckPos - check for block overlapping
//*******************************************

//will ignore block placement collision for blocks like torches, paintings, tripwires, items etc.
function ignoreBlockCollision( ID )
	if (ID != 66 && ID != 67 && ID != 68 && ID != 72 && ID != 82 && ID != 98 && ID != 109 && !(ID >= 110 && ID <= 116) && !(ID >= 135 && ID <= 171)) then
		return true
	else
		return false
	end
end

function ENT:CheckPos( ID )
	if (ignoreBlockCollision(ID)) then //not for torches, levers, ladders, vines, buttons, tripwires
		local bounds = 16;
		local pos = self:GetPos();
		pos.z = pos.z + 18.25; //center
		for k, v in pairs( ents.FindInBox( pos + Vector(-bounds,-bounds,-bounds), pos + Vector(bounds,bounds,bounds) ) ) do
			if ( v:IsValid() && v != self ) then
				if ( v:GetClass() == "minecraft_block") then
					if (CLIENT) then
					if (GetConVar("minecraft_debug"):GetBool()) then print("[" ..tostring(self.dt.blockID) .. "] would overlap with ID = " .. tostring(v.dt.blockID)) end
					end
					return false;
				end
				if ( v:GetClass() == "player") then
					if (v:GetMoveType() != MOVETYPE_NOCLIP) then
						if (CLIENT) then
						if (GetConVar("minecraft_debug"):GetBool()) then print("player is blocking the way!") end
						end
						return false
					else
						return true
					end
				end
			end
		end	
	end
	return true
end

//*******************************************
//	GetNearbyBlock
//*******************************************

function ENT:GetNearbyBlock( onSide )
	if ( onSide <= 0 || onSide > 6) then print("epic fail") return end
	//1 = top, 2 = bottom, 3 = front, 4 = back, 5 = left, 6 = right [when looking at a block in front of you and looking to the north!]
	
	local bounds = 15; //15
	local pos = self:GetPos();
	pos.z = pos.z + 18.25; //center
	if (onSide == 1) then
		pos.z = pos.z + 36.5
	end
	if (onSide == 2) then
		pos.z = pos.z - 36.5;
	end
	if (onSide == 3) then
		pos.x = pos.x + 36.5;
	end
	if (onSide == 4) then
		pos.x = pos.x - 36.5;
	end
	if (onSide == 5) then
		pos.y = pos.y - 36.5;
	end
	if (onSide == 6) then
		pos.y = pos.y + 36.5;
	end
	for k, v in pairs( ents.FindInBox( pos + Vector(-bounds,-bounds,-bounds), pos + Vector(bounds,bounds,bounds) ) ) do
		if ( v:IsValid() && v != self ) then
			if ( v:GetClass() == "minecraft_block" || v:GetClass() == "minecraft_block_waterized") then
				//if (GetConVar("minecraft_debug"):GetBool()) then print("[" ..tostring(self.dt.blockID) .. "] found nearby block with ID = " .. tostring(v:GetBlockID())) end
				return v;
			end
		end
	end
	//test tracer for detecting world geometry
	//local tracelength = self:GetPlayer():GetInfoNum("minecraft_water_worldcollision_trl",12.5);
	local tracelength = 12.5
	local endpos = pos;
	endpos.z = endpos.z - tracelength; //i have to use fixed values again fffffffuuuuuuuUUUUUUUUUUUU; why is 18.25 exactly 1 block too high??!
	local tracedata = {}
	tracedata.start = pos
	tracedata.endpos = endpos
	tracedata.filter = self.Owner
	local trace = util.TraceLine( tracedata )
	if (trace.HitWorld) then
		return NULL
	else
		return nil
	end
	//and check all 4 sides
	endpos = pos;
	endpos.x = endpos.x - tracelength;
	tracedata.endpos = endpos;
	trace = util.TraceLine( tracedata )
	if (trace.HitWorld) then
		return NULL
	else
		return nil
	end
	
	endpos = pos;
	endpos.x = endpos.x + tracelength;
	tracedata.endpos = endpos;
	trace = util.TraceLine( tracedata )
	if (trace.HitWorld) then
		return NULL
	else
		return nil
	end
	
	endpos = pos;
	endpos.y = endpos.y - tracelength;
	tracedata.endpos = endpos;
	trace = util.TraceLine( tracedata )
	if (trace.HitWorld) then
		return NULL
	else
		return nil
	end
	
	endpos = pos;
	endpos.y = endpos.y + tracelength;
	tracedata.endpos = endpos;
	trace = util.TraceLine( tracedata )
	if (trace.HitWorld) then
		return NULL
	else
		return nil
	end
end

//*******************************************
//					Think 
//*******************************************

//all blockIDs in here will be ignored by grass blocks (won't change to dirt)
function ignoreGrassTopBlock( ID2 )
	if (ID2 != 55 && ID2 != 70 && ID2 != 56 && ID2 != 17 && ID2 != 82) && ( !(ID2 >= 59 && ID2 <= 68) && !(ID2 >= 72 && ID2 <= 76) && !(ID2 >= 95 && ID2 <= 106) && !(ID2 >= 87 && ID2 <= 91) && !(ID2 >= 109)) then
		return true
	else 
		return false
	end
end

function ENT:Think( )
	if (CLIENT) then return end
	if (self:GetNetworkedBool("doUpdate") == true) then
		local ID = self.dt.blockID;
		/*
		if (SERVER) then
			if (GetConVar("minecraft_debug"):GetBool()) then print("["..tostring(ID).."] update... (server)") end
		else
			if (GetConVar("minecraft_debug"):GetBool()) then print("["..tostring(ID).."] update... (client)") end
		end
		*/
	
		//intelligent grass blocks
		if (ID == 2) then
			local temp = self:GetNearbyBlock( 1 )
			if (temp != nil) then //if there is a block on top of me
				local ID2 = 0;
				//if (GetConVar("minecraft_debug"):GetBool()) then print("["..tostring(ID).."] detected block with ID = "..tostring(ID2).." on top") end
				//have to check for waterized blocks manually, because GetBlockID() doesn't seem to work properly
				local check = true
				if (temp:GetClass() == "minecraft_block_waterized") then
					if (temp:GetNWString("water") == "true") then
						check = false
					end
				else
					if (temp:GetClass() == "minecraft_block") then
						ID2 = temp:GetBlockID()
					end
				end
				if (temp:IsValid()) then
					//create snowy grass blocks if a snow layer is placed on top
					if ( ID2 == 56 || ID2 == 17 ) then
						self:SetSkin( 1 );
					else
						if ( ignoreGrassTopBlock(ID2) && check) then
							self:SetModel( "models/MCModelPack/blocks/dirt.mdl" );
							self.dt.blockID = 1;
						
							if (SERVER) then //don't want this message twice
								//if (GetConVar("minecraft_debug"):GetBool()) then print("grass will now turn magically into dirt") end
							end
						end
					end
				end
			end
			
			self:SetNetworkedBool("doUpdate",false);
		end
		
		//vines spread
		if (ID == 82 && SERVER && GetCSConVarB( "minecraft_vines_grow", self:GetPlayer() ) && self.spawned ) then
			if ( GetConVar( "minecraft_swep_enable_water_spread" ):GetBool() ) then
			if (CurTime() > self.growtime) then
				self.growtime = CurTime() + GetCSConVarF( "minecraft_vines_growspeed", self:GetPlayer() );
				
				//fake position for a very short time to get the correct GetNearbyBlock() results!
				local spos = self:GetPos();
				local sposbackup = self:GetPos();
				local check = false
				//print("p = "..tostring(self:GetAngles().p)..", y = "..tostring(self:GetAngles().y)..", r = "..tostring(self:GetAngles().r))
				if (self:GetAngles() == Angle( 0,0,0 ) ) then
					spos.x = spos.x + 18;
					check = true
				end
				if (self:GetAngles().y == 90) then
					spos.y = spos.y + 18;
					check = true
				end
				if (self:GetAngles() == Angle( 0,-90,0) ) then 
					spos.y = spos.y - 18;
					check = true
				end
				//Gmod seems to alternate between 180 and -180, I have no idea why this happens! (even though ent:SetAngles( self:GetAngles() ) !)
				//this took me 2 fucking hours to figure out
				if ( self:GetAngles() == Angle( 0,180,0) || self:GetAngles() == Angle( 0,-180,0) ) then
					spos.x = spos.x - 18;
				end
				
				//two different checks for any blocks under this one
				self:SetPos( spos );
				local temp = self:GetNearbyBlock( 2 )
				self:SetPos( sposbackup );
				local temp2 = self:GetNearbyBlock( 2 )
				local check2 = true
				if (temp2 != nil && temp2 != NULL) then
					if (temp2.dt.blockID == ID) then
						check2 = false
					end
				end
				
				if (temp == nil && check2) then //if there is no block under me (and also no world geometry)
					local ent = ents.Create( "minecraft_block" )
					ent:SetAngles( self:GetAngles() )
					local pos = self:GetPos();
					pos.z = pos.z - 36.5;
				
					//the order of the following functions is important!
					ent:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER );
					ent:SetKeyValue( "DisableShadows", "1" )
					ent:SetKeyValue( "targetname", "mcblock" )
					ent:SetModel( "models/MCModelPack/other_blocks/vines.mdl" );
					ent:SetPlayer( self:GetPlayer() )
					ent:SetPos( pos );
					ent:SetBlockID( ID )
					ent:OnSpawn( ID, self )
					ent:SetNetworkedBool("doUpdate",true)
					ent:Spawn()
				end
			
				self:SetNetworkedBool("doUpdate",false);
			end
			end
		end
		
		//TODO: add more
		
		//HACKHACK: temporary solution to keep blocks with nothing here from thinking
		if (ID != 82 && ID != 2 && ID != 69) then
			self:SetNetworkedBool("doUpdate",false);
		end
	end
end

//***********************************************
//	BlockInit - special block behaviour on spawn
//***********************************************

function ENT:BlockInit( ID , hitEntity )
	if (CLIENT) then
	if (GetConVar("minecraft_debug"):GetBool()) then print("block spawned with ID = " .. tostring(ID)) end
	if (GetConVar("minecraft_debug"):GetBool()) then print("tracer hit " .. tostring(hitEntity:GetClass())) end
	end
	
	//are we spawning on another block?
	local onBlock = false
	if (!hitEntity:IsWorld() && hitEntity:GetClass() == "minecraft_block") then
		onBlock = true
		if (CLIENT) then
		if (GetConVar("minecraft_debug"):GetBool() == 2) then print("onBlock = true!") end
		end
	end

	//get the view direction (1 = North, 2 = East, 3 = South, 4 = West)
	//I hereby declare that North is the direction you are facing in gm_construct on spawn
	local viewdir = -1
	local tr = self.Owner:GetEyeTrace()
	local hitpos = tr.HitPos - self.Owner:GetPos()
	if (CLIENT) then
	if (GetConVar("minecraft_debug"):GetBool() == 2) then print("hitpos.x = ".. tostring(hitpos.x) .. " hitpos.y = ".. tostring(hitpos.y)) end
	end
	local startpos = tr.StartPos - self.Owner:GetPos()
	local rotpoint = RotatePoint2D( hitpos, startpos, 45 ) //rotate the "compass rose" by 45 degrees
	local thevector = rotpoint - startpos
	if (CLIENT) then
	if (GetConVar("minecraft_debug"):GetBool() == 2) then print("posx = " .. tostring(thevector.x)) end
	if (GetConVar("minecraft_debug"):GetBool() == 2) then print("posy = " .. tostring(thevector.y)) end
	end
	if (thevector.x < 0 && thevector.y > 0) then
		if (CLIENT) then
		if (GetConVar("minecraft_debug"):GetBool()) then print("player -> North") end
		end
		viewdir = 1
	end
	if (thevector.x > 0 && thevector.y > 0) then
		if (CLIENT) then
		if (GetConVar("minecraft_debug"):GetBool()) then print("player -> East") end
		end
		viewdir = 2
	end
	if (thevector.x > 0 && thevector.y < 0) then
		if (CLIENT) then
		if (GetConVar("minecraft_debug"):GetBool()) then print("player -> South") end
		end
		viewdir = 3
	end
	if (thevector.x < 0 && thevector.y < 0) then
		if (CLIENT) then
		if (GetConVar("minecraft_debug"):GetBool()) then print("player -> West") end
		end
		viewdir = 4
	end
	
	//on which of the possible 6 sides of an already existing block are we spawning?
	//1 = top, 2 = bottom, 3 = front, 4 = back, 5 = left, 6 = right [when looking at a block in front of you and looking to the north!]
	local onSide = -1
	if (onBlock == true) then
		if (CLIENT) then
		if (GetConVar("minecraft_debug"):GetBool() == 2) then print("self:GetPos() -> x = " .. tostring(self:GetPos().x) .. " ; y = " .. tostring(self:GetPos().y) .. " ; z = " .. tostring(self:GetPos().z)) end
		if (GetConVar("minecraft_debug"):GetBool() == 2) then print("hitE:GetPos() -> x = " .. tostring(hitEntity:GetPos().x) .. " ; y = " .. tostring(hitEntity:GetPos().y) .. " ; z = " .. tostring(hitEntity:GetPos().z)) end
		end
		local selfX = self:GetPos().x;
		local selfY = self:GetPos().y;
		local selfZ = self:GetPos().z;
		local hitX = hitEntity:GetPos().x;
		local hitY = hitEntity:GetPos().y;
		local hitZ = hitEntity:GetPos().z;
		if (selfX == hitX && selfY == hitY && selfZ > hitZ) then
			onSide = 1;
			if (CLIENT) then
			if (GetConVar("minecraft_debug"):GetBool()) then print("top") end
			end
		end
		if (selfX == hitX && selfY == hitY && selfZ < hitZ) then
			onSide = 2;
			if (CLIENT) then
			if (GetConVar("minecraft_debug"):GetBool()) then print("bottom") end
			end
		end
		if (selfX > hitX && selfY == hitY) then
			onSide = 3
			if (CLIENT) then
			if (GetConVar("minecraft_debug"):GetBool()) then print("front") end
			end
		end
		if (selfX < hitX && selfY == hitY) then
			onSide = 4
			if (CLIENT) then
			if (GetConVar("minecraft_debug"):GetBool()) then print("back") end
			end
		end
		if (selfX == hitX && selfY < hitY) then
			onSide = 5
			if (CLIENT) then
			if (GetConVar("minecraft_debug"):GetBool()) then print("left") end
			end
		end
		if (selfX == hitX && selfY > hitY) then
			onSide = 6
			if (CLIENT) then
			if (GetConVar("minecraft_debug"):GetBool()) then print("right") end
			end
		end
	end
	
	
	//***************************************//
	//		Global Per-Block Variables  	 //
	//***************************************//
	
	self.isPowered = false;
	self.isPowerSource = false;
	
	
	//fix wall sign spawn height
	if ( ID == 65 ) then
		local pos = self:GetPos()
		pos.z = pos.z + (18.25/2)
		self:SetPos( pos )
	end
	
	//fix ender crystal spawn height
	if ( ID == 198 ) then
		local pos = self:GetPos()
		pos.z = pos.z + (75.00/2)
		self:SetPos( pos )
	end
	
	//fix frame spawn height
	if ( ID == 188 ) then
		local pos = self:GetPos()
		pos.z = pos.z + (12.25/2)
		self:SetPos( pos )
	end
	
	//auto rotate furnaces, dispensers, stairs, chests, pumpkins, beds, rails, portals, iron bars, glas panes to face the player on spawn
	if ( ID == 24 || ID == 23 || ID == 45 || ID == 46 || ID == 47 || ID == 77 || ID == 25 
				  || ID == 34 || ID == 78 || ID == 73 || ID == 74 || ID == 75 || ID == 76
				  || ID == 59 || ID == 60 || ID == 61 || ID == 92 || ID == 93 || ID == 94
				  || ID == 181 || ID == 188 || ID == 179 || ID == 199 || ID == 189 || ID == 192 || ID == 198 ) then
		self:SetAngles( Angle( 0, -90*(viewdir-1), 0 ) )
	end
	
	//auto rotate side-hopper
	if ( ID == 178 ) then
		if (viewdir == 1 || viewdir == 3) then
			self:SetAngles( Angle( 0, 90*(viewdir+1), 0 ) )
		else
			self:SetAngles( Angle( 0, 90*(viewdir-1), 0 ) )
		end
	end
	
	//auto rotate fences
	if ( ID == 99 || ID == 100 || ID == 101 || ID == 102 || ID == 103 || ID == 195) then
		self:SetAngles( Angle( 0, -90*(viewdir), 0 ) )
	end
	
	//auto rotate fence gates
	if (ID == 104 || ID == 105) then
		self:SetAngles(  Angle( 0, -90*(viewdir-1), 0 ) )
	end
	
	//auto rotate wall signs and buttons, stick, and ALL items to other blocks
	if ( ID == 65 || ID == 98 || ID == 109 || (ID >= 110 && ID <= 116) || (ID >= 135 && ID <= 171) || ID == 188 || ID == 193 || ID == 194) then
		if ( (ID == 98 || ID == 109 || (ID >= 110 && ID <= 116) || (ID >= 135 && ID <= 171) || ID == 188 || ID == 193 || ID == 194) && onBlock ) then
			self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER );
			local moveValueZ = 16
			local moveValueX = 0
			local moveValueY = 0
			if (ID == 109) then //tripwires
				moveValueZ = 18.5
			end
			if (ID == 110 || ID == 193) then //paintings
				moveValueZ = 16.5
			end
			if (ID == 188) then //paintings
				moveValueZ = 16.5
			end
			if (ID >= 111) then //paintings
				moveValueZ = 17.5
			end
			if (ID == 111) then
				moveValueX = -14
			end
			if (ID == 113) then
				moveValueX = -14
				moveValueY = 2
			end
			if (ID == 114) then
				moveValueX = -18
				moveValueY = 1
			end
			if (ID == 115) then
				moveValueX = -18.5
				moveValueY = 0
				moveValueZ = 17
			end
			if (ID == 116) then
				moveValueX = -18
				moveValueY = 4
			end
			if (onSide == 3) then
				//print("onSide = 3!")
				self:SetPos( self:GetPos() + Vector(-moveValueZ, moveValueX, moveValueY) )
			end
			if (onSide == 4) then
				//print("onSide = 4!")
				self:SetPos( self:GetPos() + Vector( moveValueZ, moveValueX, moveValueY) )
			end
			if (onSide == 5) then
				//print("onSide = 5!")
				self:SetPos( self:GetPos() + Vector( moveValueX, moveValueZ, moveValueY) )
			end
			if (onSide == 6) then
				//print("onSide = 6!")
				self:SetPos( self:GetPos() + Vector( moveValueX, -moveValueZ, moveValueY) ) 
			end
		end
		if (ID >= 135 && ID <= 171) then //special case: item height
			self:SetPos( self:GetPos() + Vector(0,0,18) )
		end
		if (ID == 193) then //special case: item height
			self:SetPos( self:GetPos() + Vector(0,0,18) )
		end
		if (ID == 194) then //special case: item height
			self:SetPos( self:GetPos() + Vector(0,0,18) )
		end
		if (onBlock) then
			if (onSide == 4) then
				self:SetAngles( Angle( 0, -90*2, 0 ) )
			end
			if (onSide == 5) then
				self:SetAngles( Angle( 0, -90, 0 ) )
			end
			if (onSide == 6) then
				self:SetAngles( Angle( 0, -90*3, 0 ) )
			end
		else
			self:SetAngles( Angle( 0, -90*(viewdir-1), 0 ) )
		end
	end
	
	//auto rotate dooors, set correct position
	if (ID == 62 || ID == 63) then
		if (viewdir == 2 || viewdir == 4) then
			self:SetAngles( Angle(0 , 90 , 0) )
		end
		local pos = self:GetPos();
		//local min,max = self:WorldSpaceAABB();       doesn't work because
		//local halfwidth = math.abs(min.x - max.x)/2; the bounding box sadly is a tiny teeny bit bigger than the actual model
		//HACKHACK: I hate having to use fixed values determined by testing with convars
		local halfwidth = 3.4
		if (viewdir == 1) then
			pos.x = pos.x + 18.25 - halfwidth;
		end
		if (viewdir == 2) then
			pos.y = pos.y - 18.25 + halfwidth;
		end
		if (viewdir == 3) then
			pos.x = pos.x - 18.25 + halfwidth;
		end
		if (viewdir == 4) then
			pos.y = pos.y + 18.25 - halfwidth;
		end
		self:SetPos( pos )
	end
	
	//auto rotate signs to always face the player (like in minecraft)
	if (ID == 64) then
		local base = Vector( -1, 0, 0 ) //North vector
		local thevector = self:GetPos() - self.Owner:GetPos()
		local angle = GetAngleBetweenVectors( base, thevector )
		if (CLIENT) then
		if (GetConVar("minecraft_debug"):GetBool()) then print("angle = " .. tostring(angle)) end
		end
		self:SetAngles( Angle( 0, angle, 0) )
	end
	
	//rotate all 2.5d sprites 45 degrees (saplings, shrubs, sugar cane, mushrooms, flowers, grass, plants, cobweb), disable player collisions
	if (ID == 70 || ID == 190 || ID == 191 || ID == 109 || ID == 173 || ID == 172) then
		self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER );
		self:SetAngles( Angle( 0,45,0 ) )
	end
	
	//auto rotate ladders, stick to other blocks
	if (ID == 72) then
		if (onBlock) then
			if (onSide == 4) then
				self:SetAngles( Angle( 0,-90*2,0) )
			end
			if (onSide == 5) then
				self:SetAngles( Angle( 0,-90,0) )
			end
			if (onSide == 6) then
				self:SetAngles( Angle( 0,-90*3,0) )
			end
		else
			self:SetAngles( Angle( 0,-90*(viewdir-1),0) )
		end
	end
	
	//auto rotate redstone repeaters
	if (ID == 57 || ID == 58 || (ID >= 118 && ID <= 120) || (ID >= 124 && ID <= 130)) then
		if (viewdir == 2 || viewdir == 4) then
			self:SetAngles( Angle( 0, 90*(viewdir-1), 0) )
		else
			self:SetAngles( Angle( 0, 90*(viewdir+1), 0) )
		end
	end
	
	//auto rotate new quartz redstone blocks
	if (ID == 174 || ID == 175 || ID == 176) then
			if (viewdir == 2 || viewdir == 4) then
			self:SetAngles( Angle( 0, 90*(viewdir-3), 0) )
		else
			self:SetAngles( Angle( 0, 90*(viewdir+3), 0) )
		end	
	end
	
	//intelligently place torches, auto rotation and positioning ; also set special collision group
	if (ID == 66 || ID == 67) then
		self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER );
		local torchAngle = 20;
		if (onSide == 3) then //front
			local pos = self:GetPos();
			pos.x = pos.x - 18.25;
			pos.z = pos.z + (18.25/2);
			self:SetPos( pos );
			self:SetAngles( Angle( torchAngle, 0, 0) )
		end
		if (onSide == 4) then //back
			local pos = self:GetPos();
			pos.x = pos.x + 18.25;
			pos.z = pos.z + (18.25/2);
			self:SetPos( pos );
			self:SetAngles( Angle( -torchAngle, 0, 0) )
		end
		if (onSide == 5) then //left
			local pos = self:GetPos();
			pos.y = pos.y + 18.25;
			pos.z = pos.z + (18.25/2);
			self:SetPos( pos );
			self:SetAngles( Angle( -torchAngle, 90, 0) )
		end
		if (onSide == 6) then //right
			local pos = self:GetPos();
			pos.y = pos.y - 18.25;
			pos.z = pos.z + (18.25/2);
			self:SetPos( pos );
			self:SetAngles( Angle( torchAngle, 90, 0) )
		end
	end
	
	//and the same with levers
	if (ID == 68) then
		self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER );
		local leverAngle = 90;
		if (onSide == 3) then //front
			local pos = self:GetPos();
			pos.x = pos.x - 18.25;
			pos.z = pos.z + 18.25;
			self:SetPos( pos );
			self:SetAngles( Angle( leverAngle, 0, 0) )
		end
		if (onSide == 4) then //back
			local pos = self:GetPos();
			pos.x = pos.x + 18.25;
			pos.z = pos.z + 18.25;
			self:SetPos( pos );
			self:SetAngles( Angle( -leverAngle, 0, 0) )
		end
		if (onSide == 5) then //left
			local pos = self:GetPos();
			pos.y = pos.y + 18.25;
			pos.z = pos.z + 18.25;
			self:SetPos( pos );
			self:SetAngles( Angle( -leverAngle, 90, 0) )
		end
		if (onSide == 6) then //right
			local pos = self:GetPos();
			pos.y = pos.y - 18.25;
			pos.z = pos.z + 18.25;
			self:SetPos( pos );
			self:SetAngles( Angle( leverAngle, 90, 0) )
		end
	end	
	
	//tnt blocks
	if (ID == 39) then
		if (self:CheckPos(ID)) then
		local thetnt = ents.Create( "mc_tnt" )
		thetnt:SetPos( self:GetPos() )
		thetnt:SetKeyValue( "DisableShadows", "1" )
		thetnt:SetKeyValue( "targetname", "mcblock" )
		thetnt:SetPlayer( self:GetPlayer() ) 
		thetnt:Spawn()
		local phys = thetnt:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:EnableMotion( false ) //freeze the block
			phys:Wake()
		end
		self:Remove()
		end
	end
	
	//cake 
	if (ID == 48) then
		if (self:CheckPos(ID)) then
		local ent = ents.Create( "mc_cake" )
		ent:SetPos( self:GetPos() )
		ent:SetKeyValue( "DisableShadows", "1" )
		ent:SetKeyValue( "targetname", "mcblock" )
		ent:SetPlayer( self.Owner )
		ent:Spawn()
		local phys = ent:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:EnableMotion( false )
			phys:Wake()
		end
		self:Remove()
		end
	end
	
	//auto rotation of glass panes, iron bars, portals, fence-2 if they are spawning touching already existing ones
	if (ID == 59 || ID == 60 || ID == 61 || ID == 100) then
		if (onBlock) then
			if (hitEntity.dt.blockID == ID) then
				self:SetAngles( hitEntity:GetAngles() );
			end
		else
			local t1 = self:GetNearbyBlock(1);
			local t2 = self:GetNearbyBlock(2);
			local t3 = self:GetNearbyBlock(3);
			local t4 = self:GetNearbyBlock(4);
			local t5 = self:GetNearbyBlock(5);
			local t6 = self:GetNearbyBlock(6);
			if (t1 != nil) then
				if (t1:GetBlockID() == ID) then
					self:SetAngles( t1:GetAngles() )
				end
			end
			if (IsValid(t2)) then
				if (t2:GetBlockID() == ID) then
					self:SetAngles( t2:GetAngles() )
				end
			end
			if (IsValid(t3)) then
				if (t3:GetBlockID() == ID) then
					self:SetAngles( t3:GetAngles() )
				end
			end
			if (IsValid(t4)) then
				if (t4:GetBlockID() == ID) then
					self:SetAngles( t4:GetAngles() )
				end
			end
			if (IsValid(t5)) then
				if (t5:GetBlockID() == ID) then
					self:SetAngles( t5:GetAngles() )
				end
			end
			if (IsValid(t6)) then
				if (t6:GetBlockID() == ID) then
					self:SetAngles( t6:GetAngles() )
				end
			end
		end
	end
	
	//intelligently rotate vines
	if (ID == 82) then
		self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER );
		local pos = self:GetPos();
		if (onBlock) then
			if (onSide == 3) then
				pos.x = pos.x - 18;
			end
			if (onSide == 4) then
				self:SetAngles( Angle( 0,-90*2,0) )
				pos.x = pos.x + 18;
			end
			if (onSide == 5) then
				self:SetAngles( Angle( 0,-90,0) )
				pos.y = pos.y + 18;
			end
			if (onSide == 6) then
				self:SetAngles( Angle( 0,90,0) )
				pos.y = pos.y - 18;
			end
			self:SetPos( pos );
		else
			self:SetAngles( Angle( 0,-90*(viewdir-1),0) )
			if (viewdir == 1) then
				pos.x = pos.x - 18;
			end
			if (viewdir == 2) then
				pos.y = pos.y + 18;
			end
			if (viewdir == 3) then
				pos.x = pos.x + 18;
			end
			if (viewdir == 4) then
				pos.y = pos.y - 18;
			end
			self:SetPos( pos );
		end
	end
	
	//flip stairs
	if ( (ID == 45 || ID == 46 || ID == 47 || ID == 181) && GetCSConVarB( "minecraft_flipstairs", self.Owner )) then
		self:SetAngles( self:GetAngles() + Angle(0,0,180) )
		self:SetPos( self:GetPos() + Vector(0,0,36.5) );
	end
	
	//flip logs, if flipped also auto rotate
	if ( (ID == 31 || ID == 200) && GetCSConVarB( "minecraft_fliplogs", self.Owner ) ) then
		self:SetAngles( self:GetAngles() + Angle(0,0,90) + Angle( 0,-90*(viewdir),0))
		if (viewdir == 1) then
			self:SetPos( self:GetPos() + Vector(18.25,0,18.25) )
		end
		if (viewdir == 2) then
			self:SetPos( self:GetPos() + Vector(0,-18.25,18.25) )
		end
		if (viewdir == 3) then
			self:SetPos( self:GetPos() + Vector(-18.25,0,18.25) )
		end
		if (viewdir == 4) then
			self:SetPos( self:GetPos() + Vector(0,18.25,18.25) )
		end
	end
	
	//place the cauldron just a teeny bit higher so we don't get z-fighting on the ground vertices
	if ( ID == 88 ) then
		self:SetPos( self:GetPos() + Vector(0,0,0.1) )
	end
	
	//auto rotate cocoa beans
	if ( ID >= 89 && ID <= 91 ) then
		self:SetAngles( Angle( 0,-90*(viewdir-1),0) )
		local addHeight = 4;
		if (ID == 91) then
			addHeight = 4
		end
		if (ID == 89) then
			addHeight = 8
		end
		if (ID == 90) then
			addHeight = 6
		end
		self:SetPos( self:GetPos() + Vector(0,0,addHeight) )
	end
	
	//fix spawn height of crops, carrots, tree saplings etc.
	if ( ID == 70 || ID == 71 || ID == 123 || ID == 172 || ID == 173 || ID == 190 || ID == 191 ) then
		self:SetPos( self:GetPos() + Vector(0,0,2.21) )
	end
	
	//stack slabs
	if ( (ID >= 49 && ID <= 54) || ID == 107 || ID == 180 ) then
		self.isSlabStacked = false
		if (onSide == 1) then
			local t1 = self:GetNearbyBlock(2);
			if (t1 != nil) then
				if (t1.isSlabStacked != nil) then
					if (t1.isSlabStacked == false) then
						self:SetPos( self:GetPos() + Vector(0,0,-18.255) )
						self.isSlabStacked = true
					end
				end
			end
		end
	end
	
	//normal sign 
	if (ID == 64) then
		if (self:CheckPos(ID)) then
		local ent = ents.Create( "minecraft_sign" )
		ent:SetPos( self:GetPos() )
		
			//orient facing the player
			//HACKHACK: code duplication!
			local base = Vector( -1, 0, 0 ) //North vector
			local thevector = self:GetPos() - self.Owner:GetPos()
			local angle = GetAngleBetweenVectors( base, thevector )
			ent:SetAngles( Angle( 0, angle, 0) )
			
		ent:SetKeyValue( "DisableShadows", "1" )
		ent:SetKeyValue( "targetname", "mcblock" )
		ent:Spawn()
		local phys = ent:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:EnableMotion( false )
			phys:Wake()
		end
		self:Remove()
		end
	end
	
	//wall sign 
	if (ID == 65) then
		if (self:CheckPos(ID)) then
		local ent = ents.Create( "minecraft_wall_sign" )
		ent:SetPos( self:GetPos() )
		ent:SetAngles( self:GetAngles() )
		ent:SetKeyValue( "DisableShadows", "1" )
		ent:SetKeyValue( "targetname", "mcblock" )
		ent:Spawn()
		local phys = ent:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:EnableMotion( false )
			phys:Wake()
		end
		self:Remove()
		end
	end
	
	//****************************//
	//		Special blocks 		  //
	//****************************//
	
	//create member variables used by doors and trapdoors, also rotate doors to always face the player
	if ( ID == 55 || ID == 62 || ID == 63 ) then
		self:SetAngles( Angle( 0,-90*(viewdir-1),0) )
		self.isDoorOpen = false
		self.doorAngle = Angle(0,0,0)
	end
end

//*****************************************************************
//	PhysicsCollide + Use
//*****************************************************************

function ENT:PhysicsCollide( data, physobj )
	if (data.HitEntity:IsWorld() || data.HitEntity:GetClass() == "minecraft_block" || data.HitEntity:GetClass() == "minecraft_block_waterized") then return end
	
	//when running into cactus blocks, deal damage!
	if (self.dt.blockID == 32) then
		data.HitEntity:TakeDamage( 15, data.HitEntity, self )
	end
	
	if (self.dt.blockID == 69) then
		data.HitEntity:Ignite(5,0);
	end
	
	//TODO: add moar
end

function ENT:StartTouch( ent )
	if (self.dt.blockID == 69) then
		ent:Ignite(5,0);
	end
end

function ENT:Use( activator, caller )
	if ( activator:IsPlayer() ) then
		local ID = self:GetBlockID()
		
		//open/close doors
		if ( ID == 62 || ID == 63 ) then
			self:updateDoors( !self.isDoorOpen )
		end
		
		//open/close trapdoors
		if ( ID == 55 ) then
			local curAngle = self:GetAngles()
			if ( !self.isDoorOpen ) then
				self:EmitSound( Sound("minecraft/door_open.wav") )
				self.doorAngle = self:GetAngles()
				self:SetAngles( curAngle + Angle(90,0,0) )
				self:SetPos( self:GetPos() + curAngle:Forward() * Vector(-18.25,-18.25,-18.25) + curAngle:Up() * Vector(18.25,18.25,18.25) )
				self.isDoorOpen = true
				if ( GetCSConVarB( "minecraft_doors_disablecollision", self:GetPlayer() ) == true ) then
					self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER );
				end
			else
				self:EmitSound( Sound("minecraft/door_close.wav") )
				self:SetAngles( self.doorAngle )
				self:SetPos( self:GetPos() + self.doorAngle:Forward() * Vector(18.25,18.25,18.25)  + self.doorAngle:Up() * Vector(-18.25,-18.25,-18.25) )	
				self.isDoorOpen = false
				if ( GetCSConVarB( "minecraft_doors_disablecollision", self:GetPlayer() ) == true ) then
					self:SetCollisionGroup( 0 )
				end
			end
		end
		
		//buttons
		if ( ID == 98 ) then
			if (!self.isPowered) then
				self.isPowered = true
				self:EmitSound( Sound("minecraft/click.wav") )
				updateBlocksAround( self )
				timer.Simple( 1, function() if (IsValid(self)) then
											self.isPowered = false 
											self:EmitSound( Sound("minecraft/click.wav") ); 
											updateBlocksAround( self )
											end
								 end )
			end
		end
	end
end

function ENT:updateDoors( open )
	local curAngle = self:GetAngles()
	if ( open == true ) then
		self:EmitSound( Sound("minecraft/door_open.wav") )
		self.doorAngle = self:GetAngles()
		self:SetAngles( curAngle + Angle(0,90,0) )
		self:SetPos( self:GetPos() + curAngle:Right() * Vector(14.83, 14.83, 14.83) + curAngle:Forward() * Vector(-14.83,-14.83,-14.83) )
		self.isDoorOpen = true
		if ( GetCSConVarB( "minecraft_doors_disablecollision", self:GetPlayer() ) == true ) then
			self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER );
		end
	else
		self:EmitSound( Sound("minecraft/door_close.wav") )
		self:SetAngles( self.doorAngle )
		self:SetPos( self:GetPos() + self.doorAngle:Right() * Vector(-14.83, -14.83, -14.83) + self.doorAngle:Forward() * Vector(14.83,14.83,14.83) )	
		self.isDoorOpen = false
		if ( GetCSConVarB( "minecraft_doors_disablecollision", self:GetPlayer() ) == true ) then
			self:SetCollisionGroup( 0 )
		end
	end
end

//***************************************
//	Random helper functions
//***************************************

function updateBlocksAround( block )
		local t1 = block:GetNearbyBlock(1);
		local t2 = block:GetNearbyBlock(2);
		local t3 = block:GetNearbyBlock(3);
		local t4 = block:GetNearbyBlock(4);
		local t5 = block:GetNearbyBlock(5);
		local t6 = block:GetNearbyBlock(6);
		if (IsValid(t1)) then
			t1:SetNetworkedBool("doUpdate",true);
		end
		if (IsValid(t2)) then
			t2:SetNetworkedBool("doUpdate",true);
		end
		if (IsValid(t3)) then
			t3:SetNetworkedBool("doUpdate",true);
		end
		if (IsValid(t4)) then
			t4:SetNetworkedBool("doUpdate",true);
		end
		if (IsValid(t5)) then
			t5:SetNetworkedBool("doUpdate",true);
		end
		if (IsValid(t6)) then
			t6:SetNetworkedBool("doUpdate",true);
		end	
end

function isPowerBlockAround( block )
	local t1 = block:GetNearbyBlock(1);
	if (IsValid(t1)) then
		if (t1.isPowerSource) then return true end
	end
	
	local t2 = block:GetNearbyBlock(2);
	if (IsValid(t2)) then
		if (t2.isPowerSource) then return true end
	end
	
	local t3 = block:GetNearbyBlock(3);
	if (IsValid(t3)) then
		if (t3.isPowerSource) then return true end
	end
	
	local t4 = block:GetNearbyBlock(4);
	if (IsValid(t4)) then
		if (t4.isPowerSource) then return true end
	end
	
	local t5 = block:GetNearbyBlock(5);
	if (IsValid(t5)) then
		if (t5.isPowerSource) then return true end
	end
	
	local t6 = block:GetNearbyBlock(6);
	if (IsValid(t6)) then
		if (t6.isPowerSource) then return true end
	end	
	return false
end

function isPoweredBlockAround( block )
	local t1 = block:GetNearbyBlock(1);
	if (IsValid(t1)) then
		if (t1.isPowered) then return true end
	end
	
	local t2 = block:GetNearbyBlock(2);
	if (IsValid(t2)) then
		if (t2.isPowered) then return true end
	end
	
	local t3 = block:GetNearbyBlock(3);
	if (IsValid(t3)) then
		if (t3.isPowered) then return true end
	end
	
	local t4 = block:GetNearbyBlock(4);
	if (IsValid(t4)) then
		if (t4.isPowered) then return true end
	end
	
	local t5 = block:GetNearbyBlock(5);
	if (IsValid(t5)) then
		if (t5.isPowered) then return true end
	end
	
	local t6 = block:GetNearbyBlock(6);
	if (IsValid(t6)) then
		if (t6.isPowered) then return true end
	end	
	return false
end

function RotatePoint2D( toRotate, Anchor, Angle )
	local radians = -Angle*(math.pi/180); //convert degrees to radians
	local xdiff = toRotate.x-Anchor.x;
	local ydiff = toRotate.y-Anchor.y;                                                                        
	return Vector(math.cos(radians)*xdiff-math.sin(radians)*ydiff+Anchor.x,math.sin(radians)*xdiff+math.cos(radians)*ydiff+Anchor.y,0);
end

function GetAngleBetweenVectors( vector1, vector2 )
	vector1.z = 0;
	vector2.z = 0;
	local temp1 = vector1:Dot( vector2 );
	local temp2 = vector1:Length() * vector2:Length();
	local radians = math.acos(temp1 / temp2);
	local final = -radians/(math.pi/180);
	local angle = math.abs(math.atan2(vector2.y,vector2.x) - math.atan2(vector1.y,vector1.x));
	if (angle > math.pi) then
		final = -final;
	end
	return final;
end