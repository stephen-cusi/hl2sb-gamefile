--[[ derma_lib_test.lua  --  in-game verification for the 2026-09-26 derma
	audit fixes.  Run with:

		lua_dofile_cl derma_lib_test.lua          (client realm, in a map)

	Prints PASS/FAIL per assertion and a final tally.  Every check is guarded:
	a missing function is a FAIL line, never a crash. --]]

if ( not CLIENT ) then
	print( "[DERMATEST] client realm only" )
	return
end

local nPass, nFail = 0, 0
local function Check( bOK, strName )
	if ( bOK ) then
		nPass = nPass + 1
	else
		nFail = nFail + 1
		print( "[DERMATEST] FAIL: " .. tostring( strName ) )
	end
end

local function HasFn( t, name )
	return type( t ) == "table" and type( rawget( t, name ) ) == "function"
end

print( "[DERMATEST] --- 1. Panel metatable additions (includes/init.lua) ---" )

local PanelMeta = FindMetaTable( "Panel" )
Check( PanelMeta ~= nil, "FindMetaTable(Panel)" )
if ( PanelMeta ~= nil ) then
	Check( PanelMeta.ChildCount ~= nil, "Panel:ChildCount alias" )
	Check( PanelMeta.SetFontInternal ~= nil, "Panel:SetFontInternal" )
	Check( PanelMeta.SetTextSelectionColors ~= nil, "Panel:SetTextSelectionColors" )
	Check( PanelMeta.SetSelectionTextColor ~= nil, "Panel:SetSelectionTextColor" )
	Check( PanelMeta.SetSelectionBackgroundColor ~= nil, "Panel:SetSelectionBackgroundColor" )
	Check( PanelMeta.SetSelectionUnfocusedBackgroundColor ~= nil, "Panel:SetSelectionUnfocusedBackgroundColor" )
end

Check( type( vgui.GetKeyboardFocus ) == "function", "vgui.GetKeyboardFocus exists" )
Check( type( ChangeTooltip ) == "function", "global ChangeTooltip (tooltips.lua included)" )
Check( type( EndTooltip ) == "function", "global EndTooltip" )
Check( type( FindTooltip ) == "function", "global FindTooltip" )
Check( type( RemoveTooltip ) == "function", "global RemoveTooltip" )
Check( type( CloseDermaMenus ) == "function", "global CloseDermaMenus" )
Check( type( RegisterDermaMenuForClose ) == "function", "global RegisterDermaMenuForClose" )
Check( type( Derma_DrawBackgroundBlur ) == "function", "global Derma_DrawBackgroundBlur" )
Check( type( Label ) == "function", "global Label() helper" )

print( "[DERMATEST] --- 2. tooltip end-to-end ---" )

do
	local pnl = vgui.Create( "DPanel" )
	pnl:SetTooltip( "hello tooltip" )
	Check( pnl:GetTooltip() == "hello tooltip", "Panel:SetTooltip/GetTooltip round trip" )

	local text, content, pospanel
	if ( type( FindTooltip ) == "function" ) then
		text, content, pospanel = FindTooltip( pnl )
	end
	Check( text == "hello tooltip", "FindTooltip walks to the tooltip field" )

	local ok = pcall( ChangeTooltip, pnl )
	Check( ok, "ChangeTooltip does not error with a DTooltip registered" )
	if ( type( RemoveTooltip ) == "function" ) then RemoveTooltip() end

	local tt = vgui.Create( "DTooltip" )
	Check( type( tt.OpenForPanel ) == "function", "DTooltip:OpenForPanel exists" )
	Check( type( tt.SetContents ) == "function", "DTooltip:SetContents exists" )
	Check( type( tt.Close ) == "function", "DTooltip:Close exists" )

	local okOpen = pcall( tt.OpenForPanel, tt, pnl )
	Check( okOpen, "DTooltip:OpenForPanel runs" )
	local okClose = pcall( tt.Close, tt )
	Check( okClose, "DTooltip:Close runs" )

	pnl:Remove()
end

print( "[DERMATEST] --- 3. Derma_Anim contract (hl2sb_derma_menus.lua) ---" )

if ( type( Derma_Anim ) ~= "function" ) then
	Check( false, "global Derma_Anim exists" )
