--[[----------------------------------------------------------------------------
    hl2sb_deathnotice.lua

    GMod-style kill feed, Lua implementation for HL2SB.

    Where this file goes matters: the engine only executes
    lua/includes/extensions, lua/includes/modules, lua/game/shared and
    lua/game/client.  There is no autorun folder - lua/autorun/* is never
    loaded - so this lives in lua/game/client/.

    Events arrive through the AddDeathNotice hook, forwarded by
    CHudKillFeed::FireGameEvent() while cl_killfeed_lua is 1:

        AddDeathNotice( attacker, attackerTeam, inflictor,
                        victim, victimTeam,
                        suicide, victimIsNPC, killerIsPlayer )

    The hook fires from the HUD's game-event handler, which runs before
    HudViewportPaint each frame, so an entry added this frame is drawn this
    frame.

    Drawing is done with the raw surface library (a full vgui::ISurface
    binding), so everything below maps 1:1 onto GMod's cl_deathnotice.lua.
----------------------------------------------------------------------------]]

if ( not _CLIENT ) then return end

require( "hook" )
require( "surface" )

local surface = surface
local hook    = hook

local curtime = gpGlobals.curtime
local floor   = math.floor
local max     = math.max
local min     = math.min

-------------------------------------------------------------------------------
-- Tunables
-------------------------------------------------------------------------------
local LIFE            = 6.0     -- seconds an entry stays on screen
local FADE            = 1.2     -- alpha fade applied over the last N seconds
local TOP_FRAC        = 0.06    -- top margin as a fraction of screen height
local RIGHT_FRAC      = 0.02    -- right margin as a fraction of screen width
local TEXT_TALL       = 20      -- name text height
local GLYPH_TALL      = 26      -- death-icon glyph font height
local ICON_TALL       = GLYPH_TALL  -- icon box height (also the row height)
local GAP_ICON        = 14      -- gap between the icon and each name
local ROW_SPACING     = 1.18    -- row pitch as a multiple of icon height
local LERP            = 0.7     -- position smoothing (GMod uses 0.7)

-- Vertical nudge for the kill-icon glyphs, in pixels.  Positive moves the icon
-- DOWN.  The HL2MP/csd death-icon font does not put its ink on the baseline,
-- so baseline alignment alone leaves the glyph sitting above the names; this
-- constant compensates.  Tune it live with:
--     lua_dofile_cl lua/game/client/hl2sb_deathnotice.lua
local ICON_Y_OFFSET   = 2

-- { r, g, b } tables rather than Color objects: the surface calls take plain
-- channels, so there is no need to allocate a Color per row per frame.
local CLR_PLAYER      = { 255, 210, 60 }   -- gold
local CLR_NPC_HOSTILE = { 220,  40, 40 }   -- red
local CLR_NPC_FRIEND  = {  50, 200, 50 }   -- green (GMod's NPC_Color_Friendly)
local CLR_ICON        = { 255,  80,  0 }   -- orange (GMod's icon colour)

-- Set to false to make every NPC red (no friend/enemy split).
local FRIENDLY_NPC_GREEN = true

-- Display names arrive with the "npc_" prefix already stripped by
-- CHudKillFeed's KillFeed_DisplayName(), so these are matched against the
-- remainder ("citizen", "barney", "vortigaunt", ...).
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
	if ( not name or name == "" or not FRIENDLY_NPC_GREEN ) then return false end

	local lower = string.lower( name )
	for key in pairs( FRIENDLY_NPC ) do
		if ( lower == key or string.find( lower, key, 1, true ) ) then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------
-- Fonts
-- FONTFLAG_ANTIALIAS = 0x010, FONTFLAG_ADDITIVE = 0x100
-------------------------------------------------------------------------------
local FLAG_AA_ADD = 0x110

local hText = surface.CreateFont()
surface.SetFontGlyphSet( hText, "Default", TEXT_TALL, 700, 0, 0, 0x010 )

-- The HL2MP / csd death-icon fonts declared in resource/clientscheme.res.
local hGlyph = surface.CreateFont()
surface.SetFontGlyphSet( hGlyph, "HL2MP", GLYPH_TALL, 0, 0, 0, FLAG_AA_ADD )

local hGlyphCS = surface.CreateFont()
surface.SetFontGlyphSet( hGlyphCS, "csd", GLYPH_TALL, 0, 0, 0, FLAG_AA_ADD )

-------------------------------------------------------------------------------
-- Kill icons
-- Mirrors scripts/mod_textures.txt: each death_<weapon> name is a glyph in one
-- of the two additive death fonts.  Names that are missing fall back to the
-- GMod skull texture (hud/killicons/default).
-------------------------------------------------------------------------------
local KILLICON_GLYPH = {
	["death_357"]            = { "/" },
	["death_ar2"]            = { "2" },
	["death_crossbow_bolt"]  = { "1" },
	["death_crossbow"]       = { "1" },
	["death_smg1"]           = { "/" },
	["death_shotgun"]        = { "0" },
	["death_rpg_missile"]    = { "3" },
	["death_rpg"]            = { "3" },
	["death_grenade_frag"]   = { "4" },
	["death_frag"]           = { "4" },
	["death_handgrenade"]    = { "4" },
	["death_pistol"]         = { "-" },
	["death_physics"]        = { "9" },
	["death_physcannon"]     = { "," },
	["death_physgun"]        = { "," },
	["death_combine_ball"]   = { "8" },
	["death_smg1_grenade"]   = { "7" },
	["death_stunstick"]      = { "!" },
	["death_slam"]           = { "*" },
	["death_satchel"]        = { "*" },
	["death_tripmine"]       = { "*" },
	["death_crowbar"]        = { "6" },
}

local SKULL_GLYPH = "C"		-- CSTypeDeathSmall

-- Lazily loaded GMod skull texture.
local iSkullTex = -1
local function SkullTexture()
	if ( iSkullTex == -1 ) then
		iSkullTex = surface.CreateNewTextureID()
		surface.DrawSetTextureFile( iSkullTex, "hud/killicons/default", 1, false )
	end
	return iSkullTex
end

-------------------------------------------------------------------------------
-- The death notice table
-------------------------------------------------------------------------------
local Deaths = {}

local function PlayerColour()      return CLR_PLAYER end
local function NPCHostileColour() return CLR_NPC_HOSTILE end
local function NPCFriendColour()  return CLR_NPC_FRIEND end

-------------------------------------------------------------------------------
-- Low level drawing helpers
--
-- Layout is built right-to-left because the feed is right justified:
--     [ killer ]  gap  [ icon ]  gap  [ victim ]  <- right screen edge
-- Every element is vertically centred on the row, using the real font metrics
-- rather than a hardcoded height.
-------------------------------------------------------------------------------
local function TextWidth( str )
	if ( not str or str == "" ) then return 0 end
	return surface.GetTextSize( hText, str )
end

-- str's right edge lands on x.
local function DrawTextRight( str, x, y, clr, alpha )
	if ( not str or str == "" ) then return end

	surface.DrawSetTextFont( hText )
	surface.DrawSetTextColor( clr[1], clr[2], clr[3], alpha )
	surface.DrawSetTextPos( x - TextWidth( str ), y )
	surface.DrawPrintText( str )
end

-- Width of the icon without drawing it, so the row can be measured first.
local function IconWidth( iconName, useSkull, tall )
	if ( useSkull or not KILLICON_GLYPH[ iconName ] ) then
		return tall, true
	end

	local ch = KILLICON_GLYPH[ iconName ][1]
	local w = surface.GetCharacterWidth( hGlyph, string.byte( ch ) )
	if ( not w or w <= 0 ) then w = tall * 0.6 end
	return w, false
end

-- x is the icon's left edge; yText is the row's text top.
local function DrawIcon( iconName, useSkull, x, yText, tall, alpha )
	local w, bSkull = IconWidth( iconName, useSkull, tall )

	if ( bSkull ) then
		-- Square texture: centre it on the text line.
		local textTall = surface.GetFontTall( hText )
		local yIcon = yText + ( textTall - tall ) * 0.5
		surface.DrawSetTexture( SkullTexture() )
		surface.DrawSetColor( CLR_ICON[1], CLR_ICON[2], CLR_ICON[3], alpha )
		surface.DrawTexturedRect( x, yIcon, x + tall, yIcon + tall )
		return w
	end

	local ch = KILLICON_GLYPH[ iconName ][1]
	surface.DrawSetTextFont( hGlyph )
	surface.DrawSetTextColor( CLR_ICON[1], CLR_ICON[2], CLR_ICON[3], alpha )

	-- Baseline alignment, plus a manual nudge because the icon font's ink does
	-- not sit on the baseline.  DrawSetTextPos takes the TOP of the text box,
	-- so the glyph goes at (text baseline - glyph ascent) + ICON_Y_OFFSET.
	local textAscent  = surface.GetFontAscent( hText, "A" )
	local glyphAscent = surface.GetFontAscent( hGlyph, ch )
	surface.DrawSetTextPos( x, yText + textAscent - glyphAscent + ICON_Y_OFFSET )
	surface.DrawPrintText( ch )

	return w
end

-------------------------------------------------------------------------------
-- One row: <killer>  <icon>  <victim>, right justified.
-- Returns the y of the next row.
--
-- Every element is positioned by its RIGHT edge, which is what DrawTextRight
-- expects, and each element's own measured width is subtracted exactly once.
-------------------------------------------------------------------------------
local nRowLog = 0

local function DrawRow( x, y, d, life )
	local fadeLeft = ( d.time + life ) - curtime()
	local alpha = floor( max( 0, min( 255, fadeLeft * ( 255 / FADE ) ) ) )
	if ( alpha <= 0 ) then return y + ICON_TALL * ROW_SPACING end

	local textTall = surface.GetFontTall( hText )
	local wVictim  = TextWidth( d.right )
	local wKiller  = TextWidth( d.left )
	local wIcon    = IconWidth( d.icon, d.useSkull, ICON_TALL )

	-- Right-to-left from the right margin.
	local xVictimRight = x
	local xIconRight   = xVictimRight - wVictim - GAP_ICON
	local xIconLeft    = xIconRight - wIcon
	local xKillerRight = xIconLeft - GAP_ICON

	local yText = y + ( ICON_TALL - textTall ) * 0.5

	-- Geometry dump for the first few rows, to compare the computed layout
	-- against what actually appears on screen.
	if ( nRowLog < 3 ) then
		nRowLog = nRowLog + 1
		print( string.format(
			"[HL2SB] row%d  '%s' -> '%s'\n" ..
			"    wKiller=%d wIcon=%d wVictim=%d\n" ..
			"    killer  x=%d..%d\n" ..
			"    icon    x=%d..%d\n" ..
			"    victim  x=%d..%d\n",
			nRowLog, tostring( d.left ), tostring( d.right ),
			wKiller, wIcon, wVictim,
			xKillerRight - wKiller, xKillerRight,
			xIconLeft, xIconLeft + wIcon,
			xVictimRight - wVictim, xVictimRight ) )
	end

	DrawTextRight( d.left,  xKillerRight, yText, d.killerColour, alpha )
	DrawIcon(      d.icon,  d.useSkull, xIconLeft, yText, ICON_TALL, alpha )
	DrawTextRight( d.right, xVictimRight, yText, d.victimColour, alpha )

	return y + ICON_TALL * ROW_SPACING
end


-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
hook.add( "AddDeathNotice", "hl2sb_deathnotice", function( attacker, attackerTeam, inflictor,
                                                          victim, victimTeam,
                                                          suicide, victimIsNPC, killerIsPlayer )
	if ( suicide ) then attacker = nil end

	local d = {}
	d.time     = curtime()
	d.left     = attacker
	d.right    = victim or ""
	d.icon     = inflictor or ""
	d.useSkull = ( suicide == true ) or ( attacker == nil ) or ( not KILLICON_GLYPH[ d.icon ] )

	-- Players are always gold.  NPCs are red, except friendly ones which are
	-- green while FRIENDLY_NPC_GREEN is on.
	if ( killerIsPlayer == true ) then
		d.killerColour = PlayerColour()
	elseif ( IsFriendlyNPC( attacker ) ) then
		d.killerColour = NPCFriendColour()
	else
		d.killerColour = NPCHostileColour()
	end

	if ( victimIsNPC == true ) then
		d.victimColour = IsFriendlyNPC( victim ) and NPCFriendColour() or NPCHostileColour()
	else
		d.victimColour = PlayerColour()
	end

	table.insert( Deaths, d )
end )

-------------------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------------------
local bLoggedFirstDraw = false
local bLoggedMetrics   = false

hook.add( "HudViewportPaint", "hl2sb_deathnotice", function()
	if ( #Deaths == 0 ) then return end

	if ( not bLoggedFirstDraw ) then
		bLoggedFirstDraw = true
		print( "[HL2SB] kill feed: HudViewportPaint reached, first Lua draw\n" )
	end

	-- One-shot font metric dump.  GetTextSize() used to measure an
	-- uninitialised buffer, so this is the quickest way to confirm the binding
	-- returns real widths (roughly 8-10 px per character at this size).
	if ( not bLoggedMetrics ) then
		bLoggedMetrics = true
		local sw, sh = surface.GetScreenSize()
		local w1, h1 = surface.GetTextSize( hText, "hut" )
		local w2, h2 = surface.GetTextSize( hText, "Vortigaunt" )
		local w3, h3 = surface.GetTextSize( hText, "i" )
		local tallText  = surface.GetFontTall( hText )
		local tallGlyph = surface.GetFontTall( hGlyph )
		local ascText   = surface.GetFontAscent( hText, "A" )
		local ascGlyph  = surface.GetFontAscent( hGlyph, "/" )
		local yText     = ( ICON_TALL - tallText ) * 0.5
		print( string.format(
			"[HL2SB] kill feed metrics: screen=%dx%d\n" ..
			"    text:  tall=%d ascent=%d   'i'=%dx%d 'hut'=%dx%d 'Vortigaunt'=%dx%d\n" ..
			"    glyph: tall=%d ascent=%d   ICON_TALL=%d  ICON_Y_OFFSET=%d\n" ..
			"    row:   yText=+%.1f  glyphY=+%.1f\n",
			sw, sh,
			tallText, ascText, w3, h3, w1, h1, w2, h2,
			tallGlyph, ascGlyph, ICON_TALL, ICON_Y_OFFSET,
			yText, yText + ascText - ascGlyph + ICON_Y_OFFSET ) )
	end

	local sw, sh = surface.GetScreenSize()
	local x = sw - sw * RIGHT_FRAC
	local y = sh * TOP_FRAC

	local life = LIFE
	local allExpired = true

	for i = 1, #Deaths do
		local d = Deaths[i]

		if ( d.time + life > curtime() ) then
			allExpired = false

			-- Smooth the anchor so a new entry slides in instead of jumping
			-- (GMod lerps x/y against the previous frame's value).
			if ( d.lerp ) then
				x = x * ( 1 - LERP ) + d.lerp.x * LERP
				y = y * ( 1 - LERP ) + d.lerp.y * LERP
			end

			d.lerp = d.lerp or {}
			d.lerp.x = x
			d.lerp.y = y

			y = DrawRow( floor( x ), floor( y ), d, life )
		end
	end

	-- Same as GMod: keep the table until everything has expired so surviving
	-- rows do not jump upwards when one entry in the middle times out.
	if ( allExpired ) then
		Deaths = {}
	end
end )

-------------------------------------------------------------------------------
-- Load marker.  This is the line to look for in the console / ds_debug.log to
-- confirm the file was executed and both hooks registered.
-------------------------------------------------------------------------------
print( "[HL2SB] hl2sb_deathnotice.lua loaded (GMod-style kill feed)\n" )
