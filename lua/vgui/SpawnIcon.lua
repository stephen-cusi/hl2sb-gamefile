--[[ SpawnIcon -- a spawn-menu model thumbnail (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/SpawnIcon
	  "A button with a model on it. Loads the model icon from GMod's spawnmenu
	  icon cache."  Parent: DButton.  SetModel( mdl, skin, bodygroups ),
	  SetSpawnIcon( name ), RebuildSpawnIcon / RebuildSpawnIconEx, SetSkinID /
	  GetSkinID, SetBodyGroup / GetBodyGroup, SetModelName / GetModelName,
	  SetIconName / GetIconName, ToTable( bigtable ), Copy, SkinChanged,
	  BodyGroupChanged, and the DoRightClick / OpenMenu hooks.

	Ported from GMod's lua/vgui/spawnicon.lua (360 lines).  DModelSelect and
	DModelSelectMulti (below, this batch) build their thumbnails out of it.

	Substitutions this fork needs (all documented in place below):
	  * GMod's thumbnail is a "ModelImage" panel - a control its ENGINE provides.
	    This fork registers the same factory name on its scripted CModelPanel
	    (game/client/lua/scripted_controls/lModelPanel.cpp:752
	    `{"ModelImage", luasrc_ModelPanel}`), so `vgui.Create( "ModelImage" )`
	    works, but the panel it hands back exposes SetModel/SetYaw/SetZoom/SetFOV/
	    RefitCamera (lModelPanel.cpp:721-733) and NOT SetSpawnIcon /
	    RebuildSpawnIcon / SetModelImage - those live in the gmod_compatibility
	    shim, which this fork never loads.  Every call to them is guarded, and
	    SetSpawnIcon falls back to treating the name as a model path (which is what
	    this fork's own spawn menu stores anyway).
	  * GMod's hover overlay is `GWEN.CreateTextureBorder` over
	    materials/gui/sm_hover.png.  There is no GWEN library here (only comments
	    about it), so PaintOver draws the same white border with surface.* - the
	    fade (OverlayFade in Think/OnThink) is GMod's.
	  * `self:SetDoubleClickingEnabled( false )` is a GMod DButton method with no
	    equivalent here; the call is guarded.
	  * The final `spawnmenu.AddContentType( "model", ... )` block is kept, but it
	    is registered only when that global exists, and the container call accepts
	    either `container:Add` (GMod) or `container:AddItem` (this fork's
	    spawnmenu.lua documents AddItem).
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_strModelName", "ModelName" )
AccessorFunc( PANEL, "m_iSkin", "SkinID" )
AccessorFunc( PANEL, "m_strBodyGroups", "BodyGroup" )
AccessorFunc( PANEL, "m_strIconName", "IconName" )

function PANEL:Init()
	if ( self.SetDoubleClickingEnabled ) then
		self:SetDoubleClickingEnabled( false )
	end

	self:SetText( "" )

	self.Icon = vgui.Create( "ModelImage", self )

	if ( IsValid( self.Icon ) ) then
		self.Icon:SetMouseInputEnabled( false )
		self.Icon:SetKeyboardInputEnabled( false )
	end

	self:SetSize( 64, 64 )

	self.m_strBodyGroups = "000000000"
	self.OverlayFade = 0
end

function PANEL:DoRightClick()
	local pCanvas = self:GetSelectionCanvas()

	if ( IsValid( pCanvas ) and pCanvas:NumSelectedChildren() > 0 and self:IsSelected() ) then
		return hook.Run( "SpawnlistOpenGenericMenu", pCanvas )
	end

	self:OpenMenu()
end

function PANEL:DoClick()
end

function PANEL:OpenMenu()
end

function PANEL:Paint( w, h )
	-- Do not draw the default background
end

--- GMod's Think (see the header for the OnThink bridge this engine needs).
function PANEL:OnThink()
	self.OverlayFade = math.Clamp( self.OverlayFade - RealFrameTime() * 640 * 2, 0, 255 )

	if ( dragndrop.IsDragging() or !self:IsHovered() ) then return end

	self.OverlayFade = math.Clamp( self.OverlayFade + RealFrameTime() * 640 * 8, 0, 255 )
end

function PANEL:Think()
	self:OnThink()
end

local border = 4
local border_w = 5
local matHover = Material( "gui/sm_hover.png", "nocull" )

-- GMod: GWEN.CreateTextureBorder( ... ).  No GWEN in this fork, so the border is
-- painted with surface.* instead (see PaintOver).
local boxHover = nil

if ( GWEN and GWEN.CreateTextureBorder and matHover ) then
	boxHover = GWEN.CreateTextureBorder( border, border, 64 - border * 2, 64 - border * 2,
		border_w, border_w, border_w, border_w, matHover )
end

function PANEL:PaintOver( w, h )
	if ( self.OverlayFade > 0 ) then
		local alpha = self.OverlayFade

		if ( boxHover ) then
			boxHover( 0, 0, w, h, Color( 255, 255, 255, alpha ) )
		else
			-- the built-in stand-in: GMod's sm_hover texture is a 5px white frame
			surface.SetDrawColor( 255, 255, 255, alpha )

			for i = 0, border_w - 1 do
				surface.DrawOutlinedRect( i, i, w - i, h - i )
			end
		end
	end

	self:DrawSelections()
end

function PANEL:PerformLayout()
	if ( not IsValid( self.Icon ) ) then return end

	if ( self:IsDown() && !self.Dragging ) then
		self.Icon:StretchToParent( 6, 6, 6, 6 )
	else
		self.Icon:StretchToParent( 0, 0, 0, 0 )
	end
end

function PANEL:OnSizeChanged( newW, newH )
	if ( IsValid( self.Icon ) ) then
		self.Icon:SetSize( newW, newH )
	end
end

function PANEL:SetSpawnIcon( name )
	self.m_strIconName = name

	if ( not IsValid( self.Icon ) ) then return end

	if ( self.Icon.SetSpawnIcon ) then
		-- GMod: the spawn-menu icon cache names the thumbnail
		self.Icon:SetSpawnIcon( name )
	elseif ( self.Icon.SetModel ) then
		-- this fork: no icon cache, so the name is the model itself
		self.Icon:SetModel( name )
	end
end

function PANEL:SetBodyGroup( k, v )
	if ( k < 0 ) then return end
	if ( k > 9 ) then return end
	if ( v < 0 ) then return end
	if ( v > 9 ) then return end

	self.m_strBodyGroups = self.m_strBodyGroups:SetChar( k + 1, v )
end

function PANEL:SetModel( mdl, iSkin, BodyGroups )
	if ( !mdl ) then debug.Trace() return end

	self:SetModelName( mdl )
	self:SetSkinID( iSkin or 0 )

	if ( tostring( BodyGroups ):len() != 9 ) then
		BodyGroups = "000000000"
	end

	self.m_strBodyGroups = BodyGroups

	if ( IsValid( self.Icon ) ) then
		self.Icon:SetModel( mdl, iSkin, BodyGroups )
	end

	if ( iSkin && iSkin > 0 ) then
		self:SetTooltip( string.format( "%s (Skin %i)", mdl, iSkin + 1 ) )
	else
		self:SetTooltip( string.format( "%s", mdl ) )
	end
end

function PANEL:RebuildSpawnIcon()
	if ( IsValid( self.Icon ) and self.Icon.RebuildSpawnIcon ) then
		self.Icon:RebuildSpawnIcon()
	end

	-- this fork's ModelImage (the engine's CModelPanel) re-renders every frame, so
	-- there is nothing to invalidate here
end

function PANEL:RebuildSpawnIconEx( t )
	if ( IsValid( self.Icon ) and self.Icon.RebuildSpawnIconEx ) then
		self.Icon:RebuildSpawnIconEx( t )
	end
end

function PANEL:ToTable( bigtable )
	local tab = {}

	tab.type = "model"
	tab.model = self:GetModelName()

	if ( self:GetSkinID() != 0 ) then
		tab.skin = self:GetSkinID()
	end

	if ( self:GetBodyGroup() != "000000000" ) then
		tab.body = "B" .. self:GetBodyGroup()
	end

	if ( self:GetWide() != 64 ) then
		tab.wide = self:GetWide()
	end

	if ( self:GetTall() != 64 ) then
		tab.tall = self:GetTall()
	end

	table.insert( bigtable, tab )
end

function PANEL:Copy()
	local copy = vgui.Create( "SpawnIcon", self:GetParent() )
	copy:SetModel( self:GetModelName(), self:GetSkinID() )
	copy:CopyBase( self )
	copy.DoClick = self.DoClick
	copy.OpenMenu = self.OpenMenu
	copy.OpenMenuExtra = self.OpenMenuExtra

	if ( self.GetTooltip ) then
		copy:SetTooltip( self:GetTooltip() )
	end

	return copy
end

-- Icon has been editied, they changed the skin
-- what should we do?
function PANEL:SkinChanged( i )
	-- This is called from Icon Editor. Mark the spawnlist as changed. Ideally this would check for GetTriggerSpawnlistChange on the parent
	hook.Run( "SpawnlistContentChanged" )

	-- Change the skin, and change the model
	-- this way we can edit the spawnmenu....
	self:SetSkinID( i )
	self:SetModel( self:GetModelName(), self:GetSkinID(), self:GetBodyGroup() )
end

function PANEL:BodyGroupChanged( k, v )
	-- This is called from Icon Editor. Mark the spawnlist as changed. Ideally this would check for GetTriggerSpawnlistChange on the parent
	hook.Run( "SpawnlistContentChanged" )

	self:SetBodyGroup( k, v )
	self:SetModel( self:GetModelName(), self:GetSkinID(), self:GetBodyGroup() )
end

-- A little hack to prevent code duplication
function PANEL:InternalAddResizeMenu( menu, callback, label )
	-- GMod's DMenu has AddSubMenu; this fork's DMenu does not (lua/vgui/DMenu.lua),
	-- so the resize submenu is skipped rather than throwing.
	if ( not menu.AddSubMenu ) then return end

	local submenu_r, submenu_r_option = menu:AddSubMenu( label or "#spawnmenu.menu.resize", function() end )
	submenu_r_option:SetIcon( "icon16/arrow_out.png" )

	-- Generate the sizes
	local function AddSizeOption( submenu, w, h, curW, curH )
		local p = submenu:AddOption( w .. " x " .. h, function() callback( w, h ) end )
		if ( w == ( curW or 64 ) && h == ( curH or 64 ) ) then p:SetChecked( true ) end
	end

	local sizes = { 64, 128, 256, 512 }

	for id, size in pairs( sizes ) do
		for _, size2 in pairs( sizes ) do
			AddSizeOption( submenu_r, size, size2, self:GetWide(), self:GetTall() )
		end

		if ( id <= #sizes - 1 ) then
			submenu_r:AddSpacer()
		end
	end
end

derma.DefineControl( "SpawnIcon", "A spawn menu model thumbnail", PANEL, "DButton" )

--
-- Action on creating a model from the spawnlist
--

if ( spawnmenu and spawnmenu.AddContentType ) then
	spawnmenu.AddContentType( "model", function( container, obj )
		if ( !isstring( obj.model ) ) then obj.model = "" end

		local icon = vgui.Create( "SpawnIcon", container )

		if ( obj.body ) then
			obj.body = string.Trim( tostring( obj.body ), "B" )
		end

		if ( obj.wide ) then
			icon:SetWide( obj.wide )
		end

		if ( obj.tall ) then
			icon:SetTall( obj.tall )
		end

		icon:InvalidateLayout( true )

		icon:SetModel( obj.model, obj.skin or 0, obj.body )

		icon:SetTooltip( string.Replace( string.GetFileFromFilename( obj.model ), ".mdl", "" ) )

		icon.DoClick = function( s )
			surface.PlaySound( "ui/buttonclickrelease.wav" )
			RunConsoleCommand( "gm_spawn", s:GetModelName(), s:GetSkinID() or 0, s:GetBodyGroup() or "" )
		end

		icon.OpenMenu = function( pnl )
			-- Use the containter that we are dragged onto, not the one we were created on
			if ( pnl:GetParent() && pnl:GetParent().ContentContainer ) then
				container = pnl:GetParent().ContentContainer
			end

			local menu = DermaMenu()
			menu:AddOption( "#spawnmenu.menu.copy", function() SetClipboardText( string.gsub( icon:GetModelName(), "\\", "/" ) ) end ):SetIcon( "icon16/page_copy.png" )

			menu:AddOption( "#spawnmenu.menu.spawn_with_toolgun", function()
				RunConsoleCommand( "gmod_tool", "creator" )
				RunConsoleCommand( "creator_type", "4" )
				RunConsoleCommand( "creator_name", icon:GetModelName() )
				RunConsoleCommand( "creator_override", table.concat( { icon:GetSkinID(), icon:GetBodyGroup() }, " " ) )
			end ):SetIcon( "icon16/brick_add.png" )

			local submenu, submenu_opt = menu:AddSubMenu( "#spawnmenu.menu.rerender", function()
				if ( IsValid( pnl ) ) then pnl:RebuildSpawnIcon() end
			end )
			submenu_opt:SetIcon( "icon16/picture_save.png" )

			submenu:AddOption( "#spawnmenu.menu.rerender_this", function()
				if ( IsValid( pnl ) ) then pnl:RebuildSpawnIcon() end
			end ):SetIcon( "icon16/picture.png" )
			submenu:AddOption( "#spawnmenu.menu.rerender_all", function()
				if ( IsValid( container ) and container.RebuildAll ) then container:RebuildAll() end
			end ):SetIcon( "icon16/pictures.png" )

			menu:AddOption( "#spawnmenu.menu.edit_icon", function()
				if ( !IsValid( pnl ) ) then return end

				local editor = vgui.Create( "IconEditor" )
				if ( not editor ) then return end

				editor:SetIcon( pnl )
				editor:Refresh()
				editor:MakePopup()
				editor:Center()
			end ):SetIcon( "icon16/pencil.png" )

			if ( isfunction( pnl.OpenMenuExtra ) ) then
				pnl:OpenMenuExtra( menu )
			end

			hook.Run( "SpawnmenuIconMenuOpen", menu, pnl, "model" )

			-- Do not allow removal/size changes from read only panels
			if ( IsValid( pnl:GetParent() ) && pnl:GetParent().GetReadOnly && pnl:GetParent():GetReadOnly() ) then menu:Open() return end

			pnl:InternalAddResizeMenu( menu, function( w, h )
				if ( !IsValid( pnl ) ) then return end

				pnl:SetSize( w, h )
				pnl:InvalidateLayout( true )
				container:OnModified()
				container:Layout()
				pnl:SetModel( obj.model, obj.skin or 0, obj.body )
			end )

			menu:AddSpacer()
			menu:AddOption( "#spawnmenu.menu.delete", function()
				if ( !IsValid( pnl ) ) then return end

				pnl:Remove()
				hook.Run( "SpawnlistContentChanged" )
			end ):SetIcon( "icon16/bin_closed.png" )

			menu:Open()
		end

		icon:InvalidateLayout( true )

		if ( IsValid( container ) ) then
			-- GMod's content panel has Add; this fork's spawnmenu documents AddItem
			if ( container.Add ) then
				container:Add( icon )
			elseif ( container.AddItem ) then
				container:AddItem( icon )
			end
		end

		return icon
	end )
end
