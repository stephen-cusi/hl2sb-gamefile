--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/cl_scoreboard.lua

    GMod base gamemode cl_scoreboard.lua, ported for HL2SB (2026-10-10).
    Client realm, included from cl_init.lua.

    Deviations (missing-binding driven):
      - Player:ShowProfile opens a Steam profile in GMod; with no Steam layer
        the avatar button is a silent click target here.
      - The mute button's volume wheel (Player:Get/SetVoiceVolumeScale) has no
        binding in this fork, so the wheel and its PaintOver indicator are
        omitted; the click toggles the mute.
      - DLabel:SetExpensiveShadow is not ported; the call is dropped.
      - GMod's client registers +showscoreboard/-showscoreboard in the
        engine; here they are concommand.Add'ed at the bottom (real engine
        button commands, same mechanism as +menu), and TAB is bound to them
        in cfg/config.cfg.
--------------------------------------------------------------------------]]--


surface.CreateFont( "ScoreboardDefault", {
	font	= "Helvetica",
	size	= 22,
	weight	= 800
} )

surface.CreateFont( "ScoreboardDefaultTitle", {
	font	= "Helvetica",
	size	= 32,
	weight	= 800
} )

-- GMod ships its team number constants as globals; this fork has no team
-- module, so the constants the scoreboard sorts with are created here with
-- GMod's values when absent.
TEAM_UNASSIGNED = TEAM_UNASSIGNED or 0
TEAM_CONNECTING = TEAM_CONNECTING or 1
TEAM_SPECTATOR = TEAM_SPECTATOR or 2

--
-- This defines a new panel type for the player row. The player row is given a player
-- and then from that point on it pretty much looks after itself. It updates player info
-- in the think function, and removes itself when the player leaves the server.
--
local PLAYER_LINE = {
	Init = function( self )

		self.AvatarButton = self:Add( "DButton" )
		self.AvatarButton:Dock( LEFT )
		self.AvatarButton:SetSize( 32, 32 )
		-- GMod opens the player's Steam profile here (Player:ShowProfile);
		-- this fork has no Steam layer, so the click stays silent.
		self.AvatarButton.DoClick = function() end

		self.Avatar = vgui.Create( "AvatarImage", self.AvatarButton )
		self.Avatar:SetSize( 32, 32 )
		self.Avatar:SetMouseInputEnabled( false )

		self.Name = self:Add( "DLabel" )
		self.Name:Dock( FILL )
		self.Name:SetFont( "ScoreboardDefault" )
		self.Name:SetTextColor( Color( 93, 93, 93 ) )
		self.Name:DockMargin( 8, 0, 0, 0 )

		self.Mute = self:Add( "DImageButton" )
		self.Mute:SetSize( 32, 32 )
		self.Mute:Dock( RIGHT )
		-- GMod wheels the player's voice volume on this button
		-- (Player:Get/SetVoiceVolumeScale); no such binding in this fork, so
		-- only the click-to-mute below is wired.
		self.Mute:NoClipping( true )

		self.Ping = self:Add( "DLabel" )
		self.Ping:Dock( RIGHT )
		self.Ping:SetWidth( 50 )
		self.Ping:SetFont( "ScoreboardDefault" )
		self.Ping:SetTextColor( Color( 93, 93, 93 ) )
		self.Ping:SetContentAlignment( 5 )

		self.Deaths = self:Add( "DLabel" )
		self.Deaths:Dock( RIGHT )
		self.Deaths:SetWidth( 50 )
		self.Deaths:SetFont( "ScoreboardDefault" )
		self.Deaths:SetTextColor( Color( 93, 93, 93 ) )
		self.Deaths:SetContentAlignment( 5 )

		self.Kills = self:Add( "DLabel" )
		self.Kills:Dock( RIGHT )
		self.Kills:SetWidth( 50 )
		self.Kills:SetFont( "ScoreboardDefault" )
		self.Kills:SetTextColor( Color( 93, 93, 93 ) )
		self.Kills:SetContentAlignment( 5 )

		self:Dock( TOP )
		self:DockPadding( 3, 3, 3, 3 )
		self:SetHeight( 32 + 3 * 2 )
		self:DockMargin( 2, 0, 2, 2 )

	end,

	Setup = function( self, pl )

		self.Player = pl

		self.Avatar:SetPlayer( pl )

		self:Think( self )

	end,

	Think = function( self )

		if ( !IsValid( self.Player ) ) then
			self:SetZPos( 9999 ) -- Causes a rebuild
			self:Remove()
			return
		end

		if ( self.PName == nil || self.PName != self.Player:Nick() ) then
			self.PName = self.Player:Nick()
			self.Name:SetText( self.PName )
		end

		if ( self.NumKills == nil || self.NumKills != self.Player:Frags() ) then
			self.NumKills = self.Player:Frags()
			self.Kills:SetText( self.NumKills )
		end

		if ( self.NumDeaths == nil || self.NumDeaths != self.Player:Deaths() ) then
			self.NumDeaths = self.Player:Deaths()
			self.Deaths:SetText( self.NumDeaths )
		end

		if ( self.NumPing == nil || self.NumPing != self.Player:Ping() ) then
			self.NumPing = self.Player:Ping()
			self.Ping:SetText( self.NumPing )
		end

		--
		-- Change the icon of the mute button based on state
		--
		if ( self.Muted == nil || self.Muted != self.Player:IsMuted() ) then

			self.Muted = self.Player:IsMuted()
			if ( self.Muted ) then
				self.Mute:SetImage( "icon32/muted.png" )
			else
				self.Mute:SetImage( "icon32/unmuted.png" )
			end

			self.Mute.DoClick = function( s ) self.Player:SetMuted( !self.Muted ) end

		end

		--
		-- Connecting players go at the very bottom
		--
		if ( self.Player:Team() == TEAM_CONNECTING ) then
			self:SetZPos( 2000 + self.Player:EntIndex() )
			return
		end

		--
		-- This is what sorts the list. The panels are docked in the z order,
		-- so if we set the z order according to kills they'll be ordered that way!
		-- Careful though, it's a signed short internally, so needs to range between -32,768k and +32,767
		--
		self:SetZPos( ( self.NumKills * -50 ) + self.NumDeaths + self.Player:EntIndex() )

	end,

	Paint = function( self, w, h )

		if ( !IsValid( self.Player ) ) then return end

		draw.RoundedBox( 4, 0, 0, w, h, self:GetLineColor() )

	end,

	GetLineColor = function( self )

		-- We draw our background a different colour based on the status of the player

		if ( !IsValid( self.Player ) ) then
			return Color( 230, 230, 230, 255 )
		end

		if ( self.Player:Team() == TEAM_CONNECTING ) then
			return Color( 200, 200, 200, 200 )
		end

		if ( !self.Player:Alive() ) then
			return Color( 230, 200, 200, 255 )
		end

		if ( self.Player:IsAdmin() ) then
			return Color( 230, 255, 230, 255 )
		end

		return Color( 230, 230, 230, 255 )

	end
}

