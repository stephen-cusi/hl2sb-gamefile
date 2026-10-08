
local meta = FindMetaTable( "Player" )
local entity = FindMetaTable( "Entity" )

-- Return if there's nothing to add on to
if ( !meta ) then return end

-- HL2SB: capture the engine's own C++ __index (CBasePlayer___index) BEFORE the
-- override below replaces it, and chain to it first.  It reads the engine
-- fields AND the per-entity Lua field table - the same table the C++ __newindex
-- writes.  Without this chain, a custom field written to a player
-- (cod_c4's Owner.C4s, any addon's ply.Whatever) could never be read back:
-- the GetTable() fallback at the bottom only answers it when GetTable() really
-- is GetRefTable, and with the old GetClassname alias that call returned a
-- STRING whose metatable lookup answered nil for every key.
local EngineIndex = meta.__index

--
-- Entity index accessor. This used to be done in engine, but it's done in Lua now because it's faster
--
function meta:__index( key )

	--
	-- Search the metatable. We can do this without dipping into C, so we do it first.
	--
	local val = meta[key]
	if ( val ~= nil ) then return val end

	--
	-- Engine fields + the per-entity Lua field table (C++ CBasePlayer___index)
	--
	if ( EngineIndex ~= nil ) then
		local ok, engineVal = pcall( EngineIndex, self, key )
		if ( ok and engineVal ~= nil ) then return engineVal end
	end

	--
	-- Search the entity metatable
	--
	local entval = entity[key]
	if ( entval ~= nil ) then return entval end

	--
	-- Search the entity table.  Guarded: GetTable is an alias the compat layer
	-- installs, and if it is missing (or still aliased to a non-table source)
	-- indexing through it must stay silent rather than abort the lookup.
	--
	local getTable = entity.GetTable
	if ( getTable ~= nil ) then
		local ok, tab = pcall( getTable, self )
		if ( ok and istable( tab ) ) then
			return tab[ key ]
		end
	end

	return nil

end

if ( !sql.TableExists( "playerpdata" ) ) then

	sql.Query( "CREATE TABLE IF NOT EXISTS playerpdata ( infoid TEXT NOT NULL PRIMARY KEY, value TEXT );" )

end

--[[---------------------------------------------------------
	Name: DebugInfo
	Desc: Prints debug information for the player
		( this is just an example )
-----------------------------------------------------------]]
function meta:DebugInfo()

	Msg( "Name: " .. self:Name() .. "\n" )
	Msg( "Pos: " .. tostring( self:GetPos() ) .. "\n" )

end

-- Helpful aliases
meta.GetName = meta.Nick
meta.Name = meta.Nick

--[[---------------------------------------------------------
	Name: ConCommand
	Desc: Overrides the default ConCommand function
-----------------------------------------------------------]]
if ( CLIENT ) then

	local SendConCommand = meta.ConCommand
	local CommandList = nil

	function meta:ConCommand( command, bSkipQueue )

		if ( bSkipQueue or IsConCommandBlocked( command ) ) then
			SendConCommand( self, command )
		else
			CommandList = CommandList or {}
			table.insert( CommandList, command )
		end

	end

	local function SendQueuedConsoleCommands()

		if ( !CommandList ) then return end

		local BytesSent = 0

		for k, v in pairs( CommandList ) do

			SendConCommand( LocalPlayer(), v )
			CommandList[ k ] = nil

			-- Only send x bytes per tick
			BytesSent = BytesSent + v:len()
			if ( BytesSent > 128 ) then
				break
			end

		end

		-- Turn the table into a nil so we can return easy
		if ( table.IsEmpty( CommandList ) ) then

			CommandList = nil

		end

	end

	hook.Add( "Tick", "SendQueuedConsoleCommands", SendQueuedConsoleCommands )

end

--[[---------------------------------------------------------
	GetPData
	Saves persist data for this player
-----------------------------------------------------------]]
function meta:GetPData( name, default )

	-- First try looking up using the new key
	local key = Format( "%s[%s]", self:SteamID64(), name )
	local val = sql.QueryValue( "SELECT value FROM playerpdata WHERE infoid = " .. SQLStr( key ) .. " LIMIT 1" )
	if ( val == nil ) then

		-- Not found? Look using the old key
		local oldkey = Format( "%s[%s]", self:UniqueID(), name )
		val = sql.QueryValue( "SELECT value FROM playerpdata WHERE infoid = " .. SQLStr( oldkey ) .. " LIMIT 1" )
		if ( val == nil ) then return default end

	end

	return val

end

--[[---------------------------------------------------------
	SetPData
	Set persistant data
-----------------------------------------------------------]]
function meta:SetPData( name, value )

	-- Remove old value
	local oldkey = Format( "%s[%s]", self:UniqueID(), name )
	sql.Query( "DELETE FROM playerpdata WHERE infoid = " .. SQLStr( oldkey ) )

	local key = Format( "%s[%s]", self:SteamID64(), name )
	return sql.Query( "REPLACE INTO playerpdata ( infoid, value ) VALUES ( " .. SQLStr( key ) .. ", " .. SQLStr( value ) .. " )" ) ~= false

end

