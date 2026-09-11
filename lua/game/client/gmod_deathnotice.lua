--[[----------------------------------------------------------------------------
    gmod_deathnotice.lua

    GMod's kill feed / death notice, ported from
        garrysmod/gamemodes/base/gamemode/cl_deathnotice.lua   (308 lines)
    together with the kill icon table it registers.

    Same shape as GMod: a Deaths table with one entry per notice, each drawn as

        <killer>   <killicon>   <victim>

    killer/victim coloured by team (red/green for hostile/friendly NPCs), icon
    from killicon, an alpha fade over the last second, and the position lerping
    toward its target every frame.  GMod's own comments -- including its BUG
    comments -- are kept.

    The five places this had to be adapted to HL2SB:

      1. Event source.  GMod receives notices through six net.Receive handlers
         (PlayerKilledByPlayer / PlayerKilledSelf / PlayerKilled /
         PlayerKilledNPC / NPCKilledNPC / DeathNoticeEvent).  HL2SB has no such
         usermessages: CHudKillFeed parses the HL2MP game events in C++ and
         forwards them through the AddDeathNotice hook with eight arguments.
         The hook handler below is the only HL2SB-shaped code here; the six
         net.Receive blocks are gone and nothing else changed.  (The
         cl_killfeed_lua convar, default 1, selects this path; at 0 the C++
         HUD draws instead -- see hud_killfeed.cpp.)

      2. GM.  GMod attaches AddDeathNotice / DrawDeathNotice to the gamemode
         table.  HL2SB loads lua/game/client BEFORE the gamemode
         (cdll_client_int.cpp loads the gamemode last), so there is no table to
         attach to at load time: they are locals here, resolved lazily.  A
         gamemode that defines its own is called INSTEAD of ours.
         ⚠️ Do not also install ours on that table: hook.lua's CallBody runs the
         registered hooks and then the gamemode method, so a hook plus an
         installed method adds every notice twice (two rows, different colours).

      3. Fonts.  GMod draws the names with "ChatFont" and the icons with a font
         it created itself.  Here draw.SimpleText wants a font FAMILY (HL2SB
         knows "Default"), and the icon glyphs come from a font created with
         surface.CreateFont + SetFontGlyphSet -- the scheme font name
         "HL2MPTypeDeath" renders empty glyph boxes through surface.SetFont.
         See DEATH_FONT and ICON_FONT.

      4. Kill icon names.  GMod keys killicons by weapon / entity class
         (weapon_smg1, prop_physics).  The engine hands the Lua side HL2MP's
         mod_textures.txt short name instead (death_smg1, d_skull), so GMod's
         table is registered first and then aliased onto those names -- see the
         HL2SB alias block.  Without it every kill would show the skull.

      5. Text alignment.  GMod's TEXT_ALIGN_* are engine globals; HL2SB's live in
         the draw table (draw.lua does module( "draw" ) first), so they are
         spelled draw.TEXT_ALIGN_* here.

    Dropped from GMod's file: HandleAchievements(), which needs list.Get( "NPC" ),
    IsEnemyEntityName / IsFriendEntityName and the achievements library -- none of
    which exist in HL2SB.  Nothing else in a death notice depends on it.

    Loaded from lua/game/client/ (client only: it draws).
-----------------------------------------------------------------------------]]--

if ( not _CLIENT ) then return end

require( "hook" )
require( "surface" )
require( "draw" )
require( "team" )
require( "killicon" )

local hook     = hook
local draw     = draw
local team     = team
local killicon = killicon

-- HL2SB: GMod's "ChatFont" is only a scheme font here, and draw.SimpleText wants
-- a font family for surface.SetFontGlyphSet.  "Default" is the family the other
-- HL2SB HUDs use (hl2sb_undo_notify.lua, hl2sb_cl_hudpickup.lua).
local DEATH_FONT = "Default"

