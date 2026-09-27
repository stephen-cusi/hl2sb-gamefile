--===========================================================================
-- HL2SB (2026-09-27): port of GMod's taunt camera, verbatim from
-- garrysmod/gamemodes/base/gamemode/player_class/taunt_camera.lua.
--
-- GMod's `act <name>` server command (ported in
-- game/server/hl2mp/hl2mp_player.cpp) starts the taunt gesture and stamps a
-- replicated taunt clock; Player:IsPlayingTaunt() reads it on every realm.
-- GMod's sandbox player_class feeds that flag into the three CAM callbacks
-- through PLAYER:CalcView / PLAYER:CreateMove / PLAYER:ShouldDrawLocal; this
-- fork has no player_class layer, so cl_init.lua wires the same three calls
-- into GM:CalcView / GM:CreateMove / GM:ShouldDrawLocalPlayer.
--
-- Deltas from the GMod original (both forced by missing engine surface):
--   * `angle_zero` is not a global here -> QAngle( 0, 0, 0 ) inline.
--   * ply:GetViewEntity() is not bound; the vehicle branch of the same check
--     is expressed with ply:InVehicle() (seated means the camera follows the
--     vehicle, which is the case the view-entity check exists for).
--===========================================================================--

-- GMod caches the two convars at file scope; here the gamemode can load before
-- the input cvars exist (menu realm), so resolve lazily on first use.
local m_pitch, m_yaw

--
-- This is designed so you can call it like
--
-- tauntcam = TauntCamera()
--
-- Then you have your own copy.
--
function TauntCamera()

	local CAM = {}

	local WasOn					= false

	local CustomAngles			= QAngle( 0, 0, 0 )
	local PlayerLockAngles		= nil

	local InLerp				= 0
	local OutLerp				= 1

	--
	-- Draw the local player if we're active in any way
	--
	CAM.ShouldDrawLocalPlayer = function( self, ply, on )

		return on || OutLerp < 1

	end

	--
	-- Implements the third person, rotation view (with lerping in/out)
	--
	CAM.CalcView = function( self, view, ply, on )

		if ( !ply:Alive() || ply:InVehicle() ) then on = false end

		if ( WasOn != on ) then

			if ( on ) then InLerp = 0 end
			if ( !on ) then OutLerp = 0 end

			WasOn = on

		end

		if ( !on && OutLerp >= 1 ) then

			CustomAngles = view.angles * 1
			CustomAngles.r = 0
			PlayerLockAngles = nil
			InLerp = 0
			return

		end

		if ( PlayerLockAngles == nil ) then return end

		--
		-- Simple 3rd person camera
		--
		local TargetOrigin = view.origin - CustomAngles:Forward() * 100
		local tr = util.TraceHull( { start = view.origin, endpos = TargetOrigin, mask = MASK_SHOT || MASK_SHOT_HULL, filter = player.GetAll(), mins = Vector( -8, -8, -8 ), maxs = Vector( 8, 8, 8 ) } )
		TargetOrigin = tr.HitPos + tr.HitNormal

		if ( InLerp < 1 ) then

			InLerp = InLerp + FrameTime() * 5.0
			view.origin = LerpVector( InLerp, view.origin, TargetOrigin )
			view.angles = LerpAngle( InLerp, PlayerLockAngles, CustomAngles )
			return true

		end

		if ( OutLerp < 1 ) then

			OutLerp = OutLerp + FrameTime() * 3.0
			view.origin = LerpVector( 1-OutLerp, view.origin, TargetOrigin )
			view.angles = LerpAngle( 1-OutLerp, PlayerLockAngles, CustomAngles )
			return true

		end

		view.angles = CustomAngles * 1
		view.origin = TargetOrigin
		return true

	end

	--
	-- Freezes the player in position and uses the input from the user command to
	-- rotate the custom third person camera
	--
	CAM.CreateMove = function( self, cmd, ply, on )

		if ( !ply:Alive() ) then on = false end
		if ( !on ) then return end

		if ( PlayerLockAngles == nil ) then
			PlayerLockAngles = CustomAngles * 1
		end

		--
		-- Rotate our view
		--
		m_pitch = m_pitch || GetConVar( "m_pitch" )
		m_yaw = m_yaw || GetConVar( "m_yaw" )

		CustomAngles.pitch	= CustomAngles.pitch	+ cmd:GetMouseY() * m_pitch:GetFloat()
		CustomAngles.yaw	= CustomAngles.yaw		- cmd:GetMouseX() * m_yaw:GetFloat()

		--
		-- Lock the player's controls and angles
		--
		cmd:SetViewAngles( PlayerLockAngles )
		cmd:ClearButtons()
		cmd:ClearMovement()

		return true

	end

	return CAM

end
