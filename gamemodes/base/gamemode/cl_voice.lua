--[[--------------------------------------------------------------------------
    gamemodes/base/gamemode/cl_voice.lua

    GMod base gamemode cl_voice.lua, ported for HL2SB (2026-10-13).
    Client realm, live via the deathmatch cl_init.lua include (this fork's
    real base gamemode while LUA_BASE_GAMEMODE is still "deathmatch").

    Deviation: util.IsPlayerSpeaking / Player:VoiceVolume answer the speaking
    state with the volume endpoints 1/0 -- the reference reads a per-player
    loudness table fed by the engine voice mixer, and this fork's engine has
    no loudness channel.  The voice bar therefore sits full green while a
    player talks instead of following their mic level.  Every other line is
    the reference file verbatim.
--------------------------------------------------------------------------]]--

local PANEL = {}
local PlayerVoicePanels = {}

surface.CreateFont( "GModVoiceNotify", {
	font	= "Arial",
	size	= 21,
	weight	= 0,
	extended = true
} )

local VoicePanelWide = 250

function PANEL:Init()

	self.LabelName = vgui.Create( "DLabel", self )
	self.LabelName:SetFont( "GModVoiceNotify" )
	self.LabelName:Dock( FILL )
	self.LabelName:DockMargin( 8, 0, 0, 0 )
	self.LabelName:SetTextColor( color_white )

	self.Avatar = vgui.Create( "AvatarImage", self )
	self.Avatar:Dock( LEFT )
	self.Avatar:SetSize( 32, 32 )

	self.Color = color_transparent -- Team Color. This property is used by addons, so cannot comment it out or rename it.
	self.VolumeColor = Color( 0, 255, 0, 240 )

	self:SetSize( VoicePanelWide, 32 + 8 )
	self:DockPadding( 4, 4, 4, 4 )
	self:DockMargin( 2, 2, 2, 2 )
	self:Dock( BOTTOM )

end

function PANEL:Setup( ply, playerIndex )

	self.ply = ply
	self.plyIndex = playerIndex

	self:UpdatePlayerInfo()

	self:InvalidateLayout()

end

function PANEL:Paint( w, h )

	local volume = 0
	if ( IsValid( self.ply ) ) then
		volume = self.ply:VoiceVolume()
	else
		local talking, vol = util.IsPlayerSpeaking( self.plyIndex )
		if ( talking and vol ) then volume = vol end
	end

	self.VolumeColor.g = volume * 255
	draw.RoundedBox( 4, 0, 0, w, h, self.VolumeColor )

	-- I don't know how to make it look decent. Just commenting it out for now.
	--draw.RoundedBox( 0, 8, h - 2, w - 16, 1, self.Color )

end

-- Prevent constant PerformLayout calls
function PANEL:SetText( text )
	if ( self.LastName == text ) then return end
	self.LastName = text
	self.LabelName:SetText( text )
end

function PANEL:UpdatePlayerInfo( skinColor )

	if ( IsValid( self.ply ) ) then
		self:SetText( self.ply:Nick() )
		self.Avatar:SetPlayer( self.ply )
		if ( !skinColor ) then self.Color = hook.Run( "GetTeamColor", self.ply ) end
	else
		self:SetText( "Unknown Player " .. self.plyIndex )
		self.Avatar:SetPlayer( NULL )
		if ( !skinColor ) then self.Color = hook.Run( "GetTeamColor", NULL ) end
	end

end

function PANEL:Think()

	self:UpdatePlayerInfo( true )

	if ( self.fadeAnim ) then
		self.fadeAnim:Run()
	end

end

function PANEL:FadeOut( anim, delta, data )

	if ( anim.Finished ) then

		if ( IsValid( PlayerVoicePanels[ self.plyIndex ] ) ) then
			PlayerVoicePanels[ self.plyIndex ]:Remove()
			PlayerVoicePanels[ self.plyIndex ] = nil
			return
		end

	return end

	self:SetAlpha( 255 - ( 255 * delta ) )

end

derma.DefineControl( "VoiceNotify", "", PANEL, "DPanel" )



function GM:PlayerStartVoice( ply, playerIndex )

	if ( !IsValid( g_VoicePanelList ) ) then return end

	-- Backwards compat with old addons
	if ( playerIndex == nil && IsValid( ply ) ) then playerIndex = ply:EntIndex() end
	if ( playerIndex == nil ) then return end

	-- There'd be an exta one if voice_loopback is on, so remove it.
	GAMEMODE:PlayerEndVoice( ply, playerIndex )

	if ( IsValid( PlayerVoicePanels[ playerIndex ] ) ) then

		if ( PlayerVoicePanels[ playerIndex ].fadeAnim ) then
			PlayerVoicePanels[ playerIndex ].fadeAnim:Stop()
			PlayerVoicePanels[ playerIndex ].fadeAnim = nil
		end

		PlayerVoicePanels[ playerIndex ]:SetAlpha( 255 )

		return

	end

	local pnl = g_VoicePanelList:Add( "VoiceNotify" )
	pnl:Setup( ply, playerIndex )

	PlayerVoicePanels[ playerIndex ] = pnl

end

local function VoiceClean()

	for k, v in pairs( PlayerVoicePanels ) do

		if ( !IsValid( v.ply ) ) then
			local talking = util.IsPlayerSpeaking( v.plyIndex )
			if ( talking ) then continue end -- Game thinks they are still talking

			GAMEMODE:PlayerEndVoice( v.ply, v.plyIndex )
		end

	end

end
timer.Create( "VoiceClean", 10, 0, VoiceClean )

function GM:PlayerEndVoice( ply, playerIndex )

	-- Backwards compat with old addons
	if ( playerIndex == nil && IsValid( ply ) ) then playerIndex = ply:EntIndex() end
	if ( playerIndex == nil ) then return end

	if ( IsValid( PlayerVoicePanels[ playerIndex ] ) ) then

		if ( PlayerVoicePanels[ playerIndex ].fadeAnim ) then return end

		PlayerVoicePanels[ playerIndex ].fadeAnim = Derma_Anim( "FadeOut", PlayerVoicePanels[ playerIndex ], PlayerVoicePanels[ playerIndex ].FadeOut )
		PlayerVoicePanels[ playerIndex ].fadeAnim:Start( 1 )

	end

end

local function CreateVoiceVGUI()

	g_VoicePanelList = vgui.Create( "DPanel" )

	g_VoicePanelList:ParentToHUD()
	g_VoicePanelList:SetPos( ScrW() - VoicePanelWide - 50, ScrH() * 0.13 )
	g_VoicePanelList:SetSize( VoicePanelWide, ScrH() * 0.74 )
	g_VoicePanelList:SetPaintBackground( false )

end

hook.Add( "InitPostEntity", "CreateVoiceVGUI", CreateVoiceVGUI )
