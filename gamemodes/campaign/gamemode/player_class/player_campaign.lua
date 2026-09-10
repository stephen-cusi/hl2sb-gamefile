--[[--------------------------------------------------------------------------
    gamemodes/campaign/gamemode/player_class/player_campaign.lua

    战役（HL2 单机流程）的玩家类。

    关键差异：**不发光任何武器** —— HL2 的关卡靠地图里摆的 weapon_* 实体和
    player_spawn_items 给装备，出生就塞一整套会破坏关卡设计。
    和旧的 GM:GiveDefaultItems 空实现是同一个意图，只是搬到了 GMod 的类体系里。
--------------------------------------------------------------------------]]--

local PLAYER = {}

PLAYER.DisplayName = "Campaign"

-------------------------------------------------------------------------------
function PLAYER:Loadout()
	-- 故意空着：战役的装备来自地图实体
end

function PLAYER:Spawn()
end

function PLAYER:SetModel()
	local cl_playermodel = self.Player:GetInfo( "cl_playermodel" )
	local modelname      = player_manager.TranslatePlayerModel( cl_playermodel )

	util.PrecacheModel( modelname )
	self.Player:SetModel( modelname )
end

player_manager.RegisterClass( "player_campaign", PLAYER, "player_default" )
