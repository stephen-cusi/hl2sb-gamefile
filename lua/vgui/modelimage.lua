-- ModelImage backend for the original SpawnIcon control.
-- Paint requests images; generation runs after VGUI with a bounded frame budget.
local PANEL = {}
local cache = {}
local queue, queued = {}, {}
local queueHead = 1
local targets = {}
local cacheVersion = "4"
local paintGeneration = 0
local warmQueue, warmHead = {}, 1

if (!PositionSpawnIcon) then include("includes/util/client.lua") end

local function IconSize(size)
    local result = 32
    while (result < size && result < 512) do result = result * 2 end
    return result
end

local function CacheName(model, skin, body, w, h)
    local name = "spawnicons/" .. model:lower():gsub("\\", "/"):gsub("%.mdl$", "")
    if (skin > 0) then name = name .. "_skin" .. skin end
    if (body != "000000000") then name = name .. "_" .. body end
    if (w != 64 || h != 64) then
        name = name .. (w == h && ("_" .. w) or ("_" .. w .. "x" .. h))
    end
    return name .. ".png"
end

local function IsShown(panel)
    while (IsValid(panel)) do
        if (!panel:IsVisible()) then return false end
        panel = panel:GetParent()
    end
    return true
end

local function LoadIconMaterial(path)
    local material = Material(path, "smooth")
    if (!material:IsError()) then
        -- Finish texture upload here, inside the queue's time budget.
        material:GetMappingWidth()
        surface.SetMaterial(material)
    end
    return material
end

function PANEL:Init()
    self.PendingModel = nil
    self.ModelSkin = 0
    self.ModelBody = "000000000"
end