-- HL2SB: the kill icon glyphs.
--
-- GMod passes the *name* of a font it created itself ("HL2MPTypeDeath") to
-- surface.SetFont.  Here that name is a client-scheme font, and looking it up
-- from Lua renders empty glyph boxes: LISurface.cpp's surface_SetFont resolves
-- it through CScheme::GetFont(name, false) (vgui2/src/Scheme.cpp:1401 -- note
-- that second argument is `proportional`, not "create if missing"), while the
-- engine's own HUD creates the face through the font manager --
-- hud.cpp:760/912 does GetFont( name, true ), and Scheme.cpp:942 does
-- SetFontGlyphSet( font, name, tall, ... ).
--
-- So create it the same way the engine does, and the same way the previous
-- hl2sb_deathnotice.lua did: surface.CreateFont() + SetFontGlyphSet().  That
-- returns a *font container*, which is what surface.GetTextSize /
-- surface.DrawSetTextFont (font.lua) accept, and it survives resolution
-- changes.  killicon.AddFont takes either a name or a handle for this reason.
--
-- FONTFLAG_ANTIALIAS | FONTFLAG_ADDITIVE = 0x110: the death fonts are additive
-- by design (resource/clientscheme.res marks them "additive" "1").
local ICON_FONT_NAME = "HL2MP"     -- resource/hl2mp.ttf, the weapon pictograms
local ICON_FONT_TALL = 20          -- ~text height; the scheme's 32px glyphs are
                                   -- far too big next to 16px names
local FONTFLAG_ANTIALIAS = 0x010
local FONTFLAG_ADDITIVE  = 0x100

local ICON_FONT = surface.CreateFont()
surface.SetFontGlyphSet( ICON_FONT, ICON_FONT_NAME, ICON_FONT_TALL, 0, 0, 0,
                         FONTFLAG_ANTIALIAS + FONTFLAG_ADDITIVE )

local hud_deathnotice_time = CreateConVar( "hud_deathnotice_time", "6", FCVAR_NONE, "Amount of time to show death notice (kill feed) for" )
local cl_drawhud = GetConVar( "cl_drawhud" )

-- HL2SB: the C++ kill feed caps the list with hud_killfeed_max, and GMod's file
-- knows no such thing -- its Deaths table grows without limit, which is what
-- makes the feed unreadable in a big fight (and costs Lua time per entry).
-- Read the same cvar: 0 = unlimited, -1 = the panel's res value (treated as
-- unlimited here, the C++ side owns that).
local hud_killfeed_max = GetConVar( "hud_killfeed_max" )

-- These are our kill icons
local Color_Icon = Color( 255, 80, 0, 255 )
local NPC_Color_Enemy = Color( 250, 50, 50, 255 )
local NPC_Color_Friendly = Color( 50, 200, 50, 255 )

killicon.AddFont( "prop_physics",		ICON_FONT,	"9",	Color_Icon, 0.52 )
killicon.AddFont( "weapon_smg1",		ICON_FONT,	"/",	Color_Icon, 0.55 )
killicon.AddFont( "weapon_357",			ICON_FONT,	".",	Color_Icon, 0.55 )
killicon.AddFont( "weapon_ar2",			ICON_FONT,	"2",	Color_Icon, 0.6 )
killicon.AddFont( "crossbow_bolt",		ICON_FONT,	"1",	Color_Icon, 0.5 )
killicon.AddFont( "weapon_shotgun",		ICON_FONT,	"0",	Color_Icon, 0.45 )
killicon.AddFont( "rpg_missile",		ICON_FONT,	"3",	Color_Icon, 0.35 )
killicon.AddFont( "npc_grenade_frag",	ICON_FONT,	"4",	Color_Icon, 0.56 )
killicon.AddFont( "weapon_pistol",		ICON_FONT,	"-",	Color_Icon, 0.52 )
killicon.AddFont( "prop_combine_ball",	ICON_FONT,	"8",	Color_Icon, 0.5 )
killicon.AddFont( "grenade_ar2",		ICON_FONT,	"7",	Color_Icon, 0.35 )
killicon.AddFont( "weapon_stunstick",	ICON_FONT,	"!",	Color_Icon, 0.6 )
killicon.AddFont( "npc_satchel",		ICON_FONT,	"*",	Color_Icon, 0.53 )
killicon.AddFont( "weapon_crowbar",		ICON_FONT,	"6",	Color_Icon, 0.45 )
killicon.AddFont( "weapon_physcannon",	ICON_FONT,	",",	Color_Icon, 0.55 )

killicon.AddAlias( "npc_tripmine", "npc_satchel" )

-- Half-Life 1 weapons, just so we have something to show for them
killicon.AddAlias( "weapon_crowbar_hl1", "weapon_crowbar" )
killicon.AddAlias( "crossbow_bolt_hl1", "crossbow_bolt" )
killicon.AddAlias( "weapon_357_hl1", "weapon_357" )
killicon.AddAlias( "weapon_mp5_hl1", "weapon_smg1" )
killicon.AddAlias( "weapon_shotgun_hl1", "weapon_shotgun" )
killicon.AddAlias( "weapon_glock_hl1", "weapon_pistol" )
killicon.AddAlias( "rpg_rocket", "rpg_missile" )
killicon.AddAlias( "grenade_hand", "npc_grenade_frag" )

