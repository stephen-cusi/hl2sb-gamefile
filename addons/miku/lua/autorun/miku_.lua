--Add Playermodel
player_manager.AddValidModel( "Miku", "models/PM/miku_PM.mdl" )                         --PM模型
player_manager.AddValidHands( "Miku", "models/arms/miku_arms.mdl", 0, "00000000" )      --PM手模

local Category = "Miku"                                                                        --NPC MOD分类

local NPC = 
{
	Name = "Miku(Friendly)",                                                            --友好NPC名字
	Class = "npc_citizen", 
	Health = "150",                                                                    --NPC血量
	KeyValues = { citizentype = 4 }, 
	Model = "models/NPC/miku_npc.mdl",                                                  --友好NPC模型
	Weapons = { "weapon_ar2","weapon_smg1"},                                           --NPC出生自带武器
	Category = Category
}

list.Set( "NPC", "miku_friendly", NPC )

local NPC =
{
	Name = "Miku(Enemy)",                                                                --敌人NPC名字
	Class = "npc_combine_s",
	Health = "150",
	Numgrenades = "4",
	Model = "models/NPC/miku_npc.mdl",                                                  --敌人NPC模型
	Weapons = { "weapon_ar2","weapon_smg1"},
	Category = Category
}

list.Set( "NPC", "miku_enemy", NPC )
