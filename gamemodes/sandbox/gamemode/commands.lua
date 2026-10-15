--[[----------------------------------------------------------------------------
    gamemodes/sandbox/gamemode/commands.lua  --  GMod 同位文件移植。

    这是 GMod gamemodes/sandbox/gamemode/commands.lua 的“生成链”部分，逐字
    移植（函数名、参数形状、注册的命令名都与 GMod 完全一致，插件会直接调
    Spawn_SENT / MakeProp / CCSpawn 这些全局函数）。

    为什么要有这个文件（本次对齐的原因）
    ------------------------------------
    这六个生成命令在 GMod 是 **Lua concommand**（concommand.Add，见本文件各
    段落），不是引擎命令。本分叉此前把它们做成了引擎侧 C++ 命令
    （game/server/hl2sb_gm_commands.cpp），好处是能绕开当时缺失的绑定，代价
    是每个命令都是 GMod 的一个分叉特例、菜单命令形状与 GMod 不一致。现在
    绑定补齐了（见下方逐条 HL2SB 注释），命令回到 GMod 的同位文件里，C++
    版即可删除。注册的六个命令名：

        gm_spawn        CCSpawn          (道具/布娃娃/特效，参数是 <model>)
        gmod_spawnnpc   Spawn_NPC        (NPC，参数是 <列表键> <武器>)
        gm_spawnsent    Spawn_SENT       (SENT/列表实体，参数是 <列表键>)
        gm_giveswep     CCGiveSWEP       (直接给武器)
        gm_spawnswep    Spawn_Weapon     (在地上生成武器)
        gm_spawnvehicle Spawn_Vehicle    (载具，参数是 <列表键>)

    GMod 没有 gm_spawnprop / gm_spawnnpc 这两个名字，分叉旧 C++ 加的它们随
    C++ 一起删除，不要再造。

    运行面：本文件由 sandbox/gamemode/init.lua include —— 那是 **服务端**
    半边（客户端加载的是 cl_init.lua，见 luasrc_LoadGamemode 的 CLIENT_DLL
    分支），与 GMod 的结构一致（GMod 也只 include 在服务端，客户端用
    RunConsoleCommand 把命令名发给服务端执行）。prop_tools.lua 同样只在
    服务端，GMod 在此文件顶部 include 它。

    分叉适配（每条都在行内以 HL2SB 注释标出）
    ----------------------------------------
    1. Entity:SetCreator 没有绑定：删除这些调用（undo/cleanup 已持有玩家，
       归属不受影响）。分叉的“显示名”契约改由 ent:SetName 承担，见下。
    2. 分叉把实体的 targetname 当作“生成菜单显示名”（服务端 baseentity.cpp
       把它写进 entity_killed 的 "victimname"，kill feed 原样显示；旧引擎
       命令 GM_SpawnAtEyeTrace 就是拿菜单传来的名字 SetName 的）。菜单不再
       传名字之后，NPC/SENT/载具改在生成成功后从注册表读名字 SetName（
       HL2SB_DisplayName 负责把 "#token" 解析成人话）。
    3. Entity:NearestPoint 本分叉无绑定：DoPlayerEntitySpawn 的“贴地 flush”
       整段略过（旧引擎生成路径同样不做 flush，位置保持 tr.HitPos）。
    4. Entity:DropToFloor() 本分叉原样没有方法绑定：已在
       lua/includes/extensions/entity.lua 补上 GMod 同名方法（内部走
       util.DropToFloor），所以本文件保持 GMod 原文调用。
    5. Entity:SetBodyGroups（复数）由 CBaseAnimating 的共享绑定提供（十六进
       制串形态）；对不支持的目标加方法判空，行为与 GMod 的“没方法就不调”
       一致。
    6. Player:HasWeapon 没有绑定：CCGiveSWEP 用 GetWeapon( class ) 判空
       （同一个 Weapon_OwnsThisType 查询）。
    7. ai.GetSquadMemberCount 没有绑定：InternalSpawnNPC 的“小队溢出改名”
       在缺表时跳过（NPC 保留注册的 SquadName）。
    8. PhysObj:GetAABB 没有绑定：FixInvalidPhysicsObject 早退（它只修
       “vphysics 盒与模型盒差太多”的坏模型）。
    9. 本分叉的 SENT 名册里有一部分没有 SpawnFunction（不基于 base_entity
       的旧脚本）：CanPlayerSpawnSENT 不再因缺 SpawnFunction 直接拒收，
       Spawn_SENT 对这类实体回退 ents.Create + Spawn + Activate（与
       base_entity 默认 SpawnFunction 相同的建法）；有 SpawnFunction 时仍是
       GMod 原路径。
    10. 载具 KeyValues 里的 `vehicleclass` 不能走 SetKeyValue（本分叉它不是
        keyfield——DATADESC FIELD_CHARACTER，datamap 路径只写一个字节）；
        MakeVehicle 跳过它，由 GMod 原文的 vehicle:SetVehicleClass( VName )
        在 Spawn 之后写（旧引擎命令同样这么做）。
    11. duplicator 模块在本分叉是完整存在的（lua/includes/modules/
        duplicator.lua，base/gamemode/save_load.lua 已在用它注册实体类），
        所以 duplicator.DoGeneric/DoGenericPhysics/RegisterEntityClass 保持
        GMod 原文调用，未做判空或跳过。

    注意：GMod 原文的 `gamemode.Call( "PlayerSpawn..." )` 语义与本分叉一致
    （先跑 hook 注册项、再回退 GAMEMODE 方法；方法不存在回答 false），上限体
    系仍落在 sandbox/gamemode/player.lua + player_extension.lua。
----------------------------------------------------------------------------]]--

include( "prop_tools.lua" )

-- A little hacky function to help prevent spawning props partially inside walls
-- Maybe it should use physics object bounds, not OBB, and use physics object bounds to initial position too
local function fixupProp( ply, ent, hitpos, mins, maxs )
	local entPos = ent:GetPos()
	local endposD = ent:LocalToWorld( mins )
	local tr_down = util.TraceLine( {
		start = entPos,
		endpos = endposD,
		filter = { ent, ply }
	} )

	local endposU = ent:LocalToWorld( maxs )
	local tr_up = util.TraceLine( {
		start = entPos,
		endpos = endposU,
		filter = { ent, ply }
	} )

	-- Both traces hit meaning we are probably inside a wall on both sides, do nothing
	if ( tr_up.Hit && tr_down.Hit ) then return end

	if ( tr_down.Hit ) then ent:SetPos( entPos + ( tr_down.HitPos - endposD ) ) end
	if ( tr_up.Hit ) then ent:SetPos( entPos + ( tr_up.HitPos - endposU ) ) end
end

