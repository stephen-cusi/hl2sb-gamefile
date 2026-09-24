-- 03.08.2026 - ой бля, лучше уже не заглядывайте в этот код, я чтобы чуть оптимизировать нейронку юзнул
-- она какую-то хуйню сделала, я с горем пополам до нормального состояния довёл, но читать это сложно
-- в теории в кэше убрать все функции GetModel(), но мне так уже на это поебать, вы бы знали
-- зато -10мс на модельке с гигантским количеством костей :^)

local cache = {}
local _GetChildBonesRecursive
local mdl = ""

local ENTITY, PLAYER = FindMetaTable("Entity"), FindMetaTable("Player")
local ANGLE = FindMetaTable("Angle") 
local VECTOR = FindMetaTable("Vector")
local CVAR = FindMetaTable("ConVar")
local Add, Sub, Div, Mul, Set = VECTOR.Add, VECTOR.Sub, VECTOR.Div, VECTOR.Mul, VECTOR.Set
local A_Set = ANGLE.Set
local GetBool = CVAR.GetBool
local Forward, Up, Right = ANGLE.Forward, ANGLE.Up, ANGLE.Right
local DistToSqr = VECTOR.DistToSqr
local Dot = VECTOR.Dot

local currentModel = "models/player/breen.mdl"
local _GetModel = ENTITY.GetModel
local shouldShowCachedVal = true
hook.Add("RenderScene", "cl_body.CurrentFrameNumber", function()
	shouldShowCachedVal = FrameNumber() % 3 ~= 0
end)

local GetModel = function(self)
	if shouldShowCachedVal then
		return currentModel
	end
	
	currentModel = _GetModel(self)
	return currentModel
end

local shouldDrawShadow = false

local GetClass = ENTITY.GetClass
local GetChildBones = ENTITY.GetChildBones
local E_IsValid = ENTITY.IsValid
local next = next
local pairs, ipairs = pairs, ipairs
local hook_Run = hook.Run
local render = render
local render_GetRenderTarget = render.GetRenderTarget
local render_SetColorModulation = render.SetColorModulation
local render_GetColorModulation = render.GetColorModulation
local math_NormalizeAngle = math.NormalizeAngle
local math_Clamp = math.Clamp
local shouldShowHands
local SetupBones = ENTITY.SetupBones 

_GetChildBonesRecursive = function(ent, bone, src)
	local t = src or {}
	table.insert(t, bone)
	local cbones = GetChildBones(ent, bone)

	if cbones then
		for _, bone in next, cbones do
			_GetChildBonesRecursive(ent, bone, t)
		end
	end

	return t
end

local cache2 = {}
local function GetChildBonesRecursive2(ent, bone)
	local mdl = GetModel(ent)
	local mdlbones = cache2[mdl]
	if not mdlbones then
		mdlbones = {}
		cache2[mdl] = mdlbones
	end

	local ret = mdlbones[bone]
	if ret then return ret end
	ret = _GetChildBonesRecursive(ent, bone)
	
	local newRet = {}
	for key, bone in ipairs(ret) do
		newRet[bone] = true
	end

	mdlbones[bone] = newRet
	return newRet
end

local function GetChildBonesRecursive(ent, bone)
	local mdl = GetModel(ent)
	local mdlbones = cache[mdl]

	if not mdlbones then
		mdlbones = {}
		cache[mdl] = mdlbones
	end

	local ret = mdlbones[bone]
	if ret then return ret end
	ret = _GetChildBonesRecursive(ent, bone)
	mdlbones[bone] = ret

	return ret
end

local GetBoneCount = ENTITY.GetBoneCount
local GetBoneName_INTERNAL = ENTITY.GetBoneName
local LookupBone_INTERNAL = ENTITY.LookupBone

local boneNameCache, boneCountCache, boneRemapCache, boneIndexCache = {}, {}, {}, {}

local CachedLookupBone = function(ent, name)
	local mdl = GetModel(ent)
	local byName = boneIndexCache[mdl]

	if not byName then
		byName = {}
		boneIndexCache[mdl] = byName
	end

	local idx = byName[name]
	if idx ~= nil then
		if idx == false then return nil end
		return idx
	end

	idx = LookupBone_INTERNAL(ent, name)
	if not idx and (GetBoneCount(ent) or 0) <= 0 then return nil end

	byName[name] = idx or false

	return idx
end

local recursiveShit = false
local GetBoneNames = function(ent)
	local mdl = GetModel(ent)
	local names = boneNameCache[mdl]
	if names then return names, boneCountCache[mdl] end

	if recursiveShit then return end

	recursiveShit = true
	SetupBones(ent)
	recursiveShit = false

	local count = GetBoneCount(ent) or 0
	if count <= 0 then return nil end

	names = {}
	for i = 0, count - 1 do
		names[i] = GetBoneName_INTERNAL(ent, i)
	end

	boneNameCache[mdl], boneCountCache[mdl] = names, count

	return names, count
end

local GetBoneRemap = function(src, dst)
	local srcMdl = GetModel(src)
	local byDst = boneRemapCache[srcMdl]

	if not byDst then
		byDst = {}
		boneRemapCache[srcMdl] = byDst
	end

	local map = byDst[srcMdl]
	if map then return map end

	local names, count = GetBoneNames(src)
	if not names or (GetBoneCount(dst) or 0) <= 0 then return nil end

	map = {}
	for i = 0, count - 1 do
		map[i] = LookupBone_INTERNAL(dst, names[i]) or false
	end

	byDst[srcMdl] = map

	return map
end

local translation = {
	["ru"] = {
		["Включить тело от 1-ого лица?"] = "Включить тело от 1-ого лица?",
		["Включить тело от 1-ого лица в Т/С?"] = "Включить тело от 1-ого лица в транспорте?",
		["Включить тень тела от 1-ого лица?"] = "Включить тень тела от 1-ого лица? (не работает с cl_drawownshadow)",
		["Включить совместимость с аддонами на руки?"] = "Включить совместимость с аддонами на руки?",
		["Дистанция отдаления тела от центра позиции игрока"] = "Дистанция отдаления тела от центра",
		["Настройка тела от 1 лица"] = "Настройка тела от 1-ого лица",
		["[Тело от первого лица] Текущая модель не имеет анимаций, выберите другую модель для показа тела от 1 лица."] = "[Тело от первого лица] У текущей модели нет анимаций. Пожалуйста, выберите другую модель.",
		["[Тело от первого лица] Не найден необходимый аддон Dynamic Player Height. Вы, конечно, можете играть и без него, но тело от первого лица будет выглядеть немного убого."] = "[Тело от первого лица] Не найден необходимый аддон Dynamic Player Height. Вы, конечно, можете играть и без него, но тело от первого лица будет выглядеть немного убого.",
		["Перезапустить тело"] = "Обновить тело",
		["Смещение по X"] = "Смещение по X",
		["Тёмность тени (-FPS!!)"] = "Тёмность тени (-FPS!!)",
		["Зафиксировать угол тела по отношению к углу камеры?"] = "Зафиксировать угол тела относительно камеры?",
	},

	["en"] = {
		["Включить тело от 1-ого лица?"] = "Enable first-person body?",
		["Включить тело от 1-ого лица в Т/С?"] = "Enable body in vehicles?",
		["Включить тень тела от 1-ого лица?"] = "Enable body shadow? (doesn't work with cl_drawownshadow)",
		["Включить совместимость с аддонами на руки?"] = "Enable compatibility with Hands SWEPs?",
		["Дистанция отдаления тела от центра позиции игрока"] = "Body distance from center",
		["Настройка тела от 1 лица"] = "First-person body settings",
		["[Тело от первого лица] Текущая модель не имеет анимаций, выберите другую модель для показа тела от 1 лица."] = "[First-Person Body] The current model has no animation sequences, please select another model.",
		["[Тело от первого лица] Не найден необходимый аддон Dynamic Player Height. Вы, конечно, можете играть и без него, но тело от первого лица будет выглядеть немного убого."] = "[First-Person Body] Required addon Dynamic Player Height not found. You can still play without it, of course, but the first-person body will look a bit shabby.",
		["Перезапустить тело"] = "Refresh Body",
		["Смещение по X"] = "X Offset",
		["Тёмность тени (-FPS!!)"] = "Shadow Darkness (-FPS!!)",
		["Зафиксировать угол тела по отношению к углу камеры?"] = "Lock body angle to camera angle?",
	},

	["tr"] = {
		["Включить тело от 1-ого лица?"] = "Birinci şahıs bedeni etkinleştirilsin mi?",
		["Включить тело от 1-ого лица в Т/С?"] = "Araç içindeyken beden etkinleştirilsin mi?",
		["Включить тень тела от 1-ого лица?"] = "Beden gölgesi etkinleştirilsin mi? (cl_drawownshadow ile çalışmaz)",
		["Включить совместимость с аддонами на руки?"] = "El SWEP'leri ile uyumluluk etkinleştirilsin mi?",
		["Дистанция отдаления тела от центра позиции игрока"] = "Bedenin merkezden uzaklığı",
		["Настройка тела от 1 лица"] = "Birinci şahıs beden ayarları",
		["[Тело от первого лица] Текущая модель не имеет анимаций, выберите другую модель для показа тела от 1 лица."] = "[Birinci Şahıs Beden] Mevcut modelin animasyon dizisi yok, lütfen başka bir model seçin.",
		["[Тело от первого лица] Не найден необходимый аддон Dynamic Player Height. Вы, конечно, можете играть и без него, но тело от первого лица будет выглядеть немного убого."] = "[Birinci Şahıs Beden] Gerekli Dynamic Player Height eklentisi bulunamadı. Elbette onsuz da oynayabilirsiniz, ancak birinci şahıs vücut biraz kötü görünecektir.",
		["Перезапустить тело"] = "Bedeni Yenile",
		["Смещение по X"] = "X Ofseti",
		["Тёмность тени (-FPS!!)"] = "Gölge Koyuluğu (-FPS!!)",
		["Зафиксировать угол тела по отношению к углу камеры?"] = "Beden açısı kamera açısına sabitlensin mi?",
	}
}

