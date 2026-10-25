-- Runtime compatibility around unchanged original modules.
-- Load after native modules and before original Derma and addon registration.
if ( rawget( _G, "HL2SB_CoreModulesReady" ) ) then return end
_G.HL2SB_CoreModulesReady = true

-- These globals are native in GMod. Keep them outside its math extension.
if ( LerpVector == nil ) then
    function LerpVector( fraction, from, to )
        return Vector( from.x + ( to.x - from.x ) * fraction,
            from.y + ( to.y - from.y ) * fraction,
            from.z + ( to.z - from.z ) * fraction )
    end
end

if ( LerpAngle == nil ) then
    function LerpAngle( fraction, from, to )
        return Angle( from.p + ( to.p - from.p ) * fraction,
            from.y + ( to.y - from.y ) * fraction,
            from.r + ( to.r - from.r ) * fraction )
    end
end

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
    local counts = {}
    for _, name in ipairs( { "props", "ragdolls", "effects", "npcs",
        "constraints", "ropeconstraints", "sents", "vehicles" } ) do
        cleanup.Register( name )
    end

    local add = cleanup.Add
    cleanup.Add = function( player, category, entity )
        if ( not IsValid( player ) ) then return end
        return add( player, category, entity )
    end

    function cleanup.AddCount( player, category, entity )
        if ( not IsValid( player ) or not entity ) then return end
        local key = player:UniqueID()
        counts[ key ] = counts[ key ] or {}
        counts[ key ][ category ] = ( counts[ key ][ category ] or 0 ) + 1
    end

    function cleanup.GetCount( player, category )
        if ( not IsValid( player ) ) then return 0 end
        local entries = counts[ player:UniqueID() ]
        return entries and entries[ category ] or 0
    end

    local meta = FindMetaTable( "Player" )
    if ( meta and meta.AddCleanup == nil ) then
        function meta:AddCleanup( category, entity )
            cleanup.Add( self, category, entity )
        end
    end
    if ( meta and meta.AddCount == nil ) then
        function meta:AddCount( category, entity )
            cleanup.AddCount( self, category, entity )
        end
    end
end
