--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/cl_hudpickup.lua

    Garry's Mod gamemodes/base/gamemode/cl_hudpickup.lua 的同款移植。原文取自
    本地 GMod 安装（D:\games\garrysmod\garrysmod\gamemodes\base\gamemode\
    cl_hudpickup.lua，173 行），正文逐行照抄；对外的 API 面与 GMod 完全一致：

        GM.PickupHistory / GM.PickupHistoryLast / GM.PickupHistoryTop
        GM.PickupHistoryWide / GM.PickupHistoryCorner
        GM:HUDWeaponPickedUp( weapon )          -- wiki: 收到的是 Weapon 实体
        GM:HUDItemPickedUp( itemName )          -- wiki: string
        GM:HUDAmmoPickedUp( itemName, amount )  -- wiki: string + number
        GM:HUDDrawPickupHistory()

    绘制链与 GMod 相同：GM:HUDPaint（cl_init.lua，已照抄 GMod 的三行
    hook.Run）→ hook.Run( "HUDDrawPickupHistory" ) → gamemode 方法。
    由本 fork 的 sandbox gamemode 经 table.inherit 从 base 继承。

    HL2SB delta（共两处，正文内均已标注）：

      1. 本地化。GMod 把 "#item_battery" 原样交给 draw.SimpleText，由它的
         引擎在绘制时解析 #token；本 fork 的 surface 文本不解析 token，所以在
         入队时解析成 pickup.text，绘制与测宽都用它。

      2. 文件末尾的事件适配器。GMod 的引擎直接以 GMod 签名驱动三个
         GM:HUD*Pick* 方法；本 fork 的 C++（hud_killfeed.cpp）把 item_pickup
         游戏事件转发成 hook "HUDItemPickedUp"( userid, item, amount )。适配器
         负责分类并翻译成 GMod 签名，同时 RETURN 非 nil 值短路 hook.call 的
         gamemode 回退——否则回退会把原始三元组（首参是 userid）喂给
         GM:HUDItemPickedUp( itemName )，每次拾取多压一条 "#<userid>" 垃圾条目。
--------------------------------------------------------------------------]]

GM.PickupHistory = {}
GM.PickupHistoryLast = 0
GM.PickupHistoryTop = ScrH() / 2
GM.PickupHistoryWide = 300
GM.PickupHistoryCorner = surface.GetTextureID( "gui/corner8" )

-- HL2SB delta 1: token -> 显示文本。GMod 绘制时由引擎解析，这里提前解析。
local function LocalName( raw )
	if ( type( raw ) ~= "string" ) then return tostring( raw ) end

	local key = raw
	if ( key:sub( 1, 1 ) == "#" ) then key = key:sub( 2 ) end

	if ( _G.Localizations ~= nil and _G.Localizations.Find ~= nil ) then
		-- Source 的 Find() 带不带前导 '#' 都接受。
		for _, tok in ipairs( { "#" .. key, key } ) do
			local ok, txt = pcall( _G.Localizations.Find, tok )
			if ( ok and type( txt ) == "string" and txt ~= ""
			     and txt ~= tok and txt ~= key ) then
				return txt
			end
		end
	end

	if ( _G.language ~= nil and _G.language.GetPhrase ~= nil ) then
		local ok, txt = pcall( _G.language.GetPhrase, key )
		if ( ok and type( txt ) == "string" and txt ~= "" and txt ~= key ) then
			return txt
		end
	end

	-- 兜底：类名转可读词 -- "item_battery" -> "Battery"。
	local s = key:gsub( "^weapon_", "" ):gsub( "^item_", "" ):gsub( "_", " " )
	return ( s:gsub( "^%l", string.upper ) )
end

local function AddGenericPickup( self, itemname )
	local pickup		= {}
	pickup.time			= CurTime()
	pickup.name			= itemname
	pickup.text			= LocalName( itemname )		-- HL2SB delta 1
	pickup.holdtime		= 5
	pickup.font			= "DermaDefaultBold"
	pickup.fadein		= 0.04
	pickup.fadeout		= 0.3

	-- ⚠️ measure with the EXACT handle draw.SimpleText renders with
	-- (draw.GetFont).  The 1-arg surface.GetTextSize measured the fallback
	-- small font (w=106/h=11 for a 26-char string, 2026-09-26 diag) and the
	-- box never covered the text; derma.GetTextSize resolves a different
	-- registry than the renderer.  Same-handle measurement = box == text.
	local hFont = ( draw ~= nil and draw.GetFont ~= nil ) and draw.GetFont( pickup.font or "DermaDefault" ) or nil
	local w, h = 0, 0
	if ( hFont ~= nil and surface.GetTextSize ~= nil ) then
		w, h = surface.GetTextSize( hFont, pickup.text or "" )
	end
	w = w or 0
	h = h or 0	-- HL2SB delta 1: 量实际绘制的那串
	pickup.height		= h
	pickup.width		= w

	-- HL2SB (2026-09-26): collapse duplicate events.  Two server paths can
	-- both fire item_pickup for one physical pickup (hl2mp BumpWeapon's
	-- new-weapon notice + the EquipAmmoOnly notice when the reserve tops up
	-- in the same second), and the strip then showed two identical rows.
	-- A same-name event inside 0.5s refreshes the row instead of stacking.
	for _, v in ipairs( self.PickupHistory ) do
		if ( v.name == pickup.name and ( CurTime() - ( v.time or 0 ) ) < 0.5 ) then
			v.time = CurTime() - ( v.fadein or 0.04 )
			self.PickupHistoryLast = pickup.time
			return v
		end
	end

	table.insert( self.PickupHistory, pickup )
	self.PickupHistoryLast = pickup.time

	return pickup
