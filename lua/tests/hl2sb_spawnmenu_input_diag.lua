-- Optional client diagnostic. It observes native mouse delivery without replacing handlers.
if SERVER then return end

local id = "HL2SBSpawnmenuInputDiagnostic"
local expires = RealTime() + 90
local changes = 0
local previous

local function log(text)
    print("[SpawnmenuInput] " .. text)
end

local function describe(panel)
    if not IsValid(panel) then return "none" end
    local x, y = panel:LocalToScreen(0, 0)
    return string.format("%s mouse=%s keyboard=%s visible=%s bounds=%d,%d,%d,%d",
        tostring(panel), tostring(panel:IsMouseInputEnabled()),
        tostring(panel:IsKeyboardInputEnabled()), tostring(panel:IsVisible()),
        x, y, panel:GetWide(), panel:GetTall())
end

local function chain(panel)
    for depth = 0, 11 do
        if not IsValid(panel) then return end
        log("ancestor " .. depth .. " " .. describe(panel))
        panel = panel:GetParent()
    end
end

local function snapshot()
    if not IsValid(g_SpawnMenu) then log("SpawnMenu is not created") return end
    log("root " .. describe(g_SpawnMenu))
    log("divider " .. describe(g_SpawnMenu.HorizontalDivider))
    log("creation " .. describe(g_SpawnMenu.CreateMenu))
    log("tools " .. describe(g_SpawnMenu.ToolMenu))
    chain(g_SpawnMenu:GetParent())
end

local function stop()
    hook.Remove("Think", id)
    hook.Remove("OnSpawnMenuOpen", id)
    hook.Remove("VGUIMousePressAllowed", id)
    log("stopped")
end

hook.Add("OnSpawnMenuOpen", id, function()
    timer.Simple(0, snapshot)
end)

hook.Add("VGUIMousePressAllowed", id, function(code)
    if not IsValid(g_SpawnMenu) or not g_SpawnMenu:IsVisible() then return end
    local x, y = input.GetCursorPos()
    log(string.format("press code=%s cursor=%d,%d", tostring(code), x, y))
    chain(vgui.GetHoveredPanel())
    -- Returning nil preserves the normal hook and input dispatch.
end)

hook.Add("Think", id, function()
    if RealTime() >= expires then stop() return end
    if not IsValid(g_SpawnMenu) or not g_SpawnMenu:IsVisible() then return end
    local hovered = vgui.GetHoveredPanel()
    local current = IsValid(hovered) and tostring(hovered) or "none"
    if current == previous or changes >= 40 then return end
    previous = current
    changes = changes + 1
    log("hover " .. describe(hovered))
end)

log("observing for 90 seconds; open Q and click a tab or model")
snapshot()
