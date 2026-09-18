ENT.Type 			= "anim"
ENT.Base 			= "base_gmodentity"
ENT.PrintName		= "C4"
ENT.Author			= "Hoff"

ENT.Spawnable			= false
ENT.AdminSpawnable		= false

if SERVER then
    local C4ConVars = {
        { "C4_Infinite", 0, "Should C4 be infinite? 1 = infinite" },
        { "C4_ThrowSpeed", 1, "How long is the delay between C4 throws?" },
        { "C4_Magnitude", 175, "How strong is the C4 explosion?" },
        { "C4_KnockDoors", 0, "Should C4 knock down doors?" },
        { "C4_DoorKnockStrength", 500, "How hard should the door be blasted?" },
        { "C4_DoorSearchRadius", 75, "How far away should doors be effected?" }
    }
    for _, C4ConVar in ipairs(C4ConVars) do
        if !ConVarExists(C4ConVar[1]) then
            CreateConVar(C4ConVar[1], C4ConVar[2], { FCVAR_REPLICATED, FCVAR_ARCHIVE }, C4ConVar[3])
        end
    end

    util.AddNetworkString("C4_Convars_Change")

    net.Receive("C4_Convars_Change", function(len, ply)
        if !IsValid(ply) or !ply:IsAdmin() then
            return
        end
        local cvar_name = net.ReadString()
        local cvar_val = net.ReadFloat()
        local AllowedConVars = {
            C4_Infinite = true,
            C4_ThrowSpeed = true,
            C4_Magnitude = true,
            C4_KnockDoors = true,
            C4_DoorKnockStrength = true,
            C4_DoorSearchRadius = true
        }
        if AllowedConVars[cvar_name] then
            RunConsoleCommand(cvar_name, tostring(cvar_val))
        end
    end)

elseif CLIENT then
    if !ConVarExists("C4_RedLight") then
        CreateClientConVar("C4_RedLight", 1, true)
    end

    local function funcCallback(CVar, PreviousValue, NewValue)
        net.Start("C4_Convars_Change", true)
        net.WriteString(CVar)
        net.WriteFloat(tonumber(NewValue) or 0)
        net.SendToServer()
    end
    cvars.AddChangeCallback("C4_Infinite", funcCallback)
    cvars.AddChangeCallback("C4_ThrowSpeed", funcCallback)
    cvars.AddChangeCallback("C4_Magnitude", funcCallback)
    cvars.AddChangeCallback("C4_KnockDoors", funcCallback)
    cvars.AddChangeCallback("C4_DoorKnockStrength", funcCallback)
    cvars.AddChangeCallback("C4_DoorSearchRadius", funcCallback)

    hook.Add("PopulateToolMenu", "AddC4SettingsPanel", function()
        spawnmenu.AddToolMenuOption("Utilities", "Hoff's Addons", "C4SettingsPanel", "C4 Setup", "", "", function(cpanel)

            if !game.SinglePlayer() and !LocalPlayer():IsAdmin() then
                cpanel:CheckBox("C4 Red Light", "C4_RedLight")
                return
            end

            cpanel:CheckBox("Infinite C4", "C4_Infinite")
            cpanel:NumSlider("C4 Magnitude", "C4_Magnitude", 1, 500, 0)
            cpanel:NumSlider("C4 Throw Speed", "C4_ThrowSpeed", 0.1, 10, 2)
            cpanel:CheckBox("Knock Down Doors", "C4_KnockDoors")
            cpanel:NumSlider("Door Knock Strength", "C4_DoorKnockStrength", 100, 2500, 0)
            cpanel:NumSlider("Door Search Radius", "C4_DoorSearchRadius", 1, 500, 0)
            cpanel:CheckBox("C4 Red Light", "C4_RedLight")
        end)
    end)
end
