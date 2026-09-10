--========== HL2SB - GMod compat ==========--
--
-- Purpose: Player class system (ported from Garry's Mod's player_manager).
--
--   This is the linchpin of GMod's gamemode layer: GM:PlayerSpawn calls
--   player_manager.OnPlayerSpawn / RunClass("Spawn"), then PlayerLoadout calls
--   RunClass("Loadout") and the class table's PLAYER:Loadout() decides the
--   spawn kit.
--
--   Ported shape (same names as GMod):
--     Models : AddValidModel / RemoveValidModel / AllValidModels /
--              GetAllPlayerModels / TranslatePlayerModel /
--              TranslateToPlayerModelName / AddValidHands / TranslatePlayerHands
--     Classes: RegisterClass / GetPlayerClasses / PlayerClassExists /
--              SetPlayerClass / GetPlayerClass / RunClass / GetStored /
--              OnPlayerSpawn / ClearPlayerClass / PlayerClass
--
--   HL2SB differences:
--     - The class name lives on the player entity itself (HL2SB entities have a
--       __newindex that stores arbitrary Lua fields), so no C++ change is
--       needed and it survives as long as the entity does.
--     - Model translation defers to the hl2sb library (the mod's own player
--       model menu) and only falls back to the local table.
--
--===========================================================================--

module( "player_manager", package.seeall )

local ModelList    = {}
local ModelNameDict = {}
local HandNames    = {}
local PlayerClasses = {}

-------------------------------------------------------------------------------
-- Purpose: Registers a selectable player model
-------------------------------------------------------------------------------
function AddValidModel( name, model, title, category )
	if ( type( name ) ~= "string" ) then return end
	if ( type( model ) ~= "string" ) then return end

	ModelList[ name ] = {
		model    = model,
		title    = title or name,
		category = category or "Other",
	}

	ModelNameDict[ string.lower( model ) ] = name
end

function RemoveValidModel( name )
	local entry = ModelList[ name ]
	if ( entry == nil ) then return end

	ModelNameDict[ string.lower( entry.model ) ] = nil
	ModelList[ name ] = nil
end

function AllValidModels()
	local out = {}
	for name, data in pairs( ModelList ) do
		out[ name ] = data.model
	end
	return out
end

function GetAllPlayerModels()
	return table.Copy( ModelList )
end

function AddValidHands( name, model, skin, body, matchBodySkin )
	HandNames[ name ] = {
		model         = model,
		skin          = skin or 0,
		body          = body or "0000000",
		matchBodySkin = matchBodySkin or false,
	}
end

function TranslatePlayerHands( model )
	return HandNames[ model ]
end

-------------------------------------------------------------------------------
-- Purpose: Turns a model *path* back into the registered name
-------------------------------------------------------------------------------
function TranslateToPlayerModelName( model )
	if ( type( model ) ~= "string" ) then return nil end

	local name = ModelNameDict[ string.lower( model ) ]
	if ( name ~= nil ) then return name end

	-- hl2sb 的玩家模型系统也维护了一份列表，认不出来就问它。
	if ( _G.hl2sb ~= nil and hl2sb.FindPlayerModel ~= nil ) then
		local ok, found = pcall( hl2sb.FindPlayerModel, model )
		if ( ok and found ~= nil and found ~= "" ) then return found end
	end

	return nil
end

-------------------------------------------------------------------------------
-- Purpose: Model path for a player-model name (cl_playermodel value)
-------------------------------------------------------------------------------
function TranslatePlayerModel( name )
	if ( type( name ) ~= "string" ) then return "models/player/kleiner.mdl" end

	local entry = ModelList[ name ]
	if ( entry ~= nil ) then return entry.model end

	-- The value may already be a path.
	if ( string.find( name, "models/", 1, true ) == 1 ) then return name end

	return "models/player/kleiner.mdl"
end

-------------------------------------------------------------------------------
-- Purpose: Registers a player class. `base` chains to another class.
-------------------------------------------------------------------------------
function RegisterClass( name, tab, base )
	if ( type( name ) ~= "string" or not istable( tab ) ) then return end

	if ( base ~= nil and PlayerClasses[ base ] ~= nil ) then
		tab = table.Inherit and table.Inherit( tab, PlayerClasses[ base ] )
			or table.inherit( tab, PlayerClasses[ base ] )
	end

	PlayerClasses[ name ] = tab
