--[[---------------------------------------------------------------------------
    HL2SB undo module (server + client).

    This is Garry's Mod's own lua/includes/modules/undo.lua, ported with the
    smallest possible diff.  HL2SB's Lua keeps GLua's lexer extensions (`!`,
    `!=`, `&&`, `||`, `continue`), so GMod's source is usable nearly verbatim --
    the edits below are only the things HL2SB genuinely does not have.

    Differences from GMod's file, all marked with "HL2SB:" comments:
      * CLIENT / SERVER   -> _CLIENT / _GAME
      * saverestore.*     -> omitted; HL2SB has no saverestore module yet, and
                             GMod only needs it for singleplayer saves.
      * controlpanel.Get / spawnmenu.AddToolMenuOption / Panel:ListBox
                          -> the spawnmenu control panel does not exist yet, so
                             the client UI block is gated behind a presence
                             check.  The net receivers, GetTable/MakeUIDirty and
                             the OnUndo hook (the parts scripts actually use)
                             are unconditional.
      * language.GetPhrase -> optional; the "#name (secondary)" prettifier is
                             skipped when the language module is absent.

    Force conditions (GMod semantics, unchanged):
      hook.Run("CanCreateUndo", owner, undo)
      hook.Run("PreUndo", undo)            -- false cancels Do_Undo
      hook.Run("PostUndo", undo, count)
      hook.Run("CanUndo", ply, undo)
      hook.Run("OnUndo", name, customtext) -- client side, from Undo_FireUndo

    Console commands (GMod's own names):
      undo / gmod_undo     -> undo the player's most recent action
      gmod_undonum <n>     -> undo a specific entry (used by the control panel)

    Loaded every level from lua/includes/modules/.
-----------------------------------------------------------------------------]]

-- HL2SB: GMod loads its modules in a fixed order and its undo.lua carries no
-- requires.  luasrc_dofolder() walks lua/includes/modules/ in directory order,
-- so pull in what the module body touches at load time and what its functions
-- rely on.  (`net` is a C library, already a global; no require for it.)
require( "hook" )
require( "concommand" )
require( "table" )
require( "timer" )

module( "undo", package.seeall )

-- undo.Create("Wheel")
-- undo.AddEntity( axis )
-- undo.AddEntity( constraint )
-- undo.SetPlayer( self.Owner )
-- undo.Finish()

if ( _CLIENT ) then

	local ClientUndos = {}
	local bIsDirty = true

	--[[---------------------------------------------------------
		GetTable
		Returns the undo table for whatever reason
	-----------------------------------------------------------]]
	function GetTable()
		return ClientUndos
	end

	--[[---------------------------------------------------------
		UpdateUI
		Actually updates the UI. Removes old controls and
		re-creates them using the new data.
	-----------------------------------------------------------]]
	local function UpdateUI()

		-- HL2SB: no spawnmenu control panel yet -> nothing to update.
		if ( _G.controlpanel == nil ) then return end

		local Panel = controlpanel.Get( "Undo" )
		if ( !IsValid( Panel ) ) then return end

		local ComboBox = Panel.UndoListPanel
		if ( !IsValid( ComboBox ) ) then
			Panel:Clear()
			Panel:Help( "#spawnmenu.utilities.undo.help" )

			ComboBox = Panel:ListBox()
			ComboBox:SetTall( 500 )
			Panel.UndoListPanel = ComboBox
		else
			ComboBox:Clear()
		end

		local Limit = 100
		local Count = 0
		for k, v in ipairs( ClientUndos ) do

			local Item = ComboBox:AddItem( tostring( v.Name ) )
			Item.DoClick = function() RunConsoleCommand( "gmod_undonum", tostring( v.Key ) ) end

			Count = Count + 1
			if ( Count > Limit ) then break end

		end

	end

	--[[---------------------------------------------------------
		AddUndo
		Called from server. Adds a new undo to our UI
	-----------------------------------------------------------]]
	net.Receive( "Undo_AddUndo", function()

		local key = net.ReadInt( 16 )
		local name = net.ReadString()

		-- HACK: To support localization of "#prop_physics (models/path.mdl)"
		if ( string.sub( name, 1, 1 ) == "#" and string.find( name, " (", nil, true ) ) then
			local undoName, undoSecondary = string.match( name, "^(#.*) %((.*)%)$" )
			if ( undoName and undoSecondary ) then
				-- HL2SB: language.GetPhrase only if the module exists.
				if ( _G.language ~= nil and language.GetPhrase ~= nil ) then
					name = string.format( "%s (%s)", language.GetPhrase( undoName ), language.GetPhrase( undoSecondary ) )
				else
					name = undoName .. " (" .. undoSecondary .. ")"
				end
			end
		end

		table.insert( ClientUndos, 1, { Key = key, Name = name } )

		MakeUIDirty()

	end )

	-- Called from server, fires GM:OnUndo
	net.Receive( "Undo_FireUndo", function()

		local name = net.ReadString()
		local hasCustomText = net.ReadBool()
		local customtext
		if ( hasCustomText ) then
			customtext = net.ReadString()
		end

		hook.Run( "OnUndo", name, customtext )

	end )


	--[[---------------------------------------------------------
		Undone
		Called from server. Notifies us that one of our undos
		has been undone or made redundant. We act by updating
		out data (We wait until the UI is viewed until updating)
	-----------------------------------------------------------]]
	net.Receive( "Undo_Undone", function()

		local key = net.ReadInt( 16 )

		local NewUndo = {}
		local i = 1
		for k, v in ipairs( ClientUndos ) do

			if ( v.Key != key ) then
				NewUndo [ i ] = v
				i = i + 1
			end

		end

		ClientUndos = NewUndo
		NewUndo = nil

		MakeUIDirty()

	end )

	--[[---------------------------------------------------------
		MakeUIDirty
		Makes the UI dirty - it will re-create the controls
		the next time it is viewed.
	-----------------------------------------------------------]]
	function MakeUIDirty()

		bIsDirty = true

	end

	--[[---------------------------------------------------------
		CPanelPaint
		Called when the inner panel of the undo CPanel is painted
		We hook onto this to determine when the panel is viewed.
		When it's viewed we update the UI if it's marked as dirty
	-----------------------------------------------------------]]
	local function CPanelUpdate( panel )

		-- This is kind of a shitty way of doing it - but we only want
		-- to update the UI when it's visible.
		if ( bIsDirty ) then

			-- Doing this in a timer so it calls it in a sensible place
			-- Calling in the paint function could cause all kinds of problems
			-- It's a hack but hey welcome to GMod!
			timer.Simple( 0, UpdateUI )
			bIsDirty = false

		end

	end

	--[[---------------------------------------------------------
		SetupUI
		Adds a hook (CPanelPaint) to the control panel paint
		function so we can determine when it is being drawn.
	-----------------------------------------------------------]]
	function SetupUI()

		-- HL2SB: no spawnmenu control panel yet.
		if ( _G.controlpanel == nil ) then return end

		local UndoPanel = controlpanel.Get( "Undo" )
		if ( !IsValid( UndoPanel ) ) then return end

		-- Mark as dirty please
		MakeUIDirty()

		-- Panels only think when they're visible
		UndoPanel.Think = CPanelUpdate

	end

	if ( _G.spawnmenu ~= nil and spawnmenu.AddToolMenuOption ~= nil ) then
		hook.Add( "PopulateToolMenu", "Undo_RegisterToolMenu", function()

			spawnmenu.AddToolMenuOption( "Utilities", "User", "Undo", "#spawnmenu.utilities.undo", "", "", function( pnl )
				SetupUI()
			end )

		end )
	end

end


if ( !_GAME ) then return end

local PlayerUndo = {}
-- PlayerUndo
--	- Player UniqueID
--		- Undo Table
--			- Name
--			- Entities (table of ents)
--			- Owner (player)

local Current_Undo = nil

util.AddNetworkString( "Undo_Undone" )
util.AddNetworkString( "Undo_AddUndo" )
util.AddNetworkString( "Undo_FireUndo" )

--[[---------------------------------------------------------
	GetTable
	Returns the undo table for whatever reason
-----------------------------------------------------------]]
function GetTable()
	return PlayerUndo
end

--[[---------------------------------------------------------
	Save/Restore the undo tables
	HL2SB: omitted - there is no saverestore module yet, and this only matters
	for singleplayer saves (GMod: saverestore.AddSaveHook("UndoTable", ...)).
-----------------------------------------------------------]]

--[[---------------------------------------------------------
	Start a new undo
-----------------------------------------------------------]]
function Create( text )

	Current_Undo = {}
	Current_Undo.Name			= text
	Current_Undo.Entities		= {}
	Current_Undo.Owner			= nil
	Current_Undo.Functions		= {}

end

--[[---------------------------------------------------------
	Adds a custom undo text
-----------------------------------------------------------]]
function SetCustomUndoText( CustomUndoText )

	if ( !Current_Undo ) then return end

	Current_Undo.CustomUndoText = CustomUndoText

end

--[[---------------------------------------------------------
	Adds an entity to this undo (The entity is removed on undo)
-----------------------------------------------------------]]
function AddEntity( ent )

	if ( !Current_Undo ) then return end
	if ( !IsValid( ent ) ) then return end

	table.insert( Current_Undo.Entities, ent )

end

--[[---------------------------------------------------------
	Add a function to call to this undo
-----------------------------------------------------------]]
function AddFunction( func, ... )

	if ( !Current_Undo ) then return end
	if ( !func ) then return end

	table.insert( Current_Undo.Functions, { func, {...} } )

end

--[[---------------------------------------------------------
	Replace Entity
-----------------------------------------------------------]]
function ReplaceEntity( from, to )

	local ActionTaken = false

	for _, PlayerTable in pairs( PlayerUndo ) do
		for _, UndoTable in pairs( PlayerTable ) do
			if ( UndoTable.Entities ) then

				for key, ent in pairs( UndoTable.Entities ) do
					if ( ent == from ) then
						UndoTable.Entities[ key ] = to
						ActionTaken = true
					end
				end

			end
		end
	end

	return ActionTaken

end


--[[---------------------------------------------------------
	Sets who's undo this is
-----------------------------------------------------------]]
function SetPlayer( ply )

	if ( !Current_Undo ) then return end
	if ( !IsValid( ply ) ) then return end

	Current_Undo.Owner = ply

end

--[[---------------------------------------------------------
	Sends a message to notify the client that one of their
	undos has been removed. They can then update their GUI.
-----------------------------------------------------------]]
local function SendUndoneMessage( ent, id, ply )

	if ( !IsValid( ply ) ) then return end

	-- For further optimization we could queue up the ids and send them
	-- in one batch every 0.5 seconds or something along those lines.

	net.Start( "Undo_Undone" )
		net.WriteInt( id, 16 )
	net.Send( ply )

end

--[[---------------------------------------------------------
	Checks whether an undo is allowed to be created
-----------------------------------------------------------]]
local function Can_CreateUndo( undo )

	local call = hook.Run( "CanCreateUndo", undo.Owner, undo )

	return call == true or call == nil

end

--[[---------------------------------------------------------
	Finish
-----------------------------------------------------------]]
function Finish( NiceText )

	if ( !Current_Undo ) then return end

	-- Do not add undos that have no owner or anything to undo
	if ( !IsValid( Current_Undo.Owner ) or ( table.IsEmpty( Current_Undo.Entities ) && table.IsEmpty( Current_Undo.Functions ) ) or !Can_CreateUndo( Current_Undo ) ) then
		Current_Undo = nil
		return false
	end

	local index = Current_Undo.Owner:UniqueID()
	PlayerUndo[ index ] = PlayerUndo[ index ] or {}

	Current_Undo.NiceText = NiceText or ( "#" .. Current_Undo.Name )

	local id = table.insert( PlayerUndo[ index ], Current_Undo )

	net.Start( "Undo_AddUndo" )
		net.WriteInt( id, 16 )
		net.WriteString( Current_Undo.NiceText )
	net.Send( Current_Undo.Owner )

	-- Have one of the entities in the undo tell us when it gets undone.
	if ( IsValid( Current_Undo.Entities[ 1 ] ) ) then

		local ent = Current_Undo.Entities[ 1 ]
		ent:CallOnRemove( "undo" .. id, SendUndoneMessage, id, Current_Undo.Owner )

	end

	Current_Undo = nil

	return true

end

--[[---------------------------------------------------------
	Cleanup the list of invalid undos, primarily for disconnected players
-----------------------------------------------------------]]
local function CleanupInvalidUndos()
	for uniqId, playerUndos in pairs( PlayerUndo ) do
		local invalidUndos = 0
		local allUndos = 0

		for undoIndex, undoData in pairs( playerUndos ) do
			allUndos = allUndos + 1

			-- If the undo has functions, we cannot discard it
			if ( undoData.Functions and next( undoData.Functions ) ) then
				continue
			end

			local allInvalid = true
			for entIdx, ent in pairs( undoData.Entities or {} ) do
				if ( IsValid( ent ) ) then
					allInvalid = false
				else
					undoData.Entities[ entIdx ] = nil
				end
			end

			-- If there are still valid entities, can't remove it
			if ( not allInvalid ) then continue end

			-- Null out the invalid undo entry
			-- Undone: causes issues somehow
			--playerUndos[ undoIndex ] = nil
			invalidUndos = invalidUndos + 1

			-- CallOnRemove already handles this for players on the server
			--SendUndoneMessage( nil, undoIndex, undoData.Owner )
		end

		-- If the player has no undos left or they are all invalid, remove their entry
		if ( not next( playerUndos ) || invalidUndos == allUndos ) then PlayerUndo[ uniqId ] = nil end
	end
end

local numCleanups = 0
hook.Add( "EntityRemoved", "Undo_RemoveInvalidUndos", function( ent )

	-- Use a timer to guard against many entities being removed at once
	timer.Create( "Undo_QueuedRemoveInvalidUndos", 0, 1, function()
		numCleanups = numCleanups + 1

		-- Cleanup invalid undo entries only every once in a while
		-- The value is arbitrary, we just don't want to go through the entire table on every entity removal
		-- As the memory savings would not be worth the execution time
		if ( numCleanups >= 16 ) then
			numCleanups = 0
			CleanupInvalidUndos()
		end
	end )

end )

--[[---------------------------------------------------------
	HL2SB: is this entity currently carried by a player?

	The engine records an undo action for everything `ent_create` spawns
	(HL2SB_UndoRecord, game/server/hl2sb_undo.cpp), weapons from the admin menu
	included.  That record goes stale the moment somebody picks the weapon up:
	running the undo would delete it straight out of that player's hands.
	Anything a player carries is therefore left alone -- weapons sitting in the
	inventory too, because CBaseCombatWeapon::Equip() sets the owner as well.
-----------------------------------------------------------]]
local function IsCarriedByPlayer( ent )

	local owner = nil

	if ( ent.GetOwnerEntity ) then owner = ent:GetOwnerEntity() end
	if ( !IsValid( owner ) and ent.GetOwner ) then owner = ent:GetOwner() end

	if ( IsValid( owner ) and owner.GetClass and owner:GetClass() == "player" ) then
		return true
	end

	return false

end

--[[---------------------------------------------------------
	Undos an undo
-----------------------------------------------------------]]
function Do_Undo( undo )

	if ( !undo ) then return false end

	if ( hook.Run( "PreUndo", undo ) == false ) then return end

	local count = 0

	-- Call each function
	if ( undo.Functions ) then
		for index, func in pairs( undo.Functions ) do

			local success = func[ 1 ]( undo, unpack( func[ 2 ] ) )
			if ( success != false ) then
				count = count + 1
			end

		end
	end

	-- Remove each entity in this undo
	if ( undo.Entities ) then
		for index, entity in pairs( undo.Entities ) do

			if ( IsValid( entity ) ) then

				-- HL2SB: leave anything a player is carrying alone.  An
				-- admin-spawned weapon gets an undo record when it is created,
				-- but once a player picks it up that record is stale and
				-- undoing it would rip the weapon out of their hands.
				if ( !IsCarriedByPlayer( entity ) ) then
					entity:Remove()
					count = count + 1
				end

			end

		end
	end

	if ( count > 0 ) then
		net.Start( "Undo_FireUndo" )
			net.WriteString( undo.Name )
			net.WriteBool( undo.CustomUndoText != nil )
			if ( undo.CustomUndoText != nil ) then
				net.WriteString( undo.CustomUndoText )
			end
		net.Send( undo.Owner )
	end

	hook.Run( "PostUndo", undo, count )

	return count

end

--[[---------------------------------------------------------
	Checks whether a player is allowed to undo
-----------------------------------------------------------]]
local function Can_Undo( ply, undo )

	local call = hook.Run( "CanUndo", ply, undo )

	return call == true or call == nil

end

local function CC_UndoLast( pl, command, args )

	local index = pl:UniqueID()
	PlayerUndo[ index ] = PlayerUndo[ index ] or {}

	local last = nil
	local lastk = nil

	for k, v in pairs( PlayerUndo[ index ] ) do

		lastk = k
		last = v

	end

	-- No undos
	if ( !last ) then return end

	-- This is quite messy, but if the player rejoined the server
	-- 'Owner' might no longer be a valid entity. So replace the Owner
	-- with the player that is doing the undoing
	last.Owner = pl

	if ( !Can_Undo( pl, last ) ) then return end

	local count = Do_Undo( last )

	net.Start( "Undo_Undone" )
		net.WriteInt( lastk, 16 )
	net.Send( pl )

	PlayerUndo[ index ][ lastk ] = nil

	-- If our last undo object is already deleted then compact
	-- the undos until we hit one that does something
	if ( count == 0 ) then
		CC_UndoLast( pl )
	end

end

local function CC_UndoNum( ply, command, args )

	if ( !args[ 1 ] ) then return end

	local index = ply:UniqueID()
	PlayerUndo[ index ] = PlayerUndo[ index ] or {}

	local UndoNum = tonumber( args[ 1 ] )
	if ( !UndoNum ) then return end

	local TheUndo = PlayerUndo[ index ][ UndoNum ]
	if ( !TheUndo ) then return end

	-- Do the same as above
	TheUndo.Owner = ply

	if ( !Can_Undo( ply, TheUndo ) ) then return end

	-- Undo!
	Do_Undo( TheUndo )

	-- Notify the client UI that the undo happened
	-- This is normally called by the deleted entity via SendUndoneMessage
	-- But in cases where the undo only has functions that will not do
	net.Start( "Undo_Undone" )
		net.WriteInt( UndoNum, 16 )
	net.Send( ply )

	-- Don't delete the entry completely so nothing new takes its place and ruin CC_UndoLast's logic (expecting newest entry be at highest index)
	PlayerUndo[ index ][ UndoNum ] = {}

end

concommand.Add( "undo",			CC_UndoLast, nil, "", { FCVAR_DONTRECORD } )
concommand.Add( "gmod_undo",	CC_UndoLast, nil, "", { FCVAR_DONTRECORD } )
concommand.Add( "gmod_undonum",	CC_UndoNum, nil, "", { FCVAR_DONTRECORD } )

print( "[HL2SB] undo module loaded (GMod lua/includes/modules/undo.lua)" )
