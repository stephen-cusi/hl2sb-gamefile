--[[--------------------------------------------------------------------------
    gamemodes/sandbox/gamemode/player_class/player_sandbox.lua

    对应 GMod 的 gamemodes/sandbox/gamemode/player_class/player_sandbox.lua。

    开局装备从旧的 GM:GiveDefaultItems 搬到了这里的 PLAYER:Loadout()，
    和 GMod 一致：GM:PlayerSpawn -> PlayerLoadout -> RunClass("Loadout")。

    GMod 原版的 gmod_tool / gmod_camera 在 HL2SB 没有可用实现：
      gmod_tool   -> weapon_toolgun（HL2SB 自带的 C++ 工具枪）
      gmod_camera -> 略过（只有半个 shared.lua，没有 init.lua，也缺 camera.mdl）
--------------------------------------------------------------------------]]--

local PLAYER = {}

PLAYER.DuckSpeed     = 0.1
PLAYER.UnDuckSpeed   = 0.1

PLAYER.TauntCam      = TauntCamera()

PLAYER.SlowWalkSpeed = 100
PLAYER.WalkSpeed     = 200
PLAYER.RunSpeed      = 400

-------------------------------------------------------------------------------
function PLAYER:SetupDataTables()
end

-------------------------------------------------------------------------------
-- Purpose: 出生装备（GMod 沙盒预设）
-------------------------------------------------------------------------------
function PLAYER:Loadout()
	-- 不 StripWeapons：GMod 也注释掉了，说会破坏现有 mod
	self.Player:RemoveAllAmmo()

	if ( cvars.Bool( "sbox_weapons", true ) ) then
		self.Player:GiveAmmo( 256, "Pistol",     true )
		self.Player:GiveAmmo( 256, "SMG1",       true )
		self.Player:GiveAmmo( 5,   "grenade",    true )
		self.Player:GiveAmmo( 64,  "Buckshot",   true )
		self.Player:GiveAmmo( 32,  "357",        true )
		self.Player:GiveAmmo( 32,  "XBowBolt",   true )
		self.Player:GiveAmmo( 6,   "AR2AltFire", true )
		self.Player:GiveAmmo( 100, "AR2",        true )

		self.Player:Give( "weapon_crowbar" )
		self.Player:Give( "weapon_pistol" )
		self.Player:Give( "weapon_smg1" )
		self.Player:Give( "weapon_frag" )
		self.Player:Give( "weapon_physcannon" )
		self.Player:Give( "weapon_crossbow" )
		self.Player:Give( "weapon_shotgun" )
		self.Player:Give( "weapon_357" )
		self.Player:Give( "weapon_rpg" )
		self.Player:Give( "weapon_ar2" )
	end

	-- 工具（GMod 里这两个不受 sbox_weapons 影响）
	self.Player:Give( "weapon_physgun" )
	self.Player:Give( "weapon_toolgun" )

	self.Player:SwitchToDefaultWeapon()
end

-------------------------------------------------------------------------------
function PLAYER:SetModel()
	local cl_playermodel = self.Player:GetInfo( "cl_playermodel" )
	local modelname      = player_manager.TranslatePlayerModel( cl_playermodel )

	util.PrecacheModel( modelname )
	self.Player:SetModel( modelname )
end

-------------------------------------------------------------------------------
function PLAYER:Spawn()
end

function PLAYER:ShouldDrawLocal()
	if ( self.TauntCam ~= nil ) then
		return self.TauntCam:ShouldDrawLocalPlayer( self.Player, false )
	end
end

function PLAYER:CreateMove( cmd )
	if ( self.TauntCam ~= nil ) then
		return self.TauntCam:CreateMove( cmd, self.Player, false )
	end
end

function PLAYER:CalcView( view )
	if ( self.TauntCam ~= nil ) then
		return self.TauntCam:CalcView( view, self.Player, false )
	end
end

-------------------------------------------------------------------------------
-- Purpose: HL2 单机的跳跃加成（GMod 沙盒原样保留）
-------------------------------------------------------------------------------
local JUMPING

function PLAYER:StartMove( move )
	if ( bit == nil ) then return end

	if ( bit.band( move:GetButtons(), 2 ) ~= 0 and bit.band( move:GetOldButtons(), 2 ) == 0 and self.Player:OnGround() ) then
		JUMPING = true
	end
end

function PLAYER:FinishMove( move )
	if ( not JUMPING ) then return end

	JUMPING = nil
	-- HL2SB 没有 move:SetVelocity 的绑定，跳跃加成留待引擎侧补齐。
end

player_manager.RegisterClass( "player_sandbox", PLAYER, "player_default" )
