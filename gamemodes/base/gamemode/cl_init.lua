--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/cl_init.lua

    客户端半边。对应 GMod 的 gamemodes/base/gamemode/cl_init.lua。

    2026-10-08（LUA_BASE_GAMEMODE 切换轮）：这个文件现在是 deathmatch
    cl_init.lua 的同款内容——那份"改编移植版"（HUD 泵 / CalcView 族 /
    undo 通知 / taunt 镜头 / 视图模型手部绘制）才是本引擎真正在跑的客户端
    gamemode 面，切换后它整体上提到 base，sandbox / campaign / deathmatch
    都从这里继承。GMod 原版 cl_init 的 736 行里，记分板（cl_scoreboard）与
    队伍选择面板（cl_pickteam）已移植（2026-10-10），语音面板（cl_voice）
    还没有移植，保持缺席。

    与 deathmatch 那份的两处刻意偏差（都写在对应方法上方）：
      - GM:RenderScene 不定义：引擎契约是「返回 true = 跳过整个场景绘制」
        （viewrender.cpp 的 bSkipSceneDraw），任何空桩都不得返回 true。
      - GM:Initialize 不调 self:CreateDefaultPanels()：引擎自己就会派发
        CreateDefaultPanels（scriptedclientluapanel.cpp），这里再调一次会把
        sandbox 的建造菜单建两遍。
--------------------------------------------------------------------------]]--

include( "shared.lua" )
include( "cl_targetid.lua" )
include( "cl_spawnmenu.lua" )

-- HL2SB (2026-10-08): 拾取通知条（GMod base cl_hudpickup.lua 的分叉移植版，
-- 含 hud_killfeed item_pickup 事件 -> GM:HUD*PickedUp 的适配器）。
include( "cl_hudpickup.lua" )

-- HL2SB (2026-10-10): GMod base 的记分板（cl_scoreboard.lua 分叉移植版，
-- +showscoreboard/-showscoreboard 按钮命令在文件尾注册，TAB 绑定走它们）。
include( "cl_scoreboard.lua" )

-- HL2SB (2026-10-10): GMod base 的选队面板（cl_pickteam.lua 移植版）。
include( "cl_pickteam.lua" )

-- HL2SB (2026-09-27): GMod 的 taunt 相机（player_class/taunt_camera.lua 逐字
-- 版）。GMod 经 PLAYER:CalcView / PLAYER:CreateMove / PLAYER:ShouldDrawLocal
-- 接它；本分叉在下面的 GM:CalcView / GM:CreateMove / GM:ShouldDrawLocalPlayer
-- 里直接接管，键是 Player:IsPlayingTaunt()（服务端 act 命令盖章的复制时钟）。
include( "taunt_camera.lua" )
local TauntCam = TauntCamera()

-------------------------------------------------------------------------------
-- 生命周期
-------------------------------------------------------------------------------
function GM:Initialize()
end

function GM:InitPostEntity()
end

function GM:Think()
end

function GM:ShutDown()
end

-------------------------------------------------------------------------------
-- GMod base cl_init.lua:124-145 verbatim —— 队伍颜色，cl_targetid 的
-- 名字/血量文本两边都读。
-------------------------------------------------------------------------------
function GM:GetTeamColor( ent )

	local team = TEAM_UNASSIGNED
	if ( ent.Team ) then team = ent:Team() end
	return GAMEMODE:GetTeamNumColor( team )

end

function GM:GetTeamNumColor( num )

	return team.GetColor( num )

end

function GM:HUDShouldDraw( name )
end

-------------------------------------------------------------------------------
-- HL2SB (2026-10-08): 上提自 deathmatch cl_init.lua —— 每帧 HUD 泵。
-- GMod 每帧派发已部署武器的 WEAPON:DrawHUD()（引擎侧钩子；base 的空桩只是
-- 缺省），本分叉的等价泵挂在 HUDPaint 链头：先画当前武器的 HUD，再跑共享
-- 钩子。拾取条画在 cl_hudpickup.lua。
-------------------------------------------------------------------------------
function GM:HUDPaint()

	local ply = LocalPlayer()
	local wep = ( IsValid( ply ) and ply.GetActiveWeapon ) and ply:GetActiveWeapon() or nil
	if ( IsValid( wep ) and wep.DrawHUD ) then
		wep:DrawHUD()
	end

	hook.Run( "HUDDrawTargetID" )
	hook.Run( "HUDDrawPickupHistory" )
	hook.Run( "DrawDeathNotice", 0.85, 0.04 )

end

-- ===========================================================================
-- HL2SB (2026-09-26): undo 弹窗（上提自 deathmatch cl_init.lua）。undo 模块
-- 的客户端半边 fire hook.Run( "OnUndo", name, customtext ) —— GMod 里弹窗
-- 本体是 sandbox/gamemode/cl_init.lua:46 GM:OnUndo -> GM:AddNotify ->
-- notification.AddLegacy。GMod 的 sandbox 翻译逻辑逐字；
-- language.FormatPhrase 带守卫（本分叉的 language 只有 GetPhrase）。
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

