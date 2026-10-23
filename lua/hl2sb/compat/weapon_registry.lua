-- Bridge the native weapon registry to the original weapons module.

if ( weapon ~= nil and weapon.register ~= nil and weapons ~= nil and weapons.Register ~= nil ) then
	local weaponRegister = weapon.register
	weapon.register = function( t, classname, bReload )
		weaponRegister( t, classname, bReload )

		local ok, err = pcall( weapons.Register, t, classname )
		if ( not ok ) then
			Msg( "[HL2SB] weapons.Register sync failed for " .. tostring( classname ) .. ": " .. tostring( err ) .. "\n" )
		end
	end
end
