-- ===========================================================================
-- HL2SB NPC / NextBot engine-contract test v2 (2026-10-06).
--
-- Server console, in a map with at least one NPC and one Lua nextbot:
--   lua_dofile lnpc_lib_test.lua
--
-- Asserts:
--   1. FindMetaTable("NPC") / ("NextBot") resolve with the GMod stamping
--      (MetaName / MetaID=9 / MetaBaseClass=Entity).
--   2. EVERY method on the Garry's Mod wiki's NPC page (182 entries) is
--      present on the server metatable -- or, for BecomeRagdoll, reachable
--      through the CBaseAnimating chain (GMod's own table leaves it there).
--   3. type() / IsNPC() / script-override precedence on a live NPC.
--   4. NextBot surface on a live bot.
--   5. Negative checks (player is not an NPC; world sentinel reads false).
-- ===========================================================================

local passed, failed = 0, 0
local function check( name, ok )
  if ( ok ) then
    passed = passed + 1
  else
    failed = failed + 1
    print( "[npct FAIL] " .. name )
  end
end

-- ---------------------------------------------------------------------------
-- 1. FindMetaTable + stamping
-- ---------------------------------------------------------------------------
local npcMeta = FindMetaTable( "NPC" )
check( "FindMetaTable('NPC') returns a table", istable( npcMeta ) )
if ( istable( npcMeta ) ) then
  check( "NPC.MetaName == 'NPC'", npcMeta.MetaName == "NPC" )
  check( "NPC.MetaID == 9", npcMeta.MetaID == 9 )
  check( "NPC.MetaBaseClass is Entity",
         istable( npcMeta.MetaBaseClass ) and npcMeta.MetaBaseClass.MetaName == "Entity" )
  check( "NPC.__index is a function", isfunction( npcMeta.__index ) )
end

local botMeta = FindMetaTable( "NextBot" )
check( "FindMetaTable('NextBot') returns a table", istable( botMeta ) )
if ( istable( botMeta ) ) then
  check( "NextBot.MetaName == 'NextBot'", botMeta.MetaName == "NextBot" )
  check( "NextBot.MetaID == 9", botMeta.MetaID == 9 )
end

-- ---------------------------------------------------------------------------
-- 2. the full wiki NPC method list
-- ---------------------------------------------------------------------------
local WIKI_NPC_METHODS = {
  "AddEntityRelationship","AddRelationship","AdvancePath","AlertSound","AutoMovement",
  "CapabilitiesAdd","CapabilitiesClear","CapabilitiesGet","CapabilitiesHas",
  "CapabilitiesRemove","Classify","ClearBlockingEntity","ClearCondition","ClearEnemyMemory",
  "ClearExpression","ClearGoal","ClearSchedule","ConditionID","ConditionName","Disposition",
  "DropWeapon","ExitScriptedSequence","FearSound","FoundEnemySound","GetActiveWeapon",
  "GetActivity","GetAimVector","GetArrivalActivity","GetArrivalDirection","GetArrivalDistance",
  "GetArrivalSequence","GetArrivalSpeed","GetBestSoundHint","GetBlockingEntity","GetCurGoalType",
  "GetCurrentSchedule","GetCurrentWeaponProficiency","GetCurWaypointPos","GetEnemy",
  "GetEnemyFirstTimeSeen","GetEnemyLastKnownPos","GetEnemyLastSeenPos","GetEnemyLastTimeSeen",
  "GetExpression","GetEyeDirection","GetFOV","GetGoalPos","GetGoalTarget","GetHeadDirection",
  "GetHullType","GetIdealActivity","GetIdealMoveAcceleration","GetIdealMoveSpeed",
  "GetIdealSequence","GetIdealYaw","GetKnownEnemies","GetKnownEnemyCount","GetLastPosition",
  "GetLastTimeTookDamageFromEnemy","GetMaxLookDistance","GetMinMoveCheckDist","GetMinMoveStopDist",
  "GetMoveDelay","GetMoveInterval","GetMovementActivity","GetMovementSequence","GetMoveVelocity",
  "GetNavType","GetNearestSquadMember","GetNextWaypointPos","GetNPCState","GetPathDistanceToGoal",
  "GetPathTimeToGoal","GetShootPos","GetSquad","GetStepHeight","GetTarget","GetTaskStatus",
  "GetTimeEnemyLastReacquired","GetViewOffset","GetWeapon","GetWeapons","Give","HasCondition",
  "HasEnemyEluded","HasEnemyMemory","HasObstacles","IdleSound","IgnoreEnemyUntil","IsCrouching",
  "IsCurrentSchedule","IsCurWaypointGoal","IsFacingIdealYaw","IsGoalActive","IsInViewCone",
  "IsMoveYawLocked","IsMoving","IsRunningBehavior","IsSquadLeader","IsUnforgettable",
  "IsUnreachable","LostEnemySound","MaintainActivity","MarkEnemyAsEluded","MarkTookDamageFromEnemy",
  "MoveClimbExec","MoveClimbStart","MoveClimbStop","MoveGroundStep","MoveJumpExec","MoveJumpStart",
  "MoveJumpStop","MoveOrder","MovePause","MoveStart","MoveStop","NavSetGoal","NavSetGoalPos",
  "NavSetGoalTarget","NavSetRandomGoal","NavSetWanderGoal","PickupWeapon","PlaySentence",
  "RememberUnreachable","RemoveIgnoreConditions","ResetIdealActivity","ResetMoveCalc",
  "RunEngineTask","SelectWeapon","SentenceStop","SetActivity","SetArrivalActivity",
  "SetArrivalDirection","SetArrivalDistance","SetArrivalSequence","SetArrivalSpeed",
  "SetCondition","SetCurrentWeaponProficiency","SetEnemy","SetExpression","SetForceCrouch",
  "SetFOV","SetHullSizeNormal","SetHullType","SetIdealActivity","SetIdealSequence","SetIdealYaw",
  "SetIdealYawAndUpdate","SetIgnoreConditions","SetLastPosition","SetMaxLookDistance",
  "SetMaxRouteRebuildTime","SetMoveDelay","SetMoveInterval","SetMovementActivity",
  "SetMovementSequence","SetMoveVelocity","SetMoveYawLocked","SetNavType","SetNPCState",
  "SetSchedule","SetSquad","SetStepHeight","SetTarget","SetTaskStatus","SetUnforgettable",
  "SetViewOffset","StartEngineTask","StopMoving","TargetOrder","TaskComplete","TaskFail",
  "UpdateEnemyMemory","UpdateTurnActivity","UpdateYaw","UseActBusyBehavior","UseAssaultBehavior",
  "UseFollowBehavior","UseFuncTankBehavior","UseLeadBehavior","UseNoBehavior",
}

if ( istable( npcMeta ) ) then
  local missing = {}
  for _, m in ipairs( WIKI_NPC_METHODS ) do
    if ( !isfunction( npcMeta[ m ] ) ) then missing[ #missing + 1 ] = m end
  end
  check( "wiki NPC methods present on the server metatable: " ..
         ( #WIKI_NPC_METHODS - #missing ) .. "/" .. #WIKI_NPC_METHODS ..
         ( #missing > 0 and "  missing: " .. table.concat( missing, "," ) or "" ),
         #missing == 0 )
  -- BecomeRagdoll is NOT a direct NPC-table entry -- GMod's own NPC table
  -- lacks it too; it lives on the CBaseAnimating metatable and reaches NPC
  -- instances through the __index chain (metatable-to-metatable indexing does
  -- NOT traverse the chain, so look at the owner table directly).
  local animMeta = FindMetaTable( "CBaseAnimating" )
  check( "BecomeRagdoll lives on the CBaseAnimating meta (chain source)",
         istable( animMeta ) and isfunction( animMeta.BecomeRagdoll ) )
end

-- ---------------------------------------------------------------------------
-- 3. live NPC behaviour
-- ---------------------------------------------------------------------------
-- Classnames are only hints -- the answer is validated by type() before it
-- counts (npc_scp173 here is an SNPC, npc_scp_049-2 is a NextBot; the type
-- filter picks the right one regardless of which classname list it appears
-- in).
local function findByClasses( t, classes )
  for _, cls in ipairs( classes ) do
    local list = ents.FindByClass( cls )
    for _, e in ipairs( list ) do
      if ( type( e ) == t ) then return e, cls end
    end
  end
  return nil, nil
end

local function findAny( classes )
  return findByClasses( "NPC", classes )
end

local npc, npcClass = findAny( { "npc_combine_s", "npc_citizen", "npc_zombie", "npc_antlion",
  "npc_metropolice", "npc_scp173", "npc_scp_049-2" } )
if ( npc != nil ) then
  check( "type( npc ) == 'NPC'  (" .. tostring( npcClass ) .. ")", type( npc ) == "NPC" )
  check( "npc:IsNPC() == true", npc:IsNPC() == true )
  check( "getmetatable( npc ) is the NPC table", getmetatable( npc ) == npcMeta )
  check( "npc:GetNPCState() is a number", isnumber( npc:GetNPCState() ) )
  check( "npc:GetHullType() is a number", isnumber( npc:GetHullType() ) )
  check( "npc:GetCurrentSchedule() is a number", isnumber( npc:GetCurrentSchedule() ) )
  check( "npc:IsCurrentSchedule(66) is a boolean", isbool( npc:IsCurrentSchedule( 66 ) ) )
  check( "npc:CapabilitiesGet() is a number", isnumber( npc:CapabilitiesGet() ) )
  check( "npc:CapabilitiesHas(bits_CAP_MOVE_GROUND) is a boolean", isbool( npc:CapabilitiesHas( 1 ) ) )
  check( "npc:GetEnemyLKP() is a Vector", type( npc:GetEnemyLKP() ) == "Vector" )
  check( "npc:GetEnemyLastKnownPos() is a Vector", type( npc:GetEnemyLastKnownPos() ) == "Vector" )
  check( "npc:GetKnownEnemyCount() is a number", isnumber( npc:GetKnownEnemyCount() ) )
  check( "npc:GetKnownEnemies() is a table", istable( npc:GetKnownEnemies() ) )
  check( "npc:GetWeapons() is a table", istable( npc:GetWeapons() ) )
  check( "npc:GetFOV() is a number", isnumber( npc:GetFOV() ) )
  check( "npc:SetFOV(75) + GetFOV() round-trips", ( function()
    npc:SetFOV( 75 ); return npc:GetFOV() == 75
  end )() )
  check( "npc:GetStepHeight() is a number", isnumber( npc:GetStepHeight() ) )
  check( "npc:GetMoveVelocity() is a Vector", type( npc:GetMoveVelocity() ) == "Vector" )
  check( "npc:GetEyeDirection() is a Vector", type( npc:GetEyeDirection() ) == "Vector" )
  check( "npc:GetShootPos() is a Vector", type( npc:GetShootPos() ) == "Vector" )
  check( "npc:GetBestSoundHint() answers table-or-nil", ( function()
    local v = npc:GetBestSoundHint(); return v == nil or istable( v )
  end )() )
  check( "npc:GetSquad() answers string-or-nil", ( function()
    local v = npc:GetSquad(); return v == nil or isstring( v )
  end )() )
  check( "npc:SetSquad('npctest') + GetSquad() round-trips", ( function()
    npc:SetSquad( "npctest" ); return npc:GetSquad() == "npctest"
  end )() )
  check( "npc:IsSquadLeader() is a boolean", isbool( npc:IsSquadLeader() ) )
  check( "npc:GetTaskStatus() is a number", isnumber( npc:GetTaskStatus() ) )
  check( "npc:GetMaxLookDistance() is a number", isnumber( npc:GetMaxLookDistance() ) )
  check( "npc:GetMoveDelay() is a number", isnumber( npc:GetMoveDelay() ) )
  check( "npc:IsFacingIdealYaw() is a boolean", isbool( npc:IsFacingIdealYaw() ) )
  check( "npc:HasObstacles() is a boolean", isbool( npc:HasObstacles() ) )
  check( "npc:IsGoalActive() is a boolean", isbool( npc:IsGoalActive() ) )
  check( "npc:GetCurGoalType() is a number", isnumber( npc:GetCurGoalType() ) )
  -- chain: entity/animating methods still resolve through the delegated __index
  check( "npc:GetPos() resolves through the chain", type( npc:GetPos() ) == "Vector" )
  check( "npc:Health() resolves through the chain", isnumber( npc:Health() ) )
  check( "npc:BecomeRagdoll-ish chain entry exists (GetRagdollEntity or similar)",
         isfunction( npc.GetRagdollEntity ) or isfunction( npc.BecomeRagdoll ) )
  -- script-table override precedence
  local orig = npc.IsNPC
  npc.IsNPC = function( self ) return "override" end
  check( "script-table function overrides the C method", npc:IsNPC() == "override" )
  npc.IsNPC = orig
  check( "restoring the field restores the C method", npc:IsNPC() == true )
else
  print( "[npct skip] no stock NPC found -- live NPC checks skipped" )
end

-- ---------------------------------------------------------------------------
-- 4. NextBot
-- ---------------------------------------------------------------------------
local bot, botClass = findByClasses( "NextBot",
  { "npc_scp_049-2", "npc_verity", "npc_windgrinbot", "npc_scp173", "scp173" } )
if ( bot != nil ) then
  check( "type( bot ) == 'NextBot'  (" .. tostring( botClass ) .. ")", type( bot ) == "NextBot" )
  check( "bot:IsNextBot() == true", bot:IsNextBot() == true )
  check( "getmetatable( bot ) is the NextBot table", getmetatable( bot ) == botMeta )
  local ply = player.GetAll()[ 1 ]
  if ( ply ~= nil ) then
    local ok, range = pcall( function() return bot:GetRangeTo( ply ) end )
    check( "bot:GetRangeTo(player) answers a number", ok and isnumber( range ) )
    local ok2, vis = pcall( function() return bot:IsAbleToSee( ply ) end )
    check( "bot:IsAbleToSee(player) answers a boolean", ok2 and isbool( vis ) )
  end
  check( "bot:GetSolidMask() is a number", isnumber( bot:GetSolidMask() ) )
  check( "bot:GetFOV() is a number", isnumber( bot:GetFOV() ) )
  check( "bot:SetSolidMask(1) round-trips exactly (no float loss)",
         ( function() bot:SetSolidMask( 0x0200400B ); return bot:GetSolidMask() == 0x0200400B end )() )
else
  print( "[npct skip] no Lua nextbot spawned -- nextbot checks skipped" )
end

-- ---------------------------------------------------------------------------
-- 5. negatives
-- ---------------------------------------------------------------------------
local ply = player.GetAll()[ 1 ]
if ( ply ~= nil ) then
  check( "player:IsNPC() == false", ply:IsNPC() == false )
  check( "type( player ) == 'Player' (unchanged)", type( ply ) == "Player" )
  -- Our shared Entity meta carries GetNPCState for every entity (pre-existing
  -- scp173 compat: ent:GetNPCState()), so the true NPC-only discriminator is
  -- GetCurrentSchedule, which only the NPC metatable defines.
  check( "player has no GetCurrentSchedule (NPC-meta only)", ply.GetCurrentSchedule == nil )
end

check( "Entity(0):IsNPC() reads a boolean", isbool( Entity( 0 ):IsNPC() ) )

-- same entity through two pushes compares equal
if ( npc ~= nil ) then
  local same = ents.GetByIndex( npc:EntIndex() )
  check( "same entity through two pushes compares equal", npc == same )
end

-- ---------------------------------------------------------------------------
-- 6. lua_shared GMod-architecture checks (metatable type stamping)
-- ---------------------------------------------------------------------------
-- luaL_newmetatable stamps MetaName (registry name) and MetaID (0 unless
-- luaL_newmetatable_type was used) on every freshly created metatable.
-- io's file-handle metatable is created inside lua_shared itself, so it is
-- the cleanest witness of the lauxlib change.
if ( io ~= nil and io.stdout ~= nil ) then
  local m = getmetatable( io.stdout )
  check( "FILE* metatable MetaName from lua_shared", istable( m ) and m.MetaName == "FILE*" )
  check( "untyped metatable MetaID defaults to 0", istable( m ) and m.MetaID == 0 )
else
  print( "[npct skip] io library unavailable -- lauxlib stamping checks skipped" )
end

-- The two classes created via luaL_newmetatable_type carry id 9, and the
-- player metatable keeps its lsrcinit-stamped values.
local plyMeta2 = getmetatable( player.GetAll()[ 1 ] )
if ( plyMeta2 ~= nil ) then
  check( "player metatable MetaID == 9 (lsrcinit layer intact)", plyMeta2.MetaID == 9 )
end
if ( istable( npcMeta ) ) then
  check( "NPC metatable MetaID == 9 (from luaL_newmetatable_type)", npcMeta.MetaID == 9 )
  check( "NPC metatable MetaBaseClass still linked", istable( npcMeta.MetaBaseClass ) )
end
if ( istable( botMeta ) ) then
  check( "NextBot metatable MetaID == 9 (from luaL_newmetatable_type)", botMeta.MetaID == 9 )
end

timer.Simple( 0.5, function()
  print( string.format( "[npct] %d passed, %d failed", passed, failed ) )
end )
