--[[--------------------------------------------------------------------------
    lua/includes/modules/achievements.lua

    Local (nosteam) implementation of GMod's achievements library.  The wiki
    surface is reproduced exactly: Count, GetCount, GetDesc, GetGoal, GetName,
    IsAchieved plus the ten internal trackers (BalloonPopped, EatBall,
    IncBaddies, IncBystander, IncGoodies, Remover, SpawnedNPC, SpawnedProp,
    SpawnedRagdoll, SpawnMenuOpen).

    There is no Steam stats backend here, so progress lives in
    data/hl2sb_achievements.txt as "<id> <count>" lines, one per achievement,
    and an achievement counts as obtained once its count reaches the goal the
    wiki's achievements list documents (1 for the one-shot entries, the stated
    number for the counter entries).

    IDs are positional (1..N) in the order of that list: the reference does not
    expose its numeric ids, so nothing can depend on a foreign numbering and
    this keeps them stable for saved data.
--------------------------------------------------------------------------]]--

module( "achievements", package.seeall )

local SAVE_FILE = "hl2sb_achievements.txt"

-- id, internal name, wiki display name, wiki description, goal
local LIST = {
	{ "play_multiplayer",	"Play Multiplayer",		"Play multiplayer at least once",			1 },
	{ "play_around",		"Play Around",			"Play a gamemode that isn't sandbox",		1 },
	{ "play_singleplayer",	"Play Singleplayer",	"Play singleplayer at least once",			1 },
	{ "bad_coder",			"Bad Coder",			"Experience 500 Lua programming errors",	500 },
	{ "map_loader",			"Map Loader",			"Play 20 different maps",					20 },
	{ "one_day",			"One Day",				"24 hours of your life wasted",				1 },
	{ "procreator",			"Procreator",			"Spawn 1000 NPCs",							1000 },
	{ "half_marathon",		"Half Marathon",		"Play on the same server & map for 4 hours",1 },
	{ "ball_eater",			"Ball Eater",			"Eat 200 balls",							200 },
	{ "war_zone",			"War Zone",				"Killed 1000 Baddies",						1000 },
	{ "marathon",			"Marathon",				"Play on the same server & map for 8 hours",1 },
	{ "one_week",			"One Week",				"One whole week of your life wasted",		1 },
	{ "bad_friend",			"Bad Friend",			"Kill 1000 friendly NPCs",					1000 },
	{ "secret_phrase",		"Secret Phrase",		"Say the secret phrase",					1 },
	{ "innocent_bystander",	"Innocent Bystander",	"Kill 1000 innocent animals",				1000 },
	{ "creator",			"Creator",				"Spawn 5000 props",							5000 },
	{ "one_month",			"One Month",			"One whole month of your life wasted",		1 },
	{ "popper",				"Popper",				"Burst 1000 balloons",						1000 },
	{ "startup_millenium",	"Startup Millenium",	"Start Garry's Mod 1000 times",				1000 },
	{ "dollhouse",			"Dollhouse",			"Spawn 2000 ragdolls",						2000 },
	{ "menu_user",			"Menu User",			"Open the spawnmenu 100,000 times",			100000 },
	{ "destroyer",			"Destroyer",			"Remove 5000 things",						5000 },
	{ "friendly",			"Friendly",				"Play with 10 friends",						1 },
	{ "real_garry",			"Yes, I am the real garry!", "Play on the same server as garry",		1 },
	{ "thumbs_10",			"10 Thumbs",			"Your Workshop uploads got 10 thumbs",		1 },
	{ "addict",				"Addict",				"You have wasted a year of your life playing GMod!", 1 },
	{ "thumbs_100",			"100 Thumbs",			"Your Workshop uploads got 100 thumbs",		1 },
	{ "thumbs_1000",		"1000 Thumbs",			"Your Workshop uploads got 1000 thumbs",	1 },
}

-- counters by id; 0 means "not started"
local counts = {}
local bLoaded = false

local function Load()
	if ( bLoaded ) then return end
	bLoaded = true

	local raw = file.Read( SAVE_FILE, "DATA" )
	if ( !raw ) then return end

	for line in string.gmatch( raw, "[^\r\n]+" ) do
		local id, n = string.match( line, "^(%d+)%s+(%d+)$" )
		if ( id ) then
			counts[ tonumber( id ) ] = tonumber( n )
		end
	end
end

local function Save()
	local out = {}
	for id = 1, #LIST do
		out[ #out + 1 ] = string.format( "%d %d", id, counts[ id ] or 0 )
	end
	file.Write( SAVE_FILE, table.concat( out, "\n" ) .. "\n" )
end

local function IsValidID( id )
	return isnumber( id ) and id >= 1 and id <= #LIST
end

-- Adds progress and reports whether the achievement crossed its goal.
local function Add( id, n )
	Load()
	if ( !IsValidID( id ) ) then return false end
	n = n or 1
	local old = counts[ id ] or 0
	local wasAchieved = old >= LIST[ id ][ 4 ]
	counts[ id ] = old + n
	Save()
	local nowAchieved = counts[ id ] >= LIST[ id ][ 4 ]
	return ( nowAchieved and !wasAchieved )
end

function Count()
	return #LIST
end

function GetName( achievementID )
	if ( !IsValidID( achievementID ) ) then return "" end
	return LIST[ achievementID ][ 2 ]
end

function GetDesc( achievementID )
	if ( !IsValidID( achievementID ) ) then return "" end
	return LIST[ achievementID ][ 3 ]
end

function GetGoal( achievementID )
	if ( !IsValidID( achievementID ) ) then return 1 end
	return LIST[ achievementID ][ 4 ]
end

function GetCount( achievementID )
	Load()
	if ( !IsValidID( achievementID ) ) then return 0 end
	return counts[ achievementID ] or 0
end

function IsAchieved( achievementID )
	return GetCount( achievementID ) >= GetGoal( achievementID )
end

-- Internal trackers, one per wiki entry that has a counter.
function BalloonPopped() return Add( 18 ) end
function EatBall() return Add( 9 ) end
function IncBaddies() return Add( 10 ) end
function IncBystander() return Add( 15 ) end
function IncGoodies() return Add( 13 ) end
function Remover() return Add( 22 ) end
function SpawnedNPC() return Add( 7 ) end
function SpawnedProp() return Add( 16 ) end
function SpawnedRagdoll() return Add( 20 ) end
function SpawnMenuOpen() return Add( 21 ) end

