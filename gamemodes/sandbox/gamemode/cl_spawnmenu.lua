
--[[---------------------------------------------------------
	gamemodes/sandbox/gamemode/cl_spawnmenu.lua

	HL2SB port (2026-10-16) of the TOOL-MENU half of GMod's
	gamemodes/sandbox/gamemode/cl_spawnmenu.lua.  Reference install:
	D:\games\garrysmod\garrysmod (byte-identical to the Steam install under
	  D:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod;
	  both copies MD5-compared before porting).

	WHERE THESE ARE CALLED FROM (all pure Lua -- the engine dispatches none of
	these names; a grep of this fork's game/ + public/ source and of the
	reference client.dll / server.dll finds no "AddToolMenuTabs",
	"AddGamemodeToolMenuTabs", "AddToolMenuCategories",
	"AddGamemodeToolMenuCategories", "PopulateToolMenu", "AddSTOOL" or
	"GetSpawnmenuTools" string anywhere):

	  spawn-menu tool menu creation (reference spawnmenu/spawnmenu.lua:198-232)
	    hook.Run( "AddGamemodeToolMenuTabs" )        -> GM:AddGamemodeToolMenuTabs
	    hook.Run( "AddToolMenuTabs" )                -> GM:AddToolMenuTabs
	    hook.Run( "AddGamemodeToolMenuCategories" )  -> GM:AddGamemodeToolMenuCategories
	    hook.Run( "AddToolMenuCategories" )          -> GM:AddToolMenuCategories
	    hook.Run( "PopulateToolMenu" )               -> GM:PopulateToolMenu

	hook.Run falls back to the GAMEMODE method (lua/includes/modules/hook.lua),
	so these bodies are reached exactly like in GMod.  In this fork the pump runs
	from the tools tab of lua/autorun/client/hl2sb_spawnmenu_gmod.lua.

	The tab / category / tool registry these call into
	(lua/includes/modules/spawnmenu.lua: AddToolTab, AddToolCategory,
	GetToolMenu, AddToolMenuOption, ActivateTool, ClearToolMenus) is GMod's own
	module file -- MD5-identical to the reference copy, already in this tree.

	DELIBERATELY NOT PORTED from the reference file, with reasons:

	  * include( "spawnmenu/spawnmenu.lua" ) (reference line 2) -- that is GMod's
	    whole spawn-menu Derma UI (SpawnMenu panel + creation menu + context
	    menu + its CreateSpawnMenu hook pump).  This fork already ships a spawn
	    menu and only needs the tool menu inside it; two SpawnMenu panels would
	    fight over g_SpawnMenu.
	  * GM:OnSpawnMenuOpen / GM:OnSpawnMenuClose -- the fork's +menu / -menu
	    ConCommands already fire hook.Run("OnSpawnMenuOpen"/"OnSpawnMenuClose")
	    from the engine (game/client/cdll_client_int.cpp) and the fork's menu
	    listens on those hooks.  A GM method here would be a second opener.
	  * GM:ContextMenuEnabled / GM:ContextMenuOpen -- already defined in
	    gamemodes/sandbox/gamemode/cl_init.lua with the same values.
	  * GM:SpawnMenuEnabled / SpawnMenuOpen / SpawnMenuOpened / SpawnMenuClosed /
	    SpawnMenuCreated / ContextMenuOpened / ContextMenuClosed /
	    ContextMenuCreated -- the lifecycle of the Derma spawn menu that is not
	    ported; nothing in the tool chain reads them.

	The function bodies below are the reference's, verbatim.
-----------------------------------------------------------]]

--[[---------------------------------------------------------
	Backwards compatibility. Do Not Use!!!
-----------------------------------------------------------]]
-- HL2SB (2026-10-16): the tool-menu panels themselves.  The engine gamemode
-- loader only executes gamemode/cl_init.lua / gamemode/init.lua, so the
-- spawnmenu/ folder is never walked on its own; GMod pulls toolmenu.lua in
-- from spawnmenu/spawnmenu.lua:5, which this fork does not port.  toolmenu.lua
-- then includes toolpanel.lua -> controlpanel.lua -> controls/manifest.lua, all
-- of them the reference files copied verbatim into
-- gamemodes/sandbox/gamemode/spawnmenu/ (include() is caller-relative, so
-- those chains resolve there).
include( "spawnmenu/toolmenu.lua" )

function GM:GetSpawnmenuTools( name )
	return spawnmenu.GetToolMenu( name )
end

--[[---------------------------------------------------------
	Backwards compatibility. Do Not Use!!!
-----------------------------------------------------------]]
function GM:AddSTOOL( category, itemname, text, command, controls, cpanelfunction )
	self:AddToolMenuOption( "Main", category, itemname, text, command, controls, cpanelfunction )
end

function GM:PreReloadToolsMenu()
end

--[[---------------------------------------------------------
	Don't hook or override this function.
	Hook AddToolMenuTabs instead!
-----------------------------------------------------------]]
function GM:AddGamemodeToolMenuTabs()

	-- This is named like this to force it to be the first tab
	spawnmenu.AddToolTab( "Main",		"#spawnmenu.tools_tab", "icon16/wrench.png" )
	spawnmenu.AddToolTab( "Utilities",	"#spawnmenu.utilities_tab", "icon16/page_white_wrench.png" )

end

--[[---------------------------------------------------------
	Add your custom tabs here.
-----------------------------------------------------------]]
function GM:AddToolMenuTabs()

	-- Hook me!

end

--[[---------------------------------------------------------
	Add categories to your tabs
-----------------------------------------------------------]]
function GM:AddGamemodeToolMenuCategories()

	spawnmenu.AddToolCategory( "Main", "Constraints",	"#spawnmenu.tools.constraints" )
	spawnmenu.AddToolCategory( "Main", "Construction",	"#spawnmenu.tools.construction" )
	spawnmenu.AddToolCategory( "Main", "Poser",			"#spawnmenu.tools.posing" )
	spawnmenu.AddToolCategory( "Main", "Render",		"#spawnmenu.tools.render" )

end

--[[---------------------------------------------------------
	Add categories to your tabs
-----------------------------------------------------------]]
function GM:AddToolMenuCategories()

	-- Hook this function to add custom stuff

end

function GM:PopulateToolMenu()
end

function GM:PostReloadToolsMenu()
end

--[[---------------------------------------------------------
	Add categories to your tabs
-----------------------------------------------------------]]
function GM:PopulatePropMenu()

	-- This function makes the engine load the spawn menu text files.
	-- We call it here so that any gamemodes not using the default
	-- spawn menu can totally not call it.
	spawnmenu.PopulateFromEngineTextFiles()

end
