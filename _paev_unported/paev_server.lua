--[[
    PAEV - Player Animation Engine
    服务器: 网络接收 + 模型白名单校验 + 每个玩家的模型持久化保存
]]

util.AddNetworkString("PAEV_SetModel")

file.CreateDir("paev")

local function GetSavePath(ply)
    return "paev/" .. ply:SteamID64() .. ".txt"
end

local function IsAllowedModel(mdl)
    for _, entry in ipairs(PAEV.PlayerModels) do
        if entry.model == mdl then return true end
    end
    return false
end

net.Receive("PAEV_SetModel", function(len, ply)
    local mdl = net.ReadString()
    if not IsValid(ply) then return end

    if not IsAllowedModel(mdl) then
        ply:ChatPrint("[PAEV] 非法模型请求已被拒绝。")
        return
    end

    ply:SetModel(mdl)
    hook.Run("PAEV_PlayerModelChanged", ply, mdl)

    file.Write(GetSavePath(ply), mdl)
end)

-- 玩家重新进服时读取上次选择的模型
hook.Add("PlayerInitialSpawn", "PAEV_LoadSavedModel", function(ply)
    local path = GetSavePath(ply)
    if file.Exists(path, "DATA") then
        local mdl = file.Read(path, "DATA")
        if mdl and IsAllowedModel(mdl) then
            ply:SetModel(mdl)
            hook.Run("PAEV_PlayerModelChanged", ply, mdl)
        end
    end
end)
