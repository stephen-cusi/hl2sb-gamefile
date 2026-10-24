--
-- Vehicle Extensions
--
local vehicle = FindMetaTable( "Vehicle" )

--
-- We steal some DT slots by default for vehicles
-- to control the third person view. You should use
-- these functions if you want to play with them because
-- they might eventually be moved into the engine - so manually
-- editing the DT values will stop working.
--
function vehicle:SetVehicleClass( s )

	self:SetDTString( 3, s )

end

function vehicle:GetVehicleClass()

	return self:GetDTString( 3 )

end

function vehicle:SetThirdPersonMode( b )

	self:SetDTBool( 3, b )

end

function vehicle:GetThirdPersonMode()

	return self:GetDTBool( 3 )

end

function vehicle:SetCameraDistance( dist )

	self:SetDTFloat( 3, dist )

end

function vehicle:GetCameraDistance()

	return self:GetDTFloat( 3 )

end
