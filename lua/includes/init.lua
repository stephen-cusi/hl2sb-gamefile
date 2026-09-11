--[[----------------------------------------------------------------------------
    lua/includes/init.lua  --  HL2SB

    *** This file is NOT GMod's.  It is the one deliberate deviation in
    lua/includes/, and it exists only until the modules it would pull in exist. ***

    GMod's own lua/includes/init.lua is the bootstrap: it includes util.lua and
    util/sql.lua, then `require`s ~25 shared modules (saverestore, weapons,
    scripted_ents, construct, duplicator, constraint, cleanup, numpad, usermessage,
    cvars, http, properties, widget, cookie, utf8, drive, ...) and, on the client,
    draw / markup / effects / halo / killicon / spawnmenu / controlpanel / presets /
    menubar / matproxy, and finally the extensions.

    HL2SB loads extensions/ and modules/ itself, and most of that module list does
    not exist here yet, so this file includes only what is actually available and
    grows one line at a time as the port lands.  When the last line of GMod's list
    becomes real, delete this file and copy GMod's in instead.

    Everything it *does* include is GMod's file, byte for byte:
        util.lua        type predicates, AccessorFunc, FORCE_*, Lerp, Either,
                        PrintTable, STNDRD, timers helpers, ...
        (util/color.lua is pulled in by util.lua itself via include())

    Loaded from lua/includes/ by luasrc_dofolder_sorted() (see the LUA_PATH_INCLUDES
    block in cdll_client_int.cpp and gameinterface.cpp), after extensions/ +
    modules/ and before game/*.
-----------------------------------------------------------------------------]]--

include( "util.lua" )
