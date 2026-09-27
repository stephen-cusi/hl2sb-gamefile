player_manager.AddValidModel("Hu Tao", "models/sheepylord/genshin_impact/hutao_sheepylord_pm.mdl");
player_manager.AddValidHands("Hu Tao", "models/sheepylord/genshin_impact/hutao_sheepylord_arms.mdl" , 0, "000000")

local Category = "Genshin Impact"

local NPC = {
    Name = "Hu Tao (Friendly)",
    Class = "npc_citizen",
    Model = "models/sheepylord/genshin_impact/hutao_sheepylord.mdl",
    Health = "100",
    KeyValues = { citizentype = 4 },
    Weapons = { "weapon_smg1" },
    Category = Category
}

list.Set("NPC", "hutao_sheepylord_sheepylord_F", NPC)

local NPC = {
    Name = "Hu Tao (Enemy)",
    Class = "npc_combine_s",
    Model = "models/sheepylord/genshin_impact/hutao_sheepylord.mdl",
    Health = "100",
    Numgrenades = "4",
    Weapons = { "weapon_ar2" },
    Category = Category
}

list.Set("NPC", "hutao_sheepylord_sheepylord_E", NPC)
