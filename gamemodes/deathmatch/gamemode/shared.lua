--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--


include( "ammo.lua" )

-- HL2SB (2026-09-27): GMod's player animation glue (base gamemode
-- animations.lua port).  The C++ player animation path dispatches
-- GM:CalcMainActivity / GM:UpdateAnimation / GM:TranslateActivity /
-- GM:DoAnimationEvent from here, both realms.
include( "animations.lua" )

-- HL2SB (2026-09-27): GMod's base gamemode taunt hooks (player.lua:774-789).
-- The server `act` command (game/server/hl2mp/hl2mp_player.cpp) dispatches
-- PlayerShouldTaunt before starting a taunt and PlayerStartTaunt after; the
-- base gamemode owns the default answers, gamemodes override to refuse.
function GM:PlayerShouldTaunt( ply, actid )

	-- The default behaviour is to always let them act
	-- Some gamemodes will obviously want to stop this for certain players by returning false
	return true

end

function GM:PlayerStartTaunt( ply, actid, length )
end

--[[---------------------------------------------------------
	Name: gamemode:PlayerSetHandsModel()
	Desc: Sets the player's view model hands model.
	 HL2SB (2026-09-27): port of GMod base player.lua:275.  Called by the
	 gmod_hands entity's DoSetup on every spawn; the model comes from the
	 player class (PLAYER:GetHandsModel) or the path->hands registry.
-----------------------------------------------------------]]
function GM:PlayerSetHandsModel( pl, ent )

	local info = player_manager.RunClass( pl, "GetHandsModel" )
	if ( !info ) then
		local playermodel = player_manager.TranslateToPlayerModelName( pl:GetModel() )
		info = player_manager.TranslatePlayerHands( playermodel )
	end

	if ( info ) then
		ent:SetModel( info.model )
		ent:SetSkin( info.matchBodySkin and pl:GetSkin() or info.skin )
		ent:SetBodyGroups( info.body )
	end

end

--[[---------------------------------------------------------
	Name: gamemode:OnViewModelChanged()
	Desc: Called when the player's viewmodel model changes.  GMod base
	 shared.lua:251 verbatim - forwards to the player class's
	 PLAYER:ViewModelChanged hook point.
-----------------------------------------------------------]]
function GM:OnViewModelChanged( vm, old, new )

	local ply = vm:GetOwner()
	if ( IsValid( ply ) ) then
		player_manager.RunClass( ply, "ViewModelChanged", vm, old, new )
	end

end

GM.Name       = "Deathmatch"
GM.Homepage   = "http://www.steampowered.com/"
GM.Developer  = "Valve"
GM.Manual     = nil

function GM:Initialize()
  self.m_bTeamPlayEnabled = cvar.FindVar( "mp_teamplay" ):GetBool()
end

function GM:Shutdown()
  -- Andrew; this is a Lua-side implemented hook. We have a proper C level hook
  -- call for Initialize which is called directly after the gamemode is loaded.
  -- While one might wonder why Shutdown isn't implemented at the C level as
  -- well, it's simply because it would be called within LevelShutdown, causing
  -- it's implementation to be redundant.
end

function GM:CalcPlayerView( pPlayer, eyeOrigin, eyeAngles, fov )
end

function GM:CheckGameOver()
end

function GM:ClientSettingsChanged( pPlayer )
end

function GM:CreateStandardEntities()
end

function GM:DeathNotice( pVictim, info )
end

function GM:FlWeaponRespawnTime( pWeapon )
end

function GM:FlWeaponTryRespawn( pWeapon )
end

function GM:GetGameDescription()
  if ( self:IsTeamplay() ) then
    return "Team " .. self.Name
  end
  return self.Name
end

function GM:GetMapRemainingTime()
  -- if timelimit is disabled, return 0
  if ( cvar.FindVar( "mp_timelimit" ):GetInt() <= 0 ) then
    return 0;
  end
end

function GM:GoToIntermission()
end

function GM:IsIntermission()
end

function GM:IsTeamplay()
  return self.m_bTeamPlayEnabled
end

function GM:LevelShutdown()
  self:Shutdown()
