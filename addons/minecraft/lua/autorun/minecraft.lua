//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//
// This is a WIP of mesh-based blocks;
// It's buggy as hell and only works with water blocks atm for testing
// Some pieces of code and the idea itself is (c) Overv (google Crafty Gamemode)
//
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//set this to true and spawn a water block, I dare you
USE_MESH = false

if (SERVER) then return end
if (!USE_MESH) then return end

CreateClientConVar("minecraft_chunks_debug","1",false,false)
CreateClientConVar("minecraft_temp","1",false,false)
//*******************************************
//	World
//*******************************************

world = {}
//these are unused as of now
worldsize_x = 256
worldsize_y = 256
worldsize_z = 64

blocksize = 36.5

function BlockToLocal( pos )
	return (Vector(pos.x+18.25,pos.y+18.25,pos.z)/blocksize)
end

function BlockToWorld( pos )
	return (Vector(pos.x-18.25,pos.y-18.25,pos.z)*blocksize)
end

function CheckWorldPos( pos )
	
end

function RemoveBlock( entpos )
	local tempworld = {}
	for i,c in ipairs( world ) do
		if (world[i].realpos == entpos) then
			world[i] = nil
		else
			tempworld[#tempworld+1] = world[i]
		end
	end
	world = tempworld
	RebuildChunk( entpos )
end

//*******************************************
//	Chunks
//*******************************************

//TODO: if the game is closed, OnRemove() is called updating all chunks and creating a shitload of lag
//TODO: fix lighting issues with transparent (water etc) blocks
//TODO: create one texture map which contains all blocks, including animated lava and water (have to animate entire texture, ffs)
//TODO: implement dynamic block entity creation for player physics and tracers (4x4x4 blocks around the player)
//TODO: find a way to be able to place blocks from far away even though they are only rendered and don't collide with tracers

chunks = {}
local chunksize = 8 //one chunk = 8x8x8 cube!

//Adds a block to the game
//automatically creates/rebuilds chunks and checks if there is already a block at that position
function AddBlock( ent, blockID )
	for i, c in ipairs( world ) do
		if (world[i].realpos == ent:GetPos()) then
			if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("Block already in world, WTF") end
			return
		end
	end
	local worldnumber = #world+1
	world[worldnumber] = {}
	local temppos = ent:GetPos()
	temppos.z = temppos.z + 18.25
	world[worldnumber].realpos = ent:GetPos()
	world[worldnumber].worldpos = temppos
	world[worldnumber].blockpos = BlockToLocal(ent:GetPos())  //1 unit = 1 block! (these are always integers, e.g. (5,1,4))
	world[worldnumber].ID = blockID

	local entpos = ent:GetPos()
	if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("Block[world] ("..tostring(entpos.x)..","..tostring(entpos.y)..","..tostring(entpos.z)..")") end
	if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("Block[local] ("..tostring(BlockToLocal(ent:GetPos()).x)..","..tostring(BlockToLocal(ent:GetPos()).y)..","..tostring(BlockToLocal(ent:GetPos()).z)..")") end
	local buildnewchunk = false
	local check = false
	for i, c in ipairs( chunks ) do
		//gmod can't compare two vectors????! MADNESS
		///////if (entpos < chunks[i].Start || entpos > chunks[i].End) then
		if ( entpos.x >= chunks[i].Start.x
		  && entpos.y >= chunks[i].Start.y 
		  && entpos.z >= chunks[i].Start.z 
		   && entpos.x <= chunks[i].End.x 
		   && entpos.y <= chunks[i].End.y
		   && entpos.z <= chunks[i].End.z) then
		   check = true
		end
	end
	if (!check) then
		buildnewchunk = true
		if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("will generate a new chunk!") end
	end
	
	if (!buildnewchunk) then
		RebuildChunk( entpos )
	else
		CreateChunk( entpos )
	end
end

//Creates a new chunk given a position (the chunks are created by a grid, multiple points may be in the same chunk!)
//does NOT check if a chunk already exists at that position!!!
function CreateChunk( blockpos )
	local chunknumber = #chunks+1
	if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("generating new chunk["..tostring(chunknumber).."] ...") end
	
	chunks[chunknumber] = {}
	chunks[chunknumber].dirty = true
	chunks[chunknumber].mesh = NewMesh()
	chunks[chunknumber].Start = Vector( math.floor(blockpos.x/(blocksize*chunksize))*blocksize*chunksize, math.floor(blockpos.y/(blocksize*chunksize))*blocksize*chunksize, math.floor(blockpos.z/(blocksize*chunksize))*blocksize*chunksize )
	chunks[chunknumber].End = Vector( chunks[chunknumber].Start.x + blocksize*chunksize, chunks[chunknumber].Start.y + blocksize*chunksize, chunks[chunknumber].Start.z + blocksize*chunksize )
	
	if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("currently "..tostring(#chunks).." chunks in memory") end
	if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("chunk["..tostring(chunknumber).."] Start("..tostring(chunks[chunknumber].Start.x)..","..tostring(chunks[chunknumber].Start.y)..","..tostring(chunks[chunknumber].Start.z)..")") end
	if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("chunk["..tostring(chunknumber).."] End("..tostring(chunks[chunknumber].End.x)..","..tostring(chunks[chunknumber].End.y)..","..tostring(chunks[chunknumber].End.z)..")") end
	debugoverlay.Line(chunks[chunknumber].Start, chunks[chunknumber].End, 60, Color(255,0,0))
	
	if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("blockpos("..tostring(blockpos.x)..","..tostring(blockpos.y)..","..tostring(blockpos.z)..")") end
	if (blockpos.x >= chunks[chunknumber].Start.x 
		 && blockpos.y >= chunks[chunknumber].Start.y 
		 && blockpos.z > chunks[chunknumber].Start.z 
		  && blockpos.x <= chunks[chunknumber].End.x 
	 	  && blockpos.y <= chunks[chunknumber].End.y
		  && blockpos.z <= chunks[chunknumber].End.z) then

			local noFront = false
			local noBack = false
			local noBottom = false
			local noTop = false
			local noRight = false
			local noLeft = false
				local lblockpos = BlockToLocal(blockpos)
				for i,c in ipairs( world ) do
					if (world[i].blockpos == Vector(lblockpos.x+1, lblockpos.y, lblockpos.z)) then
						noFront = true
						RebuildSpecificChunk(GetChunkID(world[i].realpos))
					end
					if (world[i].blockpos == Vector(lblockpos.x-1, lblockpos.y, lblockpos.z)) then
						noBack = true
						RebuildSpecificChunk(GetChunkID(world[i].realpos))
					end
					if (world[i].blockpos == Vector(lblockpos.x, lblockpos.y+1, lblockpos.z)) then
						noRight = true
						RebuildSpecificChunk(GetChunkID(world[i].realpos))
					end
					if (world[i].blockpos == Vector(lblockpos.x, lblockpos.y-1, lblockpos.z)) then
						noLeft = true
						RebuildSpecificChunk(GetChunkID(world[i].realpos))
					end
					if (world[i].blockpos == Vector(lblockpos.x, lblockpos.y, lblockpos.z+1)) then
						noTop = true
						RebuildSpecificChunk(GetChunkID(world[i].realpos))
					end
					if (world[i].blockpos == Vector(lblockpos.x, lblockpos.y, lblockpos.z-1)) then
						noBottom = true
						RebuildSpecificChunk(GetChunkID(world[i].realpos))
					end
				end
			blockpos.z = blockpos.z + 18.25
			chunks[chunknumber].mesh:BuildFromTriangles( CubeTriangles( blockpos, noTop, noBottom, noLeft, noRight, noFront, noBack ) )
			chunks[chunknumber].dirty = false
	end
end


//Rebuilds the chunk which contains the blockpos vector; 
//give it the position of a block and it will rebuild the chunk that the block is in
//does NOT create a chunk if there is none at the given position!
function RebuildChunk( blockpos )
	for i, c in ipairs( chunks ) do
		if ( blockpos.x >= chunks[i].Start.x
		  && blockpos.y >= chunks[i].Start.y 
		  && blockpos.z > chunks[i].Start.z 
		   && blockpos.x <= chunks[i].End.x 
		   && blockpos.y <= chunks[i].End.y
		   && blockpos.z <= chunks[i].End.z) then
			//this is the chunk we have to rebuild
			local triangles = {}
			chunks[i].dirty = true
			chunks[i].mesh:Destroy()
			chunks[i].mesh = NewMesh()
			if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("rebuilding chunk["..tostring(i).."] ...") end
			local torebuild = {}
			for i2, c2 in ipairs( world ) do
				if (world[i2].realpos.x >= chunks[i].Start.x 
				 && world[i2].realpos.y >= chunks[i].Start.y 
				 && world[i2].realpos.z > chunks[i].Start.z 
				  && world[i2].realpos.x <= chunks[i].End.x
				  && world[i2].realpos.y <= chunks[i].End.y
				  && world[i2].realpos.z <= chunks[i].End.z) then
				  
				local noFront = false
				local noBack = false
				local noBottom = false
				local noTop = false
				local noRight = false
				local noLeft = false
				for i3,c3 in ipairs( world ) do
					if (world[i2].blockpos == Vector(world[i3].blockpos.x-1,world[i3].blockpos.y,world[i3].blockpos.z)) then
						noFront = true
						local check = false
						for i4,c4 in ipairs( torebuild ) do
							if (torebuild[i4] == GetChunkID(world[i3].realpos)) then
								check = true
							end
						end
						if (!check && GetChunkID(world[i3].realpos) != i) then
							torebuild[#torebuild+1] = GetChunkID(world[i3].realpos)
						end
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x+1,world[i3].blockpos.y,world[i3].blockpos.z)) then
						noBack = true
						local check = false
						for i4,c4 in ipairs( torebuild ) do
							if (torebuild[i4] == GetChunkID(world[i3].realpos)) then
								check = true
							end
						end
						if (!check && GetChunkID(world[i3].realpos) != i) then
							torebuild[#torebuild+1] = GetChunkID(world[i3].realpos)
						end
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y-1,world[i3].blockpos.z)) then
						noRight = true
						local check = false
						for i4,c4 in ipairs( torebuild ) do
							if (torebuild[i4] == GetChunkID(world[i3].realpos)) then
								check = true
							end
						end
						if (!check && GetChunkID(world[i3].realpos) != i) then
							torebuild[#torebuild+1] = GetChunkID(world[i3].realpos)
						end
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y+1,world[i3].blockpos.z)) then
						noLeft = true
						local check = false
						for i4,c4 in ipairs( torebuild ) do
							if (torebuild[i4] == GetChunkID(world[i3].realpos)) then
								check = true
							end
						end
						if (!check && GetChunkID(world[i3].realpos) != i) then
							torebuild[#torebuild+1] = GetChunkID(world[i3].realpos)
						end
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y,world[i3].blockpos.z-1)) then
						noTop = true
						local check = false
						for i4,c4 in ipairs( torebuild ) do
							if (torebuild[i4] == GetChunkID(world[i3].realpos)) then
								check = true
							end
						end
						if (!check && GetChunkID(world[i3].realpos) != i) then
							torebuild[#torebuild+1] = GetChunkID(world[i3].realpos)
						end
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y,world[i3].blockpos.z+1)) then
						noBottom = true
						local check = false
						for i4,c4 in ipairs( torebuild ) do
							if (torebuild[i4] == GetChunkID(world[i3].realpos)) then
								check = true
							end
						end
						if (!check && GetChunkID(world[i3].realpos) != i) then
							torebuild[#torebuild+1] = GetChunkID(world[i3].realpos)
						end
					end
				end
				  
					table.Add( triangles, CubeTriangles( world[i2].worldpos, noTop, noBottom, noLeft, noRight, noFront, noBack ) )
				end
			end
			//Chunk-Chunk mesh occlusion (disabled for now)
			if (false) then
			for i4,c4 in ipairs( torebuild ) do
				if (torebuild[i4] != i) then
					RebuildSpecificChunk(torebuild[i4])
				end
			end
			end
			chunks[i].mesh:BuildFromTriangles( triangles )
			chunks[i].dirty = false
		end
	end
end

function RebuildSpecificChunk( ID )
	if (chunks[ID] == nil || chunks[ID] == NULL) then print("chunk["..tostring(ID).."] does not exist!!"); return end
			local i = ID
			local triangles = {}
			chunks[i].dirty = true
			chunks[i].mesh:Destroy();
			chunks[i].mesh = NewMesh()
			if (GetConVar("minecraft_chunks_debug"):GetBool()) then print("rebuilding chunk["..tostring(i).."] ...") end
			for i2, c2 in ipairs( world ) do
				if (world[i2].realpos.x >= chunks[i].Start.x 
				 && world[i2].realpos.y >= chunks[i].Start.y 
				 && world[i2].realpos.z > chunks[i].Start.z 
				  && world[i2].realpos.x <= chunks[i].End.x
				  && world[i2].realpos.y <= chunks[i].End.y
				  && world[i2].realpos.z <= chunks[i].End.z) then
				  
				local noFront = false
				local noBack = false
				local noBottom = false
				local noTop = false
				local noRight = false
				local noLeft = false
				for i3,c3 in ipairs( world ) do
					if (world[i2].blockpos == Vector(world[i3].blockpos.x-1,world[i3].blockpos.y,world[i3].blockpos.z)) then
						noFront = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x+1,world[i3].blockpos.y,world[i3].blockpos.z)) then
						noBack = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y-1,world[i3].blockpos.z)) then
						noRight = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y+1,world[i3].blockpos.z)) then
						noLeft = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y,world[i3].blockpos.z-1)) then
						noTop = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y,world[i3].blockpos.z+1)) then
						noBottom = true
					end
				end
					table.Add( triangles, CubeTriangles( world[i2].worldpos, noTop, noBottom, noLeft, noRight, noFront, noBack ) )
				end
			end
			chunks[i].mesh:BuildFromTriangles( triangles )
			chunks[i].dirty = false
