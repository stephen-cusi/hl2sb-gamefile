-- Shared Lua bootstrap and original Derma/VGUI initialization.

include( "util.lua" )

-- HL2SB: util/sql.lua -- GMod's own bootstrap loads this immediately after
-- util.lua (its lua/includes/init.lua lines 6-7), and this fork never did.  The
-- file has been sitting in lua/includes/util/ the whole time, byte-identical to
-- GMod's, defining exactly what was missing:
--
--     line  9  sql.SQLStr
--     line 27  SQLStr = sql.SQLStr          <-- the BARE GLOBAL
--     line 33  sql.TableExists
--     line 44  sql.IndexExists
--     line 56  sql.QueryRow
--     line 72  sql.QueryValue
--     line 91  sql.Begin   /  line 99 sql.Commit
--     line 107 sql.LastError
--
-- Without it, modules/cookie.lua:27 died on
--     attempt to call a nil value (global 'SQLStr')
-- the first time the spawnmenu called SetCookieName (spawnmenu.lua:25 ->
-- DHorizontalDivider:LoadCookies -> cookie.GetNumber -> GetCache), which took
-- the whole CreateSpawnMenu hook down with it:
--
--     Hook 'CreateSpawnMenu' (OnGamemodeLoaded) Failed:
--         lua/includes/modules/cookie.lua:27: attempt to call a nil value
--         (global 'SQLStr')
--
-- The engine installs a `sql` table (lsrcinit.cpp) whose SQLStr-only stub was
-- never enough; this file is the other half, and it must come after it.
-- `if ( !sql ) then return end` at the top makes it a no-op if sql ever goes
-- away.
include( "util/sql.lua" )

-- HL2SB (2026-09-29): GMod's drive classes (camera / lamp free-move modes).
-- GMod's own lua/includes/init.lua:40-41; its require("drive") above them is
-- already satisfied here because the modules folder pass loads drive.lua
-- BEFORE this init.lua runs.
include( "drive/drive_base.lua" )
include( "drive/drive_noclip.lua" )

-- HL2SB (2026-10-05): the GMod single-player save layer (gmsave.SaveMap /
-- gmsave.LoadMap over the duplicator).  GMod's own lua/includes/init.lua:86
-- includes it the same way; gm_save / gm_load live in the deathmatch gamemode
-- (save_load.lua), which every gamemode here inherits.
include( "gmsave.lua" )

-- HL2SB (2026-10-19): bridge the engine's SWEP loader into GMod's weapon
-- registry.  GMod's engine hands every lua/weapons/*.lua script to
-- weapons.Register, which is what fills weapons.GetList(), the
-- list.Get( "Weapon" ) registry (the sandbox give path reads it:
-- list.GetEntry( "Weapon", class )) and duplicator.Allow.  This fork's loader
-- answers weapon.register instead and nothing connected the two, so the
-- sandbox gamemode's gm_giveswep reported "invalid weapon" for every addon
-- SWEP that did not run list.Set itself.  Wrap, don't replace: the loader
-- resolves weapon.register at call time, so the wrapper is what it will see.
-- pcall keeps a sync failure from ever breaking the weapon's own
-- registration; the guard keeps a reordered bootstrap a silent no-op rather
-- than a hard error.
if ( weapon ~= nil and weapon.register ~= nil and weapons ~= nil and weapons.Register ~= nil ) then
	local weaponRegister = weapon.register
	weapon.register = function( t, classname, bReload )
		weaponRegister( t, classname, bReload )

		local ok, err = pcall( weapons.Register, t, classname )
		if ( not ok ) then
			Msg( "[HL2SB] weapons.Register sync failed for " .. tostring( classname ) .. ": " .. tostring( err ) .. "\n" )
		end
	end
end