end

function GM:OnEntityCreated( pEntity )
end

function GM:PlayerKilled( pVictim, info )
end

function GM:PlayerPlayFootStep( pPlayer, vecOrigin, fvol, force )
end

function GM:PlayerRelationship( pPlayer, pTarget )
end

function GM:PlayerTraceAttack( info, vecDir, ptr )
end

function GM:PlayerUse( pPlayer )
end

function GM:Precache()
  _R.CBaseEntity.PrecacheScriptSound( "AlyxEmp.Charge" );
end

function GM:ShouldCollide( collisionGroup0, collisionGroup1 )
end

function GM:Think()
end

function GM:VecWeaponRespawnSpot( pWeapon )
end

-- ===========================================================================
-- HL2SB (2026-09-29): the noclip gate and the drive pump, verbatim from GMod.
--
--   GM:PlayerNoClip            = gamemodes/base/gamemode/player_shd.lua:93
--   GM:Move / SetupMove / FinishMove / StartEntityDriving / EndEntityDriving /
--   PlayerDriveAnimate         = gamemodes/base/gamemode/shared.lua:169-224
--
-- The hook name "PlayerNoClip" is slot 0x64 of GMod's lua_shared hook table
-- (the fork's lua/src/hl2sb_hooks.c carries the same slot) and IS dispatched
-- now: game/server/client.cpp CC_Player_NoClip asks the gamemode before
-- toggling, and a false return vetoes the toggle.
--
-- Move / SetupMove / FinishMove are NOT dispatched yet - that needs the
-- engine's playermove hooks plus a CMoveData Lua binding (GMod binds
-- mv:SetOrigin/GetVelocity/KeyDown/... ).  They are defined verbatim so the
-- moment the dispatch lands they behave exactly like GMod; until then they
-- are dormant (a defined-but-never-called gamemode method is the GMod
-- status-quo for any fork without drive-capable movement).
-- ===========================================================================

--[[---------------------------------------------------------
	Name: gamemode:PlayerNoClip( player, bool )
	Desc: Player pressed the noclip key, return true if
		 the player is allowed to noclip, false to block
-----------------------------------------------------------]]
function GM:PlayerNoClip( pl, on )
	if ( !on ) then return true end
	-- Allow noclip if we're in single player and living
	return game.SinglePlayer() && IsValid( pl ) && pl:Alive()

end

--[[---------------------------------------------------------
   Name: gamemode:Move
   This basically overrides the NOCLIP, PLAYERMOVE movement stuff.
   It's what actually performs the move.
   Return true to not perform any default movement actions. (completely override)
-----------------------------------------------------------]]
function GM:Move( ply, mv )

	if ( drive.Move( ply, mv ) ) then return true end
	if ( player_manager.RunClass( ply, "Move", mv ) ) then return true end

end

--[[---------------------------------------------------------
-- Purpose: This is called pre player movement and copies all the data necessary
--          from the player for movement. Copy from the usercmd to move.
-----------------------------------------------------------]]
function GM:SetupMove( ply, mv, cmd )

	if ( drive.StartMove( ply, mv, cmd ) ) then return true end
	if ( player_manager.RunClass( ply, "StartMove", mv, cmd ) ) then return true end

end

--[[---------------------------------------------------------
   Name: gamemode:FinishMove( player, movedata )
-----------------------------------------------------------]]
function GM:FinishMove( ply, mv )

	if ( drive.FinishMove( ply, mv ) ) then return true end
	if ( player_manager.RunClass( ply, "FinishMove", mv ) ) then return true end

end

--[[---------------------------------------------------------
	A player has started driving an entity
-----------------------------------------------------------]]
function GM:StartEntityDriving( ent, ply )

	drive.Start( ply, ent )

end

--[[---------------------------------------------------------
	A player has stopped driving an entity
-----------------------------------------------------------]]
function GM:EndEntityDriving( ent, ply )

	drive.End( ply, ent )

end

--[[---------------------------------------------------------
	To update the player's animation during a drive
-----------------------------------------------------------]]
function GM:PlayerDriveAnimate( ply )

end
