--========== HL2SB - GMod compat ==========--
--
-- Purpose: Named list registry (ported from Garry's Mod's list module).
--
--===========================================================================--

module( "list", package.seeall )

local Lists = {}

-------------------------------------------------------------------------------
-- Purpose: A copy of a list (safe to hand out)
-------------------------------------------------------------------------------
function Get( listid )
	return table.Copy( GetForEdit( listid ) )
end

-------------------------------------------------------------------------------
-- Purpose: The live list table. Creates it unless nocreate is set.
-------------------------------------------------------------------------------
function GetForEdit( listid, nocreate )
	local list = Lists[ listid ]

	if ( not nocreate and list == nil ) then
		list = {}
		Lists[ listid ] = list
	end

	return list
end

-------------------------------------------------------------------------------
-- Purpose: Names of every list
-------------------------------------------------------------------------------
function GetTable()
	return table.GetKeys( Lists )
end

-------------------------------------------------------------------------------
-- Purpose: Appends a value
-------------------------------------------------------------------------------
function Add( listid, value )
	return table.insert( GetForEdit( listid ), value )
end

-------------------------------------------------------------------------------
-- Purpose: True when value is present
-------------------------------------------------------------------------------
function Contains( listid, value )
	local list = Lists[ listid ]
	if ( list == nil ) then return false end

	for _, v in pairs( list ) do
		if ( v == value ) then return true end
	end

	return false
end

-------------------------------------------------------------------------------
-- Purpose: Sets a keyed entry
-------------------------------------------------------------------------------
function Set( listid, key, value )
	GetForEdit( listid )[ key ] = value
end

-------------------------------------------------------------------------------
-- Purpose: Clears a keyed entry
-------------------------------------------------------------------------------
function RemoveEntry( listid, key )
	GetForEdit( listid )[ key ] = nil
end

-------------------------------------------------------------------------------
-- Purpose: True when the key exists
-------------------------------------------------------------------------------
function HasEntry( listid, key )
	local list = Lists[ listid ]

	return list ~= nil and list[ key ] ~= nil
end

-------------------------------------------------------------------------------
-- Purpose: Reads a keyed entry (tables are copied)
-------------------------------------------------------------------------------
function GetEntry( listid, key )
	local list = GetForEdit( listid )
	local value = list[ key ]

	if ( istable( value ) ) then
		value = table.Copy( value )
	end

	return value
end
