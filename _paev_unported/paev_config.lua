--[[
    PAEV - Player Animation Engine
    共享配置文件 (客户端 + 服务器都会自动加载)
]]

PAEV = PAEV or {}
PAEV.Version = "1.0.0"

-- ============================================================
-- 可选玩家模型列表 (显示在选择菜单里)
-- 下面这些路径都是 GMod / Half-Life 2 自带内容,不需要额外下载模型
-- 带 [CSS] 标记的条目需要服务器/客户端挂载 Counter-Strike: Source 内容,
-- 如果没有挂载,把这几行删掉即可
-- ============================================================
PAEV.PlayerModels = {
    { name = "男性市民 Male 01",     model = "models/humans/group01/male_01.mdl",   class = "citizen" },
    { name = "男性市民 Male 04",     model = "models/humans/group01/male_04.mdl",   class = "citizen" },
    { name = "女性市民 Female 01",   model = "models/humans/group01/female_01.mdl", class = "citizen" },
    { name = "反抗军 Rebel",         model = "models/humans/group02/male_07.mdl",   class = "citizen" },
    { name = "联合军战士 Combine",   model = "models/combine_soldier.mdl",          class = "citizen" },
    { name = "[CSS] Phoenix",        model = "models/player/phoenix.mdl",           class = "css" },
    { name = "[CSS] Leet",           model = "models/player/leet.mdl",              class = "css" },
    { name = "[CSS] SAS",            model = "models/player/sas.mdl",               class = "css" },
    { name = "[CSS] Urban",          model = "models/player/urban.mdl",             class = "css" },
}

-- ============================================================
-- 动画类覆盖表: 不同骨骼结构要用不同的 ACT_ 动作枚举
--   citizen -> 老式 HL2MP 骨架, 使用 ACT_HL2MP_*
--   css     -> CS:S 骨架 (新动画系统), 使用 ACT_MP_*
-- 如果你之后加入自定义模型、发现动作不对,在这里加一条映射即可,
-- 不需要改动引擎逻辑
-- ============================================================
PAEV.ModelClassOverride = {
    -- ["models/myaddon/mymodel.mdl"] = "citizen",
}

function PAEV.GetModelClass(mdl)
    if not mdl then return "citizen" end
    mdl = string.lower(mdl)

    if PAEV.ModelClassOverride[mdl] then
        return PAEV.ModelClassOverride[mdl]
    end

    for _, entry in ipairs(PAEV.PlayerModels) do
        if string.lower(entry.model) == mdl then
            return entry.class
        end
    end

    -- 兜底: 大部分新骨架模型路径都在 models/player/ 下
    if string.find(mdl, "models/player/") then
        return "css"
    end
    return "citizen"
end