function PANEL:SetModel(model, skin, body)
    self.ModelName = model
    self.ModelSkin = tonumber(skin) or 0
    self.ModelBody = tostring(body or "000000000")
    self.PendingModel = model
    self.ModelStamp = nil
    self.ForceRebuild = false
    self.IconOptions = nil
    self:SetMaterial(nil)
    if (!self.WarmPending) then
        self.WarmPending = true
        warmQueue[#warmQueue + 1] = self
    end
end

function PANEL:GetModel() return self.ModelName end

function PANEL:SetSpawnIcon(name)
    self.PendingModel = nil
    self:SetImage(name)
end

function PANEL:RebuildSpawnIcon()
    if (self.CacheKey) then cache[self.CacheKey] = nil end
    self.ForceRebuild = true
    self.PendingModel = self.ModelName
end

function PANEL:RebuildSpawnIconEx(options)
    self.IconOptions = options
    self:RebuildSpawnIcon()
end

function PANEL:BuildIcon(w, h, cachedOnly)
    local model = self.PendingModel
    if (!model) then return end
    w, h = IconSize(w), IconSize(h)
    local options = self.IconOptions
    local viewKey = ""
    if (istable(options)) then
        viewKey = tostring(options.cam_pos) .. tostring(options.cam_ang) .. tostring(options.cam_fov)
    end
    self.ModelStamp = self.ModelStamp or file.Time(model, "GAME") or 0
    local stamp = self.ModelStamp
    local key = cacheVersion .. "|" .. model:lower() .. "|" .. stamp .. "|" .. self.ModelSkin .. "|" .. self.ModelBody .. "|" .. w .. "x" .. h .. "|" .. viewKey
    self.CacheKey = key
    local path = "spawnicons/hl2sb_cache/" .. util.CRC(key) .. ".png"
    local entry = cache[key]
    if (queued[key]) then return end
    if (!entry && !self.ForceRebuild) then
        local existing = CacheName(model, self.ModelSkin, self.ModelBody, w, h)
        if (file.Exists("materials/" .. path, "GAME")) then
            entry = {path = path, attempts = 0, nextAttempt = 0}
        elseif (!options && file.Exists("materials/" .. existing, "GAME")) then
            entry = {path = existing, attempts = 0, nextAttempt = 0}
        end
        cache[key] = entry
    end
    if (cachedOnly && !entry) then return end
    local loadPath
    if (entry && !self.ForceRebuild) then
        if (entry.material && !entry.material:IsError()) then
            self:SetMaterial(entry.material)
            self.PendingModel = nil
            return
        end
        if (entry.attempts >= 2) then
            if (entry.generated) then
                if (!entry.reported) then ErrorNoHalt("ModelImage: failed to load " .. entry.path .. "\n"); entry.reported = true end
                self.PendingModel = nil
                return
            end
            cache[key] = nil
            self.ForceRebuild = true
        else
            if (SysTime() < entry.nextAttempt) then return end
            loadPath = entry.path
        end
    end
    if (cachedOnly && !loadPath) then return end
    local job = {panel = self, model = model, skin = self.ModelSkin, body = self.ModelBody,
        w = w, h = h, key = key, path = path, options = options, loadPath = loadPath}
    queued[key] = job
    queue[#queue + 1] = job
end

local function GenerateIcon(job)
    local ent = ClientsideModel(job.model, RENDERGROUP_OTHER)
    if (!IsValid(ent)) then return false end
    local inTarget, inView = false, false
    local r, g, b = render.GetColorModulation()
    local blend = render.GetBlend()
    local ok, result = xpcall(function()
        ent:SetNoDraw(true)
        ent:SetSkin(job.skin)
        ent:SetAngles(Angle(0, 0, 0))
        for i = 1, #job.body do
            ent:SetBodygroup(i - 1, tonumber(job.body:sub(i, i)) or 0)
        end
        local idle = ent:LookupSequence("idle_all_01")
        if (idle >= 0) then ent:ResetSequence(idle) end
        ent:SetupBones()
        local camera = PositionSpawnIcon(ent, vector_origin)
        if (istable(job.options)) then
            camera.origin = job.options.cam_pos or camera.origin
            camera.angles = job.options.cam_ang or camera.angles
            camera.fov = job.options.cam_fov or camera.fov
        end
        local sizeKey = job.w .. "x" .. job.h
        if (!targets[sizeKey]) then
            targets[sizeKey] = render.CreateNamedRenderTarget("_rt_hl2sb_icon_scratch_" .. sizeKey, job.w, job.h)
        end
        local target = targets[sizeKey]
        if (!target) then return false end
        render.PushRenderTarget(target, 0, 0, job.w, job.h, true)
        inTarget = true
        render.Clear(0, 0, 0, 0, true, true)
        render.PushView3D(camera.origin, camera.angles, camera.fov, 0, 0, job.w, job.h, camera.znear, camera.zfar)
        inView = true
        render.SuppressEngineLighting(true)
        render.SetLightingOrigin(ent:GetPos())
        render.ResetModelLighting(0.6, 0.6, 0.6)
        render.SetModelLighting(BOX_TOP, 1, 1, 1)
        render.SetModelLighting(BOX_FRONT, 0.7, 0.7, 0.7)
        render.SetColorModulation(1, 1, 1)
        render.SetBlend(1)
        ent:DrawModel()
        render.PopView3D()
        inView = false
        local png = render.Capture({format = "png", x = 0, y = 0, w = job.w, h = job.h, alpha = true})
        if (!png) then return false end
        local output = file.Open("materials/" .. job.path, "wb", "GAME")
        if (!output) then return false end
        output:Write(png)
        output:Close()
        return true
    end, debug.traceback)
    render.SuppressEngineLighting(false)
    render.SetColorModulation(r, g, b)
    render.SetBlend(blend)
    if (inView) then render.PopView3D() end
    if (inTarget) then render.PopRenderTarget() end
    ent:Remove()
    if (!ok || !result) then
        ErrorNoHalt("ModelImage: " .. tostring(result) .. "\n")
        return false
    end
    cache[job.key] = {material = LoadIconMaterial(job.path), path = job.path,
        attempts = 1, nextAttempt = SysTime() + 0.5, generated = true}
    hook.Run("SpawniconGenerated", job.model, job.path)
    return true
end

function PANEL:Paint(w, h)
    self.LastIconPaint = nil
    local enabled, left, top, right, bottom = surface.GetScissorRect()
    if (!enabled) then left, top, right, bottom = 0, 0, ScrW(), ScrH() end
    local x, y = self:LocalToScreen(0, 0)
    local visible = x < right && x + w > left && y < bottom && y + h > top
    if (visible) then
        self.LastIconPaint = paintGeneration
        if (self.PendingModel) then self:BuildIcon(w, h) end
    end
    DImage.Paint(self, w, h)
end

vgui.Register("ModelImage", PANEL, "DImage")

hook.Add("PostRenderVGUI", "HL2SBModelImageQueue", function()
    local deadline = SysTime() + 0.003
    local prepareDeadline = deadline - 0.002
    local prepared = 0
    while (warmHead <= #warmQueue && prepared < 8 && SysTime() < prepareDeadline) do
        local panel = warmQueue[warmHead]
        warmHead = warmHead + 1
        if (!IsValid(panel)) then continue end
        panel.WarmPending = nil
        if (panel.PendingModel) then panel:BuildIcon(panel:GetWide(), panel:GetTall(), true) end
        prepared = prepared + 1
    end
    if (warmHead > #warmQueue) then warmQueue, warmHead = {}, 1 end
    local count = 0
    while (queueHead <= #queue && count < 64 && SysTime() < deadline) do
        local job = queue[queueHead]
        queueHead = queueHead + 1
        queued[job.key] = nil
        local panel = job.panel
        if (!IsValid(panel) || panel.CacheKey != job.key) then continue end
        if (!job.loadPath && (panel.LastIconPaint != paintGeneration || !IsShown(panel))) then continue end
        if (job.loadPath) then
            local entry = cache[job.key]
            if (entry) then
                entry.material = LoadIconMaterial(job.loadPath)
                entry.attempts = entry.attempts + 1
                entry.nextAttempt = SysTime() + 0.5
            end
        else
            local generated = GenerateIcon(job)
            panel.ForceRebuild = false
            if (!generated) then panel.PendingModel = nil end
            break
        end
        count = count + 1
    end
    if (queueHead > #queue) then queue, queueHead = {}, 1 end
    paintGeneration = paintGeneration + 1
end)
