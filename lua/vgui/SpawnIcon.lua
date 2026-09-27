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

-- ===========================================================================
-- HL2SB (perf): deferred model loading.
--
-- Creating the clientside model is the most expensive thing a cell does
-- (tens of ms each).  Building a big tab used to do 50+ of them back to
-- back and stuttered through the whole fill.  SetModel now only RECORDS the
-- model; LoadModel does the real work, queued from OnThink and pumped at
-- most one per tick, and only for cells that are actually on screen.
-- ===========================================================================
local g_LoadQueue = {}
local g_SnapshotReported = false
local g_SnapshotFailed = false
local g_NextLoad  = 0

-- ---------------------------------------------------------------------------
-- HL2SB (perf, 2026-09-27): the screen-bounds cull still rendered every cell
-- inside a SCROLLED list.  The player-model editor's DPanelSelect holds ~100
-- cells that all sit on screen (they are merely clipped by the scroll
-- viewport), so all ~100 live 3D thumbnails rendered every frame and the
-- window was unusable while open.  The real viewport is the nearest scrolling
-- list ancestor; cells outside it are skipped for rendering AND deferred for
-- loading (their next OnThink requeues them, so visible cells bubble to the
-- front of the load queue).
-- ---------------------------------------------------------------------------
local g_ClipClasses = {
	DPanelSelect	= true,
	DPanelList		= true,
	DScrollPanel	= true,
}

local function FindClipPanel( pnl )
	local p = pnl:GetParent()

	while ( IsValid( p ) ) do
		if ( p.ClassName and g_ClipClasses[ p.ClassName ] ) then return p end
		p = p:GetParent()
	end

	return nil
end

--- True when the cell's screen rect intersects its scrolling ancestor's rect.
--- Never-painted cells answer true (they load and render; the first Paint
--- corrects the flag within a frame).
local function IsInViewport( pnl, ax, ay, w, h )
	if ( pnl.m_ClipPanel == nil ) then
		pnl.m_ClipPanel = FindClipPanel( pnl ) or false
	end

	local clip = pnl.m_ClipPanel or nil
	if ( not IsValid( clip ) ) then return true end

	local cx, cy = clip:LocalToScreen( 0, 0 )
	local cw, ch = clip:GetWide(), clip:GetTall()

	if ( ay + h <= cy or ay >= cy + ch or ax + w <= cx or ax >= cx + cw ) then return false end

	return true
end

