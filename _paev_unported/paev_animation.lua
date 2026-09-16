--[[
    PAEV - Player Animation Engine
    核心动画引擎 (共享文件, 客户端和服务器都会执行)

    使用的都是 GMod 官方文档记录的动画相关钩子:
      - GM:CalcMainActivity(ply, velocity)
      - GM:TranslateActivity(ply, act)
      - GM:DoAnimationEvent(ply, event, data)
    参考: https://wiki.facepunch.com/gmod/Player_Animation

    注意: 不同底层武器基类(base weapon)声明的 HoldType 字符串、
    以及部分 ACT_ 枚举名可能因 GMod 版本略有差异。代码里所有查表
    都做了 nil 检查,查不到就静默跳过、不会报错,建议实际进游戏
    测试后按需在 paev_config.lua 里补充映射。
]]

PAEV = PAEV or {}
PAEV.PlayerState = PAEV.PlayerState or {}

-- 两套动作枚举, 分别对应老式 HL2MP 骨架和新式 CS:S 骨架
local ACT_SETS = {
    citizen = {
        idle        = ACT_HL2MP_IDLE,
        idle_crouch = ACT_HL2MP_IDLE_CROUCH,
        walk        = ACT_HL2MP_WALK,
        run         = ACT_HL2MP_RUN,
        crouchwalk  = ACT_HL2MP_WALK_CROUCH,
        jump        = ACT_HL2MP_JUMP,
        swim_idle   = ACT_HL2MP_SWIM_IDLE or ACT_HL2MP_IDLE,
        swim        = ACT_HL2MP_SWIM or ACT_HL2MP_WALK,
    },
    css = {
        idle        = ACT_MP_STAND_IDLE,
        idle_crouch = ACT_MP_CROUCH_IDLE,
        walk        = ACT_MP_WALK,
        run         = ACT_MP_RUN,
        crouchwalk  = ACT_MP_CROUCHWALK,
        jump        = ACT_MP_JUMP,
        swim_idle   = ACT_MP_SWIM_IDLE,
        swim        = ACT_MP_SWIM,
    },
}

-- 武器持握方式后缀映射, 用来把"站立/行走/奔跑"替换成"持枪站立/持枪行走..."
-- 对应的具体 ACT_xxx_PISTOL / ACT_xxx_AR2 等枚举由 TranslateActivity 里拼接查找
local HOLDTYPE_SUFFIX = {
    pistol   = "_PISTOL",
    smg      = "_SMG1",
    ar2      = "_AR2",
    shotgun  = "_SHOTGUN",
    rpg      = "_RPG",
    physgun  = "_PHYSGUN",
    crossbow = "_CROSSBOW",
    grenade  = "_GRENADE",
    melee    = "_MELEE",
    melee2   = "_MELEE2",
    slam     = "_SLAM",
    knife    = "_KNIFE",
    duel     = "_PISTOL",
    revolver = "_REVOLVER",
    magic    = "_PISTOL",
    fist     = "_PASSIVE",
    camera   = "_PASSIVE",
    passive  = "_PASSIVE",
    normal   = "",
}

-- HL2SB: built with a nil check per entry.  A bare
--     [ACT_MP_STAND_IDLE] = "..."
-- throws "table index is nil" and kills this whole file when any one of those
-- globals is not published by the engine.
local BASE_ACT_NAMES = {}
local function MapAct( act, name )
    if ( act ~= nil ) then
        BASE_ACT_NAMES[ act ] = name
    end
end

MapAct( ACT_MP_STAND_IDLE,     "ACT_MP_STAND_IDLE" )
MapAct( ACT_MP_WALK,           "ACT_MP_WALK" )
MapAct( ACT_MP_RUN,            "ACT_MP_RUN" )
MapAct( ACT_MP_CROUCH_IDLE,    "ACT_MP_CROUCH_IDLE" )
MapAct( ACT_MP_CROUCHWALK,     "ACT_MP_CROUCHWALK" )
MapAct( ACT_MP_JUMP,           "ACT_MP_JUMP" )
MapAct( ACT_HL2MP_IDLE,        "ACT_HL2MP_IDLE" )
MapAct( ACT_HL2MP_WALK,        "ACT_HL2MP_WALK" )
MapAct( ACT_HL2MP_RUN,         "ACT_HL2MP_RUN" )
MapAct( ACT_HL2MP_IDLE_CROUCH, "ACT_HL2MP_IDLE_CROUCH" )
MapAct( ACT_HL2MP_WALK_CROUCH, "ACT_HL2MP_WALK_CROUCH" )
MapAct( ACT_HL2MP_JUMP,        "ACT_HL2MP_JUMP" )

