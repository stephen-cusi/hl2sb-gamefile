--========== HL2SB - GMod compat ==========--
--
-- Purpose: Team library (ported from Garry's Mod's team module).
--
--   HL2SB runs on the HL2MP rule set, so the teams the engine actually knows
--   are TEAM_UNASSIGNED / TEAM_SPECTATOR / TEAM_COMBINE / TEAM_REBELS.  This
--   module keeps GMod's shape (SetUp / GetName / GetColor / GetPlayers /
--   NumPlayers / Score helpers) and pre-seeds it with the HL2MP teams so a
--   ported scoreboard shows something sensible before any gamemode calls
--   team.SetUp.
--
--   Two GMod dependencies are handled defensively because HL2SB has no
--   score bindings yet:
--     ply:Deaths() / ply:Frags()  -> 0 when the binding is missing
--
--===========================================================================--

module( "team", package.seeall )

local TeamInfo = {}
local DefaultColor = Color( 255, 255, 100, 255 )

-- HL2SB 的 Color 是 userdata，分量是**方法**不是字段（见 AGENTS.md 5.4）。
local function Parts( c )
	if ( c == nil ) then return 255, 255, 255, 255 end

	if ( type( c.r ) == "function" ) then
		return c.r, c.g, c.b, c.a
	end

	return c.r or 255, c.g or 255, c.b or 255, c.a or 255
end

local function Seed( id, name, color, joinable )
	TeamInfo[ id ] = {
		Name     = name,
		Color    = color or DefaultColor,
		Score    = 0,
		Joinable = joinable ~= false,
	}
end

-- 引擎已知的队伍（HL2MP）
Seed( TEAM_CONNECTING or 0, "Joining/Connecting", DefaultColor, false )
Seed( TEAM_UNASSIGNED or 0, "Unassigned",         DefaultColor, false )
Seed( TEAM_SPECTATOR  or 1, "Spectator",          DefaultColor, true )
Seed( 2, "Combine", Color( 60, 90, 200, 255 ), true )
Seed( 3, "Rebels",  Color( 200, 90, 60, 255 ), true )

-------------------------------------------------------------------------------
-- Purpose: Registers / overwrites a team (a shared file should call this)
-------------------------------------------------------------------------------
function SetUp( id, name, color, joinable )
	Seed( id, name, color, joinable )
end

function GetAllTeams()
	return TeamInfo
end

function Valid( id )
	return TeamInfo[ id ] ~= nil
end

function Joinable( id )
	if ( TeamInfo[ id ] == nil ) then return false end
	return TeamInfo[ id ].Joinable
end

function GetName( id )
	if ( TeamInfo[ id ] == nil ) then return "" end
	return TeamInfo[ id ].Name
end

function GetColor( id )
	local c = TeamInfo[ id ] and TeamInfo[ id ].Color or DefaultColor
	local r, g, b, a = Parts( c )
	return Color( r, g, b, a )
end

function SetColor( id, color )
	if ( TeamInfo[ id ] == nil ) then return false end

	TeamInfo[ id ].Color = color
	return color
end

-------------------------------------------------------------------------------
-- Purpose: Spawn point bookkeeping (GMod keeps these on the team)
-------------------------------------------------------------------------------
function SetSpawnPoint( id, ent_name )
	if ( TeamInfo[ id ] == nil ) then return end
	if ( not istable( ent_name ) ) then ent_name = { ent_name } end

	TeamInfo[ id ].SpawnPointTable = ent_name
	TeamInfo[ id ].SpawnPoints     = nil
end

function GetSpawnPoint( id )
	if ( TeamInfo[ id ] == nil ) then return nil end
	return TeamInfo[ id ].SpawnPointTable
end

function GetSpawnPoints( id )
	if ( TeamInfo[ id ] == nil ) then return nil end

	local names = TeamInfo[ id ].SpawnPointTable
	if ( names == nil ) then return nil end

	local out = {}
	for _, entname in ipairs( names ) do
		if ( _G.ents ~= nil and ents.FindByClass ~= nil ) then
			local found = ents.FindByClass( entname )
			for _, e in ipairs( found ) do
				out[ #out + 1 ] = e
			end
		end
	end

	TeamInfo[ id ].SpawnPoints = out
	return out
end

function SetClass( id, classtable )
	if ( TeamInfo[ id ] == nil ) then return end
	if ( not istable( classtable ) ) then classtable = { classtable } end

	TeamInfo[ id ].SelectableClasses = classtable
end

function GetClass( id )
	if ( TeamInfo[ id ] == nil ) then return nil end
	return TeamInfo[ id ].SelectableClasses
end

-------------------------------------------------------------------------------
-- Purpose: Score / roster helpers
-------------------------------------------------------------------------------
local function ForEachPlayer( fn )
	if ( _G.player == nil or player.GetAll == nil ) then return end

	for _, ply in ipairs( player.GetAll() ) do
		fn( ply )
	end
end

-- ply:Team() 是 gmod_compat.lua 给 CBasePlayer 加的别名（= GetTeamNumber）。
local function PlyTeam( ply )
	if ( ply.Team ~= nil ) then return ply:Team() end
	if ( ply.GetTeamNumber ~= nil ) then return ply:GetTeamNumber() end
	return -1
end

function NumPlayers( id )
	local n = 0
	ForEachPlayer( function( ply )
		if ( PlyTeam( ply ) == id ) then n = n + 1 end
	end )
	return n
end

function GetPlayers( id )
	local out = {}
	ForEachPlayer( function( ply )
		if ( PlyTeam( ply ) == id ) then out[ #out + 1 ] = ply end
	end )
	return out
end

function TotalFrags( id )
	local n = 0
	ForEachPlayer( function( ply )
		if ( PlyTeam( ply ) == id and ply.Frags ~= nil ) then n = n + ( ply:Frags() or 0 ) end
	end )
	return n
end

function TotalDeaths( id )
	local n = 0
	ForEachPlayer( function( ply )
		if ( PlyTeam( ply ) == id and ply.Deaths ~= nil ) then n = n + ( ply:Deaths() or 0 ) end
	end )
	return n
end

function GetScore( id )
	return GetGlobalInt( "Team." .. tostring( id ) .. ".Score", 0 )
end

function SetScore( id, score )
	return SetGlobalInt( "Team." .. tostring( id ) .. ".Score", score )
end

function AddScore( id, score )
	SetScore( id, GetScore( id ) + score )
end

-------------------------------------------------------------------------------
-- Purpose: The joinable team with the fewest players
-------------------------------------------------------------------------------
function BestAutoJoinTeam()
	local smallest, count = TEAM_UNASSIGNED or 0, 1000

	for id, tm in pairs( TeamInfo ) do
		if ( id ~= ( TEAM_SPECTATOR or 1 ) and id ~= ( TEAM_UNASSIGNED or 0 ) and tm.Joinable ) then
			local n = NumPlayers( id )
			if ( n < count or ( n == count and id < smallest ) ) then
				count    = n
				smallest = id
			end
		end
	end

	return smallest
end
