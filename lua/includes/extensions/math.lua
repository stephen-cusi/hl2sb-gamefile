--[[---------------------------------------------------------------------------
    HL2SB math extension.

    GMod's math.lua is a large helper kitchen.  We port the subset that
    HL2SB scripts (and the ported draw.lua) actually use, using HL2SB's Lua
    5.1 style (no LuaJIT, no __unpack tricks).  Functions are added straight
    onto the standard math table so existing HL2SB code keeps working.

    These are the pieces draw.lua relies on (Round/Clamp) plus a few more
    that are ubiquitous in GMod HUD/exposed-only code.
---------------------------------------------------------------------------]]

require( "math" )

local math = math

local floor   = math.floor
local ceil    = math.ceil
local abs     = math.abs
local max     = math.max
local min     = math.min
local random  = math.random
local huge    = math.huge

-------------------------------------------------------------------------------
-- Round(x) -> nearest integer (0.5 rounds up, matches GMod).
-------------------------------------------------------------------------------
function math.Round( x )
  if ( x == 0 ) then return 0 end
  if ( x < 0 ) then return ceil( x - 0.5 ) end
  return floor( x + 0.5 )
end

-------------------------------------------------------------------------------
-- Clamp(x, min, max)
-------------------------------------------------------------------------------
function math.Clamp( x, mn, mx )
  if ( mn == nil ) then mn = 0 end
  if ( mx == nil ) then mx = 1 end
  if ( x < mn ) then return mn end
  if ( x > mx ) then return mx end
  return x
end

-------------------------------------------------------------------------------
-- Sign(x) -> -1 / 0 / 1
-------------------------------------------------------------------------------
function math.Sign( x )
  if ( x > 0 ) then return 1 end
  if ( x < 0 ) then return -1 end
  return 0
end

-------------------------------------------------------------------------------
-- Approach(x, target, step): move x toward target by at most step.
-------------------------------------------------------------------------------
function math.Approach( x, target, step )
  if ( x < target ) then
    return min( x + step, target )
  elseif ( x > target ) then
    return max( x - step, target )
  end
  return target
end

-------------------------------------------------------------------------------
-- Remap(x, in_min, in_max, out_min, out_max)
-------------------------------------------------------------------------------
function math.Remap( x, inMin, inMax, outMin, outMax )
  local t = ( x - inMin ) / ( inMax - inMin )
  return outMin + ( outMax - outMin ) * t
end

-------------------------------------------------------------------------------
-- EaseInOut(t) (0..1), a smoothstep-ish curve.
-------------------------------------------------------------------------------
function math.EaseInOut( t )
  if ( t <= 0 ) then return 0 end
  if ( t >= 1 ) then return 1 end
  return -0.5 * ( math.cos( t * math.pi ) - 1 )
end

-------------------------------------------------------------------------------
-- IsNearlyEqual(a, b, epsilon)
-------------------------------------------------------------------------------
function math.IsNearlyEqual( a, b, epsilon )
  epsilon = epsilon or 0.0001
  return abs( a - b ) <= epsilon
end

-- Load marker (console + ds_debug.log), for confirming the extension ran.
print( "[HL2SB] math extension loaded" )
