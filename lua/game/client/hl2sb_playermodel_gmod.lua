--[[----------------------------------------------------------------------------
    hl2sb_playermodel_gmod.lua

    COMPLETE port of GMod's player model selector, from

        garrysmod/gamemodes/sandbox/gamemode/editor_player.lua   (407 lines)

    Structure follows GMod's file 1:1: `SetDefaultColorFromConVar`, then the
    `list.Set( "DesktopWindows", "PlayerEditor", ... )` registration (same
    title/icon/width/height/onewindow fields and the same init body), then the
    `open_playermodel_selector` concommand, then the PlayerOptionsAnimations
    list.  The window is the same: a DHorizontalDivider with a DModelPanel
    preview on the left and a DPropertySheet on the right holding

        Model       quick filter box + a DPanelSelect of SpawnIcons, one per
                    player model, grouped by category
        Colors      two DColorMixers (player colour / weapon colour)
        Bodygroups  DNumSliders, one per bodygroup plus a skin slider

    The preview rotates by dragging and is lit by three coloured point lights
    swinging around it (mdl:PreDrawModel + render.SetLocalModelLights).

    DEVIATIONS from GMod's file, all of them forced by this fork (each is
    marked with a DELTA comment at its site):

      * Opening.  GMod's concommand walks g_ContextMenu.DesktopWidgets, which
        does not exist here.  The list.Set entry above is still registered (it
        is the API GMod exposes to widget grids), and `open_playermodel_selector`
        builds the window and calls the registered init directly -- the same
        call a widget icon's DoClick would make.  A second press closes it,
        because a keybind needs a way back out.

      * "#token" strings.  This fork draws Derma texts in Lua and does not
        resolve #tokens engine-side, so every token goes through Phrase(),
        backed by the language.AddTable block below (GMod's own English
        values from resource/localization/en/spawnmenu.properties).

      * Model data.  GMod iterates player_manager.GetAllPlayerModels(); the
        fork's player_manager is fed by lua/autorun/client/hl2sb_playermodels.lua
        (models/player/ scan), which announces "HL2SB_PlayerModelsBuilt" when
        the list changes.  Selection writes the model PATH into cl_playermodel
        (the fork's server reads a path, not a player_manager name).

      * SetDefaultColorFromConVar.  GMod writes panel.HSV:SetDefaultColor;
        this fork's DColorMixer exposes the same idea as SetDefaultColor.

      * SpawnIcon population is batched a few per frame (each SetModel loads
        and renders a .mdl; ~100 in one frame froze the game for seconds).

      * UpdateFromControls writes each mixer's own convar behind a
        bUpdatingFromConvars guard (GMod writes BOTH convars from BOTH
        callbacks; with this fork's event timing that cross-writes stale
        values -- "opening the menu changes my colour").

      * mdl.Entity:SetEyeTarget is inert (no CIKContext::SetEyeTarget) and
        render.BindLocalCubemap is guarded (binding may be absent).

    Console commands:  open_playermodel_selector   /   hl2sb_playermodel_gmod
--]]----------------------------------------------------------------------------

if ( SERVER ) then return end

