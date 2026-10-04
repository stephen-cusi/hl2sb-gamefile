if SERVER then	
	util.AddNetworkString("plySpawned")
	util.AddNetworkString("plyDead")

	hook.Add("PlayerSpawn", "EscapefromTarkov_HUDResetValue", function(ply)
		net.Start("plySpawned")
		net.WriteEntity(ply)
		net.Send(ply)
	end)

	hook.Add("PlayerDeath", "EscapeFromTarkov_HUDSetValue", function(ply)
		net.Start("plyDead")
		net.WriteEntity(ply)
		net.Send(ply)
	end)

elseif CLIENT then

	TarkovEnabled = CreateClientConVar("tarkovhud_enabled", 1, true)
	Stamina_and_stance = CreateClientConVar("tarkovhud_autohide_stamina", 1, true)
	HP_Condition = CreateClientConVar("tarkovhud_autohide_hp", 1, true)
	Colored = CreateClientConVar("tarkovhud_hp_colored", 0, true)
	BluronNearDeathScreen = CreateClientConVar("tarkovhud_blur_neardeath", 1, true)
	BluronDamage = CreateClientConVar("tarkovhud_blur", 1, true)
	AmmoUseSecondKey = CreateClientConVar("tarkovhud_ammocheck_use2ndkey", 1, true)
	AmmoCheck = CreateClientConVar("tarkovhud_ammocheck", 81, true)
	SecondAmmoCheck = CreateClientConVar("tarkovhud_ammocheck2nd", 30, true)
	DontCheck = CreateClientConVar("tarkovhud_dontfmcheck", 0, true)
	FMUseSecondkey = CreateClientConVar("tarkovhud_fmcheck_use2ndkey", 1, true)
	FMCheck = CreateClientConVar("tarkovhud_fmcheck", 81, true)
	SecondFMCheck = CreateClientConVar("tarkovhud_fmcheck2nd", 12, true)
	Notification = CreateClientConVar("tarkovhud_notification", 1, true)
	HealNotification = CreateClientConVar("tarkovhud_notification_heal", 1, true)
	InteractHUD = CreateClientConVar("tarkovhud_interact", 1, true)
	InteractDoor = CreateClientConVar("tarkovhud_interact_door", 1, true)

	surface.CreateFont("tarkovFont", {
		font = "MBender",
		size = 39,
		weight = 500,
		antialias = true,
	})
	surface.CreateFont("tarkovFont_icon", {
		font = "Bender",
		size = 14,
		weight = 500,
		antialias = true,
		outline = true,
	})
	surface.CreateFont("tarkovFont_notification", {
		font = "Bender",
		size = 18,
		weight = 500,
		antialias = true,
	})
	surface.CreateFont("tarkovFont_interact", {
		font = "MBender",
		size = 12,
		weight = 500,
		antialias = true,
	})

	local hide = {
		["CHudHealth"] = true,
		["CHudBattery"] = true,
		["CHudAmmo"] = true,
		["CHudSecondaryAmmo"] = true,
		["CHudDamageIndicator"] = true,

	}

	hook.Add("HUDShouldDraw", "EscapeFromTarkov_HideHUD", function(name)
		if TarkovEnabled:GetInt() >= 1 then
			if (hide[name]) then return false end
		end
	end)

	hook.Add("HUDDrawPickupHistory", "EscapeFromTarkov_HidePickedHistoryHUD", function()
		if TarkovEnabled:GetInt() >= 1 then
			if Notification:GetInt() >= 1 then
				return true
			end
		end
	end)

	local OldHealth = 0
	local OldArmor = 0
	local movedarrow = 18
	HPHUDAlpha = 255
	HPConHUDAlpha = 255
	hpinputed = 0
	hpconinputed = 0
	bldinputed = 0
	noticeinputed = 0
	AMMOHUDAlpha = 255
	ammoinputed = 0
	StandingStats = 0
	Walkdetect = 0
	deathvalue = 0
	Passes = 0
	AddAlpha = 1
	NearDeathAlpha = 0
	destroyed = 155
	Headdestroyed = 155
	Thoraxdestroyed = 155
	LeftArmdestroyed = 155
	RightArmdestroyed = 155
	LeftLegdestroyed = 155
	RightLegdestroyed = 155
	deathscreen = 1000
	FMCheckDelay = 0
	AMMOCheckDelay = 0
	shn = 30
	NoticeAlpha = 0
	item = ""
	FM = ""
	fminputed = 0
	FiremodeAlpha = 255
	Ammo = ""
	fixvalue = 0
	fixinputed = 0
	noticecolor = 1
	SAMMOHUDAlpha = 255
	sammoinputed = 0
	CURSORHUDAlpha = 255
	CursoR = 1
	pressinputed = 0
	brightvalue = 0
	deathinputed = 0

	hook.Add("HUDPaint", "EscapeFromTarkov_HUD", function()
		if TarkovEnabled:GetInt() >= 1 then

			local ply = LocalPlayer()
			local wep = ply:GetActiveWeapon()

			if IsValid(ply) and ply:Alive() then

				local sw = ScrW()/ScrW()+54
				local sh = ScrH()-242

				--HP表示
				local Health = ply:Health()
				local Armor = ply:Armor()
				local MaxHealth = ply:GetMaxHealth()
				local MaxArmor = ply:GetMaxArmor()
				local HealthshouldTrue = true
				local HealthconshouldTrue = true
				local neardeathshouldTrue = false
				local bloodshouldTrue = true
				local NoticeshouldTrue = true
				local FixMalshouldTrue = true
				local CursorshouldTrue = true
				local ADS = true
				swhp = sw - 8
				shhp = sh + 185
				PanelAlpha = HPHUDAlpha
				SliderAlpha = HPHUDAlpha
				SliderAlpha_red = 0
				HPbar = 0
				AMbar = 0
				Healthpercent = math.Clamp(Health / MaxHealth*100, 0, 100)
				Armorpercent = math.Clamp(Armor / MaxArmor*100, 0, 100)
				HPbarpercent = math.Clamp(Health / MaxHealth*146, 0, 146)
				AMbarpercent = math.Clamp(Armor / MaxArmor*146, 0, 146)

				if BluronDamage:GetInt() <= 0 then
					Passes = 0
				end

				if ConVarExists("vivo_enable") and (GetConVarNumber("vivo_enable")) != 0 then
					if OldHealth - Health > 3 then
						Passes = 8
					end
				else
					if Health < OldHealth then
						Passes = 8
					end
				end

				if Healthpercent <= 0 then
					Healthpercent = 0
				elseif Health <= MaxHealth / 10 then
					hpinputed = CurTime()
					SliderAlpha_red = HPHUDAlpha
					SliderAlpha = 0
				elseif Healthpercent >= 100 then
					Healthpercent = 100
				end

				if Armorpercent <= 0 then
					Armorpercent = 0
					PanelAlpha = 0
				elseif Armorpercent >= 0 then
					HPbar = 9
					AMbar = 9
					PanelAlpha = HPHUDAlpha
					if Armorpercent > 100 then
						Armorpercent = 100
					end
				end

				if Health < OldHealth then
					hpconinputed = CurTime()
				elseif Health > OldHealth then
					if Notification:GetInt() >= 1 then
						if HealNotification:GetInt() >= 1 then
							surface.PlaySound("notification_exp.wav")
							shn = 30
							NoticeAlpha = 0
							noticecolor = 1
							noticeinputed = CurTime()
							item = "Treatment Experience - Healing (" .. Health - OldHealth .. ")"
						end
					end
				elseif Armor < OldArmor then
					hpconinputed = CurTime()
					Passes = 8
				elseif Armor > OldArmor then
					hpinputed = CurTime()
				end

				OldHealth = Health
				OldArmor = Armor

				if Passes >= 0 then
		    		Passes = math.Approach(Passes, 0, 6 * FrameTime() / 0.5)
		    	end

				if Health <= MaxHealth / 3.5 then
					neardeathshouldTrue = true
				end

				if neardeathshouldTrue == true then
			    	NearDeathAlpha = math.Approach(NearDeathAlpha, 255, 255 * FrameTime() / 6)
			    	AddAlpha = 0.5
			    else
			      	NearDeathAlpha = math.Approach(NearDeathAlpha, 0, 255 * FrameTime() / 6)
			      	AddAlpha = 1
			    end

			    if BluronNearDeathScreen:GetInt() <= 0 then
					AddAlpha = 1
				end

			  	hook.Add("RenderScreenspaceEffects", "EscapeFromTarkov_HUDDamageEffect", function()
					DrawToyTown(Passes, sh)
					DrawMotionBlur(AddAlpha, 1, 0)
				end)

				surface.SetDrawColor(255, 255, 255, NearDeathAlpha)
				surface.SetMaterial(Material("Tarkov HUD/deathscreen/neardeath.png", "tarkovMaterial"))
				surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

			  	local swhc = ScrW()/ScrW()
			  	local shhc = ScrH()/ScrH()

				if ConVarExists("vivo_enable") and (GetConVarNumber("vivo_enable")) != 0 then

			  		local OJSHPTable=ply.OJSHPTable
					local limbTable={
						"Head",
						"Thorax",
						"Stomach",
						"RightArm",
						"LeftArm",
						"RightLeg",
						"LeftLeg"
					}

					if (OJSHPTable) then

						PainAlpha = 0
						PainH = 0
						BleedingAlpha = 0
						BleedingValueAlpha = 0
						Bleeding = 0
						BleedingH = 0
						BleedingDetect = 0
						FractureAlpha = 0
						FractureValueAlpha = 0
						Fracture = 0
						FractureH = 0
						FractureDetect = 0
						PainKillerAlpha = 0
						PainKillerH = 0
						ContusionAlpha = 0
						ContusionH = 0
						Headmax = GetConVarNumber("vivo_HPHeadMax")
						Thoraxmax = GetConVarNumber("vivo_HPThoraxMax")
						Stomachmax = GetConVarNumber("vivo_HPStomachMax")
						Armmax = GetConVarNumber("vivo_HPArmsMax")
						Legmax = GetConVarNumber("vivo_HPLegsMax")
						Head = OJSHPTable["Head"]["HP"]
						Thorax = OJSHPTable["Thorax"]["HP"]
						Stomach = OJSHPTable["Stomach"]["HP"]
						LeftArm = OJSHPTable["LeftArm"]["HP"]
						RightArm = OJSHPTable["RightArm"]["HP"]
						LeftLeg = OJSHPTable["LeftLeg"]["HP"]
						RightLeg = OJSHPTable["RightLeg"]["HP"]
						Headpercent = math.Clamp(Head / Headmax*155, 0, 155)
						ColoredHeadpercent = math.Clamp(Head / Headmax*155*2, 0, 155)
						ColoredHeadpercentminus = math.Clamp(155*2 - Head / Headmax*155*2, 0, 155)
					  	Thoraxpercent = math.Clamp(Thorax / Thoraxmax*155, 0, 155)
					  	ColoredThoraxpercent = math.Clamp(Thorax / Thoraxmax*155*2, 0, 155)
						ColoredThoraxpercentminus = math.Clamp(155*2 - Thorax / Thoraxmax*155*2, 0, 155)
					  	Stomachpercent = math.Clamp(Stomach / Stomachmax*155, 0, 155)
					  	ColoredStomachpercent = math.Clamp(Stomach / Stomachmax*155*2, 0, 155)
						ColoredStomachpercentminus = math.Clamp(155*2 - Stomach / Stomachmax*155*2, 0, 155)
					  	LeftArmpercent = math.Clamp(LeftArm / Armmax*155, 0, 155)
					  	ColoredLeftArmpercent = math.Clamp(LeftArm / Armmax*155*2, 0, 155)
						ColoredLeftArmpercentminus = math.Clamp(155*2 - LeftArm / Armmax*155*2, 0, 155)
					  	RightArmpercent = math.Clamp(RightArm / Armmax*155, 0, 155)
					  	ColoredRightArmpercent = math.Clamp(RightArm / Armmax*155*2, 0, 155)
						ColoredRightArmpercentminus = math.Clamp(155*2 - RightArm / Armmax*155*2, 0, 155)
					  	LeftLegpercent = math.Clamp(LeftLeg / Legmax*155, 0, 155)
					  	ColoredLeftLegpercent = math.Clamp(LeftLeg / Legmax*155*2, 0, 155)
						ColoredLeftLegpercentminus = math.Clamp(155*2 - LeftLeg / Legmax*155*2, 0, 155)
					  	RightLegpercent = math.Clamp(RightLeg / Legmax*155, 0, 155)
					  	ColoredRightLegpercent = math.Clamp(RightLeg / Legmax*155*2, 0, 155)
						ColoredRightLegpercentminus = math.Clamp(155*2 - RightLeg / Legmax*155*2, 0, 155)

					  	if OJSHPTable["Head"]["StatusEffects"]["Bleed"] then
					  		Bleeding = Bleeding + 1
					  	end
					  	if OJSHPTable["Thorax"]["StatusEffects"]["Bleed"] then
					  		Bleeding = Bleeding + 1
					  	end
					  	if OJSHPTable["Stomach"]["StatusEffects"]["Bleed"] then
					  		Bleeding = Bleeding + 1
					  	end
					  	if OJSHPTable["LeftArm"]["StatusEffects"]["Bleed"] then
					  		Bleeding = Bleeding + 1
					  	end
					  	if OJSHPTable["RightArm"]["StatusEffects"]["Bleed"] then
					  		Bleeding = Bleeding + 1
					  	end
					  	if OJSHPTable["LeftLeg"]["StatusEffects"]["Bleed"] then
					  		Bleeding = Bleeding + 1
					  	end
					  	if OJSHPTable["RightLeg"]["StatusEffects"]["Bleed"] then
					  		Bleeding = Bleeding + 1
					  	end

					  	if OJSHPTable["LeftArm"]["StatusEffects"]["Fractured"] then
					  		Fracture = Fracture + 1
					  	end
					  	if OJSHPTable["RightArm"]["StatusEffects"]["Fractured"] then
					  		Fracture = Fracture + 1
					  	end
					  	if OJSHPTable["LeftLeg"]["StatusEffects"]["Fractured"] then
					  		Fracture = Fracture + 1
					  	end
					  	if OJSHPTable["RightLeg"]["StatusEffects"]["Fractured"] then
					  		Fracture = Fracture + 1
					  	end

						for i=1,#limbTable do
							if OJSHPTable[limbTable[i]]["StatusEffects"]["Bleed"] then
								BleedingAlpha = HPConHUDAlpha
								BleedingDetect = 22
								if Bleeding <= 1 then
									BleedingValueAlpha = 0
								else
									BleedingValueAlpha = HPConHUDAlpha
								end
								ContusionH = BleedingDetect
							end

							if OJSHPTable[limbTable[i]]["StatusEffects"]["Fractured"] then
								FractureAlpha = HPConHUDAlpha
								FractureDetect = 22
								FractureH = BleedingDetect
								if Fracture <= 1 then
									FractureValueAlpha = 0
								else
									FractureValueAlpha = HPConHUDAlpha
								end
								ContusionH = BleedingDetect + FractureDetect
							end

							if OJSHPTable[limbTable[i]]["StatusEffects"]["Pain"] then
								PainAlpha = HPConHUDAlpha
								PainH = 22
								BleedingH = PainH
								FractureH = BleedingDetect + PainH
								ContusionH = BleedingDetect + FractureDetect + PainH
							end

							if OJSHPTable["Head"]["StatusEffects"]["Painkillers"] then
								PainKillerAlpha = HPConHUDAlpha
								PainKillerH = 22
								BleedingH = PainKillerH
								FractureH = BleedingDetect + PainKillerH
								ContusionH = BleedingDetect + FractureDetect + PainKillerH
							end

							if OJSHPTable["Head"]["StatusEffects"]["Dazed"] then
								ContusionAlpha = HPConHUDAlpha
								hook.Add( "RenderScreenspaceEffects", "EscapeFromTarkov_HUDDamageEffect", function()
									DrawMotionBlur( 0.1, 0.8, 0.01 )
								end)
							end
						end

					  	if Headpercent <= 0 then
					  		Headdestroyed = 0
					  		ColoredHeadpercentminus = 0
					  	else
					  		Headdestroyed = 155
					  	end

					  	if Thoraxpercent <= 0 then
					  		Thoraxdestroyed = 0
					  		ColoredThoraxpercentminus = 0
					  	else
					  		Thoraxdestroyed = 155
					  	end

					  	if Stomachpercent <= 0 then
					  		Stomachdestroyed = 0
					  		ColoredStomachpercentminus = 0
					  	else
					  		Stomachdestroyed = 155
					  	end

					  	if LeftArmpercent <= 0 then
					  		LeftArmdestroyed = 0
					  		ColoredLeftArmpercentminus = 0
					  	else
					  		LeftArmdestroyed = 155
					  	end

					  	if RightArmpercent <= 0 then
					  		RightArmdestroyed = 0
					  		ColoredRightArmpercentminus = 0
					  	else
					  		RightArmdestroyed = 155
					  	end

					  	if LeftLegpercent <= 0 then
					  		LeftLegdestroyed = 0
					  		ColoredLeftLegpercentminus = 0
					  	else
					  		LeftLegdestroyed = 155
					  	end

					  	if RightLegpercent <= 0 then
					  		RightLegdestroyed = 0
					  		ColoredRightLegpercentminus = 0
					  	else
					  		RightLegdestroyed = 155
					  	end

					  	if Colored:GetInt() >= 1 then
					  		Headpercent = 0
					  		Thoraxpercent = 0
					  		Stomachpercent = 0
					  		LeftArmpercent = 0
					  		RightArmpercent = 0
					  		LeftLegpercent = 0
					  		RightLegpercent = 0
					  		Headdestroyed = 0
					  		Thoraxdestroyed = 0
					  		Stomachdestroyed = 0
					  		LeftArmdestroyed = 0
					  		RightArmdestroyed = 0
					  		LeftLegdestroyed = 0
					  		RightLegdestroyed = 0
					  	else
					  		ColoredHeadpercent = 0
					  		ColoredThoraxpercent = 0
					  		ColoredStomachpercent = 0
					  		ColoredLeftArmpercent = 0
					  		ColoredRightArmpercent = 0
					  		ColoredLeftLegpercent = 0
					  		ColoredRightLegpercent = 0
					  		ColoredHeadpercentminus = 0
					  		ColoredThoraxpercentminus = 0
					  		ColoredStomachpercentminus = 0
					  		ColoredLeftArmpercentminus = 0
					  		ColoredRightArmpercentminus = 0
					  		ColoredLeftLegpercentminus = 0
					  		ColoredRightLegpercentminus = 0
					  	end

					  	surface.SetDrawColor(255, 255, 255, PainAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/effect_pain.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+145, shhc+7, 24, 22)
					  	surface.SetDrawColor(255, 255, 255, BleedingAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/effect_light_bleeding.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+145, shhc+7+BleedingH, 24, 22)
						surface.SetDrawColor(255, 255, 255, FractureAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/effect_fracture.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+145, shhc+7+FractureH, 24, 22)
						surface.SetDrawColor(255, 255, 255, PainKillerAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/effect_painkiller.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+145, shhc+7, 24, 22)
						surface.SetDrawColor(255, 255, 255, ContusionAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/effect_contusion.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+145, shhc+7+ContusionH, 24, 22)
						draw.SimpleText(Bleeding, "tarkovFont_icon", swhc+168, shhc+15+BleedingH, Color(255, 255, 255, BleedingValueAlpha), TEXT_ALIGN_RIGHT)
						draw.SimpleText(Fracture, "tarkovFont_icon", swhc+168, shhc+15+FractureH, Color(255, 255, 255, FractureValueAlpha), TEXT_ALIGN_RIGHT)

						surface.SetDrawColor(255, 255, 255, HPConHUDAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_char_back.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc, shhc, 148, 264)
						surface.SetDrawColor(ColoredHeadpercentminus+Headdestroyed, ColoredHeadpercent+Headpercent, Headpercent, HPConHUDAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_head.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+54, shhc+15, 41, 45)
						surface.SetDrawColor(ColoredThoraxpercentminus+Thoraxdestroyed, ColoredThoraxpercent+Thoraxpercent, Thoraxpercent, HPConHUDAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_chest.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+43, shhc+43, 60, 64)
						surface.SetDrawColor(ColoredStomachpercentminus+Stomachdestroyed, ColoredStomachpercent+Stomachpercent, Stomachpercent, HPConHUDAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_belly.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+42, shhc+87, 56, 50)
						surface.SetDrawColor(ColoredLeftArmpercentminus+LeftArmdestroyed, ColoredLeftArmpercent+LeftArmpercent, LeftArmpercent, HPConHUDAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_hand_left.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+82, shhc+50, 45, 98)
						surface.SetDrawColor(ColoredRightArmpercentminus+RightArmdestroyed, ColoredRightArmpercent+RightArmpercent, RightArmpercent, HPConHUDAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_hand_right.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+19, shhc+53, 45, 97)
						surface.SetDrawColor(ColoredLeftLegpercentminus+LeftLegdestroyed, ColoredLeftLegpercent+LeftLegpercent, LeftLegpercent, HPConHUDAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_leg_left.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+63, shhc+79, 50, 170)
						surface.SetDrawColor(ColoredRightLegpercentminus+RightLegdestroyed, ColoredRightLegpercent+RightLegpercent, RightLegpercent, HPConHUDAlpha)
						surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_leg_right.png", "tarkovMaterial"))
						surface.DrawTexturedRect(swhc+30, shhc+114, 48, 129)

					end
				else
					Healthconpercent = math.Clamp(Health / MaxHealth*155, 0, 155)
					ColoredHealthpercent = math.Clamp(Health / MaxHealth*155*2, 0, 155)
					ColoredHealthpercentminus = math.Clamp(155*2 - Health / MaxHealth*155*2, 0, 155)

					if Health <= 0 then
				  		destroyed = 0
				  		ColoredHealthpercentminus = 0
				  	else
				  		destroyed = 155
				  	end

				  	if Colored:GetInt() >= 1 then
						Healthconpercent = 0
						destroyed = 0
					else
						ColoredHealthpercent = 0
						ColoredHealthpercentminus = 0
					end

					surface.SetDrawColor(255, 255, 255, HPConHUDAlpha)
					surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_char_back.png", "tarkovMaterial"))
					surface.DrawTexturedRect(swhc, shhc, 148, 264)
					surface.SetDrawColor(destroyed+ColoredHealthpercentminus, Healthconpercent+ColoredHealthpercent, Healthconpercent, HPConHUDAlpha)
					surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_head.png", "tarkovMaterial"))
					surface.DrawTexturedRect(swhc+54, shhc+15, 41, 45)
					surface.SetDrawColor(destroyed+ColoredHealthpercentminus, Healthconpercent+ColoredHealthpercent, Healthconpercent, HPConHUDAlpha)
					surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_chest.png", "tarkovMaterial"))
					surface.DrawTexturedRect(swhc+43, shhc+43, 60, 64)
					surface.SetDrawColor(destroyed+ColoredHealthpercentminus, Healthconpercent+ColoredHealthpercent, Healthconpercent, HPConHUDAlpha)
					surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_belly.png", "tarkovMaterial"))
					surface.DrawTexturedRect(swhc+42, shhc+87, 56, 50)
					surface.SetDrawColor(destroyed+ColoredHealthpercentminus, Healthconpercent+ColoredHealthpercent, Healthconpercent, HPConHUDAlpha)
					surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_hand_left.png", "tarkovMaterial"))
					surface.DrawTexturedRect(swhc+82, shhc+50, 45, 98)
					surface.SetDrawColor(destroyed+ColoredHealthpercentminus, Healthconpercent+ColoredHealthpercent, Healthconpercent, HPConHUDAlpha)
					surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_hand_right.png", "tarkovMaterial"))
					surface.DrawTexturedRect(swhc+19, shhc+53, 45, 97)
					surface.SetDrawColor(destroyed+ColoredHealthpercentminus, Healthconpercent+ColoredHealthpercent, Healthconpercent, HPConHUDAlpha)
					surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_leg_left.png", "tarkovMaterial"))
					surface.DrawTexturedRect(swhc+63, shhc+79, 50, 170)
					surface.SetDrawColor(destroyed+ColoredHealthpercentminus, Healthconpercent+ColoredHealthpercent, Healthconpercent, HPConHUDAlpha)
					surface.SetMaterial(Material("Tarkov HUD/Health_condition/battle_leg_right.png", "tarkovMaterial"))
					surface.DrawTexturedRect(swhc+30, shhc+114, 48, 129)
			  	end

				surface.SetDrawColor(255, 255, 255, HPHUDAlpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/sprint_panel.png", "tarkovMaterial"))
				surface.DrawTexturedRect(swhp-1, shhp+HPbar, 156, 13)
				surface.SetDrawColor(255, 255, 255, SliderAlpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/sprint_slider.png", "tarkovMaterial"))
				surface.DrawTexturedRect(swhp+4, shhp+4+HPbar, HPbarpercent, 3)
				surface.SetDrawColor(255, 255, 255, SliderAlpha_red)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/sprint_slider_exh.png", "tarkovMaterial"))
				surface.DrawTexturedRect(swhp+4, shhp+4+HPbar, HPbarpercent, 3)

				surface.SetDrawColor(255, 255, 255, PanelAlpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/sprint_panel.png", "tarkovMaterial"))
				surface.DrawTexturedRect(swhp-1, shhp+9-AMbar, 156, 13)
				surface.SetDrawColor(255, 255, 255, HPHUDAlpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/sprint_slider_blue.png", "tarkovMaterial"))
				surface.DrawTexturedRect(swhp+4, shhp+4+9-AMbar, AMbarpercent, 3)

				--姿勢表示
				local Standing0Alpha = 0 
				local Standing1Alpha = 0 
				local Standing2Alpha = 0 
				local Standing3Alpha = 0 
				local Standing4Alpha = 0 
				local Standing5Alpha = 0 
				local CrouchingAlpha = 0
				local ProningAlpha = 0
				local noise01Alpha = 0
				local noise02Alpha = 0
				local noise03Alpha = 0
				rarrow = 0
				darrow = 0

				--屈伸animation
				if ConVarExists("prone_movespeed") then
					if ply:IsProne() then
						rarrow = 18*8
						StandingStats = math.Approach(StandingStats, 7, 7 * FrameTime() / 0.15)
					elseif ply:Crouching() then
						rarrow = 18*6
						StandingStats = math.Approach(StandingStats, 6, 6 * FrameTime() / 0.15)
					else
						StandingStats = math.Approach(StandingStats, 0, 7 * FrameTime() / 0.15)
					end
				else
					if ply:Crouching() then
						rarrow = 18*6
						StandingStats = math.Approach(StandingStats, 6, 6 * FrameTime() / 0.15)
					else
						StandingStats = math.Approach(StandingStats, 0, 6 * FrameTime() / 0.15)
					end
				end

				if StandingStats >= 7 then
			    	ProningAlpha = HPHUDAlpha
			    elseif StandingStats >= 6 then
			    	CrouchingAlpha = HPHUDAlpha
			    elseif StandingStats >= 5 then
			    	hpinputed = CurTime()
			    	Standing5Alpha = HPHUDAlpha
			    elseif StandingStats >= 4 then
			    	Standing4Alpha = HPHUDAlpha
			    elseif StandingStats >= 3 then
			    	Standing3Alpha = HPHUDAlpha
			    elseif StandingStats >= 2 then
			    	Standing2Alpha = HPHUDAlpha
			    elseif StandingStats >= 1 then
			    	hpinputed = CurTime()
			    	Standing1Alpha = HPHUDAlpha
			    elseif StandingStats >= 0 then   	
			    	Standing0Alpha = HPHUDAlpha
			    end

				if ConVarExists("finespeed_key") then
					FineSpeed.HoldTime = 0
					FineSpeed.SpeedIncrements = 18

					if ConVarExists("prone_movespeed") then
						if ply:IsProne() then
							noise02Alpha = HPHUDAlpha
						elseif ply:Crouching() then
							if FineSpeed.SpeedIncrementPos < 5 then
								noise03Alpha = HPHUDAlpha
							else
								noise02Alpha = HPHUDAlpha
							end
						else
							if FineSpeed.SpeedIncrementPos < 5 then
								noise03Alpha = HPHUDAlpha
							elseif FineSpeed.SpeedIncrementPos < 15 then
								noise02Alpha = HPHUDAlpha
							else
								noise01Alpha = HPHUDAlpha
							end
						end
					else
						if ply:Crouching() then
							if FineSpeed.SpeedIncrementPos < 5 then
								noise03Alpha = HPHUDAlpha
							else
								noise02Alpha = HPHUDAlpha
							end
						else
							if FineSpeed.SpeedIncrementPos < 5 then
								noise03Alpha = HPHUDAlpha
							elseif FineSpeed.SpeedIncrementPos < 15 then
								noise02Alpha = HPHUDAlpha
							else
								noise01Alpha = HPHUDAlpha
							end
						end
					end

					darrow = math.Clamp(FineSpeed.SpeedIncrementPos/18*154-13.8, -5, 140)
				else
					if ConVarExists("prone_movespeed") then
						if ply:IsProne() or ply:Crouching() then
							noise02Alpha = HPHUDAlpha
						else
							noise01Alpha = HPHUDAlpha
						end
					else
						if ply:Crouching() then
							noise02Alpha = HPHUDAlpha
						else
							noise01Alpha = HPHUDAlpha
						end
					end

					darrow = 154-13.8
				end

				--ADS
				local DownAlpha = 0

				if wep.Base == "arccw_base" then
					if wep:GetState() == ArcCW.STATE_SIGHTS then
						ADS = false
					end
				end
				if wep.Base == "mg_base" then
					if wep:GetIsAiming() then
						ADS = false
					end
				end
				if wep.Base == "tfa_gun_base" then
					if wep:GetIronSights() then
						ADS = false
					end
				end
				if wep.Base == "cw_base" then
					if wep:isAiming() then
						ADS = false
					end
				end
				if wep.Base == "fas2_base" then
					if wep.dt.Status == FAS_STAT_ADS then
						ADS = false
					end
				end
				if wep.Base == "bobs_gun_base" or wep.Base == "bobs_shotty_base" or wep.Base == "bobs_scoped_base" then
					if wep:GetIronsights() then
						ADS = false
					end
				end

				if ADS == false then
					DownAlpha = HPHUDAlpha/17

					if ConVarExists("finespeed_key") then
						if FineSpeed.SpeedIncrementPos > 8 then
							darrow = 55
							noise01Alpha = 0
							noise02Alpha = HPHUDAlpha
						end
					else
						darrow = 55
						noise01Alpha = 0
						noise02Alpha = HPHUDAlpha
					end
				else
					DownAlpha = HPHUDAlpha
				end

				if darrow < movedarrow then
					hpinputed = CurTime()
				elseif darrow > movedarrow then
					hpinputed = CurTime()
				end

				movedarrow = darrow

				if ply:IsSprinting() or ply:KeyDown(IN_JUMP) then
					Walkdetect = math.Approach(Walkdetect, 4, 4 * FrameTime()/0.2)
				elseif ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT) then
					Walkdetect = math.Approach(Walkdetect, 2, 4 * FrameTime()/0.2)
				else
					Walkdetect = math.Approach(Walkdetect, 0, 4 * FrameTime()/0.2)
				end

				if Walkdetect > 2 and Walkdetect < 4 then
					hpinputed = CurTime()
				elseif Walkdetect > 0 and Walkdetect < 2 then
					hpinputed = CurTime()
				end

				surface.SetDrawColor(255, 255, 255, Standing0Alpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/stand0.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-1, sh-3, 126, 166)
				surface.SetDrawColor(255, 255, 255, Standing1Alpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/stand1.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-1, sh+2, 126, 160)
				surface.SetDrawColor(255, 255, 255, Standing2Alpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/stand2.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-1, sh+6, 127, 154)
				surface.SetDrawColor(255, 255, 255, Standing3Alpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/stand3.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-1, sh+13, 127, 148)
				surface.SetDrawColor(255, 255, 255, Standing4Alpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/stand4.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-1, sh+18, 127, 143)
				surface.SetDrawColor(255, 255, 255, Standing5Alpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/stand5.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-1, sh+23, 127, 138)
				surface.SetDrawColor(255, 255, 255, CrouchingAlpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/crouch.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-1, sh+46, 127, 114)
				surface.SetDrawColor(255, 255, 255, ProningAlpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/settle.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-5, sh+102, 199, 60)

				surface.SetDrawColor(255, 255, 255, noise01Alpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/noise_01.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-30, sh+172, 16, 16)
				surface.SetDrawColor(255, 255, 255, noise02Alpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/noise_02.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-30, sh+172, 16, 16)
				surface.SetDrawColor(255, 255, 255, noise03Alpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/noise_03.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-30, sh+172, 16, 16)

				--縦軸
				local sw = sw - 26
				local sh = sh + 13

				surface.SetDrawColor(255, 255, 255, HPHUDAlpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/arrow_down_tiny.png", "tarkovMaterial"))
				surface.DrawTexturedRectRotated(sw-10, sh+1+(rarrow), 6, 5, 90)
				draw.RoundedBox(2, sw, sh, 3, 18*8+1.75, Color(255/5, 255/5, 255/5, HPHUDAlpha/2))
				draw.RoundedBox(2, sw, sh, 3, 1.75, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw, sh+18, 3, 1.75, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw, sh+18*2, 3, 1.75, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw, sh+18*3, 3, 1.75, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw, sh+18*4, 3, 1.75, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw, sh+18*5, 3, 1.75, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw, sh+18*6, 3, 1.75, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw, sh+18*8, 3, 1.75, Color(255,255,255,HPHUDAlpha))

				--横軸
				local sw = sw + 22
				local sh = sh + 167

				surface.SetDrawColor(255, 255, 255, HPHUDAlpha)
				surface.SetMaterial(Material("Tarkov HUD/Stamina_and_stance/arrow_down_tiny.png", "tarkovMaterial"))
				surface.DrawTexturedRect(sw-1+darrow, sh-11, 6, 5)
				draw.RoundedBox(2, sw, sh, 7*20+1.75+5, 3, Color(255/5, 255/5, 255/5, HPHUDAlpha/2))
				draw.RoundedBox(2, sw, sh, 1.75, 3, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw+7, sh, 1.75, 3, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw+7*2+1, sh, 1.75, 3, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw+7*3+1, sh, 1.75, 3, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw+7*4+1, sh, 1.75, 3, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw+7*5+1, sh, 1.75, 3, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw+7*6+2, sh, 1.75, 3, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw+7*7+2, sh, 1.75, 3, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw+7*8+2, sh, 1.75, 3, Color(255,255,255,HPHUDAlpha))
				draw.RoundedBox(2, sw+7*9+2, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*10+3, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*11+3, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*12+3, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*13+3, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*14+4, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*15+4, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*16+4, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*17+4, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*18+5, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*19+5, sh, 1.75, 3, Color(255,255,255,DownAlpha))
				draw.RoundedBox(2, sw+7*20+5, sh, 1.75, 3, Color(255,255,255,DownAlpha))

				if Stamina_and_stance:GetInt() <= 0 then
					hpinputed = CurTime()
				elseif Stamina_and_stance:GetInt() >= 2 then
					hpinputed = 0
				end

				if HP_Condition:GetInt() <= 0 then
					hpconinputed = CurTime()
				elseif HP_Condition:GetInt() >= 2 then
					hpconinputed = 0
				end

				-- Health Condition
			    if hpconinputed + 3 < CurTime() then
					HealthconshouldTrue = false
			    end

			    if HealthconshouldTrue == true then
					HPConHUDAlpha = math.Approach(HPConHUDAlpha, 255, 255 * FrameTime() / 0.25)
			    else
					HPConHUDAlpha = math.Approach(HPConHUDAlpha, 0, 255 * FrameTime() / 0.25)
			    end

			    -- Stamina and Stance
			    if hpinputed + 3 < CurTime() then
					HealthshouldTrue = false
			    end

			    if HealthshouldTrue == true then
					HPHUDAlpha = math.Approach(HPHUDAlpha, 255, 255 * FrameTime() / 0.25)
			    else
					HPHUDAlpha = math.Approach(HPHUDAlpha, 0, 255 * FrameTime() / 0.25)
			    end

			    --カーソル
			    if InteractHUD:GetInt() >= 1 then

				    local sw = ScrW()/2
				    local sh = ScrH()/2
				    local CursorY = 0
					local HandAlpha = 255 - CURSORHUDAlpha
					local PointAlpha = 255 - CURSORHUDAlpha
					local InteractAlpha = 0
					local InteractDoorAlpha = 0
					local Interact = "TAKE"
					local Pointer = 0
					local NameAlpha = 0
					local PressedshouldTrue = true
					local tr = util.TraceLine({
						start = ply:GetShootPos(),
						endpos = ply:GetShootPos() + ply:EyeAngles():Forward() * 100,
						filter = ply
					})
					local Ent = tr.Entity

					if ADS == false then
						CursorY = 200
					end

					if !(Ent:IsNPC()) and !(Ent:IsPlayer()) and IsValid(Ent) then
						local EntityName = string.upper(language.GetPhrase(Ent:GetClass()))
						surface.SetFont("tarkovFont_interact")
						local EntityBox = surface.GetTextSize(EntityName)+10
						local DetectEntity = 0
						
						if Ent:IsWeapon() then
							EntityName = string.upper(language.GetPhrase(Ent:GetPrintName()))
							EntityBox = surface.GetTextSize(EntityName)+10
							CursoR = 1
							DetectEntity = 1
							PointAlpha = 0
							Pointer = 1

						elseif string.find(Ent:GetClass(), "item_") or
							string.find(Ent:GetClass(), "ojs_") or 
							string.find(Ent:GetClass(), "ammo") or 
							string.find(Ent:GetClass(), "att") or 
							string.find(Ent:GetClass(), "arc") or 
							string.find(Ent:GetClass(), "vest") or 
							string.find(Ent:GetClass(), "helmet") then
							CursoR = 1
							DetectEntity = 1
							PointAlpha = 0
							Pointer = 1

						elseif Ent:GetClass() == "prop_door_rotating" then
							CursoR = 2
							DetectEntity = 3

							if InteractDoor:GetInt() >= 1 then
								InteractDoorAlpha = 255
							end

						elseif Ent:GetClass() == "class C_BaseEntity" then
							CursoR = 2
							DetectEntity = 2
							Interact = "PRESS THE BUTTON"
					    else
							if CursoR == 2 then
								PointAlpha = 0
							else
								HandAlpha = 0
							end
						end

						if Ent:GetClass() == "item_healthcharger" or Ent:GetClass() == "item_suitcharger" then
							CursoR = 2
							DetectEntity = 2
							Interact = "CHARGE"
							Pointer = 0
						end

						if EntityName == "AMMO CRATE" then
							CursoR = 2
							DetectEntity = 2
							Interact = "SEARCH"
							Pointer = 0
						end

						if ply:KeyDown(IN_USE) then
							pressinputed = CurTime()
						end
						if pressinputed + 1 < CurTime() then
							PressedshouldTrue = false
					    end

						if PressedshouldTrue == true then
							if DetectEntity >= 1 then
								InteractDoorAlpha = 0
								if Pointer == 1 then
									DetectEntity = 3
						    		HandAlpha = 0
						    		PointAlpha = 255
						    	else
						    		DetectEntity = 0
						    		PointAlpha = 0
						    	end
						    end
					    end

						if DetectEntity == 1 then
							CursorshouldTrue = false
							InteractAlpha = 255
							NameAlpha = 255
						elseif DetectEntity == 2 then
							CursorshouldTrue = false
							InteractAlpha = 255
						elseif DetectEntity == 3 then
							CursorshouldTrue = false
						end

						draw.RoundedBox(1, sw-EntityBox/2-1, sh+31+CursorY, EntityBox, 13, Color(0, 0, 0, NameAlpha))
						draw.SimpleText(EntityName, "tarkovFont_interact", sw-1, sh+31+CursorY, Color(220, 220, 220, NameAlpha), TEXT_ALIGN_CENTER)
						--draw.SimpleText(Ent:GetClass(), "tarkovFont", sw-500, sh, color_white)
					else
						if CursoR == 2 then
							PointAlpha = 0
						else
							HandAlpha = 0
						end
					end

					if CursorshouldTrue == true then
						CURSORHUDAlpha = math.Approach(CURSORHUDAlpha, 255, 255 * FrameTime() / 0.5)
				    else
						CURSORHUDAlpha = math.Approach(CURSORHUDAlpha, 0, 255 * FrameTime() / 0.25)
				    end

				    surface.SetFont("tarkovFont_interact")
					local InteractBox = surface.GetTextSize(Interact)+16

					surface.SetDrawColor(255, 255, 255, PointAlpha)
					surface.SetMaterial(Material("Tarkov HUD/icons/cursor_point.png", "tarkovMaterial"))
					surface.DrawTexturedRect(sw-4.5, sh-4.5+CursorY, 9, 9)
					surface.SetDrawColor(255, 255, 255, HandAlpha)
					surface.SetMaterial(Material("Tarkov HUD/icons/cursor_hand.png", "tarkovMaterial"))
					surface.DrawTexturedRect(sw-20, sh-18+CursorY, 38, 38)
					draw.RoundedBox(1, sw-InteractBox/2-1, sh-40+CursorY, InteractBox, 19, Color(0, 0, 0, InteractAlpha))
					draw.RoundedBox(1, sw-InteractBox/2+3-1, sh-37+CursorY, InteractBox-6, 13, Color(131, 131, 131, InteractAlpha))
					draw.SimpleText(Interact, "tarkovFont_interact", sw-1, sh-37+CursorY, Color(0, 0, 0, InteractAlpha), TEXT_ALIGN_CENTER)
					draw.RoundedBox(1, sw-46, sh-70+CursorY, 91, 79, Color(0, 0, 0, InteractDoorAlpha))
					draw.RoundedBox(1, sw-43, sh-67+CursorY, 85, 13, Color(132, 130, 131, InteractDoorAlpha))
					draw.SimpleText("OPEN DOOR", "tarkovFont_interact", sw-1, sh-67+CursorY, Color(0, 0, 0, InteractDoorAlpha), TEXT_ALIGN_CENTER)
					--draw.SimpleText("BREACH", "tarkovFont_interact", sw-1, sh-52+CursorY, Color(97, 97, 97, InteractDoorAlpha), TEXT_ALIGN_CENTER)
					draw.SimpleText("BREACH", "tarkovFont_interact", sw-1, sh-52+CursorY, Color(45, 45, 45, InteractDoorAlpha), TEXT_ALIGN_CENTER)
					draw.SimpleText("BANG & CLEAR", "tarkovFont_interact", sw-1, sh-37+CursorY, Color(45, 45, 45, InteractDoorAlpha), TEXT_ALIGN_CENTER)
					draw.SimpleText("FLASH & CLEAR", "tarkovFont_interact", sw-1, sh-22+CursorY, Color(45, 45, 45, InteractDoorAlpha), TEXT_ALIGN_CENTER)
					draw.SimpleText("MOVE IN", "tarkovFont_interact", sw-1, sh-6+CursorY, Color(45, 45, 45, InteractDoorAlpha), TEXT_ALIGN_CENTER)
				end

			    --通知
			    if Notification:GetInt() >= 1 then

				    local sw = ScrW()-500
				    local sh = ScrH()-30
				    NoticeAlpha_Green = 0
				    NoticeAlpha_Red = 0

				    hook.Add("HUDWeaponPickedUp", "EscapeFromTarkov_HUDWeaponPickedUp", function(weapon)
						surface.PlaySound("notification_exp.wav")
						shn = 30
						NoticeAlpha = 0
						noticecolor = 1
						noticeinputed = CurTime()
						item = "Looting Experience - " .. language.GetPhrase(weapon:GetPrintName())

					end)

				    hook.Add("HUDItemPickedUp", "EscapeFromTarkov_HUDItemPickedUp", function(itemName)
						surface.PlaySound("notification_exp.wav")
						shn = 30
						NoticeAlpha = 0
						noticecolor = 1
						noticeinputed = CurTime()
						item = "Looting Experience - " .. language.GetPhrase(itemName)
					end)

					hook.Add("HUDAmmoPickedUp", "EscapeFromTarkov_HUDAmmoPickedUp", function(itemName, amount)
						surface.PlaySound("notification_exp.wav")
						shn = 30
						NoticeAlpha = 0
						noticecolor = 1
						noticeinputed = CurTime()
						if itemName == "AR2" then
							itemName = "Pulse Ammo"
						elseif itemName == "AR2AltFire" then
							itemName = "Energy Ball"
						elseif itemName == "Pistol" then
							itemName = "Pistol Ammo"
						elseif itemName == "SMG1" then
							itemName = "SMG Ammo"
						elseif itemName == "357" then
							itemName = "Magnum Ammo"
						elseif itemName == "Buckshot" then
							itemName = "Shotgun Ammo"
						elseif itemName == "RPG_Round" then
							itemName = "RPG Round"
						elseif itemName == "XBowBolt" then
							itemName = "Crossbow Bolt"
						elseif itemName == "SMG1_Grenade" then
							itemName = "40mm"
						elseif itemName == "SniperPenetratedRound" then
							itemName = "Sniper Ammo"
						end
						item = "Looting Experience - " .. language.GetPhrase(itemName) .. " (" .. amount .. ")"
					end)

					if wep.Base == "arccw_base" then
						if wep:GetMalfunctionJam() then
							fixvalue = math.Approach(fixvalue, 1, 1 * FrameTime())
						else
							fixvalue = 0
						end
					end

					if fixvalue > 0. and fixvalue < 0.01 then
						surface.PlaySound("notification_exp.wav")
						shn = 30
						noticecolor = 0
						NoticeAlpha = 0
						noticeinputed = CurTime()
						item = "Fix malfunction +reload"
					end

					if noticecolor == 1 then
						NoticeAlpha_Green = NoticeAlpha
						NoticeAlpha_Red = 0
					else
						NoticeAlpha_Green = 0
						NoticeAlpha_Red = NoticeAlpha
					end

					if noticeinputed + 3 < CurTime() then
						NoticeshouldTrue = false
				    end

				    if NoticeshouldTrue == true then
				    	shn = math.Approach(shn, 0, 30 * FrameTime() / 0.25)
				    	NoticeAlpha = math.Approach(NoticeAlpha, 205, 205 * FrameTime() / 0.4)
				    else
				    	shn = math.Approach(shn, 30, 30 * FrameTime() / 0.25)
				    	NoticeAlpha = math.Approach(NoticeAlpha, 0, 205 * FrameTime() / 0.15)
				    end

				    deathinputed = CurTime()

					draw.RoundedBox(2, sw, sh+shn, 500, 26, Color(0, 0, 0, 235))
					surface.SetDrawColor(255, 255, 255, NoticeAlpha_Green)
					surface.SetMaterial(Material("Tarkov HUD/icons/notification_icon_alert.png", "tarkovMaterial"))
					surface.DrawTexturedRect(sw+3, sh-1+shn, 30, 29)
					surface.SetDrawColor(255, 255, 255, NoticeAlpha_Red)
					surface.SetMaterial(Material("Tarkov HUD/icons/notification_icon_alert_red.png", "tarkovMaterial"))
					surface.DrawTexturedRect(sw+3, sh-1+shn, 30, 29)
					draw.SimpleText(item, "tarkovFont_notification", sw+35, sh+3+shn, Color(220, 220, 220, 255), TEXT_ALIGN_LEFT)
				end
			else

				AddAlpha = 1
				if BluronDamage:GetInt() >= 1 then
					Passes = 8
				else
					Passes = 0
				end

				net.Receive("plyDead", function()
					local ply = net.ReadEntity()
					brightvalue = 0
				end)

				net.Receive("plySpawned", function()
					local ply = net.ReadEntity()
					NearDeathAlpha = 0
					deathvalue = 0
					deathscreen = 1000
				end)

				if deathinputed + 1.75 < CurTime() then
					Passes = 0
				end
				if deathinputed + 2 < CurTime() then
					brightvalue = math.Approach(brightvalue, -1, 1 * FrameTime() / 0.4)
					deathscreen = math.Approach(deathscreen, -50, 1000 * FrameTime() / 0.4)
				else
					brightvalue = math.Approach(brightvalue, -0.1, 0.1 * FrameTime() / 2)
			    end

				surface.SetDrawColor(255, 0, 0, NearDeathAlpha)
				surface.SetMaterial(Material("Tarkov HUD/deathscreen/neardeath.png", "tarkovMaterial"))
				surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(Material("Tarkov HUD/deathscreen/deathscreen_u.png", "tarkovMaterial"))
				surface.DrawTexturedRect(-96, deathscreen, ScrW()*1.1, ScrH()*1.1)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(Material("Tarkov HUD/deathscreen/deathscreen_d.png", "tarkovMaterial"))
				surface.DrawTexturedRect(-96, (-deathscreen-80), ScrW()*1.1, ScrH()*1.1)
				
				local bright = {
					["$pp_colour_addr"] = 0,
					["$pp_colour_addg"] = 0,
					["$pp_colour_addb"] = 0,
					["$pp_colour_brightness"] = brightvalue,
					["$pp_colour_colour"] = 1,
					["$pp_colour_contrast"] = 1,
					["$pp_colour_mulr"] = 0,
					["$pp_colour_mulg"] = 0,
					["$pp_colour_mulb"] = 0
				}
				DrawColorModify(bright)

			end

			--弾薬表示
			if IsValid(ply) and IsValid(wep) then

				CountAlpha = 255 - AMMOHUDAlpha
				AmmoAlpha = 255 - AMMOHUDAlpha
				SAmmoAlpha = SAMMOHUDAlpha - AMMOHUDAlpha

				local sw = ScrW()-95
				local sh = ScrH()-119
				local xac = 0
				local swac = 0
				local xsa = 0
				local swsa = 0
				local AmmoshouldTrue = true
				local SAmmoshouldTrue = true
				local FMshouldTrue = true
				mag = wep:Clip1()
				Maxmag = wep:GetMaxClip1()
				ammoname = game.GetAmmoName(wep:GetPrimaryAmmoType())
				pammot = wep:GetPrimaryAmmoType()
				pammo = ply:GetAmmoCount(wep:GetPrimaryAmmoType())
				sammo = ply:GetAmmoCount(wep:GetSecondaryAmmoType())
				magicon = -200

				if wep:GetPrimaryAmmoType() > 0 then

					if mag <= 0 then
						Ammo = "Empty"
						xac = 118
						swac = 128
					elseif mag <= Maxmag / 5 then
						Ammo = "Almost empty"
						xac = 231
						swac = 241
					elseif mag <= Maxmag / 2  then
						Ammo = "Less than half"
						xac = 240
						swac = 250
					elseif mag <= Maxmag / 1.25  then
						Ammo = "About half"
						xac = 180
						swac = 190
					elseif mag <= Maxmag - 1  then
						Ammo = "Nearly full"
						xac = 175
						swac = 185
					else
						Ammo = "Full"
						xac = 70
						swac = 80
					end

					if mag == -1 and wep:Clip2() == -1 or mag == 100 and wep:Clip2() == 100 then
						if pammo < 10 then
							xac = 38
							swac = 48
						elseif pammo < 100 then
							xac = 58
							swac = 68
						elseif pammo < 1000 then
							xac = 78
							swac = 88
						else
							pammo = 999
							xac = 78
							swac = 88
						end
						Ammo = pammo
					end

					if wep:GetSecondaryAmmoType() != -1 then
						if wep:GetSecondaryAmmoType() == 7 then
							sammo = wep:Clip2()
						end

						if sammo > 0 then
							sammoinputed = CurTime()
						end
						if sammo < 10 then
							xsa = 38
							swsa = 48
						elseif sammo < 100 then
							xsa = 58
							swsa = 68
						else
							sammo = 99
							xsa = 58
							swsa = 68
						end
					else
						sammo = ""
					end

					--ファイヤモード
					local defwep = language.GetPhrase(wep:GetPrintName())

					if wep.Base == "arccw_base" then
						local ArcCWFM = wep:GetFiremodeName()

						if ArcCWFM == "Automatic" then
							FMvalue = 1
						elseif string.find(ArcCWFM, "burst") then
							FMvalue = 2
						elseif ArcCWFM == "Safety" then
							FMvalue = 4
						else
							FMvalue = 3
						end
					end
					if wep.Base == "mg_base" then
						local MWFM = wep.Firemodes[wep:GetFiremode()].Name

						if (!wep:GetSafety()) then
							if MWFM == "Full Auto" then
								FMvalue = 1
							elseif string.find(MWFM, "Burst") then
								FMvalue = 2
							elseif string.find(MWFM, "Semi") then
								FMvalue = 3
							end
						else
							FMvalue = 4
						end						
					end
					if wep.Base == "tfa_gun_base" then
						local TFAFM = wep:GetFireModeName()

						if TFAFM == "Full-Auto" then
							FMvalue = 1
						elseif TFAFM == "3 Round Burst" then
							FMvalue = 2
						elseif TFAFM == "Semi-Auto" or TFAFM == "Pump-Action" then
							FMvalue = 3
						end
					end
					if wep.Base == "cw_base" then
						local CWFM = wep.FireMode
						
						if CWFM == "auto" then
							FMvalue = 1
						elseif CWFM == "3burst" or CWFM == "2burst" then
							FMvalue = 2
						elseif CWFM == "semi" or CWFM == "double" or CWFM == "bolt" or CWFM == "pump" then
							FMvalue = 3
						elseif CWFM == "safe" then
							FMvalue = 4
						end
					end
					if wep.Base == "fas2_base" then
						local FASFM = wep.FireMode

						if FASFM == "auto" then
							FMvalue = 1
						elseif FASFM == "3burst" or FASFM == "2burst" then
							FMvalue = 2
						elseif FASFM == "safe" then
							FMvalue = 4
						else
							FMvalue = 3
						end
					end
					if wep.Base == "bobs_gun_base" or wep.Base == "bobs_shotty_base" or wep.Base == "bobs_scoped_base" then
						if wep.Primary.Automatic then
							FMvalue = 1
						else
							FMvalue = 3
						end
					end
					if defwep == "PULSE-RIFLE" or defwep == "SMG" then
						FMvalue = 1
					elseif defwep == "9MM PISTOL" or defwep == ".357 MAGNUM" or defwep == "SHOTGUN" or defwep == "CROSSBOW" or defwep == "RPG" then
						FMvalue = 3
					elseif defwep == "GRENADE" then
						FMvalue = 0
					end

					if FMvalue == 1 then
						FM = "Full Auto"
						xfm = 155
						swfm = 165
					elseif FMvalue == 2 then
						FM = "Burst Fire"
						xfm = 180
						swfm = 190
					elseif FMvalue == 3 then
						FM = "Single Fire"
						xfm = 182
						swfm = 192
					elseif FMvalue == 4 then
						FM = "Safety"
						xfm = 120
						swfm = 130
						--[[
						FM = "Safe"
						xfm = 88
						swfm = 98
						]]
					else
						FM = ""
						xfm = 0
						swfm = 0
					end

					-- Firemode
					if DontCheck:GetInt() <= 0 then
						if FMUseSecondkey:GetInt() >= 1 then
							if ply:KeyDown(IN_USE) and ply:KeyDown(IN_RELOAD) or (input.IsKeyDown(FMCheck:GetInt()) and input.IsKeyDown(SecondFMCheck:GetInt())) and FMCheckDelay == 0 then
								fminputed = CurTime()
								ammoinputed = CurTime()
							end
						else
							if ply:KeyDown(IN_USE) and ply:KeyDown(IN_RELOAD) or input.IsKeyDown(FMCheck:GetInt()) and FMCheckDelay == 0 then
								fminputed = CurTime()
								ammoinputed = CurTime()
							end
						end
					else
						if ply:KeyDown(IN_USE) and ply:KeyDown(IN_RELOAD) then
							fminputed = CurTime()
							ammoinputed = CurTime()
						end
					end

					if fminputed + 3 < CurTime() then
						FMshouldTrue = false
					end

					if FMshouldTrue == true then
						FiremodeAlpha = math.Approach(FiremodeAlpha, 255, 255 * FrameTime() / 0.25)
				    else
				        FiremodeAlpha = math.Approach(FiremodeAlpha, 0, 255 * FrameTime() / 0.25)
					end

					if FiremodeAlpha != 0 then
				    	FMCheckDelay = 1
				    else
				    	FMCheckDelay = 0
				    end

					-- Ammo
					if AmmoUseSecondKey:GetInt() >= 1 then
						if input.IsKeyDown(AmmoCheck:GetInt()) and input.IsKeyDown(SecondAmmoCheck:GetInt()) and AMMOCheckDelay == 0 then
							ammoinputed = CurTime()
						end
					else
						if input.IsKeyDown(AmmoCheck:GetInt()) and AMMOCheckDelay == 0 then
							ammoinputed = CurTime()
						end
					end

					if ammoinputed + 3 < CurTime() then
				        AmmoshouldTrue = false
				    end

				    if AmmoshouldTrue == true then
				        AMMOHUDAlpha = math.Approach(AMMOHUDAlpha, 0, 255 * FrameTime() / 0.25)
				    else
				        AMMOHUDAlpha = math.Approach(AMMOHUDAlpha, 255, 255 * FrameTime() / 0.25)
				    end

				    -- Secondary Ammo
				    if sammoinputed + 3 < CurTime() then
				        SAmmoshouldTrue = false
				    end

				    if SAmmoshouldTrue == true then
				        SAMMOHUDAlpha = math.Approach(SAMMOHUDAlpha, 255, 255 * FrameTime() / 0.25)
				    else
				        SAMMOHUDAlpha = math.Approach(SAMMOHUDAlpha, 0, 255 * FrameTime() / 0.25)
				    end

				    if FiremodeAlpha != 0 then
						Ammo = FM
						xac = xfm
						swac = swfm
						AmmoAlpha = 0
						SAmmoAlpha = 0
					else
						xfm = xac
						swfm = swac
						AmmoAlpha = 255 - AMMOHUDAlpha
						SAmmoAlpha = SAMMOHUDAlpha - AMMOHUDAlpha
					end

				    if AMMOHUDAlpha != 255 then
				    	AMMOCheckDelay = 1
				    else
				    	AMMOCheckDelay = 0
				    end

				    if pammot == 1 then
						ammoname = "Pulse Ammo"
						magicon = 122
					elseif pammot == 3 then
						ammoname = "Pistol Ammo"
						magicon = 124
					elseif pammot == 4 then
						ammoname = "SMG Ammo"
						magicon = 107
					elseif pammot == 5 then
						ammoname = "Magnum Ammo"
						magicon = 173
					elseif pammot == 6 then
						ammoname = "Crossbow Bolt"
						magicon = 158
					elseif pammot == 7 then
						ammoname = "Shotgun Ammo"
						magicon = 169
					elseif pammot == 8 then
						ammoname = "RPG Round"
						magicon = 103
					elseif pammot == 9 then
						ammoname = "40mm"
						magicon = 28
					elseif pammot == 10 then
						ammoname = "Grenade"
						magicon = 64
					elseif pammot == 14 then
						ammoname = "Sniper Ammo"
						magicon = 139
					end

					draw.RoundedBox(2, sw-xac+3, sh+2, swac, 38, Color(0, 0, 0, CountAlpha/3))
					draw.SimpleText(Ammo, "tarkovFont", sw, sh, Color(255, 255, 255, CountAlpha), TEXT_ALIGN_RIGHT)
					draw.RoundedBox(2, sw-xsa+3, sh+2-42, swsa, 38, Color(0, 0, 0, SAmmoAlpha/3))
					draw.SimpleText(sammo, "tarkovFont", sw, sh-42, Color(255, 255, 255, SAmmoAlpha), TEXT_ALIGN_RIGHT)

					local sw = ScrW()-197
					local sh = ScrH()-80

					-- Debug
					--[[
					draw.SimpleText(wep:Clip1(), "tarkovFont", sw, sh-140, color_white)
					draw.SimpleText(surface.GetTextSize(ammoname), "tarkovFont", sw, sh-110, color_white)
					draw.SimpleText(ply:GetAmmoCount(wep:GetPrimaryAmmoType()), "tarkovFont", sw, sh-80, color_white)
					]]

					surface.SetDrawColor(255, 255, 255, AmmoAlpha)
					surface.SetMaterial(Material("Tarkov HUD/icons/icon_info_magsize.png", "tarkovMaterial"))
					surface.DrawTexturedRect(sw-surface.GetTextSize(ammoname)+72, sh+10, 19, 20)
					draw.SimpleText(ammoname, "tarkovFont", sw+97, sh, Color(220, 220, 220, AmmoAlpha), TEXT_ALIGN_RIGHT)

				end
			end



		end
	end)

	hook.Add("PopulateToolMenu", "EscapeFromTarkov_HUDOption", function()
		spawnmenu.AddToolMenuOption("Options", "EFT HUD", "EscapeFromTarkov_HUDOption_Client", "Options", "", "", function(panel)
			panel:SetName("Escape From Tarkov HUD")

			panel:AddControl("Checkbox", {
				Label = "Enabled HUD",
				Command = "tarkovhud_enabled"
			})

			panel:ControlHelp("")
			panel:AddControl("Header", {
				Description = "- Experimental"
			})
			panel:AddControl("Checkbox", {
				Label = "Notification",
				Command = "tarkovhud_notification"
			})
			panel:AddControl("Checkbox", {
				Label = "Healing Notification",
				Command = "tarkovhud_notification_heal"
			})
			panel:AddControl("Checkbox", {
				Label = "Interactive HUD",
				Command = "tarkovhud_interact"
			})
			panel:AddControl("Checkbox", {
				Label = "Interactive Door HUD",
				Command = "tarkovhud_interact_door"
			})

			panel:ControlHelp("")
			panel:AddControl("Header", {
				Description = "- Performance"
			})
			panel:AddControl("Checkbox", {
				Label = "Blur on NearDeath Screen",
				Command = "tarkovhud_blur_neardeath"
			})

			panel:AddControl("Checkbox", {
				Label = "Blur on Damaged or Death",
				Command = "tarkovhud_blur"
			})
			panel:ControlHelp("")

			panel:AddControl("Header", {
				Description = "- Game"
			})

			local combobox, label = panel:ComboBox("Stamina and stance", "tarkovhud_autohide_stamina")
			combobox:AddChoice("Always shown", 0)
			combobox:AddChoice("Autohide", 1)
			combobox:AddChoice("Always hidden", 2)

			local combobox, label = panel:ComboBox("Health condition", "tarkovhud_autohide_hp")
			combobox:AddChoice("Always shown", 0)
			combobox:AddChoice("Autohide", 1)
			combobox:AddChoice("Always hidden", 2)

			local combobox, label = panel:ComboBox("Health color scheme", "tarkovhud_hp_colored")
			combobox:AddChoice("Monochrome", 0)
			combobox:AddChoice("Colored", 1)

			panel:ControlHelp("")
			panel:AddControl("Header", {
				Description = "- Bind"
			})
			panel:AddControl("Numpad", {
				Label = "                                    Check",
				Label2 = "Ammo                                    ",
				Command = "tarkovhud_ammocheck",
				Command2 = "tarkovhud_ammocheck2nd",
			})
			panel:AddControl("Checkbox", {
				Label = "Use the second key",
				Command = "tarkovhud_ammocheck_use2ndkey",
			})

			panel:ControlHelp("")
			panel:AddControl("Numpad", {
				Label = "                                Check",
				Label2 = "Firemode                                  ",
				Command = "tarkovhud_fmcheck",
				Command2 = "tarkovhud_fmcheck2nd",
			})
			panel:AddControl("Checkbox", {
				Label = "Don't check firemode using key",
				Command = "tarkovhud_dontfmcheck",
			})
			panel:AddControl("Checkbox", {
				Label = "Use the second key",
				Command = "tarkovhud_fmcheck_use2ndkey",
			})
			panel:ControlHelp("")

		end)
	end)
end