local function PumpModelLoads()
	if ( #g_LoadQueue == 0 ) then return end
	if ( RealTime() < g_NextLoad ) then return end

	local pnl = table.remove( g_LoadQueue, 1 )
	pnl.m_bQueued = nil

	if ( not IsValid( pnl ) ) then return end
	if ( pnl.m_bModelLoaded or pnl.m_bModelFailed ) then return end

	if ( pnl.IsVisible and not pnl:IsVisible() ) then return end	-- hidden tab/category: OnThink requeues when shown

	-- HL2SB: off-viewport cells wait in line (OnThink requeues them, so the
	-- visible ones always bubble to the front) -- opening a big list must not
	-- stream a hundred models the player is not looking at.
	if ( pnl.m_bInView == false ) then return end

	pnl:LoadModel()
	g_NextLoad = RealTime() + 0.04
end

function PANEL:Init()
	if ( self.SetDoubleClickingEnabled ) then
		self:SetDoubleClickingEnabled( false )
	end

	self:SetText( "" )

	-- HL2SB: the thumbnail renderer is the LUA DModelPanel, not the engine's
	-- ModelImage/CModelPanel.  The engine panel rendered only some models --
	-- weapons showed one cell in twenty, vehicles and most NPCs painted
	-- nothing at all, and big models bled outside the cell (no scissor) --
	-- while DModelPanel is the renderer the player-model selector proved:
	-- it draws every model, fits the camera, scissors to the panel and
	-- cleans its clientside entity up on remove.
	self.Icon = vgui.Create( "DModelPanel", self )
	if ( not IsValid( self.Icon ) ) then
		self.Icon = vgui.Create( "ModelImage", self )
	end

	if ( IsValid( self.Icon ) ) then
		self.Icon:SetMouseInputEnabled( false )
		self.Icon:SetKeyboardInputEnabled( false )
		-- thumbnails are static: no sequence processing per icon per frame
		if ( self.Icon.SetAnimated ) then self.Icon:SetAnimated( false ) end
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
	-- HL2SB: an opaque cell background so a model thumbnail reads as a cell
	-- (GMod's spawn icons sit on a dark tile), and a SCISSOR around the cell:
	-- the ModelImage child paints a live 3D model that knows nothing about
	-- this panel's bounds -- without the scissor a big model (an NPC, a
	-- vehicle) painted far outside its 64px cell, over the whole menu.
	-- PaintOver (which runs after the children) turns the scissor back off.
	surface.SetDrawColor( 45, 48, 52, 255 )
	surface.DrawRect( 0, 0, w, h )

	-- a model that never came up (missing file / error model): draw the model's
	-- file name where the thumbnail would be -- NOT the magenta checkerboard
	if ( self.m_bModelFailed ) then
		if ( draw and draw.SimpleText ) then
			local name = self:GetModelName() or ""
			local short = string.match( name, "([^/]+)%.mdl$" ) or name
			draw.SimpleText( short, "DermaDefault", w / 2, h / 2 - 4,
				Color( 210, 210, 210, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
		return
	end

	-- HL2SB (2026-09-27): queued for its load -- say so, so the filling grid
	-- reads as "loading" instead of a wall of dead tiles.  Loads are paced one
	-- per tick because each one hitches the frame.
	if ( not self.m_bModelLoaded and not self.m_bModelFailed ) then
		if ( draw and draw.SimpleText ) then
			local name = self:GetModelName() or ""
			local short = string.match( name, "([^/]+)%.mdl$" ) or name
			draw.SimpleText( short, "DermaDefault", w / 2, h / 2 - 4,
				Color( 120, 126, 132, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
		return
	end

	-- HL2SB (2026-09-27): snapshot path -- the model was rendered once into a
	-- render target at LoadModel time; drawing it is a textured rect.  This is
	-- the cheap path, and it is why the model list no longer lags while open.
	if ( self.m_IconTexPath ) then
		-- keep the child pinned off -- it paints itself independently of this
		-- Paint, and the texture is already on top of it
		if ( IsValid( self.Icon ) ) then self.Icon.m_bCulled = true end

		local id = self.m_IconTexID
		if ( not id and surface.GetTextureID ) then
			id = surface.GetTextureID( self.m_IconTexPath )
			self.m_IconTexID = id
		end

		if ( id and surface.SetTexture and surface.DrawTexturedRect ) then
			surface.SetTexture( id )
			surface.SetDrawColor( 255, 255, 255, 255 )
			surface.DrawTexturedRect( 0, 0, w, h )
		end

		return
	end

	-- viewport culling: the live 3D thumbnail is the one expensive thing a
	-- cell does per frame.  Two tests: on screen at all, and inside the
	-- nearest scrolling list's viewport (a cell clipped by the list's scroll
	-- is still "on screen" but must not render -- see the perf note at the
	-- top of the load queue).  The child reads the flag in its Paint.
	local bOnScreen = true
	local ok, ax, ay = pcall( self.LocalToScreen, self, 0, 0 )
	if ( ok and ax ~= nil ) then
		bOnScreen = not ( ay + h < 0 or ay > ScrH() or ax + w < 0 or ax > ScrW() )

		if ( bOnScreen ) then
			bOnScreen = IsInViewport( self, ax, ay, w, h )
		end
	end

	self.m_bInView = bOnScreen

	if ( IsValid( self.Icon ) ) then
		self.Icon.m_bCulled = not bOnScreen
	end

	if ( not bOnScreen ) then return end

	if ( render and render.SetScissorRectangle and self.LocalToScreen ) then
		if ( ok and ax ~= nil ) then
			render.SetScissorRectangle( ax, ay, ax + w, ay + h, true )
			self.m_bScissorSet = true
		end
	end
end

--- GMod's Think (see the header for the OnThink bridge this engine needs).
function PANEL:OnThink()
	-- queue the (deferred) model load, then pump the queue -- one model per
	-- tick, on-screen cells first-come-first-served
	if ( not self.m_bModelLoaded and not self.m_bModelFailed and not self.m_bQueued ) then
		self.m_bQueued = true
		g_LoadQueue[ #g_LoadQueue + 1 ] = self
	end

	PumpModelLoads()

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
	-- release the scissor Paint enabled (children painted inside it)
	if ( self.m_bScissorSet and render and render.SetScissorRectangle ) then
		render.SetScissorRectangle( 0, 0, 0, 0, false )
		self.m_bScissorSet = false
	end

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

	-- HL2SB (perf): the model does NOT load here (see the queue note at the
	-- top of the file).  OnThink queues LoadModel, which does the real work
	-- one cell per tick for on-screen cells only.
	self.m_bModelLoaded = false
	self.m_bModelFailed = false

	if ( iSkin && iSkin > 0 ) then
		self:SetTooltip( string.format( "%s (Skin %i)", mdl, iSkin + 1 ) )
	else
		self:SetTooltip( string.format( "%s", mdl ) )
	end
end

--- HL2SB: the real load, run from the queue (see PumpModelLoads).  Keeps the
--- camera-fit the old SetModel did right after the load, plus the error-model
--- check the spawn menu used to run at creation time -- a model that fails
--- marks the icon and Paint degrades to the model's file name.
function PANEL:LoadModel()
	if ( self.m_bModelLoaded or self.m_bModelFailed ) then return end
	self.m_bModelLoaded = true

	local mdl = self:GetModelName()
	if ( mdl == nil or mdl == "" ) then return end

	if ( not IsValid( self.Icon ) or self.Icon.SetModel == nil ) then
		self.m_bModelFailed = true
		return
	end

	local ok, err = pcall( self.Icon.SetModel, self.Icon, mdl, self:GetSkinID(), self.m_strBodyGroups )
	if ( not ok ) then
		print( "[SpawnIcon] SetModel failed for '" .. mdl .. "': " .. tostring( err ) )
		self.m_bModelFailed = true
		return
	end

	local ent = self.Icon.Entity
	local mdlGot = ( ent ~= nil and IsValid( ent ) ) and tostring( ent:GetModel() ) or ""
	if ( ent == nil or not IsValid( ent ) or string.find( string.lower( mdlGot ), "error", 1, true ) ~= nil ) then
		print( "[SpawnIcon] no clientside model for '" .. mdl .. "' - text fallback" )
		self.m_bModelFailed = true
		return
	end

	-- DModelPanel path: fit the camera to the model's bounds, the way
	-- GMod's thumbnail camera frames every model no matter its size (a
	-- strider and a can must both fill the cell).  Guarded: one model with
	-- odd bounds or a missing vector binding must not error every Think.
	pcall( function()
		if ( self.Icon.SetCamPos ) then
			-- HL2SB (2026-09-27): OBBMins/OBBMaxs on a clientside entity come
			-- back all-zero (nothing creates its collision), so radius collapsed
			-- to the 10-unit floor and the camera sat inside the model's feet --
			-- every thumbnail in the model list was legs.  Render bounds are the
			-- real studio bounds; OBB is the fallback; a standing-player box is
			-- the last resort.
			local mins, maxs
			local okb, bmin, bmax = pcall( ent.GetRenderBounds, ent )
			if ( okb and bmin and bmax ) then mins, maxs = bmin, bmax end
			if ( not mins ) then mins, maxs = ent:OBBMins(), ent:OBBMaxs() end
			if ( math.max( maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z ) <= 0 ) then
				mins, maxs = Vector( -16, -16, 0 ), Vector( 16, 16, 70 )
			end

			local center = ( mins + maxs ) * 0.5
			local radius = math.max( maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z ) * 0.5
			if ( radius < 1 ) then radius = 10 end

			self.Icon:SetLookAt( center )
			-- HL2SB (2026-09-27): the old offset (1.9/1.4/1.1)x radius put the
			-- camera 2.6x radius out -- at FOV 70 that framed the model at barely
			-- half the cell.  Same direction, but pulled in so the model fills
			-- the cell the way GMod's thumbnails do.
			local dir = Vector( radius * 1.9, radius * 1.4, radius * 1.1 )
			local len = dir:Length()
			if ( len and len > 0 ) then dir = dir * ( radius * 1.65 / len ) end
			self.Icon:SetCamPos( center + dir )
			self.Icon:SetFOV( 70 )
		end

		-- engine LModelPanel (ModelImage) keeps the camera the model was loaded with
		-- unless it is asked to fit again; without this the thumbnails of models whose
		-- bounds differ from the modelinfo defaults framed the head only
		-- (2026-09-17 screenshot).  RefitCamera is the binding for FitCameraToModel.
		if ( self.Icon.RefitCamera ) then self.Icon:RefitCamera() end
	end )

	-- HL2SB (2026-09-27): render the model ONCE into a render target and let
	-- Paint draw the texture.  Live 3D thumbnails meant the visible grid
	-- re-rendered dozens of player models every frame, which is what made the
	-- model list lag the whole time it was open.  Set hl2sb_spawnicon_live 1
	-- to revert to the live render.
	local bLive = ( GetConVarNumber ~= nil and GetConVarNumber( "hl2sb_spawnicon_live" ) == 1 )
	if ( not bLive and self.m_IconTexPath == nil and self.Icon.Snapshot ) then
		local okSnap, texpath = pcall( self.Icon.Snapshot, self.Icon, 64, 64 )
		if ( okSnap and texpath ) then
			self.m_IconTexPath = texpath
			-- the child must NEVER render again -- Paint's snapshot path returns
			-- before the live path sets m_bCulled, and the DModelPanel child
			-- paints itself regardless of what the parent drew (this is exactly
			-- how the first snapshot build stayed laggy: textures on top, live
			-- renders still running underneath)
			if ( IsValid( self.Icon ) ) then self.Icon.m_bCulled = true end

			-- one-line console proof that the snapshot path is live
			if ( not g_SnapshotReported ) then
				g_SnapshotReported = true
				Msg( "[HL2SB] spawnicon snapshots active (rt + vmt ok)\n" )
			end
		elseif ( not g_SnapshotFailed ) then
			g_SnapshotFailed = true
			Msg( "[HL2SB] spawnicon snapshot FAILED: " .. tostring( texpath ) .. "\n" )
		end
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
