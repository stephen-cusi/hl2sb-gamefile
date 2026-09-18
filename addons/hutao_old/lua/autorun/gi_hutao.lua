player_manager.AddValidModel( "gi_hutao", "models/daniao/gi_hutao/gi_hutao_player.mdl" );
player_manager.AddValidHands( "gi_hutao", "models/daniao/gi_hutao/gi_hutao_arms.mdl", 0, "00000000" )

local Category = "Genshin Impact Hutao"

local NPC = { 	Name = "gi_hutao - Friendly", 
				Class = "npc_citizen",
				Model = "models/daniao/gi_hutao/gi_hutao_f.mdl",
				Health = "100",
				KeyValues = { citizentype = 4 },
				Weapons = { "weapons_smg1" },
				Category = Category	}

list.Set( "NPC", "gi_hutao_friendly", NPC )

local NPC = { 	Name = "gi_hutao - Hostile", 
				Class = "npc_combine_s",
				Model = "models/daniao/gi_hutao/gi_hutao_e.mdl",
				Squadname = "gi_hutao",
				Numgrenades = "3",
				Health = "100",
				Category = Category	}

list.Set( "NPC", "gi_hutao_hostile", NPC )