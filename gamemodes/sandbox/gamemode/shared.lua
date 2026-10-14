--========== Copyleft © 2010, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose:
--
--===========================================================================--

include( "ammo.lua" )

GM.Name			= "Sandbox"
GM.Homepage		= "http://www.andrewmcwatters.com/hl2sb/"
GM.Developer	= "Team Sandbox"
GM.Manual		= nil

function GM:Initialize()
if ( not _CLIENT ) then
  -- Sandbox default: real fall damage OFF (the create-server "Enable
  -- fall damage" checkbox can turn it back on per session).
  engine.ServerCommand( "mp_falldamage 0\n" )
  engine.ServerCommand( "mp_flashlight 1\n" )
else
  -- Andrew; not the right place to put this, but oh well.
  self:CreateDefaultPanels()
end
end

function GM:FlWeaponRespawnTime( pWeapon )
  return -1
end

function GM:FlWeaponTryRespawn( pWeapon )
  return 0
end

local function PlayerPlayStepSound_Impl( pPlayer, vecOrigin, psurface, fvol, force )
	if ( gpGlobals.maxClients() > 1 and cvar.FindVar( "sv_footsteps" ):GetFloat() == 0 ) then
		return false;
	end

if ( _CLIENT ) then
	-- during prediction play footstep sounds only once
	if ( prediction.InPrediction() and not prediction.IsFirstTimePredicted() ) then
		return false;
	end
end

	if ( not psurface ) then
		return false;
	end

	local nSide = pPlayer:GetPlayerLocalData().m_nStepside;
	local stepSoundName = nSide ~= 0 and psurface.sounds.stepleft or psurface.sounds.stepright;
	if ( not stepSoundName ) then
		return false;
	end

	pPlayer:SetPlayerLocalData( "m_nStepside", nSide == 0 and 1 or 0 );

	local params;

	assert( nSide == 0 or nSide == 1 );

	if ( pPlayer:GetStepSoundCache()[ nSide ].m_usSoundNameIndex == stepSoundName ) then
		params = pPlayer:GetStepSoundCache()[ nSide ].m_SoundParameters;
	else
		local physprops = MoveHelper():GetSurfaceProps();
		local pSoundName = physprops:GetString( stepSoundName );
		local b
		b, params = _R.CBaseEntity.GetParametersForSound( pSoundName )
		if ( not b ) then
			return false;
		end

		-- Only cache if there's one option.  Otherwise we'd never here any other sounds
		if ( params.count == 1 ) then
			pPlayer:SetStepSoundCache( nSide, "m_usSoundNameIndex", stepSoundName );
			pPlayer:SetStepSoundCache( nSide, "m_SoundParameters", params );
		end
	end

	local filter = CRecipientFilter();
	filter:AddRecipientsByPAS( vecOrigin );

if not _CLIENT then
	-- in MP, server removes all players in the vecOrigin's PVS, these players generate the footsteps client side
	if ( gpGlobals.maxClients() > 1 ) then
		filter:RemoveRecipientsByPVS( vecOrigin );
	end
end

	local ep = {};
	ep.m_nChannel = 4; -- CHAN_BODY
	ep.m_pSoundName = params.soundname;
	ep.m_flVolume = fvol;
	ep.m_SoundLevel = params.soundlevel;
	ep.m_nFlags = 0;
	ep.m_nPitch = params.pitch;
	ep.m_pOrigin = vecOrigin;

	_R.CBaseEntity.EmitSound( filter, pPlayer:entindex(), ep );
	return false
end

-- HL2SB: the hook above used to fail once per footstep with a bare
-- "attempt to index a number value" (no file/line), which spammed the log
-- hundreds of times per session.  Run it through xpcall + debug.traceback so
-- the failure reports its exact line instead of an anonymous message.
function GM:PlayerPlayStepSound( pPlayer, vecOrigin, psurface, fvol, force )
	local ok, err = xpcall( function()
		return PlayerPlayStepSound_Impl( pPlayer, vecOrigin, psurface, fvol, force )
	end, debug.traceback )

	if ( not ok ) then
		dbg.Warning( "[step-sound] " .. tostring( err ) .. "\n" )
		return false
	end

	return err
end

function GM:WeaponShouldRespawn( pItem )
  pItem:AddSpawnFlags( 2^30 )
  -- return 2
end

-- HL2SB (2026-09-29): verbatim from GMod gamemodes/sandbox/gamemode/shared.lua:185.
-- Consumed by the engine's PlayerNoClip hook dispatch (game/server/client.cpp
-- CC_Player_NoClip); sbox_noclip is created in this gamemode's init.lua.
function GM:PlayerNoClip( pl, on )

	-- Don't allow if player is in vehicle
	if ( !IsValid( pl ) || pl:InVehicle() || !pl:Alive() ) then return false end

	-- Always allow to turn off noclip, and in single player
	if ( !on || game.SinglePlayer() ) then return true end

	return GetConVarNumber( "sbox_noclip" ) > 0

