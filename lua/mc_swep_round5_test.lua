-- Run on the server after restarting the game:
-- lua_dofile mc_swep_round5_test.lua

if not SERVER then
    error("mc_swep_round5_test.lua requires the server realm")
end

local passed, failed = 0, 0
local created = {}

local function check(name, test)
    local ok, err = pcall(test)
    if ok then
        passed = passed + 1
        print("[mc round5 OK] " .. name)
    else
        failed = failed + 1
        print("[mc round5 FAIL] " .. name .. ": " .. tostring(err))
    end
end

local function create(classname)
    local ent = ents.Create(classname)
    assert(IsValid(ent), "cannot create " .. classname)
    created[#created + 1] = { entity = ent, classname = classname }
    return ent
end

local function near(a, b)
    return math.abs(a - b) < 0.002
end

local function sameVector(a, b)
    return near(a.x, b.x) and near(a.y, b.y) and near(a.z, b.z)
end

check("GetClass aliases and case sensitivity", function()
    local ent = create("info_target")
    local cases = {
        { "ai_hint", "hint" },
        { "ai_", "" },
        { "AI_hint", "AI_hint" },
        { "prop_vehicle_jeep_old", "prop_vehicle_jeep" },
        { "prop_vehicle_jeep_old_extra", "prop_vehicle_jeep_old_extra" },
        { "minecraft_block", "minecraft_block" }
    }
    for _, case in ipairs(cases) do
        ent:SetClassname(case[1])
        assert(ent:GetClass() == case[2], case[1])
        assert(ent:GetClassname() == case[1], "raw classname changed")
    end
    ent:SetClassname("info_target")
end)

check("SetRenderMode clamps and accepts fractional numbers", function()
    local ent = create("info_target")
    local cases = { { -99, 0 }, { 99, 10 }, { 4.75, 4 }, { 4, 4 } }
    for _, case in ipairs(cases) do
        ent:SetRenderMode(case[1])
        assert(ent:GetInternalVariable("m_nRenderMode") == case[2], tostring(case[1]))
    end
end)

check("GetMoveCollide reads the engine value", function()
    local ent = create("info_target")
    ent:SetMoveType(MOVETYPE_FLY, 1)
    assert(ent:GetMoveCollide() == 1)
    ent:SetMoveCollide(0)
    assert(ent:GetMoveCollide() == 0)
end)

check("SetSkin ignores valid non-animating entities", function()
    local ent = create("info_target")
    ent:SetSkin(3)
    ent:SetSkin({})
    assert(ent:GetSkin() == 0)
end)

check("GetViewModel clamps to the engine's two slots", function()
    local ply = player.GetAll()[1]
    assert(IsValid(ply), "a player must be in the map")
    local function id(vm)
        return IsValid(vm) and vm:EntIndex() or -1
    end
    local firstModel = ply:GetViewModel(0)
    assert(IsValid(firstModel), "the default viewmodel must exist")
    local first = id(firstModel)
    local last = id(ply:GetViewModel(1))
    assert(id(ply:GetViewModel()) == first)
    assert(id(ply:GetViewModel(-99)) == first)
    assert(id(ply:GetViewModel(0.75)) == first)
    assert(id(ply:GetViewModel({})) == first)
    assert(id(ply:GetViewModel(99)) == last)
    assert(id(ply:GetViewModel(1e100)) == last)
end)

local function physicsBox(mins, maxs, expectedMins, expectedMaxs, expectedMass)
    local ent = create("prop_physics")
    local origin = Vector(128, 256, 384)
    ent:SetModel("models/props_junk/wood_crate001a.mdl")
    ent:SetPos(origin)
    ent:Spawn()
    local beforeMins = Vector(mins.x, mins.y, mins.z)
    local beforeMaxs = Vector(maxs.x, maxs.y, maxs.z)
    local returned = ent:PhysicsInitBox(mins, maxs)
    local phys = ent:GetPhysicsObject()
    assert(IsValid(phys), "no physics object")
    assert(IsValid(returned), "fork physics-object return changed")
    assert(sameVector(mins, beforeMins) and sameVector(maxs, beforeMaxs), "input vectors mutated")
    assert(sameVector(ent:OBBMins(), expectedMins), "wrong local mins")
    assert(sameVector(ent:OBBMaxs(), expectedMaxs), "wrong local maxs")
    assert(sameVector(ent:GetPos(), origin), "entity origin moved")
    assert(sameVector(phys:GetPos(), origin), "physics origin moved")
    assert(near(phys:GetMass(), expectedMass), "mass = " .. tostring(phys:GetMass()))
    ent:SetSkin(2.75)
    assert(ent:GetSkin() == 2, "animating skin round trip")
end

check("PhysicsInitBox normalizes each reversed axis", function()
    physicsBox(Vector(3, -4, 8), Vector(-3, 4, -8),
        Vector(-3, -4, -8), Vector(3, 4, 8), 7.68)
end)

check("PhysicsInitBox uses volume for Minecraft-sized boxes", function()
    physicsBox(Vector(-18.25, -18.25, -18.25), Vector(18.25, 18.25, 18.25),
        Vector(-18.25, -18.25, -18.25), Vector(18.25, 18.25, 18.25), 486.27125)
end)

check("PhysicsInitBox expands a point and respects the mass floor", function()
    physicsBox(Vector(7, 8, 9), Vector(7, 8, 9),
        Vector(-1, -1, -1), Vector(1, 1, 1), 1)
end)

for _, item in ipairs(created) do
    if IsValid(item.entity) then
        item.entity:SetClassname(item.classname)
        item.entity:Remove()
    end
end

print(string.format("[mc round5] %d passed, %d failed", passed, failed))
