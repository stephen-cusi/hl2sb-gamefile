-- Remaining entity compatibility helpers.
-- Typed data tables use the native slots and the original Entity installer.

local EntityMeta = FindMetaTable( "Entity" )

if ( EntityMeta == nil ) then return end

Msg( "[HL2SB] gmod entity shims loaded\n" )
