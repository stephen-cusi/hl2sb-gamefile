-- Runtime compatibility around unchanged original modules.
-- Load after native modules and before original Derma and addon registration.
if ( rawget( _G, "HL2SB_CoreModulesReady" ) ) then return end
_G.HL2SB_CoreModulesReady = true
include( "hl2sb/compat/binary_modules.lua" )

-- Lua 5.4 rejects fractional bounds that older addon scripts pass.
if ( not math.__hl2sb_random_patched ) then
    local random = math.random
    math.random = function( low, high )
        if ( low == nil ) then return random() end
        if ( high == nil ) then return random( 1, math.floor( low ) ) end
        low, high = math.floor( low ), math.floor( high )
        if ( high < low ) then low, high = high, low end
        return random( low, high )
    end
    math.__hl2sb_random_patched = true
end

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
