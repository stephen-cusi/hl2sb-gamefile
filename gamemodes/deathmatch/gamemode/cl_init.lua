--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

include( "shared.lua" )

-- HL2SB (2026-09-26): the pickup notification strip -- GMod's
-- gamemodes/base/gamemode/cl_hudpickup.lua verbatim.  This FILE is this fork's
-- real base gamemode (LUA_BASE_GAMEMODE is "deathmatch" -- luamanager.h:40),
-- so everything defined here is inherited by sandbox/campaign/... through
-- gamemode.register's table.inherit.  GMod's base cl_init.lua includes
-- cl_hudpickup.lua the same way and drives it from GM:HUDPaint below.
include( "cl_hudpickup.lua" )

-- HL2SB (2026-09-27): GMod's taunt camera (base gamemode player_class
-- taunt_camera.lua verbatim).  GMod wires it through the sandbox player_class;
-- this fork calls it directly from GM:CalcView / GM:CreateMove /
-- GM:ShouldDrawLocalPlayer below, keyed on Player:IsPlayingTaunt() (the
-- replicated taunt clock the server `act` command stamps).
include( "taunt_camera.lua" )
local TauntCam = TauntCamera()

-- HL2SB (2026-10-08): GMod base gamemode client files, live via this include
-- while LUA_BASE_GAMEMODE is still "deathmatch" (the same full-path pattern
-- init.lua uses for the base init chain).  When the base flip lands, base
-- cl_init.lua includes these itself and the two lines here come off.
include( "gamemodes/base/gamemode/cl_targetid.lua" )
include( "gamemodes/base/gamemode/cl_spawnmenu.lua" )

-------------------------------------------------------------------------------
-- HL2SB (2026-10-08): GMod base cl_init.lua:124-145 verbatim - team colour
-- answered through the team library; cl_targetid's name/health text reads
-- both.
-------------------------------------------------------------------------------
function GM:GetTeamColor( ent )

	local team = TEAM_UNASSIGNED
	if ( ent.Team ) then team = ent:Team() end
	return GAMEMODE:GetTeamNumColor( team )

end

function GM:GetTeamNumColor( num )

	return team.GetColor( num )

end

function GM:ActivateClientUI()
end

function GM:AdjustEngineViewport( x, y, width, height )
end

function GM:CanShowSpeakerLabels()
end

function GM:CreateDefaultPanels()
end

function GM:DrawHeadLabels( pPlayer )
end

function GM:GetPlayerTextColor( entindex, r, g, b )
end

function GM:HideClientUI()
end

