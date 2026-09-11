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

    Loaded from lua/includes/ by luasrc_dofile_includes( L, "init.lua" ) -- one
    named file, NOT a directory scan (see that call site in cdll_client_int.cpp
    and gameinterface.cpp: a scan re-runs vgui_base.lua and kills all 54
    controls).
    Note that include() resolves relative to the calling file first, then falls
    back to lua/ -- which is how "derma/init.lua" is found from here.
-----------------------------------------------------------------------------]]--

include( "util.lua" )

-- Everything below is CLIENT ONLY, and GMod's own bootstrap guards it the same
-- way.  On the server these files do not merely no-op: derma/init.lua opens by
-- indexing `surface` (nil server-side), so it throws before it ever reaches
-- include("derma.lua") -- which means the global `derma` is never created, and
-- vgui_base.lua's 54 lua/vgui controls then all fail with
-- "attempt to index a nil value (global 'derma')".  Guarding here is what stops
-- the server from importing the entire client VGUI layer.
-- HL2SB: one line of realm evidence, because "which realm is this and does it
-- have surface/vgui" has been the difference between a clean load and 54 FAILED
-- lines more than once.  Grep the log for "lua/includes/init.lua:".
Msg( string.format(
	"[HL2SB] lua/includes/init.lua: CLIENT=%s SERVER=%s _CLIENT=%s _GAME=%s surface=%s vgui=%s\n",
	tostring( CLIENT ), tostring( SERVER ), tostring( _CLIENT ), tostring( _GAME ),
	tostring( surface ~= nil ), tostring( vgui ~= nil ) ) )

-- HL2SB: guard on CAPABILITY, not only on the realm flag.
--
-- `CLIENT` is the GMod spelling and the engine does set it (luamanager.cpp
-- base_open), but a wrong or missing flag here is NOT a harmless no-op:
-- derma/init.lua opens by indexing `surface`, so on a realm that has no surface
-- it throws before creating the global `derma`, and vgui_base.lua's 54
-- lua/vgui controls then each fail with
-- "attempt to index a nil value (global 'derma')" -- 54 FAILED lines, no
-- controls registered.  surface + vgui exist exactly where the client VGUI
-- layer really is, so test for them directly as well.
if ( CLIENT and surface and vgui ) then

	-- GMod's scripted-panel layer: vgui.Register / vgui.Create / vgui.CreateX and
	-- the Panel metatable extensions.  MUST precede derma/init.lua -- derma.lua's
	-- DefineControl calls vgui.Register, and scriptedpanels.lua is the version that
	-- resolves a base class through PanelFactory instead of requiring it to be a
	-- registered vgui[] factory.
	include( "extensions/client/panel.lua" )

	include( "derma/init.lua" )

	include( "vgui_base.lua" )

	-- HL2SB: GMod's notification system (AddLegacy / NoticePanel).  GMod keeps
	-- this file in lua/includes/modules/notification.lua and pulls it in from
	-- its own init.lua; here it lives one directory up and is included by hand,
	-- because it MUST run after the two lines above:
	--
	--   * its last statement is vgui.Register( "NoticePanel", PANEL, "DPanel" ),
	--     and DPanel only exists once vgui_base.lua has run lua/vgui/dpanel.lua;
	--   * it calls derma.SkinHook indirectly through DPanel's Paint, which
	--     derma/derma.lua provides.
	--
	-- The engine's folder pass loads lua/includes/modules/ BEFORE this file, so
	-- leaving it in modules/ made that Register fail with
	-- "vgui.Register: base class 'DPanel' does not exist" on every level.
	include( "notification.lua" )

end