local function TryFixPropPosition( ply, ent, hitpos )
	fixupProp( ply, ent, hitpos, Vector( ent:OBBMins().x, 0, 0 ), Vector( ent:OBBMaxs().x, 0, 0 ) )
	fixupProp( ply, ent, hitpos, Vector( 0, ent:OBBMins().y, 0 ), Vector( 0, ent:OBBMaxs().y, 0 ) )
	fixupProp( ply, ent, hitpos, Vector( 0, 0, ent:OBBMins().z ), Vector( 0, 0, ent:OBBMaxs().z ) )
end

local function GetSpawnTrace( ply )
	local vStart = ply:GetShootPos()
	local vForward = ply:EyeAngles():Forward() -- Ignores world clicker

	local trace = {}
	trace.start = vStart
	trace.endpos = vStart + ( vForward * 2048 )
	trace.filter = { ply, ply:GetVehicle() }

	return util.TraceLine( trace )
end

local function ReportErrorToPlayer( player, error )
	if ( IsValid( player ) ) then
		--player:ChatPrint( "#spawnmenu.error." .. error )
		player:SendLua( [[GAMEMODE:AddNotify( "#spawnmenu.error.]] .. error .. [[", NOTIFY_ERROR, 4 ) surface.PlaySound( "buttons/button10.wav" )]] )
	end
end

--[[---------------------------------------------------------
	HL2SB: 分叉的“生成菜单显示名”契约（对应文件头适配 2）。

	GMod 的 targetname 与显示无关；本分叉把 targetname 当显示名用：
	game/server/baseentity.cpp 在 entity_killed 事件里把 GetEntityName() 写进
	"victimname"，客户端 kill feed 原样显示（不再解析）。旧引擎生成命令在
	生成时用菜单传来的名字 SetName；菜单现在按 GMod 形状只传列表键，名字就
	在服务端从注册表取。注册表里的名字是 GMod 的 "#token"（base_npcs.lua /
	base_vehicles.lua 等），这里用服务端的 language 表解析成人话再写；
	解析不到（不是 "#" 开头或语言表缺条目）就原样写。
-----------------------------------------------------------]]
local function HL2SB_DisplayName( name )
	if ( name == nil or name == "" ) then return nil end
	if ( string.sub( name, 1, 1 ) == "#" and _G.language ~= nil and language.GetPhrase ~= nil ) then
		local phrase = language.GetPhrase( name )
		if ( phrase ~= nil and phrase ~= "" and string.sub( phrase, 1, 1 ) ~= "#" ) then
			return phrase
		end
	end
	return name
end

local function Spawn_SandboxModel( ply, modelName, iSkin, strBody, traceOverride )

	-- We don't support this command from dedicated server console
	if ( !IsValid( ply ) ) then return end

	-- Player is dead, don't allow them to spam stuff
	if ( not ply:Alive() and not ply:IsAdmin() ) then ReportErrorToPlayer( ply, "dead" ) return end

	-- Make sure the model path is valid
	if ( modelName == nil ) then ReportErrorToPlayer( ply, "bad_model" ) return end
	if ( modelName:find( "%.[/\\]" ) ) then ReportErrorToPlayer( ply, "bad_model" ) return end

	-- Clean up the path from attempted blacklist bypasses
	modelName = modelName:gsub( "\\\\+", "/" )
	modelName = modelName:gsub( "//+", "/" )
	modelName = modelName:gsub( "\\/+", "/" )
	modelName = modelName:gsub( "/\\+", "/" )

	-- Cleanup for checks below
	modelName = modelName:lower()
	modelName = modelName:gsub( "\\+", "/" )

	-- Only models are allowed
	if ( !modelName:StartsWith( "models/" ) || !modelName:EndsWith( ".mdl" ) ) then ReportErrorToPlayer( ply, "bad_model" ) return end

	-- Make sure the model is valid
	if ( !util.IsValidModel( modelName ) ) then ReportErrorToPlayer( ply, "bad_model" ) return end

	-- Give the gamemode an opportunity to prevent spawning
	-- TODO: Give strBody to the hook as well?
	if ( !gamemode.Call( "PlayerSpawnObject", ply, modelName, iSkin ) ) then ReportErrorToPlayer( ply, "hook" ) return end

	if ( util.IsValidProp( modelName ) ) then

		GMODSpawnProp( ply, modelName, iSkin, strBody, traceOverride )
		return

	end

	if ( util.IsValidRagdoll( modelName ) ) then

		GMODSpawnRagdoll( ply, modelName, iSkin, strBody, traceOverride )
		return

	end

	-- Not a ragdoll or prop.. must be an 'effect' - spawn it as one
	GMODSpawnEffect( ply, modelName, iSkin, strBody, traceOverride )

end



--[[---------------------------------------------------------
	Name: CCSpawn
	Desc: Console Command for a player to spawn different items
-----------------------------------------------------------]]
function CCSpawn( ply, command, arguments, argumentsStr, traceOverride )

	local iSkin = tonumber( arguments[ 2 ] ) or 0
	local strBody = arguments[ 3 ] or nil

	Spawn_SandboxModel( ply, arguments[ 1 ], iSkin, strBody, traceOverride )

end
concommand.Add( "gm_spawn", CCSpawn, nil, "Spawn sandbox props, ragdolls, and effects." )

local function MakeRagdoll( ply, _, _, model, _, data )

	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnRagdoll", ply, model ) ) then return end

	local ent = ents.Create( "prop_ragdoll" )
	if ( !IsValid( ent ) ) then return end -- Must've hit edict limit

	duplicator.DoGeneric( ent, data )
	ent:Spawn()

	duplicator.DoGenericPhysics( ent, ply, data )

	ent:Activate()

	if ( IsValid( ply ) ) then
		-- HL2SB: GMod 在这里 ent:SetCreator( ply ) —— 本分叉没有该绑定（undo/
		-- cleanup 已持有玩家），删除；道具/布娃娃不需要显示名。
		gamemode.Call( "PlayerSpawnedRagdoll", ply, model, ent )
	end

	DoPropSpawnedEffect( ent )

	return ent

end

-- Register the "prop_ragdoll" class with the duplicator, (Args in brackets will be retreived for every bone)
duplicator.RegisterEntityClass( "prop_ragdoll", MakeRagdoll, "Pos", "Ang", "Model", "PhysicsObjects", "Data" )

--[[---------------------------------------------------------
	Name: GMODSpawnRagdoll - player spawns a ragdoll
-----------------------------------------------------------]]
function GMODSpawnRagdoll( ply, model, iSkin, strBody, tr )

	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnRagdoll", ply, model ) ) then ReportErrorToPlayer( ply, "hook" ) return end

	local ragdoll = DoPlayerEntitySpawn( ply, "prop_ragdoll", model, iSkin, strBody, tr )
	if ( !IsValid( ragdoll ) ) then ReportErrorToPlayer( ply, "no_entity" ) return end -- Must've hit edict limit

	if ( IsValid( ply ) ) then
		gamemode.Call( "PlayerSpawnedRagdoll", ply, model, ragdoll )
	end

	DoPropSpawnedEffect( ragdoll )

	undo.Create( "prop_ragdoll" )
		undo.SetPlayer( ply )
		undo.AddEntity( ragdoll )
	undo.Finish( "#prop_ragdoll (" .. tostring( model ) .. ")" )

	ply:AddCleanup( "ragdolls", ragdoll )

