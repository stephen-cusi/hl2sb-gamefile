--[[ HL2SB compatibility shim for GMod-style Lua plugins.
     Loaded from lua/autorun/ before paev_*.lua (alphabetical order), so PAEV can
     call the helpers below.  Everything here is pure Lua: it probes for the
     engine API with pcall() because HL2SB entity userdata raises when a NULL
     entity is indexed. ]]

if math.NormalizeAngle == nil then
  function math.NormalizeAngle(a)
    a = math.fmod(a, 360)
    if a > 180 then a = a - 360 elseif a < -180 then a = a + 360 end
    return a
  end
end

if math.Clamp == nil then
  function math.Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
  end
end

if IsValid == nil then
  function IsValid(v)
    if v == nil then return false end
    if type(v) == "userdata" then
      local ok, res = pcall(function() return v.IsValid end)
      if not ok then return false end
      if res == nil then return true end
      if type(res) == "function" then
        local ok2, r2 = pcall(res, v)
        return ok2 and r2 ~= false
      end
      return res ~= false
    end
    return true
  end
end

function hl2sb_IsOnGround(ply)
  if ply == nil then return false end
  if ply.IsOnGround then
    local ok, r = pcall(ply.IsOnGround, ply); if ok then return r and true or false end
  end
  if ply.OnGround then
    local ok, r = pcall(ply.OnGround, ply); if ok then return r and true or false end
  end
  if ply.GetFlags then
    local ok, fl = pcall(ply.GetFlags, ply)
    if ok and fl and FL_ONGROUND ~= nil then return bit.band(fl, FL_ONGROUND) ~= 0 end
  end
  return false
end

function hl2sb_IsCrouching(ply)
  if ply == nil then return false end
  if ply.IsDucking then
    local ok, r = pcall(ply.IsDucking, ply); if ok then return r and true or false end
  end
  if ply.IsFlagSet then
    if FL_ANIMDUCKING ~= nil then
      local ok, r = pcall(ply.IsFlagSet, ply, FL_ANIMDUCKING); if ok and r then return true end
    end
    if FL_DUCKING ~= nil then
      local ok, r = pcall(ply.IsFlagSet, ply, FL_DUCKING); if ok and r then return true end
    end
  end
  if ply.GetFlags then
    local ok, fl = pcall(ply.GetFlags, ply)
    if ok and fl then
      if FL_ANIMDUCKING ~= nil and bit.band(fl, FL_ANIMDUCKING) ~= 0 then return true end
      if FL_DUCKING ~= nil and bit.band(fl, FL_DUCKING) ~= 0 then return true end
    end
  end
  return false
end

function hl2sb_Velocity2D(vel)
  if vel == nil then return 0 end
  local x, y = vel.x or 0, vel.y or 0
  return math.sqrt(x * x + y * y)
end

function hl2sb_VelocityYaw(vel)
  if vel == nil then return 0 end
  return math.deg(math.atan2(vel.y or 0, vel.x or 0))
end

function hl2sb_EyeYaw(ply)
  if ply == nil or ply.EyeAngles == nil then return 0 end
  local ok, a = pcall(ply.EyeAngles, ply)
  if not ok or a == nil then return 0 end
  return a.y or 0
end

function hl2sb_SetIK(ply, on)
  if ply ~= nil and ply.SetIK then pcall(ply.SetIK, ply, on) end
end

function hl2sb_GestureSequence(ply, slot, seq, cycle, autokill)
  if ply == nil or ply.AddVCDSequenceToGestureSlot == nil then return end
  pcall(ply.AddVCDSequenceToGestureSlot, ply, slot, seq, cycle, autokill)
end