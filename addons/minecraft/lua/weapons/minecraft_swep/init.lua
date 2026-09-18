//********************************//
//     		(c) McKay        	  //   Do NOT redistribute!
//********************************//



//********************************//
//     	  Global variables        //
//********************************//

if (CLIENT) then
	local m_bBlockNewPanel = false
	local m_bUpdateViewmodel = true
	local m_iLastBlockType = 0
	local m_iLastBlockSkin = 0
	local m_iBlockType = 0
	local m_iBlockSkin = 0
end

util.AddNetworkString("MinecraftSwepBlockChange")
net.Receive("MinecraftSwepBlockChange", function( len )
		m_bUpdateServerViewmodel = true;
	end )

if (SERVER) then
	local m_bRemoveAllBlocks = false
	local m_bRemoveAllSelectedBlocks = false
	local m_bMenuCheck = false
	local m_bUpdateServerViewmodel = false;
	
	CreateConVar( "minecraft_swep_blocklimit", "2048", { FCVAR_REPLICATED, FCVAR_ARCHIVE } )
	CreateConVar( "minecraft_swep_enable_water_spread", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE } )
	
	//delete all my blocks on disconnect
	local function MCPlayerDisconnect( ply )
		for k, v in pairs( ents.FindByName( "mcblock*" ) ) do
			if ( v:IsValid() && v:GetPlayer() == ply ) then
				v.Entity.health = -1
				v.Entity.simpleRemove = true
				v:Remove()
			end
		end	
	end
	hook.Add( "PlayerDisconnected", "playerdisconnected", MCPlayerDisconnect )
	
	CreateConVar( "minecraft_swep_blacklist", "", { FCVAR_REPLICATED, FCVAR_ARCHIVE } )
end


//********************************//
//     	  	  Includes            //
//********************************//

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( 'shared.lua' )



//********************************//
//     	  	  Resources           //
//********************************//

function AddDir(dir) // Recursively adds everything in a directory to be downloaded by client
	local files,folders = file.Find(dir.."/*", "GAME")
	for _, fdir in pairs(folders) do
		if fdir != ".svn" then // Don't spam people with useless .svn folders
			AddDir(dir.."/"..fdir, "GAME")
		end
	end
 
	for k,v in pairs(file.Find(dir.."/*", "GAME")) do
		resource.AddFile(dir.."/"..v)
	end
end

resource.AddFile( "materials/vgui/minecraft/logo.vtf" )
resource.AddFile( "materials/vgui/minecraft/logo.vmt" )
resource.AddFile( "materials/VGUI/entities/minecraft_swep.vtf" )
resource.AddFile( "materials/VGUI/entities/minecraft_swep.vmt" )

resource.AddFile( "sound/minecraft/block_break.wav" )
resource.AddFile( "sound/minecraft/explode.wav" )
resource.AddFile( "sound/minecraft/ignite.wav" )

resource.AddFile( "sound/minecraft/cloth1.wav" )
resource.AddFile( "sound/minecraft/cloth2.wav" )
resource.AddFile( "sound/minecraft/cloth3.wav" )
resource.AddFile( "sound/minecraft/cloth4.wav" )

resource.AddFile( "sound/minecraft/concrete_break2.wav" )
resource.AddFile( "sound/minecraft/concrete_break3.wav" )
resource.AddFile( "sound/minecraft/concrete_impact_hard1.wav" )
resource.AddFile( "sound/minecraft/concrete_impact_hard2.wav" )
resource.AddFile( "sound/minecraft/concrete_impact_hard3.wav" )

resource.AddFile( "sound/minecraft/door_close.wav" )
resource.AddFile( "sound/minecraft/door_open.wav" )

resource.AddFile( "sound/minecraft/glass_1.wav" )
resource.AddFile( "sound/minecraft/glass_2.wav" )
resource.AddFile( "sound/minecraft/glass_3.wav" )

resource.AddFile( "sound/minecraft/grass1.wav" )
resource.AddFile( "sound/minecraft/grass2.wav" )
resource.AddFile( "sound/minecraft/grass3.wav" )
resource.AddFile( "sound/minecraft/grass4.wav" )

resource.AddFile( "sound/minecraft/gravel1.wav" )
resource.AddFile( "sound/minecraft/gravel2.wav" )
resource.AddFile( "sound/minecraft/gravel3.wav" )
resource.AddFile( "sound/minecraft/gravel4.wav" )

resource.AddFile( "sound/minecraft/sand1.wav" )
resource.AddFile( "sound/minecraft/sand2.wav" )
resource.AddFile( "sound/minecraft/sand3.wav" )
resource.AddFile( "sound/minecraft/sand4.wav" )

resource.AddFile( "sound/minecraft/snow1.wav" )
resource.AddFile( "sound/minecraft/snow2.wav" )
resource.AddFile( "sound/minecraft/snow3.wav" )
resource.AddFile( "sound/minecraft/snow4.wav" )

resource.AddFile( "sound/minecraft/stone1.wav" )
resource.AddFile( "sound/minecraft/stone2.wav" )
resource.AddFile( "sound/minecraft/stone3.wav" )
resource.AddFile( "sound/minecraft/stone4.wav" )

resource.AddFile( "sound/minecraft/wood1.wav" )
resource.AddFile( "sound/minecraft/wood2.wav" )
resource.AddFile( "sound/minecraft/wood3.wav" )
resource.AddFile( "sound/minecraft/wood4.wav" )


resource.AddFile( "materials/particles/minecraft/smoke0.vmt" )
resource.AddFile( "materials/particles/minecraft/smoke1.vmt" )
resource.AddFile( "materials/particles/minecraft/smoke2.vmt" )
resource.AddFile( "materials/particles/minecraft/smoke3.vmt" )
resource.AddFile( "materials/particles/minecraft/smoke4.vmt" )
resource.AddFile( "materials/particles/minecraft/smoke5.vmt" )
resource.AddFile( "materials/particles/minecraft/flame.vmt" )
resource.AddFile( "materials/particles/minecraft/bubble.vmt" )
resource.AddFile( "materials/particles/minecraft/smoke0.vtf" )
resource.AddFile( "materials/particles/minecraft/smoke1.vtf" )
resource.AddFile( "materials/particles/minecraft/smoke2.vtf" )
resource.AddFile( "materials/particles/minecraft/smoke3.vtf" )
resource.AddFile( "materials/particles/minecraft/smoke4.vtf" )
resource.AddFile( "materials/particles/minecraft/smoke5.vtf" )
resource.AddFile( "materials/particles/minecraft/flame.vtf" )
resource.AddFile( "materials/particles/minecraft/bubble.vtf" )

resource.AddFile( "materials/models/sparkle.vtf" )
resource.AddFile( "materials/models/sparkle.vmt" )

AddDir( "models/MCModelPack" )
AddDir( "materials/models/MCModelPack" )