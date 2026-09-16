-- HL2SB - vehicle third person and the GMod vehicle Lua API.
--
-- Signatures and semantics taken from the GMod wiki:
--   Vehicle:SetThirdPersonMode( boolean enable )
--     https://wiki.facepunch.com/gmod/Vehicle:SetThirdPersonMode
--   Vehicle:GetThirdPersonMode()
--   Vehicle:SetCameraDistance( number distance )
--     https://wiki.facepunch.com/gmod/Vehicle:SetCameraDistance
--   Vehicle:GetCameraDistance()
--     https://wiki.facepunch.com/gmod/Vehicle   (Vehicle library index)
--   GM:CalcVehicleView( Vehicle veh, Player ply, table view )
--     https://wiki.facepunch.com/gmod/GM:CalcVehicleView
--     "Called from GM:CalcView when player is in driving a vehicle."
--   GM:VehicleMove( Vehicle veh, CMoveData mv )
--     https://wiki.facepunch.com/gmod/GM:VehicleMove
--     "Called when you are driving a vehicle. This hook works just like GM:Move."
--
-- The behaviour these are ported from (GMod's own Lua):
--   gamemodes/base/gamemode/init.lua     GM:VehicleMove: mv:KeyPressed( IN_DUCK ) ->
--                                        vehicle:SetThirdPersonMode( !GetThirdPersonMode() );
--                                        mouse wheel -> vehicle:SetCameraDistance( ... )
--   gamemodes/base/gamemode/cl_init.lua  GM:CalcVehicleView: radius from
--                                        Vehicle:GetRenderBounds(), TraceHull with props and
--                                        vehicles filtered out, view.origin = tr.HitPos,
--                                        view.drawviewer = true
--   lua/drive/drive_base.lua             CalcView_ThirdPerson( self, ply, view )
--
-- Engine half: ClientModeShared::OverrideView (game/client/clientmode_shared.cpp) applies the
-- camera on the final CViewSetup from the convar below, so the state kept here IS the live
-- camera state. HL2SB has no binding for these four methods and no Vehicle library of its own
-- (nothing in game/*/lua or public/lua mentions ThirdPersonMode or CameraDistance), so this
-- file provides both the API and the compatibility methods.

local CVAR_ON   = GetConVar( "hl2sb_veh_thirdperson" )
local CVAR_DIST = GetConVar( "hl2sb_veh_thirdperson_dist" )

hl2sb = hl2sb or {}
hl2sb.veh3rd = hl2sb.veh3rd or {}

local M = hl2sb.veh3rd

-- Default camera distance. GMod derives it from Vehicle:GetRenderBounds()
-- ((mn - mx):Length()); the engine half uses a distance that clears any HL2 vehicle.
M.DefaultDistance = 480

-- Per-vehicle state, the same shape GMod keeps per vehicle.
local state = setmetatable( {}, { __mode = "k" } )

local function slot( veh )
	state[ veh ] = state[ veh ] or {}
	return state[ veh ]
end

function M.SetThirdPersonMode( veh, bEnable )
	slot( veh ).thirdPerson = bEnable and true or false

	if CVAR_ON then
		CVAR_ON:SetValue( bEnable and 1 or 0 )
	end

	return true
end

function M.GetThirdPersonMode( veh )
	local s = state[ veh ]
	if s and s.thirdPerson ~= nil then
		return s.thirdPerson
	end

	return CVAR_ON and CVAR_ON:GetBool() or false
end

function M.SetCameraDistance( veh, flDistance )
	flDistance = tonumber( flDistance )
	if not flDistance then
		return false
	end

	slot( veh ).distance = flDistance

	if CVAR_DIST then
		CVAR_DIST:SetValue( flDistance )
	end

	return true
end

function M.GetCameraDistance( veh )
	local s = state[ veh ]
	if s and s.distance then
		return s.distance
	end

	return CVAR_DIST and CVAR_DIST:GetFloat() or M.DefaultDistance
end

function M.ToggleThirdPerson( veh )
	return M.SetThirdPersonMode( veh, not M.GetThirdPersonMode( veh ) )
end

-- GMod's GM:CalcVehicleView maths, kept in Lua so a gamemode can replace the camera.
-- The engine half (OverrideView) already applies this exact camera; this is what a
-- gamemode overriding the hook would run, and it is the reference if it ever moves to Lua.
function M.CalcVehicleView( veh, ply, view )
	if not M.GetThirdPersonMode( veh ) then
		return view
	end

	local flRadius = M.GetCameraDistance( veh )
	local vecForward = view.angles:Forward()

	local vecTarget = view.origin - vecForward * flRadius

	-- GMod filters props and vehicles here; util.TraceHull is only present if the
	-- implementation shipped it, so fall back to a plain ray when it is missing.
	local tr
	if util and util.TraceHull then
		tr = util.TraceHull( {
			start  = view.origin,
			endpos = vecTarget,
			mins   = Vector( -4, -4, -4 ),
			maxs   = Vector( 4, 4, 4 ),
			filter = function( ent )
				local class = ent.GetClass and ent:GetClass() or ""
				return class ~= "prop_vehicle_jeep" and class ~= "prop_vehicle_airboat"
			end,
		} )
	elseif util and util.TraceLine then
		tr = util.TraceLine( { start = view.origin, endpos = vecTarget } )
	end

	if tr and tr.HitPos then
		view.origin = tr.HitPos
	end

	view.drawviewer = true
	return view
end

-- GMod's GM:VehicleMove third person option: IN_DUCK toggles it, as in
-- gamemodes/base/gamemode/init.lua. HL2SB has no CMoveData exposed to Lua, so the same
-- behaviour is offered as a function the gamemode's own move/think code (or a key bind)
-- can call. Bind it while seated:
--   bind ctrl "hl2sb_veh_thirdperson_toggle"
function M.VehicleMove( veh, bPressedDuck )
	if bPressedDuck then
		return M.ToggleThirdPerson( veh )
	end

	return false
end

-- Install the four wiki methods on the entity metatable when it is reachable, so addons
-- that follow the wiki (vehicle:SetThirdPersonMode( true )) keep working unchanged.
-- HL2SB pushes entities as userdata whose __index falls back to this metatable, so a
-- table metatable is what we need; anything else is skipped instead of erroring.
local bInstalled = false

function M.InstallVehicleMethods()
	if bInstalled then
		return true
	end

	local function installOn( mt )
		if type( mt ) ~= "table" then
			return false
		end

		mt.SetThirdPersonMode = function( self, b ) return M.SetThirdPersonMode( self, b ) end
		mt.GetThirdPersonMode = function( self ) return M.GetThirdPersonMode( self ) end
		mt.SetCameraDistance = function( self, d ) return M.SetCameraDistance( self, d ) end
		mt.GetCameraDistance = function( self ) return M.GetCameraDistance( self ) end

		-- GMod also has Vehicle:SetThirdPersonMode reachable through the shared entity
		-- __index table; patch that too when the metatable uses one.
		if type( mt.__index ) == "table" then
			mt.__index.SetThirdPersonMode = mt.SetThirdPersonMode
			mt.__index.GetThirdPersonMode = mt.GetThirdPersonMode
			mt.__index.SetCameraDistance = mt.SetCameraDistance
			mt.__index.GetCameraDistance = mt.GetCameraDistance
		end

		return true
	end

	local ok, ent = pcall( function()
		if not Entity then return nil end
		for i = 1, 4 do
			local e = Entity( i )
			if e then return e end
		end
		return nil
	end )

	if ok and ent then
		bInstalled = installOn( getmetatable( ent ) )
	end

	return bInstalled
end

M.InstallVehicleMethods()

-- Console side (works while seated; the engine reads the convar every frame).
local cc = concommand or {}
local ccAdd = cc.Add or cc.Create	-- HL2SB ships Create; GMod compatibility adds Add

if ccAdd then
	ccAdd( "hl2sb_veh3rd_toggle", function()
		local ply = LocalPlayer and LocalPlayer() or nil
		local veh = ply and ply.GetVehicle and ply:GetVehicle() or nil
		M.ToggleThirdPerson( veh )
	end, "Toggle the vehicle third person camera." )
end