-- Prop like objects get the prop kill icon
killicon.AddAlias( "prop_ragdoll", "prop_physics" )
killicon.AddAlias( "prop_physics_respawnable", "prop_physics" )
killicon.AddAlias( "func_physbox", "prop_physics" )
killicon.AddAlias( "func_physbox_multiplayer", "prop_physics" )
killicon.AddAlias( "trigger_vphysics_motion", "prop_physics" )
killicon.AddAlias( "func_movelinear", "prop_physics" )
killicon.AddAlias( "func_plat", "prop_physics" )
killicon.AddAlias( "func_platrot", "prop_physics" )
killicon.AddAlias( "func_pushable", "prop_physics" )
killicon.AddAlias( "func_rotating", "prop_physics" )
killicon.AddAlias( "func_rot_button", "prop_physics" )
killicon.AddAlias( "func_tracktrain", "prop_physics" )
killicon.AddAlias( "func_train", "prop_physics" )
killicon.AddAlias( "prop_vehicle_jeep", "prop_physics" )
killicon.AddAlias( "prop_vehicle_jeep_old", "prop_physics" )
killicon.AddAlias( "prop_vehicle_apc", "prop_physics" )
killicon.AddAlias( "prop_vehicle_prisoner_pod", "prop_physics" )
killicon.AddAlias( "prop_vehicle_airboat", "prop_physics" )

-- ===========================================================================
-- HL2SB: the engine's names for the same icon.
--
-- CHudKillFeed pushes CHudTexture::szShortName, which is the key it looked up in
-- mod_textures.txt -- "death_<weapon>" ("death_smg1", "death_357", ...) -- and
-- "d_skull" when it fell back to the textured skull (suicide, world death, or a
-- weapon with no glyph).  Aliasing them onto GMod's names above keeps GMod's
-- table exactly as it is.
-- ===========================================================================

killicon.AddAlias( "death_357", "weapon_357" )
killicon.AddAlias( "death_ar2", "weapon_ar2" )
killicon.AddAlias( "death_crossbow_bolt", "crossbow_bolt" )
killicon.AddAlias( "death_crossbow", "crossbow_bolt" )
killicon.AddAlias( "death_smg1", "weapon_smg1" )
killicon.AddAlias( "death_shotgun", "weapon_shotgun" )
killicon.AddAlias( "death_rpg_missile", "rpg_missile" )
killicon.AddAlias( "death_rpg", "rpg_missile" )
killicon.AddAlias( "death_grenade_frag", "npc_grenade_frag" )
killicon.AddAlias( "death_frag", "npc_grenade_frag" )
killicon.AddAlias( "death_handgrenade", "npc_grenade_frag" )
killicon.AddAlias( "death_pistol", "weapon_pistol" )
killicon.AddAlias( "death_physics", "prop_physics" )
killicon.AddAlias( "death_physcannon", "prop_physics" )
killicon.AddAlias( "death_physgun", "prop_physics" )
killicon.AddAlias( "death_combine_ball", "prop_combine_ball" )
killicon.AddAlias( "death_smg1_grenade", "grenade_ar2" )
killicon.AddAlias( "death_stunstick", "weapon_stunstick" )
killicon.AddAlias( "death_slam", "npc_satchel" )
killicon.AddAlias( "death_satchel", "npc_satchel" )
killicon.AddAlias( "death_tripmine", "npc_satchel" )
killicon.AddAlias( "death_crowbar", "weapon_crowbar" )
killicon.AddAlias( "d_skull", "default" )
killicon.AddAlias( "death_skull", "default" )

-- ===========================================================================
-- HL2SB: friendly NPCs.
--
-- GMod asks IsFriendEntityName(), which HL2SB has no binding for.  The engine
-- strips the "npc_" prefix before it hands a name to Lua (CHudKillFeed's
-- KillFeed_DisplayName), so these are matched against what is left ("citizen",
-- "barney", "vortigaunt", ...).
-- ===========================================================================

local FRIENDLY_NPC = {
	["citizen"]    = true,
	["refugee"]    = true,
	["rebel"]      = true,
	["alyx"]       = true,
	["barney"]     = true,
	["breen"]      = true,
	["dog"]        = true,
	["eli"]        = true,
	["kleiner"]    = true,
	["magnusson"]  = true,
	["mossman"]    = true,
	["monk"]       = true,
	["odessa"]     = true,
	["vortigaunt"] = true,
	["gman"]       = true,
	["griggs"]     = true,
	["sheckley"]   = true,
}

