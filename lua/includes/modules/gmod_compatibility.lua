--[[----------------------------------------------------------------------------
    gmod_compatibility - entry point

    Ported from Experiment: Source
    (game/experiment/addons/gmod_compatibility/scripts/lua/includes/modules/).

    Experiment's original entry is two lines:
        -- lua_run require("gmod_compatibility")
        Include("gmod_compatibility/sh_init.lua")

    Two differences here:

      * HL2SB spells the global `include`, not `Include`.  `include` resolves
        relative to the calling file, so from lua/includes/modules/ this still
        finds gmod_compatibility/sh_init.lua.

      * This file lives in lua/includes/modules/, and HL2SB loads *every* .lua
        in that directory on every level (luasrc_dofolder, non-recursive).
        Experiment only ever pulls the module in through `require`, so their
        entry never ran unconditionally.  Running it now would abort the module
        pass with a hard error -- sh_init.lua opens with require("bitwise"),
        require("gamemodes"), require("hooks") and require("timers"), none of
        which exist in HL2SB yet -- so it stays inert behind this switch.

    TODO(port): set GMOD_COMPATIBILITY = true once the port is complete; the
    Experiment bootstrap, its plural modules and GMod's derma/ + vgui/ +
    includes/ all have to be in place first.
-----------------------------------------------------------------------------]]

GMOD_COMPATIBILITY = GMOD_COMPATIBILITY or false

if ( not GMOD_COMPATIBILITY ) then
    return
end

include( "gmod_compatibility/sh_init.lua" )
