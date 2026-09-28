--[[----------------------------------------------------------------------------
    hl2sb_notification.lua

    Shims that keep GMod's notification module and its gamemode-layer notices
    working on this fork.

    The undo popup is NOT here.  GMod's chain is:

        server: lua/includes/modules/undo.lua -> Do_Undo()
                -> net "Undo_FireUndo" (name, hasCustomText, customtext)
        client: undo.lua net.Receive -> hook.Run( "OnUndo", name, customtext )
                -> GM:OnUndo            (GMod: sandbox/gamemode/cl_init.lua:46;
                                         this fork: deathmatch/gamemode/cl_init.lua
                                         - this fork's real base gamemode)
                -> GM:AddNotify         (GMod: sandbox/gamemode/cl_notice.lua:2)
                -> notification.AddLegacy( text, NOTIFY_UNDO, 2 )
                -> NoticePanel (lua/includes/notification.lua)

    hook.Run dispatches the registered hooks and THEN the gamemode method
    (GMod's own hook.lua Call - verified against the shipped file 2026-09-29),
    so the gamemode method IS the popup and registering a second OnUndo hook on
    top of it prints two notices per undo.  This file used to do exactly that
    (a hook.add( "OnUndo", ... ) plus a 0.25 s de-dup hack masking it) - removed
    2026-09-29; GM:OnUndo in the deathmatch cl_init is the only consumer, the
    same shape as GMod.
----------------------------------------------------------------------------]]--

-- ===========================================================================
-- render.* filter stack (no-ops)
--
-- GMod's notification.lua:241-245 wraps its icon blit in
-- render.PushFilterMag/ PushFilterMin / PopFilterMin / PopFilterMag to stop the
-- scaled notice icons from looking terrible.  HL2SB has no such bindings: the
-- four functions in game/client/lua/lrender.cpp are #if 0'd out because they go
-- straight through g_pShaderApi, which this engine does not expose outside the
-- materialsystem DLL -- and upstream marks them "Non-functional; help wanted" /
-- "TODO: This doesn't work" anyway, so nothing is lost that ever worked.
--
-- They are defined here rather than engine-side so GMod's notification.lua can
-- stay byte-for-byte: it only calls them from inside the icon's Paint closure,
-- which runs long after lua/game/client/ has loaded.
-- ===========================================================================
TEXFILTER = TEXFILTER or {
	NEAREST     = 1,
	LINEAR      = 2,
	ANISOTROPIC = 3,
}

local function NoopFilter() end

render.PushFilterMag = render.PushFilterMag or NoopFilter
render.PushFilterMin = render.PushFilterMin or NoopFilter
render.PopFilterMag  = render.PopFilterMag  or NoopFilter
render.PopFilterMin  = render.PopFilterMin  or NoopFilter

-- GMod's sandbox exposes AddNotify on the gamemode so tools can post notices
-- (LimitHit / hints).  Same one-liner as cl_notice.lua:2 - kept as a fallback
-- only: the deathmatch cl_init (the fork's base gamemode) already defines it
-- for everything, so this never fires there.
if ( _G.GM ~= nil and GM.AddNotify == nil ) then
	function GM:AddNotify( str, type, length )
		if ( notification and notification.AddLegacy ) then
			notification.AddLegacy( str, type, length )
		end
	end
end

print( "[HL2SB] hl2sb_notification.lua loaded (notification shims; popup lives in the gamemode)" )
