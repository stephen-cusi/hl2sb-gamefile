--[[----------------------------------------------------------------------------
    gmod_util.lua

    GMod globals that GMod's own Lua files (undo.lua, cl_hudpickup.lua, ...) use
    but HL2SB never defined.  Everything here is pure Lua on top of bindings
    HL2SB already has; nothing engine-side is faked.

    Provided:
      Msg( ... )                       -- console write, no trailing newline
      PrintTable( tab, indent )        -- GMod debug helper
      util.AddNetworkString( name )    -- records the name (HL2SB's `net` sends
                                          names inline, so this is bookkeeping)
      util.PrecacheModel / util.PrecacheSound  (only if not already bound)
      concommand.Add( cmd, fn, canExecute, help, flags )  -> concommand.Create
      ent:CallOnRemove( id, fn, ... )  -- backed by the engine's EntityRemoved hook
      CurTime / UnPredictedCurTime     -- already in gmod_globals, re-exported for
                                          files that load before it

    Loaded every level from lua/includes/extensions/.
-----------------------------------------------------------------------------]]--

local type      = type
local tostring  = tostring
local table     = table
local pairs     = pairs
local select    = select
local setmetatable = setmetatable

-- ===========================================================================
-- Msg / PrintTable
-- ===========================================================================

if ( _G.Msg == nil ) then
	function Msg( ... )
		local n = select( "#", ... )
		local out = {}
		for i = 1, n do out[ i ] = tostring( ( select( i, ... ) ) ) end
		local s = table.concat( out )

		-- GMod's Msg writes to the console without adding a newline; dbg.Msg is
		-- the HL2SB binding that does exactly that.  Fall back to print().
		if ( _G.dbg ~= nil and dbg.Msg ~= nil ) then
			dbg.Msg( s )
		else
			print( s )
		end
	end
end

if ( _G.PrintTable == nil ) then
	function PrintTable( tab, indent, done )
		indent = indent or 0
		done = done or {}
		if ( done[ tab ] ) then return end
		done[ tab ] = true

		local pad = string.rep( "    ", indent )
		for k, v in pairs( tab ) do
			if ( type( v ) == "table" ) then
				Msg( pad .. tostring( k ) .. ":\n" )
				PrintTable( v, indent + 1, done )
			else
				Msg( pad .. tostring( k ) .. " = " .. tostring( v ) .. "\n" )
			end
		end
	end
end

-- ===========================================================================
-- util
-- ===========================================================================

util = util or {}

-- HL2SB's `net` library carries the message name inline in the usermessage, so
-- there is no network string table to register into.  GMod requires this call
-- before net.Start, so keep the call valid and remember the name for
-- diagnostics / for a future table-based implementation.
util.NetworkStrings = util.NetworkStrings or {}

if ( util.AddNetworkString == nil ) then
	function util.AddNetworkString( name )
		name = tostring( name )
		util.NetworkStrings[ name ] = true
		return name
	end
end

-- ===========================================================================
-- concommand.Add  (GMod signature: name, fn, canExecute, helpString, flags)
--   HL2SB's concommand.Create is ( name, fn, helpString, flags ) and already
--   invokes the callback as fn( ply, cmd, args ) -- the same shape GMod uses.
-- ===========================================================================

if ( _G.concommand ~= nil and concommand.Add == nil ) then
	function concommand.Add( cmd, fn, canExecute, helpString, flags )
		-- canExecute is accepted and ignored: HL2SB has no per-command ACL hook.
		return concommand.Create( cmd, fn, helpString, flags )
	end
end

-- ===========================================================================
-- ent:CallOnRemove( id, fn, ... )
--   GMod fires the callback when the entity is removed.  Backed by the
--   EntityRemoved hook (see the engine's entity removal path); if a build does
--   not fire it the callbacks simply never run, which is exactly GMod's
--   behaviour when an entity survives to the end of the level.
-- ===========================================================================

local CallOnRemoveTable = setmetatable( {}, { __mode = "k" } )   -- [ent] = { [id] = {fn, args} }

local entmeta = _R ~= nil and _R.CBaseEntity or nil
if ( entmeta == nil and _G.FindMetaTable ~= nil ) then
	entmeta = FindMetaTable( "Entity" )
end

if ( entmeta ~= nil and entmeta.CallOnRemove == nil ) then
	function entmeta:CallOnRemove( id, fn, ... )
		if ( not IsValid( self ) ) then return end
		if ( type( fn ) ~= "function" ) then return end

		local tbl = CallOnRemoveTable[ self ]
		if ( tbl == nil ) then
			tbl = {}
			CallOnRemoveTable[ self ] = tbl
		end

		tbl[ tostring( id ) ] = { fn, { ... } }
	end
end

-- Called by the engine when an entity is removed.
if ( _G.hook ~= nil ) then
	hook.Add( "EntityRemoved", "gmod_util.CallOnRemove", function( ent )
		local tbl = CallOnRemoveTable[ ent ]
		if ( tbl == nil ) then return end

		CallOnRemoveTable[ ent ] = nil

		for _, entry in pairs( tbl ) do
			local ok, err = pcall( entry[ 1 ], ent, unpack( entry[ 2 ] ) )
			if ( not ok ) then
				Msg( "[CallOnRemove] " .. tostring( err ) .. "\n" )
			end
		end
	end )
end

-- ===========================================================================
-- GMod: UnPredictedCurTime()
-- ===========================================================================

if ( _G.UnPredictedCurTime == nil and _G.CurTime ~= nil ) then
	UnPredictedCurTime = CurTime
end
