--[[--------------------------------------------------------------------------
    gamemodes/base/content/lua/entities/lua_run/init.lua

    服务端半边。移植自 GMod 的 lua_run.lua。

    和 GMod 版的差异：
      - RunString 由 gmod_compat.lua 提供（引擎没有这个全局）
      - self:EntIndex() 由 gmod_compat.lua 别名到 entindex()
      - 执行代码用的是 HL2SB 自己的 Lua 状态，所以 ACTIVATOR / CALLER /
        TRIGGER_PLAYER 这三个全局和 GMod 语义一致
--------------------------------------------------------------------------]]--

include( "shared.lua" )

function ENT:Initialize()
	-- 第一个 spawnflag 置位时，生成即执行
	if ( self:HasSpawnFlags( SF_LUA_RUN_ON_SPAWN ) ) then
		self:RunCode( self, self, self:GetDefaultCode() )
	end
end

function ENT:KeyValue( key, value )
	if ( string.lower( key ) == "code" ) then
		self:SetDefaultCode( value )
	end
end

function ENT:SetupGlobals( activator, caller )
	ACTIVATOR = activator
	CALLER    = caller

	if ( IsValid( activator ) and activator.IsPlayer ~= nil and activator:IsPlayer() ) then
		TRIGGER_PLAYER = activator
	end
end

function ENT:KillGlobals()
	ACTIVATOR      = nil
	CALLER         = nil
	TRIGGER_PLAYER = nil
end

function ENT:RunCode( activator, caller, code )
	self:SetupGlobals( activator, caller )

	if ( code ~= nil and code ~= "" ) then
		RunString( tostring( code ), "lua_run#" .. tostring( self:EntIndex() ) )
	end

	self:KillGlobals()
end

function ENT:AcceptInput( name, activator, caller, data )
	if ( name == "RunCode" ) then
		self:RunCode( activator, caller, self:GetDefaultCode() )
		return true
	end

	if ( name == "RunPassedCode" ) then
		self:RunCode( activator, caller, data )
		return true
	end

	return false
end