end

--[[---------------------------------------------------------
   Name: gamemode:CanProperty( pl, property, ent )
   Desc: Can the player do this property, to this entity?
-----------------------------------------------------------]]
function GM:CanProperty( pl, property, ent )

	--
	-- Always a chance some bastard got through
	--
	if ( !IsValid( ent ) ) then return false end

	--
	-- If we have a toolsallowed table, check to make sure the toolmode is in it
	-- This is used by things like map entities
	--
	if ( ent.m_tblToolsAllowed ) then

		local vFound = false
		for k, v in pairs( ent.m_tblToolsAllowed ) do
			if ( property == v ) then vFound = true end
		end

		if ( !vFound ) then return false end

	end

	--
	-- Who can who bone manipulate?
	--
	if ( property == "bonemanipulate" ) then

		if ( game.SinglePlayer() ) then return true end

		if ( ent:IsNPC() ) then return GetConVarNumber( "sbox_bonemanip_npc" ) != 0 end
		if ( ent:IsPlayer() ) then return GetConVarNumber( "sbox_bonemanip_player" ) != 0 end

		return GetConVarNumber( "sbox_bonemanip_misc" ) != 0

	end

	--
	-- Weapons can only be property'd if nobody is holding them
	--
	if ( ent:IsWeapon() and IsValid( ent:GetOwner() ) ) then
		return false
	end

	-- Give the entity a chance to decide
	if ( ent.CanProperty ) then
		return ent:CanProperty( pl, property )
	end

	return true

end

--[[---------------------------------------------------------
   Name: gamemode:CanDrive( pl, ent )
   Desc: Return true to let the entity drive.
-----------------------------------------------------------]]
function GM:CanDrive( pl, ent )

	local classname = ent:GetClass()

	--
	-- Only let physics based NPCs be driven for now
	--
	if ( ent:IsNPC() ) then

		if ( classname == "npc_cscanner" ) then return true end
		if ( classname == "npc_clawscanner" ) then return true end
		if ( classname == "npc_manhack" ) then return true end
		if ( classname == "npc_turret_floor" ) then return true end
		if ( classname == "npc_rollermine" ) then return true end

		return false

	end

	if ( classname == "prop_dynamic" ) then return false end
	if ( classname == "prop_door" ) then return false end

	return true

end

--[[---------------------------------------------------------
	To update the player's animation during a drive
-----------------------------------------------------------]]
function GM:PlayerDriveAnimate( ply )

	local driving = ply:GetDrivingEntity()
	if ( !IsValid( driving ) ) then return end

	ply:SetPlaybackRate( 1 )
	ply:ResetSequence( ply:SelectWeightedSequence( ACT_HL2MP_IDLE_MAGIC ) )

	--
	-- Work out the direction from the player to the entity, and set parameters
	--
	local DirToEnt = driving:GetPos() - ( ply:GetPos() + Vector( 0, 0, 50 ) )
	local AimAng = DirToEnt:Angle()

	if ( AimAng.p > 180 ) then
		AimAng.p = AimAng.p - 360
	end

	ply:SetPoseParameter( "aim_yaw",		0 )
	ply:SetPoseParameter( "aim_pitch",		AimAng.p )
	ply:SetPoseParameter( "move_x",			0 )
	ply:SetPoseParameter( "move_y",			0 )
	ply:SetPoseParameter( "move_yaw",		0 )
	ply:SetPoseParameter( "move_scale",		0 )

	AimAng.p = 0
	AimAng.r = 0

	ply:SetRenderAngles( AimAng )
	ply:SetEyeTarget( driving:GetPos() )

end
