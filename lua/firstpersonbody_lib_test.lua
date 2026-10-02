-- ===========================================================================
-- HL2SB First Person Body engine-contract test (2026-10-03).
--
-- Client console, in a map with the local player spawned:
--   lua_dofile_cl  firstpersonbody_lib_test.lua
--
-- Covers every binding the legs addon leans on that this round fixed or
-- added: STUDIO_* draw-flag globals, render.EnableClipping's previous-state
-- return, the colour modulation/blend quartet, Player:ShouldDrawLocalPlayer,
-- the standing/current view-offset pair, Entity:GetBodygroups, the
-- SetBoneMatrix write-through, per-bone ManipulateBonePosition/Scale, and
-- the RenderOverride script field.
-- ===========================================================================

local passed, failed = 0, 0
local function check( name, ok )
  if ( ok ) then
    passed = passed + 1
    print( "[fpb ok] " .. name )
  else
    failed = failed + 1
    print( "[fpb FAIL] " .. name )
  end
end

-- 1. draw-flag globals (bit.band on these gated the shadow copies before)
check( "STUDIO_RENDER = 1", STUDIO_RENDER == 1 )
check( "STUDIO_SHADOWDEPTHTEXTURE = 0x40000000", STUDIO_SHADOWDEPTHTEXTURE == 0x40000000 )
check( "STUDIO_SSAODEPTHTEXTURE = 0x08000000", STUDIO_SSAODEPTHTEXTURE == 0x08000000 )
check( "bit.band accepts the flags", bit.band( STUDIO_RENDER + STUDIO_SHADOWDEPTHTEXTURE, STUDIO_SHADOWDEPTHTEXTURE ) ~= 0 )

-- 2. clipping state round-trip
local prev = render.EnableClipping( true )
check( "EnableClipping returns a boolean", isbool( prev ) )
check( "EnableClipping restores", render.EnableClipping( prev ) == true )
check( "SetClippingEnabled alias exists", isfunction( render.SetClippingEnabled ) )

-- 3. modulation / blend quartet
check( "SetColorModulation exists", isfunction( render.SetColorModulation ) )
check( "SetBlend exists", isfunction( render.SetBlend ) )
check( "GetBlend exists", isfunction( render.GetBlend ) )
check( "GetBlend returns a number", isnumber( render.GetBlend() ) )
check( "GetColorModulation exists", isfunction( render.GetColorModulation ) )
render.SetColorModulation( 0.5, 0.25, 1 )
local r, g, b = render.GetColorModulation()
check( "GetColorModulation returns 3 numbers", isnumber( r ) and isnumber( g ) and isnumber( b ) )
check( "modulation round-trips", math.abs( r - 0.5 ) < 0.01 and math.abs( g - 0.25 ) < 0.01 and math.abs( b - 1 ) < 0.01 )
render.SetColorModulation( 1, 1, 1 )
local blend = render.GetBlend()
render.SetBlend( 0.5 )
check( "SetBlend round-trips", math.abs( render.GetBlend() - 0.5 ) < 0.01 )
render.SetBlend( blend )

-- 4. player methods
local ply = LocalPlayer and LocalPlayer()
check( "local player found", IsValid( ply ) )
if ( ply ) then
  check( "ShouldDrawLocalPlayer returns a boolean", isbool( ply:ShouldDrawLocalPlayer() ) )

  local standing = ply:GetViewOffset()
  local current = ply:GetCurrentViewOffset()
  check( "GetViewOffset is a Vector", standing and standing.z ~= nil )
  check( "GetCurrentViewOffset is a Vector", current and current.z ~= nil )
  check( "standing offset is ~64", math.abs( standing.z - 64 ) < 2 )

  local groups = ply:GetBodygroups()
  check( "GetBodygroups returns a table", istable( groups ) )
  local first = groups and groups[1]
  check( "bodygroup rows carry id/name/num",
    first == nil or ( isnumber( first.id ) and isstring( first.name ) and isnumber( first.num ) ) )
end

-- 5. bone write-through on a clientside model
local mdl = ply and ply:GetModel() or "models/player/kleiner.mdl"
local body = ents.CreateClientProp( mdl )
check( "CreateClientProp created a body", IsValid( body ) )
if ( IsValid( body ) ) then
  body:SetNoDraw( true ) -- nothing leaks into the view while testing

  body:ManipulateBonePosition( 0, Vector( 3, 4, 5 ) )
  body:ManipulateBoneScale( 0, Vector( 0.5, 0.5, 0.5 ) )
  body:SetupBones()

  local mat = body:GetBoneMatrix( 0 )
  check( "GetBoneMatrix after manipulation", mat ~= nil )

  if ( mat ) then
    -- ManipulateBonePosition applied immediately: probe the translation by
    -- comparing against a fresh offset delta.
    local before = mat:GetTranslation()
    body:ManipulateBonePosition( 0, Vector( 13, 0, 0 ) )
    local after = body:GetBoneMatrix( 0 ):GetTranslation()
    check( "ManipulateBonePosition moves the bone", after.x - before.x > 10 )
  end

  local write = Matrix()
  write:SetTranslation( Vector( 100, 200, 300 ) )
  body:SetBoneMatrix( 0, write )
  local readBack = body:GetBoneMatrix( 0 )
  check( "SetBoneMatrix writes through",
    readBack ~= nil and math.abs( readBack:GetTranslation().x - 100 ) < 0.01
    and math.abs( readBack:GetTranslation().y - 200 ) < 0.01
    and math.abs( readBack:GetTranslation().z - 300 ) < 0.01 )

  -- 6. the RenderOverride script field is storable and stays callable
  local overrideCalled = false
  body.RenderOverride = function( self, flags )
    overrideCalled = true
  end
  check( "RenderOverride field stored", isfunction( body.RenderOverride ) )
  body.RenderOverride( body, STUDIO_RENDER )
  check( "RenderOverride callable", overrideCalled )

  -- clean up (the manipulation side table follows the entity handle)
  body:Remove()
end

print( string.format( "[fpb test] %d passed, %d failed", passed, failed ) )
if ( failed > 0 ) then print( "[fpb test] FAILURES PRESENT" ) end
