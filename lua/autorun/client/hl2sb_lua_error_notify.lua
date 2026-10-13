--[[----------------------------------------------------------------------------
    hl2sb_lua_error_notify.lua  --  GMod's on-screen Lua error toast.

    Garry's Mod's lua/menu/errors.lua installs a hook.Add( "DrawOverlay" ) that
    paints a top-left stack of "The addon "X" is creating errors" rows, one per
    addon, each with an alert icon, a 0.5 s colour flash on a fresh error and a
    10 s lifetime.  This fork has no DrawOverlay dispatch (only the HUD hooks
    fire every frame), so the same drawing runs from HUDPaint.  The geometry,
    colours, phrases and timing are the reference values; errors arrive through
    the engine's GM:OnLuaError (see luamanager.cpp).

    This is the on-screen notification only.  The fuller triage viewers stay
    where they were (console hl2sb_errors; the main-menu Lua errors dialog).
-----------------------------------------------------------------------------]]

if ( not CLIENT ) then return end

-- GMod keys its notification table by addon id; with no workshop id we key by
-- the addon name the engine resolved (nil -> the "" bucket, "something").
local Errors = {}

local matAlert = Material( "icon16/error.png" )
local matInfo  = Material( "icon16/information.png" )

-- The reference draws with DermaDefaultBold (13px Tahoma); at this fork's
-- common resolutions 13px CJK is hard to read, so the toast carries its own
-- slightly larger face (same pattern as cl_voice.lua's GModVoiceNotify).
surface.CreateFont( "HL2SBLuaErrorNotify", {
    font     = "Microsoft YaHei",
    size     = 16,
    weight   = 800,
    extended = true
} )

-- cl_drawhud 0 hides the notification, exactly like the reference.
local function DrawEnabled()
    if ( GetConVar == nil ) then return true end
    local cvar = GetConVar( "cl_drawhud" )
    if ( cvar == nil ) then return true end
    return cvar:GetBool()
end

local function Push( addonName, realm )
    -- addonName nil => the "something" bucket; the engine already turns an
    -- unresolved addon into nil for us.
    local key = addonName or ""

    if ( Errors[ key ] ) then
        Errors[ key ].times = Errors[ key ].times + 1
        Errors[ key ].last  = SysTime()
        return
    end

    -- The reference's default text points at its Problems menu (errors.*_p);
    -- this fork has no Problems menu, so use the console variants
    -- (errors.something / errors.addon, "...check the console for details").
    local text
    if ( isstring( addonName ) ) then
        text = language.FormatPhrase( "errors.addon", addonName )
    else
        text = language.GetPhrase( "errors.something" )
    end

    Errors[ key ] = {
        first    = SysTime(),
        last     = SysTime(),
        times    = 1,
        x        = 32,
        text     = text,
        iserr    = true,
        realm    = realm,
    }
end

hook.Add( "OnLuaError", "HL2SBLuaErrorNotify", function( err, realm, stack, addonName, addonId )
    Push( addonName, realm )
end )

-- HUDPaint is the every-frame 2D hook this fork fires (GMod uses DrawOverlay).
hook.Add( "HUDPaint", "HL2SBLuaErrorNotify", function()

    if ( table.IsEmpty( Errors ) ) then return end
    if ( not DrawEnabled() ) then return end

    local idealy = 32
    local height = 30
    local EndTime  = SysTime() - 10
    local Recent   = SysTime() - 0.5

    surface.SetFont( "HL2SBLuaErrorNotify" )

    for k, v in SortedPairsByMemberValue( Errors, "last" ) do

        if ( v.y == nil ) then v.y = idealy end
        if ( v.w == nil ) then v.w = surface.GetTextSize( v.text ) + 48 end

        -- 2 px dark drop shadow, then the light body (reference layout).
        draw.RoundedBox( 2, v.x + 2, v.y + 2, v.w, height, Color( 40, 40, 40, 255 ) )
        draw.RoundedBox( 2, v.x, v.y, v.w, height, Color( 240, 240, 240, 255 ) )

        if ( v.last > Recent ) then
            if ( v.iserr ) then
                draw.RoundedBox( 2, v.x, v.y, v.w, height, Color( 255, 200, 0, ( v.last - Recent ) * 510 ) )
            else
                draw.RoundedBox( 2, v.x, v.y, v.w, height, Color( 0, 200, 255, ( v.last - Recent ) * 510 ) )
            end
        end

        surface.SetTextColor( 90, 90, 90, 255 )
        surface.SetTextPos( v.x + 34, v.y + 6 )
        surface.DrawText( v.text )

        surface.SetDrawColor( 255, 255, 255, 150 + math.sin( v.y + SysTime() * 30 ) * 100 )
        if ( v.iserr ) then
            surface.SetMaterial( matAlert )
        else
            surface.SetMaterial( matInfo )
        end
        surface.DrawTexturedRect( v.x + 6, v.y + 6, 16, 16 )

        v.y = idealy
        idealy = idealy + 40

        if ( v.last < EndTime ) then
            Errors[ k ] = nil
        end

    end

end )