end

//Rebuild ALL the chunks!
function RebuildChunks()
	if (#chunks <= 0) then return end
	print("Rebuilding "..tostring(#chunks).." chunks! This may take some time")
	for i, c in ipairs( chunks ) do
		local triangles = {}
		chunks[i].dirty = true
		chunks[i].mesh:Destroy();
		chunks[i].mesh = NewMesh()	
		//print("rebuilding chunk["..tostring(i).."] ...")
		for i2, c2 in ipairs( world ) do
			if (world[i2].realpos.x >= chunks[i].Start.x 
			 && world[i2].realpos.y >= chunks[i].Start.y 
			 && world[i2].realpos.z > chunks[i].Start.z 
			  && world[i2].realpos.x <= chunks[i].End.x
			  && world[i2].realpos.y <= chunks[i].End.y
			  && world[i2].realpos.z <= chunks[i].End.z) then
			  
				local noFront = false
				local noBack = false
				local noBottom = false
				local noTop = false
				local noRight = false
				local noLeft = false
				for i3,c3 in ipairs( world ) do
					if (world[i2].blockpos == Vector(world[i3].blockpos.x-1,world[i3].blockpos.y,world[i3].blockpos.z)) then
						noFront = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x+1,world[i3].blockpos.y,world[i3].blockpos.z)) then
						noBack = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y-1,world[i3].blockpos.z)) then
						noRight = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y+1,world[i3].blockpos.z)) then
						noLeft = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y,world[i3].blockpos.z-1)) then
						noTop = true
					end
					if (world[i2].blockpos == Vector(world[i3].blockpos.x,world[i3].blockpos.y,world[i3].blockpos.z+1)) then
						noBottom = true
					end
				end
				  
				table.Add( triangles, CubeTriangles( world[i2].worldpos, noTop, noBottom, noLeft, noRight, noFront, noBack ) )
			end
		end
		chunks[i].mesh:BuildFromTriangles( triangles )
		chunks[i].dirty = false
	end
