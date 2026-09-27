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

-- ===========================================================================
-- HL2SB: mirror every registration into the ENGINE's model table.
--
-- A Garry's Mod playermodel addon (custom/miku, custom/hutao_old, ...) ships no
-- cfg/playermodel/<name>.cfg; it only calls player_manager.AddValidModel /
-- AddValidHands from a lua/autorun file.  The engine table is what the
-- playermodel menu lists (hl2sb.GetPlayerModels), what hl2sb.SetPlayerModel()
-- accepts, what the server precaches and what c_baseviewmodel's c_hands lookup
-- uses -- so without this call the addon's model exists in this Lua table and
-- nowhere else: it cannot be selected, and it is never precached.
--
-- hl2sb.AddPlayerModel( name, model, hands ) updates an entry in place, which is
-- why AddValidModel (model) and the AddValidHands right after it (hands) can be
-- two separate calls.  The hands argument uses the cfg encoding
-- "path|skin|bodygroups" (hl2sb_model_config.cpp parses it).
-- ===========================================================================
local function EngineAddModel( name, model, hands )
	if ( _G.hl2sb == nil or hl2sb.AddPlayerModel == nil ) then return end

	local ok, err = pcall( hl2sb.AddPlayerModel, name, model, hands )
	if ( not ok ) then
		Msg( "[HL2SB] hl2sb.AddPlayerModel( " .. tostring( name ) .. " ) failed: "
		     .. tostring( err ) .. "\n" )
	end
end

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

	-- HL2SB (2026-09-27): GMod parity - AddValidModel lands in the list registry
	-- too ("PlayerOptionsModel").  Older GMod playermodel addons register with
	-- list.Set( "PlayerOptionsModel", ... ) DIRECTLY (that is GMod's actual
	-- storage - its editor reads list.Get, not a private table), so GetAllPlayerModels
	-- below merges that list back in; without these two bridges one style or the
	-- other was invisible in the player model menu.
	if ( list ~= nil and list.Set ~= nil ) then
		list.Set( "PlayerOptionsModel", name, ModelList[ name ] )
	end

	-- HL2SB: engine side (menu / precache / SetPlayerModel) - hands are a
	-- separate AddValidHands call, so pass "keep" (nil) for them.
	EngineAddModel( name, model, nil )
end

function RemoveValidModel( name )
	local entry = ModelList[ name ]
	if ( entry == nil ) then return end

	ModelNameDict[ string.lower( entry.model ) ] = nil
	ModelList[ name ] = nil

	if ( list ~= nil and list.RemoveEntry ~= nil ) then
		list.RemoveEntry( "PlayerOptionsModel", name )
	end
end

function AllValidModels()
	local out = {}
	for name, data in pairs( ModelList ) do
		out[ name ] = data.model
	end
	return out
end

function GetAllPlayerModels()
	local out = table.Copy( ModelList )

	-- HL2SB (2026-09-27): merge entries registered GMod-style via
	-- list.Set( "PlayerOptionsModel", name, path|table ).  The value can be a
	-- plain model path string (GMod's old wiki form) or a table with model/title/
	-- category.  Entries this module already knows keep their richer shape.
	if ( list ~= nil and list.Get ~= nil ) then
		local ok, listed = pcall( list.Get, "PlayerOptionsModel" )

		if ( ok and type( listed ) == "table" ) then
			for lname, lvalue in pairs( listed ) do
				if ( out[ lname ] == nil ) then
					if ( type( lvalue ) == "table" and type( lvalue.model ) == "string" ) then
						out[ lname ] = table.Copy( lvalue )
					elseif ( type( lvalue ) == "string" ) then
						out[ lname ] = { model = lvalue, title = lname, category = "Other" }
					end
				end
			end
		end
	end

	return out
end

function AddValidHands( name, model, skin, body, matchBodySkin )
	HandNames[ name ] = {
		model         = model,
		skin          = skin or 0,
		body          = body or "0000000",
		matchBodySkin = matchBodySkin or false,
	}

	-- HL2SB: engine side.  c_baseviewmodel reads the hands model through
	-- HL2SB_GetHandsModelForPlayer( <player model path> ) and applies the
	-- skin/body encoded after a '|' (the same encoding cfg/playermodel uses:
	-- "models/weapons/c_arms_citizen.mdl|2|0000000").  nil = keep the model, so
	-- this only ever adds hands to an entry AddValidModel already created.
	if ( type( model ) == "string" and model ~= "" ) then
		EngineAddModel( name, nil, model .. "|" .. tostring( skin or 0 ) .. "|" .. tostring( body or "0000000" ) )
	end
end

-- ===========================================================================
-- HL2SB (2026-09-27): GMod's default HL2/CSS/Portal/DOD cast (the bottom half
-- of its player_manager.lua) -- the HANDS half only.  The fork's playermodel
-- menu is engine-scan driven, so GMod's ModelList/AddValidModel registration
-- is deliberately NOT ported here; what the hands pipeline needs is the
-- path->name dict for TranslateToPlayerModelName and these HandNames entries
-- for TranslatePlayerHands.  GMod's own AddPlayerModel( name, title, model,
-- handsModel, ... ) calls both halves; entries registered this way keep the
-- same names GMod uses.
-- ===========================================================================
local HandsCitizen = "models/weapons/c_arms_citizen.mdl"
local HandsRefugee = "models/weapons/c_arms_refugee.mdl"
local HandsCombine = "models/weapons/c_arms_combine.mdl"
local HandsCSS     = "models/weapons/c_arms_cstrike.mdl"
local HandsChell   = "models/weapons/c_arms_chell.mdl"
local HandsDOD     = "models/weapons/c_arms_dod.mdl"

