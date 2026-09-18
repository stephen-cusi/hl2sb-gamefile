
menubar = {}

function menubar.Init()

	-- HL2SB: this module is shared, but the menu bar is a vgui panel and the SERVER
	-- realm has no `vgui` library at all.  hook.Add( "OnGamemodeLoaded", "CreateMenuBar" )
	-- below runs on BOTH realms, so every map load printed
	--     Hook 'CreateMenuBar' (OnGamemodeLoaded) Failed: menubar.lua:6:
	--     attempt to index a nil value (global 'vgui')
	-- (46 of them in one session).  GMod's menubar is client-side only.
	if ( vgui == nil ) then return end

	menubar.Control = vgui.Create( "DMenuBar" )
	menubar.Control:Dock( TOP )
	menubar.Control:SetVisible( false )
	
	hook.Run( "PopulateMenuBar", menubar.Control )

end

function menubar.ParentTo( pnl )

	if ( vgui == nil ) then return end

	// I don't like this
	if ( !IsValid( menubar.Control ) ) then
		menubar.Init()
	end

	menubar.Control:SetParent( pnl )
	menubar.Control:MoveToBack()
	menubar.Control:SetHeight( 30 )
	menubar.Control:SetVisible( true )

end

function menubar.IsParent( pnl )

	return menubar.Control:GetParent() == pnl

end


hook.Add( "OnGamemodeLoaded", "CreateMenuBar", function()

	menubar.Init()

end )
