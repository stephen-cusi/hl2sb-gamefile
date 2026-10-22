--[[----------------------------------------------------------------------------
    Sandbox: 生成上限的 gamemode 层

    逐字移植 GMod gamemodes/sandbox/gamemode/player.lua 中与生成上限有关的
    部分（GMod 同位同文件名，插件按这个路径找这些方法）：

        GM:PlayerSpawn<Type>( ... )    -> LimitReachedProcess -> ply:CheckLimit
        GM:PlayerSpawned<Type>( ... )  -> ply:AddCount

    生成命令现在在 commands.lua（GMod 同位文件，同目录 / 同 include 面），
    它在这两处问一次 gamemode：前置返回 false 就不生成，生成成功后再回来计数。
    复制/粘贴（duplicator 与 save_load.lua）走的是同一对方法，所以一处接上
    两条路都受上限约束。

    注意：本分叉的 gamemode.Call 对「方法不存在」回答 false（不是 nil），
    所以这些方法**必须存在**，否则调用方（save_load.lua 等）会把生成整段
    掐掉。GMod 的 base 层不提供它们，方法缺了就是全禁——这正是这里要补齐的。

    基类已有的 CanPlayerUnfreeze / PlayerEnteredVehicle / PlayerButtonDown/Up
    不在这里重定义（沙盒版是 GMod 的额外增强，基类空桩已够用）。
------------------------------------------------------------------------------]]

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnObject( ply )
   Desc: Called to ask whether player is allowed to spawn any objects
-----------------------------------------------------------]]
function GM:PlayerSpawnObject( ply )
	return true
end

--[[---------------------------------------------------------
   Name: LimitReachedProcess
-----------------------------------------------------------]]
local function LimitReachedProcess( ply, str )

	if ( !IsValid( ply ) ) then return true end

	return ply:CheckLimit( str )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnRagdoll( ply, model )
   Desc: Return true if it's allowed
-----------------------------------------------------------]]
function GM:PlayerSpawnRagdoll( ply, model )

	return LimitReachedProcess( ply, "ragdolls" )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnProp( ply, model )
   Desc: Return true if it's allowed
-----------------------------------------------------------]]
function GM:PlayerSpawnProp( ply, model )

	return LimitReachedProcess( ply, "props" )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnEffect( ply, model )
   Desc: Return true if it's allowed
-----------------------------------------------------------]]
function GM:PlayerSpawnEffect( ply, model )

	return LimitReachedProcess( ply, "effects" )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnVehicle( ply, model, vname, vtable )
   Desc: Return true if it's allowed
-----------------------------------------------------------]]
function GM:PlayerSpawnVehicle( ply, model, vname, vtable )

	return LimitReachedProcess( ply, "vehicles" )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnSWEP( ply, wname, wtable )
   Desc: Return true if it's allowed
-----------------------------------------------------------]]
function GM:PlayerSpawnSWEP( ply, wname, wtable )

	return LimitReachedProcess( ply, "sents" )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerGiveSWEP( ply, wname, wtable )
   Desc: Return true if it's allowed
-----------------------------------------------------------]]
function GM:PlayerGiveSWEP( ply, wname, wtable )

	return true

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnSENT( ply, name )
   Desc: Return true if player is allowed to spawn the SENT
-----------------------------------------------------------]]
function GM:PlayerSpawnSENT( ply, name )

	return LimitReachedProcess( ply, "sents" )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnNPC( ply, npc_type )
   Desc: Return true if player is allowed to spawn the NPC
-----------------------------------------------------------]]
function GM:PlayerSpawnNPC( ply, npc_type, equipment )

	return LimitReachedProcess( ply, "npcs" )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnedRagdoll( ply, model, ent )
   Desc: Called after the player spawned a ragdoll
-----------------------------------------------------------]]
function GM:PlayerSpawnedRagdoll( ply, model, ent )

	ply:AddCount( "ragdolls", ent )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnedProp( ply, model, ent )
   Desc: Called after the player spawned a prop
-----------------------------------------------------------]]
function GM:PlayerSpawnedProp( ply, model, ent )

	ply:AddCount( "props", ent )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnedEffect( ply, model, ent )
   Desc: Called after the player spawned an effect
-----------------------------------------------------------]]
function GM:PlayerSpawnedEffect( ply, model, ent )

	ply:AddCount( "effects", ent )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnedVehicle( ply, ent )
   Desc: Called after the player spawned a vehicle
-----------------------------------------------------------]]
function GM:PlayerSpawnedVehicle( ply, ent )

	ply:AddCount( "vehicles", ent )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnedNPC( ply, ent )
   Desc: Called after the player spawned an NPC
-----------------------------------------------------------]]
function GM:PlayerSpawnedNPC( ply, ent )

	ply:AddCount( "npcs", ent )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnedSENT( ply, ent )
   Desc: Called after the player has spawned a SENT
-----------------------------------------------------------]]
function GM:PlayerSpawnedSENT( ply, ent )

	ply:AddCount( "sents", ent )

end

--[[---------------------------------------------------------
   Name: gamemode:PlayerSpawnedSWEP( ply, ent )
   Desc: Called after the player has spawned a Weapon
-----------------------------------------------------------]]
function GM:PlayerSpawnedSWEP( ply, ent )

	-- This is on purpose..
	ply:AddCount( "sents", ent )

end

function GM:PlayerButtonDown( ply, btn )

	numpad.Activate( ply, btn )

end

--[[---------------------------------------------------------
	These are buttons that the client is pressing. They're used
	in Sandbox mode to control things like wheels, thrusters etc.
-----------------------------------------------------------]]
function GM:PlayerButtonUp( ply, btn )

	numpad.Deactivate( ply, btn )

end
