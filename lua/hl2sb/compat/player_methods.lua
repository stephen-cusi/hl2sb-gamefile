--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/player_shd.lua

    对应 GMod 的 base/gamemode/player_shd.lua —— 给玩家实体补一组
    “GMod 语义”的方法，让玩家类脚本能直接写 ply:AllowFlashlight(...) 之类。

    HL2SB 里这些不是 metatable 别名就够的（有些要组合判断），所以在 Lua 里实现。
    只在**服务端**真正生效的部分（例如 SetAvoidPlayers）会检查 _GAME。
--------------------------------------------------------------------------]]--

local meta = _R ~= nil and _R.CBasePlayer or nil

if ( meta == nil ) then
	return
end

-------------------------------------------------------------------------------
-- 手电
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- 走路速度（GMod 用它们覆盖 MaxSpeed）
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- 分数 -- C++ 绑定（Frags/AddFrags/Deaths/AddDeaths，读引擎计数器）落地后
-- 这组方法来自 lbaseplayer_shared.cpp，这里不再有 Lua 版双源。
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 聊天输出
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- 网络：SendLua。
-- 这里曾有一个"退化成空操作"的垫片（if meta.SendLua == nil 罩了个空函数）。
-- 守卫本身有缺陷：SendLua 的 C 绑定注册在 Entity 元表上（lbaseentity_shared
-- 的实体方法表），Player 元表要经 __index 回退才够得着，所以 meta.SendLua
-- 对 Player 元表自身恒为 nil，垫片永远安装、永远遮蔽真正的引擎绑定——
-- 服务端 ply:SendLua 从此全部静默丢包（上限提示/错误提示/提示语全灭）。
-- GMod 的 SendLua 是引擎方法、没有 Lua 垫片；引擎绑定（stufftext 到客户端
-- 的 lua_run_cl）是现成的，删掉垫片让 C 绑定接管即可。
-------------------------------------------------------------------------------

-- Honor an available preferred weapon; Sandbox without HL2 weapons still needs
-- a usable default when a preference archived by the older fork is unavailable.
local switchToDefault = rawget( meta, "SwitchToDefaultWeapon" )
if ( SERVER and isfunction( switchToDefault ) ) then
    function meta:SwitchToDefaultWeapon()
        if ( GAMEMODE and GAMEMODE.IsSandboxDerived and not cvars.Bool( "sbox_weapons", true ) ) then
            local preferred = self:GetInfo( "cl_defaultweapon" )
            if ( not self:HasWeapon( preferred ) and self:HasWeapon( "weapon_physgun" ) ) then
                self:SelectWeapon( "weapon_physgun" )
                return
            end
        end
        return switchToDefault( self )
    end
end
