--[[--------------------------------------------------------------------------
    gamemodes/deathmatch/gamemode/player_class/player_deathmatch.lua

    HL2MP 死斗的玩家类。装备从旧的 GM:GiveDefaultItems 搬到这里，
    走 GMod 的 GM:PlayerSpawn -> PlayerLoadout -> RunClass("Loadout")。

    近战武器按玩家模型类型给（HL2MP 原版规则）：
      Metropolice / Combine Soldier -> 电棍
      Citizen                       -> 撬棍
--------------------------------------------------------------------------]]--

local PLAYER = {}

PLAYER.DISPLAYNAME = "HL2: Deathmatch"
PLAYER.DisplayName = "HL2: Deathmatch"

-------------------------------------------------------------------------------
function PLAYER:Loadout()
	self.Player:EquipSuit()

	self.Player:GiveAmmo( 255, "Pistol",   true )
	self.Player:GiveAmmo( 45,  "SMG1",     true )
	self.Player:GiveAmmo( 1,   "grenade",  true )
	self.Player:GiveAmmo( 6,   "Buckshot", true )
	self.Player:GiveAmmo( 6,   "357",      true )

	local modelType = nil
	if ( self.Player.GetPlayerModelType ~= nil ) then
		modelType = self.Player:GetPlayerModelType()
	end

	if ( modelType == 2 or modelType == 1 ) then          -- METROPOLICE / COMBINESOLDIER
		self.Player:Give( "weapon_stunstick" )
	elseif ( modelType == 0 ) then                        -- CITIZEN
		self.Player:Give( "weapon_crowbar" )
	else
		self.Player:Give( "weapon_crowbar" )
	end

	self.Player:Give( "weapon_pistol" )
	self.Player:Give( "weapon_smg1" )
	self.Player:Give( "weapon_frag" )
	self.Player:Give( "weapon_physcannon" )

	self.Player:SwitchToDefaultWeapon()
end

function PLAYER:Spawn()
end

function PLAYER:SetModel()
	local cl_playermodel = self.Player:GetInfo( "cl_playermodel" )
	local modelname      = player_manager.TranslatePlayerModel( cl_playermodel )

	util.PrecacheModel( modelname )
	self.Player:SetModel( modelname )
end

player_manager.RegisterClass( "player_deathmatch", PLAYER, "player_default" )