translation["uk"] = translation["ru"] -- :>

local CVar = GetConVar("gmod_language")

local L = function(str)
	local lang = CVar:GetString()
	local getTranslation = translation[lang]

	return getTranslation and getTranslation[str]
		or translation["en"][str]
		or str
end

local CVar = CreateClientConVar("cl_gm_body", 1, true, false, L"Включить тело от 1-ого лица?", 0, 1)
local CVar_FixedAngle = CreateClientConVar("cl_gm_body_fixed_angle", 0, true, false, L"Зафиксировать угол тела по отношению к углу камеры?", 0, 1)
local CVar_Distance = CreateClientConVar("cl_gm_body_forward_distance", 14, true, true, L"Дистанция отдаления тела от центра позиции игрока", 0, 32)
local CVar_XOffset = CreateClientConVar("cl_gm_body_x_offset", 0, true, false, L"Смещение по X", -16, 16)
local CVar_Vehicle = CreateClientConVar("cl_gm_body_in_vehicle", 1, true, false, L"Включить тело от 1-ого лица в Т/С?", 0, 1)
local CVar_Shadow = CreateClientConVar("cl_gm_body_enable_shadow", 1, true, false, L"Включить тень тела от 1-ого лица?", 0, 1)
local CVar_ShadowDarkness = CreateClientConVar("cl_gm_body_shadow_darkness", 1, true, false, L"Тёмность тени (-FPS!!)", 1, 4)
local CVar_Hands = CreateClientConVar("cl_gm_body_hands_compat", 1, true, false, L"Включить совместимость с аддонами на руки?", 0, 1)
local CVar_DebugDisableBoneBuilding = CreateClientConVar("cl_gm_body_debug_disable_bone_building", 0, true, false, nil, 0, 1)
local CVar_UseExperimentalOptimization = CreateClientConVar("cl_gm_body_use_experimental_optimization", 0, true, false, nil, 0, 1)

local forwardDistance = CVar_Distance:GetFloat()
local xOffset = CVar_XOffset:GetFloat()
local SHADOWS_COUNT = CVar_ShadowDarkness:GetInt()

cvars.AddChangeCallback("cl_gm_body_forward_distance", function(_, _, newValue)
	forwardDistance = tonumber(newValue) or 14
end, "cl_gm_body_forward_distance")

local getForwardDistance = function()
	local ret = hook_Run("cl_body.OverrideForwardDistance")
	if ret ~= nil then return ret end
	return forwardDistance
end

cvars.AddChangeCallback("cl_gm_body_x_offset", function(_, _, newValue)
	xOffset = tonumber(newValue) or 0
end, "cl_gm_body_x_offset")

local defaultConVars = {
	cl_gm_body = "1",
	cl_gm_body_fixed_angle = "0",
	cl_gm_body_forward_distance = "14",
	cl_gm_body_x_offset = "0",
	cl_gm_body_in_vehicle = "1",
	cl_gm_body_enable_shadow = "1",
	cl_gm_body_shadow_darkness = "1",
	cl_gm_body_use_experimental_optimization = "0",
	cl_gm_body_hands_compat = "1"
}

hook.Add("PopulateToolMenu", "body.Utilities", function()
	spawnmenu.AddToolMenuOption("Utilities", "User", "cl_body_options", L"Настройка тела от 1 лица", "", "", function(panel)
		panel:Clear()

		panel:AddControl("ComboBox", {
			MenuButton = 1,
			Folder = "first_person_body",
			Options = {["#preset.default"] = defaultConVars},
			CVars = table.GetKeys(defaultConVars)
		})

		panel:CheckBox(L"Включить тело от 1-ого лица?", "cl_gm_body")
		panel:CheckBox(L"Включить тело от 1-ого лица в Т/С?", "cl_gm_body_in_vehicle")
		panel:CheckBox(L"Зафиксировать угол тела по отношению к углу камеры?", "cl_gm_body_fixed_angle")
		panel:CheckBox(L"Включить тень тела от 1-ого лица?", "cl_gm_body_enable_shadow")
		panel:CheckBox(L"Включить совместимость с аддонами на руки?", "cl_gm_body_hands_compat")
		panel:NumSlider(L"Дистанция отдаления тела от центра позиции игрока", "cl_gm_body_forward_distance", 0, 32)
		panel:NumSlider(L"Смещение по X", "cl_gm_body_x_offset", -16, 16)
		panel:NumSlider(L"Тёмность тени (-FPS!!)", "cl_gm_body_shadow_darkness", 1, 4, 0)
		panel:Button(L"Перезапустить тело", "cl_gm_body_refresh", 8, 32)
	end)
end)

local bones = {}
local bonesName = {}
local queue = {}
local work = false

local MarkToRemove = function(ent)
	if not IsValid(ent) then
		return
	end

	work = true
	ent:SetNoDraw(true)
	table.insert(queue, ent)
end

hook.Add("Think", "cl_body.MarkToRemove", function()
	if not work then
		return
	end

	for key, ent in pairs(queue) do
		if E_IsValid(ent) then
			ent:Remove()
		end

		queue[key] = nil
	end

	if not next(queue) then
		work = false
	end
end)

