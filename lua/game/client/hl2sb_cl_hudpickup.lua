--[[---------------------------------------------------------------------------
    HL2SB pickup notification - Garry's Mod's gamemodes/base/gamemode/
    cl_hudpickup.lua, ported with the smallest possible diff.

    GMod's bar: a rounded strip that slides in from the right edge, holds for
    five seconds and fades out.  The left tab carries the type colour
    (weapon = orange, item = green, ammo = blue), the name sits next to it and
    the amount is right-aligned.  Consecutive pickups of the same ammo type are
    merged into the existing card instead of stacking.

    Same gamemode API as GMod, so gamemodes can override any of it:
        GM.PickupHistory / GM.PickupHistoryLast / GM.PickupHistoryTop
        GM.PickupHistoryWide / GM.PickupHistoryCorner
        GM:HUDWeaponPickedUp( wep )
        GM:HUDItemPickedUp( itemname )
        GM:HUDAmmoPickedUp( itemname, amount )
        GM:HUDDrawPickupHistory()

    Differences from GMod's file, all "HL2SB:" marked:
      * GM           -> _G._GAMEMODE (the engine's gamemode table; created if
                        the gamemode has not registered itself yet).
      * corners      -> NONE ANY MORE.  This used to approximate the strip with
                        two draw.RoundedBox calls because Source 2013's
                        vgui::ISurface had no rotated textured rect.  HL2SB's
                        binding layer now provides
                        surface.DrawTexturedRectRotated (built on
                        ISurface::DrawTexturedPolygon -- see
                        public/lua/vgui/LISurface.cpp), so the drawing block
                        below is GMod's, verbatim.
      * fonts        -> NONE ANY MORE.  GMod names its HUD font
                        "DermaDefaultBold"; that font is now created at load
                        through the GMod form of surface.CreateFont
                        (lua/includes/modules/gmod_vgui.lua), so the name
                        resolves here exactly as it does in GMod.
      * localization -> GMod draws "#item_battery" and lets the engine resolve
                        the token; HL2SB's surface.DrawPrintText does not, so
                        LocalName() resolves it up front.
      * input        -> GMod's CHudHistoryResource calls GM:HUD*PickedUp.
                        HL2SB's CHudKillFeed forwards the engine's item_pickup
                        game event to the Lua hook HUDItemPickedUp( userid,
                        item, amount ); the dispatcher at the bottom sorts that
                        into the three GMod gamemode methods.

    Path: lua/game/client/hl2sb_cl_hudpickup.lua
-----------------------------------------------------------------------------]]

if ( not _CLIENT ) then return end

require( "hook" )
require( "draw" )
require( "math" )     -- HL2SB math extension (Round / Clamp)

local draw    = draw
local hook    = hook
local math    = math
local surface = surface
local Color   = Color
local CurTime = CurTime
local ScrW    = ScrW
local ScrH    = ScrH
local LocalPlayer = LocalPlayer

-- HL2SB: the engine's gamemode table.
local GM = _G._GAMEMODE
if ( GM == nil ) then
	GM = {}
	_G._GAMEMODE = GM
end
_G.GAMEMODE = _G.GAMEMODE or GM

