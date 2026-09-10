--[[---------------------------------------------------------------------------
    HL2SB undo module (server side).

    Port of GMod's lua/includes/modules/undo.lua, restricted to the server-side
    core that HL2SB's Lua 5.1 environment can actually run.  Everything that
    needs a binding HL2SB does not have (net.*, saverestore, timer,
    entity:CallOnRemove, the Derma controlpanel UI) is intentionally omitted;
    the *undo logic and the force-condition hooks* are kept so scripts can pull
    undoable actions into a per-player stack and undo them.

    The force conditions (GMod semantics) are preserved:
      * hook.Run("CanCreateUndo", owner, undo)   -> gate adding to the stack
      * hook.Run("PreUndo", undo)                -> false cancels Do_Undo
      * hook.Run("PostUndo", undo, count)        -> just after undoing
      * hook.Run("CanUndo", ply, undo)           -> gate undoing

    Triggered by console commands (no UI):
      * hl2sb_undo        -> undo this player's most recent action
      * hl2sb_undoclear   -> clear this player's whole undo stack

    Loaded every level from lua/includes/modules/.
-----------------------------------------------------------------------------]]

if _CLIENT then
    return
end

require( "hook" )
require( "concommand" )
require( "table" )

module( "undo", package.seeall )

local hook = hook
local table = table
local pairs = pairs
local IsValid = IsValid
local concommand = concommand

-- PlayerUndo[ userID ][ index ] = { Name, Entities = {}, Owner = ply, Functions = {} }
local PlayerUndo = {}
local Current_Undo = nil

--[[---------------------------------------------------------
    GetTable
-----------------------------------------------------------]]
function GetTable()
    return PlayerUndo
end

--[[---------------------------------------------------------
    Create
    Start a new undo action.
-----------------------------------------------------------]]
function Create( text )
    Current_Undo = {}
    Current_Undo.Name       = text
    Current_Undo.Entities   = {}
    Current_Undo.Owner      = nil
    Current_Undo.Functions  = {}
end

--[[---------------------------------------------------------
    SetCustomUndoText
-----------------------------------------------------------]]
function SetCustomUndoText( CustomUndoText )
    if ( not Current_Undo ) then return end
    Current_Undo.CustomUndoText = CustomUndoText
end

--[[---------------------------------------------------------
    AddEntity
    Adds an entity to this undo (removed on undo).
-----------------------------------------------------------]]
function AddEntity( ent )
    if ( not Current_Undo ) then return end
    if ( not IsValid( ent ) ) then return end
    table.insert( Current_Undo.Entities, ent )
end

--[[---------------------------------------------------------
    AddFunction
    Add a function to call when this undo is undone.
-----------------------------------------------------------]]
function AddFunction( func, ... )
    if ( not Current_Undo ) then return end
    if ( not func ) then return end
    table.insert( Current_Undo.Functions, { func, { ... } } )
end

--[[---------------------------------------------------------
    ReplaceEntity
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
    SetPlayer
    Sets whose undo this is.
-----------------------------------------------------------]]
function SetPlayer( ply )
    if ( not Current_Undo ) then return end
    if ( not IsValid( ply ) ) then return end
    Current_Undo.Owner = ply
end

--[[---------------------------------------------------------
    Can_CreateUndo
    Honours hook.Run("CanCreateUndo").
-----------------------------------------------------------]]
local function Can_CreateUndo( undo )
    local call = hook.Run( "CanCreateUndo", undo.Owner, undo )
    return call == true or call == nil
end

--[[---------------------------------------------------------
    Finish
-----------------------------------------------------------]]
function Finish( NiceText )
    if ( not Current_Undo ) then return end

    if ( not IsValid( Current_Undo.Owner ) or
         ( table.IsEmpty( Current_Undo.Entities ) and table.IsEmpty( Current_Undo.Functions ) ) or
         not Can_CreateUndo( Current_Undo ) ) then
        Current_Undo = nil
        return false
    end

    local index = Current_Undo.Owner:UniqueID()
    PlayerUndo[ index ] = PlayerUndo[ index ] or {}

    Current_Undo.NiceText = NiceText or ( "#" .. Current_Undo.Name )

    table.insert( PlayerUndo[ index ], Current_Undo )
    Current_Undo = nil
    return true
end

--[[---------------------------------------------------------
    Do_Undo
-----------------------------------------------------------]]
function Do_Undo( undo )
    if ( not undo ) then return false end

    if ( hook.Run( "PreUndo", undo ) == false ) then return end

    local count = 0

    -- Call each function
    if ( undo.Functions ) then
        for index, func in pairs( undo.Functions ) do
            local success = func[ 1 ]( undo, unpack( func[ 2 ] ) )
            if ( success ~= false ) then
                count = count + 1
            end
        end
    end

    -- Remove each entity in this undo
    if ( undo.Entities ) then
        for index, entity in pairs( undo.Entities ) do
            if ( IsValid( entity ) ) then
                entity:Remove()
                count = count + 1
            end
        end
    end

    hook.Run( "PostUndo", undo, count )
    return count
end

--[[---------------------------------------------------------
    Can_Undo
    Honours hook.Run("CanUndo").
-----------------------------------------------------------]]
local function Can_Undo( ply, undo )
    local call = hook.Run( "CanUndo", ply, undo )
    return call == true or call == nil
end

--[[---------------------------------------------------------
    UndoLast (console: hl2sb_undo / gmod-style `undo`)
-----------------------------------------------------------]]
local function UndoLast( ply )
    if ( not IsValid( ply ) ) then return end
    local index = ply:UniqueID()
    PlayerUndo[ index ] = PlayerUndo[ index ] or {}

    local last = nil
    local lastk = nil
    for k, v in pairs( PlayerUndo[ index ] ) do
        lastk = k
        last = v
    end

    if ( not last ) then return end

    last.Owner = ply

    if ( not Can_Undo( ply, last ) ) then return end

    local count = Do_Undo( last )
    PlayerUndo[ index ][ lastk ] = nil

    -- If nothing happened, keep unwinding to the previous undoable action
    if ( count == 0 ) then
        UndoLast( ply )
    end
end

--[[---------------------------------------------------------
    ClearAll (console: hl2sb_undoclear)
-----------------------------------------------------------]]
local function ClearAll( ply )
    if ( not IsValid( ply ) ) then return end
    local index = ply:UniqueID()
    PlayerUndo[ index ] = {}
    print( "[HL2SB] undo stack cleared" )
end

local function CC_UndoLast( ply, command, args )
    UndoLast( ply )
end

local function CC_ClearAll( ply, command, args )
    ClearAll( ply )
end

concommand.Create( "hl2sb_undo",      CC_UndoLast, "Undo this player's last action" )
concommand.Create( "hl2sb_undoclear", CC_ClearAll, "Clear this player's undo stack" )

print( "[HL2SB] undo module loaded" )
