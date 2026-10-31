-- Runtime compatibility around unchanged original modules.
-- Load after native modules and before original Derma and addon registration.
if ( rawget( _G, "HL2SB_CoreModulesReady" ) ) then return end
_G.HL2SB_CoreModulesReady = true
include( "hl2sb/compat/binary_modules.lua" )

-- Entity factories accept the native nextbot type without an explicit base.
hook.Add( "PreRegisterSENT", "HL2SBNextbotDefaultBase", function( definition )
    if ( definition.Type == "nextbot" and definition.Base == nil ) then
        definition.Base = "base_nextbot"
    end
end )

-- The native folder bootstrap also visits client-only modules on the server.
if ( SERVER ) then
    hook.Remove( "OnGamemodeLoaded", "CreateMenuBar" )
end

-- Non-sandbox modes retain their existing cleanup services.
if ( SERVER and cleanup ) then
    for _, name in ipairs( { "props", "ragdolls", "effects", "npcs",
        "constraints", "ropeconstraints", "sents", "vehicles" } ) do
        cleanup.Register( name )
    end
end
