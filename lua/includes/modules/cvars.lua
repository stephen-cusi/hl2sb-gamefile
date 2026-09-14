--[[--========================================================
	HL2SB `cvars` library - ConVar change callbacks.

	Re-implemented from scratch against the GMod wiki surface
	(https://wiki.facepunch.com/gmod/cvars); NOT a copy of GMod's lua.

	Public API (matches the wiki exactly):
		cvars.AddChangeCallback( name, callback, identifier=nil )
		cvars.RemoveChangeCallback( name, identifier )
		cvars.GetConVarCallbacks( name, createIfNotFound=false )
		cvars.OnConVarChanged( name, oldVal, newVal )   -- called by the engine bridge
		cvars.String( name, default=nil )
		cvars.Number( name, default=nil )
		cvars.Bool( name, default=nil )

	The callback signature is ( convarName:string, oldValue:string, newValue:string ).

	Re-entry guard: lua/includes/modules/*.lua are executed once by the loader and
	AGAIN on any require("cvars") (luasrc_dofolder does not populate package.loaded),
	so without the guard the second run would wipe ConVars and orphan every callback
	registered before it - the exact class of bug that killed hook/concommand here.
------------------------------------------------------------]]--

-- Capture the globals we use BEFORE module() swaps _ENV to the (seeall-less)
-- module table, after which bare `type`/`table`/`GetConVar` are not visible.
local type      = type
local table     = table
local tostring  = tostring
local error     = error
local GetConVar = GetConVar

local GlobalTable = _G   -- capture before module() swaps _ENV (see hook.lua)

module( "cvars" )

if ( GlobalTable.cvars and GlobalTable.cvars.AddChangeCallback and GlobalTable.cvars.OnConVarChanged ) then
	return GlobalTable.cvars
end

local ConVars = {}

-- Return the callback list for `name`; create (and store) an empty one if asked.
function GetConVarCallbacks( name, createIfNotFound )
	local tab = ConVars[ name ]
	if ( tab == nil and createIfNotFound ) then
		tab = {}
		ConVars[ name ] = tab
	end
	return tab
end

-- The engine bridge (cvar.lua CallGlobalChangeCallbacks) calls this on every change.
-- Each stored callback is either a plain function or { func, identifier }.
function OnConVarChanged( name, old, new )
	local tab = ConVars[ name ]
	if ( tab == nil ) then return end

	-- Iterate over slots by index and tolerate nils: a callback may Add/RemoveChangeCallback
	-- and mutate the list while we walk it.
	for i = 1, #tab do
		local cb = tab[ i ]
		if ( cb ~= nil ) then
			if ( type( cb ) == "table" ) then
				cb[ 1 ]( name, old, new )
			else
				cb( name, old, new )
			end
		end
	end
end

function AddChangeCallback( name, func, identifier )
	if ( identifier ~= nil and type( identifier ) ~= "string" ) then
		error( "cvars.AddChangeCallback: bad argument #3 (string expected, got " .. type( identifier ) .. ")", 2 )
	end
	if ( type( func ) ~= "function" ) then
		error( "cvars.AddChangeCallback: bad argument #2 (function expected, got " .. type( func ) .. ")", 2 )
	end

	local tab = GetConVarCallbacks( name, true )

	if ( identifier == nil ) then
		table.insert( tab, func )
		return
	end

	-- Same (name, identifier) pair replaces the existing callback (wiki: identifier is
	-- paired with the convar name, not globally unique).
	for i = 1, #tab do
		local cb = tab[ i ]
		if ( type( cb ) == "table" and cb[ 2 ] == identifier ) then
			cb[ 1 ] = func
			return
		end
	end

	table.insert( tab, { func, identifier } )
end

function RemoveChangeCallback( name, identifier )
	local tab = ConVars[ name ]
	if ( tab == nil ) then return end

	for i = #tab, 1, -1 do
		local cb = tab[ i ]
		if ( type( cb ) == "table" and cb[ 2 ] == identifier ) then
			table.remove( tab, i )
			return
		end
	end
end

function String( name, default )
	local cv = GetConVar( name )
	if ( cv ~= nil ) then return cv:GetString() end
	return default
end

function Number( name, default )
	local cv = GetConVar( name )
	if ( cv ~= nil ) then return cv:GetFloat() end
	return default
end

function Bool( name, default )
	local cv = GetConVar( name )
	if ( cv ~= nil ) then return cv:GetBool() end
	return default
end
