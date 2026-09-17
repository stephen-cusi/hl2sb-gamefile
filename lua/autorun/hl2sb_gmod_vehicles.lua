--[[----------------------------------------------------------------------------
    hl2sb_gmod_vehicles.lua

    Garry's Mod's own vehicle entries for the Vehicles page, the same way
    hl2sb_gmod_seats.lua carries the chairs: `list.Set( "Vehicles", <spawn name>,
    { Class, Model, KeyValues, Category } )`, which is GMod's contract in
    garrysmod/lua/autorun/base_vehicles.lua.

    Why this exists
    ---------------
    The class registry alone is not a spawn list for vehicles.  It lists the engine's
    classes, and the vehicle bases (prop_vehicle, prop_vehicle_driveable,
    prop_vehicle_crane) have NO MODEL: the page offered them, `gm_spawnvehicle
    prop_vehicle` created a model-less vehicle, and the server died in
    CFourWheelVehiclePhysics::Initialize dereferencing the null body vphysics handed
    back.  The real vehicles are (class + model + vehicle script) triples - exactly
    what GMod registers here - and the menu now drops any vehicle entry without a
    usable model (see the filter in lua/autorun/client/hl2sb_spawnmenu.lua).

    Difference from GMod's file, deliberate: GMod's "Jeep" is `prop_vehicle_jeep_old`,
    a class GMod's engine adds.  This engine's HL2 jeep is `prop_vehicle_jeep`
    (game/server/hl2/vehicle_jeep.cpp), so that is the class used here - the spawn
    NAME, the model and the vehicle script are GMod's.

    Only what this install can actually spawn is registered: the model must resolve
    through the search paths and the vehicle script must be on disk (GMod's Jalopy is
    Episode Two content - models/vehicle.mdl + scripts/vehicles/jalopy.txt - and it is
    registered only when that script is present, so it appears on an install that has
    it and never becomes a cell that does nothing).

    autorun/*.lua runs on BOTH realms (GMod keeps its copy there too); the list is
    client-side spawn data and is harmless on the server.
----------------------------------------------------------------------------]]--

if ( type( list ) ~= "table" or list.Set == nil ) then
	print( "[HL2SB] hl2sb_gmod_vehicles.lua: the list module is missing - vehicles not registered\n" )
	return
end

local function OnDisk( path )
	if ( file == nil or file.Exists == nil ) then return true end	-- cannot tell: do not hide it
	return file.Exists( path, "GAME" )
end

-- GMod's grouping for these (base_vehicles.lua: Category = "Half-Life 2").
local HL2 = "Half-Life 2"

-- id        - GMod's SPAWN NAME (the list key, and the entry's identity in the menu)
-- label     - what the cell prints
-- class     - the engine class to spawn
-- model     - the model that makes it this vehicle
-- script    - the vehiclescript KeyValue
-- icon      - materials/<icon>.png; the menu falls back to entities/<class> by itself
local VEHICLES =
{
	{ id = "Jeep",    label = "吉普车",     class = "prop_vehicle_jeep",
	  model = "models/buggy.mdl",                  script = "scripts/vehicles/jeep_test.txt",
	  icon = "entities/jeep" },

	{ id = "Airboat", label = "汽艇",       class = "prop_vehicle_airboat",
	  model = "models/airboat.mdl",                script = "scripts/vehicles/airboat.txt",
	  icon = "entities/airboat" },

	{ id = "Pod",     label = "囚禁舱",     class = "prop_vehicle_prisoner_pod",
	  model = "models/vehicles/prisoner_pod_inner.mdl", script = "scripts/vehicles/prisoner_pod.txt",
	  icon = "entities/pod" },

	{ id = "prop_vehicle_apc", label = "联合军 APC", class = "prop_vehicle_apc",
	  model = "models/combine_apc.mdl",            script = "scripts/vehicles/apc.txt",
	  icon = "entities/prop_vehicle_apc" },

	-- Episode Two content: model and script both have to be there for the cell to do
	-- anything, so it is conditional rather than always listed.
	{ id = "Jalopy",  label = "肌肉车",     class = "prop_vehicle_jeep",
	  model = "models/vehicle.mdl",                script = "scripts/vehicles/jalopy.txt",
	  icon = "entities/jalopy" },
}

local n = 0

for _, v in ipairs( VEHICLES ) do
	if ( not OnDisk( v.model ) ) then
		print( "[HL2SB] hl2sb_gmod_vehicles.lua: skipping '" .. v.id ..
			"' - no " .. v.model .. "\n" )
	elseif ( v.script ~= nil and v.script ~= "" and not OnDisk( v.script ) ) then
		print( "[HL2SB] hl2sb_gmod_vehicles.lua: skipping '" .. v.id ..
			"' - no " .. v.script .. "\n" )
	else
		list.Set( "Vehicles", v.id, {
			-- GMod spells the label `Name`; its content types read `PrintName`.
			Name		= v.label,
			PrintName	= v.label,

			Class		= v.class,
			Model		= v.model,
			Category	= HL2,
			IconOverride	= v.icon,

			KeyValues	= {
				vehiclescript	= v.script,
				limitview	= "0",
			},
		} )

		n = n + 1
	end
end

Msg( "[HL2SB] hl2sb_gmod_vehicles.lua: registered " .. tostring( n ) ..
	" GMod vehicle entries in the Vehicles list\n" )
