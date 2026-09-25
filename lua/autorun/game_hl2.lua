--[[--------------------------------------------------------------------------
	game_hl2.lua  --  GMod's lua/autorun/game_hl2.lua (211 lines), ported.

	This is the STOCK spawnmenu registry: the Half-Life 2 ammo / items / weapons
	that GMod's Entities + Weapons tabs are built from.  The fork's Entities tab
	reads list.Get( "SpawnableEntities" ) and the Weapons tab reads
	weapons.GetList(), so the two ADD_* helpers below also route the weapons
	through weapons.Register (the fork's CollectWeapons reads the WeaponList
	weapons.Register fills, not the raw list).

	Adaptations from GMod's file, all forced by this fork:
	  * PrintName: GMod registers "#weapon_stunstick" style TOKENS and its
	    engine resolves them; this fork's text layer does not, so the readable
	    names are stored directly (the ITEM_NAME / WEAPON_NAME maps).
	  * language.FormatPhrase / localization packs do not exist here, so no
	    "#spawnmenu.category.ammo_items" SubCategory -- everything lands in the
	    "Half-Life 2" category, like GMod's without the language pack.
	  * IsMounted( "hl1" / "portal" ) blocks kept: this fork answers false and
	    they skip themselves.
	  * `return NULL` in the dupe functions: NULL is nil here, which is what
	    those failure paths need (a falsy, invalid entity).
----------------------------------------------------------------------------]]

local Category = ""

-- the fork's list.lua spells GetForEdit/Get but not GMod's GetEntry
local listGetEntry = list.GetEntry or function( listid, name )
	local t = list.Get( listid )
	if ( t ~= nil ) then return t[ name ] end
	return nil
end

-- readable names (GMod resolves these from its localization; we store them)
local ITEM_NAME = {
	item_ammo_ar2           = "AR2 Ammo",
	item_ammo_ar2_large     = "AR2 Ammo (Large)",
	item_ammo_pistol        = "9mm Pistol Ammo",
	item_ammo_pistol_large  = "9mm Pistol Ammo (Large)",
	item_ammo_357           = ".357 Ammo",
	item_ammo_357_large     = ".357 Ammo (Large)",
	item_ammo_smg1          = "SMG Ammo",
	item_ammo_smg1_large    = "SMG Ammo (Large)",
	item_ammo_smg1_grenade  = "SMG Grenade",
	item_ammo_crossbow      = "Crossbow Bolt",
	item_box_buckshot       = "Shotgun Ammo",
	item_ammo_ar2_altfire   = "AR2 Alt-Fire Ammo",
	item_rpg_round          = "RPG Round",
	item_battery            = "Suit Battery",
	item_healthkit          = "Medkit",
	item_healthvial         = "Health Vial",
	item_suitcharger        = "Suit Charger",
	item_healthcharger      = "Health Charger",
	item_suit               = "HEV Suit",
	prop_thumper            = "Thumper",
	combine_mine            = "Combine Mine",
	combine_mine_resistance = "Combine Mine (Resistance)",
	npc_grenade_frag        = "Grenade",
	grenade_helicopter      = "Helicopter Bomb",
	weapon_striderbuster    = "Strider Buster",
}

local WEAPON_NAME = {
	weapon_physcannon = "Gravity Gun",
	weapon_stunstick  = "Stunstick",
	weapon_frag       = "Grenade",
	weapon_crossbow   = "Crossbow",
	weapon_bugbait    = "Bug Bait",
	weapon_rpg        = "RPG",
	weapon_crowbar    = "Crowbar",
	weapon_shotgun    = "Shotgun",
	weapon_pistol     = "9mm Pistol",
	weapon_slam       = "S.L.A.M.",
	weapon_smg1       = "SMG",
	weapon_ar2        = "Pulse Rifle",
	weapon_357        = ".357 Magnum",
	weapon_physgun    = "Physics Gun",
}

local function ADD_ITEM_DUPEFUNC( ply, data )
	if ( IsValid( ply ) && gamemode.Call( "PlayerSpawnSENT", ply, data.Class ) == false ) then return NULL end

	local ent = ents.Create( data.Class )
	if ( !IsValid( ent ) ) then return NULL end

	data.Model = nil

	local entTable = listGetEntry( "SpawnableEntities", data.EntityName )
	if ( entTable && entTable.ClassName == data.Class && entTable.KeyValues ) then
		for k, v in pairs( entTable.KeyValues ) do
			ent:SetKeyValue( k, v )
		end
	end

	duplicator.DoGeneric( ent, data )

	ent:Spawn()
	ent:Activate()

	ent.EntityName = data.EntityName

	if ( data.Skin ) then ent:SetSkin( data.Skin ) end

	if ( IsValid( ply ) ) then
		if ( ent.SetCreator ) then ent:SetCreator( ply ) end
		gamemode.Call( "PlayerSpawnedSENT", ply, ent )
	end

	return ent
