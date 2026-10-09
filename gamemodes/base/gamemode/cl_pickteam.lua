--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/cl_pickteam.lua

    GMod base gamemode cl_pickteam.lua, ported for HL2SB (2026-10-10).
    Client realm, included from cl_init.lua.  GMod's client dispatches F2
    straight to GM:ShowTeam in the engine; this fork has no engine-side F-key
    dispatch, so cl_init.lua's GM:KeyInput routes it here.

    Deviations:
      - Player:Team has no C++ binding yet; a fallback local answers
        TEAM_UNASSIGNED until it lands.
      - The buttons run "changeteam"/"autoteam" exactly like GMod; this
        fork's rules do not consume those commands yet, so clicking prints
        an unknown-command line until they are wired server-side.
--------------------------------------------------------------------------]]--


local TeamFn = FindMetaTable( "Player" ).Team

--[[---------------------------------------------------------
   Name: gamemode:ShowTeam()
   Desc:
-----------------------------------------------------------]]
function GM:ShowTeam()

	if ( IsValid( self.TeamSelectFrame ) ) then return end

	-- Simple team selection box
	self.TeamSelectFrame = vgui.Create( "DFrame" )
	self.TeamSelectFrame:SetTitle( "Pick Team" )

	local AllTeams = team.GetAllTeams()
	local y = 30
	for ID, TeamInfo in pairs ( AllTeams ) do

		if ( ID != TEAM_CONNECTING && ID != TEAM_UNASSIGNED ) then

			local Team = vgui.Create( "DButton", self.TeamSelectFrame )
			function Team.DoClick() self:HideTeam() RunConsoleCommand( "changeteam", ID ) end
			Team:SetPos( 10, y )
			Team:SetSize( 130, 20 )
			Team:SetText( TeamInfo.Name )

			local MyTeam = TEAM_UNASSIGNED or 0
			if ( TeamFn != nil and IsValid( LocalPlayer() ) ) then MyTeam = TeamFn( LocalPlayer() ) end
			if ( MyTeam == ID ) then
				Team:SetEnabled( false )
			end

			y = y + 30

		end

	end

	if ( GAMEMODE.AllowAutoTeam ) then

		local Team = vgui.Create( "DButton", self.TeamSelectFrame )
		function Team.DoClick() self:HideTeam() RunConsoleCommand( "autoteam" ) end
		Team:SetPos( 10, y )
		Team:SetSize( 130, 20 )
		Team:SetText( "Auto" )
		y = y + 30

	end

	self.TeamSelectFrame:SetSize( 150, y )
	self.TeamSelectFrame:Center()
	self.TeamSelectFrame:MakePopup()
	self.TeamSelectFrame:SetKeyboardInputEnabled( false )

end

--[[---------------------------------------------------------
   Name: gamemode:HideTeam()
   Desc:
-----------------------------------------------------------]]
function GM:HideTeam()

	if ( IsValid( self.TeamSelectFrame ) ) then
		self.TeamSelectFrame:Remove()
		self.TeamSelectFrame = nil
	end

end
