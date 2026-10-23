--[[----------------------------------------------------------------------------
    hl2sb_c4_check.lua  (TEMPORARY diagnostic for the cod_c4 addon)

    Run on the SERVER console (or server part of a listen server):
        lua_dofile hl2sb_c4_check.lua

    Prints every cod-c4 entity: position / angles / model / NW "Hit" flag,
    plus the local player's "Slam" ammo (pick-up gives +1).  Run it before
    and after pressing R to see whether pick-up actually happened.
--]]----------------------------------------------------------------------------

local n = 0
for _, e in ipairs( ents.GetAll() ) do
	if ( e:GetClass() == "cod-c4" ) then
		n = n + 1
		Msg( "[c4check] ent=" .. e:EntIndex()
			.. " pos=" .. tostring( e:GetPos() )
			.. " ang=" .. tostring( e:GetAngles() )
			.. " model=" .. tostring( e:GetModel() )
			.. " hit=" .. tostring( e:GetNWBool( "Hit" ) )
			.. "\n" )
	end
end
Msg( "[c4check] total cod-c4 = " .. n .. "\n" )

for _, p in ipairs( player.GetAll() ) do
	Msg( "[c4check] player '" .. p:GetPlayerName() .. "' Slam ammo = " .. p:GetAmmoCount( "Slam" ) .. "\n" )
end