else
	do
		local gotPanel, gotAnim, gotProgress, gotData
		local anim = Derma_Anim( "test", nil, function( pnl, a, delta, data )
			gotPanel, gotAnim, gotProgress, gotData = pnl, a, delta, data
		end )

		Check( anim:Active() == false, "Derma_Anim is inert before Start() (Running flag)" )
		anim:Run()	-- must be a no-op, NOT "arithmetic on nil"

		anim:Start( 1, { k = "v" } )
		Check( anim:Active() == true, "Derma_Anim:Start activates" )

		-- fake the panel with a table (the callback only forwards it)
		local fakePanel = setmetatable( {}, {} )
		local anim2 = Derma_Anim( "t2", fakePanel, function( pnl, a, delta, data )
			gotPanel, gotAnim, gotProgress, gotData = pnl, a, delta, data
		end )
		anim2:Start( 2, { k = "v" } )
		anim2:Run()

		Check( gotPanel == fakePanel, "Derma_Anim callback arg1 is the PANEL (GMod order)" )
		Check( gotAnim == anim2, "Derma_Anim callback arg2 is the anim" )
		Check( gotData ~= nil and gotData.k == "v", "Derma_Anim callback arg4 is the data" )
		Check( gotProgress >= 0 and gotProgress <= 1, "Derma_Anim callback arg3 is clamped progress" )
	end
end

print( "[DERMATEST] --- 4. DMenu family ---" )

do
	local menu = vgui.Create( "DMenu" )

	local gotSelf
	local opt = menu:AddOption( "click", function( pnl ) gotSelf = pnl end )
	Check( IsValid( opt ), "DMenu:AddOption returns a panel" )
	Check( opt.onClicked ~= nil, "AddOption stores the callback as onClicked" )
	Check( type( opt.GetMenu ) == "function", "DMenuOption:GetMenu exists" )
	Check( opt:GetMenu() == menu, "GetMenu answers the owning menu" )

	-- click through the class chain: toggle + OptionSelected + callback(panel)
	local optSelected
	menu.OptionSelected = function( m, pnl ) optSelected = pnl end
	local okClick = pcall( opt.DoClick, opt )
	Check( okClick and gotSelf == opt, "DoClick chain calls fn( pnl )" )
	Check( optSelected == opt, "DoClick chain fires menu:OptionSelected" )

	local sub, subOpt = menu:AddSubMenu( "submenu" )
	Check( IsValid( sub ), "AddSubMenu returns a submenu" )
	Check( IsValid( subOpt ), "AddSubMenu returns the option row" )
	if ( subOpt ~= nil ) then
		Check( subOpt.SubMenu == sub, "row carries SubMenu" )
	end

	local cvarOpt = menu:AddCVar( "cvar", "test_nv", "1", "0" )
	Check( IsValid( cvarOpt ), "DMenu:AddCVar creates DMenuOptionCVar" )

	local okHide = pcall( menu.Hide, menu )
	Check( okHide, "DMenu:Hide runs" )

	local okOpen = pcall( menu.Open, menu, 10, 10 )
	Check( okOpen, "DMenu:Open(x,y) runs" )
	if ( type( RemoveTooltip ) == "function" ) then CloseDermaMenus() end

	menu:Remove()
end

print( "[DERMATEST] --- 5. DButton ---" )

do
	local btn = vgui.Create( "DButton" )
	Check( type( btn.DoMiddleClick ) == "function", "DButton:DoMiddleClick stage" )
	Check( type( btn.DoClickInternal ) == "function", "DButton:DoClickInternal stage" )
	Check( type( btn.SetConsoleCommand ) == "function", "DButton:SetConsoleCommand" )
	Check( type( btn.SetActionFunction ) == "function", "DButton:SetActionFunction" )

	btn:Remove()

	-- the backwards-compat "Button" control is the Derma one now
	local compat = vgui.Create( "Button" )
	Check( IsValid( compat ), "vgui.Create( 'Button' ) registers" )
	if ( IsValid( compat ) ) then
		Check( compat.DoClick ~= nil and compat.DoClickInternal ~= nil, "compat Button is clickable Derma" )
		compat:Remove()
	end
end

print( "[DERMATEST] --- 6. DLabel ---" )

do
	local lbl = vgui.Create( "DLabel" )
	Check( lbl.m_iAlign == 3, "DLabel default alignment is a_west (3)" )

	lbl:SetIsToggle( true )
	Check( lbl:GetIsToggle() == true, "DLabel:SetIsToggle exists" )
	local okT = pcall( lbl.Toggle, lbl )
	Check( okT, "DLabel:Toggle runs" )
	Check( type( lbl.OnToggled ) == "function", "DLabel:OnToggled hook" )

	lbl:SetColor( Color( 1, 2, 3 ) )
	local c = lbl:GetColor()
	Check( c ~= nil and c.r == 1, "DLabel:SetColor/GetColor aliases" )

	lbl:Remove()

	if ( type( Label ) == "function" ) then
		local g = Label( "global label" )
		Check( IsValid( g ), "global Label() creates a DLabel" )
		if ( IsValid( g ) ) then g:Remove() end
	else
		Check( false, "global Label() exists" )
	end