hook.Add("LocalPlayer_Validated", "cl_body.Initialize", function(ply)
	hook.Remove("LocalPlayer_Validated", "cl_body.Initialize")

	local playermodelbones = {"ValveBiped.Bip01_Head1","ValveBiped.Bip01_R_Trapezius","ValveBiped.Bip01_R_Bicep","ValveBiped.Bip01_R_Shoulder", "ValveBiped.Bip01_R_Elbow","ValveBiped.Bip01_R_Wrist","ValveBiped.Bip01_R_Ulna","ValveBiped.Bip01_L_Trapezius","ValveBiped.Bip01_L_Bicep","ValveBiped.Bip01_L_Shoulder", "ValveBiped.Bip01_L_Elbow","ValveBiped.Bip01_L_Wrist","ValveBiped.Bip01_L_Ulna", "ValveBiped.Bip01_Neck1","ValveBiped.Bip01_Hair1","ValveBiped.Bip01_Hair2","ValveBiped.Bip01_L_Clavicle","ValveBiped.Bip01_R_Clavicle","ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_L_Wrist", "ValveBiped.Bip01_R_Wrist", "ValveBiped.Bip01_L_Finger4", "ValveBiped.Bip01_L_Finger41", "ValveBiped.Bip01_L_Finger42", "ValveBiped.Bip01_L_Finger3", "ValveBiped.Bip01_L_Finger31", "ValveBiped.Bip01_L_Finger32", "ValveBiped.Bip01_L_Finger2", "ValveBiped.Bip01_L_Finger21", "ValveBiped.Bip01_L_Finger22", "ValveBiped.Bip01_L_Finger1", "ValveBiped.Bip01_L_Finger11", "ValveBiped.Bip01_L_Finger12", "ValveBiped.Bip01_L_Finger0", "ValveBiped.Bip01_L_Finger01", "ValveBiped.Bip01_L_Finger02", "ValveBiped.Bip01_R_Finger4", "ValveBiped.Bip01_R_Finger41", "ValveBiped.Bip01_R_Finger42", "ValveBiped.Bip01_R_Finger3", "ValveBiped.Bip01_R_Finger31", "ValveBiped.Bip01_R_Finger32", "ValveBiped.Bip01_R_Finger2", "ValveBiped.Bip01_R_Finger21", "ValveBiped.Bip01_R_Finger22", "ValveBiped.Bip01_R_Finger1", "ValveBiped.Bip01_R_Finger11", "ValveBiped.Bip01_R_Finger12", "ValveBiped.Bip01_R_Finger0", "ValveBiped.Bip01_R_Finger01", "ValveBiped.Bip01_R_Finger02"}
	local playermodelbones_kv = {}

	for key, v in pairs(playermodelbones) do
		playermodelbones_kv[v] = true
	end

	local SHADOW_KEYS = {"Body_Shadow_1", "Body_Shadow_2", "Body_Shadow_3", "Body_Shadow_4"}
	local cl_drawownshadow = GetConVar("cl_drawownshadow")

	local garbageBoneCache = {}
	local forward = Vector()
	local ply = ply or LocalPlayer()
	local lastShadowRender = SysTime() + 1

	local bonesFastLookup = {}
	local bonesFastName = {}
	local bonesUncached = true

	local LookupBone = ENTITY.LookupBone
	local GetBoneName = ENTITY.GetBoneName

	local TraceHull = util.TraceHull
	local setBlend = render.SetBlend
	local getBlend = render.GetBlend
	local FindInSphere = ents.FindInSphere
	local SetModelScale = ENTITY.SetModelScale

	local _EyeAngles = ENTITY.EyeAngles
	local GetFlags = ENTITY.GetFlags
	local GetTable = ENTITY.GetTable

	local TEXTURE = FindMetaTable("ITexture")
	local GetName = TEXTURE.GetName

	local MATRIX = FindMetaTable("VMatrix")
	local Scale, Translate, SetTranslation, SetAngles = MATRIX.Scale, MATRIX.Translate, MATRIX.SetTranslation, MATRIX.SetAngles
	local GetTranslation, GetAngles = MATRIX.GetTranslation, MATRIX.GetAngles
	local SetBoneMatrix = ENTITY.SetBoneMatrix
	local render = render
	local cam_Start3D, render_EnableClipping, render_PushCustomClipPlane, render_PopCustomClipPlane, render_EnableClipping, cam_End3D =
		cam.Start3D, render.EnableClipping, render.PushCustomClipPlane, render.PopCustomClipPlane, render.EnableClipping, cam.End3D

	local _EyePos = ENTITY.EyePos
	local CurTime = CurTime
	local FrameTime = FrameTime
	local GetCycle = ENTITY.GetCycle
	local DrawModel = ENTITY.DrawModel
	local ManipulateBonePosition = ENTITY.ManipulateBonePosition
	local ManipulateBoneScale = ENTITY.ManipulateBoneScale
	local GetAttachment = ENTITY.GetAttachment
	local GetNWBool = ENTITY.GetNWBool
	local LookupAttachment = ENTITY.LookupAttachment
	local GetCurrentViewOffset = PLAYER.GetCurrentViewOffset
	local Crouching = PLAYER.Crouching
	local OnGround = ENTITY.OnGround
	local ShouldDrawLocalPlayer = PLAYER.ShouldDrawLocalPlayer
	local Alive = PLAYER.Alive
	local GetRagdollEntity = PLAYER.GetRagdollEntity
	local _InVehicle = PLAYER.InVehicle
	local inVehicleCached = false
	local InVehicle = function()
		return inVehicleCached
	end

	local FL_ANIMDUCKING = FL_ANIMDUCKING
	local STUDIO_RENDER = STUDIO_RENDER
	local STUDIO_SHADOWDEPTHTEXTURE = STUDIO_SHADOWDEPTHTEXTURE
	local STUDIO_SSAODEPTHTEXTURE = STUDIO_SSAODEPTHTEXTURE
	local GetBodygroup = ENTITY.GetBodygroup
	local SetBodygroup = ENTITY.SetBodygroup

	local GetFlexScale = ENTITY.GetFlexScale
	local GetFlexNum = ENTITY.GetFlexNum
	local GetFlexWeight = ENTITY.GetFlexWeight
	local SetFlexScale = ENTITY.SetFlexScale
	local SetFlexWeight = ENTITY.SetFlexWeight
	local GetModelScale = ENTITY.GetModelScale
	local GetModelRenderBounds = ENTITY.GetModelRenderBounds

	local currentWeapon = ""
	local GetObserverMode = PLAYER.GetObserverMode

	local removeAll = function()
		MarkToRemove(ply.Body)
		MarkToRemove(ply.Body_NoDraw)

		for i = 1, 4 do
			MarkToRemove(ply["Body_Shadow_" .. i])
		end
		
		bonesFastLookup, bonesFastName = {}, {}
		boneNameCache, boneCountCache, boneRemapCache, boneIndexCache, garbageBoneCache = {}, {}, {}, {}, {}
	end
	removeAll()
 
	for _, cvarName in ipairs({"cl_gm_body", "cl_gm_body_enable_shadow"}) do
		cvars.AddChangeCallback(cvarName, function(_, _, newValue)
			lastShadowRender = -1
		end, cvarName)
	end

	cvars.AddChangeCallback("cl_gm_body_shadow_darkness", function(_, _, newValue)
		SHADOWS_COUNT = tonumber(newValue) or 1
		
		timer.Remove("cl_gm_body_shadow_darkness_update")
		timer.Create("cl_gm_body_shadow_darkness_update", 0.1, 1, removeAll)
	end, "cl_gm_body_shadow_darkness")

	local hook = hook
	local math = math
	local remap = math.Remap
	local eyeAngles = Angle()
	local suppress = true

	local isDucking = false
	local limit_check = 0
	local timeCache = -1
	local vector_origin = Vector(0, 0, 0)
	local trace_array = {
		mins = Vector(-1, -1, -1),
		maxs = Vector(1, 1, 1),
		ignoreworld = true,
	}
	
	local RENDERTARGET_SHADOW_LIMIT_DISTANCE = 512 ^ 2

	local find, insert, lower = string.find, table.insert, string.lower

	local SetPoseParameter, GetPoseParameter = ENTITY.SetPoseParameter, ENTITY.GetPoseParameter
	local SetPlaybackRate, GetPlaybackRate = ENTITY.SetPlaybackRate, ENTITY.GetPlaybackRate
	local SetSkin, GetSkin = ENTITY.SetSkin, ENTITY.GetSkin
	local SetMaterial, GetMaterial = ENTITY.SetMaterial, ENTITY.GetMaterial
	local GetColor = ENTITY.GetColor

	local GetBoneMatrix = ENTITY.GetBoneMatrix
	local SetLOD = ENTITY.SetLOD

	local a1, b1, c1 = 0, 0, 0
	local headPos = Vector(0,10000,0)
	local limitJump = 0

	local onGround = true
	local JUMPING_ = false
	local vehicle_steer,d1,e1 = 0, 0, 0
	local GetNumPoseParameters, GetPoseParameterRange = ENTITY.GetNumPoseParameters, ENTITY.GetPoseParameterRange
	local GetPoseParameterName, GetSequence = ENTITY.GetPoseParameterName, ENTITY.GetSequence
	local GetRenderAngles, SetRenderAngles = PLAYER.GetRenderAngles, PLAYER.SetRenderAngles
	local faggot = Vector()
	local GetPos, GetViewOffset = ENTITY.GetPos, PLAYER.GetViewOffset
	local vector_normal = Vector(1, 1, 1)
	local vector_fixCrouch = Vector()
	local CreateShadow, DestroyShadow, SetRenderBounds = ENTITY.CreateShadow, ENTITY.DestroyShadow, ENTITY.SetRenderBounds
	local vrmod = vrmod
	local mins_render, maxs_render = Vector(-72, -72, 0), Vector(72, 72, 0)
	local fuckedMins, fuckedMaxs = Vector(-768, -768, 0), Vector(768, 768, 768)
	local eyePos = Vector()
	local ply_EyePos = Vector()
	local realEyeAngles = EyeAngles()

	local vector_down = Vector(0, 0, -1)
	local erroredModels = {}
	local DestroyShadow = ENTITY.DestroyShadow
	local oldSeq, oldSequenceName = 0, ""

	hook.Add("SetupMove", "cl_body.SetupMove", function(ply, move)
		if not IsFirstTimePredicted() then
			return
		end
	
		if bit.band(move:GetButtons(), IN_JUMP) ~= 0
			and bit.band(move:GetOldButtons(), IN_JUMP) == 0
			and OnGround(ply) then
			JUMPING_, onGround = not JUMPING_, false
		end
	end)

	hook.Add("FinishMove", "cl_body.FinishMove", function(ply, move)
		if not IsFirstTimePredicted() then return end

		local isOnGround = OnGround(ply)
		if onGround ~= isOnGround then
			onGround = isOnGround
	
			if onGround then
				limitJump = CurTime() + FrameTime() * 3
			end
		end
	end)

	local validBones = {}
	local calcView = function(ply, vec, ang, overrideEyePos)
		if not GetBool(CVar_Vehicle)
			or not inVehicleCached
			or suppress then
			return
		end

		vehicle_steer = GetPoseParameter(ply, "vehicle_steer")
		d1 = GetPoseParameter(ply, "head_yaw")
		e1 = GetPoseParameter(ply, "head_pitch")

		local a1, b1, c1 = GetPoseParameter(ply, "body_yaw", 0), GetPoseParameter(ply, "aim_yaw", 0), GetPoseParameter(ply, "aim_pitch", 0)

		SetPoseParameter(ply, "body_yaw", 0)
		SetPoseParameter(ply, "aim_yaw", 0)
		SetPoseParameter(ply, "aim_pitch", 0)

		SetPoseParameter(ply, "vehicle_steer", 0)
		SetPoseParameter(ply, "head_yaw", 0)
		SetPoseParameter(ply, "head_pitch", 0)

		SetupBones(ply)

		local eyesAttachment = LookupAttachment(ply, "eyes")
		if eyesAttachment then
			local mat = GetAttachment(ply, eyesAttachment)

			if mat then
				local pos = mat.Pos
				if overrideEyePos then
					vec.x = pos.x
					vec.y = pos.y
				else
					vec.x = vec.x - (vec.x - pos.x)
					vec.y = vec.y - (vec.y - pos.y)
				end
			end
		end

		SetPoseParameter(ply, "vehicle_steer", vehicle_steer)
		SetPoseParameter(ply, "head_yaw", d1)
		SetPoseParameter(ply, "head_pitch", e1)

		SetPoseParameter(ply, "body_yaw", a1)
		SetPoseParameter(ply, "aim_yaw", b1)
		SetPoseParameter(ply, "aim_pitch", c1)
	end

	hook.Add("CalcView", "body.CalcView", function(ply, vec, ang)
		calcView(ply, vec, ang)
	end)

	local GetGarbageBones = function(ent)
		local mdl = GetModel(ent)
		local flags = garbageBoneCache[mdl]
		if flags then return flags end

		local names, count = GetBoneNames(ent)
		if not names then return nil end

		flags = {}
		for i = 0, count - 1 do
			flags[i] = playermodelbones_kv[names[i]] or false
		end

		garbageBoneCache[mdl] = flags

		return flags
	end

	local EMPTY_HAND_CACHE = {}

	local removeGarbage = function(ent, bonesSuccess, boneCount)
		local eyeForward = Forward(eyeAngles)
		local hideAllGarbageShitPosition = GetPos(ply)
		Add(hideAllGarbageShitPosition, GetViewOffset(ply))
		Sub(hideAllGarbageShitPosition, eyeForward * 32)

		if GetBool(CVar_Vehicle) and inVehicleCached then
			local boneMap = GetBoneRemap(ent, ply)

			for i = 0, boneCount - 1 do
				local bone = boneMap and boneMap[i]

				if bone then
					local mat = GetBoneMatrix(ent, i)

					if mat then
						local mat2 = GetBoneMatrix(ply, bone)

						if mat2 then
							SetTranslation(mat, GetTranslation(mat2))
							SetAngles(mat, GetAngles(mat2))
							SetBoneMatrix(ent, i, mat)
						end
					end
				end
			end

			local h = CachedLookupBone(ent, "ValveBiped.Bip01_Head1")
			if h then
				local getScale = inVehicleCached and vector_origin or vector_normal
				local mat = GetBoneMatrix(ent, h)

				ManipulateBonePosition(ent, h, headPos)
				ManipulateBoneScale(ent, h, getScale)

				if mat then
					local pos = GetTranslation(mat)
					local recursive = GetChildBonesRecursive(ent, h)

					for key = 1, #recursive do
						local bone = recursive[key]

						if bone then
							ManipulateBoneScale(ent, bone, getScale)

							local mat2 = GetBoneMatrix(ent, bone)
							if not mat2 then goto skip end

							SetTranslation(mat2, pos)
							SetBoneMatrix(ent, bone, mat2)

							::skip::
						end
					end
				end
			end

			return
		end

		local L_Cache, R_Cache = EMPTY_HAND_CACHE, EMPTY_HAND_CACHE
		local diff = 0
		if shouldShowHands() then
			local headBone = CachedLookupBone(ply, "ValveBiped.Bip01_Neck1")
			local L_Clavicle = CachedLookupBone(ply, "ValveBiped.Bip01_L_Clavicle")
			local R_Clavicle = CachedLookupBone(ply, "ValveBiped.Bip01_R_Clavicle")

			if not headBone then
				headBone = CachedLookupBone(ply, "ValveBiped.Bip01_Head1")
			end
			
			if headBone then
				local mat = GetBoneMatrix(ply, headBone)
				if mat then
					local viewOffset = GetCurrentViewOffset(ply)
					viewOffset.z = 0
					diff = ((eyePos - viewOffset) - GetTranslation(mat)):Length2D() - 1
				end
			end

			if L_Clavicle then
				L_Cache = GetChildBonesRecursive2(ent, L_Clavicle)
			end

			if R_Clavicle then
				R_Cache = GetChildBonesRecursive2(ent, R_Clavicle)
			end
		end

		local boneMap = GetBoneRemap(ent, ply)
		local garbage = GetGarbageBones(ent)
		local handsOffset = eyeForward * diff

		for i = 0, boneCount - 1 do
			local hands = L_Cache[i] or R_Cache[i]
			local isGarbage = not hands 

			if garbage then
				isGarbage = garbage[i] and not hands 
			end
	
			if isGarbage then
				local mat = GetBoneMatrix(ent, i)

				if mat then
					SetTranslation(mat, hideAllGarbageShitPosition)
					SetBoneMatrix(ent, i, mat)

					bonesSuccess[i] = true

					local recursive = GetChildBonesRecursive(ent, i)
					for key = 1, #recursive do
						local bone = recursive[key]

						if not bonesSuccess[bone] then
							bonesSuccess[bone] = true

							local childMat = GetBoneMatrix(ent, bone)
							if childMat then
								SetTranslation(childMat, hideAllGarbageShitPosition)
								SetBoneMatrix(ent, bone, childMat)
							end
						end
					end
				end
			elseif hands or not bonesSuccess[i] then
				local mat = GetBoneMatrix(ent, i)

				if mat then
					local bone = boneMap and boneMap[i] or false

					if bone then
						local mat2 = GetBoneMatrix(ply, bone)

						if mat2 then
							local translation = GetTranslation(mat2)
							Sub(translation, forward)
							Sub(translation, vector_fixCrouch)
							if hands then
								Sub(translation, handsOffset)
							end

							SetTranslation(mat, translation)
							SetAngles(mat, GetAngles(mat2))
						end
					end

					SetBoneMatrix(ent, i, mat)
				end
			end
		end

		return L_Cache, R_Cache
	end

	local Body_NoDraw_Angle = Angle(0, 0, 0)
	local Body_NoDraw_Pos_Z = 0
	local Body_NoDraw_Pos_Z_SpineIdleAnim = 0
	local localPelvisZ -- Z таза Body_NoDraw относительно origin'а модели
	local potentionalBones, timeCacheBones = {}, 0
	local vectorsDiff = Vector() -- скретч вместо "mat2TR - matTR" на каждую кость
	local spineBones = { ["ValveBiped.Bip01_Spine2"] = true, ["ValveBiped.Bip01_Spine4"] = true }

	local miscSpineBones = {}
	local ik_foot = hook.GetTable()["PostPlayerDraw"]

	if ik_foot then
		ik_foot = ik_foot["IKFoot_PostPlayerDraw"]
	end

	if VMS and VMS.GetViewModels then
		VMS_GetViewModels = VMS_GetViewModels or VMS.GetViewModels
		local VMS_GetViewModels = VMS_GetViewModels

		function VMS.GetViewModels(...)
			local mdls = VMS_GetViewModels(...)

			if IsValid(ply.Body) then
				table.insert(mdls, ply.Body)
			end

			return mdls
		end
	end

	hook.Add("Glide_OnLocalEnterVehicle", "cl_body.InitializeCamera", function()
		timer.Simple(0, function()
			if Glide.Camera and Glide.Camera.CalcView then
				Glide.Camera.OldCalcView = Glide.Camera.OldCalcView or Glide.Camera.CalcView
				local oldFunc = Glide.Camera.OldCalcView
				Glide.Camera.CalcView = function(self, ...)
					if suppress then
						return oldFunc(self, ...)
					end

					local returnedArray = oldFunc(self, ...)
					if not returnedArray then return returnedArray end

					calcView(LocalPlayer(), returnedArray.origin, returnedArray.angles, true)
					return returnedArray
				end
			end
		end)
	end)

	local shadow_buildBonePosition = function(shadowIndex)
		local shadowEnt = ply[SHADOW_KEYS[shadowIndex]]
		if not IsValid(shadowEnt) then return end

		shadowEnt.Callback = shadowEnt:AddCallback("BuildBonePositions", function(ent, boneCount)
			local boneMap = GetBoneRemap(ent, ply)
			if not boneMap then return end

			local ang = GetRenderAngles(ply)
			local renderAngleChanged = GetBool(CVar_FixedAngle)

			if renderAngleChanged then
				SetRenderAngles(ply, eyeAngles)

				a1, b1, d1 = GetPoseParameter(ply, "body_yaw", 0), GetPoseParameter(ply, "aim_yaw", 0), GetPoseParameter(ply, "head_yaw", 0)

				SetPoseParameter(ply, "body_yaw", 0)
				SetPoseParameter(ply, "aim_yaw", 0)
				SetPoseParameter(ply, "head_yaw", 0)
			end

			SetupBones(ply)

			for i = 0, boneCount - 1 do
				local lookupBone = boneMap[i]

				if lookupBone then
					local mat = GetBoneMatrix(ply, lookupBone)

					if mat then
						local mat2 = GetBoneMatrix(ent, i)

						if mat2 then
							local translation = GetTranslation(mat)
							Sub(translation, forward)
							Sub(translation, vector_fixCrouch)

							SetTranslation(mat2, translation)
							SetAngles(mat2, GetAngles(mat))
							SetBoneMatrix(ent, i, mat2)
						end
					end
				end
			end

			SetRenderAngles(ply, ang)

			if renderAngleChanged then
				SetPoseParameter(ply, "body_yaw", a1)
				SetPoseParameter(ply, "aim_yaw", b1)
				SetPoseParameter(ply, "head_yaw", d1)
			end
		end)
	end

	local buildBonePosition = function()
		ply.Body.Callback = ply.Body:AddCallback("BuildBonePositions", function(ent, boneCount)
			if GetBool(CVar_DebugDisableBoneBuilding) then return end

			local plyTable = GetTable(ply)
			if not plyTable.TimeToDuck
				or suppress then
				return ent:RemoveCallback("BuildBonePositions", plyTable.Body.Callback)
			end

			local ang = GetRenderAngles(ply)
			local renderAngleChanged = not inVehicleCached and GetBool(CVar_FixedAngle)

			if renderAngleChanged then
				SetRenderAngles(ply, eyeAngles)

				a1, b1, c1 = GetPoseParameter(ply, "body_yaw", 0), GetPoseParameter(ply, "aim_yaw", 0), GetPoseParameter(ply, "aim_pitch", 0)

				SetPoseParameter(ply, "body_yaw", 0)
				SetPoseParameter(ply, "aim_yaw", 0)
				SetPoseParameter(ply, "aim_pitch", 0)
			end

			local currentSequence = ply:GetSequence()
			if ent.Seq ~= currentSequence then
				ent.Seq = currentSequence
				ply:ResetSequenceInfo()
			end

			SetupBones(ply)

			if ik_foot then
				ik_foot(ply)
			end

			hook_Run("body.SetupBones", ent)

			local bonesSuccess = {}
			local L_Cache, R_Cache = removeGarbage(ent, bonesSuccess, boneCount)

			if renderAngleChanged then
				SetPoseParameter(ply, "body_yaw", a1)
				SetPoseParameter(ply, "aim_yaw", b1)
				SetPoseParameter(ply, "aim_pitch", c1)
			end

			local bodyNoDraw = plyTable.Body_NoDraw
			SetupBones(bodyNoDraw)

			local this = (2 - (0.8 * plyTable.TimeToDuck))
			local defaultThis = this
			local CT = CurTime()

			if not inVehicleCached then
				if timeCacheBones < CT then
					timeCacheBones, potentionalBones, miscSpineBones, timeCache = CT + timeCache, {}, {}, 999999 -- всем, кто заикнётся про это, сразу скажу - идите нахуй, мне лень нормально фиксить

					for boneName in pairs(spineBones) do
						local bone = CachedLookupBone(ent, boneName)

						if bone then
							local bones = GetChildBonesRecursive(ent, bone)

							for i = 1, #bones do
								miscSpineBones[bones[i]] = true
							end
						end
					end

					local boneNames = GetBoneNames(ent)

					for i = 1, #validBones do
						local array = validBones[i]
						local bone, isPelvis = array[2], array[1]

						if bonesSuccess[bone] then
							continue
						end

						local recursive = GetChildBonesRecursive(ent, bone)

						for key = 1, #recursive do
							local i = recursive[key]

							if not bonesSuccess[i]
								and (isPelvis and i == bone or not isPelvis)
								and i then
								bonesSuccess[i] = true

								local boneName = boneNames and boneNames[i] or GetBoneName(ent, i)

								local hands = L_Cache[i] or R_Cache[i]
								if hands then goto skip end

								local mat = GetBoneMatrix(ent, i)
								if mat then
									local b = CachedLookupBone(bodyNoDraw, boneName)

									if b then
										local mat2 = GetBoneMatrix(bodyNoDraw, b)
										if mat2 then
											local matTR, mat2TR = GetTranslation(mat), GetTranslation(mat2)
											Sub(mat2TR, vector_fixCrouch)

											local kind = 0

											if boneName == "ValveBiped.Bip01_Pelvis" then
												kind = 1
												Body_NoDraw_Angle.y = math_NormalizeAngle(math_NormalizeAngle(eyeAngles.y - GetAngles(mat).y) + 90) / 1.25
												Body_NoDraw_Pos_Z = matTR.z
												Body_NoDraw_Pos_Z_SpineIdleAnim = mat2TR.z
											elseif spineBones[boneName] then
												kind = 2
												this = 4
											elseif miscSpineBones[i] then
												kind = 3
												this = 5
											end

											Set(vectorsDiff, mat2TR)
											Sub(vectorsDiff, matTR)
											Div(vectorsDiff, this)
											Sub(mat2TR, vectorsDiff)
											SetTranslation(mat, mat2TR)
											SetAngles(mat, GetAngles(mat2))
											SetBoneMatrix(ent, i, mat)

											potentionalBones[#potentionalBones + 1] = {
												[1] = i,
												[2] = boneName,
												[3] = b,
												[4] = kind
											}

											this = defaultThis
										end
									end
								end
								::skip::
							end
						end
					end
				else
					for key = 1, #potentionalBones do
						local array = potentionalBones[key]
						local i, b, kind = array[1], array[3], array[4]

						local hands = L_Cache[i] or R_Cache[i]
						if not hands then
							local mat = GetBoneMatrix(ent, i)

							if mat then
								local mat2 = GetBoneMatrix(bodyNoDraw, b)

								if mat2 then
									local matTR, mat2TR = GetTranslation(mat), GetTranslation(mat2)
									Sub(mat2TR, vector_fixCrouch)

									if kind == 1 then
										Body_NoDraw_Angle.y = math_NormalizeAngle(math_NormalizeAngle(eyeAngles.y - GetAngles(mat).y) + 90) / 1.25
										Body_NoDraw_Pos_Z = matTR.z
										Body_NoDraw_Pos_Z_SpineIdleAnim = mat2TR.z
									elseif kind == 2 then
										this = 4
									elseif kind == 3 then
										this = 5
									end
			
									Set(vectorsDiff, mat2TR)
									Sub(vectorsDiff, matTR)
									Div(vectorsDiff, this)
									Sub(mat2TR, vectorsDiff)
									SetTranslation(mat, mat2TR)
									SetAngles(mat, GetAngles(mat2))
									SetBoneMatrix(ent, i, mat)

									this = defaultThis
								end
							end
						end
					end
				end
			end

			SetRenderAngles(ply, ang)
		end)

		ply.Body.FullyLoaded = true
	end

	local getValidBones = function()
		validBones = {}

		local plyTable = GetTable(ply)
		local body = plyTable.Body
		local boneNames = GetBoneNames(body)

		for i = 0, body:GetBoneCount() - 1 do
			local boneName = boneNames and boneNames[i] or GetBoneName(body, i)
			local isPelvis = find(boneName, "Pelvis", 1, true) or false
			local getBone = find(boneName, "Spine", 1, true)
				or isPelvis
				or find(boneName, "Jacket", 1, true)

			if not getBone then goto skip end

			validBones[#validBones + 1] = {
				[1] = isPelvis,
				[2] = i
			}

			::skip::
		end
	end

	local clipPlanePos = Vector() -- скретч: RenderOverride зовётся ~9 раз за кадр
	local changeRenderOverrideFunction = function()
		local plyTable = GetTable(ply)
		if not IsValid(plyTable.Body) then return end

		plyTable.Body.RenderOverride = function(ply_Body, flag)
			flag = flag or STUDIO_RENDER

			if suppress
				or not ply_Body.FullyLoaded
				or bit.band(flag, STUDIO_SHADOWDEPTHTEXTURE) ~= 0
				-- or bit.band(flag, STUDIO_TRANSPARENCY) ~= 0 -- хер знает че это, но оно дублирует вызов RenderOverride на некоторых моделях: https://steamcommunity.com/sharedfiles/filedetails/?id=3764294435
				--or bit.band(flag, STUDIO_SSAODEPTHTEXTURE) ~= 0 -- в буфер глубины было бы отлично рендерить
				or ShouldDrawLocalPlayer(ply) then
				return
			end

			if render_GetRenderTarget()
				and DistToSqr(EyePos(), _EyePos(ply)) > 1024 then
				return
			end

			local ret = hook_Run("PreDrawBody", ply_Body)
			if ret == false then
				shouldDrawShadow = false
				return
			end

			shouldDrawShadow = true

			local isResolvedDepth = bit.band(flag, STUDIO_SSAODEPTHTEXTURE) ~= 0
			local inVeh = InVehicle(ply)
			local bEnabled = false

			if not inVeh then
				local eyePosOverride = ply_EyePos * 1
				local retVec, retAng = hook.Run("cl_body.OverrideOffsets", ply_Body, eyePosOverride)
				local ply_EyeAng = retAng
				if retVec then
					eyePosOverride = retVec
				end
				cam_Start3D(eyePosOverride, ply_EyeAng, nil, nil, nil, nil, nil, 0.5, -1)
					local t = math_Clamp((realEyeAngles.p + 60) / 89, 0, 1)
					Set(clipPlanePos, eyePosOverride)
					clipPlanePos.z = clipPlanePos.z + 10 * t
					render_PushCustomClipPlane(vector_down, Dot(vector_down, clipPlanePos))
					bEnabled = render_EnableClipping(true)
			end
				local m1, m2, m3
				if !isResolvedDepth then
					m1, m2, m3 = render_GetColorModulation()

					local color = GetColor(ply)
					render_SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
				end

				DrawModel(ply_Body)

				if !isResolvedDepth then
					render_SetColorModulation(m1, m2, m3)
				end

			if not inVeh then
					render_PopCustomClipPlane()
					render_EnableClipping(bEnabled)
				cam_End3D()
			end

			hook_Run("PostDrawBody", ply_Body)
		end
		
		plyTable.Body.RenderOverrideHash = tostring(plyTable.Body.RenderOverride)
		getValidBones()
	end

	local SetParent, SetPos, SetAngles, SetCycle = ENTITY.SetParent, ENTITY.SetPos, ENTITY.SetAngles, ENTITY.SetCycle

	local handsWeapons = {
		["none"] = true, -- PAC3
		["weapon_hands"] = true, -- Hands SWEP
		["weapon_empty_hands"] = true, -- Empty Hands SWEP
		["rp_keys"] = true, -- для сервера Уютный Сандбокс
		["rp_hands"] = true, -- RP hands
		["weaponholster"] = true, -- Simple Holster
	}

	shouldShowHands = function()
		if not GetBool(CVar_Hands) then return false end
		if not IsValid(activeWeapon) then return true end -- nothing
		local weaponClass = GetClass(activeWeapon)
		local ret = hook_Run("cl_body.ShouldShowHands", activeWeapon, weaponClass) -- you can override this
		if ret ~= nil then return ret end
		if handsWeapons[weaponClass] then return true end
		return false
	end
	
	local FC5CVar = GetConVar("fc5_lookdown_enabled")
	hook.Add("cl_body.ShouldShowHands", "cl_body.OverrideExample", function(activeWeapon, weaponClass)
		if weaponClass == "rp_keys" and activeWeapon.GetFightMode and (activeWeapon:GetFightMode() or (activeWeapon.LastFightMode or 0) > CurTime()) then
			return false
		end

		if weaponClass == "wep_jack_gmod_hands" and not activeWeapon:GetFists() then
			return true
		end

		if FC5CVar and not GetBool(FC5CVar) and weaponClass == "fc5_hands" then
			local currentAnim = activeWeapon:GetCurrentAnim()
			return (find(currentAnim, "idle", 1, true) or find(currentAnim, "jog", 1, true)) and not isDucking and not Crouching(ply)
		end
	end)

	hook.Add("RenderScene", "firstperson_shadow.RenderScene", function(vec, ee)
		local plyTable = GetTable(ply)
		local ply_Body = plyTable.Body
		if not IsValid(ply_Body) then return end

		DestroyShadow(ply_Body)

		local nodrawbody = plyTable.Body_NoDraw
		if IsValid(nodrawbody) then
			DestroyShadow(nodrawbody)
			nodrawbody:SetNoDraw(true)
		end

		local mdlScale = GetModelScale(ply)
		local _, size2 = GetModelRenderBounds(ply)
		maxs_render.z = size2.z * 1.25 + vector_fixCrouch.z

		local shouldDisableShadow = suppress
				or not GetBool(CVar)
				or ShouldDrawLocalPlayer(ply)
				or not GetBool(CVar_Shadow)
				or not shouldDrawShadow
				or GetBool(cl_drawownshadow)

		for i = 1, SHADOWS_COUNT do
			local self = plyTable[SHADOW_KEYS[i]]
			if not IsValid(self) then
				goto skip
			end

			if shouldDisableShadow then
				DestroyShadow(self)
			elseif faggot and plyTable.TimeToFaggot then
				lastShadowRender = SysTime() + .33

				SetPos(self, GetPos(ply) - forward)
				SetAngles(self, eyeAngles)
				SetModelScale(self, mdlScale)
				CreateShadow(self)

				SetRenderBounds(self, mins_render, maxs_render)
			end
			
			::skip::
		end
	end)

	local processTick = function()
		local plyTable = GetTable(ply)
		local body = plyTable.Body
		local bodyNoDraw = plyTable.Body_NoDraw
		local bodyIsValid = IsValid(body)
		local bodyShadowIsValid = IsValid(plyTable.Body_Shadow_1)
		local inVeh = InVehicle(ply)
		local isEnabled = GetBool(CVar)

		local oldSuppress = suppress
		suppress = ShouldDrawLocalPlayer(ply)
			or not Alive(ply)
			or not bodyIsValid
			or not bodyShadowIsValid
			or not body.FullyLoaded
			or not IsValid(ply.Body_NoDraw)
			or not isEnabled
			or (inVeh and (not GetBool(CVar_Vehicle) or ply:GetAllowWeaponsInVehicle()))
			or ply:GetAllowWeaponsInVehicle()
			or E_IsValid(GetRagdollEntity(ply))
			or GetObserverMode(ply) ~= 0
			or (plyTable.IsProne and ply:IsProne())
			or realEyeAngles.p > 110
			or realEyeAngles.p < -110
			or (vrmod and vrmod.IsPlayerInVR(ply))
			or plyTable.ShouldDisableLegs
			or hook_Run("ShouldDisableLegs", body) == true

		activeWeapon = ply:GetActiveWeapon()
		inVehicleCached = _InVehicle(ply)
		currentModel = GetModel(ply)

		if bodyIsValid and bodyShadowIsValid and isEnabled then
			local CT = SysTime()

			if body.Callback then
				local getCallbacks = body:GetCallbacks("BuildBonePositions")

				if not getCallbacks[body.Callback] then
					buildBonePosition()
				end
			else
				buildBonePosition()
			end

			for i = 1, SHADOWS_COUNT do
				local self = plyTable[SHADOW_KEYS[i]]
				if IsValid(self) and self.Callback then
					local getCallbacks = self:GetCallbacks("BuildBonePositions")

					if not getCallbacks[self.Callback] then
						shadow_buildBonePosition(i)
					end
				else
					shadow_buildBonePosition(i)
				end
			end

			local bodyGroups = ply:GetBodyGroups()
			local shadowsIsRendered = lastShadowRender >= SysTime()
			
			for k = 1, #bodyGroups do
				local id = bodyGroups[k].id
				local bg = GetBodygroup(ply, id)
	
				SetBodygroup(body, id, bg)
				SetBodygroup(bodyNoDraw, id, bg)
	
				if shadowsIsRendered then
					for i = 1, SHADOWS_COUNT do
						local self = plyTable[SHADOW_KEYS[i]]
						if not IsValid(self) then goto skip end
						SetBodygroup(self, id, bg)
						::skip::
					end
				end
			end
		end	
	end

	hook.Add("Tick", "cl_body.SlowProcess", processTick)

	local flexWeights = {}
	local copyInfo = function(body, bodyNoDraw)
		SetLOD(body, 0)
		SetCycle(body, GetCycle(ply))
		SetPlaybackRate(body, GetPlaybackRate(ply))
		SetSkin(body, GetSkin(ply))
		SetMaterial(body, GetMaterial(ply))

		SetFlexScale(body, GetFlexScale(ply))

		local flexNum = GetFlexNum(ply) - 1
		for i = 0, flexNum do
			local w = GetFlexWeight(ply, i)
			flexWeights[i] = w
			SetFlexWeight(body, i, w)
		end

		local plyTable = GetTable(ply)
		local shadowsIsRendered = lastShadowRender >= SysTime()
		if shadowsIsRendered then
			for i = 1, SHADOWS_COUNT do
				local self = plyTable[SHADOW_KEYS[i]]
				if not IsValid(self) then goto skip end
				for i = 0, flexNum do
					SetFlexWeight(self, i, flexWeights[i])
				end
				::skip::
			end
		end

		local mdlScale = GetModelScale(ply)
		SetModelScale(body, mdlScale)
		SetModelScale(bodyNoDraw, mdlScale)
		SetRenderBounds(body, fuckedMins, fuckedMaxs)
	end

	local triggerBodyCreation = function()
		local plyTable = GetTable(ply)
		local current = plyTable.wardrobe or GetModel(ply)
		local currentSequence = ply:GetSequence()

		if oldSeq ~= currentSequence then
			oldSeq = currentSequence

			local currentSequenceName = ply:GetSequenceName(currentSequence)

			if currentSequenceName == oldSequenceName then
				removeAll()
			end

			oldSequenceName = currentSequenceName
			boneNameCache, boneCountCache, boneRemapCache, boneIndexCache, garbageBoneCache = {}, {}, {}, {}, {}
		end

		if not erroredModels[current]
			and (not IsValid(plyTable.Body)
			or GetModel(plyTable.Body) ~= current) then
			removeAll()

			plyTable.Body = ents.CreateClientProp(current)
			plyTable.Body:SetModel(current)
			plyTable.Body:DestroyShadow()
			plyTable.Body:SetIK(false)
			plyTable.Body:PhysicsDestroy()
			SetupBones(plyTable.Body)
			plyTable.Body.GetPlayerColor = function()
				return ply:GetPlayerColor()
			end

			plyTable.Body_NoDraw = ents.CreateClientProp(current)
			plyTable.Body_NoDraw:SetModel(current)
			plyTable.Body_NoDraw:SetNoDraw(true)
			plyTable.Body_NoDraw:SetIK(false)
			plyTable.Body_NoDraw:PhysicsDestroy()
			plyTable.Body_NoDraw.GetPlayerColor = function()
				return ply:GetPlayerColor()
			end

			hook.Add("RenderScene", "cl_body.FastBodyInitialize", function()
				if not IsValid(plyTable.Body)
					or not IsValid(plyTable.Body_NoDraw) then
					return
				end
				
				hook.Remove("RenderScene", "cl_body.FastBodyInitialize")
 
				local seq = plyTable.Body:LookupSequence("idle_all_01") or 0

				if seq < 0 then
					seq = plyTable.Body:LookupSequence("idle_all_02") or 0

					if seq < 0 then
						seq = plyTable.Body:LookupSequence("idle1") or 0

						if seq < 0 then
							MarkToRemove(plyTable.Body)
							erroredModels[current] = true
							chat.AddText(Color(230, 30, 30), L"[Тело от первого лица] Текущая модель не имеет анимаций, выберите другую модель для показа тела от 1 лица.")
							return
						end
					end
				end
				
				plyTable.Body_NoDraw:SetSequence(seq)
				changeRenderOverrideFunction()
				bonesFastLookup, bonesFastName = {}, {}
				boneNameCache, boneCountCache, boneRemapCache, boneIndexCache, garbageBoneCache = {}, {}, {}, {}, {}
				limit_check = -1
			end)

			for i = 1, SHADOWS_COUNT do
				local bodyShadowName = "Body_Shadow_" .. i

				plyTable[bodyShadowName] = ents.CreateClientProp(current)
				plyTable[bodyShadowName]:SetModel(current)
				plyTable[bodyShadowName]:SetIK(false)
				plyTable[bodyShadowName]:PhysicsDestroy()
				plyTable[bodyShadowName].RenderOverride = function(self, flags)
					local isResolvedDepth = bit.band(flags, STUDIO_SSAODEPTHTEXTURE) ~= 0
					if isResolvedDepth then return end -- gshaders https://steamcommunity.com/id/amede/

					local RT = render_GetRenderTarget()
					if not RT then DestroyShadow(self) return end -- WTF, фикс для RT прицелов в оружках
					if i ~= 1 or lastShadowRender < SysTime() then
						return -- тени не наслаиваются в проджектах, поэтому смысла нагружать нет
					end

					local RTname = GetName(RT)
					if RTname ~= "_rt_shadowdummy" then return end

					local foundedLamp = false
					trace_array.start = EyePos() -- откуда идёт проджектайл
					trace_array.endpos = GetPos(ply) -- где игрок находится
					trace_array.ignoreworld = DistToSqr(trace_array.start, trace_array.endpos) < RENDERTARGET_SHADOW_LIMIT_DISTANCE -- вблизи фонарика иногда может отображаться тень тела
					local tr = TraceHull(trace_array) -- TraceLine по какой-то причине ёбу даёт и пропускает фонарь игрока
					if tr.Entity:IsPlayer() then return end
					local oldBlend = getBlend()
					setBlend(0)
					DrawModel(self)
					setBlend(oldBlend)
				end
			end

			plyTable.Body.FullyLoaded, timeCacheBones, localPelvisZ, timeCache = false, 0, nil, -1
		end	
	end
	hook.Add("Think", "body.Think", triggerBodyCreation)

	local lastChangeRenderOverride = -1
	local faggotMini = Vector()
	local crouchOffset = Vector()
	hook.Add("RenderScene", "firstperson.RenderScene", function(vec, ang)
		eyePos, ply_EyePos = vec, ply:EyePos()
		eyeAngles = ply:EyeAngles()
		eyeAngles.p = 0

		isDucking = bit.band(GetFlags(ply), FL_ANIMDUCKING) > 0
			and onGround

		local FT = FrameTime()
		local plyTable = GetTable(ply)
		local body = plyTable.Body
		local bodyNoDraw = plyTable.Body_NoDraw

		plyTable.TimeToDuck = math_Clamp((plyTable.TimeToDuck or 0) + FT * 3.5 * (isDucking and 1 or -1), 0, 1)
		realEyeAngles = ang * 1
		forward = Forward(eyeAngles) * getForwardDistance() - Right(eyeAngles) * xOffset

		if suppress or not IsValid(body) then
			lastShadowRender = -1
			return
		end

		local getPos = GetPos(ply)
		local getView = GetViewOffset(ply)

		SetParent(body, ply)
		-- это очень хуёвый фикс темноты в небе когда в воду погружаешься
		SetPos(body, vec + Forward(realEyeAngles) * 40 + Up(realEyeAngles) * 24)

		copyInfo(body, bodyNoDraw)

		local currentView = GetCurrentViewOffset(ply)
		local onGround = OnGround(ply)

		plyTable.TimeToFaggot = math_Clamp((plyTable.TimeToFaggot or 0) + FT * (Crouching(ply) and 4 or 10000) * (not onGround and 1 or -1), 0, 1)
		plyTable.TimeToCrouch = math_Clamp(((plyTable.TimeToCrouch or 0) + FT * (isDucking and 4 or -4) * 2) * (1 - plyTable.TimeToFaggot), 0, 1)

		faggotMini.z = getView.z - currentView.z
		faggot = (not onGround or limitJump > CurTime()) and faggotMini or vector_origin

		Set(vector_fixCrouch, faggot)
		Mul(vector_fixCrouch, plyTable.TimeToFaggot)

		if not inVehicleCached then
			local gPosForward = getPos - forward
			local bodyNoDraw_Pelvis = CachedLookupBone(bodyNoDraw, "ValveBiped.Bip01_Pelvis")

			if not localPelvisZ then
				SetPos(bodyNoDraw, gPosForward)
				SetupBones(bodyNoDraw)

				if bodyNoDraw_Pelvis then
					local matrix = GetBoneMatrix(bodyNoDraw, bodyNoDraw_Pelvis)
					if matrix then
						localPelvisZ = GetTranslation(matrix).z - gPosForward.z
					end
				end
			end

			Body_NoDraw_Pos_Z_SpineIdleAnim = gPosForward.z + (localPelvisZ or 0)

			crouchOffset.z = (Body_NoDraw_Pos_Z_SpineIdleAnim - Body_NoDraw_Pos_Z) * plyTable.TimeToCrouch
			Sub(gPosForward, crouchOffset)

			SetPos(bodyNoDraw, gPosForward)
			SetAngles(bodyNoDraw, eyeAngles - Body_NoDraw_Angle)
			SetupBones(bodyNoDraw)

			if bodyNoDraw_Pelvis then
				local matrix = GetBoneMatrix(bodyNoDraw, bodyNoDraw_Pelvis)
				if matrix then
					localPelvisZ = GetTranslation(matrix).z - gPosForward.z
				end
			end

			SetAngles(body, eyeAngles)
		end

		local currentHash = tostring(body.RenderOverride)
		if body.RenderOverrideHash ~= nil and currentHash ~= body.RenderOverrideHash then
			if (SysTime() - lastChangeRenderOverride) > 0.1 then
				removeAll()
				lastChangeRenderOverride = SysTime()
			else
				body.RenderOverrideHash = currentHash
			end
		end
	end)
	concommand.Add("cl_gm_body_refresh", removeAll)

	hook.Add("PreDrawBody", "cl_body.PreDrawBody_Compat", function()
		if (GMinimap and GMinimap.radar and GMinimap.radar.capturing) -- patch by https://steamcommunity.com/profiles/76561198135201177
			or VWallrunning
			or inmantle
			or (VMLegs and VMLegs:IsActive())
			or (ply.StopKick or 0) > CurTime() then
			return false
		end
	end)

	local checkGamemode = function()
		if GAMEMODE and GAMEMODE.Name then
			if GAMEMODE.Name:find("Prop Hunt", 1, true) then
				hook.Add("PreDrawBody", "cl_body.PropHuntCompat", function()
					if ply:Team() == 2 then return false end
				end)
			end

			if GAMEMODE.Name:find("Beatrun", 1, true) then
				hook.Add("PreDrawBody", "cl_body.BeatrunCompat", function()
					return false
				end)
			end
		end
	end
	checkGamemode()
	hook.Add("PostGamemodeLoaded", "cl_body.PropHuntCompat", checkGamemode)
end)