-------------------------------------------------------------------------------
-- GMod base cl_init.lua:266 同款。GMod 的 lua/postprocess/*.lua（pp_colormod
-- / pp_motionblur / pp_toytown ...）在 RenderScreenspaceEffects 里先问它再画；
-- 本分叉的无后处理黑名单语义与 GMod 相同：全部放行。
-------------------------------------------------------------------------------
function GM:PostProcessPermitted( str )

	return true

end

-------------------------------------------------------------------------------
-- HL2MP 引擎钩桥空桩（上提自 deathmatch cl_init.lua）：引擎每帧/每元素派发
-- 这些 HL2MP 名字，空实现 = 引擎默认。注意 CreateDefaultPanels 由引擎直接
-- 派发（scriptedclientluapanel.cpp），sandbox 在自己的 cl_init 里覆盖它建
-- 建造菜单——base 的空桩只服务没有覆盖者的 gamemode。
-------------------------------------------------------------------------------
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

function GM:KeyInput( down, keynum, pszCurrentBinding )

	-- GMod 的客户端在引擎侧把功能键直接派发给 gamemode 方法（F1 ShowHelp、
	-- F2 ShowTeam、F3/F4 ShowSpare1/2）。本分叉引擎没有这层派发，从这里
	-- 路由；方法存在才调（ShowTeam 由 cl_pickteam.lua 提供，ShowHelp 由
	-- 子 gamemode 决定要不要给）。
	if ( !down ) then return end

	if ( keynum == KEY_F1 ) then
		if ( self.ShowHelp != nil ) then self:ShowHelp() end
	elseif ( keynum == KEY_F2 ) then
		if ( self.ShowTeam != nil ) then self:ShowTeam() end
	end

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

function GM:ShouldDrawParticles()
end

function GM:ShouldDrawViewModel()
end

-- ===========================================================================
-- HL2SB (2026-09-27): GM:CalcView（上提自 deathmatch cl_init.lua）。构造
-- CamData 表，taunt 播放期间让 taunt 相机接管（GMod 走
-- player_manager.RunClass( ply, "CalcView", view ) -> PLAYER:CalcView），
-- 然后把（可能被改过的）view 表交还引擎的 CalcView 钩子读取端。
-- HL2SB (2026-10-04): 对齐 GMod base 形状（cl_init.lua:357）——
-- (ply, origin, angles, fov, znear, zfar) 签名、znear/zfar/drawviewer 字段、
-- 载具改道、玩家类一轮。GMod 的 Lua 武器视图段刻意不放进来：
-- SWEP:CalcView/TranslateFOV 已由 c_hl2mp_player.cpp 原生派发，这里再跑
-- 一遍会叠加两次。给插件的备注：注册的 CalcView 钩子先于本方法跑，可以
-- 原地改 origin/angles——view.origin/angles 持有同一份 userdata 引用，
-- 改动经返回表回传引擎（First Person Body 的载具眼睛吸附就靠这个）。
-- ===========================================================================
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

-- HL2SB (sbrust): GMod base gamemode 的 GM:CalcVehicleView 逐字体（上提自
-- deathmatch cl_init.lua）。这就是载具第三人称相机本体：它读的状态
-- （GetThirdPersonMode / GetCameraDistance）是服务端
-- CPropVehicleDriveable::HL2SB_UpdateCameraState 写的网络化数据，GM:CalcView
-- 会把乘坐中的视图改道到这里。第一人称原样返回——C++ 载具眼睛
-- （SharedVehicleViewSmoothing）保持原计算。分叉差异：trace filter 里排除
-- 驾驶员自己（本分叉 hull 在驾驶员体内起算 solid，不排除会把相机钉在眼睛上）。
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

-- HL2SB (sbrust): GMod base 的客户端 GM:VehicleMove 空桩
-- （gamemodes/base/gamemode/cl_init.lua:735）—— GMod 里也是空的：钩子双端
-- 存在，只有服务端体干活。移植以保持双端钩子合同一致。本引擎不派发
-- VehicleMove（休眠，见 base init.lua 的服务端体注释）。
function GM:VehicleMove( ply, vehicle, mv )

end

-- HL2SB (2026-09-27): GM:CreateMove（上提自 deathmatch cl_init.lua）。
-- taunt 播放期间 taunt 相机用鼠标自转并锁住身体
-- （cmd:SetViewAngles/ClearButtons/ClearMovement）；in_main.cpp 在钩子返回后
-- 把可写字段拷回真实命令。
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

-------------------------------------------------------------------------------
-- 队伍/帮助 UI 触发点（引擎的 gm_showhelp / gm_showteam / gm_showspare1 /
-- gm_showspare2 命令会派发这些；GMod base 里同样是空桩，队伍选择面板
-- cl_pickteam.lua 还没移植）。
-------------------------------------------------------------------------------
function GM:ShowTeam()
end

function GM:ShowHelp()
end

function GM:ShowSpare1()
end

function GM:ShowSpare2()
end
