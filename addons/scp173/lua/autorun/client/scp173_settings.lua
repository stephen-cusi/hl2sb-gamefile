
local PrevScreenDimsUpdate = CurTime()

function SCP173_Error(str)
	local errorTable = {}
	
	for i = 1, (#str / 511 + 1) do
		table.insert(errorTable, (#errorTable + 1), string.sub(str, ((i - 1) * 511 + 1), math.min((i * 511), #str)))
	end
	
	if (#errorTable > 0) then
		errorTable[#errorTable] = errorTable[#errorTable] .. "\n"
	end
	
	ErrorNoHalt(unpack(errorTable))
end

function SCP173_RegisterRenderGroup(ent)
	local entIsValid
	
	net.Start("scp173_registerEntRenderGroup")
	net.WriteEntity(ent)
	
	if ent:IsValid() then
		net.WriteType(ent:GetRenderGroup())
		entIsValid = true
	else
		net.WriteType(nil)
		entIsValid = false
	end
	
	net.SendToServer()
	
	return entIsValid
end

local function RegisterRenderGroupCoroutine(ent)
	if (GetConVarNumber("scp173_useRenderGroups") == 0) then return end
	
	local ent = ent
	
	while true do
		if (GetConVarNumber("scp173_useRenderGroups") == 0) then return end
		
		local entIsValid = SCP173_RegisterRenderGroup(ent)
		
		if (not entIsValid) then return end
		
		coroutine.wait(math.max(GetConVarNumber("scp173_renderGroupsUpdateInterval"), engine.TickInterval()))
	end
end

function SCP173_Think()
	if (GetConVarNumber("scp173_useRenderGroups") != 0) then
		for k, v in pairs(ents.GetAll()) do
			if ((not v.SCP173_Coroutine) or (coroutine.status(v.SCP173_Coroutine) == "dead")) then
				v.SCP173_Coroutine = coroutine.create(RegisterRenderGroupCoroutine)
			end
			
			local hadNoErrors, args = coroutine.resume(v.SCP173_Coroutine, v)
			
			if (not hadNoErrors) then
				SCP173_Error("[ERROR] " .. args)
			end
		end
	end
	
	if (GetConVarNumber("scp173_useScreenDims") != 0) then
		if ((CurTime() - PrevScreenDimsUpdate) >= GetConVarNumber("scp173_screenDimsUpdateInterval")) then
			net.Start("scp173_screenDimensions")
			net.WriteTable({x = ScrW(), y = ScrH()})
			net.SendToServer()
			
			PrevScreenDimsUpdate = CurTime()
		end
	end
end

function SCP173_Settings(panel)
	panel:Help("These are all of the settings that apply for any SCP-173 in the map.\n\n")
	panel:Help("The usage of render groups helps determine which objects block line of sight completely. This can negatively impact performance on a server.")
	panel:CheckBox("Use Render Groups", "scp173_useRenderGroups")
	panel:Help("The Render Groups Update Interval sets the interval at which entities\' render groups are sent to the server.")
	panel:NumSlider("Render Groups\nUpdate Interval", "scp173_renderGroupsUpdateInterval", 0.01, 1, 4)
	panel:Help("The usage of players\' screen dimensions helps determine whether an SCP-173 is in a player\'s field of view. This can negatively impact performance on a server.")
	panel:CheckBox("Use Screen\nDimensions", "scp173_useScreenDims")
	panel:Help("The Screen Dimensions Update Interval sets the interval at which the dimensions of each player\'s screen are sent to the server.")
	panel:NumSlider("Screen Dimensions\nUpdate Interval", "scp173_screenDimsUpdateInterval", 0, 1, 4)
	panel:CheckBox("Enable Thinking", "scp173_enableThinking")
	panel:CheckBox("Ignore Players", "scp173_ignorePlayers")
	panel:NumSlider("Cooldown\nTime", "scp173_cooldownTime", 0, 3, 3)
	panel:NumSlider("Think\nFrequency", "scp173_thinkFreq", 0, 180, 3)
	panel:NumSlider("Teleport\nMax Tries", "scp173_teleportMaxTries", 1, 100, 0)
	panel:NumSlider("Creep Probability\nRate", "scp173_creepProbRate", 0.05, 10, 3)
	panel:NumSlider("Creep\nCooldown", "scp173_creepCooldown", 0, 3, 3)
	panel:NumSlider("Creep Speed", "scp173_creepSpeed", 10, 500, 3)
	panel:NumSlider("Move Speed", "scp173_moveSpeed", 10, 500, 3)
	panel:NumSlider("Max Attack\nDistance", "scp173_stabMaxDist", 4, 40)
	panel:NumSlider("Attack Probability\nRate", "scp173_stabProbRate", 0.05, 20, 3)
	panel:NumSlider("Attack\nCooldown", "scp173_stabCooldown", 0, 3, 3)
	panel:NumSlider("Attack\nForce", "scp173_stabForce", 0, 12000, 3)
	panel:NumSlider("Attack\nDamage", "scp173_stabDamage", 0, 1000, 3)
	panel:Button("Reset All Settings", "scp173_reset")
end

function SCP173_Menu()
	spawnmenu.AddToolMenuOption("Options", "SCP-173", "SCP173_Options", "Options", "", "", SCP173_Settings)
end

hook.Add("Think", "SCP173_Think", SCP173_Think)
hook.Add("PopulateToolMenu", "SCP173_Menu", SCP173_Menu)
