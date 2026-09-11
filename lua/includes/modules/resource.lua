--[[---------------------------------------------------------------------------
    HL2SB: Garry's Mod's `resource` library.

    In Garry's Mod `resource` is a C library that builds the "the client must
    download these files" list for a dedicated server:
        resource.AddFile( path )
        resource.AddSingleFile( path )
        resource.AddWorkshop( id )

    HL2SB has no download-list mechanism and the C++ side has no AddFile
    binding at all, so this module exists for one reason: an enormous number of
    GMod addons call resource.AddFile(...) from their lua/autorun/*.lua, and
    without this they die on "attempt to call a nil value (field 'AddFile')"
    the moment autorun is loaded.  The calls are deliberately no-ops -- the
    mod's content is already on disk.

    Path: lua/includes/modules/resource.lua
----------------------------------------------------------------------------]]

-- The top-level guard is the same one hook.lua uses: luasrc_dofolder() loads
-- this file as a PLAIN FILE (so package.loaded is not populated) and a later
-- require( "resource" ) would execute it again.  Re-running the body is harmless
-- here because every assignment below is unconditional, but keep it that way.
if ( _G.resource ~= nil and _G.resource.AddFile ~= nil ) then
	return _G.resource
end

module( "resource" )

function AddFile( path )
end

function AddSingleFile( path )
end

function AddWorkshop( id )
end
