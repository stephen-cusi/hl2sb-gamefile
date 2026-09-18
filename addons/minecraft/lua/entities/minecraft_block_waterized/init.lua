//************************************//
//  prop_waterized base (c) Meoo~we   //
//     everything else (c) McKay      //
//************************************//

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( 'shared.lua')

-- Accessor Funcs
function ENT:SetDamping( dmp )
    self.dt.damping = tonumber( dmp )
end

function ENT:SetDensity( den )
    self.dt.density = tonumber( den )
end

function ENT:SetBuoyancy( buo )
    self.Buoyancy = tonumber( buo )
end

function ENT:GetBuoyancy( )
    return self.Buoyancy
end

function ENT:SetPlayer( ply )
    self.Owner = ply
end

function ENT:GetPlayer( )
    return self.Owner
end


//FUCK THIS    ( lua/includes/extensions/entity.lua:396:  ent[ "Set" .. k ]( ent, tab[ k ] ) )
//duplicator & save/load fix
function ENT:SetblockID( ID )
	self.dt.blockID = ID
end

function ENT:Setdamping( damping )
	self.dt.damping = damping
end

function ENT:Setdensity( density )
	self.dt.density = density
end

function ENT:SetdoUpdate( doUpdate )
	self.dt.doUpdate = doUpdate
end


-- Serverside init
function ENT:Initialize()
	//remove hook
	hook.Add( "waterRemove", "waterremove", WOnRemove )
	self:CallOnRemove("waterremove",WOnRemove)
	if (USE_MESH) then
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_NONE )
	
		self:SetNoDraw( true )
		self:SetRenderMode( RENDERMODE_NONE )
		self:SetColor( 0, 0, 0, 0 )
	else
		-- Basic stufff
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
	
		local phys = self.Entity:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:EnableMotion( false ) //freeze the block
			phys:Wake()
		end
	end
    -- Nocollide
    self:SetCollisionGroup( COLLISION_GROUP_WORLD )
    self.CollisionGroup = COLLISION_GROUP_WORLD
	if (self:GetPlayer() != nil) then
		self:SetNotSolid(self:GetPlayer().w_EnableCollisions)
	end
	-- Set Trigger
	self.Entity:SetTrigger( true )
	
	self.lavaresiduetime = -1;
end

-- Start touch hook
function ENT:StartTouch( ent )
    if (!IsValid( ent ) || !IsValid(ent:GetPhysicsObject()) || ent:GetClass() == "minecraft_block_waterized") then return end

	//only ignite certain block types
	local canIgnite = true;
	if (ent:GetClass() == "minecraft_block") then
		canIgnite = false;
		local ID = ent:GetBlockID();
		if (ID == 28 || ID == 29 || ID == 31 || ID == 38 || ID == 47 || ID == 54 || ID == 62 || ID == 64 || ID == 65 || ID == 55
			|| ID == 79 || ID == 80 || ID == 56 || ID == 40 || ID == 17) then
			canIgnite = true;
		end
	end
	
	//handle igniting
	if (self:GetNetworkedString("lava") == "true") then
		if ( GetCSConVarB( "minecraft_lavaigniteplayer", self.Owner ) == false && ent:IsPlayer() == false) then
			if (ent:IsOnFire() == false) then
				if ( GetCSConVarB( "minecraft_lavaigniteblocks", self.Owner ) == true) then
					if (canIgnite == true) then
						ent:Ignite(40,0)
					end
				else
					if (ent:GetName() != "mcblock" && canIgnite) then
						ent:Ignite(40,0)
					end			
				end
			end
		end
		if ( GetCSConVarB( "minecraft_lavaigniteplayer", self.Owner ) == true) then
			if (ent:IsOnFire() == false) then
				if ( GetCSConVarB( "minecraft_lavaigniteblocks", self.Owner ) == true) then
					ent:Ignite(40,0)
				end
				if ( GetCSConVarB( "minecraft_lavaigniteblocks", self.Owner ) == false && ent:GetName() != "mcblock") then
					ent:Ignite(40,0)
				end
            end
        end
	end
	
	//and extinguishing
	if (self:GetNetworkedString("water") == "true") then
		if (ent:IsOnFire()) then
			ent:Extinguish()
		end
	end
	
	if (ent:GetClass() == "minecraft_block") then return end //lag prevention
    -- Create table if necessary
    ent.w_WaterEnts = ent.w_WaterEnts or {}
    table.insert(ent.w_WaterEnts, self)
    if not ent:IsPlayer() then
        table.insert(w_EntsInWater, ent)
        return
    end
    -- UMsg
    umsg.Start("w_StartTouch", ent)
        umsg.Entity( self )
    umsg.End()
