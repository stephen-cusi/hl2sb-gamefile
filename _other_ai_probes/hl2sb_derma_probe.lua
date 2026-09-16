-- Final acceptance probe for the custom derma framework: every control in
-- batch 1 must create, and its key interaction path must run.
-- Runs from lua/autorun/client on map load. Delete after verification.

local function Log( fmt, ... ) print( "[DERMA] " .. string.format( fmt, ... ) ) end

local ALL = {
	"DPanel", "DLabel", "DButton", "DImageButton", "DTextEntry", "DCheckBox",
	"DScrollBar", "DScrollPanel", "DScroller", "DSlider", "DNumSlider",
	"DFrame", "DListView", "DListView_Line", "DMenu", "DMenuBar", "DTooltip",
	"DCollapsibleCategory", "DCategoryList", "DPropertySheet", "DNotify",
	"NoticePanel",
}

local ok, err = pcall( function()
	-- 1. registry: every batch-1 control present
	local missing = {}
	for _, n in ipairs( ALL ) do
		if ( not vgui.GetControlTable( n ) ) then missing[ #missing + 1 ] = n end
	end
	Log( "registry %d/%d present, missing=[%s]", #ALL - #missing, #ALL, table.concat( missing, "," ) )

	-- 2. instantiate each and exercise its headline behaviour
	local created = {}
	local function Mk( cls, parent )
		local p = vgui.Create( cls, parent or nil, "acc_" .. cls )
		if ( IsValid( p ) ) then created[ #created + 1 ] = p end
		return p
	end

	local f = Mk( "DFrame" )
	f:SetTitle( "acceptance" )
	f:SetSize( 520, 420 )
	f:MakePopup()

	local lbl = Mk( "DLabel", f )
	lbl:SetText( "label" )
	lbl:SizeToContents()

	local btn = Mk( "DButton", f )
	btn:SetText( "press" )
	local clicks = 0
	btn.DoClick = function() clicks = clicks + 1 end
	btn:DoClick()

	local ib = Mk( "DImageButton", f )
	ib:SetText( "img" )
	ib:SetImage( "materials/vgui/tutorials/icon16/hl2.png" )

	local te = Mk( "DTextEntry", f )
	local teFired = 0
	te.OnValueChange = function() teFired = teFired + 1 end
	te:SetText( "typed" )

	local cbx = Mk( "DCheckBox", f )
	local cbFired = 0
	cbx.OnChange = function() cbFired = cbFired + 1 end
	cbx:SetChecked( true )
	cbx:SetChecked( false )

	local sb = Mk( "DScrollBar", f )
	sb:SetVertical( true )
	sb:SetEnabled( true )
	sb:SetValue( 0.5 )

	local sp = Mk( "DScrollPanel", f )
	for i = 1, 10 do
		local row = vgui.Create( "DButton", sp:GetCanvas(), "row" .. i )
		row:SetPos( 0, ( i - 1 ) * 20 )
		row:SetSize( 100, 20 )
	end
	sp:SetContentHeight( 220 )
	sp:OnMouseWheeled( -1 )

	local sc = Mk( "DScroller", f )

	local sl = Mk( "DSlider", f )
	local slFired = 0
	sl.OnValueChanged = function() slFired = slFired + 1 end
	sl:SetValue( 0.25 )

	local ns = Mk( "DNumSlider", f )
	ns:SetText( "num" )
	ns:SetMin( 0 )
	ns:SetMax( 100 )
	ns:SetValue( 42 )

	local lv = Mk( "DListView", f )
	lv:AddColumn( "A" )
	lv:AddColumn( "B" )
	local row1 = lv:AddRow( "1", "2" )
	local row2 = lv:AddRow( "3", "4" )
	lv:OnClickLine( row2 )
	local sel = lv:GetSelectedLine()

	local menu = Mk( "DMenu" )
	local menuFired = 0
	menu:AddOption( "opt", function() menuFired = menuFired + 1 end )

	local mb = Mk( "DMenuBar" )
	mb:AddMenu( "File" )

	local tt = Mk( "DTooltip" )

	local cc = Mk( "DCollapsibleCategory", f )
	cc:SetLabel( "cat" )
	cc:Toggle()
	cc:Toggle()

	local cl = Mk( "DCategoryList", f )
	cl:AddCategory( "c1", "", true, 1 )

	local ps = Mk( "DPropertySheet", f )
	ps:AddSheet( "Tab1", vgui.Create( "DPanel", f, "tabpnl1" ) )
	ps:AddSheet( "Tab2", vgui.Create( "DPanel", f, "tabpnl2" ) )

	local dn = Mk( "DNotify", f )
	dn:SetType( NOTIFY_HINT )
	dn:SetTitle( "t" )
	dn:SetText( "n" )

	Log( "interactions: btn-clicks=%d te=%d cb=%d sb-val=%.2f sp-pos=%d sl=%d ns-val=%s lv-sel=%s row1col=%q menu-opts=%d ps-tabs=%d cc-collapsed=%s",
		clicks, teFired, cbFired, sb:GetValue(),
		math.floor( sp:GetValue() ), slFired, tostring( ns:GetValue() ),
		tostring( sel == row2 ), tostring( row1:GetColText( 1 ) ),
		menu.m_iHeight and math.floor( menu.m_iHeight / 20 ) or -1,
		#ps.m_tTabs, tostring( cc.m_bCollapsed ) )

	-- 3. notifications via the module surface
	notification.AddLegacy( "acc notice", NOTIFY_UNDO, 2 )
	notification.AddProgress( "acc", "progress", 0.3 )
	notification.Kill( "acc" )
	Log( "notifications OK" )

	-- 4. skin painting does not throw for any control (pcall Paint once)
	local paintErrs = 0
	for _, p in ipairs( created ) do
		if ( IsValid( p ) and p.Paint ) then
			local ok2 = pcall( function() p:Paint( p:GetWide(), p:GetTall() ) end )
			if ( not ok2 ) then paintErrs = paintErrs + 1 end
		end
	end
	Log( "Paint pcall pass: %d/%d clean (errs=%d)", #created - paintErrs, #created, paintErrs )

	-- cleanup
	for _, p in ipairs( created ) do
		if ( IsValid( p ) ) then p:Remove() end
	end
	collectgarbage( "collect" )
	Log( "ACCEPTANCE DONE" )
end )

if not ok then
	Log( "ACCEPTANCE ERROR: %s", tostring( err ) )
end
