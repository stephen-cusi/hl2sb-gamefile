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
if ( meta.AllowFlashlight == nil ) then
	function meta:AllowFlashlight( able )
		self.m_bFlashlightAllowed = able and true or false
	end

	function meta:CanUseFlashlight()
		return self.m_bFlashlightAllowed ~= false
	end
end

-------------------------------------------------------------------------------
-- 走路速度（GMod 用它们覆盖 MaxSpeed）
-------------------------------------------------------------------------------
if ( meta.SetWalkSpeed == nil ) then
	function meta:SetWalkSpeed( speed )
		self.m_flHL2SBWalkSpeed = speed
	end

	function meta:SetRunSpeed( speed )
		self.m_flHL2SBRunSpeed = speed
	end

	function meta:SetSlowWalkSpeed( speed )
		self.m_flHL2SBSlowWalkSpeed = speed
	end

	function meta:SetCrouchedWalkSpeed( mul )
		self.m_flHL2SBCrouchedWalkSpeed = mul
	end

	function meta:SetJumpPower( power )
		self.m_flHL2SBJumpPower = power
	end
end

-------------------------------------------------------------------------------
-- 分数 -- C++ 绑定（Frags/AddFrags/Deaths/AddDeaths，读引擎计数器）落地后
-- 这组方法来自 lbaseplayer_shared.cpp，这里不再有 Lua 版双源。
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 聊天输出
-------------------------------------------------------------------------------
if ( meta.ChatPrint == nil ) then
	function meta:ChatPrint( msg )
		-- 服务端：直接给这个玩家的控制台塞一条 echo
		if ( _GAME and engine ~= nil and engine.ClientCmd ~= nil ) then
			pcall( engine.ClientCmd, self, "echo \"" .. tostring( msg ) .. "\"\n" )
			return
		end

		print( tostring( msg ) )
	end
end

-------------------------------------------------------------------------------
-- 默认武器 —— GMod 的 ply:SwitchToDefaultWeapon()
-- 读客户端 cl_defaultweapon，拥有就切过去
-------------------------------------------------------------------------------
if ( meta.SwitchToDefaultWeapon == nil ) then
	function meta:SwitchToDefaultWeapon()
		local name = ""

		if ( self.GetInfo ~= nil ) then
			local ok, v = pcall( self.GetInfo, self, "cl_defaultweapon" )
			if ( ok and type( v ) == "string" ) then name = v end
		end

		if ( name ~= "" and self.Weapon_OwnsThisType ~= nil ) then
			local wep = self:Weapon_OwnsThisType( name )
			if ( wep ~= nil and self.Weapon_Switch ~= nil ) then
				self:Weapon_Switch( wep )
				return
			end
		end

		-- 兜底：切到物理枪
		if ( self.Weapon_OwnsThisType ~= nil and self.Weapon_Switch ~= nil ) then
			local wep = self:Weapon_OwnsThisType( "weapon_physgun" )
			if ( wep ~= nil ) then
				self:Weapon_Switch( wep )
			end
		end
	end
end

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
