--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

if ( not bit ) then
  require( "bit" )
end

include( "shared.lua" )
include( "cl_worldtips.lua" )
include( "cl_hints.lua" )
include( "cl_spawnmenu.lua" )
include( "cl_search_models.lua" )
include( "gui/iconeditor.lua" )
include( "editor_player.lua" )

local BaseClass = gamemode.Get( "base" )

function GM:LimitHit( name )

	local str = "#SBoxLimit_" .. name
	local translated = language.GetPhrase( str )
	if ( str == translated ) then
		-- No translation available, apply our own
		local strPhrase = language.GetPhrase( "hint.hitXlimit" )
		if ( strPhrase and strPhrase != "hint.hitXlimit" and strPhrase:find( "%%" ) ) then
			translated = language.FormatPhrase( "hint.hitXlimit", language.GetPhrase( name ) )
		else
			translated = "You have hit the " .. language.GetPhrase( name ) .. " limit!"
		end
	end

	self:AddNotify( translated, NOTIFY_ERROR, 6 )
	surface.PlaySound( "buttons/button10.wav" )

end

function GM:HUDPaint()

	self:PaintWorldTips()

	-- Draw all of the default stuff
	local base = BaseClass or ( gamemode and gamemode.Get and gamemode.Get( "base" ) )
	if ( base and base.HUDPaint ) then
		base.HUDPaint( self )
	end

end

function GM:NetworkEntityCreated( ent )

	if ( ent:GetSpawnEffect() && ent:GetCreationTime() > ( CurTime() - 1.0 ) ) then

		local ed = EffectData()
		ed:SetOrigin( ent:GetPos() )
		ed:SetEntity( ent )
		util.Effect( "propspawn", ed, true, true )

	end

end
