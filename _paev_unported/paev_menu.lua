--[[
    PAEV - Player Animation Engine
    客户端: 玩家模型选择菜单 (Derma UI)

    打开方式:
      - 控制台指令: paev_menu
      - 聊天框输入: !models 或 !playermodel
]]

local PANEL_W, PANEL_H = 420, 520

local function OpenModelMenu()
    if IsValid(PAEV.MenuFrame) then
        PAEV.MenuFrame:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(PANEL_W, PANEL_H)
    frame:Center()
    frame:SetTitle("选择玩家模型 - Player Animation Engine")
    frame:MakePopup()
    PAEV.MenuFrame = frame

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(5, 5, 5, 5)

    local list = vgui.Create("DIconLayout", scroll)
    list:Dock(FILL)
    list:SetSpaceY(4)

    for _, entry in ipairs(PAEV.PlayerModels) do
        local btn = vgui.Create("DButton", list)
        btn:SetSize(PANEL_W - 40, 90)
        btn:SetText("")

        local icon = vgui.Create("SpawnIcon", btn)
        icon:SetSize(80, 80)
        icon:SetModel(entry.model)
        icon:SetPos(5, 5)

        local label = vgui.Create("DLabel", btn)
        label:SetPos(95, 30)
        label:SetSize(PANEL_W - 140, 30)
        label:SetText(entry.name)
        label:SetFont("DermaDefaultBold")

        btn.DoClick = function()
            net.Start("PAEV_SetModel")
            net.WriteString(entry.model)
            net.SendToServer()
            frame:Close()
        end
    end
end

concommand.Add("paev_menu", OpenModelMenu)

hook.Add("OnPlayerChat", "PAEV_ChatOpenMenu", function(ply, text)
    if ply ~= LocalPlayer() then return end
    if text == "!models" or text == "!playermodel" then
        OpenModelMenu()
        return true
    end
end)