end

concommand.Add("minecraft_chunks_forcerebuild", RebuildChunks )

function GetChunkID( blockpos )
	for i,c in ipairs( chunks ) do
		if ( blockpos.x >= chunks[i].Start.x
		  && blockpos.y >= chunks[i].Start.y 
		  && blockpos.z > chunks[i].Start.z 
		   && blockpos.x <= chunks[i].End.x 
		   && blockpos.y <= chunks[i].End.y
		   && blockpos.z <= chunks[i].End.z) then
		   return i;
		end
	end
	print("no chunk at that position!!")
	return -1;
end

//Remove all chunks
function ResetChunks()
	if (#chunks <= 0) then return end
	chunks = {}
	print("All chunks removed!")
end

//Empty the world (else all blocks would reappear on chunk rebuild)
function ResetWorld()
	world = {}
	print("World cleared!")
end

function CompleteReset()
	ResetChunks()
	ResetWorld()
end

concommand.Add("minecraft_chunks_reset", CompleteReset )

//*******************************************
//	Rendering
//*******************************************

local themat = Material( "models/MCModelPack/animated/water" );

hook.Add("PostDrawTranslucentRenderables", "MCDraw", function()
	render.SetMaterial( themat )
	for i, c in ipairs( chunks ) do
		if (chunks[i].mesh && !chunks[i].dirty) then
			chunks[i].mesh:Draw()
		end
	end
end)

//*******************************************
//	Think
//*******************************************

hook.Add("Think", "MCThink", function()
	//TODO: i have to put the entire block logic in here :(
end)

//*******************************************
//	Texture coordinates
//*******************************************

function TexCoords( x, y, z, n )	
	return 0, 0, 1, 1
end

//*******************************************
//	Meshes
//*******************************************

function ShadeSide( coords, n, forcedraw )
	local l = ( 7 - 7 ) / 8
	if ( forcedraw ) then l = 0 end
	
	if ( n == Vector( -1, 0, 0 ) or n == Vector( 0, -1, 0 ) or n == Vector( 0, 0, -1 ) ) then
		l = math.Clamp( l, 0, 4/8 )
		return coords[1] + 3/8 + l, coords[2], coords[3] + 3/8 + l - 0.01, coords[4]
	else
		return coords[1] + l, coords[2], coords[3] + l - 0.01, coords[4]
	end
end

function CubeTriangles( pos, noTop, noBottom, noLeft, noRight, noFront, noBack ) 
	local triangles = {}
	local forcedraw = false
	
	//pos.z = pos.z + 18.25

	local blocksizex = 36.5
	local blocksizey = 36.5
	local blocksizez = 36.5
	local height = 36.5
	
	// Top
	if (!noTop || forcedraw) then
		table.Add( triangles,  TrianglesFromQuad(
			pos + Vector( -blocksizex / 2, blocksizey / 2, height / 2 ),
			pos + Vector( blocksizex / 2, blocksizey / 2, height / 2 ),
			pos + Vector( blocksizex / 2, -blocksizey / 2, height / 2 ),
			pos + Vector( -blocksizex / 2, -blocksizey / 2, height / 2 ),
			
			ShadeSide( { TexCoords( blocksizex, blocksizey, blocksizez, Vector( 0, 0, 1 ) ) }, Vector( 0, 0, 1 ), forcedraw )
		) )
	end
	
	// Bottom
	if (!noBottom || forcedraw) then
		table.Add( triangles,  TrianglesFromQuad(
			pos + Vector( -blocksizex / 2, -blocksizey / 2, -blocksizez / 2 ),
			pos + Vector( blocksizex / 2, -blocksizey / 2, -blocksizez / 2 ),
			pos + Vector( blocksizex / 2, blocksizey / 2, -blocksizez / 2 ),
			pos + Vector( -blocksizex / 2, blocksizey / 2, -blocksizez / 2 ),
			
			ShadeSide( { TexCoords( blocksizex, blocksizey, blocksizez, Vector( 0, 0, -1 ) ) }, Vector( 0, 0, -1 ), forcedraw )
		) )
	end
	
	// Back
	if (!noBack || forcedraw) then
		table.Add( triangles,  TrianglesFromQuad(			
			pos + Vector( -blocksizex / 2, blocksizey / 2, height / 2 ),
			pos + Vector( -blocksizex / 2, -blocksizey / 2, height / 2 ),
			pos + Vector( -blocksizex / 2, -blocksizey / 2, -blocksizez / 2 ),
			pos + Vector( -blocksizex / 2, blocksizey / 2, -blocksizez / 2 ),
			
			ShadeSide( { TexCoords( blocksizex, blocksizey, blocksizez, Vector( -1, 0, 0 ) ) }, Vector( -1, 0, 0 ), forcedraw )
		) )
	end
	
	// Front
	if (!noFront || forcedraw) then
		table.Add( triangles,  TrianglesFromQuad(
			pos + Vector( blocksizex / 2, -blocksizey / 2, height / 2 ),
			pos + Vector( blocksizex / 2, blocksizey / 2, height / 2 ),
			pos + Vector( blocksizex / 2, blocksizey / 2, -blocksizez / 2 ),
			pos + Vector( blocksizex / 2, -blocksizey / 2, -blocksizez / 2 ),
			
			ShadeSide( { TexCoords( blocksizex, blocksizey, blocksizez, Vector( 1, 0, 0 ) ) }, Vector( 1, 0, 0 ), forcedraw )
		) )
	end
	
	// Left
	if (!noLeft || forcedraw) then
		table.Add( triangles,  TrianglesFromQuad(
			pos + Vector( -blocksizex / 2, -blocksizey / 2, height / 2 ),
			pos + Vector( blocksizex / 2, -blocksizey / 2, height / 2 ),
			pos + Vector( blocksizex / 2, -blocksizey / 2, -blocksizez / 2 ),
			pos + Vector( -blocksizex / 2, -blocksizey / 2, -blocksizez / 2 ),
			
			ShadeSide( { TexCoords( blocksizex, blocksizey, blocksizez, Vector( 0, -1, 0 ) ) }, Vector( 0, -1, 0 ), forcedraw )
		) )
	end
	
	// Right
	if (!noRight || forcedraw) then
		table.Add( triangles,  TrianglesFromQuad(		
			pos + Vector( blocksizex / 2, blocksizey / 2, height / 2 ),
			pos + Vector( -blocksizex / 2, blocksizey / 2, height / 2 ),
			pos + Vector( -blocksizex / 2, blocksizey / 2, -blocksizez / 2 ),
			pos + Vector( blocksizex / 2, blocksizey / 2, -blocksizez / 2 ),
			
			ShadeSide( { TexCoords( blocksizex, blocksizey, blocksizez, Vector( 0, 1, 0 ) ) }, Vector( 0, 1, 0 ), forcedraw )
		) )
	end
	
	return triangles
end

function TrianglesFromQuad( p1, p2, p3, p4, u1, v1, u2, v2 )
	return {
		Vertex( p1, u1, v1 ),
		Vertex( p2, u2, v1 ),
		Vertex( p3, u2, v2 ),
		
		Vertex( p3, u2, v2 ),
		Vertex( p4, u1, v2 ),
		Vertex( p1, u1, v1 ),
	}
end