end

function MakeProp( ply, pos, ang, model, _, data )

	-- Uck.
	data.Pos = pos
	data.Angle = ang
	data.Model = model

	-- Make sure this is allowed
	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnProp", ply, model ) ) then return end

	local prop = ents.Create( "prop_physics" )
	if ( !IsValid( prop ) ) then return end -- Must've hit edict limit

	duplicator.DoGeneric( prop, data )
	prop:Spawn()

	duplicator.DoGenericPhysics( prop, ply, data )

	-- Tell the gamemode we just spawned something
	if ( IsValid( ply ) ) then
		-- HL2SB: GMod 在这里 prop:SetCreator( ply ) —— 无此绑定，删除（undo/
		-- cleanup 已持有玩家）；道具显示名走 undo 的模型路径，不设 targetname。
		gamemode.Call( "PlayerSpawnedProp", ply, model, prop )
	end

	FixInvalidPhysicsObject( prop )

	DoPropSpawnedEffect( prop )

	return prop

end

duplicator.RegisterEntityClass( "prop_physics", MakeProp, "Pos", "Ang", "Model", "PhysicsObjects", "Data" )
duplicator.RegisterEntityClass( "prop_physics_multiplayer", MakeProp, "Pos", "Ang", "Model", "PhysicsObjects", "Data" )

function MakeEffect( ply, model, data )

	data.Model = model

	-- Make sure this is allowed
	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnEffect", ply, model ) ) then return end

	local prop = ents.Create( "prop_effect" )
	if ( !IsValid( prop ) ) then return end -- Must've hit edict limit

	duplicator.DoGeneric( prop, data )
	if ( data.AttachedEntityInfo ) then
		prop.AttachedEntityInfo = table.Copy( data.AttachedEntityInfo ) -- This shouldn't be neccesary
	end
	prop:Spawn()

	-- duplicator.DoGenericPhysics( Prop, ply, Data )

	-- Tell the gamemode we just spawned something
	if ( IsValid( ply ) ) then
		-- HL2SB: GMod 在这里 prop:SetCreator( ply ) —— 无此绑定，删除。
		gamemode.Call( "PlayerSpawnedEffect", ply, model, prop )
	end

	if ( IsValid( prop.AttachedEntity ) ) then
		DoPropSpawnedEffect( prop.AttachedEntity )
	end

	return prop

end

duplicator.RegisterEntityClass( "prop_effect", MakeEffect, "Model", "Data" )

--[[---------------------------------------------------------
	Name: FixInvalidPhysicsObject
	Desc: Attempts to detect and correct the physics object
	on models such as the TF2 Turrets
-----------------------------------------------------------]]
function FixInvalidPhysicsObject( prop )

	local PhysObj = prop:GetPhysicsObject()
	if ( !IsValid( PhysObj ) ) then return end

	-- HL2SB: PhysObj:GetAABB 在本分叉没有绑定（GMod 有）。它是“vphysics 盒与
	-- 模型盒差太多”这套检测的唯一输入，缺了就什么都不做——旧引擎生成路径
	-- 同样不修。正常模型不受影响。
	if ( PhysObj.GetAABB == nil ) then return end

	local min, max = PhysObj:GetAABB()
	if ( !min or !max ) then return end

	local PhysSize = ( min - max ):Length()
	if ( PhysSize > 5 ) then return end

	local mins = prop:OBBMins()
	local maxs = prop:OBBMaxs()
	if ( !mins or !maxs ) then return end

	local ModelSize = ( mins - maxs ):Length()
	local Difference = math.abs( ModelSize - PhysSize )
	if ( Difference < 10 ) then return end

	-- This physics object is definitiely weird.
	-- Make a new one.
	prop:PhysicsInitBox( mins, maxs )
	prop:SetCollisionGroup( COLLISION_GROUP_DEBRIS )

	-- Check for success
	PhysObj = prop:GetPhysicsObject()
	if ( !IsValid( PhysObj ) ) then return end

	PhysObj:SetMass( 100 )
	PhysObj:Wake()

end

--[[---------------------------------------------------------
	Name: GMODSpawnProp - player spawns a prop
-----------------------------------------------------------]]
function GMODSpawnProp( ply, model, iSkin, strBody, tr )

	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnProp", ply, model ) ) then ReportErrorToPlayer( ply, "hook" ) return end

	local e = DoPlayerEntitySpawn( ply, "prop_physics", model, iSkin, strBody, tr )
	if ( !IsValid( e ) ) then ReportErrorToPlayer( ply, "no_entity" ) return end

	if ( IsValid( ply ) ) then
		gamemode.Call( "PlayerSpawnedProp", ply, model, e )
	end

	-- This didn't work out - todo: Find a better way.
	--timer.Simple( 0.01, CheckPropSolid, e, COLLISION_GROUP_NONE, COLLISION_GROUP_WORLD )

	FixInvalidPhysicsObject( e )

	DoPropSpawnedEffect( e )

	undo.Create( "prop_physics" )
		undo.SetPlayer( ply )
		undo.AddEntity( e )
	undo.Finish( "#prop_physics (" .. tostring( model ) .. ")" )

	ply:AddCleanup( "props", e )

end

--[[---------------------------------------------------------
	Name: GMODSpawnEffect
-----------------------------------------------------------]]
function GMODSpawnEffect( ply, model, iSkin, strBody, tr )

	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnEffect", ply, model ) ) then ReportErrorToPlayer( ply, "hook" ) return end

	local e = DoPlayerEntitySpawn( ply, "prop_effect", model, iSkin, strBody, tr )
	if ( !IsValid( e ) ) then ReportErrorToPlayer( ply, "no_entity" ) return end

	if ( IsValid( ply ) ) then
		gamemode.Call( "PlayerSpawnedEffect", ply, model, e )
	end

	if ( IsValid( e.AttachedEntity ) ) then
		DoPropSpawnedEffect( e.AttachedEntity )
	end

	undo.Create( "prop_effect" )
		undo.SetPlayer( ply )
		undo.AddEntity( e )
	undo.Finish( "#prop_effect (" .. tostring( model ) .. ")" )

	ply:AddCleanup( "effects", e )

end

