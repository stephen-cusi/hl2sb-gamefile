--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

include( "shared.lua" )

-- HL2SB (2026-09-26): the pickup notification strip -- GMod's
-- gamemodes/base/gamemode/cl_hudpickup.lua verbatim.  This FILE is this fork's
-- real base gamemode (LUA_BASE_GAMEMODE is "deathmatch" -- luamanager.h:40),
-- so everything defined here is inherited by sandbox/campaign/... through
-- gamemode.register's table.inherit.  GMod's base cl_init.lua includes
-- cl_hudpickup.lua the same way and drives it from GM:HUDPaint below.
include( "cl_hudpickup.lua" )

function GM:ActivateClientUI()
end

function GM:AdjustEngineViewport( x, y, width, height )
end

function GM:CanShowSpeakerLabels()
end

function GM:CreateDefaultPanels()
end

function GM:DrawHeadLabels( pPlayer )
end

function GM:GetPlayerTextColor( entindex, r, g, b )
end

function GM:HideClientUI()
end

function GM:HudElementShouldDraw( pElementName )
end

function GM:HudViewportPaint()
end

-- HL2SB (2026-09-26): GMod base gamemode 的 GM:HUDPaint 原文
-- （GMod gamemodes/base/gamemode/cl_init.lua:80-86）。拾取条画在
-- cl_hudpickup.lua；hook.Run 在无钩子返回非 nil 时派发 gamemode 方法
-- （hook.lua 的回退）。HUDDrawTargetID / DrawDeathNotice 当前无注册者、
-- 无 gamemode 方法，是 no-op，照抄只为同款；deathnotice 移植件走它自己的
-- HudViewportPaint，未迁移。
function GM:HUDPaint()

	hook.Run( "HUDDrawTargetID" )
	hook.Run( "HUDDrawPickupHistory" )
	hook.Run( "DrawDeathNotice", 0.85, 0.04 )

end

function GM:KeyInput( down, keynum, pszCurrentBinding )
end

-- ===========================================================================
-- HL2SB (2026-09-26): the undo popup.  The undo module's client half fires
-- hook.Run( "OnUndo", name, customtext ) -- in GMod the POPUP itself is
-- sandbox/gamemode/cl_init.lua:46 GM:OnUndo -> GM:AddNotify ->
-- notification.AddLegacy.  Nothing in this fork defined either method, so
-- undoing worked (entities went away) but never said anything.  GMod's
-- sandbox translation logic verbatim; language.FormatPhrase is guarded
-- because this fork's language module only ships GetPhrase.
-- ===========================================================================

--- GMod sandbox/gamemode/cl_notice.lua:2
function GM:AddNotify( str, type, length )

	if ( notification ~= nil and notification.AddLegacy ~= nil ) then
		notification.AddLegacy( str, type, length )
	end

end

--- GMod sandbox/gamemode/cl_init.lua:46
function GM:OnUndo( name, strCustomString )

	local text = strCustomString
	local overwritten = false

	if ( !text ) then
		local strId = "#Undone_" .. name
		text = language.GetPhrase( strId )
		if ( strId == text ) then
			-- No custom translation available, make a generic one.
			-- ⚠️ This fork's language.FormatPhrase is GetPhrase(key):format(...) --
			-- an unknown key formats into ITSELF, and the screenshot showed the raw
			-- "hint.undoneX" on screen.  Only use the phrase when the translation
			-- actually resolved, "Undone <name>" otherwise.
			local strPhrase = language.GetPhrase( "hint.undoneX" )
			if ( strPhrase ~= nil and strPhrase ~= "hint.undoneX" ) then
				text = strPhrase:format( language.GetPhrase( name ) )
			else
				text = "Undone " .. language.GetPhrase( name )
			end
			overwritten = true
		end
	end

	if ( !overwritten ) then
		-- HACK: Try to translate existing English-only translations
		local strMatch = string.match( text, "^Undone (.*)$" )
		if ( strMatch ) then
			text = "Undone " .. language.GetPhrase( strMatch )
		end
	end

	self:AddNotify( text, NOTIFY_UNDO, 2 )

	-- GMod verbatim ("Find a better sound :X", sandbox cl_init.lua:68)
	surface.PlaySound( "buttons/button15.wav" )

end

--- GMod sandbox/gamemode/cl_init.lua:76
function GM:OnCleanup( name )

	local str = "#Cleaned_" .. name
	local translated = language.GetPhrase( str )
	if ( str == translated ) then
		local strPhrase = language.GetPhrase( "hint.cleanedX" )
		if ( strPhrase ~= nil and strPhrase ~= "hint.cleanedX" ) then
			translated = strPhrase:format( language.GetPhrase( name ) )
		else
			translated = "Cleaned up " .. language.GetPhrase( name )
		end
	end

	self:AddNotify( translated, NOTIFY_CLEANUP, 5 )

	-- GMod verbatim
	surface.PlaySound( "buttons/button15.wav" )

end

--- GMod sandbox/gamemode/cl_init.lua:87
function GM:UnfrozeObjects( num )

	local strPhrase = language.GetPhrase( "hint.unfrozeX" )
	local text
	if ( strPhrase ~= nil and strPhrase ~= "hint.unfrozeX" ) then
		text = strPhrase:format( num )
	else
		text = "Unfroze " .. tostring( num ) .. " Objects"
	end

	self:AddNotify( text, NOTIFY_GENERIC, 3 )

	-- GMod verbatim
	surface.PlaySound( "npc/roller/mine/rmine_chirp_answer1.wav" )

end

function GM:LevelInitPreEntity()
end

function GM:LevelInitPostEntity()
end

function GM:OnScreenSizeChanged( iOldWide, iOldTall )
end

function GM:PlayerUpdateFlashlight( pHL2MPPlayer, position, vecForward, vecRight, vecUp, nDistance )
end

function GM:ShouldDrawCrosshair()
end

function GM:ShouldDrawDetailObjects()
end

function GM:ShouldDrawEntity( pEnt )
end

function GM:ShouldDrawFog()
end

function GM:ShouldDrawLocalPlayer()
end

function GM:ShouldDrawParticles()
end

function GM:ShouldDrawViewModel()
end
