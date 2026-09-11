--[[----------------------------------------------------------------------------
    lua/includes/init.lua  --  HL2SB

    *** This file is NOT GMod's.  It is the one deliberate deviation in
    lua/includes/, and it exists only until the modules GMod's own init.lua
    would pull in are ported. ***

    GMod's own lua/includes/init.lua is the bootstrap: it includes util.lua and
    util/sql.lua, then `require`s ~25 shared modules (saverestore, weapons,
    scripted_ents, construct, duplicator, constraint, cleanup, numpad,
    usermessage, cvars, http, properties, widget, cookie, utf8, drive, ...) and,
    on the client, draw / markup / effects / halo / killicon / spawnmenu /
    controlpanel / presets / menubar / matproxy, and finally the extensions.

    HL2SB loads extensions/ and modules/ itself, and most of that module list
    does not exist here yet, so this file includes only what is actually
    available and grows one line at a time as the port lands.  When the last
    line of GMod's list becomes real, delete this file and copy GMod's in.

    ==========================================================================
    Everything it includes is GMod's file, byte for byte, and the ORDER is
    GMod's too (its engine loads these three in this order):

        util.lua            type predicates, AccessorFunc, FORCE_*, Lerp,
                            Either, PrintTable, STNDRD, ...
                            (pulls in util/color.lua via its own include)
        derma/init.lua      the Derma framework: fonts, derma.DefineControl /
                            DefineSkin / SkinHook, Derma_Hook, and the
                            sub-includes (derma.lua, derma_utils.lua, ...)
        vgui_base.lua       includes the 54 lua/vgui/*.lua controls

    derma/init.lua has to precede vgui_base.lua: every control in lua/vgui/
    calls derma.DefineControl at file scope.

    Loaded from lua/includes/ by luasrc_dofolder_sorted() (see the
    LUA_PATH_INCLUDES block in cdll_client_int.cpp and gameinterface.cpp).
    Note that include() resolves relative to the calling file first, then falls
    back to lua/ -- which is how "derma/init.lua" is found from here.
-----------------------------------------------------------------------------]]--

include( "util.lua" )

-- GMod's scripted-panel layer: vgui.Register / vgui.Create / vgui.CreateX and
-- the Panel metatable extensions.  MUST precede derma/init.lua -- derma.lua's
-- DefineControl calls vgui.Register, and scriptedpanels.lua is the version that
-- resolves a base class through PanelFactory instead of requiring it to be a
-- registered vgui[] factory.
include( "extensions/client/panel.lua" )

include( "derma/init.lua" )

include( "vgui_base.lua" )
