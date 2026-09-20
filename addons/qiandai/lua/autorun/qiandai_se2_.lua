--Add Playermodel
player_manager.AddValidModel( "qiandai_open", "models/PM/qiandai_open_PM.mdl" )                         --PM模型
player_manager.AddValidHands( "qiandai_open", "models/arms/qiandai_se_arms.mdl", 0, "00000000" )      --PM手模

local Category = "Strinova(se)"                                                                        --NPC MOD分类

local NPC = 
{
	Name = "qiandai_close(Friendly)",                                                            --友好NPC名字
	Class = "npc_citizen", 
	Health = "150",                                                                    --NPC血量
	KeyValues = { citizentype = 4 }, 
	Model = "models/NPC/qiandai_open_npc.mdl",                                                  --友好NPC模型
	Weapons = { "weapon_ar2","weapon_smg1"},                                           --NPC出生自带武器
	Category = Category
}

list.Set( "NPC", "qiandai_se_friendly2", NPC )

local NPC =
{
	Name = "qiandai_close_a(Enemy)",                                                                --敌人NPC名字
	Class = "npc_combine_s",
	Health = "150",
	Numgrenades = "4",
	Model = "models/NPC/qiandai_open_npc.mdl",                                                  --敌人NPC模型
	Weapons = { "weapon_ar2","weapon_smg1"},
	Category = Category
}

list.Set( "NPC", "qiandai_se_enemy2", NPC )
