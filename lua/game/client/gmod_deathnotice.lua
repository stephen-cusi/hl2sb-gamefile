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

      3. Fonts / sizes (2026-09-29 GMod-parity pass).  GMod draws the names
         with the scheme "ChatFont" at its NATIVE yres-banded height (17px at
         1080p, 22 at 1200+, dropshadow) through draw.SimpleText ->
         surface.SetFont, and the icon glyphs at the native 64px
         "HL2MPTypeDeath" face, rows at icon_h*0.75, names 16px clear of the
         icon.  Our surface measures scheme fonts but cannot render them, so
         both faces are rebuilt with surface.CreateFont at EXACTLY those
         sizes/flags (see DEATH_HFONT / ICON_FONT).  The previous port scaled
         names x1.5, boosted the glyph ink to 48px and padded rows - all
         removed; no tuning convars remain.

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
-- HL2SB: 击杀播报尺寸 = GMod 真实渲染链（2026-09-29 对照 + 方案核对定案）。
--
-- GMod 的绘制（gamemodes/base/gamemode/cl_deathnotice.lua）：
--   名字   draw.SimpleText(..., "ChatFont") -> surface.SetFont 走方案字体
--          原生分档高度（GMod ClientScheme.res：1024-1199 tall=17、
--          1200+ tall=22，dropshadow=1），没有任何缩放；
--   图标   字体类图标 = 方案 "HL2MPTypeDeath"（HL2MP 字族、tall 64、
--          weight 0、antialias+additive）原生字形；材质类图标
--          adj_h = 64*0.75 = 48px（killicon.lua 本 fork 与 GMod 同款）；
--   行距   y + 图标框 h * 0.75（GMod DrawDeath 原式）；
--   间距   名字与图标左右各固定 16px。
--
-- 旧实现的三处偏离（就是用户报的"大小问题"）已全部移除：
--   * 名字 ×1.5 缩放（1080p 方案 20px 被画成 30px）
--   * 图标字形 ink 放大到 48px（GMod 就是 64px 字号的原生 ink）
--   * 行距 max(h*0.75, 文字高)*1.1、间距 round(16*1.5)=24px
-- 三个调优 convar（icontall/textscale/rowpitch）一并删除：值不在 config.cfg
-- 里，代码默认值即生效，留着只会让下次调参又偏离 GMod。
--
-- 名字字体：本 fork 的 scheme 字体只能测量、不能经 surface 文本路径渲染
-- （draw.lua 注释），所以 surface.CreateFont 复刻 ChatFont 的全部参数
-- （家族/当前分档高度/weight700/dropshadow），字号取方案实测值不再放大。
-- ===========================================================================
local DEATH_SCHEME_FONT = "ChatFont"         -- GMod 的 kill feed 用的就是它
local DEATH_FAMILY      = "Microsoft YaHei"  -- 方案里 ChatFont 的 "name"
local FONTFLAG_DROPSHADOW = 0x080            -- ISurface.h; 方案 ChatFont dropshadow=1

local hSchemeFont = surface.SetFont( DEATH_SCHEME_FONT )
local DEATH_BASE_TALL = 0
if ( hSchemeFont ) then DEATH_BASE_TALL = surface.GetFontTall( hSchemeFont ) end
if ( !DEATH_BASE_TALL or DEATH_BASE_TALL <= 0 ) then DEATH_BASE_TALL = 16 end

local DEATH_HFONT = surface.CreateFont()
surface.SetFontGlyphSet( DEATH_HFONT, DEATH_FAMILY, DEATH_BASE_TALL, 700, 0, 0,
                         FONTFLAG_DROPSHADOW )
local DEATH_TEXT_H = surface.GetFontTall( DEATH_HFONT )

local NAME_GAP = 16   -- GMod 是固定 16px

-- HL2SB: the kill icon glyphs.
--
-- GMod passes the *name* of a scheme font ("HL2MPTypeDeath") to
-- surface.SetFont and draws the glyph natively at that size.  Our surface can
-- measure scheme fonts but cannot render them through the text path (see
-- draw.lua), so the face is rebuilt with surface.CreateFont +
-- SetFontGlyphSet using the scheme block's exact parameters (resource/
-- clientscheme.res "HL2MPTypeDeath": name HL2MP, tall 64, weight 0,
-- antialias 1, additive 1).
--
-- The old port boosted the glyph size until its ink reached 48px so engine
-- and Lua-weapon icons lined up - an intentional deviation from GMod and one
-- of the size mismatches reported 2026-09-29; removed.  Both icon kinds now
-- render exactly as GMod does (font glyphs at the 64px face, material icons
-- equalised by killicon.lua to 64*0.75=48px, same as GMod).
--
-- FONTFLAG_ANTIALIAS | FONTFLAG_ADDITIVE = 0x110: the death fonts are
-- additive by design (scheme marks them "additive" "1").
local ICON_FONT_NAME = "HL2MP"     -- resource/hl2mp.ttf, the weapon pictograms
local FONTFLAG_ANTIALIAS = 0x010
local FONTFLAG_ADDITIVE  = 0x100
local ICON_TALL = 64               -- scheme HL2MPTypeDeath tall (GMod identical)

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
	-- reskin packs name their entries "... - Friendly" / "... - Hostile"; the
	-- feed now receives the DISPLAY name (the entity's targetname), so match
	-- the word too -- without it a friendly reskin fed red
	["friendly"]   = true,
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
	-- deaths cannot stack an unreadable column.  Fallback 0 = unlimited = GMod
	-- (its Deaths table is never capped); config.cfg pins 0 too.
	local iMax = hud_killfeed_max and hud_killfeed_max:GetInt() or 0
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

	-- 行距 = GMod 原式：图标框 h * 0.75（名字 ChatFont 原生高度本来就画在
	-- 图标框里，不会叠行——2026-09-29 对齐后不再需要 max/rowpitch 补偿）。
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
