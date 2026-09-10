--========== HL2SB - GMod compat ==========--
--
-- Purpose: Base class registry (ported from Garry's Mod's baseclass module).
--
--   DEFINE_BASECLASS( "name" ) is an engine-side macro in GMod; HL2SB has no
--   such preprocessing, so ported files must write
--
--       local BaseClass = baseclass.Get( "name" )
--
--   instead.  Everything else behaves like GMod.
--
--===========================================================================--

module( "baseclass", package.seeall )

local BaseClassTable = {}

-------------------------------------------------------------------------------
-- Purpose: Returns (and remembers) the base class table for a name.
--          Also records the name on ENT/SWEP under construction, which is how
--          GMod learns an entity's or weapon's base.
-------------------------------------------------------------------------------
function Get( name )
	if ( ENT )  then ENT.Base  = name end
	if ( SWEP ) then SWEP.Base = name end

	BaseClassTable[ name ] = BaseClassTable[ name ] or {}

	return BaseClassTable[ name ]
end

-------------------------------------------------------------------------------
-- Purpose: Registers a base class table
-------------------------------------------------------------------------------
function Set( name, tab )
	if ( not BaseClassTable[ name ] ) then
		BaseClassTable[ name ] = tab
	else
		table.Merge( BaseClassTable[ name ], tab )
		setmetatable( BaseClassTable[ name ], getmetatable( tab ) )
	end

	BaseClassTable[ name ].ThisClass = name
end

-------------------------------------------------------------------------------
-- Purpose: All registered base classes
-------------------------------------------------------------------------------
function GetAll()
	return BaseClassTable
end