-- Everything below is CLIENT ONLY, and GMod's own bootstrap guards it the same
-- way.  On the server these files do not merely no-op: derma/init.lua opens by
-- indexing `surface` (nil server-side), so it throws before it ever reaches
-- include("derma.lua") -- which means the global `derma` is never created, and
-- vgui_base.lua's 54 lua/vgui controls then all fail with
-- "attempt to index a nil value (global 'derma')".  Guarding here is what stops
-- the server from importing the entire client VGUI layer.
-- HL2SB: one line of realm evidence, because "which realm is this and does it
-- have surface/vgui" has been the difference between a clean load and 54 FAILED
-- lines more than once.  Grep the log for "lua/includes/init.lua:".
Msg( string.format(
	"[HL2SB] lua/includes/init.lua: CLIENT=%s SERVER=%s _CLIENT=%s _GAME=%s surface=%s vgui=%s\n",
	tostring( CLIENT ), tostring( SERVER ), tostring( _CLIENT ), tostring( _GAME ),
	tostring( surface ~= nil ), tostring( vgui ~= nil ) ) )

-- HL2SB: guard on CAPABILITY, not only on the realm flag.
--
-- `CLIENT` is the GMod spelling and the engine does set it (luamanager.cpp
-- base_open), but a wrong or missing flag here is NOT a harmless no-op:
-- derma/init.lua opens by indexing `surface`, so on a realm that has no surface
-- it throws before creating the global `derma`, and vgui_base.lua's 54
-- lua/vgui controls then each fail with
-- "attempt to index a nil value (global 'derma')" -- 54 FAILED lines, no
-- controls registered.  surface + vgui exist exactly where the client VGUI
-- layer really is, so test for them directly as well.
if ( CLIENT and surface and vgui ) then

	--==========================================================================
	-- HL2SB: register the custom .ttf files this mod ships BEFORE anything
	-- creates a font with them.
	--
	-- WHY THIS IS NEEDED AT ALL -- having the file in resource/ is not enough:
	-- the Windows font manager resolves a family through GDI, and a game-supplied
	-- .ttf only becomes visible to GDI once it has been handed to
	-- CMatSystemSurface::AddCustomFontFile
	--
	--     vguimatsurface/MatSystemSurface.cpp:1840
	--         AddCustomFontFile( fontName, fontFileName )
	--           -> g_pFullFileSystem->GetLocalPath( fontFileName, ... )
	--           -> AddFontResourceExA( fullPath, 0x10 /*FR_PRIVATE*/, NULL )
	--              (MatSystemSurface.cpp:1893)
	--
	-- There is NO resource/*.ttf scan anywhere in vgui2 or vguimatsurface (the
	-- only other implementation, vgui2/src/Surface.cpp:3253, is the stand-alone
	-- Win32 surface; and the family->file table in
	-- materialsystem/shaderapidx9/shaderapidx8.cpp:13375 is inside
	-- `#if defined( _X360 )`, so it does not apply to this build).  On Windows the
	-- name argument is not used for matching either -- GDI keys the font by the
	-- family recorded INSIDE the ttf -- which is why the argument below must spell
	-- the real family, and why tools/ttf_family.py exists to check it.
	--
	-- Consequence before this block: "Roboto" (DermaLarge) could never resolve.
	-- lua/derma/init.lua:41 creates DermaLarge with font="Roboto", and the GMod
	-- spawnmenu draws through it -- spawnmenu/toolpanel.lua:66
	-- markup.Parse( "<font=DermaLarge>" ... ).  It silently fell back to Verdana
	-- (LISurface.cpp:195 retries with Verdana when SetFontGlyphSet fails), so the
	-- menu's own labels were the wrong face.
	--
	-- Every family below was read out of the shipped file with
	-- tools/ttf_family.py, so the name and the file cannot drift.  Windows system
	-- families (Tahoma, Arial, Verdana, Trebuchet MS, Courier New, Times New
	-- Roman, Lucida Console, Marlett) need no registration -- they are in the OS
	-- font database; they are listed in the test's system-font allowlist instead.
	--==========================================================================
	local hl2sb_CustomFonts = {
		-- family        file (relative to the game dir)
		--
		-- The name is only a label here: on Windows CMatSystemSurface::
		-- AddCustomFontFile ends in AddFontResourceExA(path, FR_PRIVATE) and GDI
		-- then keys the face by the family recorded INSIDE the ttf, not by this
		-- argument.  For the Roboto style variants those differ: GDI sees
		-- Roboto-Regular/Bold/Italic/BoldItalic as family "Roboto", but the
		-- Medium/Light face as "Roboto Lt", Black as "Roboto Bk" and the
		-- Condensed face as "Roboto Cn" (the Windows nameID 1 record carries the
		-- width; the Macintosh one does not).  So "Roboto" -- what DermaLarge and
		-- the spawnmenu markup ask for -- is supplied by the four straight faces
		-- below; the variants are registered for completeness and appear under
		-- their own families.  tools/ttf_gdi_families.lua prints this mapping.
		{ "Roboto",            "resource/Roboto-Regular.ttf" },          -- DermaLarge
		{ "Roboto",            "resource/Roboto-Bold.ttf" },
		{ "Roboto",            "resource/Roboto-Italic.ttf" },
		{ "Roboto",            "resource/Roboto-BoldItalic.ttf" },
		{ "Roboto",            "resource/Roboto-Medium.ttf" },            -- GDI: Roboto Lt
		{ "Roboto",            "resource/Roboto-MediumItalic.ttf" },      -- GDI: Roboto Lt
		{ "Roboto",            "resource/Roboto-Light.ttf" },             -- GDI: Roboto Lt
		{ "Roboto",            "resource/Roboto-LightItalic.ttf" },       -- GDI: Roboto Lt
		{ "Roboto",            "resource/Roboto-Thin.ttf" },              -- GDI: Roboto Th
		{ "Roboto",            "resource/Roboto-ThinItalic.ttf" },        -- GDI: Roboto Th
		{ "Roboto",            "resource/Roboto-Black.ttf" },             -- GDI: Roboto Bk
		{ "Roboto",            "resource/Roboto-BlackItalic.ttf" },       -- GDI: Roboto Bk
		{ "Roboto",            "resource/Roboto-Condensed.ttf" },         -- GDI: Roboto Cn
		{ "Roboto",            "resource/Roboto-BoldCondensed.ttf" },     -- GDI: Roboto Cn
		{ "Roboto",            "resource/Roboto-BoldCondensedItalic.ttf" }, -- GDI: Roboto Cn
		{ "Roboto",            "resource/Roboto-CondensedItalic.ttf" },   -- GDI: Roboto Cn
		-- game icon/hud families named by resource/clientscheme.res and by GMod's
		-- own Lua; the files were already in the tree, just never registered
		{ "HalfLife2",         "resource/halflife2.ttf" },
		{ "HL2MP",             "resource/hl2mp.ttf" },
		{ "HL2SB",             "resource/hl2sb.ttf" },
		{ "HL2EP2",            "resource/hl2ep2.ttf" },
		{ "HL2cross",          "resource/HL2crosshairs.ttf" },
		{ "cs",                "resource/cs.ttf" },
		{ "cs",                "resource/csd.ttf" },                     -- csd.ttf declares family "cs"
		{ "Counter-Strike",    "resource/cstrike.ttf" },
		{ "Akbar",             "resource/akbar.ttf" },
		{ "Coolvetica",        "resource/coolvetica.ttf" },
		-- NOT registered, deliberately:
		--   lucidaconsole.ttf / marlett.ttf -- Windows already ships both
		--   families, so the files are redundant here.
	}

	for _, hl2sb_font in ipairs( hl2sb_CustomFonts ) do

		local hl2sb_ok = surface.AddCustomFontFile( hl2sb_font[ 1 ], hl2sb_font[ 2 ] )

		if ( not hl2sb_ok ) then
			-- Not fatal: LISurface.cpp:195 falls back to Verdana, so the family
			-- degrades to a visible face rather than to nothing.  Say so loudly
			-- anyway, because "my font is the wrong face" is otherwise invisible.
			Msg( "[HL2SB] AddCustomFontFile failed for '" .. hl2sb_font[ 1 ] ..
				"' (" .. hl2sb_font[ 2 ] .. ") -- that family will fall back\n" )
		end

	end

    -- Original scripted panels own control registration and inheritance.
    include("extensions/client/panel.lua")
    local panel = FindMetaTable("Panel")
    panel.SetFGColorEx = function(self, r, g, b, a)
        return panel.SetFgColor(self, Color(r or 255, g or 255, b or 255, a or 255))
    end
    panel.SetBGColorEx = function(self, r, g, b, a)
        return panel.SetBgColor(self, Color(r or 255, g or 255, b or 255, a or 255))
    end
    panel.GetFGColor = panel.GetFgColor
    panel.GetBGColor = panel.GetBgColor
    if (!panel.SetExpensiveShadow) then
        function panel:SetExpensiveShadow(offset, color)
            self.m_iExpensiveShadowOffset = offset
            self.m_colExpensiveShadow = color
        end
    end
    if (!vgui.GetKeyboardFocus) then vgui.GetKeyboardFocus = input.GetFocus end
    local playerMeta = FindMetaTable("Player")
    if (playerMeta && !playerMeta.GetTool) then
        function playerMeta:GetTool(mode)
            local weapon = self:GetWeapon("gmod_tool")
            if (!IsValid(weapon)) then return end
            return weapon:GetToolObject(mode)
        end
    end

	include( "derma/init.lua" )

	include( "skins/default.lua" )
	include( "vgui_base.lua" )
	include( "vgui_extra.lua" )

	--=====================================================================
	-- HL2SB: wire the tooltip hover pair.  GMod's engine calls the global
	-- ChangeTooltip( panel ) / EndTooltip( panel ) (lua/includes/util/tooltips.lua)
	-- when the hovered panel changes; this engine has no such callback, so the
	-- two are driven from the panels themselves: every panel built through
	-- vgui.Create from now on gets its OnCursorEntered / OnCursorExited wrapped
	-- to raise the same globals.  Controls that define their own handlers keep
	-- them (wrapped around the tooltip call), panels whose parents carry the
	-- tooltip fields are covered by FindTooltip's parent walk, exactly like GMod.
	--
	-- tooltips.lua is NOT auto-loaded here (this fork's util.lua only includes
	-- util/color.lua -- there is no util/ folder pass like GMod's), so include
	-- it explicitly.  It has to run AFTER vgui_base.lua: the DTooltip control
	-- must be registered before ChangeTooltip can build one, and vgui.Create is
	-- the framework's final version only once derma/init.lua has defined it.
	--=====================================================================
	include( "util/tooltips.lua" )

	do
		local CreateNoTooltip = vgui.Create

		vgui.Create = function( strClass, pParent, strName )
			local pnl = CreateNoTooltip( strClass, pParent, strName )

			-- The wrapper is installed on EVERY panel, not only ones that already
			-- define the cursor handlers: a plain DPanel carries no OnCursorEntered
			-- of its own, and it is exactly the common tooltip host.  The engine
			-- dispatch reads the ref table first, so the write below makes the
			-- events reach Lua on controls that had no handler before.
			if ( pnl ~= nil and not pnl.HL2SBTooltipWired ) then
				pnl.HL2SBTooltipWired = true

				-- Tooltip panels never get wired: ChangeTooltip on a tooltip
				-- would RemoveTooltip() itself (the panel it walks with IS the
				-- tooltip), so cursor enter/exit on the bubble would fight the
				-- creator forever.
				if ( not pnl.m_bIsTooltipPanel ) then
					-- Capture the previous handlers from the REF TABLE ONLY.
					-- `pnl.OnCursorEntered` reads through the metatable, whose
					-- entries are C dispatchers that call the Lua method back --
					-- wrapping THAT made wrapper -> C -> wrapper -> C ... a C stack
					-- overflow on every hover (92 in one session, hl2sb_lua.log).
					local tbl = ( pnl.GetTable ~= nil ) and pnl:GetTable() or nil
					local BaseOnCursorEntered = tbl and rawget( tbl, "OnCursorEntered" ) or nil
					local BaseOnCursorExited = tbl and rawget( tbl, "OnCursorExited" ) or nil

					pnl.OnCursorEntered = function( s, ... )
						if ( ChangeTooltip ~= nil ) then ChangeTooltip( s ) end
						if ( BaseOnCursorEntered ~= nil ) then return BaseOnCursorEntered( s, ... ) end
					end

					pnl.OnCursorExited = function( s, ... )
						if ( EndTooltip ~= nil ) then EndTooltip( s ) end
						if ( BaseOnCursorExited ~= nil ) then return BaseOnCursorExited( s, ... ) end
					end
				end
			end

			return pnl
		end

		Msg( "[HL2SB]   tooltip hover wiring installed on vgui.Create\n" )
	end

	-- Original Derma controls and skin are loaded above.

	-- HL2SB: notification system (see the rewritten includes/notification.lua:
	-- it must run after the controls, because NoticePanel bases on DPanel).
	include( "notification.lua" )
	include( "util/javascript_util.lua" )
	include( "util/workshop_files.lua" )
	include( "util/model_database.lua" )

end

-- ===========================================================================
-- GMod's sh_enumerations.lua (lua/includes/modules/gmod_compatibility/)
--
-- It copies the engine's _E.* enumerations to globals under GMod's spellings.
-- This engine publishes KEY_CONTROL_LEFT where GMod Lua says KEY_LCONTROL, and
-- lua/vgui/DListView.lua:382 needs KEY_LCONTROL just to select a line:
--
--   lua/vgui/DListView.lua:382: bad argument #1 to 'IsKeyDown' (number expected, got nil)
--     in method 'OnClickLine'
--     in function <lua/vgui/DListView_Line.lua:81>
--
-- so clicking a row in a DListView threw instead of selecting it -- which is why
-- the player model list could not be clicked.
--
-- The engine's folder pass (luasrc_dofolder) does not recurse into
-- gmod_compatibility/, so this file was never loaded.  `include` resolves
-- relative to the calling file, and this one lives in lua/includes/.
--
-- sh_enumerations.lua hard-errors on the first _E table this engine does not
-- publish.  Seeding EVERY table it wants lets it run further and then die at
--
--   sh_enumerations.lua:159: attempt to index a nil value (field 'DOCK_TYPE')
--
-- (it wants _E.DOCK_TYPE too), and that deeper run also changed what it had
-- already written to _G.  Seed only the table that gets the KEY_* aliases past
-- their own error and stop there -- this is the state the Derma skin is verified
-- working in.  TODO(engine): publish _E.INPUT / _E.SURFACE / ... / _E.DOCK_TYPE
-- for real, then this whole block goes away.
-- ===========================================================================
if ( _E ~= nil ) then
	local hl2sb_EnumStubs = {
		"ACTIVITY", "BUTTON", "INPUT", "CONTENTS", "COLLISION_GROUP", "FCVAR",
		"EDICT_FLAG", "SOLID_FLAG", "SOLID", "SOUND_CHANNEL", "SURFACE",
		"DAMAGE_TYPE", "HIT_GROUP", "MATERIAL_TYPE", "ENTITY_EFFECT", "ENGINE_FLAG",
	}

	for _, hl2sb_Key in ipairs( hl2sb_EnumStubs ) do
		if ( not _E[ hl2sb_Key ] ) then
			_E[ hl2sb_Key ] = {}
		end
	end
end

include( "modules/gmod_compatibility/sh_enumerations.lua" )

-- ===========================================================================
-- GMod's Entity:SetNoDraw / Entity:GetNoDraw
--
-- GMod implements these on EF_NODRAW (garrysmod/lua/includes/modules/
-- gmod_compatibility/sh_init.lua:772-782, "self:AddEffects( _E.ENTITY_EFFECT.NO_DRAW )"),
-- and that file is never loaded here -- which broke every caller:
--
--   lua/vgui/DModelPanel.lua:131  DModelPanel:SetModel -> self.Entity:SetNoDraw( true )
--       (the player model selector died there: "attempt to call a nil value (method
--        'SetNoDraw')", with the window already drawn and empty)
--   lua/includes/modules/render.lua:183   ent:SetNoDraw( true )
--   lua/includes/modules/halo.lua:75      if ( !IsValid( v ) or v:GetNoDraw() )
--
-- The engine bindings are all present: AddEffects / RemoveEffects / IsEffectActive
-- (game/shared/lua/lbaseentity_shared.cpp:3298/3504/3455).  This fork's
-- sh_enumerations.lua publishes the flag as the bare global EF_NODRAW (= 32, :400)
-- rather than through _E.ENTITY_EFFECT, so that is what is used here, with the
-- literal as a last resort.  This block sits after the sh_enumerations include so the
-- constant is already defined.
-- ===========================================================================
local hl2sb_EntityMeta = FindMetaTable( "Entity" )

if ( hl2sb_EntityMeta ~= nil and hl2sb_EntityMeta.SetNoDraw == nil ) then
	local hl2sb_NoDraw = EF_NODRAW or 32

	--- GMod: toggles EF_NODRAW on the entity.
	function hl2sb_EntityMeta:SetNoDraw( b )
		if ( b ) then
			self:AddEffects( hl2sb_NoDraw )
		else
			self:RemoveEffects( hl2sb_NoDraw )
		end
	end

	function hl2sb_EntityMeta:GetNoDraw()
		return self:IsEffectActive( hl2sb_NoDraw )
	end

	Msg( "[HL2SB]   Entity:SetNoDraw / GetNoDraw added (EF_NODRAW=" .. tostring( hl2sb_NoDraw ) .. ")\n" )end

-- ===========================================================================
-- HL2SB (2026-10-07): the Entity-shaped methods an EFFECT instance expects.
--
-- GMod's effect self answers Entity calls (EntIndex, SetRenderMode,
-- SetRenderFX, ...).  This engine's effects are Lua tables driven by
-- Init/Think/Render, and the engine stamps only SetRenderBoundsWS /
-- GetTracerShootPos and the numeric property setters on each spawned copy
-- (game/client/lua/lua_effects.cpp).  hl1sweps' effects use the rest:
--
--   effects/hl1_explosion/init.lua:11     DynamicLight( self:EntIndex() )
--   effects/hl1_gauss_glow/init.lua:2-3   self:SetRenderMode( RENDERMODE_GLOW )
--                                         self:SetRenderFX( kRenderFxNoDissipation )
--
-- With EntIndex missing, that Init dies on its first dynamic-light line --
-- self.Time is never assigned and Think then errors on "field 'Time' is a
-- nil value" every frame, so the explosion never draws at all.
--
-- The stamps go on the template through effects.Register, which is what the
-- effect loader calls once per lua/effects/<name>.lua; the per-spawn shallow
-- copy in lua_effects.cpp then carries them onto every live instance.  This
-- file runs after the modules pass (effects.Register exists here) and well
-- before the effect loading stage.  All three are additive: only installed
-- when the template does not already define them.
--
-- EntIndex hands back a stable number per instance.  A dynamic-light id only
-- needs identity, not a real entity index, and the weak-keyed id table lets
-- a retired effect release its slot.  SetRenderMode / SetRenderFX store the
-- mode on the instance: the affected effects draw their own sprites and
-- particles and need no engine render mode to look right.
-- ===========================================================================
if ( CLIENT and type( effects ) == "table" and type( effects.Register ) == "function" ) then
	local hl2sb_OldEffectRegister = effects.Register
	local hl2sb_EffectIDs = setmetatable( {}, { __mode = "k" } )
	local hl2sb_NextEffectID = 0

	function effects.Register( t, name )
		if ( type( t ) == "table" ) then
			if ( t.EntIndex == nil ) then
				function t:EntIndex()
					local id = hl2sb_EffectIDs[ self ]
					if ( id == nil ) then
						hl2sb_NextEffectID = ( hl2sb_NextEffectID + 1 ) % 255
						hl2sb_EffectIDs[ self ] = hl2sb_NextEffectID
						id = hl2sb_NextEffectID
					end

					return id
				end
			end

			if ( t.SetRenderMode == nil ) then
				function t:SetRenderMode( mode )
					self.__hl2sb_rendermode = mode
				end
			end

			if ( t.SetRenderFX == nil ) then
				function t:SetRenderFX( fx )
					self.__hl2sb_renderfx = fx
				end
			end
		end

		return hl2sb_OldEffectRegister( t, name )
	end

	Msg( "[HL2SB]   EFFECT:EntIndex / SetRenderMode / SetRenderFX added\n" )
end