-- ---------------------------------------------------------------------------
-- HL2SB: token -> display text.
--
-- GMod's cl_hudpickup names things "#item_battery" / "#Pistol_ammo" and lets the
-- engine resolve the token while drawing.  HL2SB's surface.DrawPrintText does
-- NOT resolve tokens (it only converts ANSI to Unicode), so the literal
-- "#item_battery" was being rendered on screen.
--
-- Resolve through the engine's localization table (Localizations.Find is
-- g_pVGuiLocalize->Find, llocalization.cpp), then language.GetPhrase, then fall
-- back to a readable form of the class name so a missing token still looks sane.
-- ---------------------------------------------------------------------------
local function LocalName( raw )
	if ( type( raw ) ~= "string" ) then return tostring( raw ) end

	local key = raw
	if ( key:sub( 1, 1 ) == "#" ) then key = key:sub( 2 ) end

	if ( _G.Localizations ~= nil and _G.Localizations.Find ~= nil ) then
		-- Source's Find() accepts the token with or without the leading '#'.
		for _, tok in ipairs( { "#" .. key, key } ) do
			local ok, txt = pcall( _G.Localizations.Find, tok )
			if ( ok and type( txt ) == "string" and txt ~= ""
			     and txt ~= tok and txt ~= key ) then
				return txt
			end
		end
	end

	if ( _G.language ~= nil and _G.language.GetPhrase ~= nil ) then
		local ok, txt = pcall( _G.language.GetPhrase, key )
		if ( ok and type( txt ) == "string" and txt ~= "" and txt ~= key ) then
			return txt
		end
	end

	-- Readable fallback -- HL2 class names are close enough to English:
	--   "item_battery"        -> "Battery"
	--   "weapon_pist_weagon"  -> "Pist weagon"
	--   "SMG1_grenade_ammo"   -> "SMG1 grenade ammo"
	local s = key:gsub( "^weapon_", "" ):gsub( "^item_", "" ):gsub( "_", " " )
	return ( s:gsub( "^%l", string.upper ) )
end

-- HL2SB: GMod names its HUD font "DermaDefaultBold".  That font is created at
-- load time the same way GMod does it (surface.CreateFont with the FontData
-- table -- see lua/includes/modules/gmod_vgui.lua), so the name resolves through
-- surface.SetFont exactly as it does in GMod.  Should it ever fail to resolve,
-- surface.SetFont falls back to the scheme's Default by itself.
local function Font( name )
	return name
end

-- HL2SB: GMod's cl_hudpickup calls LocalPlayer():Alive().  The alias is not
-- reliably present on the client's player metatable here, so resolve it by hand
-- -- otherwise every pickup hook failed with "attempt to call a nil value
-- (method 'Alive')" and nothing was ever drawn.
local function LocalAlive()
	local ply = LocalPlayer()
	if ( not IsValid( ply ) ) then return false end
	if ( isfunction( ply.Alive ) ) then return ply:Alive() end
	if ( isfunction( ply.IsAlive ) ) then return ply:IsAlive() end
	return true
end

-- ===========================================================================
-- HL2SB debug: hl2sb_hud_debug 1
--
-- Both HUDs in this file and in hl2sb_undo_notify.lua were silently invisible
-- once already, and "nothing drawn" has three very different causes: the event
-- never arrives, it arrives and is filtered out, or it arrives and the draw is
-- skipped.  A single cvar separates them from the log:
--
--     hl2sb_hud_debug 1
--
-- prints one line per event.  Off by default; no cost when off beyond one
-- convar lookup per event (not per frame).
-- ===========================================================================
if ( HL2SB_HUDDebug == nil ) then
	-- The convar has to be CREATED, not merely read.  Reading a name that was
	-- never registered returns 0 (so the debug stayed silent) and the console
	-- answered "Unknown command: hl2sb_hud_debug" -- which is exactly what
	-- happened the first time this shipped.
	local HUDDebugCvar = nil
	if ( CreateClientConVar ) then
		HUDDebugCvar = CreateClientConVar( "hl2sb_hud_debug", "0", false, false,
			"Print pickup / undo HUD events to the console and log (1 = on)" )
	end

	function HL2SB_HUDDebug( ... )
		local bOn
		if ( HUDDebugCvar ) then
			bOn = HUDDebugCvar:GetBool()
		else
			bOn = ( GetConVarNumber( "hl2sb_hud_debug" ) ~= 0 )
		end
		if ( not bOn ) then return end

		local out = {}
		for i = 1, select( "#", ... ) do out[ i ] = tostring( ( select( i, ... ) ) ) end

		Msg( "[HL2SB HUD] " .. table.concat( out, " " ) .. "\n" )
	end