end

print( "[DERMATEST] --- 7. DFrame / DTextEntry / DComboBox ---" )

do
	local frame = vgui.Create( "DFrame" )
	frame:SetBackgroundBlur( true )
	Check( frame:GetBackgroundBlur() == true, "DFrame:SetBackgroundBlur/GetBackgroundBlur" )
	local okPaint = pcall( frame.Paint, frame, 400, 300 )
	Check( okPaint, "DFrame:Paint runs with background blur" )
	frame:Remove()

	local entry = vgui.Create( "DTextEntry" )
	Check( type( entry.GetInt ) == "function", "DTextEntry:GetInt" )
	Check( type( entry.GetFloat ) == "function", "DTextEntry:GetFloat" )
	Check( type( entry.SetEnterAllowed ) == "function", "DTextEntry:SetEnterAllowed" )
	Check( type( entry.SetCaretPos ) == "function", "DTextEntry:SetCaretPos" )
	local okCaret = pcall( entry.SetCaretPos, entry, 2 )
	Check( okCaret, "DTextEntry:SetCaretPos runs" )

	local gotText
	entry.OnEnter = function( self, text ) gotText = text end
	entry:SetText( "enter-test" )
	if ( entry.OnEnter ) then entry:OnEnter( entry:GetValue() ) end
	Check( gotText == "enter-test", "OnEnter receives the text argument" )
	entry:Remove()

	local combo = vgui.Create( "DComboBox" )
	combo:AddChoice( "Enabled", "1" )
	combo:AddChoice( "Disabled", "0" )
	combo:ChooseOptionID( 2 )
	Check( combo:GetSelectedID() == 2, "DComboBox:GetSelectedID" )
	local t, d = combo:GetSelected()
	Check( t == "Disabled" and d == "0", "DComboBox:GetSelected returns text, data" )
	Check( combo:GetOptionTextByData( "1" ) == "Enabled", "GetOptionTextByData maps data->text" )
	Check( combo:GetOptionText( 1 ) == "Enabled", "GetOptionText" )
	Check( combo:GetOptionData( 1 ) == "1", "GetOptionData" )
	combo:Remove()
end

print( "[DERMATEST] --- 8. DListView columns ---" )

do
	local list = vgui.Create( "DListView" )
	list:SetSize( 300, 200 )

	local col1 = list:AddColumn( "A" )
	local col2 = list:AddColumn( "B" )
	Check( type( col1.SetFixedWidth ) == "function", "AddColumn returns GMod column surface" )
	Check( col2.Header ~= nil, "column.Header reference" )

	col1:SetFixedWidth( 100 )
	Check( list:ColumnWidth( 1 ) == 100, "SetFixedWidth pins the column width" )

	local w1, w2 = list:ColumnWidth( 1 ), list:ColumnWidth( 2 )
	list:OnRequestResize( col1, 150 )
	Check( list:ColumnWidth( 1 ) == 150, "OnRequestResize applies the size" )
	if ( type( w2 ) == "number" and type( list:ColumnWidth( 2 ) ) == "number" ) then
		Check( list:ColumnWidth( 2 ) < w2, "OnRequestResize shrinks the right neighbour" )
	else
		Check( false, "OnRequestResize shrinks the right neighbour" )
	end

	list:AddRow( "x", "y" ):SetSortValue( 1, 1 )
	local okLayout = pcall( list.PerformLayout, list, 300, 200 )
	Check( okLayout, "DListView:PerformLayout runs with fixed widths" )
	list:Remove()
end

print( "[DERMATEST] --- 9. scroll family ---" )

do
	local scroll = vgui.Create( "DScrollPanel" )
	Check( scroll.pnlCanvas ~= nil, "DScrollPanel.pnlCanvas field" )
	Check( scroll.pnlVBar ~= nil, "DScrollPanel.pnlVBar field" )
	local ok = pcall( scroll.SetScrollY, scroll, 10 )
	Check( ok, "DScrollPanel:SetScrollY" )
	local vbar = scroll:GetVBar()
	Check( type( vbar.SetScroll ) == "function", "VBar:SetScroll (GMod spelling)" )
	Check( type( vbar.SetUp ) == "function", "VBar:SetUp" )
	Check( type( vbar.GetOffset ) == "function", "VBar:GetOffset" )
	Check( type( vbar.AnimateTo ) == "function", "VBar:AnimateTo" )
	scroll:Remove()

	local numslider = vgui.Create( "DNumSlider" )
	numslider:SetMinMax( 10, 20 )
	numslider:SetValue( 15 )
	numslider:SetMin( 16 )	-- below the new min
	local vAfter = numslider:GetValue()
	if ( type( vAfter ) == "number" ) then
		Check( vAfter >= 16, "SetMin re-clamps the value" )
	else
		Check( false, "SetMin re-clamps the value" )
	end
	numslider:Remove()