--
-- Convert it from a normal table into a Panel Table based on DPanel
--
PLAYER_LINE = vgui.RegisterTable( PLAYER_LINE, "DPanel" )

--
-- Here we define a new panel table for the scoreboard. It basically consists
-- of a header and a scrollpanel - into which the player lines are placed.
--
local SCORE_BOARD = {
	Init = function( self )

		self.Header = self:Add( "Panel" )
		self.Header:Dock( TOP )
		self.Header:SetHeight( 100 )

		self.Name = self.Header:Add( "DLabel" )
		self.Name:SetFont( "ScoreboardDefaultTitle" )
		self.Name:SetTextColor( color_white )
		self.Name:Dock( TOP )
		self.Name:SetHeight( 40 )
		self.Name:SetContentAlignment( 5 )

		self.Scores = self:Add( "DScrollPanel" )
		self.Scores:Dock( FILL )

		-- The bar only appears when the roster overflows (DVScrollBar:SetUp
		-- enables on demand); hide its arrow buttons and narrow the strip so
		-- the scoreboard stays quiet while it is up.
		self.Scores.VBar:SetHideButtons( true )
		self.Scores.VBar.BarWidth = function( s ) return 8 end

	end,

	PerformLayout = function( self )

		self:SetSize( 700, ScrH() - 200 )
		self:SetPos( ScrW() / 2 - 350, 100 )

	end,

	Paint = function( self, w, h )

		--draw.RoundedBox( 4, 0, 0, w, h, Color( 0, 0, 0, 200 ) )

	end,

	Think = function( self, w, h )

		self.Name:SetText( GetHostName() )

		--
		-- Loop through each player, and if one doesn't have a score entry - create it.
		--

		for id, pl in player.Iterator() do

			if ( IsValid( pl.ScoreEntry ) ) then continue end

			pl.ScoreEntry = vgui.CreateFromTable( PLAYER_LINE, pl.ScoreEntry )
			pl.ScoreEntry:Setup( pl )

			self.Scores:AddItem( pl.ScoreEntry )

		end

	end
}

SCORE_BOARD = vgui.RegisterTable( SCORE_BOARD, "EditablePanel" )

--[[---------------------------------------------------------
	Name: gamemode:ScoreboardShow( )
	Desc: Sets the scoreboard to visible
-----------------------------------------------------------]]
function GM:ScoreboardShow()

	if ( !IsValid( g_Scoreboard ) ) then
		g_Scoreboard = vgui.CreateFromTable( SCORE_BOARD )
	end

	if ( IsValid( g_Scoreboard ) ) then
		g_Scoreboard:Show()
		g_Scoreboard:MakePopup()
		g_Scoreboard:SetKeyboardInputEnabled( false )
	end

end

--[[---------------------------------------------------------
	Name: gamemode:ScoreboardHide( )
	Desc: Sets the scoreboard to visible
-----------------------------------------------------------]]
function GM:ScoreboardHide()

	if ( IsValid( g_Scoreboard ) ) then
		g_Scoreboard:Hide()
	end

end

--[[---------------------------------------------------------
	Name: gamemode:HUDDrawScoreBoard( )
	Desc: If you prefer to draw your scoreboard the stupid way (without vgui)
-----------------------------------------------------------]]
function GM:HUDDrawScoreBoard()
end

-- HL2SB: GMod's client creates these two button commands in the engine; here
-- the concommand library creates the real engine ConCommands (the +menu
-- mechanism) and TAB is bound to the pair in cfg/config.cfg.
concommand.Add( "+showscoreboard", function()
	if ( GAMEMODE != nil and GAMEMODE.ScoreboardShow != nil ) then GAMEMODE:ScoreboardShow() end
end )

concommand.Add( "-showscoreboard", function()
	if ( GAMEMODE != nil and GAMEMODE.ScoreboardHide != nil ) then GAMEMODE:ScoreboardHide() end
end )
