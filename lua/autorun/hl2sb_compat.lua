-- Compatibility that must run during autorun, after the shared libraries.
-- Keep the registry order used by the previous separate autorun files.
include( "hl2sb/compat/entity_shims.lua" )
include( "hl2sb/compat/registrations/npcs.lua" )
include( "hl2sb/compat/registrations/seats.lua" )
include( "hl2sb/compat/registrations/vehicles.lua" )
include( "hl2sb/compat/player_vehicle.lua" )

if ( SERVER ) then
	include( "hl2sb/compat/server_commands.lua" )
end