-- ---------------------------------------------------------------------------
-- Phrases (GMod's resource/localization/en/spawnmenu.properties, verbatim)
-- ---------------------------------------------------------------------------
if ( _G.language ~= nil and language.AddTable ~= nil ) then
	language.AddTable( {
		[ "smwidget.playermodel" ]			= "Player Model",
		[ "smwidget.playermodel_title" ]	= "Player Model Selector",
		[ "smwidget.model" ]				= "Model",
		[ "smwidget.colors" ]				= "Colors",
		[ "smwidget.color_plr" ]			= "Player color:",
		[ "smwidget.color_wep" ]			= "Weapon color:",
		[ "smwidget.bodygroups" ]			= "Bodygroups",
		[ "spawnmenu.quick_filter" ]		= "Quick Filter...",
		[ "spawnmenu.menu.copy" ]			= "Copy to clipboard",
		[ "spawnmenu.category.other" ]		= "Other",
	} )
end

local function Phrase( str )
	if ( type( str ) ~= "string" ) then return "" end

	if ( _G.language ~= nil and language.GetPhrase ~= nil ) then
		local ok, txt = pcall( language.GetPhrase, str )
		if ( ok and type( txt ) == "string" ) then return txt end
	end

	return str
end

local default_animations = { "idle_all_01", "menu_walk" }

-- HL2SB (2026-09-27, perf): the three swinging point lights are GMod's exact
-- preview rig, but on this engine's DX9 path per-pixel local lights are the
-- single most expensive thing on the Model tab (the icon grid itself is
-- snapshots = texture blits).  `hl2sb_preview_lights` in the console toggles
-- them off; the preview then falls back to the map lighting, like the icons.
local bPreviewLightsOff = false

local function SetDefaultColorFromConVar( panel, convarName )
	-- GMod: local color = Vector( GetConVar( convarName ):GetDefault() ):ToColor()
	--        if ( color ) then panel.HSV:SetDefaultColor( color ) end
	-- DELTA: the fork's DColorMixer calls the baseline SetDefaultColor.
	local cv = GetConVar( convarName )

	if ( not cv or not panel.SetDefaultColor ) then return end

	local col = Vector( cv:GetDefault() ):ToColor()

	if ( col ) then
		panel:SetDefaultColor( col )
	end
end

--- Every player model this fork knows about (GMod: player_manager.GetAllPlayerModels()).
local function GetModelList()
	local models = {}

	if ( _G.player_manager ~= nil and player_manager.GetAllPlayerModels ~= nil ) then
		local ok, data = pcall( player_manager.GetAllPlayerModels )

		if ( ok and istable( data ) ) then models = data end
	end

	return models
end

-- ---------------------------------------------------------------------------
-- list.Set( "DesktopWindows", "PlayerEditor", { ... } )  -- GMod, verbatim shape
-- ---------------------------------------------------------------------------
list.Set( "DesktopWindows", "PlayerEditor", {

	title		= Phrase( "#smwidget.playermodel" ),
	icon		= "icon64/playermodel.png",
	width		= 960,
	height		= 700,
	onewindow	= true,
	init		= function( widgetIcon, window )

		window:SetTitle( Phrase( "#smwidget.playermodel_title" ) )
		window:SetSize( math.max( ScrW() * 0.8, window:GetWide() ), math.max( ScrH() * 0.8, window:GetTall() ) )
		window:SetSizable( true )
		window:SetMinWidth( 400 )
		window:SetMinHeight( 250 )
		window:Center()

		local divider = window:Add( "DHorizontalDivider" )
		divider:Dock( FILL )
		divider:SetLeftWidth( window:GetWide() / 2 )
		divider:SetLeftMin( 150 )
		divider:SetRightMin( 250 )
		divider:SetCookieName( "PlayerModelSelectorDivider" )

		--
		-- Model preview
		--
		local mdl = divider:Add( "DModelPanel" )
		divider:SetLeft( mdl )

		-- Undo defaults
		mdl:SetDirectionalLight( BOX_FRONT, nil )
		mdl:SetDirectionalLight( BOX_TOP, nil )
		mdl:SetAmbientLight( Color( 32, 32, 32 ) ) -- Still show the phong a little

		mdl:SetAnimated( true )
		mdl.Angles = angle_zero
		mdl:SetLookAt( Vector( 0, 0, 37 ) )
		mdl:SetCamPos( Vector( 100, 0, 59 ) )

		local sheet = divider:Add( "DPropertySheet" )
		sheet:SetWide( window:GetWide() / 2 )
		divider:SetRight( sheet )

		--
		-- Model List
		--
		local modelListPnl = window:Add( "DPanel" )
		modelListPnl:DockPadding( 8, 8, 8, 8 )

		local SearchBar = modelListPnl:Add( "DTextEntry" )
		SearchBar:Dock( TOP )
		SearchBar:DockMargin( 0, 0, 0, 8 )
		SearchBar:SetUpdateOnType( true )
		SearchBar:SetPlaceholderText( Phrase( "#spawnmenu.quick_filter" ) )

		local PanelSelect = modelListPnl:Add( "DPanelSelect" )
		PanelSelect:Dock( FILL )

		local categorized = {}

		--- DELTA: populating is a function, not a one-shot loop.  The window can be
		--- built before the models/player scan (hl2sb_playermodels.lua) has finished;
		--- the hook below re-pulls when the scan announces its rebuild.
		local function PopulateModelList()
			if ( not IsValid( PanelSelect ) or not IsValid( SearchBar ) ) then return end

			PanelSelect:CleanList()
			categorized = {}

			for name, info in pairs( GetModelList() ) do
				local catName = Phrase( info.category or "#spawnmenu.category.other" )

				categorized[ catName ] = categorized[ catName ] or {}
				table.insert( categorized[ catName ], { title = Phrase( info.title ), model = info.model, name = name } )
			end

			-- HL2SB (2026-09-27, TEMPORARY DIAG): dump the categorization to
			-- data/hl2sb_modellist_debug.txt so a missing category can be checked
			-- against the data directly.  Remove once the list is confirmed.
			if ( file and file.Write ) then
				local nTotal = 0
				local diag = {}

				for cname, citems in SortedPairs( categorized ) do
					diag[ #diag + 1 ] = string.format( "%s = %d", cname, #citems )
					nTotal = nTotal + #citems
				end

				file.Write( "hl2sb_modellist_debug.txt",
					"total=" .. tostring( nTotal ) .. "\n" .. table.concat( diag, "\n" ) .. "\n" )
			end

			-- DELTA: cells stream in a few per frame instead of ~100 SpawnIcon:SetModel()
			-- calls in one frame (each loads and renders a .mdl).  The LABELS go
			-- through the same queue, because the queue must create cells in the
			-- display order -- labels created first and icons appended later would
			-- pile every category heading at the top of the list.
			local queue = {}

			for catName, items in SortedPairs( categorized ) do

				queue[ #queue + 1 ] = { label = catName }

				for _, info in SortedPairsByMemberValue( items, "title" ) do
					queue[ #queue + 1 ] = { info = info }
				end

			end

			local TIMER = "HL2SB_PlayerModelIcons"

			if ( timer.Exists ~= nil and timer.Exists( TIMER ) ) then
				timer.Remove( TIMER )
			end

			local pos = 0
			local fillErrors = 0

			timer.Create( TIMER, 0, 0, function()
				if ( not IsValid( PanelSelect ) ) then
					timer.Remove( TIMER )
					return
				end

				local batch = 0

				while ( batch < 4 and pos < #queue ) do
					pos = pos + 1
					batch = batch + 1

					local item = queue[ pos ]

					-- HL2SB: one broken entry must not kill the fill timer --
					-- the engine removes an erroring timer outright, which used
					-- to truncate the whole list after the failing item (the
					-- "there is no Other category" report).
					local okItem, errItem = pcall( function()

						if ( item.label ) then

							local label = vgui.Create( "DLabel" )
							label:SetFont( "DermaLarge" )
							label:SetText( item.label )
							label:SetTall( 32 )
							label:SetDark( true )
							label:SizeToContentsX()
							label.m_strLineState = "ownline"
							PanelSelect:AddPanel( label )
							label.DoClick = function() end -- Unselectable

						else

							local info = item.info

							local icon = vgui.Create( "SpawnIcon" )
							icon:SetModel( info.model )
							icon:SetSize( 64, 64 )
							icon:SetTooltip( info.title )
							icon.playermodel = info.name
							icon.model_path = info.model
							icon.OpenMenu = function( button )
								local menu = DermaMenu()
								menu:AddOption( Phrase( "#spawnmenu.menu.copy" ), function() SetClipboardText( info.model ) end )
									:SetIcon( "icon16/page_copy.png" )
								menu:Open()
							end

							-- DELTA: GMod passes { cl_playermodel = info.name }; this fork's server
							-- reads cl_playermodel as a model path, so the path goes in.
							PanelSelect:AddPanel( icon, { cl_playermodel = info.model } )

						end
					end )

					if ( not okItem ) then
						fillErrors = fillErrors + 1
						if ( fillErrors == 1 ) then
							Msg( "[HL2SB] model list entry failed: " .. tostring( errItem ) .. "\n" )
						end
					end
				end

				if ( pos >= #queue ) then
					timer.Remove( TIMER )

					Msg( "[HL2SB] model list filled: " .. tostring( #queue ) .. " entries, "
						.. tostring( fillErrors ) .. " failed\n" )

					-- HL2SB (2026-09-27, TEMPORARY DIAG 2): dump what ACTUALLY got
					-- created and where it sits, so a missing category can be traced
					-- to creation vs layout.  Remove with the other diag block.
					if ( file and file.Write and file.Append and PanelSelect.GetItems ) then
						local items = PanelSelect:GetItems()
						local out = { "created=" .. tostring( #items ) .. " / queued=" .. tostring( #queue ) }

						local canvas = ( PanelSelect.GetCanvas and PanelSelect:GetCanvas() ) or nil
						out[ #out + 1 ] = "canvasTall=" .. tostring( canvas and canvas.GetTall and canvas:GetTall() or -1 )

						for i = 1, #items do
							local p = items[ i ]
							local x, y = p:GetPos()
							out[ #out + 1 ] = string.format( "%d %s x=%s y=%s vis=%s",
								i, tostring( p.ClassName ), tostring( x ), tostring( y ),
								tostring( p.IsVisible ~= nil and p:IsVisible() or "?" ) )
						end

						file.Append( "hl2sb_modellist_debug.txt", table.concat( out, "\n" ) .. "\n" )
					end

					-- Icons that arrived after the last keystroke need the filter applied.
					if ( SearchBar.OnValueChange ~= nil ) then
						SearchBar.OnValueChange( SearchBar, SearchBar:GetText() or "" )
					end
				end
			end )

			-- Re-apply the search filter: freshly built items are all visible.
			if ( SearchBar.OnValueChange ~= nil ) then
				SearchBar.OnValueChange( SearchBar, SearchBar:GetText() or "" )
			end
		end

		PopulateModelList()

		-- DELTA: the autorun scan announces every rebuild; pull the new models in even
		-- while this window is closed, so the next open shows them.
		if ( hook ~= nil and hook.Add ~= nil ) then
			hook.Add( "HL2SB_PlayerModelsBuilt", "HL2SB_PlayerModelEditor", PopulateModelList )
		end

		SearchBar.OnValueChange = function( _, str )
			str = string.lower( str or "" )

			for _, pnl in pairs( PanelSelect:GetItems() ) do
				if ( pnl.playermodel == nil ) then
					pnl:SetVisible( str == "" )
					continue
				end

				if ( not string.find( string.lower( pnl.playermodel ), str, 1, true )
					and not string.find( string.lower( pnl.model_path ), str, 1, true )
					and not string.find( string.lower( pnl:GetTooltip() or "" ), str, 1, true ) ) then
					pnl:SetVisible( false )
				else
					pnl:SetVisible( true )
				end
			end

			PanelSelect:InvalidateLayout()
		end

		sheet:AddSheet( Phrase( "#smwidget.model" ), modelListPnl, "icon16/user.png" )

		--
		-- Colors
		--
		local colorPickerSize = math.min( window:GetTall() / 3, 260 )

		local controlsTop = window:Add( "DPanel" )
		controlsTop:DockPadding( 8, 8, 8, 8 )

		local plycol = controlsTop:Add( "DColorMixer" )
		plycol:Dock( TOP )
		plycol:SetLabel( Phrase( "#smwidget.color_plr" ) )
		plycol:SetTall( colorPickerSize )
		plycol:SetAlphaBar( false )
		plycol:SetPaletteName( "plrmdlslct_ply_clr" )
		SetDefaultColorFromConVar( plycol, "cl_playercolor" )

		local wepcol = controlsTop:Add( "DColorMixer" )
		wepcol:Dock( TOP )
		wepcol:DockMargin( 0, 32, 0, 0 )
		wepcol:SetLabel( Phrase( "#smwidget.color_wep" ) )
		wepcol:SetTall( colorPickerSize )
		wepcol:SetVector( Vector( GetConVarString( "cl_weaponcolor" ) ) )
		wepcol:SetAlphaBar( false )
		wepcol:SetPaletteName( "plrmdlslct_wep_clr" )
		SetDefaultColorFromConVar( wepcol, "cl_weaponcolor" )

		sheet:AddSheet( Phrase( "#smwidget.colors" ), controlsTop, "icon16/color_wheel.png" )

		--
		-- Bodygroups
		--
		local bgControls = window:Add( "DPanel" )
		bgControls:DockPadding( 8, 8, 8, 8 )

		local bdcontrolspanel = bgControls:Add( "DPanelList" )
		bdcontrolspanel:EnableVerticalScrollbar()
		bdcontrolspanel:Dock( FILL )

		local bgTab = sheet:AddSheet( Phrase( "#smwidget.bodygroups" ), bgControls, "icon16/cog.png" )

		-- Helper functions
		local function PlayPreviewAnimation( panel, playermodel )

			if ( not panel or not IsValid( panel.Entity ) ) then return end

			local anim = default_animations[ math.random( 1, #default_animations ) ]

			local anims = list.GetEntry( "PlayerOptionsAnimations", playermodel )
			if ( anims ) then
				anim = anims[ math.random( 1, #anims ) ]
			end

			local iSeq = panel.Entity:LookupSequence( anim )
			if ( iSeq and iSeq > 0 ) then panel.Entity:ResetSequence( iSeq ) end

		end

		-- Updating
		local function UpdateBodyGroups( pnl, val )
			-- DELTA: the preview entity only exists when the model loaded.
			if ( not IsValid( mdl.Entity ) ) then return end

			if ( pnl.type == "bgroup" ) then

				mdl.Entity:SetBodygroup( pnl.typenum, math.floor( val ) )

				local str = string.Explode( " ", GetConVarString( "cl_playerbodygroups" ) )
				if ( #str < pnl.typenum + 1 ) then for i = 1, pnl.typenum + 1 do str[ i ] = str[ i ] or "0" end end
				str[ pnl.typenum + 1 ] = tostring( math.floor( val ) )
				RunConsoleCommand( "cl_playerbodygroups", table.concat( str, " " ) )

			elseif ( pnl.type == "skin" ) then

				mdl.Entity:SetSkin( math.floor( val ) )
				RunConsoleCommand( "cl_playerskin", tostring( math.floor( val ) ) )

			end
		end

		local function RebuildBodygroupTab()
			bdcontrolspanel:Clear()

			bgTab.Tab:SetVisible( false )

			-- DELTA: nothing to read the bodygroups from when the model failed to load
			-- (DModelPanel warns once and leaves Entity nil).
			if ( not IsValid( mdl.Entity ) ) then return end

			local nskins = mdl.Entity:SkinCount() - 1
			if ( nskins > 0 ) then
				local skins = vgui.Create( "DNumSlider" )
				skins:Dock( TOP )
				skins:SetText( "Skin" )
				skins:SetDark( true )
				skins:SetTall( 50 )
				skins:SetDecimals( 0 )
				skins:SetMax( nskins )
				skins:SetValue( GetConVarNumber( "cl_playerskin" ) )
				skins.type = "skin"
				skins.OnValueChanged = UpdateBodyGroups

				bdcontrolspanel:AddItem( skins )

				mdl.Entity:SetSkin( GetConVarNumber( "cl_playerskin" ) )

				bgTab.Tab:SetVisible( true )
			end

			local groups = string.Explode( " ", GetConVarString( "cl_playerbodygroups" ) )
			for k = 0, mdl.Entity:GetNumBodyGroups() - 1 do
				if ( mdl.Entity:GetBodygroupCount( k ) <= 1 ) then continue end

				local bgroup = vgui.Create( "DNumSlider" )
				bgroup:Dock( TOP )
				bgroup:SetText( string.NiceName( mdl.Entity:GetBodygroupName( k ) ) )
				bgroup:SetDark( true )
				bgroup:SetTall( 50 )
				bgroup:SetDecimals( 0 )
				bgroup.type = "bgroup"
				bgroup.typenum = k
				bgroup:SetMax( mdl.Entity:GetBodygroupCount( k ) - 1 )
				bgroup:SetValue( tonumber( groups[ k + 1 ] ) or 0 )
				bgroup.OnValueChanged = UpdateBodyGroups

				bdcontrolspanel:AddItem( bgroup )

				mdl.Entity:SetBodygroup( k, tonumber( groups[ k + 1 ] ) or 0 )

				bgTab.Tab:SetVisible( true )
			end

			sheet.tabScroller:InvalidateLayout()
		end

		--- DELTA: true while UpdateFromConvars() is pushing the stored values into the
		--- two mixers.  GMod initialises both mixers from the same two convars BEFORE
		--- the callbacks are wired, so its cross-write is a no-op; here the callbacks
		--- can fire during a partial refresh and would push the other mixer's stale
		--- value into its convar ("opening the menu changes my colour").
		local bUpdatingFromConvars = false

		local function UpdateFromConvars()

			if ( not IsValid( mdl ) ) then return end

			local model = LocalPlayer():GetInfo( "cl_playermodel" )
			local modelname = player_manager.TranslatePlayerModel( model )
			util.PrecacheModel( modelname )
			mdl:SetModel( modelname )

			-- DELTA: the entity only exists when the model actually loaded.
			if ( IsValid( mdl.Entity ) ) then
				mdl.Entity.GetPlayerColor = function() return Vector( GetConVarString( "cl_playercolor" ) ) end

				PlayPreviewAnimation( mdl, model )
				RebuildBodygroupTab()
			end

			bUpdatingFromConvars = true

			plycol:SetVector( Vector( GetConVarString( "cl_playercolor" ) ) )
			wepcol:SetVector( Vector( GetConVarString( "cl_weaponcolor" ) ) )

			bUpdatingFromConvars = false

		end

		--- DELTA: each mixer writes exactly its own convar (GMod writes both from both
		--- callbacks), so the player colour and the weapon colour can never bleed into
		--- each other.  And the components are formatted explicitly -- GMod relies on
		--- Vector __tostring being bare "r g b", which this fork's is not.
		local function UpdateFromControls( panel )

			-- Programmatic refresh (window open, model switch): never write back.
			if ( bUpdatingFromConvars ) then return end

			local v = panel:GetVector()

			RunConsoleCommand( ( panel == wepcol ) and "cl_weaponcolor" or "cl_playercolor",
				string.format( "%f %f %f", v.x, v.y, v.z ) )

		end

		plycol.ValueChanged = function() UpdateFromControls( plycol ) end
		wepcol.ValueChanged = function() UpdateFromControls( wepcol ) end

		function PanelSelect:OnActivePanelChanged( old, new )

			if ( old ~= new ) then -- Only reset if we changed the model
				-- DELTA: a full row of zeros -- GMod writes "0", but the fork's server
				-- reads that as "bodygroup 0 = 0" and keeps the rest of the old model's
				-- bodygroups; it walks the string until it runs out.
				RunConsoleCommand( "cl_playerbodygroups", "0 0 0 0 0 0 0 0" )
				RunConsoleCommand( "cl_playerskin", "0" )
			end

			timer.Simple( 0.1, function() UpdateFromConvars() end )

		end

		-- Hold to rotate

		function mdl:DragMousePress( btnId )
			if ( btnId ~= MOUSE_LEFT and btnId ~= MOUSE_RIGHT and btnId ~= MOUSE_MIDDLE ) then return end

			self.PressX, self.PressY = input.GetCursorPos()
			self.Pressed = btnId
		end

		function mdl:DragMouseRelease() self.Pressed = nil end

		function mdl:PreDrawModel()
			self.LocalLights = {
				-- left
				{
					type = MATERIAL_LIGHT_POINT,
					pos = Vector( 0, -100, 72 + math.sin( CurTime() * 1 + 5 ) * 90 ),
					color = Vector( 0.3, 0.6, 1 )
				},
				-- right
				{
					type = MATERIAL_LIGHT_POINT,
					pos = Vector( 0, 100, 72 + math.sin( CurTime() * 1 + 9 ) * 90 ),
					color = Vector( 1, 0.6, 0.3 )
				},
				-- front
				{
					type = MATERIAL_LIGHT_POINT,
					pos = Vector( 100, 0, 60 + math.sin( CurTime() * 1 ) * 90 ),
					color = Vector( 1, 1, 1 )
				}
			}

			-- Use local lights as it produces much better looking rendering than the light box
			if ( not bPreviewLightsOff ) then
				render.SetLocalModelLights( self.LocalLights )
			end

			-- DELTA: consistent preview regardless of map location -- guarded, the
			-- binding is only in engine builds that ship it (DModelPanel:Paint clears
			-- it again after the draw).
			if ( render.BindLocalCubemap ) then render.BindLocalCubemap( "editor/cubemap" ) end

			return true
		end

		mdl.StoredFOV = 47
		mdl:SetFOV( mdl.StoredFOV )

		function mdl:LayoutEntity( ent )
			-- DELTA: deliberately NOT tinted here -- DModelPanel:Paint feeds colColor to
			-- render.SetColorModulation() and the studio renderer writes that into
			-- $color2 for EVERY material, which would tint the FACE and HANDS of models
			-- whose clothes have no $color2.  GMod's colour reaches only materials whose
			-- VMTs declare the PlayerColor proxy; the preview must do the same.
			if ( self.bAnimated ) then self:RunAnimation() end

			if ( self.Pressed ) then
				local mx, my = input.GetCursorPos()

				if ( self.Pressed == MOUSE_LEFT ) then
					self.Angles = self.Angles - Angle( 0, ( ( self.PressX or mx ) - mx ) / 2, 0 )
				end

				self.PressX, self.PressY = mx, my

			end

			ent:SetAngles( self.Angles )

			-- Not ideal, but handles resizing the panel well enough
			self:SetFOV( self.StoredFOV * math.min( mdl:GetWide() / mdl:GetTall(), 2.5 ) )

			-- GMod: the eyes follow the camera.  DELTA: inert here -- no
			-- CIKContext::SetEyeTarget in this engine (guarded, entity may be nil).
			if ( IsValid( mdl.Entity ) ) then
				mdl.Entity:SetEyeTarget( mdl:GetCamPos() )
			end

		end

		--[[ DELTA: LAST, and deliberately so.  GMod calls UpdateFromConvars() in the
		     middle of this list; here a failure in the model setup must not take the
		     interactive parts below it with it (that ordering bug once defined neither
		     OnActivePanelChanged nor the drag handlers, and the window just quietly
		     was not the editor). ]]
		UpdateFromConvars()

	end
} )

-- ---------------------------------------------------------------------------
-- Opening (GMod's concommand walks g_ContextMenu.DesktopWidgets; there is no
-- context-menu widget grid in this fork, so the window is built directly and
-- the registered init is invoked -- the same call a widget icon would make).
-- ---------------------------------------------------------------------------
local ActiveWindow = nil

local function OpenPlayerEditor()
	-- A second press closes the window (GMod closes with the frame's X / Escape,
	-- but a keybind needs a way back out).
	if ( IsValid( ActiveWindow ) ) then
		if ( ActiveWindow:IsVisible() ) then
			ActiveWindow:Close()
		else
			ActiveWindow:SetVisible( true )
			ActiveWindow:MakePopup()
		end

		return ActiveWindow
	end

	local window = vgui.Create( "DFrame" )
	if ( not window ) then return nil end

	window:MakePopup()
	window:SetDeleteOnClose( true )

	local editor = list.GetEntry( "DesktopWindows", "PlayerEditor" )

	if ( editor and editor.init ) then
		editor.init( nil, window )
	else
		window:Remove()
		return nil
	end

	ActiveWindow = window
	return window
end

concommand.Create( "open_playermodel_selector", OpenPlayerEditor )
concommand.Create( "hl2sb_playermodel_gmod", OpenPlayerEditor )

-- HL2SB (2026-09-27, perf): toggle for the preview's three swinging point
-- lights -- see the note at bPreviewLightsOff above.
concommand.Create( "hl2sb_preview_lights", function()
	bPreviewLightsOff = not bPreviewLightsOff
	Msg( "[HL2SB] preview local lights: " .. ( bPreviewLightsOff and "OFF (fast)" or "ON (GMod rig)" ) .. "\n" )
end )

-- ---------------------------------------------------------------------------
-- GMod's per-player-model preview animations (file tail, verbatim)
-- ---------------------------------------------------------------------------
list.Set( "PlayerOptionsAnimations", "gman", { "menu_gman" } )

list.Set( "PlayerOptionsAnimations", "hostage01", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage02", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage03", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage04", { "idle_all_scared" } )

list.Set( "PlayerOptionsAnimations", "zombine", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "corpse", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "zombiefast", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "zombie", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "skeleton", { "menu_zombie_01" } )

list.Set( "PlayerOptionsAnimations", "combine", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "combineprison", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "combineelite", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "police", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "policefem", { "menu_combine" } )

list.Set( "PlayerOptionsAnimations", "css_arctic", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_gasmask", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_guerilla", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_leet", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_phoenix", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_riot", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_swat", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_urban", { "pose_standing_02", "idle_fist" } )