hook.Add("Think", "cl_body.Load", function()
	local ply = LocalPlayer()

	if E_IsValid(ply) then
		hook.Remove("Think", "cl_body.Load")
		hook_Run("LocalPlayer_Validated", ply)

		local currentGetPos = ply:GetPos()
		local foundedRequiredAddons = DynamicPlayerHeight
			or DynamicHeightTwo
			or DynamicCameraHullViewCL

		if not foundedRequiredAddons then
			if cookie.GetNumber("cl_body.NotifyAboutDynamicPlayerHeight", 0) == 1 then return end

			hook.Add("Think", "cl_body.NotifyAboutDynamicPlayerHeight", function()
				if currentGetPos:DistToSqr(ply:GetPos()) < 96*96 then return end

				hook.Remove("Think", "cl_body.NotifyAboutDynamicPlayerHeight")
				cookie.Set("cl_body.NotifyAboutDynamicPlayerHeight", 1)
				chat.AddText(Color(50, 230, 30), "==================================")
				chat.AddText(Color(230, 30, 30), L"[Тело от первого лица] Не найден необходимый аддон Dynamic Player Height. Вы, конечно, можете играть и без него, но тело от первого лица будет выглядеть немного убого.")
				chat.AddText(Color(130, 130, 230), "Dynamic Player Height: https://steamcommunity.com/sharedfiles/filedetails/?id=3610361244")
				chat.AddText(Color(50, 230, 30), "==================================")
				surface.PlaySound("friends/message.wav")
			end)
		else
			cookie.Set("cl_body.NotifyAboutDynamicPlayerHeight", 0)
		end
	end
end)