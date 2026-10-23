-- ===========================================================================
-- HL2SB trace result test (2026-09-28).
--
-- Fully restart the game, enter a map (spawn once), then:
--   server console:  lua_dofile  trace_lib_test.lua
--
-- GMod reference facts under test (x64 server.dll shared trace-table builder):
--   * tr.Normal       = normalize(endpos - startpos)  -- the trace DIRECTION,
--                       fallback -plane.normal when the difference is zero
--   * tr.HitNormal    = plane normal (unchanged)
--   * default mask of the table form of util.TraceLine = MASK_SOLID
--   * Player:GetEyeTraceNoCursor().Normal = eye ray direction
--     (scp173 builds its whole vision cone from that one field)
--   * util.TraceLine honors ignoreworld = true (world stops colliding)
-- ===========================================================================

local passed, failed, skipped = 0, 0, 0
local function check( name, ok )
  if ( ok ) then
    passed = passed + 1
    print( "[trace ok] " .. name )
  else
    failed = failed + 1
    print( "[trace FAIL] " .. name )
  end
end
local function skip( name )
  skipped = skipped + 1
  print( "[trace SKIP] " .. name )
end

local ply = player.GetAll()[1]
check( "player found", ply ~= nil )
if ( ply == nil ) then
  print( string.format( "[trace test] %d passed, %d failed, %d skipped", passed, failed, skipped ) )
  return
end

local eye = ply:EyePos()

-- 1) A diagonal ray: Normal must equal the ray DIRECTION (collinear), never
--    the impact plane normal.  The old fork answer (plane.normal) was
--    (0,0,1)-ish for a floor hit, which fails this test outright.
local dir = Vector( 1, 0, -0.3 ):GetNormalized()
local start = eye + Vector( 0, 0, 8 )
local tr = util.TraceLine( { start = start, endpos = start + dir * 512 } )
check( "TraceLine returned a result", istable( tr ) or tr ~= nil )
local dotDir = tr.Normal:Dot( dir )
check( string.format( "hit trace Normal is ray direction (dot=%.4f)", dotDir ), dotDir > 0.999 )
check( "Normal is unit length", math.abs( tr.Normal:Length() - 1 ) < 0.001 )

-- 2) HitNormal still exists and (on a real hit) is the plane normal --
--    distinct from Normal whenever the ray is not perpendicular to the face.
if ( tr.Hit ) then
  check( "HitNormal present on hit", tr.HitNormal ~= nil )
  if ( tr.HitNormal ) then
    local nlen = tr.HitNormal:Length()
    check( string.format( "HitNormal is unit length (%.4f)", nlen ), math.abs( nlen - 1 ) < 0.01 )
    check( "HitNormal differs from Normal on a glancing ray",
      tr.Normal:Dot( tr.HitNormal ) < 0.999 )
  end
else
  skip( "diagonal ray missed (odd geometry), HitNormal checks" )
end

-- 3) A guaranteed miss (straight up from the eye): Normal must still be the
--    direction, not (0,0,0) and not a stale plane normal.
local up = Vector( 0, 0, 1 )
local trUp = util.TraceLine( { start = eye, endpos = eye + up * 4096 } )
check( string.format( "miss trace Normal is ray direction (dot=%.4f)", trUp.Normal:Dot( up ) ),
  trUp.Normal:Dot( up ) > 0.999 )

-- 4) THE scp173 input: GetEyeTraceNoCursor().Normal must be the eye ray.
local fwd = ply:EyeAngles():Forward()
local trEye = ply:GetEyeTraceNoCursor()
check( "GetEyeTraceNoCursor returned a result", trEye ~= nil and trEye.Normal ~= nil )
if ( trEye and trEye.Normal ) then
  local d = trEye.Normal:Dot( fwd )
  check( string.format( "eye trace Normal == EyeAngles:Forward (dot=%.4f)", d ), d > 0.999 )
end

-- 5) GetFOV sanity (scp173 scales its cone off this; the chain is
--    m_iFOV -> DefaultFOV -> gamerules 90).
local fov = ply:GetFOV()
check( string.format( "GetFOV in range (%s)", tostring( fov ) ), isnumber( fov ) and fov >= 75 and fov <= 110 )

-- 6) ignoreworld: a downward ray that stops on the world must pass straight
--    through it when ignoreworld = true.
local downStart = eye + Vector( 0, 0, 8 )
local trDown = util.TraceLine( { start = downStart, endpos = downStart - Vector( 0, 0, 10000 ), mask = MASK_SOLID } )
if ( trDown.HitWorld ) then
  local trDown2 = util.TraceLine( {
    start = downStart, endpos = downStart - Vector( 0, 0, 10000 ),
    mask = MASK_SOLID, ignoreworld = true } )
  check( string.format( "ignoreworld passes through world (Hit=%s)", tostring( trDown2.Hit ) ),
    not trDown2.HitWorld )
else
  skip( string.format( "no world under the player (HitWorld=%s)", tostring( trDown.HitWorld ) ) )
end

-- 7) Default mask of the table form is MASK_SOLID: a trace with no "mask"
--    key must not match CONTENTS_DEBRIS where MASK_SOLID would not.  Direct
--    assertion is geometry-dependent; verify the parser answer instead by
--    checking that a mask-less trace behaves identically to MASK_SOLID on
--    the same ray.
local trDefault = util.TraceLine( { start = start, endpos = start + dir * 512 } )
local trSolid = util.TraceLine( { start = start, endpos = start + dir * 512, mask = MASK_SOLID } )
check( "default mask behaves as MASK_SOLID",
  trDefault.Hit == trSolid.Hit and
  trDefault.Fraction == trSolid.Fraction and
  trDefault.Normal:Dot( trSolid.Normal ) > 0.9999 )

print( string.format( "[trace test] %d passed, %d failed, %d skipped", passed, failed, skipped ) )
