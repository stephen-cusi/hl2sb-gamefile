--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/cl_init.lua

    客户端半边。对应 GMod 的 gamemodes/base/gamemode/cl_init.lua。

    GMod 那个文件有 549 行，绝大多数是 HUD/记分板/队伍选择/Derma 面板。
    HL2SB 已经有一套自己的 HUD（击杀播报、拾取条…），而且 vgui 绑定撑不起
    Derma，所以这里只保留**引擎真的会调**的那部分客户端钩子，
    其余留空实现，让子 gamemode 覆盖时不会报 nil。
--------------------------------------------------------------------------]]--

include( "shared.lua" )

-------------------------------------------------------------------------------
-- 生命周期
-------------------------------------------------------------------------------
function GM:Initialize()
	self:CreateDefaultPanels()
end

function GM:InitPostEntity()
end

function GM:Think()
end

function GM:ShutDown()
end

function GM:OnReloaded()
end

-------------------------------------------------------------------------------
-- 帧 / 视口
-------------------------------------------------------------------------------
function GM:HUDPaint()
end

function GM:HUDShouldDraw( name )
end

function GM:Tick()
end

function GM:PreRender()
end

function GM:PostRender()
end

function GM:RenderScene( origin, angles, fov )
	return true
end

function GM:CalcView( ply, origin, angles, fov )
end

-------------------------------------------------------------------------------
-- 视图模型 / 玩家
-------------------------------------------------------------------------------
function GM:PreDrawViewModel( vm, weapon, ply )
	player_manager.RunClass( ply, "PreDrawViewModel", vm, weapon )
end

function GM:PostDrawViewModel( vm, weapon, ply )
	player_manager.RunClass( ply, "PostDrawViewModel", vm, weapon )
end

function GM:PostDrawPlayerHands( hands, vm, ply )
end

function GM:CreateMove( cmd )
	local ply = LocalPlayer()
	if ( not IsValid( ply ) ) then return end

	if ( player_manager.RunClass( ply, "CreateMove", cmd ) ) then return true end
end

function GM:PlayerBindPress( ply, bind, pressed )
end

-------------------------------------------------------------------------------
-- 客户端 UI 面板：HL2SB 的 sandbox gamemode 在这里建建造菜单
-------------------------------------------------------------------------------
function GM:CreateDefaultPanels()
end

-------------------------------------------------------------------------------
-- 队伍选择（GMod 在 cl_pickteam.lua 里画 Derma 面板；这里留空）
-------------------------------------------------------------------------------
function GM:ShowTeam()
end

function GM:ShowHelp()
end

function GM:ShowSpare1()
end

function GM:ShowSpare2()
end

function GM:PlayerStartVoice( ply )
end

function GM:PlayerEndVoice( ply )
end