--[[---------------------------------------------------------
	Name: DoPlayerEntitySpawn
	Desc: Utility function for player entity spawning functions
-----------------------------------------------------------]]
function DoPlayerEntitySpawn( ply, entity_name, model, iSkin, strBody, tr )

	if ( !tr ) then tr = GetSpawnTrace( ply ) end

	-- Prevent spawning too close
	--[[if ( !tr.Hit or tr.Fraction < 0.05 ) then
		return
	end]]

	local ent = ents.Create( entity_name )
	if ( !IsValid( ent ) ) then return end

	local ang = ply:EyeAngles()
	ang.yaw = ang.yaw + 180 -- Rotate it 180 degrees in my favour
	ang.roll = 0
	ang.pitch = 0

	if ( entity_name == "prop_ragdoll" ) then
		ang.pitch = -90
	end

	ent:SetModel( model )
	ent:SetSkin( iSkin )
	ent:SetAngles( ang )
	-- HL2SB: GMod 的 Entity:SetBodyGroups（复数、十六进制串）在本分叉由
	-- CBaseAnimating 的共享绑定提供；对没有该方法的实体保持“不调”的原语义。
	if ( strBody and ent.SetBodyGroups ~= nil ) then ent:SetBodyGroups( strBody ) end
	ent:SetPos( tr.HitPos )
	-- HL2SB: GMod 在这里 ent:SetCreator( ply ) —— 无此绑定，删除。
	ent:Spawn()
	ent:Activate()

	-- Special case for effects
	if ( strBody && entity_name == "prop_effect" && IsValid( ent.AttachedEntity ) ) then
		if ( ent.AttachedEntity.SetBodyGroups ~= nil ) then
			ent.AttachedEntity:SetBodyGroups( strBody )
		end
	end

	-- HL2SB: GMod 在这里做“贴地 flush”（ent:NearestPoint 那四行），本分叉
	-- 没有该方法的引擎绑定，整段略过——旧引擎生成路径（GM_SpawnAtEyeTrace）
	-- 同样只把实体放在 tr.HitPos + 法线偏移，不做 flush。位置保持 tr.HitPos。
	-- 成就调用按 GMod 原文保留（achievements 模块两端都有 inert 实现）。
	if ( entity_name != "prop_ragdoll" ) then

		ply:SendLua( "achievements.SpawnedProp()" )

	else

		ply:SendLua( "achievements.SpawnedRagdoll()" )

	end

	TryFixPropPosition( ply, ent, tr.HitPos )

	return ent

end

