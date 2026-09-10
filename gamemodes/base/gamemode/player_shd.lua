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
-- 分数（HL2SB 没有分数绑定，这里存 Lua 侧，供 team.lua / 记分板用）
-------------------------------------------------------------------------------
if ( meta.Frags == nil ) then
	function meta:Frags()
		return self.m_nHL2SBFrags or 0
	end

	function meta:AddFrags( n )
		self.m_nHL2SBFrags = ( self.m_nHL2SBFrags or 0 ) + ( n or 1 )
	end
end

if ( meta.Deaths == nil ) then
	function meta:Deaths()
		return self.m_nHL2SBDeaths or 0
	end

	function meta:AddDeaths( n )
		self.m_nHL2SBDeaths = ( self.m_nHL2SBDeaths or 0 ) + ( n or 1 )
	end
end

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
-- 网络：GMod 用 ply:SendLua 让客户端执行一段 Lua。
-- HL2SB 有 net 库，但没有“执行任意 Lua”的通道，这里退化成空操作。
-------------------------------------------------------------------------------
if ( meta.SendLua == nil ) then
	function meta:SendLua( code )
	end
end