--[[---------------------------------------------------------
	RemovePData
	Remove persistant data
-----------------------------------------------------------]]
function meta:RemovePData( name )

	-- First old key
	local oldkey = Format( "%s[%s]", self:UniqueID(), name )
	local removed = sql.Query( "DELETE FROM playerpdata WHERE infoid = " .. SQLStr( oldkey ) ) ~= false

	-- Then new key
	local key = Format( "%s[%s]", self:SteamID64(), name )
	local removed2 = sql.Query( "DELETE FROM playerpdata WHERE infoid = " .. SQLStr( key ) ) ~= false

	return removed or removed2

end

--
-- If they have their preferred default weapon then switch to it
--
function meta:SwitchToDefaultWeapon()

	local weapon = self:GetInfo( "cl_defaultweapon" )

	if ( self:HasWeapon( weapon ) ) then
		self:SelectWeapon( weapon )
	end

end

--
-- Can use flashlight?
--
function meta:AllowFlashlight( bAble ) self.m_bFlashlight = bAble end
function meta:CanUseFlashlight() return self.m_bFlashlight == true end

-- A function to set up player hands, so coders don't have to copy all the code everytime.
-- Call this in PlayerSpawn hook.
-- HL2SB (2026-09-27): GetHands is the ENGINE binding now (the replicated
-- m_hHands handle, GMod's reference semantics) -- the old Lua shim used to
-- shadow it on this very metatable and answer the always-nil m_hHandsEntity
-- field forever.  The base spawn chain calls this after PlayerSetModel
-- (gamemodes/base/gamemode/init.lua, included live by deathmatch's init.lua).
function meta:SetupHands( spec_ply )

	local oldhands = self:GetHands()
	if ( IsValid( oldhands ) ) then
		oldhands:Remove()
	end

	local hands = ents.Create( "gmod_hands" )
	if ( IsValid( hands ) ) then
		-- This fork's ents.Create defers ENT:Initialize to :Spawn() (GMod
		-- initializes at create time), so Spawn runs first and DoSetup's
		-- AttachToViewmodel (SetMoveType MOVETYPE_NONE + EF_BONEMERGE onto the
		-- viewmodel) is the final word either way.
		hands:Spawn()
		hands:DoSetup( self, spec_ply )
	end

end

--
-- Those functions have been removed from the engine since AddFlag and RemoveFlag
-- made them obsolete, but we'll keep a Lua version of them for backward compatibility
--
if ( SERVER ) then

--[[---------------------------------------------------------
	Freeze
	Freezes or unfreezes the player
-----------------------------------------------------------]]
function meta:Freeze( b )

	if ( b ) then
		self:AddFlags( FL_FROZEN )
	else
		self:RemoveFlags( FL_FROZEN )
	end

end

--[[---------------------------------------------------------
	GodEnable
	Enables godmode on the player
-----------------------------------------------------------]]
function meta:GodEnable()

	self:AddFlags( FL_GODMODE )

end

--[[---------------------------------------------------------
	GodDisable
	Disables godmode on the player
-----------------------------------------------------------]]
function meta:GodDisable()

	self:RemoveFlags( FL_GODMODE )

end

end

--[[---------------------------------------------------------
	IsFrozen
	Returns true if the player is frozen
-----------------------------------------------------------]]
function meta:IsFrozen()

	return self:IsFlagSet( FL_FROZEN )

end

--[[---------------------------------------------------------
	HasGodMode
	Returns true if the player is in godmode
-----------------------------------------------------------]]
function meta:HasGodMode()

	return self:IsFlagSet( FL_GODMODE )

end

-- These are totally in the wrong place.
function player.GetByAccountID( ID )
	for _, pl in player.Iterator() do
		if ( pl:AccountID() == ID ) then
			return pl
		end
	end

	return false
end

function player.GetByUniqueID( ID )
	for _, pl in player.Iterator() do
		if ( pl:UniqueID() == ID ) then
			return pl
		end
	end

	return false
end

function player.GetBySteamID( ID )
	ID = string.upper( ID )

	for _, pl in player.Iterator() do
		if ( pl:SteamID() == ID ) then
			return pl
		end
	end

	return false
end

function player.GetBySteamID64( ID )
	for _, pl in player.Iterator() do
		if ( pl:SteamID64() == ID ) then
			return pl
		end
	end

	return false
end
------------------------------------------------------------------------------
-- HL2SB (2026-10-08): GMod-name conveniences the base gamemode calls.
--
--   StripWeapons    - GMod binding does not exist here; the engine spelling
--                     is RemoveAllItems( true ) (drop everything + hull).
--   Spectate        - alias of the engine's StartObserverMode binding.
--   UnSpectate      - alias of StopObserverMode.
--   Kill            - the engine only ships KillSilent; aliasing is a
--                     semantic shortcut (no suicide death notice) that keeps
--                     team-change paths from erroring.  Revisit when the
--                     death-notice chain gets its parity round.
------------------------------------------------------------------------------

if ( meta.StripWeapons == nil ) then
	function meta:StripWeapons()
		self:RemoveAllItems( true )
	end
end

if ( meta.Spectate == nil ) then
	meta.Spectate = meta.StartObserverMode
end

if ( meta.UnSpectate == nil ) then
	meta.UnSpectate = meta.StopObserverMode
end

if ( meta.Kill == nil ) then
	function meta:Kill()
		self:KillSilent()
	end
end