local function IsFriendlyNPC( name )
	if ( not name or name == "" ) then return false end

	local lower = string.lower( name )
	for key in pairs( FRIENDLY_NPC ) do
		if ( lower == key or string.find( lower, key, 1, true ) ) then
			return true
		end
	end

	return false
end

local Deaths = {}

local function getDeathColor( teamID, target )

	if ( teamID == -1 ) then
		return table.Copy( NPC_Color_Enemy )
	end

	if ( teamID == -2 ) then
		return table.Copy( NPC_Color_Friendly )
	end

	return table.Copy( team.GetColor( teamID ) )

end

--[[---------------------------------------------------------
	Name: gamemode:AddDeathNotice( Attacker, team1, Inflictor, Victim, team2, flags )
	Desc: Adds an death notice entry

	GMod writes this as `function GM:AddDeathNotice( attacker, ... )`, which makes
	the gamemode table an implicit first argument.  These are attached to the
	gamemode table below (InstallGamemode), so the parameter is spelled out.
-----------------------------------------------------------]]
local function AddDeathNotice( self, attacker, team1, inflictor, victim, team2, flags )

	if ( inflictor == "suicide" ) then attacker = nil end

	local Death = {}
	Death.time		= CurTime()

	Death.left		= attacker
	Death.right		= victim
	Death.icon		= inflictor
	Death.flags		= flags

	Death.color1	= getDeathColor( team1, Death.left )
	Death.color2	= getDeathColor( team2, Death.right )

	table.insert( Deaths, Death )

	-- HL2SB: cap the list (see hud_killfeed_max above) so a pile of simultaneous
	-- deaths cannot stack an unreadable column.
	local iMax = hud_killfeed_max and hud_killfeed_max:GetInt() or 4
	if ( iMax > 0 ) then
		while ( #Deaths > iMax ) do
			table.remove( Deaths, 1 )
		end
	end

end

local function DrawDeath( x, y, death, time )

	local w, h = killicon.GetSize( death.icon )
	if ( !w or !h ) then return end

	local fadeout = ( death.time + time ) - CurTime()

	local alpha = math.Clamp( fadeout * 255, 0, 255 )
	death.color1.a = alpha
	death.color2.a = alpha

	-- Draw Icon
	killicon.Render( x - w / 2, y, death.icon, alpha )

	-- Draw KILLER
	if ( death.left ) then
		draw.SimpleText( death.left, DEATH_FONT, x - ( w / 2 ) - 16, y + h / 2, death.color1, draw.TEXT_ALIGN_RIGHT, draw.TEXT_ALIGN_CENTER )
	end

	-- Draw VICTIM
	draw.SimpleText( death.right, DEATH_FONT, x + ( w / 2 ) + 16, y + h / 2, death.color2, draw.TEXT_ALIGN_LEFT, draw.TEXT_ALIGN_CENTER )

	return math.ceil( y + h * 0.75 )

	-- Font killicons are too high when height corrected, and changing that is not backwards compatible
	--return math.ceil( y + math.max( h, 28 ) )

end

-- GMod writes this as `function GM:DrawDeathNotice( x, y )`; see AddDeathNotice.
local function DrawDeathNotice( self, x, y )

	if ( cl_drawhud and cl_drawhud:GetInt() == 0 ) then return end

	-- HL2SB: never let a missing or zero convar value pop every notice out
	-- instantly (hud_deathnotice_time is an engine ConVar here, default 6).
	local time = hud_deathnotice_time and hud_deathnotice_time:GetFloat() or 6
	if ( time <= 0 ) then time = 6 end

	local reset = Deaths[1] != nil -- Don't reset it if there's nothing in it

	x = x * ScrW()
	y = y * ScrH()

	-- Draw
	for k, Death in ipairs( Deaths ) do

		if ( Death.time + time > CurTime() ) then

			if ( Death.lerp ) then
				x = x * 0.3 + Death.lerp.x * 0.7
				y = y * 0.3 + Death.lerp.y * 0.7
			end

			Death.lerp = Death.lerp or {}
			Death.lerp.x = x
			Death.lerp.y = y

			y = DrawDeath( math.floor( x ), math.floor( y ), Death, time )
			reset = false

		end

	end

	-- We want to maintain the order of the table so instead of removing
	-- expired entries one by one we will just clear the entire table
	-- once everything is expired.
	if ( reset ) then
		Deaths = {}
	end

end

-- ===========================================================================
-- HL2SB: the gamemode table.
--
-- lua/game/client is loaded before the gamemode, so _GAMEMODE is normally nil
-- at this point (luamanager.cpp sets it in luasrc_LoadGamemode, and
-- cdll_client_int.cpp calls that last).  Resolve it lazily.
--
-- ⚠️ Do NOT install our AddDeathNotice on that table.  The engine dispatches
-- this event with hook.call(), and hook.lua's CallBody runs the registered
-- hooks FIRST and the gamemode method SECOND (hook.lua:57-89) -- so a hook plus
-- an installed method produce TWO notices per death (seen in game 2026-09-11:
-- two rows, one red and one yellow, because the gamemode path receives the raw
-- team ids instead of the hostile/friendly NPC codes).  Only *call* a gamemode
-- method, and only when the gamemode defined one itself -- that is the GMod
-- semantic without the double dispatch.
-- ===========================================================================

local GM = _G._GAMEMODE or _G.GM

local function Gamemode()
	if ( GM == nil ) then
		GM = _G._GAMEMODE or _G.GM
	end

	return GM
end

-- HL2SB: one-shot error flags for the two hooks below.
local bAddError  = false
local bDrawError = false

-- ===========================================================================
-- Events
--
-- Argument order is CHudKillFeed's (hud_killfeed.cpp, the AddDeathNotice
-- forward): attacker, attackerTeam, inflictor, victim, victimTeam, suicide,
-- victimIsNPC, killerIsPlayer.
-- ===========================================================================

