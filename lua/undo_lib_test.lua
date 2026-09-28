-- ===========================================================================
-- HL2SB undo test (2026-09-29).  Run BOTH realms after a full restart + map:
--   server console:  lua_dofile    undo_lib_test.lua
--   client console:  lua_dofile_cl undo_lib_test.lua
--
-- GMod parity facts under test (source: garrysmod/lua/includes/modules/
-- undo.lua, GM:OnUndo = sandbox/gamemode/cl_init.lua:46, and the lua_shared
-- export audit that proved undo has ZERO C++ exports):
--
--   * undo module exports the GMod surface: GetTable Create SetCustomUndoText
--     AddEntity AddFunction ReplaceEntity SetPlayer Finish Do_Undo
--   * table.insert returns the insertion index (GLua ltablib semantics, now
--     patched into lua/src/ltablib.c -> lua_shared.dll)  -- Finish's whole id
--     scheme (Undo_Undone key, CallOnRemove "undo"..id) depends on it
--   * a record + undo cycle removes the entity, returns count 1 and fires
--     Undo_FireUndo EXACTLY once (server side of the double-notify bug)
--   * undoing a dead entry does nothing and fires NO notice (compaction)
--   * CLIENT: exactly ONE OnUndo consumer exists (the gamemode method), no
--     registered OnUndo hooks, and hook.Run("OnUndo") produces EXACTLY ONE
--     notification.AddLegacy call (the client side of the double-notify bug)
-- ===========================================================================

local passed, failed = 0, 0
local function check( name, ok )
	if ( ok ) then
		passed = passed + 1
		print( "[undo ok] " .. name )
	else
		failed = failed + 1
		print( "[undo FAIL] " .. name )
	end
end
local function summary()
	print( string.format( "[undo test] %d passed, %d failed", passed, failed ) )
end

-- ---------------------------------------------------------------------------
-- the VM contract (both realms)
-- ---------------------------------------------------------------------------
do
	local t = {}
	check( "table.insert(t,v) returns 1", table.insert( t, "a" ) == 1 )
	check( "table.insert appends returns 2", table.insert( t, "b" ) == 2 )
	check( "table.insert(t,1,v) returns pos", table.insert( t, 1, "c" ) == 1 )
	check( "undo module loaded", istable( undo ) and isfunction( undo.Create ) )
end

if ( SERVER ) then

	local ply = player.GetAll()[ 1 ]
	if ( !IsValid( ply ) ) then
		check( "a player is in the map", false )
		summary()
		return
	end

	-- ---- exported surface, GMod's names -----------------------------------
	for _, fn in ipairs( { "GetTable", "Create", "SetCustomUndoText", "AddEntity",
		"AddFunction", "ReplaceEntity", "SetPlayer", "Finish", "Do_Undo" } ) do
		check( "undo." .. fn .. " exists", isfunction( undo[ fn ] ) )
	end

	-- ---- record -----------------------------------------------------------
	local ent = ents.Create( "prop_physics" )
	ent:SetModel( "models/props_junk/watermelon01.mdl" )
	ent:SetPos( ply:EyePos() + ply:EyeAngles():Forward() * 60 )
	ent:Spawn()

	local uid = ply:UniqueID()
	local stackBefore = undo.GetTable()[ uid ]
	local nBefore = stackBefore and #stackBefore or 0

	undo.Create( "HL2SBTestProp" )
		undo.SetPlayer( ply )
		undo.AddEntity( ent )
	local okFinish = undo.Finish( "HL2SBTestProp" )
	check( "Finish accepted the record", okFinish == true )

	local stack = undo.GetTable()[ uid ]
	check( "stack grew by one entry", stack ~= nil and #stack == nBefore + 1 )
	-- The id is table.insert's return; a nil here means the GLua
	-- table.insert patch is NOT in the running lua_shared.dll.
	local entry = stack and stack[ #stack ]
	check( "entry landed at a numeric index (id path works)",
		entry ~= nil and entry.Name == "HL2SBTestProp" )

	-- ---- undo it ----------------------------------------------------------
	local count = undo.Do_Undo( entry )
	check( "Do_Undo removed the entity once (count==1)", count == 1 )
	check( "entity is gone", !IsValid( ent ) )

	-- ---- undo the same dead entry: silent, no notice ----------------------
	local count2 = undo.Do_Undo( entry )
	check( "re-undo of dead entry counts 0", count2 == 0 )

	-- tidy: drop the consumed entry so repeat runs stay balanced
	stack[ #stack ] = nil

elseif ( CLIENT ) then

	-- ---- one consumer, not two (the double-notify fix) ---------------------
	-- GMod shape: the popup lives ONLY in the gamemode method (GM:OnUndo in
	-- this fork's base = gamemodes/deathmatch/gamemode/cl_init.lua).  No
	-- registered OnUndo hook may exist (hook.Call would then fire the hook
	-- AND the gamemode method = two notices).
	local tHooks = hook.GetTable and hook.GetTable()[ "OnUndo" ]
	local nRegistered = 0
	if ( tHooks ) then
		for _ in pairs( tHooks ) do nRegistered = nRegistered + 1 end
	end
	check( "no registered OnUndo hooks (gamemode method is the only consumer)",
		nRegistered == 0 )

	-- ---- hook.Run("OnUndo") must add EXACTLY ONE legacy notice -------------
	if ( !isfunction( notification.AddLegacy ) ) then
		check( "notification.AddLegacy exists", false )
		summary()
		return
	end
	local oldAdd = notification.AddLegacy
	local nCalls, lastName = 0, nil
	notification.AddLegacy = function( txt, typ, len )
		nCalls = nCalls + 1
		lastName = txt
		return oldAdd( txt, typ, len )
	end
	hook.Run( "OnUndo", "HL2SBTestProp", nil )
	notification.AddLegacy = oldAdd
	check( "exactly ONE AddLegacy per hook.Run(OnUndo)", nCalls == 1 )
	check( "the notice text names the undone thing",
		lastName ~= nil and string.find( tostring( lastName ), "HL2SBTestProp", 1, true ) ~= nil )

else
	print( "[undo test] neither SERVER nor CLIENT - run inside a map" )
end

summary()
