
AddCSLuaFile()
AddCSLuaFile("autorun/client/scp173_settings.lua")

RENDERGROUP_STATIC_HUGE = 0
RENDERGROUP_OPAQUE_HUGE = 1
RENDERGROUP_STATIC = 6
RENDERGROUP_OPAQUE = 7
RENDERGROUP_TRANSLUCENT = 8
RENDERGROUP_BOTH = 9
RENDERGROUP_VIEWMODEL = 10
RENDERGROUP_VIEWMODEL_TRANSLUCENT = 11
RENDERGROUP_OPAQUE_BRUSH = 12
RENDERGROUP_OTHER = 13

SCP173_ConVarDefaults = {
	["scp173_useRenderGroups"] = "1",
	["scp173_renderGroupsUpdateInterval"] = "0.5",
	["scp173_useScreenDims"] = "1",
	["scp173_screenDimsUpdateInterval"] = "0.25",
	["scp173_enableThinking"] = "1",
	["scp173_ignorePlayers"] = "0",
	["scp173_cooldownTime"] = "0.2",
	["scp173_thinkFreq"] = "45",
	["scp173_teleportMaxTries"] = "50",
	["scp173_creepProbRate"] = "2",
	["scp173_creepCooldown"] = "0.05",
	["scp173_creepSpeed"] = "300",
	["scp173_moveSpeed"] = "200",
	["scp173_stabMaxDist"] = "5",
	["scp173_stabProbRate"] = "3.5",
	["scp173_stabCooldown"] = "0.2",
	["scp173_stabForce"] = "50",
	["scp173_stabDamage"] = "500"
}

for k, v in pairs(SCP173_ConVarDefaults) do
	CreateConVar(k, v, {FCVAR_ARCHIVE, FCVAR_NOTIFY})
end

function SCP173_ResetConVars(ply, cmd, args)
	if ply:IsValid() then
		if ((not ply:IsAdmin()) and (not ply:IsUserGroup("admin")) and (not ply:IsUserGroup("superadmin"))) then return end
	end
	
	for k, v in pairs(SCP173_ConVarDefaults) do
		RunConsoleCommand(tostring(k), tostring(v))
	end
end

concommand.Add("scp173_reset", SCP173_ResetConVars)

if SERVER then
	SCP173_ScreenDimensions = {}
	
	util.AddNetworkString("scp173_screenDimensions")
	util.AddNetworkString("scp173_registerEntRenderGroup")
	
	net.Receive("scp173_registerEntRenderGroup", function(len, ply)
		local ent = net.ReadEntity()
		local renderGroup = net.ReadType()
		
		if (ent and ent:IsValid()) then
			ent.SCP173_RenderGroup = renderGroup
		end
	end)
	
	net.Receive("scp173_screenDimensions", function(len, ply)
		if ply:IsValid() then
			SCP173_ScreenDimensions[ply:EntIndex()] = net.ReadTable()
		end
	end)
	
	local function OnEntityCreated(ent)
		if (ent:IsNPC() and (ent:GetClass() != "npc_scp173")) then
			ent:AddRelationship("npc_scp173 D_FR 9999")
		end
	end
	
	hook.Add("OnEntityCreated", "SCP173_OnEntityCreated", OnEntityCreated)
end

list.Set("NPC", "npc_scp173", {
	Name = "SCP-173",
	Class = "npc_scp173",
	Model = "models/scp173_new/scp173_new.mdl",
	Health = "100",
	Category = "SCPs"
})