end

--[[---------------------------------------------------------
	Name: gamemode:HUDWeaponPickedUp( wep )
	Desc: The game wants you to draw on the HUD that a weapon has been picked up
-----------------------------------------------------------]]
function GM:HUDWeaponPickedUp( wep )

	if ( !IsValid( LocalPlayer() ) || !LocalPlayer():Alive() ) then return end
	if ( !IsValid( wep ) ) then return end
	if ( !isfunction( wep.GetPrintName ) ) then return end

	local pickup = AddGenericPickup( self, wep:GetPrintName() )
	pickup.color = Color( 255, 200, 50, 255 )

end

--[[---------------------------------------------------------
	Name: gamemode:HUDItemPickedUp( itemname )
	Desc: An item has been picked up..
-----------------------------------------------------------]]
function GM:HUDItemPickedUp( itemname )

	if ( !IsValid( LocalPlayer() ) || !LocalPlayer():Alive() ) then return end

	local pickup = AddGenericPickup( self, "#" .. itemname )
	pickup.color = Color( 180, 255, 180, 255 )

end

--[[---------------------------------------------------------
	Name: gamemode:HUDAmmoPickedUp( itemname, amount )
	Desc: Ammo has been picked up..
-----------------------------------------------------------]]
function GM:HUDAmmoPickedUp( itemname, amount )

	if ( !IsValid( LocalPlayer() ) || !LocalPlayer():Alive() ) then return end

	-- Try to tack it onto an exisiting ammo pickup
	if ( self.PickupHistory ) then

		for k, v in pairs( self.PickupHistory ) do

			if ( v.name == "#" .. itemname .. "_ammo" ) then

				v.amount = tostring( tonumber( v.amount ) + amount )
				v.time = CurTime() - v.fadein
				return

			end

		end

	end

	local pickup = AddGenericPickup( self, "#" .. itemname .. "_ammo" )
	pickup.color = Color( 180, 200, 255, 255 )
	pickup.amount = tostring( amount )

	-- same-handle measurement as AddGenericPickup (draw.GetFont, see there)
	local amtFont = ( draw ~= nil and draw.GetFont ~= nil ) and draw.GetFont( pickup.font or "DermaDefault" ) or nil
	local w2 = 0
	if ( amtFont ~= nil and surface.GetTextSize ~= nil ) then
		w2 = select( 1, surface.GetTextSize( amtFont, pickup.amount or "" ) ) or 0
	end
	pickup.width = pickup.width + w2 + 16

end