local function GetPlayerAnimSet(ply)
    local class = PAEV.GetModelClass(ply:GetModel())
    return ACT_SETS[class] or ACT_SETS.citizen, class
end

-- 每个玩家的动画状态机数据 (预留字段, 方便以后扩展落地缓冲/预测摇摆等)
local function GetState(ply)
    local st = PAEV.PlayerState[ply]
    if not st then
        st = { wasInAir = false }
        PAEV.PlayerState[ply] = st
    end
    return st
end

hook.Add("PlayerDisconnected", "PAEV_CleanupState", function(ply)
    PAEV.PlayerState[ply] = nil
end)

-- ============================================================
-- 1. 主动作计算: 站立 / 行走 / 奔跑 / 蹲伏 / 游泳 / 跳跃
--    同时驱动移动方向混合参数, 让转身和斜向移动的动画更自然
-- ============================================================
hook.Add("CalcMainActivity", "PAEV_CalcMainActivity", function(ply, velocity)
    local set = GetPlayerAnimSet(ply)
    local state = GetState(ply)

    local speed = hl2sb_Velocity2D(velocity)
    local onGround = hl2sb_IsOnGround(ply)
    local inWater = ply:WaterLevel() >= 2
    local crouching = hl2sb_IsCrouching(ply)

    if speed > 1 then
        local moveYaw = math.NormalizeAngle(hl2sb_VelocityYaw(velocity) - hl2sb_EyeYaw(ply))
        ply:SetPoseParameter("move_yaw", moveYaw)
        ply:SetPoseParameter("move_x", math.cos(math.rad(moveYaw)) * math.Clamp(speed / 200, 0, 1))
        ply:SetPoseParameter("move_y", math.sin(math.rad(moveYaw)) * math.Clamp(speed / 200, 0, 1))
    end

    state.wasInAir = not onGround

    if inWater then
        return speed > 10 and set.swim or set.swim_idle
    end

    if not onGround then
        return set.jump
    end

    if crouching then
        return speed > 10 and set.crouchwalk or set.idle_crouch
    end

    if speed > 210 then
        return set.run
    elseif speed > 10 then
        return set.walk
    end

    return set.idle
end)

-- ============================================================
-- 2. 根据手持武器类型替换动作 (站立/行走/奔跑 -> 持械版本)
-- ============================================================
hook.Add("TranslateActivity", "PAEV_TranslateActivity", function(ply, act)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end

    local holdtype = wep.HoldType or (wep.GetHoldType and wep:GetHoldType()) or "normal"
    local suffix = HOLDTYPE_SUFFIX[holdtype]
    if not suffix or suffix == "" then return end

    local baseName = BASE_ACT_NAMES[act]
    if not baseName then return end

    local newAct = _G[baseName .. suffix]
    if newAct then
        return newAct
    end
end)

-- ============================================================
-- 3. 特殊动画事件 (起跳等), 可在这里扩充自定义手势动画
-- ============================================================
hook.Add("DoAnimationEvent", "PAEV_DoAnimationEvent", function(ply, event, data)
    if event == PLAYERANIMEVENT_JUMP then
        local seq = ply.LookupSequence and ply:LookupSequence("jump") or -1
        if seq and seq > 0 then
            hl2sb_GestureSequence(ply, GESTURE_SLOT_JUMP, seq, 0, true)
        end
        return ACT_MP_JUMP
    end
    -- 返回 nil 交给游戏默认处理其余事件 (换弹/开火手势等)
end)

-- ============================================================
-- 4. 玩家模型切换后重置状态 + 打开脚部 IK
-- ============================================================
hook.Add("PAEV_PlayerModelChanged", "PAEV_OnModelChanged", function(ply)
    PAEV.PlayerState[ply] = nil
    hl2sb_SetIK(ply, true)
end)

hook.Add("PlayerSpawn", "PAEV_InitAnim", function(ply)
    hl2sb_SetIK(ply, true)
end)