local function InternalSpawnNPC( NPCData, ply, Position, Normal, Class, Equipment, SpawnFlagsSaved, NoDropToFloor )

	-- Don't let them spawn this entity if it isn't in our NPC Spawn list.
	-- We don't want them spawning any entity they like!
	if ( !NPCData ) then return NULL end

	local isAdmin = ( IsValid( ply ) && ply:IsAdmin() ) or game.SinglePlayer()
	if ( NPCData.AdminOnly && !isAdmin ) then return NULL end

	local bDropToFloor = false
	local wasSpawnedOnCeiling = false
	local wasSpawnedOnFloor = false

	--
	-- This NPC has to be spawned on a ceiling (Barnacle) or a floor (Turrets)
	--
	if ( NPCData.OnCeiling or NPCData.OnFloor ) then
		local isOnCeiling	= Vector( 0, 0, -1 ):Dot( Normal ) >= 0.95
		local isOnFloor		= Vector( 0, 0,  1 ):Dot( Normal ) >= 0.95

		-- Not on ceiling, and we can't be on floor
		if ( !isOnCeiling && !NPCData.OnFloor ) then return NULL end

		-- Not on floor, and we can't be on ceiling
		if ( !isOnFloor && !NPCData.OnCeiling ) then return NULL end

		-- We can be on either, and we are on neither
		if ( !isOnFloor && !isOnCeiling ) then return NULL end

		wasSpawnedOnCeiling = isOnCeiling
		wasSpawnedOnFloor = isOnFloor
	else
		bDropToFloor = true
	end

	if ( NPCData.NoDrop or NoDropToFloor ) then bDropToFloor = false end

	-- Create NPC
	local NPC = ents.Create( NPCData.Class )
	if ( !IsValid( NPC ) ) then return NULL end

	--
	-- Offset the position
	--
	local Offset = NPCData.Offset or 32
	NPC:SetPos( Position + Normal * Offset )

	-- Rotate to face player (expected behaviour)
	local Angles = Angle( 0, 0, 0 )

	if ( IsValid( ply ) ) then
		Angles = ply:GetAngles()
	end

	Angles.pitch = 0
	Angles.roll = 0
	Angles.yaw = Angles.yaw + 180

	if ( NPCData.Rotate ) then Angles = Angles + NPCData.Rotate end

	NPC:SetAngles( Angles )

	if ( NPCData.SnapToNormal ) then
		NPC:SetAngles( Normal:Angle() )
	end

	--
	-- Does this NPC have a specified model? If so, use it.
	--
	local NPCModel = NPCData.Model
	if ( istable( NPCModel ) ) then NPCModel = NPCModel[ math.random( #NPCModel ) ] end
	if ( NPCModel ) then
		NPC:SetModel( NPCModel )
	end

	--
	-- Does this NPC have a specified material? If so, use it.
	--
	if ( NPCData.Material ) then
		NPC:SetMaterial( NPCData.Material )
	end

	--
	-- Spawn Flags
	--
	local SpawnFlags = bit.bor( SF_NPC_FADE_CORPSE, SF_NPC_ALWAYSTHINK )
	if ( NPCData.SpawnFlags ) then SpawnFlags = bit.bor( SpawnFlags, NPCData.SpawnFlags ) end
	if ( NPCData.TotalSpawnFlags ) then SpawnFlags = NPCData.TotalSpawnFlags end
	if ( SpawnFlagsSaved ) then SpawnFlags = SpawnFlagsSaved end
	NPC:SetKeyValue( "spawnflags", SpawnFlags )
	NPC.SpawnFlags = SpawnFlags

	--
	-- Optional Key Values
	--
	local squadName = nil
	if ( NPCData.KeyValues ) then
		for k, v in pairs( NPCData.KeyValues ) do
			NPC:SetKeyValue( k, v )

			if ( string.lower( k ) == "squadname" ) then squadName = v end
		end
	end

	--
	-- Handle squads being overflown.
	--
	-- HL2SB: 本分叉没有 ai.GetSquadMemberCount 绑定；表缺了就跳过“小队溢出
	-- 改名”这一步，NPC 保留注册的 SquadName（GMod 只在溢出时才改名）。
	local MAX_SQUAD_MEMBERS	= 16
	if ( squadName and _G.ai ~= nil and ai.GetSquadMemberCount ~= nil
		and ai.GetSquadMemberCount( squadName ) >= MAX_SQUAD_MEMBERS ) then

		-- Find first open squad
		local sqNum = 0
		while ( ai.GetSquadMemberCount( squadName .. sqNum ) >= MAX_SQUAD_MEMBERS ) do
			sqNum = sqNum + 1
		end

		NPC:SetKeyValue( "SquadName", squadName .. sqNum )
	end

	--
	-- Does this NPC have a specified skin? If so, use it.
	--
	if ( NPCData.Skin ) then
		NPC:SetSkin( NPCData.Skin )
	end

	--
	-- What weapon this NPC should be carrying
	--

	-- Check if this is a valid weapon from the list, or the user is trying to fool us.
	local valid = false
	for _, v in pairs( list.Get( "NPCUsableWeapons" ) ) do
		if ( v.class == Equipment ) then valid = true break end
	end
	for _, v in pairs( NPCData.Weapons or {} ) do
		if ( v == Equipment ) then valid = true break end
	end

	if ( Equipment && Equipment != "none" && valid ) then
		NPC:SetKeyValue( "additionalequipment", Equipment )
		NPC.Equipment = Equipment
	end

	if ( wasSpawnedOnCeiling && isfunction( NPCData.OnCeiling ) ) then
		NPCData.OnCeiling( NPC )
	elseif ( wasSpawnedOnFloor && isfunction( NPCData.OnFloor ) ) then
		NPCData.OnFloor( NPC )
	end

	-- Allow special case for duplicator stuff
	if ( isfunction( NPCData.OnDuplicated ) ) then
		NPC.OnDuplicated = NPCData.OnDuplicated
	end

	DoPropSpawnedEffect( NPC )

	NPC:Spawn()
	NPC:Activate()

	-- Store spawnmenu data for addons and stuff
	NPC.NPCName = Class
	NPC._wasSpawnedOnCeiling = wasSpawnedOnCeiling

	-- For those NPCs that set their model/skin in Spawn function
	-- We have to keep the call above for NPCs that want a model set by Spawn() time
	-- BAD: They may adversly affect entity collision bounds
	if ( NPCModel && NPC:GetModel():lower() != NPCModel:lower() ) then
		NPC:SetModel( NPCModel )
	end
	if ( NPCData.Skin ) then
		NPC:SetSkin( NPCData.Skin )
	end

	if ( bDropToFloor ) then
		-- HL2SB: GMod 的 Entity:DropToFloor() 方法已在本分叉补齐（见
		-- lua/includes/extensions/entity.lua 的 GMod 兼容垫片，内部走
		-- util.DropToFloor( ent, MASK_NPCSOLID )），保持 GMod 原文调用。
		NPC:DropToFloor()
	end

	if ( NPCData.Health ) then
		NPC:SetHealth( NPCData.Health )
		NPC:SetMaxHealth( NPCData.Health )
	end

	-- Body groups
	if ( NPCData.BodyGroups ) then
		for k, v in pairs( NPCData.BodyGroups ) do
			NPC:SetBodygroup( k, v )
		end
	end

	return NPC

end

function Spawn_NPC( ply, NPCClassName, WeaponName, tr )

	-- We don't support this command from dedicated server console
	if ( !IsValid( ply ) ) then return end

	-- Player is dead, don't allow them to spam stuff
	if ( not ply:Alive() and not ply:IsAdmin() ) then ReportErrorToPlayer( ply, "dead" ) return end

	if ( !NPCClassName ) then ReportErrorToPlayer( ply, "bad_npc" ) return end

	-- Give the gamemode an opportunity to deny spawning
	if ( !gamemode.Call( "PlayerSpawnNPC", ply, NPCClassName, WeaponName ) ) then ReportErrorToPlayer( ply, "hook" ) return end

	if ( !tr ) then tr = GetSpawnTrace( ply ) end

	local NPCData = list.GetEntry( "NPC", NPCClassName )

	-- Create the NPC if you can.
	local SpawnedNPC = InternalSpawnNPC( NPCData, ply, tr.HitPos, tr.HitNormal, NPCClassName, WeaponName )
	if ( !IsValid( SpawnedNPC ) ) then ReportErrorToPlayer( ply, "no_entity" ) return end

	TryFixPropPosition( ply, SpawnedNPC, tr.HitPos )

	-- Give the gamemode an opportunity to do whatever
	if ( IsValid( ply ) ) then
		-- HL2SB: 显示名契约（文件头适配 2）——旧引擎命令在这里 SetName 菜单发来
		-- 的名字；现在从注册表 NPCData.Name 取（"#token" 先解析成人话）。
		-- 只在该条目真的注册过 Name 时设置，否则保持引擎的默认显示名。
		if ( NPCData and NPCData.Name ) then
			SpawnedNPC:SetName( HL2SB_DisplayName( NPCData.Name ) )
		end

		-- HL2SB: GMod 在这里 SpawnedNPC:SetCreator( ply ) —— 无此绑定，删除。
		gamemode.Call( "PlayerSpawnedNPC", ply, SpawnedNPC )
	end

	-- See if we can find a nice name for this NPC..
	local NiceName = NPCClassName
	if ( NPCData and NPCData.Name ) then NiceName = NPCData.Name end

	-- Add to undo list
	undo.Create( "NPC" )
		undo.SetPlayer( ply )
		undo.AddEntity( SpawnedNPC )
		if ( NiceName ) then
			undo.SetCustomUndoText( "Undone " .. NiceName )
		end
	undo.Finish( "#undo.generic.npc (" .. tostring( NiceName ) .. ")" )

	-- And cleanup
	ply:AddCleanup( "npcs", SpawnedNPC )

	ply:SendLua( "achievements.SpawnedNPC()" )

	return SpawnedNPC

end
concommand.Add( "gmod_spawnnpc", function( ply, cmd, args ) Spawn_NPC( ply, args[ 1 ], args[ 2 ] ) end, nil, "Spawn sandbox NPCs." )

-- This should be in base_npcs.lua really
local function GenericNPCDuplicator( ply, class, equipment, spawnflags, data )

	-- Match the behavior of Spawn_NPC above - class should be the one in the list, NOT the entity class!
	if ( data.NPCName ) then class = data.NPCName end

	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnNPC", ply, class, equipment ) ) then return NULL end

	local NPCData = list.GetEntry( "NPC", class )

	local normal = Vector( 0, 0, 1 )
	if ( NPCData && NPCData.OnCeiling && ( NPCData.OnFloor && data._wasSpawnedOnCeiling or !NPCData.OnFloor ) ) then
		normal = Vector( 0, 0, -1 )
	end

	local ent = InternalSpawnNPC( NPCData, ply, data.Pos, normal, class, equipment, spawnflags, true )
	if ( IsValid( ent ) ) then

		local pos = ent:GetPos() -- Hack! Prevents the NPCs from falling through the floor

		duplicator.DoGeneric( ent, data )

		if ( NPCData && !NPCData.OnCeiling && !NPCData.NoDrop ) then
			ent:SetPos( pos )
		end

		if ( IsValid( ply ) ) then
			-- HL2SB: GMod 在这里 ent:SetCreator( ply ) —— 无此绑定，删除；
			-- 显示名已在 Spawn_NPC/InternalSpawnNPC 契约里，duplicator 路径
			-- 不重复写（EntityName 来自存档数据，可能不是注册表键）。
			gamemode.Call( "PlayerSpawnedNPC", ply, ent )
			ply:AddCleanup( "npcs", ent )
		end

		if ( data.CurHealth ) then ent:SetHealth( data.CurHealth ) end
		if ( data.MaxHealth ) then ent:SetMaxHealth( data.MaxHealth ) end

		table.Merge( ent:GetTable(), data )

	end

	return ent

end

-- Duplicator support for all base NPCs
local NPCClassList = {
	-- Half-Life 2
	"npc_alyx", "npc_breen", "npc_kleiner",
	"npc_antlion", "npc_antlionguard", "npc_barnacle",
	"npc_barney", "npc_combine_s", "npc_crow", "npc_cscanner",
	"npc_clawscanner", "npc_dog", "npc_eli", "npc_gman", "npc_headcrab",
	"npc_headcrab_black", "npc_headcrab_poison","npc_headcrab_fast",
	"npc_manhack", "npc_metropolice", "npc_monk", "npc_mossman",
	"npc_pigeon", "npc_rollermine", "npc_strider",
	"npc_helicopter", "npc_combinegunship", "npc_combinedropship",
	"npc_turret_ceiling", "npc_combine_camera", "npc_turret_floor",
	"npc_vortigaunt", "npc_sniper", "npc_seagull", "npc_citizen",
	"npc_stalker", "npc_zombie", "npc_zombie_torso", "npc_zombine",
	"npc_poisonzombie", "npc_fastzombie", "npc_fastzombie_torso",

	-- Episode 2
	"npc_hunter", "npc_antlion_worker", "npc_antlion_grub", "npc_magnusson",

	-- Lost Coast
	"npc_fisherman",

	-- Half-Life Source
	"monster_alien_grunt", "monster_alien_slave", "monster_alien_controller",
	"monster_barney", "monster_bigmomma", "monster_bullchicken",
	"monster_babycrab", "monster_cockroach", "monster_houndeye",
	"monster_headcrab", "monster_gargantua", "monster_human_assassin",
	"monster_human_grunt", "monster_scientist", "monster_snark",
	"monster_nihilanth", "monster_tentacle", "monster_zombie",
	"monster_turret", "monster_miniturret", "monster_sentry",

	-- Portal
	"npc_portal_turret_floor",
	"npc_rocket_turret",
	"npc_security_camera",
}

for _, v in ipairs( NPCClassList ) do
	duplicator.RegisterEntityClass( v, GenericNPCDuplicator, "Class", "Equipment", "SpawnFlags", "Data" )
end

--[[---------------------------------------------------------
	Name: CanPlayerSpawnSENT
-----------------------------------------------------------]]
local function CanPlayerSpawnSENT( ply, EntityName )

	local isAdmin = ( IsValid( ply ) && ply:IsAdmin() ) or game.SinglePlayer()

	-- Make sure that given EntityName is actually a SENT
	local sent = scripted_ents.GetStored( EntityName )
	if ( sent == nil ) then

		-- Is the entity spawnable?
		local EntTable = list.GetEntry( "SpawnableEntities", EntityName )
		if ( !EntTable ) then ReportErrorToPlayer( ply, "bad_sent" ) return false end
		if ( EntTable.AdminOnly && !isAdmin ) then ReportErrorToPlayer( ply, "bad_sent" ) return false end
		return true

	end

	-- We need a spawn function. The SENT can then spawn itself properly
	local SpawnFunction = scripted_ents.GetMember( EntityName, "SpawnFunction" )
	if ( !isfunction( SpawnFunction ) ) then
		-- HL2SB: GMod 在这里直接拒收（"bad_sent"）。本分叉名册里有一部分
		-- SENT 没有 SpawnFunction（不基于 base_entity 的旧脚本），旧引擎命令
		-- 仍能生成它们；这里放行，由 Spawn_SENT 走
		-- ents.Create + Spawn + Activate 的回退。Spawnable/AdminOnly 两道闸
		-- 仍在下面照常执行。
	end

	-- You're not allowed to spawn this unless you're an admin!
	if ( !scripted_ents.GetMember( EntityName, "Spawnable" ) && !isAdmin ) then ReportErrorToPlayer( ply, "admin" )  return false end
	if ( scripted_ents.GetMember( EntityName, "AdminOnly" ) && !isAdmin ) then ReportErrorToPlayer( ply, "admin" ) return false end

	return true

end

--[[---------------------------------------------------------
	Name: Spawn_SENT
	Desc: Console Command for a player to spawn different items
-----------------------------------------------------------]]
function Spawn_SENT( ply, EntityName, tr )

	-- We don't support this command from dedicated server console
	if ( !IsValid( ply ) ) then return end

	-- Player is dead, don't allow them to spam stuff
	if ( not ply:Alive() and not ply:IsAdmin() ) then ReportErrorToPlayer( ply, "dead" ) return end

	if ( EntityName == nil ) then ReportErrorToPlayer( ply, "bad_sent" ) return end

	if ( !CanPlayerSpawnSENT( ply, EntityName ) ) then return end

	-- Ask the gamemode if it's OK to spawn this
	if ( !gamemode.Call( "PlayerSpawnSENT", ply, EntityName ) ) then ReportErrorToPlayer( ply, "hook" ) return end

	if ( !tr ) then tr = GetSpawnTrace( ply ) end

	local entity = nil
	local PrintName = EntityName
	local sent = scripted_ents.GetStored( EntityName )

	if ( sent ) then

		local sentTable = sent.t

		ClassName = EntityName

			local SpawnFunction = scripted_ents.GetMember( EntityName, "SpawnFunction" )
			if ( !SpawnFunction ) then
				-- HL2SB: GMod 在这里报错拒生成。本分叉的旧 SENT 脚本集合里
				-- 有一部分没有 SpawnFunction（CanPlayerSpawnSENT 已放行），
				-- 回退到与 base_entity 默认 SpawnFunction 相同的建法：
				-- ents.Create + SetPos + Spawn + Activate。
				entity = ents.Create( EntityName )
				if ( IsValid( entity ) ) then
					entity:SetPos( tr.HitPos + tr.HitNormal * 16 )
					entity:Spawn()
					entity:Activate()
				end
			else
				entity = SpawnFunction( sentTable, ply, tr, EntityName )
			end

			if ( IsValid( entity ) ) then
				-- HL2SB: 显示名契约（文件头适配 2）——旧引擎命令在这里 SetName
				-- 菜单发来的名字；现在用 sentTable.PrintName（"#token" 先解析）。
				if ( sentTable ~= nil and sentTable.PrintName ) then
					entity:SetName( HL2SB_DisplayName( sentTable.PrintName ) )
				end

				-- HL2SB: GMod 在这里 entity:SetCreator( ply ) —— 无此绑定，删除。
			end

		ClassName = nil

		PrintName = sentTable.PrintName

	else

		-- Spawn from list table
		local EntTable = list.GetEntry( "SpawnableEntities", EntityName )
		if ( !EntTable ) then ReportErrorToPlayer( ply, "bad_sent" ) return end

		PrintName = EntTable.PrintName

		local SpawnPos = tr.HitPos + tr.HitNormal * 16
		if ( EntTable.NormalOffset ) then SpawnPos = SpawnPos + tr.HitNormal * EntTable.NormalOffset end

		-- Make sure the spawn position is not out of bounds
		local oobTr = util.TraceLine( {
			start = tr.HitPos,
			endpos = SpawnPos,
			mask = MASK_SOLID_BRUSHONLY
		} )

		if ( oobTr.Hit ) then
			SpawnPos = oobTr.HitPos + oobTr.HitNormal * ( tr.HitPos:Distance( oobTr.HitPos ) / 2 )
		end

		entity = ents.Create( EntTable.ClassName )
		if ( !IsValid( entity ) ) then ReportErrorToPlayer( ply, "no_entity" ) return end

		entity:SetPos( SpawnPos )

		if ( EntTable.KeyValues ) then
			for k, v in pairs( EntTable.KeyValues ) do
				entity:SetKeyValue( k, v )
			end
		end

		if ( EntTable.Material ) then
			entity:SetMaterial( EntTable.Material )
		end

		entity:Spawn()
		entity:Activate()
		entity.EntityName = EntityName -- For duplicator usage later on

		DoPropSpawnedEffect( entity )

		if ( EntTable.DropToFloor ) then
			-- HL2SB: Entity:DropToFloor() 方法垫片见 extensions/entity.lua
			-- （GMod 原文调用，内部 util.DropToFloor）。
			entity:DropToFloor()
		end

		-- HL2SB: 显示名契约（文件头适配 2）；只在该条目注册过 PrintName 时设。
		if ( EntTable.PrintName ) then
			entity:SetName( HL2SB_DisplayName( EntTable.PrintName ) )
		end

	end

	if ( !IsValid( entity ) ) then
		-- Existing addons doing weird things...
		if ( entity != nil ) then ReportErrorToPlayer( ply, "no_entity" ) end
		return
	end

	TryFixPropPosition( ply, entity, tr.HitPos )

	if ( IsValid( ply ) ) then
		gamemode.Call( "PlayerSpawnedSENT", ply, entity )
	end

	undo.Create( "SENT" )
		undo.SetPlayer( ply )
		undo.AddEntity( entity )
		if ( PrintName ) then
			undo.SetCustomUndoText( "Undone " .. PrintName )
		end
	undo.Finish( "#undo.generic.entity (" .. tostring( PrintName ) .. ")" )

	ply:AddCleanup( "sents", entity )
	entity:SetVar( "Player", ply )

	return entity

end
concommand.Add( "gm_spawnsent", function( ply, cmd, args ) Spawn_SENT( ply, args[ 1 ] ) end, nil, "Spawn sandbox scripted entities." )

--[[---------------------------------------------------------
	-- Give a swep.
-----------------------------------------------------------]]
function CCGiveSWEP( ply, command, arguments )

	-- We don't support this command from dedicated server console
	if ( !IsValid( ply ) ) then return end

	-- Player is dead, don't allow them to spam stuff
	if ( !ply:Alive() ) then ReportErrorToPlayer( ply, "dead" ) return end

	if ( arguments[1] == nil ) then ReportErrorToPlayer( ply, "bad_weapon" ) return end

	-- Make sure this is a SWEP
	local swep = list.GetEntry( "Weapon", arguments[1] )
	if ( swep == nil ) then ReportErrorToPlayer( ply, "bad_weapon" ) return end

	-- You're not allowed to spawn this!
	local isAdmin = ply:IsAdmin() or game.SinglePlayer()
	if ( ( !swep.Spawnable && !isAdmin ) or ( swep.AdminOnly && !isAdmin ) ) then
		return
	end

	if ( !gamemode.Call( "PlayerGiveSWEP", ply, arguments[1], swep ) ) then ReportErrorToPlayer( ply, "hook" ) return end

	-- HL2SB: GMod 用 Player:HasWeapon；本分叉没有该绑定，GetWeapon( class )
	-- 是同一查询（Weapon_OwnsThisType，未持有时回 nil）。
	if ( !IsValid( ply:GetWeapon( swep.ClassName ) ) ) then
		MsgAll( "Giving " .. ply:Nick() .. " a " .. swep.ClassName .. "\n" )
		ply:Give( swep.ClassName )
	end

	-- And switch to it
	ply:SelectWeapon( swep.ClassName )

end
concommand.Add( "gm_giveswep", CCGiveSWEP, nil, "Give a sandbox weapons directly to the executing player." )

--[[---------------------------------------------------------
	-- Spawn a SWEP on the ground
-----------------------------------------------------------]]
function Spawn_Weapon( ply, wepname, tr )

	-- We don't support this command from dedicated server console
	if ( !IsValid( ply ) ) then return end

	-- Player is dead, don't allow them to spam stuff
	if ( not ply:Alive() and not ply:IsAdmin() ) then ReportErrorToPlayer( ply, "dead" ) return end

	if ( wepname == nil ) then ReportErrorToPlayer( ply, "bad_weapon" ) return end

	-- Make sure this is a SWEP
	local swep = list.GetEntry( "Weapon", wepname )
	if ( swep == nil ) then ReportErrorToPlayer( ply, "bad_weapon" ) return end

	-- You're not allowed to spawn this!
	local isAdmin = ply:IsAdmin() or game.SinglePlayer()
	if ( ( !swep.Spawnable && !isAdmin ) or ( swep.AdminOnly && !isAdmin ) ) then
		ReportErrorToPlayer( ply, "admin" )
		return
	end

	-- Do not allow spawning weapons with no model
	local swepTable = weapons.Get( swep.ClassName )
	if ( swepTable && swepTable.WorldModel == "" && !isAdmin ) then
		ReportErrorToPlayer( ply, "bad_weapon" )
		return
	end

	if ( !gamemode.Call( "PlayerSpawnSWEP", ply, wepname, swep ) ) then ReportErrorToPlayer( ply, "hook" ) return end

	if ( !tr ) then tr = GetSpawnTrace( ply ) end

	local entity = ents.Create( swep.ClassName )
	if ( !IsValid( entity ) ) then ReportErrorToPlayer( ply, "no_entity" ) return end

	DoPropSpawnedEffect( entity )

	local SpawnPos = tr.HitPos + tr.HitNormal * 32

	-- Make sure the spawn position is not out of bounds
	local oobTr = util.TraceLine( {
		start = tr.HitPos,
		endpos = SpawnPos,
		mask = MASK_SOLID_BRUSHONLY
	} )

	if ( oobTr.Hit ) then
		SpawnPos = oobTr.HitPos + oobTr.HitNormal * ( tr.HitPos:Distance( oobTr.HitPos ) / 2 )
	end

	-- HL2SB: GMod 在这里 entity:SetCreator( ply ) —— 无此绑定，删除（武器实体
	-- 不是 kill feed 的显示名对象，不需要 SetName 替代）。
	entity:SetPos( SpawnPos )
	entity:Spawn()

	undo.Create( "SWEP" )
		undo.SetPlayer( ply )
		undo.AddEntity( entity )
		undo.SetCustomUndoText( "Undone " .. tostring( swep.PrintName ) )
	undo.Finish( "#undo.generic.weapon (" .. tostring( swep.PrintName ) .. ")" )

	-- Throw it into SENTs category
	ply:AddCleanup( "sents", entity )

	TryFixPropPosition( ply, entity, tr.HitPos )

	gamemode.Call( "PlayerSpawnedSWEP", ply, entity )

	return entity

end
concommand.Add( "gm_spawnswep", function( ply, cmd, args ) Spawn_Weapon( ply, args[1] ) end, nil, "Spawn sandbox weapons where the player is looking at." )

-- Do not allow people to undo weapons from player's hands
hook.Add( "WeaponEquip", "SpawnWeaponUndoRemoval", function( wep, ply )
	undo.ReplaceEntity( wep, nil )
	cleanup.ReplaceEntity( wep, nil )
end )

local function MakeVehicle( ply, pos, ang, model, className, VName, data )

	local VTable = list.GetEntry( "Vehicles", VName )
	if ( VTable ) then
		-- Load the proper model & class, instead of whatever the dupe wanted us to use
		-- For very old dupes, VName will not be set.
		model = VTable.Model
		className = VTable.Class
	end

	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnVehicle", ply, model, VName, VTable ) ) then return end

	local vehicle = ents.Create( className )
	if ( !IsValid( vehicle ) ) then return NULL end

	duplicator.DoGeneric( vehicle, data )

	vehicle:SetModel( model )

	-- Fallback vehiclescripts for HL2 maps ( dupe support )
	if ( model == "models/buggy.mdl" ) then vehicle:SetKeyValue( "vehiclescript", "scripts/vehicles/jeep_test.txt" ) end
	if ( model == "models/vehicle.mdl" ) then vehicle:SetKeyValue( "vehiclescript", "scripts/vehicles/jalopy.txt" ) end

	-- Fill in the keyvalues if we have them
	if ( VTable && VTable.KeyValues ) then
		for k, v in pairs( VTable.KeyValues ) do
			-- HL2SB: `vehicleclass` 不能走 SetKeyValue —— 本分叉里它不是
			-- keyfield（DATADESC FIELD_CHARACTER，datamap 的键值路径只往
			-- char[64] 写一个字节）。它在 Spawn 之后由下面 GMod 原文的
			-- vehicle:SetVehicleClass( VName ) 写入（旧引擎命令也是这么做的：
			-- GM_SpawnAtEyeTrace 跳过它、DispatchSpawn 后调
			-- HL2SB_SetEntityVehicleClass）。
			if ( k != "vehicleclass" ) then
				vehicle:SetKeyValue( k, v )
			end
		end
	end

	-- HL2SB: GMod 在这里 if ( ply ) then vehicle:SetCreator( ply ) end ——
	-- SetCreator 无绑定（删除）；改用显示名契约：注册表 VTable.Name 写进
	-- targetname（kill feed / 显示名，旧引擎命令同款 SetName）。
	if ( VTable and VTable.Name ) then
		vehicle:SetName( HL2SB_DisplayName( VTable.Name ) )
	end

	vehicle:SetAngles( ang )
	vehicle:SetPos( pos )

	DoPropSpawnedEffect( vehicle )

	vehicle:Spawn()
	vehicle:Activate()

	if ( VTable && VTable.Health ) then
		vehicle:SetHealth( VTable.Health )
		vehicle:SetMaxHealth( VTable.Health )
	end

	-- Some vehicles reset this in Spawn()
	if ( data && data.ColGroup ) then vehicle:SetCollisionGroup( data.ColGroup ) end

	-- Store spawnmenu data for addons and stuff
	if ( vehicle.SetVehicleClass && VName ) then vehicle:SetVehicleClass( VName ) end
	vehicle.VehicleName = VName

	-- We need to override the class in the case of the Jeep, because it
	-- actually uses a different class than is reported by GetClass
	vehicle.ClassOverride = className

	if ( IsValid( ply ) ) then
		gamemode.Call( "PlayerSpawnedVehicle", ply, vehicle )
	end

	return vehicle

end

local VehicleClassList = {
	"prop_vehicle_jeep_old", "prop_vehicle_jeep", "prop_vehicle_apc",
	"prop_vehicle_airboat", "prop_vehicle_prisoner_pod"
}
for _, v in ipairs( VehicleClassList ) do
	duplicator.RegisterEntityClass( v, MakeVehicle, "Pos", "Ang", "Model", "Class", "VehicleName", "Data" )
end

--[[---------------------------------------------------------
	Name: Spawn_Vehicle
	Desc: Player attempts to spawn vehicle
-----------------------------------------------------------]]
function Spawn_Vehicle( ply, vname, tr )

	-- We don't support this command from dedicated server console
	if ( !IsValid( ply ) ) then return end

	-- Player is dead, don't allow them to spam stuff
	if ( not ply:Alive() and not ply:IsAdmin() ) then ReportErrorToPlayer( ply, "dead" ) return end

	if ( !vname ) then ReportErrorToPlayer( ply, "bad_vehicle" ) return end

	-- Is it a valid vehicle to be spawning..
	local vehicle = list.GetEntry( "Vehicles", vname )
	if ( !vehicle ) then ReportErrorToPlayer( ply, "bad_vehicle" ) return end

	if ( !tr ) then tr = GetSpawnTrace( ply ) end

	local Angles = ply:GetAngles()
	Angles.pitch = 0
	Angles.roll = 0
	Angles.yaw = Angles.yaw + 180

	local pos = tr.HitPos
	if ( vehicle.Offset ) then
		pos = pos + tr.HitNormal * vehicle.Offset
	end

	local Ent = MakeVehicle( ply, pos, Angles, vehicle.Model, vehicle.Class, vname )
	if ( !IsValid( Ent ) ) then ReportErrorToPlayer( ply, "no_entity" ) return end

	-- Unstable for Jeeps
	-- TryFixPropPosition( ply, Ent, tr.HitPos )

	if ( vehicle.Members ) then
		table.Merge( Ent, vehicle.Members )
	end

	undo.Create( "Vehicle" )
		undo.SetPlayer( ply )
		undo.AddEntity( Ent )
		undo.SetCustomUndoText( "Undone " .. vehicle.Name )
	undo.Finish( "#undo.generic.vehicle (" .. tostring( vehicle.Name ) .. ")" )

	ply:AddCleanup( "vehicles", Ent )

	return Ent

end
concommand.Add( "gm_spawnvehicle", function( ply, cmd, args ) Spawn_Vehicle( ply, args[1] ) end, nil, "Spawn sandbox vehicles." )
