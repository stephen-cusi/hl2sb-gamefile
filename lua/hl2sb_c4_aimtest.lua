--[[----------------------------------------------------------------------------
    hl2sb_c4_aimtest.lua  (TEMPORARY A/B render test for the cod_c4 addon)

    Run on the server console:
        lua_dofile hl2sb_c4_aimtest.lua

    Moves every cod-c4 entity right in front of your eyes (2m, eye height,
    frozen) and spawns a plain prop_physics_override with the SAME model
    next to it.  Look straight ahead:
      * prop visible + cod-c4 invisible -> scripted-entity client draw bug
      * both invisible                  -> model/pos problem
      * both visible                    -> it was position after all
--]]----------------------------------------------------------------------------

local ply = player.GetAll()[1]
if ( not IsValid( ply ) ) then Msg( "[c4aim] no player\n" ) return end

local base = ply:GetPos() + ply:GetForward() * 80 + Vector( 0, 0, 20 )
local n = 0

for _, e in ipairs( ents.GetAll() ) do
	if ( e:GetClass() == "cod-c4" ) then
		n = n + 1
		e:SetPos( base + Vector( 0, n * 16 - 8, 0 ) )
		e:SetAngles( Angle( 0, 0, 0 ) )
		local phys = e:GetPhysicsObject()
		if ( IsValid( phys ) ) then phys:EnableMotion( false ) end
		Msg( "[c4aim] moved cod-c4 #" .. e:EntIndex() .. " to " .. tostring( e:GetPos() ) .. "\n" )
	end
end

local prop = ents.Create( "prop_physics_override" )
if ( IsValid( prop ) ) then
	prop:SetModel( "models/hoff/weapons/c4/w_c4.mdl" )
	prop:SetPos( base + Vector( 0, n * 16 + 8, 0 ) )
	prop:Spawn()
	local phys = prop:GetPhysicsObject()
	if ( IsValid( phys ) ) then phys:EnableMotion( false ) end
	Msg( "[c4aim] spawned reference prop at " .. tostring( prop:GetPos() ) .. "\n" )
end

Msg( "[c4aim] moved " .. n .. " cod-c4 + 1 reference prop in front of you - LOOK NOW\n" )
