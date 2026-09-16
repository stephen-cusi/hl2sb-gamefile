--[[----------------------------------------------------------------------------
	gmod_vgui.lua  --  trimmed to what the derma framework does NOT provide.

	HISTORY: this file was HL2SB's first hand-written vgui/derma shim -- it
	registered minimal DPanel/DFrame/DLabel/DButton/DTextEntry controls and a
	no-op derma.SkinHook so a copied GMod window could open at all.  With the
	custom framework in lua/derma/ those are all superseded: the class system,
	vgui.Create/Register, fonts and the skin registry now come from
	lua/derma/hl2sb_derma.lua + hl2sb_skin.lua + derma/init.lua.  The old
	control definitions, the conmand hl2sb_uitest (it built windows from the
	shim's private registry) and its drag hook were removed on 2026-09-14.

	What stays: the two root-panel accessors GMod code calls, which have no
	engine equivalent.
-----------------------------------------------------------------------------]]

if ( not _CLIENT and not _GAMEUI ) then return end

local IS_MENU = ( not _CLIENT ) and _GAMEUI

--- GMod's root panel accessor, resolved per realm.
local function rootPanel()
    if ( IS_MENU and VGui_GetGameUIPanel ) then
        return VGui_GetGameUIPanel()
    end
    if ( VGui_GetClientLuaRootPanel ) then
        return VGui_GetClientLuaRootPanel()
    end
    return nil
end

--- GMod's root panel accessors.
function vgui.GetWorldPanel()
    return rootPanel()
end

function vgui.GetHoveredPanel()
    if ( input and input.GetMouseOver ) then return input.GetMouseOver() end
    return nil
end