function GM:HUDDrawPickupHistory()

	if ( self.PickupHistory == nil ) then return end

	local x, y = ScrW() - self.PickupHistoryWide - 20, self.PickupHistoryTop
	local tall = 0
	local wide = 0

	for k, v in pairs( self.PickupHistory ) do

		if ( !istable( v ) ) then

			Msg( tostring( v ) .. "\n" )
			PrintTable( self.PickupHistory )
			self.PickupHistory[ k ] = nil
			return
		end

		if ( v.time < CurTime() ) then

			if ( v.y == nil ) then v.y = y end

			v.y = ( v.y * 5 + y ) / 6

			local delta = ( v.time + v.holdtime ) - CurTime()
			delta = delta / v.holdtime

			local alpha = 255
			local colordelta = math.Clamp( delta, 0.6, 0.7 )

			-- Fade in/out
			if ( delta > 1 - v.fadein ) then
				alpha = math.Clamp( ( 1.0 - delta ) * ( 255 / v.fadein ), 0, 255 )
			elseif ( delta < v.fadeout ) then
				alpha = math.Clamp( delta * ( 255 / v.fadeout ), 0, 255 )
			end

			v.x = x + self.PickupHistoryWide - ( self.PickupHistoryWide * ( alpha / 255 ) )

			local rx, ry, rw, rh = math.Round( v.x - 4 ), math.Round( v.y - ( v.height / 2 ) - 4 ), math.Round( self.PickupHistoryWide + 9 ), math.Round( v.height + 8 )
			local bordersize = 8

			surface.SetTexture( self.PickupHistoryCorner )

			surface.SetDrawColor( v.color.r, v.color.g, v.color.b, alpha )
			surface.DrawTexturedRectRotated( rx + bordersize / 2, ry + bordersize / 2, bordersize, bordersize, 0 )
			surface.DrawTexturedRectRotated( rx + bordersize / 2, ry + rh -bordersize / 2, bordersize, bordersize, 90 )
			surface.DrawRect( rx, ry + bordersize, bordersize, rh-bordersize * 2 )
			surface.DrawRect( rx + bordersize, ry, v.height - 4, rh )

			surface.SetDrawColor( 230 * colordelta, 230 * colordelta, 230 * colordelta, alpha )
			surface.DrawTexturedRectRotated( rx + rw - bordersize / 2 , ry + rh - bordersize / 2, bordersize, bordersize, 180 )
			surface.DrawTexturedRectRotated( rx + rw - bordersize / 2 , ry + bordersize / 2, bordersize, bordersize, 270 )
			surface.DrawRect( rx + rw - bordersize, ry + bordersize, bordersize, rh-bordersize * 2 )
			surface.DrawRect( rx + bordersize + v.height - 4, ry, rw - ( v.height - 4 ) - bordersize * 2, rh )

			-- HL2SB delta 1: v.text 是 v.name 的本地化结果
			draw.SimpleText( v.text or v.name, v.font, v.x + v.height + 9, ry + ( rh / 2 ) + 1, Color( 0, 0, 0, alpha * 0.5 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			draw.SimpleText( v.text or v.name, v.font, v.x + v.height + 8, ry + ( rh / 2 ), Color( 255, 255, 255, alpha ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

			if ( v.amount ) then

				draw.SimpleText( v.amount, v.font, v.x + self.PickupHistoryWide + 1, ry + ( rh / 2 ) + 1, Color( 0, 0, 0, alpha * 0.5 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
				draw.SimpleText( v.amount, v.font, v.x + self.PickupHistoryWide, ry + ( rh / 2 ), Color( 255, 255, 255, alpha ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

			end

			y = y + ( v.height + 16 )
			tall = tall + v.height + 18
			wide = math.max( wide, v.width + v.height + 24 )

			if ( alpha == 0 ) then self.PickupHistory[ k ] = nil end

		end

	end

	self.PickupHistoryTop = ( self.PickupHistoryTop * 5 + ( ScrH() * 0.75 - tall ) / 2 ) / 6
	self.PickupHistoryWide = ( self.PickupHistoryWide * 5 + wide ) / 6

end

-- ===========================================================================
-- HL2SB delta 2: 引擎事件适配器。
--
-- GMod 的引擎以 GM:HUDWeaponPickedUp( Weapon ) / GM:HUDItemPickedUp( string )
-- / GM:HUDAmmoPickedUp( string, number ) 驱动 gamemode；本 fork 的
-- hud_killfeed.cpp 把 item_pickup 事件转发成
--     hook "HUDItemPickedUp"( userid, item, amount )
-- （本地玩家守卫在 C++ 侧）。这里分类翻译成 GMod 签名。
--
-- 每个分支末尾 return true 有双重作用：hook.lua 的 CallBody 在某个注册钩子
-- 返回非 nil 时立即返回、跳过 gamemode 回退——这挡住了回退用原始三元组
-- （首参 userid 是数字）错调 GM:HUDItemPickedUp( itemName )。返回值本身被
-- C++ 丢弃（END_LUA_CALL_HOOK 3, 0）。
-- ===========================================================================
hook.Add( "HUDItemPickedUp", "gmod_cl_hudpickup", function( userid, item, amount, weaponEntity )

	local ply = LocalPlayer()
	if ( not IsValid( ply ) ) then return true end
	if ( item == nil or item == "" ) then return true end

	-- GMod 只给本地玩家发；userid 校验保住这条语义。
	if ( isfunction( ply.UniqueID ) and ply:UniqueID() ~= userid ) then return true end

	local gm = GAMEMODE or _G._GAMEMODE
	if ( gm == nil ) then return true end

	local low = string.lower( item )

	-- 弹药事件带 "_ammo" 后缀；GMod 的 HUDAmmoPickedUp 收裸名、自己加后缀。
	if ( string.sub( low, -5 ) == "_ammo" ) then
		gm:HUDAmmoPickedUp( string.sub( item, 1, #item - 5 ), tonumber( amount ) or 0 )
		return true
	end

	if ( string.sub( low, 1, 7 ) == "weapon_" ) then
		-- wiki：GM:HUDWeaponPickedUp 收到的是 Weapon 实体。引擎第四参把背包里
		-- 按类名匹配到的武器实体递过来（hud_killfeed.cpp，m_hMyWeapons 对本地
		-- 玩家网络化）；激活武器匹配只作回退（捡起即部署的场景）。
		local wep = weaponEntity
		if ( not IsValid( wep ) ) then
			local active = ply:GetActiveWeapon()
			if ( IsValid( active ) and active:GetClass() == item ) then
				wep = active
			end
		end
		gm:HUDWeaponPickedUp( wep )
		return true
	end

	gm:HUDItemPickedUp( item )
	return true
end )
