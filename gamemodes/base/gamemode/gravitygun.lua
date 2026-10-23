-- Gravity-gun callbacks and scripted-entity forwarding.

function GM:GravGunPickupAllowed( ply, ent )
	-- 玩家不能被重力枪抓（GMod 同款默认）
	if ( ent ~= nil and ent.IsPlayer ~= nil and ent:IsPlayer() ) then return false end

	if ( ent ~= nil and isfunction( ent.GravGunPickupAllowed ) ) then
		return ent:GravGunPickupAllowed( ply )
	end

	return true
end

function GM:GravGunPunt( ply, ent )
	if ( ent ~= nil and isfunction( ent.GravGunPunt ) ) then
		return ent:GravGunPunt( ply )
	end

	return true
end

function GM:GravGunOnPickedUp( ply, ent )
	if ( ent ~= nil and isfunction( ent.GravGunOnPickedUp ) ) then
		ent:GravGunOnPickedUp( ply )
	end
end

function GM:GravGunOnDropped( ply, ent )
	if ( ent ~= nil and isfunction( ent.GravGunOnDropped ) ) then
		ent:GravGunOnDropped( ply )
	end
end
