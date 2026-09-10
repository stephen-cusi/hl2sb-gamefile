--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/player_class/player_default.lua

    对应 GMod 的 base/gamemode/player_class/player_default.lua。

    PLAYER 表是这个体系里的“类实例”，引擎侧不会碰它：
    只有 player_manager.RunClass 会调它的方法。字段名保持 GMod 原样，
    这样从 GMod 搬过来的 gamemode / 玩家类可以照抄。

    GMod -> HL2SB 的替身：
      AddCSLuaFile()          -> 空操作（HL2SB 的 Lua 本来就在两端）
      self.Player:Give(x)     -> GiveNamedItem（gmod_compat 里加了 Give 别名）
      include("taunt_camera") -> 没移植，略过
--------------------------------------------------------------------------]]--

include( "taunt_camera.lua" )

local PLAYER = {}

PLAYER.DisplayName        = "Default Class"

PLAYER.SlowWalkSpeed      = 200   -- +WALK 时的速度
PLAYER.WalkSpeed          = 400
PLAYER.RunSpeed           = 600
PLAYER.CrouchedWalkSpeed  = 0.3
PLAYER.DuckSpeed          = 0.3
PLAYER.UnDuckSpeed        = 0.3
PLAYER.JumpPower          = 200
PLAYER.CanUseFlashlight   = true
PLAYER.MaxHealth          = 100
PLAYER.MaxArmor           = 100
PLAYER.StartHealth        = 100
PLAYER.StartArmor         = 0
PLAYER.DropWeaponOnDie    = false
PLAYER.TeammateNoCollide  = true
PLAYER.AvoidPlayers       = true
PLAYER.UseVMHands         = true

-------------------------------------------------------------------------------
-- 生命周期
-------------------------------------------------------------------------------
function PLAYER:SetupDataTables()
end

function PLAYER:Init()
end

function PLAYER:Spawn()
end

-------------------------------------------------------------------------------
-- 出生装备 —— 子类覆盖这个方法
-------------------------------------------------------------------------------
function PLAYER:Loadout()
	self.Player:Give( "weapon_pistol" )
	self.Player:GiveAmmo( 255, "Pistol", true )
end

-------------------------------------------------------------------------------
-- 模型
-------------------------------------------------------------------------------
function PLAYER:SetModel()
	local cl_playermodel = self.Player:GetInfo( "cl_playermodel" )
	local modelname      = player_manager.TranslatePlayerModel( cl_playermodel )

	util.PrecacheModel( modelname )
	self.Player:SetModel( modelname )
end

function PLAYER:Death( inflictor, attacker )
end

-------------------------------------------------------------------------------
-- 仅客户端
-------------------------------------------------------------------------------
function PLAYER:CalcView( view ) end
function PLAYER:CreateMove( cmd ) end
function PLAYER:ShouldDrawLocal() end
function PLAYER:PreDrawViewModel( vm, weapon ) end
function PLAYER:PostDrawViewModel( vm, weapon ) end

-------------------------------------------------------------------------------
-- 共享移动钩子
-------------------------------------------------------------------------------
function PLAYER:StartMove( cmd, mv ) end
function PLAYER:Move( mv ) end
function PLAYER:FinishMove( mv ) end

function PLAYER:ViewModelChanged( vm, old, new )
end

-------------------------------------------------------------------------------
-- 手部模型
-------------------------------------------------------------------------------
function PLAYER:GetHandsModel()
	local playermodel = player_manager.TranslateToPlayerModelName( self.Player:GetModel() )
	return player_manager.TranslatePlayerHands( playermodel )
end

player_manager.RegisterClass( "player_default", PLAYER, nil )
