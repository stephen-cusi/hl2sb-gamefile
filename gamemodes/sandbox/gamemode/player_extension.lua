--[[----------------------------------------------------------------------------
    Sandbox: Player 元表扩展

    逐字移植 GMod gamemodes/sandbox/gamemode/player_extension.lua。
    这是沙盒上限体系的**本体**：sbox_max<type> 的读取（CheckLimit）、
    计数（GetCount / AddCount）、超限提示（LimitHit）全在这里，
    GMod 的生成命令最后都落到 CheckLimit / AddCount 上。

    工具枪（constraint/light/button 等）直接调 ply:CheckLimit/AddCount；
    生成菜单的载具/道具/NPC/SENT 走 gamemode 层：
        GM:PlayerSpawn<Type>   -> LimitReachedProcess -> ply:CheckLimit  (前置放行)
        GM:PlayerSpawned<Type> -> ply:AddCount                            (后置计数)
    见同目录 player.lua。

    两处分叉适配（引擎 API 差异，行为等价）：
      1. 本分叉的 Entity:CallOnRemove( id, fn ) 只回传 ( ent, id )，不转发
         可变参数（GMod 的签名是 CallOnRemove( id, fn, ... )）。计数刷新
         回调因此用闭包捕获 ply/countType，不依赖尾参转发。
      2. CLIENT 分支的 GetNWInt 读取保持不变；计数是靠 SetNWInt 同步给
         客户端的，生成菜单在客户端就能先拦一道。
------------------------------------------------------------------------------]]

local meta = FindMetaTable( "Player" )

-- Return if there's nothing to add on to
if ( !meta ) then return end

if ( SERVER ) then
	g_SBoxObjects = g_SBoxObjects or {}
end

function meta:CheckLimit( str )

	-- No limits in single player
	if ( game.SinglePlayer() ) then return true end

	local c = cvars.Number( "sbox_max" .. str, 0 )
	local count = self:GetCount( str )

	local ret = hook.Run( "PlayerCheckLimit", self, str, count, c )
	if ( ret != nil ) then
		if ( !ret && SERVER ) then self:LimitHit( str ) end
		return ret
	end

	if ( c < 0 ) then return true end

	if ( count > c - 1 ) then
		if ( SERVER ) then self:LimitHit( str ) end
		return false
	end

	return true

end

local function CleanInvalidEntities( uid )
	if ( !g_SBoxObjects[ uid ] ) then return end

	for countType, entities in pairs( g_SBoxObjects[ uid ] ) do
		for k, v in pairs( entities ) do
			if ( !IsValid( v ) ) then entities[ k ] = nil end
		end

		-- Clear the table for this "count type" if its empty
		if ( !next( entities ) ) then g_SBoxObjects[ uid ][ countType ] = nil end
	end

	if ( !next( g_SBoxObjects[ uid ] ) ) then g_SBoxObjects[ uid ] = nil end
end

local function QueueUpdateCleanup( uid, countType )
	timer.Create( "SBoxCountUpdate_" .. countType .. "_" .. uid, 0, 1, function()
		CleanInvalidEntities( uid )
	end )
end

local function QueueUpdateCounts( ply, countType )
	-- Instead of running ply:GetCount for each deletion or creation immediately,
	-- we use a timer to batch them together in the next frame.
	-- This helps immenseley when a lot of entities are being removed or created at once.
	local key = ply:UniqueID()
	timer.Create( "SBoxCountUpdate_" .. countType .. "_" .. key, 0, 1, function()
		if ( IsValid( ply ) ) then ply:GetCount( countType ) else CleanInvalidEntities( key ) end
	end )
end

function meta:GetCount( str, minus )

	if ( CLIENT ) then
		return self:GetNWInt( "Count." .. str, 0 )
	end

	if ( !self:IsValid() ) then return end

	local key = self:UniqueID()
	local tab = g_SBoxObjects[ key ]
	if ( !tab || !tab[ str ] ) then
		self:SetNWInt( "Count." .. str, 0 )
		return 0
	end

	local c = 0
	for k, v in pairs( tab[ str ] ) do

		if ( IsValid( v ) && !v:IsMarkedForDeletion() ) then
			c = c + 1
		else
			tab[ str ][ k ] = nil
		end

	end

	-- Clear the table for this "count type" if its empty
	if ( c == 0 ) then tab[ str ] = nil end

	-- Clear the top level table for the player if there's nothing in it left
	if ( !next( tab ) ) then g_SBoxObjects[ key ] = nil end

	minus = minus or 0
	self:SetNWInt( "Count." .. str, math.max( c - minus, 0 ) )

	return c

end

function meta:AddCount( str, ent )

	if ( SERVER ) then

		local key = self:UniqueID()
		g_SBoxObjects[ key ] = g_SBoxObjects[ key ] or {}
		g_SBoxObjects[ key ][ str ] = g_SBoxObjects[ key ][ str ] or {}

		local tab = g_SBoxObjects[ key ][ str ]

		table.insert( tab, ent )

		-- Update count (for client)
		QueueUpdateCounts( self, str )

		-- Update count on deletion.  GMod forwards ( ply, str, uid ) as trailing
		-- CallOnRemove arguments; this fork's CallOnRemove answers ( ent, id )
		-- only, so the same data rides in the closure.
		local owner, countType = self, str
		ent:CallOnRemove( "GetCountUpdate", function()
			if ( !IsValid( owner ) ) then
				owner = player.GetByUniqueID( key )
			end

			if ( !IsValid( owner ) ) then
				QueueUpdateCleanup( key, countType )
				return
			end

			QueueUpdateCounts( owner, countType )
		end )

	end

end

function meta:GetTool( mode )

	local wep = self:GetWeapon( "gmod_tool" )
	if ( !IsValid( wep ) || !wep.GetToolObject ) then return nil end

	local tool = wep:GetToolObject( mode )
	if ( !tool ) then return nil end

	return tool

end

if ( SERVER ) then

	function meta:AddCleanup( type, ent )
		cleanup.Add( self, type, ent )
	end

	function meta:LimitHit( str )
		self:SendLua( string.format( "hook.Run('LimitHit',%q)", str ) )
	end

	function meta:SendHint( str, delay )
		self.Hints = self.Hints or {}
		if ( self.Hints[ str ] ) then return end

		self:SendLua( string.format( "hook.Run('AddHint',%q,%d)", str, delay ) )
		self.Hints[ str ] = true
	end

	function meta:SuppressHint( str )
		self.Hints = self.Hints or {}
		if ( self.Hints[ str ] ) then return end

		self:SendLua( string.format( "hook.Run('SuppressHint',%q)", str ) )
		self.Hints[ str ] = true
	end

end