end

-- End touch hook
function ENT:EndTouch( ent )
	if (!IsValid( ent ) || !IsValid(ent:GetPhysicsObject()) || ent:GetClass() == "minecraft_block_waterized" || ent:GetClass() == "minecraft_block") then return end
	
    if not ent.w_WaterEnts then return end
    -- Delete unused entities
    for k, e in ipairs(ent.w_WaterEnts) do
        if not IsValid(e) or e == self then
            table.remove(ent.w_WaterEnts, k)
        end
    end
    -- Set nil when table is useless
    if #(ent.w_WaterEnts) == 0 then
        ent.w_WaterEnts = nil
        if ent.w_IsInWater then
            ent:SetGravity(1)
            ent.w_IsInWater = false
        end
    end
    if not ent:IsPlayer() then
        for k, e in ipairs(w_EntsInWater) do
            if not IsValid(e) or e == self then
                table.remove(w_EntsInWater, k)
            end
        end
        return
    end
    -- UMsg
    umsg.Start("w_EndTouch", ent)
        umsg.Entity( self )
    umsg.End()
end

function WOnRemove( ent )
	//if (GetConVar("minecraft_debug"):GetBool()) then print("water/lava block removed!") end
	ent:PostSpawn()
end

function ENT:PostSpawn()
	local t1 = self:GetNearbyBlock( 1,0,0,false );
	local t2 = self:GetNearbyBlock( 2,0,0,false );
	local t3 = self:GetNearbyBlock( 3,0,0,false );
	local t4 = self:GetNearbyBlock( 4,0,0,false );
	local t5 = self:GetNearbyBlock( 5,0,0,false );
	local t6 = self:GetNearbyBlock( 6,0,0,false );
	
	if (t1 != nil && t1 != NULL) then
		if (t1:IsValid()) then
			if (t1:GetClass() == "minecraft_block_waterized") then
				if (t1.child > 0) then
					t1.parent:SetNetworkedBool("doUpdate",true)
				end
				t1:SetNetworkedBool("doUpdate",true)
			else
				t1:SetNetworkedBool("doUpdate", true);
			end
		end
	end
	if (t2 != nil && t2 != NULL) then
		if (t2:IsValid()) then
			if (t2:GetClass() == "minecraft_block_waterized") then
				if (t2.child > 0) then
					t2.parent:SetNetworkedBool("doUpdate",true)
				end
				t2:SetNetworkedBool("doUpdate",true)
			else
				t2:SetNetworkedBool("doUpdate", true);
			end
		end
	end
	if (t3 != nil && t3 != NULL) then
		if (t3:IsValid()) then
			if (t3:GetClass() == "minecraft_block_waterized") then
				if (t3.child > 0) then
					t3.parent:SetNetworkedBool("doUpdate",true)
				end
				t3:SetNetworkedBool("doUpdate",true)
			else
				t3:SetNetworkedBool("doUpdate", true);
			end
		end
	end
	if (t4 != nil && t4 != NULL) then
		if (t4:IsValid()) then
			if (t4:GetClass() == "minecraft_block_waterized") then
				if (t4.child > 0) then
					t4.parent:SetNetworkedBool("doUpdate",true)
				end
				t4:SetNetworkedBool("doUpdate",true)
			else
				t4:SetNetworkedBool("doUpdate", true);
			end
		end
	end
	if (t5 != nil && t5 != NULL) then
		if (t5:IsValid()) then
			if (t5:GetClass() == "minecraft_block_waterized") then
				if (t5.child > 0) then
					t5.parent:SetNetworkedBool("doUpdate",true)
				end
				t5:SetNetworkedBool("doUpdate",true)
			else
				t5:SetNetworkedBool("doUpdate", true);
			end
		end
	end
	if (t6 != nil && t6 != NULL) then
		if (t6:IsValid()) then
			if (t6:GetClass() == "minecraft_block_waterized") then
				if (t6.child > 0) then
					t6.parent:SetNetworkedBool("doUpdate",true)
				end
				t6:SetNetworkedBool("doUpdate",true)
			else
				t6:SetNetworkedBool("doUpdate", true);
			end
		end
	end
end
