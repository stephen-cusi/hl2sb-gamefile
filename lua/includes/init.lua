--[[----------------------------------------------------------------------------
    lua/includes/init.lua  --  HL2SB

    *** This file is NOT GMod's.  It is the one deliberate deviation in
    lua/includes/, and it exists only until the modules GMod's own init.lua
    would pull in are ported. ***

    GMod's own lua/includes/init.lua is the bootstrap: it includes util.lua and
    util/sql.lua, then `require`s ~25 shared modules (saverestore, weapons,
    scripted_ents, construct, duplicator, constraint, cleanup, numpad,
    usermessage, cvars, http, properties, widget, cookie, utf8, drive, ...) and,
    on the client, draw / markup / effects / halo / killicon / spawnmenu /
    controlpanel / presets / menubar / matproxy, and finally the extensions.

    HL2SB loads extensions/ and modules/ itself, and most of that module list
    does not exist here yet, so this file includes only what is actually
    available and grows one line at a time as the port lands.  When the last
    line of GMod's list becomes real, delete this file and copy GMod's in.

    ==========================================================================
    Everything it includes is GMod's file, byte for byte, and the ORDER is
    GMod's too (its engine loads these three in this order):

        util.lua            type predicates, AccessorFunc, FORCE_*, Lerp,
                            Either, PrintTable, STNDRD, ...
                            (pulls in util/color.lua via its own include)
        derma/init.lua      the Derma framework: fonts, derma.DefineControl /
                            DefineSkin / SkinHook, Derma_Hook, and the
                            sub-includes (derma.lua, derma_utils.lua, ...)
        vgui_base.lua       includes the 54 lua/vgui/*.lua controls

    derma/init.lua has to precede vgui_base.lua: every control in lua/vgui/
    calls derma.DefineControl at file scope.

    Loaded from lua/includes/ by luasrc_dofile_includes( L, "init.lua" ) -- one
    named file, NOT a directory scan (see that call site in cdll_client_int.cpp
    and gameinterface.cpp: a scan re-runs vgui_base.lua and kills all 54
    controls).
    Note that include() resolves relative to the calling file first, then falls
    back to lua/ -- which is how "derma/init.lua" is found from here.
-----------------------------------------------------------------------------]]--

include( "util.lua" )

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

	-- GMod's scripted-panel layer: vgui.Register / vgui.Create / vgui.CreateX and
	-- the Panel metatable extensions.  MUST precede derma/init.lua -- derma.lua's
	-- DefineControl calls vgui.Register, and scriptedpanels.lua is the version that
	-- resolves a base class through PanelFactory instead of requiring it to be a
	-- registered vgui[] factory.
	include( "extensions/client/panel.lua" )

	-- HL2SB: GMod-vs-vgui2 Panel method spelling differences.
	--
	-- This has to happen HERE -- after scriptedpanels.lua has registered the
	-- Panel metatable, and before vgui_base.lua loads DLabel.lua -- and NOT in
	-- the extensions pass: there FindMetaTable( "Panel" ) is still nil, so the
	-- aliases were skipped in silence and DLabel.lua:29 kept failing with
	-- "attempt to call a nil value (method 'SetKeyboardInputEnabled')".
	--
	-- This fork spells these with a capital B (vgui2's own spelling, e.g.
	-- scriptedhudviewport.cpp: SetKeyBoardInputEnabled(false)); GMod's Lua API
	-- uses a lowercase b and GMod's own panel files use the GMod spelling.
	do
		local PanelMeta = FindMetaTable( "Panel" )
		Msg( "[HL2SB] panel method aliases: FindMetaTable(Panel) = " .. tostring( PanelMeta ) .. "\n" )

		if ( PanelMeta ~= nil ) then
			local Aliases = {
				{ "SetKeyboardInputEnabled", "SetKeyBoardInputEnabled" },
				{ "IsKeyboardInputEnabled",  "IsKeyBoardInputEnabled"  },
			}

			for _, pair in ipairs( Aliases ) do
				if ( PanelMeta[ pair[ 1 ] ] == nil and PanelMeta[ pair[ 2 ] ] ~= nil ) then
					PanelMeta[ pair[ 1 ] ] = PanelMeta[ pair[ 2 ] ]
					Msg( "[HL2SB]   aliased " .. pair[ 1 ] .. " -> " .. pair[ 2 ] .. "\n" )
				end
			end

			Msg( "[HL2SB]   SetKeyboardInputEnabled = " .. tostring( PanelMeta.SetKeyboardInputEnabled ) .. "\n" )

			-- HL2SB: Panel:SetFont must also accept a font NAME string.
			--
			-- GMod's Panel:SetFont( font ) takes either an HFont or a font name,
			-- and its own panel files pass names:
			--
			--     lua/vgui/DLabel.lua:39: bad argument #1 to 'SetFont'
			--                             (HFont expected, got string)
			--
			-- This fork's binding only takes an HFont, so resolve the name first
			-- through the same path surface.SetFont( name ) uses (the per-state
			-- font registry, then the scheme) and hand the HFont to the engine
			-- function.  draw.GetFont is the fallback.
			local EngineSetFont = PanelMeta.SetFont
			if ( EngineSetFont ~= nil ) then
				PanelMeta.SetFont = function( self, font )
					if ( type( font ) == "string" ) then
						local hfont = nil
						if ( surface ~= nil and surface.SetFont ~= nil ) then
							hfont = surface.SetFont( font )
						end
						if ( hfont == nil and _G.draw ~= nil and draw.GetFont ~= nil ) then
							hfont = draw.GetFont( font )
						end
						if ( hfont == nil ) then
							Msg( "[HL2SB] Panel:SetFont: cannot resolve font '" .. tostring( font ) .. "'\n" )
							return
						end
						font = hfont
					end

					return EngineSetFont( self, font )
				end
			end

			-- HL2SB: Label:SetFont must take a font NAME too.
			--
			-- lua/vgui/dlabel.lua:39 is self:SetFont( "DermaDefault" ) and DLabel's
			-- base is Label, whose engine binding is HFont-only
			-- (public/lua/vgui_controls/lLabel.cpp:162 -> luaL_checkfont):
			--
			--     Hook 'hl2sb_notification' (OnUndo) Failed:
			--       lua/vgui/DLabel.lua:39: bad argument #1 to 'SetFont'
			--                              (HFont expected, got string)
			--
			-- Same resolution as above: name -> HFont through surface.SetFont
			-- (per-state font registry first, then the scheme), draw.GetFont as
			-- the fallback.
			local LabelMeta = FindMetaTable( "Label" )
			Msg( "[HL2SB] panel method aliases: FindMetaTable(Label) = " .. tostring( LabelMeta ) .. "\n" )

			if ( LabelMeta ~= nil and LabelMeta.SetFont ~= nil ) then
				local EngineLabelSetFont = LabelMeta.SetFont

				LabelMeta.SetFont = function( self, font )
					if ( type( font ) == "string" ) then
						local hfont = nil
						if ( surface ~= nil and surface.SetFont ~= nil ) then
							hfont = surface.SetFont( font )
						end
						if ( hfont == nil and _G.draw ~= nil and draw.GetFont ~= nil ) then
							hfont = draw.GetFont( font )
						end
						if ( hfont == nil ) then
							Msg( "[HL2SB] Label:SetFont: cannot resolve font '" .. tostring( font ) .. "'\n" )
							return
						end
						font = hfont
					end

					return EngineLabelSetFont( self, font )
				end

				Msg( "[HL2SB]   Label:SetFont wrapped for name strings\n" )
			end

			-- HL2SB: SetFGColorEx / SetBGColorEx and the capital-G getters.
			--
			-- GMod's lua/includes/extensions/client/panel.lua:17 overrides
			-- SetFGColor to accept a Color table OR r, g, b, a, and forwards BOTH
			-- forms to SetFGColorEx -- which this engine never bound.  Its own
			-- setter is the lowercase-g SetFgColor that takes a Color:
			--
			--     Hook 'hl2sb_notification' (OnUndo) Failed:
			--       panel.lua:24: attempt to call a nil value (method 'SetFGColorEx')
			--
			-- So build the Color here and call the engine setter.  The capital-G
			-- getters are aliased too (engine: GetFgColor / GetBgColor).
			-- NOTE: SetFGColor / SetBGColor are deliberately NOT aliased -- GMod's
			-- panel.lua already owns those names and routes them through the Ex
			-- forms below.
			if ( PanelMeta.SetFGColorEx == nil and PanelMeta.SetFgColor ~= nil ) then
				local EngineSetFgColor = PanelMeta.SetFgColor
				PanelMeta.SetFGColorEx = function( self, r, g, b, a )
					return EngineSetFgColor( self, Color( r or 255, g or 255, b or 255, a or 255 ) )
				end
				Msg( "[HL2SB]   SetFGColorEx wrapped\n" )
			end

			if ( PanelMeta.SetBGColorEx == nil and PanelMeta.SetBgColor ~= nil ) then
				local EngineSetBgColor = PanelMeta.SetBgColor
				PanelMeta.SetBGColorEx = function( self, r, g, b, a )
					return EngineSetBgColor( self, Color( r or 255, g or 255, b or 255, a or 255 ) )
				end
				Msg( "[HL2SB]   SetBGColorEx wrapped\n" )
			end

			if ( PanelMeta.GetFGColor == nil and PanelMeta.GetFgColor ~= nil ) then
				PanelMeta.GetFGColor = PanelMeta.GetFgColor
			end

			if ( PanelMeta.GetBGColor == nil and PanelMeta.GetBgColor ~= nil ) then
				PanelMeta.GetBGColor = PanelMeta.GetBgColor
			end

			--=================================================================
			-- HL2SB: Panel:HasHierarchicalFocus()
			--
			-- GMod addition to vgui -- it does NOT exist in this engine's vgui2
			-- (zero hits for HasHierarchicalFocus in public/vgui_controls and
			-- vgui2), so it has to be implemented, not aliased.  The Derma skin
			-- calls it every frame:
			--
			--     lua/skins/default.lua:350  if ( panel:HasHierarchicalFocus() ) then
			--         -> "attempt to call a nil value (method 'HasHierarchicalFocus')"
			--         (79 times in one log -- once per frame, because the frame
			--          WAS created and WAS painting; this was the last error
			--          between the new player model panel and a visible window)
			--
			-- GMod semantics: true if this panel OR any descendant has the
			-- keyboard focus.  Built from the bindings this engine already has
			-- (HasFocus / GetChildCount / GetChild), so the focused-frame
			-- highlight behaves the same.
			--=================================================================
			if ( PanelMeta.HasHierarchicalFocus == nil ) then
				function PanelMeta:HasHierarchicalFocus()
					if ( self.HasFocus ~= nil and self:HasFocus() ) then
						return true
					end

					if ( self.GetChildCount ~= nil and self.GetChild ~= nil ) then
						for i = 0, self:GetChildCount() - 1 do
							local child = self:GetChild( i )
							if ( child ~= nil and child.HasHierarchicalFocus ~= nil and child:HasHierarchicalFocus() ) then
								return true
							end
						end
					end

					return false
				end

				Msg( "[HL2SB]   Panel:HasHierarchicalFocus implemented\n" )
			end

			--=================================================================
			-- HL2SB: the last GMod Label/Panel methods notification.lua needs.
			--
			-- Listed from notification.lua itself rather than added one per log
			-- line: self:DockPadding, GetDockPadding, GetTall, GetWide,
			-- InvalidateLayout, Remove, SetBackgroundColor, SetSize,
			-- SizeToContents, self.Label:{Dock, DockMargin, GetSize,
			-- SetContentAlignment, SetExpensiveShadow, SetFont, SetText,
			-- SetTextColor, SetVisible, SizeToContents}.
			--
			-- Everything here is guarded on `== nil` so an engine binding always
			-- wins; these only fill what this fork never bound.
			--
			-- SizeToContents is COLUMN-CRITICAL: notification.lua sizes the whole
			-- notice panel from self.Label:GetSize() afterwards, so a no-op there
			-- would give a 0x0 label and an invisible notice.  It is implemented
			-- for real against surface.GetTextSize, which in this fork takes
			-- ( hfont, text ) -- the two-argument form (AGENTS.md 5.4).
			--
			-- SetExpensiveShadow and SetContentAlignment are recorded only: vgui2's
			-- Label has no shadow concept at all (GMod draws it in its own C++),
			-- and the notice is perfectly legible without it.  They are stored so
			-- a later real implementation has the values.
			--=================================================================
			local LabelMeta = FindMetaTable( "Label" )

			if ( LabelMeta ~= nil ) then
				if ( LabelMeta.SizeToContents == nil ) then
					function LabelMeta:SizeToContents()
						local w, h = 0, 0

						local font = ( self.GetFont ~= nil ) and self:GetFont() or nil
						local text = ""
						if ( self.GetText ~= nil ) then text = self:GetText() or "" end

						if ( font ~= nil and surface ~= nil and surface.GetTextSize ~= nil ) then
							w, h = surface.GetTextSize( font, text )
						end

						if ( w < 1 ) then w = 1 end
						if ( h < 1 ) then h = 1 end

						self:SetSize( w, h )
					end
					Msg( "[HL2SB]   Label:SizeToContents implemented\n" )
				end

				if ( LabelMeta.SetExpensiveShadow == nil ) then
					function LabelMeta:SetExpensiveShadow( offset, color )
						self.m_iExpensiveShadowOffset = offset
						self.m_colExpensiveShadow = color
					end
				end

				if ( LabelMeta.SetContentAlignment == nil ) then
					function LabelMeta:SetContentAlignment( align )
						self.m_iContentAlignment = align
						if ( self.SetContentAlignmentInternal ~= nil ) then
							self:SetContentAlignmentInternal( align )
						end
					end
				end
			end

			if ( PanelMeta.SetBackgroundColor == nil ) then
				PanelMeta.SetBackgroundColor = function( self, color )
					if ( self.SetBgColor ~= nil ) then
						return self:SetBgColor( color )
					end
				end
			end

			--=================================================================
			-- HL2SB: Panel:HasParent( pnl )
			--
			-- GMod's vgui2 has Panel::HasParent(VPANEL) and binds it; this
			-- fork's lPanel.cpp never did (its own IPanel has the call --
			-- public/vgui/IPanel.h:66 -- but nothing exposes it to Lua).
			--
			-- Needed by the GMod spawnmenu's own focus plumbing:
			--   gamemodes/sandbox/gamemode/spawnmenu/spawnmenu.lua:274,277,290,294
			--       pnl:HasParent( g_SpawnMenu )
			-- and by lua/includes/extensions/client/panel.lua:493 (Derma
			-- drag/drop).  Without it those throw and hook.lua UNREGISTERS the
			-- OnTextEntryGetFocus / OnTextEntryLoseFocus hooks on their first
			-- run, so the spawnmenu's search box can never take the keyboard.
			--
			-- GMod's semantics are the immediate parent, which vgui2's
			-- HasParent(VPANEL) also is, so GetParent() == pnl is exact.
			--=================================================================
			if ( PanelMeta.HasParent == nil and PanelMeta.GetParent ~= nil ) then
				function PanelMeta:HasParent( pnl )
					if ( not IsValid( pnl ) ) then return false end
					return self:GetParent() == pnl
				end

				Msg( "[HL2SB]   Panel:HasParent implemented\n" )
			end

			--=================================================================
			-- HL2SB: Panel:KillFocus()
			--
			-- lua/vgui/dtextentry.lua:432 calls it from the global mouse-press
			-- handler (click outside the text entry -> drop the keyboard).
			--
			-- This fork's vgui2 has NO focus primitive to forward to: IInput has
			-- no SetFocus/KillFocus (public/vgui/IInput.h) and IPanel has no
			-- equivalent either, so unlike MoveToBack/FocusNext this one cannot
			-- be exact.  Turning keyboard input off on that panel is what the
			-- caller actually wants -- the spawnmenu re-enables it through its
			-- own StartKeyFocus hook when a real text entry is clicked -- and it
			-- is far better than the alternative, which is an error on every
			-- mouse press.
			--=================================================================
			if ( PanelMeta.KillFocus == nil ) then
				function PanelMeta:KillFocus()
					if ( self.SetKeyboardInputEnabled ~= nil ) then
						self:SetKeyboardInputEnabled( false )
					end
				end

				Msg( "[HL2SB]   Panel:KillFocus approximated\n" )
			end
		end
	end

	-- HL2SB: Player:GetTool( name ), the last thing on the spawnmenu's tool-menu
	-- population path that this fork cannot answer.
	--
	-- gamemodes/sandbox/gamemode/spawnmenu/toolpanel.lua:159 evaluates it while
	-- building the tool tabs (Lua evaluates arguments before hook.Run):
	--
	--     hook.Run( "CanTool", LocalPlayer(), fakeTrace, item.Name,
	--               LocalPlayer():GetTool( item.Name ), 4 )
	--
	-- In GMod it returns the gmod_tool stool table for that tool name.  This
	-- fork has no stool registry at all (`gmod_tool` is one of the documented
	-- gaps), so there is nothing to return: nil is the honest answer, and it
	-- keeps UpdateToolDisabledStatus from throwing and taking the whole tool
	-- panel down with it.  When stools are ported, delete this.
	local PlayerMeta = FindMetaTable( "Player" )
	if ( PlayerMeta ~= nil and PlayerMeta.GetTool == nil ) then
		function PlayerMeta:GetTool( name )
			return nil
		end

		Msg( "[HL2SB]   Player:GetTool stubbed (no gmod_tool stools in this fork)\n" )
	end

	include( "derma/init.lua" )

	include( "vgui_base.lua" )

	-- HL2SB: the OTHER 39 controls GMod ships in lua/vgui/.
	--
	-- vgui_base.lua is GMod's own file and names only 54 of the 93 control
	-- files; GMod's engine walks lua/vgui/ for the rest and this fork never did.
	-- DHorizontalDivider -- the first panel the sandbox spawnmenu creates,
	-- spawnmenu/spawnmenu.lua:21 -- was in the missing 39, so vgui.Create
	-- returned nil and the menu died on its own Init:
	--
	--     Hook 'CreateSpawnMenu' (OnGamemodeLoaded) Failed:
	--         spawnmenu/spawnmenu.lua:22: attempt to index a nil value
	--                                    (field 'HorizontalDivider')
	--
	-- See the header of vgui_extra.lua for why it is a GENERATED explicit list
	-- rather than a directory scan, and why it is not folded into GMod's file.
	include( "vgui_extra.lua" )

	-- HL2SB: GMod's default Derma skin.  Nothing loaded it, so derma.DefaultSkin
	-- stayed the empty table derma.lua starts with -- and SkinHook() silently
	-- returns when the skin has no hook for the type:
	--
	--     local func = Skin[ strType .. strName ]
	--     if ( !func ) then return end
	--
	-- With no SKIN:PaintPanel every Derma panel (including the undo notice)
	-- painted NOTHING at all -- no background, no animation -- while the rest of
	-- the chain reported success.  skins/default.lua ends with
	-- derma.DefineSkin( "Default", ... ), and it needs derma_gwen.lua's GWEN
	-- table, which derma/init.lua already includes.
	include( "skins/default.lua" )

	-- HL2SB: GMod's notification system (AddLegacy / NoticePanel).  GMod keeps
	-- this file in lua/includes/modules/notification.lua and pulls it in from
	-- its own init.lua; here it lives one directory up and is included by hand,
	-- because it MUST run after the two lines above:
	--
	--   * its last statement is vgui.Register( "NoticePanel", PANEL, "DPanel" ),
	--     and DPanel only exists once vgui_base.lua has run lua/vgui/dpanel.lua;
	--   * it calls derma.SkinHook indirectly through DPanel's Paint, which
	--     derma/derma.lua provides.
	--
	-- The engine's folder pass loads lua/includes/modules/ BEFORE this file, so
	-- leaving it in modules/ made that Register fail with
	-- "vgui.Register: base class 'DPanel' does not exist" on every level.
	include( "notification.lua" )

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