end

local function ADD_WEAPON_DUPEFUNC( ply, data )
	if ( IsValid( ply ) && gamemode.Call( "PlayerSpawnSWEP", ply, data.Class, listGetEntry( "Weapon", data.Class ) ) == false ) then return NULL end

	local ent = ents.Create( data.Class )
	if ( !IsValid( ent ) ) then return NULL end

	data.Model = nil

	duplicator.DoGeneric( ent, data )

	ent:Spawn()
	ent:Activate()

	ent.EntityName = data.EntityName

	if ( IsValid( ply ) ) then
		if ( ent.SetCreator ) then ent:SetCreator( ply ) end
		gamemode.Call( "PlayerSpawnedSWEP", ply, ent )
	end

	return ent
end

local function ADD_ITEM( class, offset, extras, classOverride )

	local base = {
		PrintName    = ITEM_NAME[ classOverride or class ] or ( classOverride or class ),
		ClassName    = class,
		Category     = Category,
		NormalOffset = offset or 32,
		DropToFloor  = true,
		Author       = "VALVe",
	}
	list.Set( "SpawnableEntities", classOverride or class, table.Merge( base, extras or {} ) )
	duplicator.RegisterEntityClass( class, ADD_ITEM_DUPEFUNC, "Data" )

end

local function ADD_WEAPON( class )

	local t = {
		ClassName = class,
		PrintName = WEAPON_NAME[ class ] or class,
		Category  = Category,
		Author    = "VALVe",
		Spawnable = true,
	}
	list.Set( "Weapon", class, t )

	-- the fork's CollectWeapons reads weapons.GetList(), which is the
	-- WeaponList this fills (GMod's weapons.GetList reads the raw list)
	if ( weapons ~= nil and weapons.Register ~= nil ) then
		weapons.Register( t, class )
	end

	duplicator.RegisterEntityClass( class, ADD_WEAPON_DUPEFUNC, "Data" )

end

Category = "Half-Life 2"

-- Ammo
ADD_ITEM( "item_ammo_ar2", -8 )
ADD_ITEM( "item_ammo_ar2_large", -8 )

ADD_ITEM( "item_ammo_pistol", -4 )
ADD_ITEM( "item_ammo_pistol_large", -4 )

ADD_ITEM( "item_ammo_357", -4 )
ADD_ITEM( "item_ammo_357_large", -4 )

ADD_ITEM( "item_ammo_smg1", -2 )
ADD_ITEM( "item_ammo_smg1_large", -2 )

ADD_ITEM( "item_ammo_smg1_grenade", -10 )
ADD_ITEM( "item_ammo_crossbow", -10 )
ADD_ITEM( "item_box_buckshot", -10 )
ADD_ITEM( "item_ammo_ar2_altfire", -2 )
ADD_ITEM( "item_rpg_round", -10 )

-- Items
ADD_ITEM( "item_battery", -4 )
ADD_ITEM( "item_healthkit", -8 )
ADD_ITEM( "item_healthvial", -4 )
ADD_ITEM( "item_suitcharger" )
ADD_ITEM( "item_healthcharger" )
ADD_ITEM( "item_suit", 0 )

ADD_ITEM( "prop_thumper" )
ADD_ITEM( "combine_mine", -8 )
ADD_ITEM( "combine_mine", -8, { KeyValues = { Modification = 1 } }, "combine_mine_resistance" )
ADD_ITEM( "npc_grenade_frag", -8 )
ADD_ITEM( "grenade_helicopter", 4 )

ADD_ITEM( "weapon_striderbuster" )

-- Weapons (GMod's game_hl2.lua order)
ADD_WEAPON( "weapon_physcannon" )
ADD_WEAPON( "weapon_stunstick" )
ADD_WEAPON( "weapon_frag" )
ADD_WEAPON( "weapon_crossbow" )
ADD_WEAPON( "weapon_bugbait" )
ADD_WEAPON( "weapon_rpg" )
ADD_WEAPON( "weapon_crowbar" )
ADD_WEAPON( "weapon_shotgun" )
ADD_WEAPON( "weapon_pistol" )
ADD_WEAPON( "weapon_slam" )
ADD_WEAPON( "weapon_smg1" )
ADD_WEAPON( "weapon_ar2" )
ADD_WEAPON( "weapon_357" )

Category = "#spawnmenu.category.other"
ADD_WEAPON( "weapon_physgun" )