local DefaultHandsModels = {
	-- Main cast
	{ "alyx",           "models/player/alyx.mdl",                          HandsCitizen, 0, "0000000" },
	{ "breen",          "models/player/breen.mdl",                         HandsCitizen, 0, "0000000" },
	{ "eli",            "models/player/eli.mdl",                           HandsCitizen, 1, "0000000" },
	{ "gman",           "models/player/gman_high.mdl",                     HandsCitizen, 0, "0000000" },
	{ "kleiner",        "models/player/kleiner.mdl",                       HandsCitizen, 0, "0000000" },
	{ "monk",           "models/player/monk.mdl",                          HandsCitizen, 0, "0000000" },
	{ "odessa",         "models/player/odessa.mdl",                        HandsCitizen, 0, "0000000" },
	{ "barney",         "models/player/barney.mdl",                        HandsCombine, 0, "0000000" },
	{ "magnusson",      "models/player/magnusson.mdl",                     HandsCitizen, 0, "0000000" },
	{ "mossman",        "models/player/mossman.mdl",                       HandsCitizen, 0, "0000000" },
	{ "mossmanarctic",  "models/player/mossman_arctic.mdl",                HandsCitizen, 0, "0100000" },

	-- Baddies
	{ "combine",        "models/player/combine_soldier.mdl",               HandsCombine, 0, "0000000" },
	{ "combineprison",  "models/player/combine_soldier_prisonguard.mdl",   HandsCombine, 0, "0000000" },
	{ "combineelite",   "models/player/combine_super_soldier.mdl",         HandsCombine, 0, "0000000" },
	{ "police",         "models/player/police.mdl",                        HandsCombine, 0, "0000000" },
	{ "policefem",      "models/player/police_fem.mdl",                    HandsCombine, 0, "0000000" },
	{ "stripped",       "models/player/soldier_stripped.mdl",              HandsCitizen, 0, "0000000" },

	-- Zombies
	{ "charple",        "models/player/charple.mdl",                       HandsCitizen, 2, "0000000" },
	{ "corpse",         "models/player/corpse1.mdl",                       HandsCitizen, 2, "0000000" },
	{ "skeleton",       "models/player/skeleton.mdl",                      HandsCitizen, 2, "0000000" },
	{ "zombie",         "models/player/zombie_classic.mdl",                HandsCitizen, 2, "0000000" },
	{ "zombiefast",     "models/player/zombie_fast.mdl",                   HandsCitizen, 2, "0000000" },
	{ "zombine",        "models/player/zombie_soldier.mdl",                HandsCombine, 0, "0000000" },

	-- Citizens
	{ "female01",       "models/player/Group01/female_01.mdl",             HandsCitizen, 0, "0000000" },
	{ "female02",       "models/player/Group01/female_02.mdl",             HandsCitizen, 0, "0000000" },
	{ "female03",       "models/player/Group01/female_03.mdl",             HandsCitizen, 1, "0000000" },
	{ "female04",       "models/player/Group01/female_04.mdl",             HandsCitizen, 0, "0000000" },
	{ "female05",       "models/player/Group01/female_05.mdl",             HandsCitizen, 1, "0000000" },
	{ "female06",       "models/player/Group01/female_06.mdl",             HandsCitizen, 0, "0000000" },
	{ "female07",       "models/player/Group03/female_01.mdl",             HandsRefugee, 0, "0100000" },
	{ "female08",       "models/player/Group03/female_02.mdl",             HandsRefugee, 0, "0100000" },
	{ "female09",       "models/player/Group03/female_03.mdl",             HandsRefugee, 1, "0100000" },
	{ "female10",       "models/player/Group03/female_04.mdl",             HandsRefugee, 0, "0100000" },
	{ "female11",       "models/player/Group03/female_05.mdl",             HandsRefugee, 1, "0100000" },
	{ "female12",       "models/player/Group03/female_06.mdl",             HandsRefugee, 0, "0100000" },
	{ "male01",         "models/player/Group01/male_01.mdl",               HandsCitizen, 1, "0000000" },
	{ "male02",         "models/player/Group01/male_02.mdl",               HandsCitizen, 0, "0000000" },
	{ "male03",         "models/player/Group01/male_03.mdl",               HandsCitizen, 1, "0000000" },
	{ "male04",         "models/player/Group01/male_04.mdl",               HandsCitizen, 0, "0000000" },
	{ "male05",         "models/player/Group01/male_05.mdl",               HandsCitizen, 0, "0000000" },
	{ "male06",         "models/player/Group01/male_06.mdl",               HandsCitizen, 0, "0000000" },
	{ "male07",         "models/player/Group01/male_07.mdl",               HandsCitizen, 0, "0000000" },
	{ "male08",         "models/player/Group01/male_08.mdl",               HandsCitizen, 0, "0000000" },
	{ "male09",         "models/player/Group01/male_09.mdl",               HandsCitizen, 0, "0000000" },
	{ "male10",         "models/player/Group03/male_01.mdl",               HandsRefugee, 1, "0100000" },
	{ "male11",         "models/player/Group03/male_02.mdl",               HandsRefugee, 0, "0000000" },
	{ "male12",         "models/player/Group03/male_03.mdl",               HandsRefugee, 1, "0100000" },
	{ "male13",         "models/player/Group03/male_04.mdl",               HandsRefugee, 0, "0100000" },
	{ "male14",         "models/player/Group03/male_05.mdl",               HandsRefugee, 0, "0100000" },
	{ "male15",         "models/player/Group03/male_06.mdl",               HandsRefugee, 0, "0100000" },
	{ "male16",         "models/player/Group03/male_07.mdl",               HandsRefugee, 0, "0100000" },
	{ "male17",         "models/player/Group03/male_08.mdl",               HandsRefugee, 0, "0000000" },
	{ "male18",         "models/player/Group03/male_09.mdl",               HandsRefugee, 0, "0100000" },
	{ "medic01",        "models/player/Group03m/male_01.mdl",              HandsRefugee, 1, "0100000" },
	{ "medic02",        "models/player/Group03m/male_02.mdl",              HandsRefugee, 0, "0000000" },
	{ "medic03",        "models/player/Group03m/male_03.mdl",              HandsRefugee, 1, "0100000" },
	{ "medic04",        "models/player/Group03m/male_04.mdl",              HandsRefugee, 0, "0000000" },
	{ "medic05",        "models/player/Group03m/male_05.mdl",              HandsRefugee, 0, "0100000" },
	{ "medic06",        "models/player/Group03m/male_06.mdl",              HandsRefugee, 0, "0000000" },
	{ "medic07",        "models/player/Group03m/male_07.mdl",              HandsRefugee, 0, "0000000" },
	{ "medic08",        "models/player/Group03m/male_08.mdl",              HandsRefugee, 0, "0000000" },
	{ "medic09",        "models/player/Group03m/male_09.mdl",              HandsRefugee, 0, "0000000" },
	{ "medic10",        "models/player/Group03m/female_01.mdl",            HandsRefugee, 0, "0100000" },
	{ "medic11",        "models/player/Group03m/female_02.mdl",            HandsRefugee, 0, "0000000" },
	{ "medic12",        "models/player/Group03m/female_03.mdl",            HandsRefugee, 1, "0000000" },
	{ "medic13",        "models/player/Group03m/female_04.mdl",            HandsRefugee, 0, "0100000" },
	{ "medic14",        "models/player/Group03m/female_05.mdl",            HandsRefugee, 0, "0100000" },
	{ "medic15",        "models/player/Group03m/female_06.mdl",            HandsRefugee, 1, "0100000" },
	{ "refugee01",      "models/player/Group02/male_02.mdl",               HandsCitizen, 0, "0000000" },
	{ "refugee02",      "models/player/Group02/male_04.mdl",               HandsCitizen, 0, "0000000" },
	{ "refugee03",      "models/player/Group02/male_06.mdl",               HandsCitizen, 0, "0000000" },
	{ "refugee04",      "models/player/Group02/male_08.mdl",               HandsCitizen, 0, "0000000" },

	-- Counter-Strike
	{ "css_arctic",     "models/player/arctic.mdl",                        HandsCSS, 0, "0000000" },
	{ "css_gasmask",    "models/player/gasmask.mdl",                       HandsCSS, 0, "0000000" },
	{ "css_guerilla",   "models/player/guerilla.mdl",                      HandsCSS, 0, "0000000" },
	{ "css_leet",       "models/player/leet.mdl",                          HandsCSS, 0, "0000000" },
	{ "css_phoenix",    "models/player/phoenix.mdl",                       HandsCSS, 0, "0000000" },
	{ "css_riot",       "models/player/riot.mdl",                          HandsCSS, 0, "0000000" },
	{ "css_swat",       "models/player/swat.mdl",                          HandsCSS, 0, "0000000" },
	{ "css_urban",      "models/player/urban.mdl",                         HandsCSS, 0, "0000000" },

	-- Portal / Day of Defeat: Source
	{ "chell",          "models/player/p2_chell.mdl",                      HandsChell, 0, "0000000" },
	{ "dod_german",     "models/player/dod_german.mdl",                    HandsDOD, 0, "0000000" },
	{ "dod_american",   "models/player/dod_american.mdl",                  HandsDOD, 1, "0000000" },
}

