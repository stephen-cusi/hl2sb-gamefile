--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/cl_spawnmenu.lua

    GMod base gamemode cl_spawnmenu.lua, ported for HL2SB (2026-10-08).

    Deviation: GMod's file also registers the +menu / -menu / +menu_context /
    -menu_context concommands.  On this fork those four are engine
    ConCommands (cdll_client_int.cpp) that dispatch OnSpawnMenuOpen /
    OnSpawnMenuClose / OnContextMenuOpen / OnContextMenuClose directly, so
    registering the Lua twins would collide with the engine registration.
    Only the four gamemode stubs are kept - hook.Run falls back to the
    GAMEMODE method when no hook is registered, which is what makes the
    engine commands reach them.
--------------------------------------------------------------------------]]--

--[[---------------------------------------------------------
	Spawn Menu
-----------------------------------------------------------]]
function GM:OnSpawnMenuOpen()
end

function GM:OnSpawnMenuClose()
end

--[[---------------------------------------------------------
	Context Menu
-----------------------------------------------------------]]
function GM:OnContextMenuOpen()
end

function GM:OnContextMenuClose()
end