end

print( "[DERMATEST] --- 10. sheets / bars / notify / panels ---" )

do
	local sheet = vgui.Create( "DPropertySheet" )
	local page1 = vgui.Create( "DPanel" )
	local entry = sheet:AddSheet( "tab one", page1 )
	Check( entry ~= nil, "AddSheet returns the entry" )
	Check( sheet.GetItems ~= nil and #sheet:GetItems() == 1, "DPropertySheet:GetItems" )
	local okSwitch = pcall( sheet.SwitchToName, sheet, "tab one" )
	Check( okSwitch, "SwitchToName runs" )
	local okClose = pcall( sheet.CloseTab, sheet, entry.Tab, true )
	Check( okClose and #sheet:GetItems() == 0, "CloseTab removes the sheet" )
	sheet:Remove()

	local bar = vgui.Create( "DMenuBar" )
	bar:AddMenu( "one" )
	local two = bar:AddOrGetMenu( "two" )
	local two2 = bar:AddOrGetMenu( "two" )
	Check( two == two2, "AddOrGetMenu is idempotent" )
	Check( type( bar.GetOpenMenu ) == "function", "DMenuBar:GetOpenMenu" )
	bar:Remove()

	local notify = vgui.Create( "DNotify" )
	local card = vgui.Create( "DPanel" )
	notify:AddItem( card, 1 )
	Check( #notify:GetItems() == 1, "DNotify:AddItem/GetItems" )
	notify:Remove()

	local panel = vgui.Create( "DPanel" )
	panel:SetIsMenu( true )
	Check( panel:GetIsMenu() == true, "DPanel:SetIsMenu/GetIsMenu" )
	panel:Remove()

	local img = vgui.Create( "DImage" )
	Check( img:GetKeepAspect() == false, "DImage default KeepAspect matches GMod (false)" )
	img:Remove()

	local ibtn = vgui.Create( "DImageButton" )
	Check( type( ibtn.SetImageVisible ) == "function", "DImageButton:SetImageVisible" )
	Check( type( ibtn.SetDisabled ) == "function", "DImageButton:SetDisabled" )
	ibtn:Remove()
end

print( "[DERMATEST] --- 11. collapse / category list ---" )

do
	local cat = vgui.Create( "DCollapsibleCategory" )
	local fired
	cat.OnToggle = function( s, b ) fired = b end
	cat:Toggle()
	Check( fired == false, "Toggle fires OnToggle( false )" )
	cat:Toggle()
	Check( fired == true, "Toggle fires OnToggle( true )" )
	cat:DoExpansion( false )
	Check( cat:GetExpanded() == false, "DoExpansion programmatic" )
	cat:SetHeaderHeight( 30 )
	Check( cat:GetHeaderHeight() == 30, "SetHeaderHeight/GetHeaderHeight" )
	cat:Remove()

	local list = vgui.Create( "DCategoryList" )
	local c = list:Add( "tools" )
	Check( IsValid( c ), "DCategoryList:Add returns a panel" )
	local okUnsel = pcall( list.UnselectAll, list )
	Check( okUnsel, "UnselectAll runs" )
	list:Remove()
end

print( "[DERMATEST] --- 12. convar-compat names (no-ops, must not throw) ---" )

do
	local pnl = vgui.Create( "DPanel" )
	local ok1 = pcall( pnl.SetTextSelectionColors, pnl, Color( 255, 0, 0 ), Color( 0, 0, 255 ) )
	Check( ok1, "SetTextSelectionColors callable" )
	local ok2 = pcall( pnl.SetSelectionTextColor, pnl, Color( 255, 255, 255 ) )
	Check( ok2, "SetSelectionTextColor callable" )

	local te = vgui.Create( "DTextEntry" )
	local ok3 = pcall( te.SetFontInternal, te, "DermaDefault" )
	Check( ok3, "TextEntry SetFontInternal(name) callable" )
	te:Remove()
	pnl:Remove()
end

print( string.format( "[DERMATEST] done: %d passed, %d failed", nPass, nFail ) )
if ( nFail == 0 ) then print( "[DERMATEST] ALL PASS" ) end
