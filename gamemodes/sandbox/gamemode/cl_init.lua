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


-- HL2SB (2026-09-29): GMod's C context menu opt-in, verbatim from
-- gamemodes/sandbox/gamemode/cl_spawnmenu.lua:27-39.  The menu itself is
-- lua/autorun/client/hl2sb_contextmenu_gmod.lua; it asks these two gamemode
-- methods before creating / opening (hook.Run falls back to GAMEMODE, see
-- hook.lua).  GMod's base gamemode does not define them, so under any
-- non-sandbox gamemode C stays inert exactly like GMod.
function GM:ContextMenuEnabled()
  return true
end

function GM:ContextMenuOpen()
  return true
end
