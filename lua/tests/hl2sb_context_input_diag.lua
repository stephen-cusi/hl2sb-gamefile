-- Optional observations only; no panel handlers or input results are replaced.
if SERVER then return end

local id = "HL2SBContextInputDiagnostic"
local expires = RealTime() + 90
local previous, lastFrame, stalls = nil, SysTime(), 0

local function log(text)
    print("[ContextInput] " .. text)
end

local function describe(panel)
    if !IsValid(panel) then return "none" end
    local x, y = panel:LocalToScreen(0, 0)
    return string.format("%s bounds=%d,%d,%d,%d visible=%s mouse=%s keyboard=%s world=%s",
        tostring(panel), x, y, panel:GetWide(), panel:GetTall(), tostring(panel:IsVisible()),
        tostring(panel:IsMouseInputEnabled()), tostring(panel:IsKeyboardInputEnabled()), tostring(panel:IsWorldClicker()))
end

local function snapshot()
    log("menu " .. describe(g_ContextMenu))
    if IsValid(g_ContextMenu) then
        log("widgets " .. describe(g_ContextMenu.DesktopWidgets))
        if IsValid(g_ContextMenu.DesktopWidgets) then
            for _, panel in ipairs(g_ContextMenu.DesktopWidgets:GetChildren()) do log("widget " .. describe(panel)) end
        end
    end
    if menubar then log("menubar " .. describe(menubar.Control)) end
    log("native capture=" .. tostring(render.Capture))
    local files = file.Find("materials/spawnicons/hl2sb_cache/*.png", "GAME")
    log("persistent icons=" .. #files)
end

hook.Add("ContextMenuOpened", id, function() timer.Simple(0, snapshot) end)
hook.Add("VGUIMousePressAllowed", id, function(code)
    if !IsValid(g_ContextMenu) or !g_ContextMenu:IsVisible() then return end
    local x, y = input.GetCursorPos()
    log(string.format("native press=%s cursor=%d,%d target=%s", tostring(code), x, y, describe(vgui.GetHoveredPanel())))
end)
hook.Add("GUIMousePressed", id, function(code, direction)
    if !IsValid(g_ContextMenu) or !g_ContextMenu:IsVisible() then return end
    log("world dispatch=" .. tostring(code) .. " direction=" .. tostring(direction))
end)
hook.Add("SpawniconGenerated", id, function(model, path)
    log("icon generated " .. tostring(model) .. " -> " .. tostring(path))
end)
hook.Add("Think", id, function()
    local now = SysTime()
    local elapsed = now - lastFrame
    lastFrame = now
    if RealTime() >= expires then
        for _, event in ipairs({"ContextMenuOpened", "VGUIMousePressAllowed", "GUIMousePressed", "SpawniconGenerated", "Think"}) do
            hook.Remove(event, id)
        end
        log("stopped")
        return
    end
    if !IsValid(g_ContextMenu) or !g_ContextMenu:IsVisible() then return end
    if elapsed > 0.08 and stalls < 20 then stalls = stalls + 1; log(string.format("frame gap=%.1fms", elapsed * 1000)) end
    local hovered = vgui.GetHoveredPanel()
    local current = tostring(hovered)
    if current == previous then return end
    previous = current
    log("hover " .. describe(hovered))
    local ply = LocalPlayer()
    if IsValid(ply) then
        local expected = gui.ScreenToVector(input.GetCursorPos())
        log("aim=" .. tostring(ply:GetAimVector()) .. " cursor=" .. tostring(expected))
    end
end)

log("observing for 90 seconds; open C, move over an entity and right-click")
snapshot()
