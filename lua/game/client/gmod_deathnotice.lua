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

      3. Fonts / sizes.  GMod draws the names with "ChatFont" and the icons with a
         font it created itself ("HL2MPTypeDeath", tall 64).  The icon glyphs come
         from a font created with surface.CreateFont + SetFontGlyphSet -- the
         scheme font name "HL2MPTypeDeath" renders empty glyph boxes through
         surface.SetFont -- and the names are drawn with an HFont resolved from
         the scheme ChatFont, because draw.SimpleText builds its font from a
         FAMILY name at a fixed 16px (draw.lua's GetFont), which is what made the
         feed small and cramped.  See DEATH_HFONT and ICON_FONT, and the
         hud_killfeed_* convars right above them.

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

-- ===========================================================================
-- HL2SB: 击杀播报的尺寸（又小又挤的根因 + 三个可调 convar）。
--
-- GMod 的图标字体 "HL2MPTypeDeath" 是 tall **64**
-- （D:\games\garrysmod\garrysmod\resource\ClientScheme.res:639-650），于是：
--   * 材质类图标（killicon.Add，Lua 武器/插件注册的图片，例如插件武器）
--     高 = 方案字体 64 * 0.75 = **48px**（宽按素材比例，见 killicon.lua:205-212）
--   * 字体类图标（引擎 mod_textures.txt 的武器字形，走 AddFont）
--     字形框 = **64px**（killicon.lua:202-204，不走 heightScale）
--   * 名字用方案字体 "ChatFont"，行距 = 图标框 * 0.75 = 48px
-- 我们这个移植为了绕开"方案字体画符号字形变空框"（见下面 ICON_FONT 的注释）
-- 把图标改成 Lua 自建字体，当初只给了 20px -> 图标框 20px（字形实际 ~11px）、
-- 行距 15px，比 16px 的名字还矮，所以又小又挤。
-- 名字那边还叠了一个坑：draw.SimpleText 是按"字族名 + 固定 16px"建字体的
-- （draw.lua 的 GetFont），传方案字体名会被当成字族去查，于是字既不随分辨率变、
-- 也不是方案里那一档。这里改成自己把方案字体的 HFont 解析出来再放大。
--
-- 三个 convar（改完重进地图生效；FCVAR_ARCHIVE，值会存进 config）：
--   hud_killfeed_icontall   图标字体字号（= GMod 的图标框 64；移植时写死 20）
--   hud_killfeed_textscale  名字字号 = 方案 ChatFont 的字高 * 这个倍数
--   hud_killfeed_rowpitch   行距 = max( 图标框, 名字字高 ) * 这个倍数
-- ⚠️ 材质类图标（Lua 武器的图片图标）的高度**不吃** hud_killfeed_icontall，
--    它由 resource/clientscheme.res 的 "HL2MPTypeDeath" 决定（GMod = 64 -> 48px）。
-- ===========================================================================
local cv_icontall  = CreateConVar( "hud_killfeed_icontall", "64", FCVAR_ARCHIVE,
	"HL2SB: kill feed icon font height in px (GMod 64, the old port used 20)" )
local cv_textscale = CreateConVar( "hud_killfeed_textscale", "1.5", FCVAR_ARCHIVE,
	"HL2SB: kill feed name scale (multiplies the scheme ChatFont height)" )
local cv_rowpitch  = CreateConVar( "hud_killfeed_rowpitch", "1.1", FCVAR_ARCHIVE,
	"HL2SB: kill feed row pitch = max( icon, text ) height * this" )

local function CvNumber( cv, fallback )
	local v = cv and cv:GetFloat() or fallback
	if ( !v or v <= 0 ) then return fallback end
	return v
end

local ICON_TALL  = math.Round( CvNumber( cv_icontall,  64 ) )
local TEXT_SCALE = CvNumber( cv_textscale, 1.5 )
local ROW_PITCH  = CvNumber( cv_rowpitch,  1.1 )
local NAME_GAP   = math.Round( 16 * TEXT_SCALE )   -- GMod 是固定 16

-- 名字的字体：surface.SetFont( 方案名 ) 会把方案字体解析成 HFont 并返回（Lua 自建
-- 字体优先、其次方案），拿到那一档的字高后，再按同样的字族建一个放大版的。
local DEATH_SCHEME_FONT = "ChatFont"   -- GMod 的 kill feed 用的就是它
local DEATH_FAMILY      = "Verdana"    -- 方案里 ChatFont 的 "name"
local hSchemeFont = surface.SetFont( DEATH_SCHEME_FONT )
local DEATH_BASE_TALL = 0
if ( hSchemeFont ) then DEATH_BASE_TALL = surface.GetFontTall( hSchemeFont ) end
if ( !DEATH_BASE_TALL or DEATH_BASE_TALL <= 0 ) then DEATH_BASE_TALL = 14 end
local DEATH_TEXT_TALL = math.Round( DEATH_BASE_TALL * TEXT_SCALE )
local DEATH_HFONT = draw.GetFont( DEATH_FAMILY, DEATH_TEXT_TALL, 700 )
local DEATH_TEXT_H = DEATH_TEXT_TALL
if ( DEATH_HFONT ) then DEATH_TEXT_H = surface.GetFontTall( DEATH_HFONT ) end

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
local FONTFLAG_ANTIALIAS = 0x010
local FONTFLAG_ADDITIVE  = 0x100

-- 字高来自 hud_killfeed_icontall（默认 64 = GMod 的图标框；原来的移植写死 20）。
local ICON_FONT = surface.CreateFont()
surface.SetFontGlyphSet( ICON_FONT, ICON_FONT_NAME, ICON_TALL, 0, 0, 0,
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

-- HL2SB: 名字自己画。draw.SimpleText 是按"字族名 + 固定 16px"建字体的
-- （draw.lua 的 GetFont），传方案字体名会被当成字族查 —— 字号既不随分辨率变、
-- 也不是方案里那一档，这正是以前名字偏小的原因。这里直接用解析好的 HFont。
local function DrawName( text, x, y, colour, rightAlign )

	if ( !DEATH_HFONT ) then return end

	local w = surface.GetTextSize( DEATH_HFONT, text )

	surface.DrawSetTextFont( DEATH_HFONT )
	surface.SetTextPos( rightAlign and math.floor( x - w ) or math.floor( x ),
	                    math.floor( y - DEATH_TEXT_H * 0.5 ) )
	surface.SetTextColor( colour.r, colour.g, colour.b, colour.a )
	surface.DrawText( text )

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
		DrawName( death.left, x - ( w / 2 ) - NAME_GAP, y + h / 2, death.color1, true )
	end

	-- Draw VICTIM
	DrawName( death.right, x + ( w / 2 ) + NAME_GAP, y + h / 2, death.color2, false )

	-- 行距：GMod 的公式是 图标高 * 0.75，但我们的名字字号也不小，直接套会让两行
	-- 叠在一起，所以先保证"至少放得下一行名字"，再乘 hud_killfeed_rowpitch 拉开。
	local rowH = math.max( h * 0.75, DEATH_TEXT_H )
	return math.ceil( y + rowH * ROW_PITCH )

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
-- victimIsNPC, killerIsPlayer, weaponClass.
--
-- weaponClass (9th) is the full weapon class name (e.g. "weapon_medkit").
-- Lua SWEPs register their killicon by class name (killicon.Add), while the
-- 3rd argument is HL2MP's mod_textures.txt short name ("death_smg1",
-- "d_skull").  When weaponClass has a killicon of its own it wins.
-- ===========================================================================

-- ===========================================================================
-- HL2SB: names.
--
-- The engine hands the kill feed CLASS NAMES (hud_killfeed.cpp).  For the game's own
-- NPCs Source resolved them through localization ("#npc_zombie" -> "Zombie"), but a
-- Lua NPC has no token, so the feed printed the raw class ("xxx_096"); and a
-- RESKINNED NPC showed the class it inherits from ("combine_s") rather than the name
-- its own script registered ("hutao").
--
-- GMod takes its names from the CONTENT - which is why an addon NPC reads the way its
-- author wrote it - so that is where this looks, in order:
--
--     1. list.Get("NPC")   - what the spawn menu itself shows for that class
--     2. scripted_ents     - the scripted entity's own PrintName
--     3. weapons.Get       - a Lua SWEP's PrintName (killers are often weapons)
--     4. language          - the "#class" token, when it really resolves
--     5. the class itself  - the last resort
-- ===========================================================================
local function LookupDisplayName( class )
	if ( list ~= nil and list.Get ~= nil ) then
		local npcs = list.Get( "NPC" )

		if ( npcs ~= nil ) then
			for _, t in pairs( npcs ) do
				if ( t ~= nil and t.Class == class and t.Name ~= nil and t.Name ~= "" ) then
					return t.Name
				end
			end
		end
	end

	if ( scripted_ents ~= nil and scripted_ents.GetStored ~= nil ) then
		local stored = scripted_ents.GetStored( class )

		if ( stored ~= nil ) then
			local name = ( stored.t ~= nil and stored.t.PrintName ) or stored.PrintName

			if ( name ~= nil and name ~= "" ) then return name end
		end
	end

	if ( weapons ~= nil and weapons.Get ~= nil ) then
		local w = weapons.Get( class )

		if ( w ~= nil and w.PrintName ~= nil and w.PrintName ~= "" ) then return w.PrintName end
	end

	if ( language ~= nil and language.GetPhrase ~= nil ) then
		local phrase = language.GetPhrase( "#" .. class )

		-- an unresolved token comes back as "#class"; that is not a name
		if ( phrase ~= nil and phrase ~= "" and string.sub( phrase, 1, 1 ) ~= "#" ) then
			return phrase
		end
	end

	return nil
end

--- Only CLASS-SHAPED tokens are translated: a player's name ("Player", "Steve") must
--- be drawn exactly as it arrived, and so must anything already human.
local function PrettyName( s )
	-- the shared resolver (lua/autorun/client/hl2sb_displayname.lua) is what the undo
	-- notices use too, so the same class reads the same way in both places.  The local
	-- lookup below stays as the fallback for a build where the module did not load.
	if ( _G.HL2SB_GetDisplayName ~= nil ) then return HL2SB_GetDisplayName( s ) end

	if ( s == nil or s == "" ) then return s end

	local class = s
	if ( string.sub( class, 1, 1 ) == "#" ) then class = string.sub( class, 2 ) end

	if ( string.match( class, "^[%w_]+$" ) == nil ) then return s end

	return LookupDisplayName( class ) or s
end

hook.add( "AddDeathNotice", "gmod_deathnotice", function( attacker, attackerTeam, inflictor,
                                                          victim, victimTeam,
                                                          suicide, victimIsNPC, killerIsPlayer,
                                                          weaponClass )
	attacker = PrettyName( attacker )
	victim   = PrettyName( victim )
	-- Prefer the weapon's own killicon.  The 3rd argument is HL2MP's
	-- mod_textures.txt short name ("death_smg1", "d_skull"); the 9th is the full
	-- weapon class the server put in the event (a Lua SWEP class name), and a Lua SWEP
	-- registers its killicon by class name (killicon.Add) - so when that class
	-- has an icon it wins.  GMod does the same thing: it hands
	-- `inflictor:GetClass()` to AddDeathNotice (player.lua:172 / npc.lua:121).
	if ( not suicide and weaponClass and weaponClass ~= "" and killicon.Exists( weaponClass ) ) then
		inflictor = weaponClass
	end

	-- HL2SB debug (hl2sb_hud_debug 1): what the engine sent and what we will draw,
	-- so "which icon is that" is answerable from the log.  This used to print on
	-- every death and spammed ds_debug.log.
	if ( GetConVarNumber( "hl2sb_hud_debug" ) != 0 ) then
		local w, h = killicon.GetSize( inflictor )
		print( "[KillFeed] engine=" .. tostring( weaponClass ) ..
		       " icon=" .. tostring( inflictor ) ..
		       " size=" .. tostring( w ) .. "x" .. tostring( h ) .. "\n" )
	end
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
