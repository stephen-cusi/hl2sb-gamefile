--[[----------------------------------------------------------------------------
    hl2sb_notification.lua

    GMod's notification system, wired to HL2SB (replaces the hand-written
    hl2sb_undo_notify.lua that used to live next to this file).

    GMod's chain, reproduced here:

        server: engine undo -> lua/includes/modules/undo.lua -> Do_Undo()
                -> net "Undo_FireUndo" (name, hasCustomText, customtext)
        client: lua/includes/modules/undo.lua:134 net.Receive
                -> hook.Run( "OnUndo", name, customtext )
                -> GM:OnUndo            (GMod sandbox gamemode/cl_init.lua:46)
                -> GM:AddNotify         (GMod sandbox gamemode/cl_notice.lua:2)
                -> notification.AddLegacy( text, NOTIFY_UNDO, 2 )
                -> NoticePanel (lua/includes/modules/notification.lua)

    The last three are GMod code now:
      * lua/includes/modules/notification.lua -- verbatim, byte for byte.  It
        owns the whole look: spring physics (VelX/VelY + friction), the cartoon
        "charge then fly off" exit, the DPanel background and the
        vgui/notices/* icon.
      * this file -- only the two things GMod keeps in its sandbox gamemode
        (GM:OnUndo's text resolution and GM:AddNotify) plus the render.*
        compatibility the panel needs.

    Deviation count: 1 (the render.* no-ops below).
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

-- ===========================================================================
-- GM:OnUndo -- GMod sandbox gamemode/cl_init.lua:46
-- ===========================================================================
local function UndoText( name, customtext )
	if ( customtext and customtext ~= "" ) then return customtext end

	-- GMod tries the "#Undone_<name>" token, then the "hint.undoneX" format.
	-- language.GetPhrase returns the token unchanged when it is unknown, which
	-- is exactly the test GMod uses.
	local strId = "#Undone_" .. tostring( name )
	if ( language and language.GetPhrase ) then
		local ok, text = pcall( language.GetPhrase, strId )
		if ( ok and type( text ) == "string" and text ~= strId ) then return text end
	end

	return "Undone " .. tostring( name )
end

hook.add( "OnUndo", "hl2sb_notification", function( name, customtext )
	if ( notification == nil or notification.AddLegacy == nil ) then
		Msg( "[HL2SB] OnUndo: notification.AddLegacy missing\n" )
		return
	end

	HL2SB_HUDDebug( "OnUndo:", tostring( name ), "custom=" .. tostring( customtext ) )

	-- GMod: self:AddNotify( text, NOTIFY_UNDO, 2 )
	notification.AddLegacy( UndoText( name, customtext ), NOTIFY_UNDO, 2 )

	if ( surface and surface.PlaySound ) then
		surface.PlaySound( "buttons/button15.wav" )
	end
end )

-- GMod's sandbox exposes AddNotify on the gamemode so tools can post notices
-- (LimitHit / OnCleanup / hints).  Same one-liner as cl_notice.lua:2.
if ( _G.GM ~= nil and GM.AddNotify == nil ) then
	function GM:AddNotify( str, type, length )
		if ( notification and notification.AddLegacy ) then
			notification.AddLegacy( str, type, length )
		end
	end
end

print( "[HL2SB] hl2sb_notification.lua loaded (GMod notification system)" )
