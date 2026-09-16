-- HL2SB: 对照实验 —— 不覆盖 Frame.Paint，只挂子面板（和之前能画出橙面板的那次一致）
--   lua_dofile_cl hl2sb_test_window.lua
-- 预期（如果和之前那次一样能画出来）：标题栏 + 右侧三个图标 + 橙色块 + 小蓝块
-- 如果这次也不画 ⇒ 子面板绘制真的坏了（与我的红框覆盖无关）

local function L( s ) print( "[WINTEST] " .. tostring( s ) ) end

local ok, err = pcall( function()
	for k, p in pairs( vgui.GetAll() ) do
		if ( p.GetClassName and p:GetClassName() == "DFrame" ) then p:Remove() end
	end

	local Frame = vgui.Create( "DFrame" )
	Frame:SetPos( 60, 60 )
	Frame:SetSize( 350, 220 )
	Frame:SetTitle( "Test panel" )
	Frame:ShowCloseButton( true )
	Frame:SetMinimizeButtonVisible( true )
	Frame:SetMaximizeButtonVisible( true )
	Frame:MakePopup()

	-- 子面板 1：橙色大块（挂 frame，y=24）
	local body = vgui.Create( "DPanel", Frame )
	body:SetPos( 0, 24 )
	body:SetSize( 350, 100 )
	body.Paint = function( s, w, h )
		surface.DrawSetColor( 200, 90, 40, 255 )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	-- 子面板 2：绿色块（挂在橙色块里面，测二层递归）
	local inner = vgui.Create( "DPanel", body )
	inner:SetPos( 10, 10 )
	inner:SetSize( 100, 40 )
	inner.Paint = function( s, w, h )
		surface.DrawSetColor( 0, 200, 0, 255 )
		surface.DrawFilledRect( 0, 0, w, h )
	end

	-- 子面板 3：DButton（有文字，测文字+按钮绘制）
	local btn = vgui.Create( "DButton", Frame )
	btn:SetText( "Click me I'm pretty!" )
	btn:SetPos( 100, 150 )
	btn:SetSize( 150, 30 )

	L( "no Paint override on the frame - children only" )
	L( "DONE" )
end )

if ( not ok ) then L( "FAILED: " .. tostring( err ) ) end