end

-- HL2SB: hide the stock HL2MP pickup-history element (the battery / weapon
-- circle icons) so the GMod bar is the only pickup feedback.  Returning nil for
-- every other element lets the engine's own ShouldDraw logic run.
hook.add( "HudElementShouldDraw", "gmod_cl_hudpickup", function( name )
	if ( name == "CHudHistoryResource" ) then return false end
	return nil
end )

GM.PickupHistory = GM.PickupHistory or {}
GM.PickupHistoryLast = 0
GM.PickupHistoryTop = ScrH() / 2
GM.PickupHistoryWide = 300
-- GMod: GM.PickupHistoryCorner = surface.GetTextureID( "gui/corner8" ).
GM.PickupHistoryCorner = GM.PickupHistoryCorner or surface.GetTextureID( "gui/corner8" )

local function AddGenericPickup( self, itemname )
	local pickup		= {}
	pickup.time			= CurTime()
	pickup.name			= itemname                  -- raw, used by the ammo merge below
	pickup.text			= LocalName( itemname )      -- what actually gets drawn
	pickup.holdtime		= 5
	pickup.font			= Font( "DermaDefaultBold" )
	pickup.fadein		= 0.04
	pickup.fadeout		= 0.3

	local hfont = draw.GetFont( pickup.font )
	local w, h = surface.GetTextSize( hfont, tostring( pickup.text ) )
	pickup.height		= h
	pickup.width		= w

	table.insert( self.PickupHistory, pickup )
	self.PickupHistoryLast = pickup.time

	HL2SB_HUDDebug( "pickup queued:", tostring( pickup.name ), "holdtime=" .. tostring( pickup.holdtime ), "entries=" .. tostring( #self.PickupHistory ) )

	return pickup
end

--[[---------------------------------------------------------
	Name: gamemode:HUDWeaponPickedUp( wep )
	Desc: The game wants you to draw on the HUD that a weapon has been picked up
-----------------------------------------------------------]]
function GM:HUDWeaponPickedUp( wep )

	if ( not LocalAlive() ) then
		-- HL2SB: this was a silent return, and it is the last gate before an
		-- entry is queued -- so "hook fired, queued nothing, printed nothing"
		-- meant either LocalPlayer() is invalid or Alive() is false.  Say which.
		local ply = LocalPlayer()
		HL2SB_HUDDebug( "  -> dropped: LocalAlive() false",
			"LocalPlayer()=" .. tostring( ply ),
			"IsValid=" .. tostring( IsValid( ply ) ),
			"Alive=" .. tostring( isfunction( ply and ply.Alive ) and ply:Alive() ),
			"IsAlive=" .. tostring( isfunction( ply and ply.IsAlive ) and ply:IsAlive() ) )
		return
	end
	if ( wep == nil ) then return end

	local name = wep
	if ( type( wep ) ~= "string" and IsValid( wep ) and isfunction( wep.GetPrintName ) ) then
		name = wep:GetPrintName()
	end

	local pickup = AddGenericPickup( self, name )
	pickup.color = Color( 255, 200, 50, 255 )

end

--[[---------------------------------------------------------
	Name: gamemode:HUDItemPickedUp( itemname )
	Desc: An item has been picked up..
-----------------------------------------------------------]]
function GM:HUDItemPickedUp( itemname )

	if ( not LocalAlive() ) then
		-- HL2SB: this was a silent return, and it is the last gate before an
		-- entry is queued -- so "hook fired, queued nothing, printed nothing"
		-- meant either LocalPlayer() is invalid or Alive() is false.  Say which.
		local ply = LocalPlayer()
		HL2SB_HUDDebug( "  -> dropped: LocalAlive() false",
			"LocalPlayer()=" .. tostring( ply ),
			"IsValid=" .. tostring( IsValid( ply ) ),
			"Alive=" .. tostring( isfunction( ply and ply.Alive ) and ply:Alive() ),
			"IsAlive=" .. tostring( isfunction( ply and ply.IsAlive ) and ply:IsAlive() ) )
		return
	end

	local pickup = AddGenericPickup( self, "#" .. itemname )
	pickup.color = Color( 180, 255, 180, 255 )

end

--[[---------------------------------------------------------
	Name: gamemode:HUDAmmoPickedUp( itemname, amount )
	Desc: Ammo has been picked up..
-----------------------------------------------------------]]
function GM:HUDAmmoPickedUp( itemname, amount )

	if ( not LocalAlive() ) then
		-- HL2SB: this was a silent return, and it is the last gate before an
		-- entry is queued -- so "hook fired, queued nothing, printed nothing"
		-- meant either LocalPlayer() is invalid or Alive() is false.  Say which.
		local ply = LocalPlayer()
		HL2SB_HUDDebug( "  -> dropped: LocalAlive() false",
			"LocalPlayer()=" .. tostring( ply ),
			"IsValid=" .. tostring( IsValid( ply ) ),
			"Alive=" .. tostring( isfunction( ply and ply.Alive ) and ply:Alive() ),
			"IsAlive=" .. tostring( isfunction( ply and ply.IsAlive ) and ply:IsAlive() ) )
		return
	end

	-- Try to tack it onto an exisiting ammo pickup
	if ( self.PickupHistory ) then

		for k, v in pairs( self.PickupHistory ) do

			if ( v.name == "#" .. itemname .. "_ammo" ) then

				v.amount = tostring( tonumber( v.amount ) + amount )
				v.time = CurTime() - v.fadein
				return

			end

		end

	end

	local pickup = AddGenericPickup( self, "#" .. itemname .. "_ammo" )
	pickup.color = Color( 180, 200, 255, 255 )
	pickup.amount = tostring( amount )

	local hfont = draw.GetFont( pickup.font )
	local w, h = surface.GetTextSize( hfont, tostring( pickup.amount ) )
	pickup.width = pickup.width + w + 16

end

function GM:HUDDrawPickupHistory()

	if ( self.PickupHistory == nil ) then return end

	local x, y = ScrW() - self.PickupHistoryWide - 20, self.PickupHistoryTop
	local tall = 0
	local wide = 0

	for k, v in pairs( self.PickupHistory ) do

		if ( !istable( v ) ) then

			-- HL2SB: GMod's Msg() / PrintTable() do not exist here; calling them
			-- threw and hook.Run() then unregistered this hook for good.
			print( "[HL2SB] pickup history: dropping non-table entry " .. tostring( v ) )
			self.PickupHistory[ k ] = nil
			return

		end

		if ( v.time < CurTime() ) then

			if ( v.y == nil ) then v.y = y end

			v.y = ( v.y * 5 + y ) / 6

			local delta = ( v.time + v.holdtime ) - CurTime()
			delta = delta / v.holdtime

			local alpha = 255
			local colordelta = math.Clamp( delta, 0.6, 0.7 )

			-- Fade in/out
			if ( delta > 1 - v.fadein ) then
				alpha = math.Clamp( ( 1.0 - delta ) * ( 255 / v.fadein ), 0, 255 )
			elseif ( delta < v.fadeout ) then
				alpha = math.Clamp( delta * ( 255 / v.fadeout ), 0, 255 )
			end

			v.x = x + self.PickupHistoryWide - ( self.PickupHistoryWide * ( alpha / 255 ) )

			local rx, ry, rw, rh = math.Round( v.x - 4 ), math.Round( v.y - ( v.height / 2 ) - 4 ), math.Round( self.PickupHistoryWide + 9 ), math.Round( v.height + 8 )
			local bordersize = 8

			-- GMod's strip, verbatim: four rotated blits of gui/corner8 plus
			-- four flat runs.  HL2SB now has surface.DrawTexturedRectRotated
			-- (LISurface.cpp, built on ISurface::DrawTexturedPolygon), so this
			-- no longer has to be faked with two RoundedBoxes.
			surface.SetTexture( self.PickupHistoryCorner )

			surface.SetDrawColor( v.color.r, v.color.g, v.color.b, alpha )
			surface.DrawTexturedRectRotated( rx + bordersize / 2, ry + bordersize / 2, bordersize, bordersize, 0 )
			surface.DrawTexturedRectRotated( rx + bordersize / 2, ry + rh - bordersize / 2, bordersize, bordersize, 90 )
			surface.DrawRect( rx, ry + bordersize, bordersize, rh - bordersize * 2 )
			surface.DrawRect( rx + bordersize, ry, v.height - 4, rh )

			surface.SetDrawColor( 230 * colordelta, 230 * colordelta, 230 * colordelta, alpha )
			surface.DrawTexturedRectRotated( rx + rw - bordersize / 2, ry + rh - bordersize / 2, bordersize, bordersize, 180 )
			surface.DrawTexturedRectRotated( rx + rw - bordersize / 2, ry + bordersize / 2, bordersize, bordersize, 270 )
			surface.DrawRect( rx + rw - bordersize, ry + bordersize, bordersize, rh - bordersize * 2 )
			surface.DrawRect( rx + bordersize + v.height - 4, ry, rw - ( v.height - 4 ) - bordersize * 2, rh )

			-- HL2SB: v.text is the localized form of v.name (see LocalName).
			-- GMod renders "#item_battery" and lets the engine resolve it; we
			-- resolve it up front, because surface.DrawPrintText does not.
			local label = v.text or v.name

			draw.SimpleText( label, v.font, v.x + v.height + 9, ry + ( rh / 2 ) + 1, Color( 0, 0, 0, alpha * 0.5 ), draw.TEXT_ALIGN_LEFT, draw.TEXT_ALIGN_CENTER )
			draw.SimpleText( label, v.font, v.x + v.height + 8, ry + ( rh / 2 ), Color( 255, 255, 255, alpha ), draw.TEXT_ALIGN_LEFT, draw.TEXT_ALIGN_CENTER )

			if ( v.amount ) then

				draw.SimpleText( v.amount, v.font, v.x + self.PickupHistoryWide + 1, ry + ( rh / 2 ) + 1, Color( 0, 0, 0, alpha * 0.5 ), draw.TEXT_ALIGN_RIGHT, draw.TEXT_ALIGN_CENTER )
				draw.SimpleText( v.amount, v.font, v.x + self.PickupHistoryWide, ry + ( rh / 2 ), Color( 255, 255, 255, alpha ), draw.TEXT_ALIGN_RIGHT, draw.TEXT_ALIGN_CENTER )

			end

			y = y + ( v.height + 16 )
			tall = tall + v.height + 18
			wide = math.max( wide, v.width + v.height + 24 )

			if ( alpha == 0 ) then self.PickupHistory[ k ] = nil end

		end

	end

	self.PickupHistoryTop = ( self.PickupHistoryTop * 5 + ( ScrH() * 0.75 - tall ) / 2 ) / 6
	self.PickupHistoryWide = ( self.PickupHistoryWide * 5 + wide ) / 6

end

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------

-- GMod's cl_init.lua runs this from GM:HUDPaint; HL2SB's equivalent per-frame
-- client callback is HudViewportPaint.
--
-- HL2SB: the drawer is invoked DIRECTLY here instead of through
-- hook.Run("HUDDrawPickupHistory").  hook.Run silently does nothing when the
-- event has no hooks, and the pickup strip never appeared while every other
-- part of this file (event hooks, entries, colours) demonstrably worked -- so
-- the HUD must not depend on that second lookup.  The named hook is still
-- registered below, so addons that fire "HUDDrawPickupHistory" reach the same
-- drawer.
-- HL2SB: one-shot proof that the HudViewportPaint hook is being called at all.
--
-- Every GMod-style HUD in this project (pickup, undo notification, death
-- notice) draws from HudViewportPaint, while the engine-driven hooks
-- (HUDItemPickedUp, HudElementShouldDraw) demonstrably DO reach Lua.  "Nothing
-- draws, but engine hooks work" is therefore either "this hook never fires"
-- (a C++ viewport problem -- cs_scriptedhudviewport) or "it fires and the draw
-- is skipped".  This line separates the two; with hl2sb_hud_debug 1 and no
-- such line in the log, the hook is not firing.
local bFirstViewportPaint = false

hook.add( "HudViewportPaint", "gmod_cl_hudpickup", function()
	if ( not bFirstViewportPaint ) then
		bFirstViewportPaint = true
		HL2SB_HUDDebug( "HudViewportPaint: fired (first call)" )
	end

	GM:HUDDrawPickupHistory()
end )

-- Make GM:HUDDrawPickupHistory reachable through hook.Run as well, so addons
-- that hook "HUDDrawPickupHistory" get called like they do in GMod.
hook.Add( "HUDDrawPickupHistory", "gmod_cl_hudpickup", function()
	return GM:HUDDrawPickupHistory()
end )

-- GMod's CHudHistoryResource drives the three gamemode methods.  HL2SB forwards
-- the engine's item_pickup game event to this hook as ( userid, item, amount );
-- sort it into the GMod methods.
hook.add( "HUDItemPickedUp", "gmod_cl_hudpickup", function( userid, item, amount )
	HL2SB_HUDDebug( "HUDItemPickedUp:", "userid=" .. tostring( userid ), "item=" .. tostring( item ), "amount=" .. tostring( amount ) )

	-- HL2SB: the player method is UniqueID() (= GetUserID); GMod's Player:UserID()
	-- does not exist here, and calling it made this hook fail on every pickup,
	-- so the notification never drew at all.
	-- HL2SB: UniqueID() must exist on the CLIENT for this to work -- it used to be
	-- a server-only binding, so this line threw "attempt to call a nil value
	-- (method 'UniqueID')" on every pickup and hook.lua then unregistered us for
	-- the rest of the level.  Now bound in game/client/lua/lc_baseplayer.cpp.
	if ( userid and IsValid( LocalPlayer() ) and LocalPlayer():UniqueID() != userid ) then
		HL2SB_HUDDebug( "  -> dropped: not the local player" )
		return
	end
	if ( item == nil or item == "" ) then
		HL2SB_HUDDebug( "  -> dropped: empty item name" )
		return
	end

	local low = string.lower( item )

	-- Ammo arrives as "<ammoname>_ammo"; GMod's HUDAmmoPickedUp wants the bare
	-- ammo name and appends the suffix itself.
	if ( string.sub( low, -5 ) == "_ammo" ) then
		GM:HUDAmmoPickedUp( string.sub( item, 1, #item - 5 ), tonumber( amount ) or 0 )
		return
	end

	if ( string.sub( low, 1, 7 ) == "weapon_" ) then
		-- GMod passes the weapon entity.  HL2SB's item_pickup event only
		-- carries the class name (and there is no GetWeapons() binding), so use
		-- the active weapon when it matches -- a freshly picked up weapon is
		-- normally the one being deployed -- and fall back to the class name.
		local wep = nil
		if ( IsValid( LocalPlayer() ) ) then
			local active = LocalPlayer():GetActiveWeapon()
			if ( IsValid( active ) and active:GetClass() == item ) then
				wep = active
			end
		end

		GM:HUDWeaponPickedUp( wep or item )
		return
	end

	GM:HUDItemPickedUp( item )
end )

print( "[HL2SB] hl2sb_cl_hudpickup.lua loaded (GMod cl_hudpickup)" )
