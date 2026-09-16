-- HL2SB: GMod name aliases on the Player metatable.
--
-- GMod documents Player:GetVehicle() and Player:InVehicle()
--   https://wiki.facepunch.com/gmod/Player:GetVehicle
--   https://wiki.facepunch.com/gmod/Player:InVehicle
-- HL2SB's C++ binding exposes the same thing as Player:GetVehicleEntity(), so
-- ply:GetVehicle() was nil and stock Lua that uses the GMod name broke - e.g.
-- lua/includes/modules/properties.lua:140 ( "if ( veh:IsValid() && ... )" ) never ran.
--
-- This file is in lua/autorun/ (no subfolder), which both realms load, so the alias
-- applies on the client and the server. It only adds missing names: anything the engine
-- registers itself always wins.

local function AliasPlayerVehicle()
	local plyMeta = FindMetaTable and FindMetaTable( "Player" )
	if not plyMeta then
		return
	end

	local getVehicleEntity = plyMeta.GetVehicleEntity
	if not getVehicleEntity then
		return
	end

	-- GMod: Player:GetVehicle() -> Entity (the vehicle the player is in, or NULL)
	if not plyMeta.GetVehicle then
		plyMeta.GetVehicle = getVehicleEntity
	end

	-- GMod: Player:InVehicle() -> boolean
	if not plyMeta.InVehicle then
		plyMeta.InVehicle = function( self )
			return getVehicleEntity( self ) ~= nil
		end
	end
end

AliasPlayerVehicle()
