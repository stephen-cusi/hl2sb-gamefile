--[[----------------------------------------------------------------------------
    hl2sb_playermodel_gmod.lua

    GMod's player model selector (the "PlayerEditor" desktop window), ported from

        garrysmod/gamemodes/sandbox/gamemode/editor_player.lua

    It is the same window: a DHorizontalDivider with a DModelPanel preview on the
    left and a DPropertySheet on the right holding three pages --

        Model       a quick filter box + a DPanelSelect of SpawnIcons, one per
                    player model, grouped by category
        Colors      two DColorMixers (player colour / weapon colour)
        Bodygroups  DNumSliders, one per bodygroup plus a skin slider

    The preview model can be dragged to rotate it and is lit by three coloured point
    lights that swing around it (mdl:PreDrawModel + render.SetLocalModelLights).

    Deviations from GMod's file, all of them forced by this fork:

      * Opening.  GMod registers a DesktopWindow (list.Set("DesktopWindows",
        "PlayerEditor", ...)) that the spawn menu's widget grid raises, and its
        concommand walks g_ContextMenu.DesktopWidgets.  Neither exists here, so the
        window is built directly; `open_playermodel_selector` (GMod's own command
        name) and `hl2sb_playermodel_gmod` (the name this fork's old menu used) both
        open it.  One window at a time, like GMod's `onewindow = true`.

      * Model data.  GMod reads player_manager.GetAllPlayerModels(); this fork's
        player_manager is fed from cfg/playermodel by
        lua/autorun/client/hl2sb_playermodels.lua, and this file also falls back to
        hl2sb.GetPlayerModels() directly if that has not run.

      * Selecting a model.  GMod does `PanelSelect:AddPanel( icon, { cl_playermodel
        = info.name } )` -- a player_manager name, which GMod's engine translates.
        This fork's server reads cl_playermodel as a model PATH
        (hl2sb_model_commands.cpp:63 writes pConfig->szPlayerModel, and
        hl2sb_player_model_manager.cpp feeds it to HL2SB_ApplyPlayerModel), so the
        path goes in: `{ cl_playermodel = info.model }`.

      * SetDefaultColorFromConVar.  GMod writes through `panel.HSV:SetDefaultColor`;
        this fork's DColorMixer has no HSV sub-object, so it uses SetColor +
        UpdateDefaultColor (which is what that fork-side baseline is called).

      * Localization.  GMod's "#smwidget.*" / "#spawnmenu.*" tokens live in
        resource/localization/<lang>/spawnmenu.properties, and this fork ships no
        localization directory, so the handful of phrases this window needs are
        registered with language.AddTable below (values copied from GMod's own
        English file).

      * mdl.Entity:SetEyeTarget( mdl:GetCamPos() ) is called exactly like GMod does,
        but this engine has no CIKContext::SetEyeTarget, so the eyes do not follow
        the camera - the binding says so once on the console (see
        game/shared/lua/lbaseentity_shared.cpp).

    Console commands:  open_playermodel_selector   /   hl2sb_playermodel_gmod
--]]----------------------------------------------------------------------------

--[[----------------------------------------------------------------------------
    NOTE ON THE "#token" STRINGS BELOW

    In GMod every one of these goes to the *engine* (DFrame's title bar, the tab
    captions, the text entry placeholder, DMenuOption's text), and the engine resolves
    "#token" through its localization files itself.  In this fork those texts are drawn
    by Lua (DFrame:Paint, DTab:Paint, DTextEntry's placeholder, DMenuOption's caption),
    so a raw token would be printed literally -- the first in-game run showed
    "#spawnmenu.quick_filter" in the search box.  Everything therefore goes through
    Phrase(), which looks the token up in the language table that this file registers
    below (and returns it unchanged when a token is genuinely missing).
--]]----------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- GMod's per-player-model preview animations
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

local default_animations = { "idle_all_01", "menu_walk" }

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
--- GMod: local function SetDefaultColorFromConVar( panel, convarName ).
--- Adapted for this fork's DColorMixer, which has no `HSV` sub-object: the default
--- goes in through SetColor, and UpdateDefaultColor() (no arguments here) makes it
--- the baseline the convar poll compares against.
local function SetDefaultColorFromConVar( panel, convarName )
	local cv = GetConVar( convarName )

	if ( not cv or not panel.SetColor ) then return end

	-- Vector( "r g b" ) is GMod's string overload, added to this fork's Vector()
	-- for exactly this call (public/lua/mathlib/lvector.cpp).
	local col = Vector( cv:GetDefault() ):ToColor()

	if ( col ) then
		panel:SetColor( col )

		if ( panel.UpdateDefaultColor ) then
			panel:UpdateDefaultColor()
		end
	end
end

--- Every player model this fork knows about: player_manager first (GMod's data
--- source, filled from cfg/playermodel by lua/autorun/client/hl2sb_playermodels.lua),
--- the engine's own list as a fallback.
local function GetModelList()
	local models = {}

	if ( _G.player_manager ~= nil and player_manager.GetAllPlayerModels ~= nil ) then
		local ok, data = pcall( player_manager.GetAllPlayerModels )

		if ( ok and istable( data ) ) then models = data end
	end

	if ( next( models ) == nil and _G.hl2sb ~= nil and hl2sb.GetPlayerModels ~= nil ) then
		local ok, data = pcall( hl2sb.GetPlayerModels )

		if ( ok and istable( data ) ) then
			for _, entry in ipairs( data ) do
				if ( type( entry ) == "table" and entry.name and entry.model ) then
					models[ entry.name ] = {
						model = entry.model,
						title = entry.name,
						category = "Other",
					}
				end
			end
		end
	end

	return models
end

-- ---------------------------------------------------------------------------
-- The window (GMod's list.Set( "DesktopWindows", "PlayerEditor", { init = ... } ))
-- ---------------------------------------------------------------------------
local function BuildEditor( window )
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
	-- Model list
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

	for name, info in pairs( GetModelList() ) do
		local catName = Phrase( info.category or "#spawnmenu.category.other" )

		categorized[ catName ] = categorized[ catName ] or {}
		table.insert( categorized[ catName ], { title = Phrase( info.title ), model = info.model, name = name } )
	end

	for catName, items in SortedPairs( categorized ) do

		local label = vgui.Create( "DLabel" )
		label:SetFont( "DermaLarge" )
		label:SetText( catName )
		label:SetTall( 32 )
		label:SetDark( true )
		label:SizeToContentsX()
		label.m_strLineState = "ownline"
		PanelSelect:AddPanel( label )
		label.DoClick = function() end -- Unselectable

		for _, info in SortedPairsByMemberValue( items, "title" ) do

			local icon = vgui.Create( "SpawnIcon" )
			icon:SetModel( info.model )
			icon:SetSize( 64, 64 )
			icon:SetTooltip( info.title )
			icon.playermodel = info.name
			icon.model_path = info.model
			icon.OpenMenu = function()
				local menu = DermaMenu()
				menu:AddOption( Phrase( "#spawnmenu.menu.copy" ), function() SetClipboardText( info.model ) end )
					:SetIcon( "icon16/page_copy.png" )
				menu:Open()
			end

			-- ⚠️ GMod passes { cl_playermodel = info.name }; this fork's server reads
			-- cl_playermodel as a model path, so the path goes in (see the header).
			PanelSelect:AddPanel( icon, { cl_playermodel = info.model } )

		end

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

	local function UpdateFromConvars()

		if ( not IsValid( mdl ) ) then return end

		local model = LocalPlayer():GetInfo( "cl_playermodel" )
		local modelname = player_manager.TranslatePlayerModel( model )
		util.PrecacheModel( modelname )
		mdl:SetModel( modelname )
		mdl.Entity.GetPlayerColor = function() return Vector( GetConVarString( "cl_playercolor" ) ) end

		plycol:SetVector( Vector( GetConVarString( "cl_playercolor" ) ) )
		wepcol:SetVector( Vector( GetConVarString( "cl_weaponcolor" ) ) )

		PlayPreviewAnimation( mdl, model )
		RebuildBodygroupTab()

	end

	local function UpdateFromControls()

		-- GMod writes tostring( plycol:GetVector() ), because its Vector __tostring is
		-- the bare "r g b" that its Vector( string ) overload reads back.  This fork's
		-- __tostring is "Vector: r g b" (public/lua/mathlib/lvector.cpp:372), which the
		-- server's sscanf( "%f %f %f" ) would read as 0 0 0 - every colour would come
		-- out black - so the components are formatted explicitly.
		local function ColorString( panel )
			local v = panel:GetVector()
			return string.format( "%f %f %f", v.x, v.y, v.z )
		end

		RunConsoleCommand( "cl_playercolor", ColorString( plycol ) )
		RunConsoleCommand( "cl_weaponcolor", ColorString( wepcol ) )

	end

	plycol.ValueChanged = UpdateFromControls
	wepcol.ValueChanged = UpdateFromControls

	UpdateFromConvars()

	function PanelSelect:OnActivePanelChanged( old, new )

		if ( old ~= new ) then -- Only reset if we changed the model
			-- GMod writes "0", which this fork's server reads as "bodygroup 0 = 0" and
			-- leaves the rest of the old model's bodygroups in place.  A full row of
			-- zeros clears them all (the server walks the string until it runs out).
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
		render.SetLocalModelLights( self.LocalLights )

		return true
	end

	mdl.StoredFOV = 47
	mdl:SetFOV( mdl.StoredFOV )

	function mdl:LayoutEntity( ent )
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

		-- GMod: the eyes follow the camera.  Accepted here, but inert: this engine has
		-- no CIKContext::SetEyeTarget (the binding prints one line about it).
		mdl.Entity:SetEyeTarget( mdl:GetCamPos() )

	end

	return window
end

-- ---------------------------------------------------------------------------
-- Opening (GMod's DesktopWindow + open_playermodel_selector)
-- ---------------------------------------------------------------------------
local ActiveWindow = nil

local function OpenPlayerEditor()
	if ( IsValid( ActiveWindow ) ) then
		ActiveWindow:SetVisible( true )
		ActiveWindow:MakePopup()
		return ActiveWindow
	end

	local window = vgui.Create( "DFrame" )
	if ( not window ) then return nil end

	window:SetSize( math.max( ScrW() * 0.8, 960 ), math.max( ScrH() * 0.8, 700 ) )
	window:MakePopup()
	window:SetDeleteOnClose( true )

	BuildEditor( window )

	ActiveWindow = window
	return window
end

concommand.Create( "open_playermodel_selector", OpenPlayerEditor )
concommand.Create( "hl2sb_playermodel_gmod", OpenPlayerEditor )
