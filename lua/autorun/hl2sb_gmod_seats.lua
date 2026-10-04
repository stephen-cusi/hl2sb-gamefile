--[[----------------------------------------------------------------------------
    hl2sb_gmod_seats.lua

    Garry's Mod's vehicle seats, in HL2SB's SMenu Vehicles page.

    GMod ships these in garrysmod/lua/autorun/base_vehicles.lua, registered with
    `list.Set( "Vehicles", <spawn name>, { ... } )` (the "Chairs" category,
    spawnmenu.category.chairs).  Every one of them is the SAME engine class -
    prop_vehicle_prisoner_pod - and it is the MODEL that makes each seat a
    different thing, which is why GMod keys this list by SPAWN NAME instead of by
    class.  The spawn names, models and vehicle script below are GMod's own
    values, verbatim:

        spawn name     model                            GMod's own label
        Chair_Wood     models/nova/chair_wood01.mdl     #spawnmenu.chair.wooden
        Chair_Plastic  models/nova/chair_plastic01.mdl  #spawnmenu.chair.plastic
        Chair_Office1  models/nova/chair_office01.mdl   #spawnmenu.chair.office
        Chair_Office2  models/nova/chair_office02.mdl   #spawnmenu.chair.office_big
        Seat_Jeep      models/nova/jeep_seat.mdl        #spawnmenu.seat.jeep
        Seat_Airboat   models/nova/airboat_seat.mdl     #spawnmenu.seat.airboat
        Seat_Jalopy    models/nova/jalopy_seat.mdl      #spawnmenu.seat.jalopy
        phx_seat       models/props_phx/carseat2.mdl    #spawnmenu.seat.simple_sit
        phx_seat2      models/props_phx/carseat3.mdl    #spawnmenu.seat.simple_jeep
        phx_seat3      models/props_phx/carseat2.mdl    #spawnmenu.seat.simple_airboat

    All ten models, the vehicle script (scripts/vehicles/prisoner_pod.txt) and
    GMod's spawnmenu thumbnails (materials/entities/*.png) come out of the GMod
    VPK, which gameinfo.txt mounts as game+mod - verified against the VPK tree,
    not assumed.

    PrintName is the Chinese label the user's GMod shows in its Vehicles tab.  It
    is written as a plain UTF-8 string rather than as GMod's "#spawnmenu...."
    token on purpose: this fork's resource/ language files do not carry GMod's
    spawnmenu.properties, and SMenu's name resolution passes a plain string
    through untouched (a token that resolves to nothing falls through to the
    class name instead).

    NOTE on the label/pairing: the three car-seat variants are one family, so
    they are the three phx_seat* entries; Seat_Airboat and Seat_Jalopy take the
    two remaining labels.  Swapping a label is a one-line change here - the
    spawn names, models and icons are GMod's, only the display text was chosen to
    match the user's menu.

    SMenu reads this list from the client's own Lua state when it (re)builds its
    entry list, and turns each entry into one cell of the Vehicles page with the
    spawn line `ent_create prop_vehicle_prisoner_pod model <model>
    <KeyValues>` from the data below (see SMenu_MergeLuaVehicleList in
    game/client/menu/sm_menu_list.cpp).  autorun/*.lua runs on BOTH realms, which
    is exactly where GMod keeps this file; the registration itself is client-side
    data and is harmless on the server.
----------------------------------------------------------------------------]]--

if ( type( list ) ~= "table" or list.Set == nil ) then
	print( "[HL2SB] hl2sb_gmod_seats.lua: the list module is missing - seats not registered\n" )
	return
end

local SEAT_CLASS = "prop_vehicle_prisoner_pod"
local SEAT_SCRIPT = "scripts/vehicles/prisoner_pod.txt"

-- GMod's own grouping (base_vehicles.lua: Category = "#spawnmenu.category.chairs",
-- zh-cn "座椅").  SMenu uses it for the Vehicles page's sidebar bucket, the way
-- GMod shows a "Chairs" node instead of dumping the seats in with the jeep.
local SEAT_CATEGORY = "座椅"

-- HL2SB (sbrust): GMod's seat POSE handlers (base_vehicles.lua:222-230).  The
-- engine's animations.lua HandlePlayerDriving looks the spawned vehicle up in
-- this list by its VehicleClass string (the `vehicleclass` keyvalue below,
-- GMod's sandbox SetVehicleClass(VName) equivalent -- commands.lua:1057) and
-- runs the entry's Members.HandleAnimation( vehicle, player ) as the sequence
-- override.  GMod's own handlers ask through SelectWeightedSequence( ACT_* )
-- with GMod-private activity numbers baked into the model's ACT table; this
-- fork has no ACT_DRIVE_JEEP / ACT_DRIVE_AIRBOAT enum (and anime playermodels
-- carry no such mappings), so the handlers resolve the SAME sequences by the
-- NAME GMod's acttable maps to -- verified present in the current playermodel
-- (sit_rollercoaster 388, drive_jeep 390, drive_airboat 389, sit 11).  A model
-- without the sequence answers -1 = "no override", exactly GMod's miss case.
local function HandleRollercoasterAnimation( vehicle, player )
	return player:LookupSequence( "sit_rollercoaster" )
end
local function HandlePHXSeatAnimation( vehicle, player )
	return player:LookupSequence( "sit" )
end
local function HandlePHXVehicleAnimation( vehicle, player )
	return player:LookupSequence( "drive_jeep" )
end
local function HandlePHXAirboatAnimation( vehicle, player )
	return player:LookupSequence( "drive_airboat" )
end

-- id      - the SPAWN NAME GMod uses; also the name of its spawnmenu thumbnail
--           (materials/entities/<lowercase id>.png, found via IconOverride).
-- label   - what the cell prints.
-- model   - the model that makes this seat this seat.
-- icon    - materials/<icon>.png from GMod's materials/entities/ set.
-- pose    - the HandleAnimation above this seat uses (GMod's per-entry choice:
--           chairs = rollercoaster; phx_seat = plain sit; phx_seat2 = the jeep
--           drive pose; phx_seat3 = the airboat drive pose).
local SEATS =
{
	{ id = "Chair_Office1",	label = "办公椅座椅",		model = "models/nova/chair_office01.mdl",	icon = "entities/chair_office1",	pose = HandleRollercoasterAnimation },
	{ id = "Seat_Jeep",		label = "吉普车座椅",		model = "models/nova/jeep_seat.mdl",		icon = "entities/seat_jeep",		pose = HandleRollercoasterAnimation },
	{ id = "Chair_Plastic",	label = "塑料椅",			model = "models/nova/chair_plastic01.mdl",	icon = "entities/chair_plastic",	pose = HandleRollercoasterAnimation },
	{ id = "Chair_Office2",	label = "大办公椅座椅",		model = "models/nova/chair_office02.mdl",	icon = "entities/chair_office2",	pose = HandleRollercoasterAnimation },
	{ id = "Chair_Wood",	label = "木椅子",			model = "models/nova/chair_wood01.mdl",		icon = "entities/chair_wood",		pose = HandleRollercoasterAnimation },
	{ id = "phx_seat",		label = "汽车座椅(空)",		model = "models/props_phx/carseat2.mdl",	icon = "entities/phx_seat",		pose = HandlePHXSeatAnimation },
	{ id = "phx_seat2",		label = "汽车座椅(左乘客)",	model = "models/props_phx/carseat3.mdl",	icon = "entities/phx_seat2",		pose = HandlePHXVehicleAnimation },
	{ id = "phx_seat3",		label = "汽车座椅(右乘客)",	model = "models/props_phx/carseat2.mdl",	icon = "entities/phx_seat3",		pose = HandlePHXAirboatAnimation },
	{ id = "Seat_Airboat",	label = "汽座位置",			model = "models/nova/airboat_seat.mdl",		icon = "entities/seat_airboat",	pose = HandleRollercoasterAnimation },
	{ id = "Seat_Jalopy",	label = "豪华车座椅",		model = "models/nova/jalopy_seat.mdl",		icon = "entities/seat_jalopy",	pose = HandleRollercoasterAnimation },
}

for _, seat in ipairs( SEATS ) do
	list.Set( "Vehicles", seat.id, {
		-- GMod spells the label `Name`; its content types read `PrintName`.
		-- SMenu accepts either, so both are set and the cell is labelled no
		-- matter which one the reader prefers.
		Name		= seat.label,
		PrintName	= seat.label,

		Class		= SEAT_CLASS,
		Model		= seat.model,
		Category	= SEAT_CATEGORY,

		-- GMod's vehicle content type: `material = ent.IconOverride or
		-- "entities/" .. ent.SpawnName .. ".png"`.  Given here as the material
		-- BASE name (the extension is discovered by SMenu), so the icon cannot
		-- depend on the case-sensitivity of the spawn name.
		IconOverride = seat.icon,

		-- Same KeyValues GMod passes for every seat: the pod's own vehicle
		-- script (it is what gives the model a seat to sit on), GMod's
		-- third-person `limitview 0`, and HL2SB (sbrust) the vehicle TABLE
		-- name -- GMod's sandbox writes it via vehicle:SetVehicleClass(spawnname)
		-- at spawn (commands.lua:1057); the fork's gm_spawnvehicle forwards
		-- every KeyValues entry to the entity as a KeyValue before Spawn, and
		-- the `vehicleclass` keyfield stores it on the pod.  The seat pose
		-- lookup (animations.lua HandlePlayerDriving -> list.GetEntry
		-- ( "Vehicles", GetVehicleClass() ).Members.HandleAnimation) depends
		-- on this value; without it every seat falls to the generic
		-- sit_rollercoaster answer.
		KeyValues = {
			vehiclescript	= SEAT_SCRIPT,
			limitview		= "0",
			vehicleclass	= seat.id,
		},

		-- HL2SB (sbrust): GMod's seat POSE callback slot (base_vehicles.lua:
		-- Members = { HandleAnimation = ... }).  Consumed server-side by
		-- animations.lua HandlePlayerDriving; SMenu ignores this table.
		Members = {
			HandleAnimation = seat.pose,
		},
	} )
end

Msg( "[HL2SB] hl2sb_gmod_seats.lua: registered " .. tostring( #SEATS ) .. " GMod vehicle seats in the Vehicles list\n" )