hook.add( "AddDeathNotice", "gmod_deathnotice", function( attacker, attackerTeam, inflictor,
                                                          victim, victimTeam,
                                                          suicide, victimIsNPC, killerIsPlayer )
	-- GMod's team codes: -1 = hostile NPC, -2 = friendly NPC, anything else is a
	-- team id that team.GetColor() knows.
	local team1, team2

	if ( suicide ) then
		-- GMod's PlayerKilledSelf sends the inflictor "suicide", which
		-- AddDeathNotice turns into "no attacker", and killicon aliases to the
		-- default skull.
		inflictor = "suicide"
		team1 = -1
	elseif ( killerIsPlayer ) then
		team1 = attackerTeam or 0
	elseif ( IsFriendlyNPC( attacker ) ) then
		team1 = -2
	else
		team1 = -1
	end

	if ( victimIsNPC ) then
		team2 = IsFriendlyNPC( victim ) and -2 or -1
	else
		team2 = victimTeam or 0
	end

	local gm = Gamemode()

	-- Only a gamemode's OWN AddDeathNotice is called (see the note above): ours
	-- is reached through the registered hook, and installing it here as well
	-- would add every notice twice.
	--
	-- HL2SB: guarded with pcall.  hook.lua UNREGISTERS a hook that throws
	-- ("Hook '...' Failed:"), so one bad notice would silently stop the feed for
	-- the rest of the level.  Report the first failure and keep the hook alive.
	local ok, err = pcall( function()
		if ( gm and gm.AddDeathNotice ) then
			gm:AddDeathNotice( attacker, team1, inflictor, victim or "", team2, 0 )
		else
			AddDeathNotice( nil, attacker, team1, inflictor, victim or "", team2, 0 )
		end
	end )

	if ( not ok and not bAddError ) then
		bAddError = true
		print( "[HL2SB] gmod_deathnotice: AddDeathNotice failed, feed continues: " .. tostring( err ) .. "\n" )
	end
end )

-- GMod's base gamemode draws the feed from its HUDPaint with
--     hook.Run( "DrawDeathNotice", 0.85, 0.04 )      (gamemodes/base/gamemode/cl_init.lua:84)
-- HL2SB's equivalent per-frame moment is HudViewportPaint.
hook.add( "HudViewportPaint", "gmod_deathnotice", function()
	-- Same guard as above, and it matters more here: this hook runs EVERY frame,
	-- so anything that throws once (a blown Lua stack, a bad icon, a missing
	-- material) would take the whole kill feed off the screen until the next
	-- level.  Fail quietly instead, once.
	local ok, err = pcall( function()
		local gm = Gamemode()

		if ( gm and gm.DrawDeathNotice ) then
			gm:DrawDeathNotice( 0.85, 0.04 )
		else
			DrawDeathNotice( nil, 0.85, 0.04 )
		end
	end )

	if ( not ok and not bDrawError ) then
		bDrawError = true
		print( "[HL2SB] gmod_deathnotice: draw failed, feed keeps trying: " .. tostring( err ) .. "\n" )
	end
end )

print( "[HL2SB] gmod_deathnotice.lua loaded (GMod cl_deathnotice port)\n" )
