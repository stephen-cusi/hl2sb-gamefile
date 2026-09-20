local Category = "SCP"

local NPC = { 	Name = "SCP-049", 
				Class = "npc_scp_049",
				Category = Category	}

list.Set( "NPC", NPC.Class, NPC )

local NPC = { 	Name = "SCP-049-2", 
				Class = "npc_scp_049-2",
				Category = Category	}

list.Set( "NPC", NPC.Class, NPC )

sound.Add({
	name =				"SCP049_Alert",
	channel =			CHAN_VOICE,
	volume =			1.0,
	soundlevel =			80,
	sound =				{"049_alert_1.wav", "049_alert_2.wav", "049_alert_3.wav", "049_alert_4.wav"}
})

sound.Add({
	name =				"SCP049_Combat",
	channel =			CHAN_VOICE,
	volume =			1.0,
	soundlevel =			80,
	sound =				{"049_2.wav", "049_3.wav", "049_4.wav", "049_5.wav", "049_6.wav", "049_7.wav", "049_8.wav"}
})

sound.Add(
{
    name = "SCP0492_Breath",
    channel = CHAN_VOICE,
    volume = 1.0,
    soundlevel = 80,
    sound = "0492_breath.wav"
})