-- HL2SB (2026-10-02): the empty GM:HudElementShouldDraw / GM:HudViewportPaint
-- stubs were removed, not kept.  Both events are engine-dispatched EVERY frame
-- (HudElementShouldDraw once per HUD element, HudViewportPaint once per frame
-- from the scripted viewport), and hook.Call's gamemode fallback xpcalls the
-- gamemode method whenever the slot exists -- an empty stub turned that into a
-- dead function call plus a results-table allocation per element per frame.
-- An ABSENT slot answers nil from hook.call's fast path, which is the same
-- result the stub produced; hook.Add("HudElementShouldDraw"/"HudViewportPaint")
-- consumers (timer.lua's client tick, the death notice, ...) are unaffected.

-- GMod base gamemode cl_init.lua:266 同款（原文 2026-10-02 移植）。GMod 的
-- lua/postprocess/*.lua（pp_colormod / pp_motionblur / pp_toytown ...）在
-- RenderScreenspaceEffects 里先问它再画；本分叉的无后处理黑名单语义与
-- GMod 相同：全部放行。
function GM:PostProcessPermitted( str )

	return true

end

-- HL2SB (2026-09-26): GMod base gamemode 的 GM:HUDPaint 原文
-- （GMod gamemodes/base/gamemode/cl_init.lua:80-86）。拾取条画在
-- cl_hudpickup.lua；hook.Run 在无钩子返回非 nil 时派发 gamemode 方法
-- （hook.lua 的回退）。HUDDrawTargetID / DrawDeathNotice 当前无注册者、
-- 无 gamemode 方法，是 no-op，照抄只为同款；deathnotice 移植件走它自己的
-- HudViewportPaint，未迁移。
function GM:HUDPaint()

	-- HL2SB (2026-10-03): GMod 每帧派发已部署武器的 WEAPON:DrawHUD()
	-- （引擎侧钩子；base 的空桩只是缺省）。本分叉的等价泵挂在这条
	-- HUDPaint 链头：先画当前武器的 HUD，再跑共享钩子。
	local ply = LocalPlayer()
	local wep = ( IsValid( ply ) and ply.GetActiveWeapon ) and ply:GetActiveWeapon() or nil
	if ( IsValid( wep ) and wep.DrawHUD ) then
		wep:DrawHUD()
	end

	hook.Run( "HUDDrawTargetID" )
	hook.Run( "HUDDrawPickupHistory" )
	hook.Run( "DrawDeathNotice", 0.85, 0.04 )

end

function GM:KeyInput( down, keynum, pszCurrentBinding )
end

-- ===========================================================================
-- HL2SB (2026-09-26): the undo popup.  The undo module's client half fires
-- hook.Run( "OnUndo", name, customtext ) -- in GMod the POPUP itself is
-- sandbox/gamemode/cl_init.lua:46 GM:OnUndo -> GM:AddNotify ->
-- notification.AddLegacy.  Nothing in this fork defined either method, so
-- undoing worked (entities went away) but never said anything.  GMod's
-- sandbox translation logic verbatim; language.FormatPhrase is guarded
-- because this fork's language module only ships GetPhrase.
-- ===========================================================================

--- GMod sandbox/gamemode/cl_notice.lua:2
function GM:AddNotify( str, type, length )

	if ( notification ~= nil and notification.AddLegacy ~= nil ) then
		notification.AddLegacy( str, type, length )
	end

end

--- GMod sandbox/gamemode/cl_init.lua:46
function GM:OnUndo( name, strCustomString )

	local text = strCustomString
	local overwritten = false

	if ( !text ) then
		local strId = "#Undone_" .. name
		text = language.GetPhrase( strId )
		if ( strId == text ) then
			-- No custom translation available, make a generic one.
			-- NOTE: This fork's language.FormatPhrase is GetPhrase(key):format(...) --
			-- an unknown key formats into ITSELF, and the screenshot showed the raw
			-- "hint.undoneX" on screen.  Only use the phrase when the translation
			-- actually resolved, "Undone <name>" otherwise.
			local strPhrase = language.GetPhrase( "hint.undoneX" )
			if ( strPhrase ~= nil and strPhrase ~= "hint.undoneX" ) then
				text = strPhrase:format( language.GetPhrase( name ) )
			else
				text = "Undone " .. language.GetPhrase( name )
			end
			overwritten = true
		end
	end

	if ( !overwritten ) then
		-- HACK: Try to translate existing English-only translations
		local strMatch = string.match( text, "^Undone (.*)$" )
		if ( strMatch ) then
			text = "Undone " .. language.GetPhrase( strMatch )
		end
	end

	self:AddNotify( text, NOTIFY_UNDO, 2 )

	-- GMod verbatim ("Find a better sound :X", sandbox cl_init.lua:68)
	surface.PlaySound( "buttons/button15.wav" )

end

--- GMod sandbox/gamemode/cl_init.lua:76
function GM:OnCleanup( name )

	local str = "#Cleaned_" .. name
	local translated = language.GetPhrase( str )
	if ( str == translated ) then
		local strPhrase = language.GetPhrase( "hint.cleanedX" )
		if ( strPhrase ~= nil and strPhrase ~= "hint.cleanedX" ) then
			translated = strPhrase:format( language.GetPhrase( name ) )
		else
			translated = "Cleaned up " .. language.GetPhrase( name )
		end
	end

	self:AddNotify( translated, NOTIFY_CLEANUP, 5 )

	-- GMod verbatim
	surface.PlaySound( "buttons/button15.wav" )

end

--- GMod sandbox/gamemode/cl_init.lua:87
function GM:UnfrozeObjects( num )

	local strPhrase = language.GetPhrase( "hint.unfrozeX" )
	local text
	if ( strPhrase ~= nil and strPhrase ~= "hint.unfrozeX" ) then
		text = strPhrase:format( num )
	else
		text = "Unfroze " .. tostring( num ) .. " Objects"
	end

	self:AddNotify( text, NOTIFY_GENERIC, 3 )

	-- GMod verbatim
	surface.PlaySound( "npc/roller/mine/rmine_chirp_answer1.wav" )

end

function GM:LevelInitPreEntity()
end

function GM:LevelInitPostEntity()
end

function GM:OnScreenSizeChanged( iOldWide, iOldTall )
end

function GM:PlayerUpdateFlashlight( pHL2MPPlayer, position, vecForward, vecRight, vecUp, nDistance )
end

function GM:ShouldDrawCrosshair()
end

function GM:ShouldDrawDetailObjects()
end

function GM:ShouldDrawEntity( pEnt )
end

function GM:ShouldDrawFog()
end

-- HL2SB (2026-09-27): GMod's GM:CalcView.  Builds the CamData table, gives the
-- taunt camera its turn while a taunt plays (GMod goes through
-- player_manager.RunClass( ply, "CalcView", view ) -> PLAYER:CalcView), and
-- hands the (possibly modified) view back to the engine's CalcView hook reader.
-- HL2SB (2026-10-04): brought to the GMod base shape (cl_init.lua:357) -- the
-- (ply, origin, angles, fov, znear, zfar) signature, the znear/zfar/drawviewer
-- CamData fields, the vehicle re-route and the player-class turn.  GMod's Lua
-- weapon-view section stays out on purpose: SWEP:CalcView/TranslateFOV are
-- dispatched natively in c_hl2mp_player.cpp and running them here too would
-- apply them twice.  NOTE for addons: registered CalcView hooks run BEFORE
-- this method and may edit origin/angles in place -- view.origin/angles hold
-- those same userdata by reference, so their edits ride back to the engine
-- through the returned table (this is what makes First Person Body's vehicle
-- eye snap work).
function GM:CalcView( ply, origin, angles, fov, znear, zfar )

	local Vehicle	= ply:GetVehicle()
	local Weapon	= ply:GetActiveWeapon()

	local view = {
		["origin"] = origin,
		["angles"] = angles,
		["fov"] = fov,
		["znear"] = znear,
		["zfar"] = zfar,
		["drawviewer"] = false,
	}

	-- GMod base (cl_init.lua:374): a vehicle re-routes the whole view through
	-- the CalcVehicleView hook chain.  HL2SB delta (2026-10-04): when nothing
	-- listens, GMod's strict `return hook.Run(...)` yields NIL and the engine
	-- readback then discards every registered hook's in-place edit of
	-- origin/angles (First Person Body's vehicle eye snap died exactly there).
	-- Fall through instead: the drive/taunt/player-class stages keep running
	-- and we return the view table, whose origin/angles still hold those
	-- hooks' mutated userdata by reference.
	if ( IsValid( Vehicle ) ) then
		local vehView = hook.Run( "CalcVehicleView", Vehicle, ply, view )
		if ( vehView ~= nil ) then return vehView end
	end

	-- HL2SB (2026-09-29): GMod base order - the drive gets the view first
	-- (gamemodes/base/gamemode/cl_init.lua:379), then the taunt camera.
	if ( drive.CalcView( ply, view ) ) then return view end

	-- GMod base: player classes get a turn (PLAYER:CalcView); no-op for
	-- classes that do not define it.
	player_manager.RunClass( ply, "CalcView", view )

	TauntCam:CalcView( view, ply, ply:IsPlayingTaunt() )

	return view

end

-- HL2SB (sbrust): verbatim port of GMod base gamemode's GM:CalcVehicleView
-- (gamemodes/base/gamemode/cl_init.lua:305-351).  This IS the vehicle third
-- person camera now: the state it reads (GetThirdPersonMode / GetCameraDistance)
-- is the networked per-vehicle data the SERVER writes in
-- CPropVehicleDriveable::HL2SB_UpdateCameraState (the port of GM:VehicleMove:
-- CTRL edge flips the mode, mouse wheel drives the distance multiplier), and
-- GM:CalcView above routes a seated view here (hook.Run("CalcVehicleView")
-- falls back to this gamemode method).  First person returns the view
-- untouched -- the C++ vehicle eye (SharedVehicleViewSmoothing) stands as
-- computed.  GMod's own comments are kept.
function GM:CalcVehicleView( Vehicle, ply, view )

	if ( Vehicle.GetThirdPersonMode == nil || ply:GetViewEntity() != ply ) then
		-- This shouldn't ever happen.
		return
	end

	--
	-- If we're not in third person mode - then get outa here stalker
	--
	if ( !Vehicle:GetThirdPersonMode() ) then return view end

	-- Don't roll the camera
	-- view.angles.roll = 0

	local mn, mx = Vehicle:GetRenderBounds()
	local radius = ( mn - mx ):Length()
	local radius = radius + radius * Vehicle:GetCameraDistance()

	-- Trace back from the original eye position, so we don't clip through walls/objects
	local TargetOrigin = view.origin + ( view.angles:Forward() * -radius )
	local WallOffset = 4

	local tr = util.TraceHull( {
		start = view.origin,
		endpos = TargetOrigin,
		filter = function( e )
			-- HL2SB (sbrust): the driver must never wall the camera into their
			-- own head.  GMod gets that for free -- the seated player's
			-- IN_VEHICLE collision group never collides with the trace hull --
			-- while this fork's hull starts solid inside the player itself
			-- (probe: ss=true, hitent=player, frac=0.000, camera pinned to the
			-- eye).  Everything below stays GMod's filter verbatim.
			if ( e == ply ) then return false end
			local c = e:GetClass() -- Avoid contact with entities that can potentially be attached to the vehicle. Ideally, we should check if "e" is constrained to "Vehicle".
			return !c:StartsWith( "prop_physics" ) &&!c:StartsWith( "prop_dynamic" ) && !c:StartsWith( "phys_bone_follower" ) && !c:StartsWith( "prop_ragdoll" ) && !e:IsVehicle() && !c:StartsWith( "gmod_" )
		end,
		mins = Vector( -WallOffset, -WallOffset, -WallOffset ),
		maxs = Vector( WallOffset, WallOffset, WallOffset ),
	} )

	view.origin = tr.HitPos
	view.drawviewer = true

	--
	-- If the trace hit something, put the camera there.
	--
	if ( tr.Hit && !tr.StartSolid) then
		view.origin = view.origin + tr.HitNormal * WallOffset
	end

	return view

end

-- HL2SB (sbrust): GMod base's CLIENT-side GM:VehicleMove stub
-- (gamemodes/base/gamemode/cl_init.lua:735) -- empty in GMod too: the hook
-- exists in both realms, only the server body does work.  Ported so the hook
-- contract matches GMod both realms.  Dormant in this fork: the engine does not
-- dispatch VehicleMove (no CMoveData Lua bindings yet), the toggle+zoom run
-- natively server-side (CPropVehicleDriveable::HL2SB_UpdateCameraState).  If a
-- later round adds the dispatch, the C++ writer must be removed FIRST -- the
-- final set must fire the toggle exactly once per seated server tick.
function GM:VehicleMove( ply, vehicle, mv )

end

-- HL2SB (2026-09-27): GMod's GM:CreateMove.  While a taunt plays the taunt
-- camera orbits itself with the mouse and locks the body
-- (cmd:SetViewAngles/ClearButtons/ClearMovement); in_main.cpp copies the
-- writable fields back into the real command after the hook returns.
function GM:CreateMove( cmd )

	-- HL2SB (2026-09-29): GMod's base CreateMove asks the drive system first
	-- (cl_init.lua:655); a drive claims the command (return true) so the engine
	-- stops applying the default player move.
	if ( drive.CreateMove( cmd ) ) then return true end

	local ply = LocalPlayer()

	if ( IsValid( ply ) && TauntCam:CreateMove( cmd, ply, ply:IsPlayingTaunt() ) ) then
		return true
	end

end

-- If return true:		Will draw the local player
-- If return false:		Won't draw the local player
-- If return nil:		Will carry out default action
--
-- HL2SB (2026-09-27): the taunt camera turn (GMod: player_manager.RunClass(
-- ply, "ShouldDrawLocal" ) -> PLAYER:ShouldDrawLocal -> TauntCam).
function GM:ShouldDrawLocalPlayer( ply )

	if ( IsValid( ply ) && TauntCam:ShouldDrawLocalPlayer( ply, ply:IsPlayingTaunt() ) ) then
		return true
	end

end

--[[---------------------------------------------------------
	Name: gamemode:CalcViewModelView()
	Desc: Called every frame by the engine to compute the view model's
	position/angles.  Forwards to SWEP:GetViewModelPosition and then
	SWEP:CalcViewModelView -- GMod base cl_init.lua:555 verbatim,
	ported 2026-10-07 (hl1sweps positions every viewmodel through this
	chain; without it the HL1 weapons drew at the bare eye transform).
-----------------------------------------------------------]]
function GM:CalcViewModelView( wep, vm, oldEyePos, oldEyeAng, eyePos, eyeAng )

	if ( !IsValid( wep ) ) then return end

	local vm_origin, vm_angles = eyePos, eyeAng

	-- Controls the position of all viewmodels
	local func = wep.GetViewModelPosition
	if ( func ) then
		local pos, ang = func( wep, eyePos*1, eyeAng*1 )
		vm_origin = pos or vm_origin
		vm_angles = ang or vm_angles
	end

	-- Controls the position of individual viewmodels
	func = wep.CalcViewModelView
	if ( func ) then
		local pos, ang = func( wep, vm, oldEyePos*1, oldEyeAng*1, eyePos*1, eyeAng*1 )
		vm_origin = pos or vm_origin
		vm_angles = ang or vm_angles
	end

	return vm_origin, vm_angles

end

--[[---------------------------------------------------------
	Name: gamemode:PreDrawViewModel()
	Desc: Called before drawing the view model; return true to suppress it
	(the engine then skips ViewModelDrawn/PostDrawViewModel too).
	HL2SB (2026-09-27): port of GMod base cl_init.lua:585.  The engine
	(viewrender.cpp) dispatches this GAMEMODE hook now instead of calling the
	SWEP method directly; the SWEP forward below is GMod's own chain.
-----------------------------------------------------------]]
function GM:PreDrawViewModel( vm, ply, wep, flags )

	if ( !IsValid( wep ) ) then return false end

	player_manager.RunClass( ply, "PreDrawViewModel", vm, wep, flags )

	if ( wep.PreDrawViewModel == nil ) then return false end
	return wep:PreDrawViewModel( vm, wep, ply, flags )

end

--[[---------------------------------------------------------
	Name: gamemode:PostDrawViewModel()
	Desc: Called after drawing the view model.  THIS is where the player's
	hands (the gmod_hands entity, EF_BONEMERGE'd onto the viewmodel) are
	drawn, gated on the weapon's UseHands -- GMod base cl_init.lua:597
	verbatim, ported 2026-09-27.
-----------------------------------------------------------]]
function GM:PostDrawViewModel( vm, ply, wep, flags )

	if ( !IsValid( wep ) ) then return false end

	if ( wep.UseHands || !wep:IsScripted() ) then

		local hands = ply:GetHands()
		if ( IsValid( hands ) ) then

			-- HL2SB (2026-10-04) SP self-heal: the vehicle enter/exit cycle
			-- holsters the weapon -> viewmodel EF_NODRAW -> FL_EDICT_DONTSEND ->
			-- the single-player backdoor dormants the vm and the hands with it,
			-- and the wake branch races the hands' own AttachToViewmodel --
			-- the entity comes back alive and bound but detached (parent=NULL,
			-- EF_BONEMERGE cleared, origin 0).  GMod never sees this because
			-- its transport has no such wake; re-attach here, every frame,
			-- which is also what GMod's per-frame parent check effectively
			-- guarantees.  Client-side SetParent is the legal
			-- outside-PostDataUpdate variant, and a healthy entity matches on
			-- the next full update so this is a no-op in MP.
			if ( hands:GetParent() != vm ) then

				hands:AttachToViewmodel( vm )

			end

			if ( IsValid( hands:GetParent() ) ) then

				if ( not hook.Call( "PreDrawPlayerHands", self, hands, vm, ply, wep, flags ) ) then

					-- GMod base cl_init.lua:611 - a ViewModelFlip weapon mirrors the
					-- viewmodel, so the hands draw with inverted winding.
					if ( wep.ViewModelFlip ) then render.CullMode( MATERIAL_CULLMODE_CW ) end
					hands:DrawModel( flags )
					render.CullMode( MATERIAL_CULLMODE_CCW )

				end

				hook.Call( "PostDrawPlayerHands", self, hands, vm, ply, wep, flags )

			end

		end

	end

	player_manager.RunClass( ply, "PostDrawViewModel", vm, wep, flags )

	if ( wep.PostDrawViewModel == nil ) then return false end
	return wep:PostDrawViewModel( vm, wep, ply, flags )

end

function GM:ShouldDrawParticles()
end

function GM:ShouldDrawViewModel()
end