for _, castEntry in ipairs( DefaultHandsModels ) do
	local castName, castModel = castEntry[ 1 ], castEntry[ 2 ]
	if ( ModelNameDict[ string.lower( castModel ) ] == nil ) then
		ModelNameDict[ string.lower( castModel ) ] = castName
	end
	AddValidHands( castName, castEntry[ 3 ], castEntry[ 4 ], castEntry[ 5 ] )
end

function TranslatePlayerHands( name )

	if ( HandNames[ name ] != nil ) then
		return HandNames[ name ]
	end

	-- GMod's default (its player_manager.lua): citizen arms, empty bodygroups.
	return { model = "models/weapons/c_arms_citizen.mdl", skin = 0, body = "100000000" }

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

	-- HL2SB (2026-09-25): GMod's RunClass calls class方法 WITHOUT the player
	-- argument - self is the class table and the player rides on tab.Player.
	-- Passing ply here shifted every argument: PLAYER:StartMove(move) received
	-- the PLAYER ENTITY as `move`, so move:GetButtons() died the first time
	-- this fork actually dispatched GM:SetupMove (player_sandbox.lua:116).
	return fn( tab, ... )
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

-------------------------------------------------------------------------------
-- Purpose: GMod 的 AddPlayerModel —— 一次注册「模型 + 手模」
--
--   GMod 的 lua/includes/modules/player_manager.lua 里它是 **file-local** 的
--   （它自己就是拿这个函数铺出那张默认模型表的），wiki 上也没有它。之所以导出，
--   是因为 HL2SB 这边没有 GMod 那份内置模型表，gamemode / addon 要按 GMod 的写法
--   补条目时只能靠它。0 个调用者，纯新增。
--
--   ⚠️ 参数顺序是 GMod 的，和本模块的 AddValidModel **不一样**：
--       AddPlayerModel( name, title, model, handsModel, handsSkin, handsBody )
--       AddValidModel ( name, model, title, category )
--   （GMod 把 title 放在 model 前面。）
-------------------------------------------------------------------------------
function AddPlayerModel( name, title, model, handsModel, handsSkin, handsBody, category )
	if ( type( name ) ~= "string" or type( model ) ~= "string" ) then return end

	AddValidModel( name, model, title, category )

	if ( handsModel ~= nil ) then
		AddValidHands( name, handsModel, handsSkin, handsBody )
	end
end

-------------------------------------------------------------------------------
-- Purpose: GMod 的 LookupPlayerClass（同样在 GMod 里是 file-local）
--
--   GMod 返回的是「玩家职业实例」——存在 ply.m_CurrentPlayerClass 上，元表 __index
--   指向职业表，并带 Player / ClassID / Func 三个字段。
--   HL2SB 的职业系统不同：职业表直接放在 PlayerClasses 里，PlayerClass( ply ) 返回
--   那张表（OnPlayerSpawn 会把 tab.Player 指向该玩家）。这里就做成它的别名，
--   于是 class:Init() / class.Loadout / class.Player 这些 GMod 写法都能用。
-------------------------------------------------------------------------------
function LookupPlayerClass( ply )
	return PlayerClass( ply )
end
