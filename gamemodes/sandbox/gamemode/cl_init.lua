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
include( "cl_worldtips.lua" )
include( "cl_hints.lua" )
-- HL2SB (2026-10-16): the spawn-menu tool-menu contract (GMod
-- gamemodes/sandbox/gamemode/cl_spawnmenu.lua, reference line 2 is that
-- file's own `include( "spawnmenu/spawnmenu.lua" )`; see the ported file's
-- header for what was left out).  The engine gamemode loader only runs
-- gamemode/cl_init.lua / init.lua, so the file has to be included here,
-- exactly like cl_hints.lua / cl_worldtips.lua above.
include( "cl_spawnmenu.lua" )

local BaseClass = gamemode.Get( "base" )

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

function GM:LimitHit( name )

	local str = "#SBoxLimit_" .. name
	local translated = language.GetPhrase( str )
	if ( str == translated ) then
		-- No translation available, apply our own
		local strPhrase = language.GetPhrase( "hint.hitXlimit" )
		if ( strPhrase and strPhrase != "hint.hitXlimit" and strPhrase:find( "%%" ) ) then
			translated = language.FormatPhrase( "hint.hitXlimit", language.GetPhrase( name ) )
		else
			translated = "You have hit the " .. language.GetPhrase( name ) .. " limit!"
		end
	end

	self:AddNotify( translated, NOTIFY_ERROR, 6 )
	surface.PlaySound( "buttons/button10.wav" )

end

function GM:HUDPaint()

	self:PaintWorldTips()

	-- Draw all of the default stuff
	local base = BaseClass or ( gamemode and gamemode.Get and gamemode.Get( "base" ) )
	if ( base and base.HUDPaint ) then
		base.HUDPaint( self )
	end

end
