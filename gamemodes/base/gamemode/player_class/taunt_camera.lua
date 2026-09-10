--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/player_class/taunt_camera.lua

    GMod 的 taunt camera 需要 CBasePlayer 的 CalcView / CreateMove 客户端钩子
    才能真的推镜头俯仰、滚转。HL2SB 目前没有把这两个钩子接到 Lua，
    所以这里是**惰性桩**：API 和 GMod 一样，但 ShouldDrawLocal / CalcView /
    CreateMove 永远返回“不接管”，于是沙盒玩家类照抄 GMod 代码不会炸，
    只是暂时看不到 taunt 镜头。

    等引擎把客户端 CalcView/CreateMove 接到 Lua 之后，把真正的实现填进来即可。
--------------------------------------------------------------------------]]--

function TauntCamera()
	local CAM = {}

	CAM.IsTaunting = false
	CAM.TauntEndTime = 0

	function CAM:ShouldDrawLocalPlayer( ply, isTaunting )
		return false
	end

	function CAM:CalcView( view, ply, isTaunting )
		return false
	end

	function CAM:CreateMove( cmd, ply, isTaunting )
		return false
	end

	function CAM:StartTaunt( ply, act )
		self.IsTaunting = true
		self.TauntEndTime = 0

		return true
	end

	function CAM:StopTaunt()
		self.IsTaunting = false
	end

	return CAM
end
