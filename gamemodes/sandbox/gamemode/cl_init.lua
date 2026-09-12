--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

if ( not bit ) then
  require( "bit" )
end

include( "shared.lua" )
include( "in_main.lua" )
include( "scripted_controls/buildmenu.lua" )

-- HL2SB: GMod 的 sandbox cl_init.lua:11 在这里 include( "cl_spawnmenu.lua" )。
-- 这一行就是"GMod 的 spawnmenu 到底有没有被加载"的开关：cl_spawnmenu.lua
-- include 了 spawnmenu/spawnmenu.lua（整个 UI），并定义 GM:SpawnMenuOpen /
-- GM:OnSpawnMenuOpen / GM:AddGamemodeToolMenuTabs / GM:PopulatePropMenu 等。
-- Team Sandbox 的 buildmenu（上一行）保留不动，两者互不冲突。
include( "cl_spawnmenu.lua" )

local bor = bit.bor
local FONTFLAG_ANTIALIAS = _E.FONTFLAG.ANTIALIAS
local FONTFLAG_ADDITIVE = _E.FONTFLAG.ADDITIVE
local FONTFLAG_CUSTOM = _E.FONTFLAG.CUSTOM

function GM:CreateDefaultPanels()
  gBuildMenuInterface = vgui.CBuildMenu( VGui_GetClientLuaRootPanel(), "build" )

  surface.AddCustomFontFile( "DIN-Light", "gamemodes/sandbox/content/resource/DINLi.ttf" )

  gBuildMenuInterface.m_hFonts[ "BuildMenuTextLarge" ] = surface.CreateFont()
  surface.SetFontGlyphSet(
    gBuildMenuInterface.m_hFonts[ "BuildMenuTextLarge" ],
    "DIN-Light",
    64,
    0,
    0,
    0,
    bor( FONTFLAG_ANTIALIAS, FONTFLAG_ADDITIVE, FONTFLAG_CUSTOM )
  )
  gBuildMenuInterface.m_hFonts[ "BuildMenuTextLargeSelected" ] = surface.CreateFont()
  surface.SetFontGlyphSet(
    gBuildMenuInterface.m_hFonts[ "BuildMenuTextLargeSelected" ],
    "DIN-Light",
    64,
    0,
    5,
    2,
    bor( FONTFLAG_ANTIALIAS, FONTFLAG_ADDITIVE, FONTFLAG_CUSTOM )
  )
end
