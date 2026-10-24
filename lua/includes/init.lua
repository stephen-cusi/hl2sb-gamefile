-- Shared libraries are prepared by the native bootstrap before this entry.
-- Keep original modules separate from fork-specific compatibility.

include( "util.lua" )
include( "util/sql.lua" )
include( "drive/drive_base.lua" )
include( "drive/drive_noclip.lua" )
include( "gmsave.lua" )
include( "hl2sb/compat/weapon_registry.lua" )

if ( CLIENT and surface and vgui ) then

	include( "hl2sb/compat/client.lua" )
	include( "derma/init.lua" )
	include( "skins/default.lua" )
	include( "vgui_base.lua" )
	include( "vgui_extra.lua" )
	include( "util/tooltips.lua" )
	include( "notification.lua" )
	include( "util/javascript_util.lua" )
	include( "util/workshop_files.lua" )
	include( "util/model_database.lua" )

end

include( "hl2sb/compat/shared.lua" )

if ( CLIENT ) then
	include( "hl2sb/compat/contextmenu.lua" )
end
