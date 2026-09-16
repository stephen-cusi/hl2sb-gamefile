--[[----------------------------------------------------------------------------
    lua/includes/vgui_extra.lua  --  HL2SB

    *** This file is NOT GMod's.  It exists because of HOW GMod loads its VGUI
    controls, which this fork does not copy. ***

    GMod ships 93 Derma/vgui control files in lua/vgui/, but
    lua/includes/vgui_base.lua only names 54 of them, and NOTHING in GMod's Lua
    includes the other 39 by name:

        grep -r "dhorizontaldivider" over all 277 .lua files in GMod's lua/
            -> only the control file itself

    GMod's engine walks lua/vgui/ itself, so all 93 are registered.  This fork
    only ever loaded vgui_base.lua's 54, so 39 controls -- including
    DHorizontalDivider, which gamemodes/sandbox/gamemode/spawnmenu/spawnmenu.lua
    creates at line 21 -- simply did not exist:

        Hook 'CreateSpawnMenu' (OnGamemodeLoaded) Failed:
            spawnmenu/spawnmenu.lua:22: attempt to index a nil value
                                       (field 'HorizontalDivider')
        ...:148: same, once per frame

    (vgui.Create -> lua/includes/extensions/client/panel/scriptedpanels.lua:26
     found no PanelFactory entry, fell through to the engine's vgui.Create, and
     public/lua/vgui_controls/lvgui_controls.cpp:50 returned nil because
     vgui["DHorizontalDivider"] does not exist.)

    Why a list and not a directory scan: this fork's own history (AGENTS.md 5.4.3)
    is a long lesson in what a second pass over lua/vgui/ costs --
    derma.DefineControl() takes its "reloading" branch and every control dies in
    ReloadClass() -> FindPanelsByClass() -> vgui.GetAll().  An explicit list is
    order-controlled and runs exactly once.  For the same reason this file is
    NOT folded into vgui_base.lua: that file is GMod's, byte for byte, and stays
    that way.

    The order below is generated (tools/gen_vgui_extra.py) by topological sort on
    derma.DefineControl/vgui.Register base classes, so a base is always registered
    before anything that derives from it.  All 39 files are GMod's, byte for byte.

    include() is error-isolated in this fork -- luasrc_include ->
    luasrc_dofile -> lua_pcall (game/shared/lua/luamanager.cpp:739-743) -- so one
    control that needs a binding this fork lacks logs a single

        [Lua] FAILED <file>: <reason>

    line and the remaining 38 still load.  That is deliberate: one bad control
    must not take the bootstrap down with it.
----------------------------------------------------------------------------]]--

include( "vgui/contextbase.lua" )
include( "vgui/dbinder.lua" )
include( "vgui/dbubblecontainer.lua" )
include( "vgui/dcolorcombo.lua" )
include( "vgui/dfilebrowser.lua" )
include( "vgui/dhorizontaldivider.lua" )
include( "vgui/dkillicon.lua" )
include( "vgui/dlabeleditable.lua" )
include( "vgui/dlistbox.lua" )
include( "vgui/dmenuoptioncvar.lua" )
include( "vgui/dmodelpanel.lua" )
include( "vgui/dmodelselectmulti.lua" )
include( "vgui/dnotify.lua" )
include( "vgui/dnumpad.lua" )
include( "vgui/dpanelselect.lua" )
include( "vgui/dproperties.lua" )
include( "vgui/dshape.lua" )
include( "vgui/dsprite.lua" )
include( "vgui/dtilelayout.lua" )
include( "vgui/dverticaldivider.lua" )
include( "vgui/fingerposer.lua" )
include( "vgui/fingervar.lua" )
include( "vgui/imagecheckbox.lua" )
include( "vgui/material.lua" )
include( "vgui/matselect.lua" )
include( "vgui/prop_generic.lua" )
include( "vgui/prop_vectorcolor.lua" )
include( "vgui/propselect.lua" )
include( "vgui/slidebar.lua" )
include( "vgui/spawnicon.lua" )
include( "vgui/vgui_panellist.lua" )
include( "vgui/dadjustablemodelpanel.lua" )
include( "vgui/dentityproperties.lua" )
include( "vgui/dmodelselect.lua" )
include( "vgui/prop_boolean.lua" )
include( "vgui/prop_combo.lua" )
include( "vgui/prop_entity.lua" )
include( "vgui/prop_float.lua" )
include( "vgui/prop_int.lua" )