end

function GetPlayerClassTable( name )
	return PlayerClasses[ name ]
end

function GetPlayerClasses()
	return PlayerClasses
end

function PlayerClassExists( class )
	return class ~= nil and PlayerClasses[ class ] ~= nil
end

-------------------------------------------------------------------------------
-- Purpose: Binds a class to a player  (GMod: ply:SetPlayerClass)
-------------------------------------------------------------------------------
function SetPlayerClass( ply, class )
	if ( not IsValid( ply ) ) then return end

	if ( not PlayerClassExists( class ) ) then
		-- Unknown class: leave the player unclassed rather than half-classed.
		ply.PlayerClassName = nil
		return
	end

	ply.PlayerClassName = class
end

function GetPlayerClass( ply )
	if ( not IsValid( ply ) ) then return nil end
	return ply.PlayerClassName
end

-------------------------------------------------------------------------------
-- Purpose: `PlayerClass()` returns the class table of the *current* class
-------------------------------------------------------------------------------
function GetStored( ply )
	return ply
end

-------------------------------------------------------------------------------
-- Purpose: Calls a method on a player's class table.
--          Returns false when the class (or the method) is missing, which is
--          what GMod's callers branch on.
-------------------------------------------------------------------------------
function RunClass( ply, func, ... )
	if ( not IsValid( ply ) ) then return false end

	local class = GetPlayerClass( ply )
	if ( class == nil ) then return false end

	if ( type( func ) == "table" ) then
		local f = func[ 1 ]
		local args = { ... }
		func = function( self ) return self[ f ]( self, unpack( args ) ) end
	end

	local tab = PlayerClasses[ class ]
	if ( tab == nil ) then return false end

	local fn = tab[ func ]
	if ( fn == nil ) then return false end

	-- GMod 在调用前把当前玩家挂到类表上：PLAYER:Loadout() 里用的 self.Player
	-- 就是它。少了这一行，所有 PLAYER:* 方法里的 self.Player 都是 nil。
	tab.Player = ply

	return fn( tab, ply, ... )
end

-------------------------------------------------------------------------------
-- Purpose: Class-less entry point (GMod exposes both)
-------------------------------------------------------------------------------
function RunClassHook( ply, func, ... )
	return RunClass( ply, func, ... )
end

-------------------------------------------------------------------------------
-- Purpose: Called from GM:PlayerSpawn
-------------------------------------------------------------------------------
function OnPlayerSpawn( ply, transition )
	if ( not IsValid( ply ) ) then return end

	-- Default class when the gamemode never assigned one.
	if ( GetPlayerClass( ply ) == nil and PlayerClassExists( "player_default" ) ) then
		SetPlayerClass( ply, "player_default" )
	end

	-- 和 GMod 一样：类方法里 self.Player 必须指向这个玩家。
	local tab = PlayerClasses[ GetPlayerClass( ply ) ]
	if ( tab ~= nil ) then
		tab.Player = ply

		if ( type( tab.Init ) == "function" ) then
			tab:Init()
		end
	end
end

function ClearPlayerClass( ply )
	if ( not IsValid( ply ) ) then return end
	ply.PlayerClassName = nil
end

-------------------------------------------------------------------------------
-- Purpose: Convenience alias so a gamemode can do PlayerClass( ply ).Loadout
-------------------------------------------------------------------------------
function PlayerClass( ply )
	local class = GetPlayerClass( ply )
	if ( class == nil ) then return nil end
	return PlayerClasses[ class ]
end

-------------------------------------------------------------------------------
-- Purpose: HL2SB 便利函数 —— 直接用玩家选中的模型建类表
-------------------------------------------------------------------------------
function GetPlayerModel( ply )
	if ( not IsValid( ply ) ) then return "" end

	local info = ply.GetInfo and ply:GetInfo( "cl_playermodel" ) or nil
	if ( info ~= nil and info ~= "" ) then return info end

	if ( _G.hl2sb ~= nil and hl2sb.GetCurrentPlayerModel ~= nil ) then
		local ok, model = pcall( hl2sb.GetCurrentPlayerModel, ply )
		if ( ok and model ~= nil ) then return model end
	end

	return ply:GetModelName() or ""
end
