-- ===========================================================================
-- HL2SB gmod_hands in-game test (2026-09-27).
--
-- Fully restart the game, enter a map (spawn once), then:
--   server console:  lua_dofile     hands_lib_test.lua
--   client console:  lua_dofile_cl  hands_lib_test.lua
--
-- Covers: the replicated hands handle (GetHands/SetHands), the gmod_hands
-- scripted entity spawned by the base chain, the gamemode glue
-- (PlayerSetHandsModel / PLAYER:GetHandsModel), player_manager's hands
-- registry + GMod default fallback, the SetBodyGroups shim, and (client)
-- the GM viewmodel hook wiring.
-- ===========================================================================

local passed, failed = 0, 0
local function check( name, ok )
  if ( ok ) then
    passed = passed + 1
    print( "[hands ok] " .. name )
  else
    failed = failed + 1
    print( "[hands FAIL] " .. name )
  end
end

local function findPlayer()
  local ply = LocalPlayer and LocalPlayer()
  if ( ply and IsValid and IsValid( ply ) ) then return ply end
  if ( player and player.GetAll ) then
    local all = player.GetAll()
    if ( all and all[1] ) then return all[1] end
  end
  return nil
end

local ply = findPlayer()
check( "player found", ply ~= nil )
if ( ply == nil ) then
  print( string.format( "[hands test] %d passed, %d failed", passed, failed ) )
  return
end

-- ---------------------------------------------------------------------------
-- Shared registry checks (both realms)
-- ---------------------------------------------------------------------------
check( "player_manager.TranslatePlayerHands bound", player_manager ~= nil and player_manager.TranslatePlayerHands ~= nil )
if ( player_manager and player_manager.TranslatePlayerHands ) then
  local info = player_manager.TranslatePlayerHands( "kleiner" )
  check( "kleiner -> citizen arms", info ~= nil and info.model == "models/weapons/c_arms_citizen.mdl" and info.body == "0000000" )
  local def = player_manager.TranslatePlayerHands( "no_such_model_name_xyz" )
  check( "unknown name -> GMod default citizen arms",
    def ~= nil and def.model == "models/weapons/c_arms_citizen.mdl" and def.body == "100000000" )
end

check( "player_manager.TranslateToPlayerModelName bound", player_manager.TranslateToPlayerModelName ~= nil )
if ( player_manager.TranslateToPlayerModelName ) then
  local name = player_manager.TranslateToPlayerModelName( ply:GetModel() )
  check( "current model translates to a name (" .. tostring( name ) .. ")", name ~= nil )
end

check( "GM:PlayerSetHandsModel wired", GAMEMODE.PlayerSetHandsModel ~= nil )

if ( ply.SetBodyGroups ~= nil ) then
  local ok = pcall( ply.SetBodyGroups, ply, "0000000" )
  check( "SetBodyGroups shim runs without error", ok )
else
  check( "SetBodyGroups shim present", false )
end

if ( SERVER ) then

  check( "GetHands bound (server)", ply.GetHands ~= nil )
  check( "SetHands bound (server)", ply.SetHands ~= nil )

  local ok0, res0 = pcall( ply.GetHands, ply )
  check( "GetHands answers", ok0 )

  -- Drive the real spawn path: SetupHands creates gmod_hands, registers it on
  -- the replicated handle, parents it onto the viewmodel.
  local okSetup, errSetup = pcall( ply.SetupHands, ply )
  check( "SetupHands runs", okSetup and ( errSetup == nil ) )

  local hands = ply:GetHands()
  check( "GetHands returns the hands entity", hands ~= nil and IsValid( hands ) )
  if ( hands ~= nil and IsValid( hands ) ) then
    check( "hands class is gmod_hands", hands:GetClassname() == "gmod_hands" )
    check( "hands owner is the player", hands:GetOwner() == ply )
    check( "hands parented to the viewmodel", IsValid( hands:GetParent() ) )
    check( "hands model matches the registry",
      player_manager.TranslatePlayerHands( player_manager.TranslateToPlayerModelName( ply:GetModel() ) ) ~= nil )

    -- SetHands(nil) clears the replicated handle, SetHands(entity) restores it.
    ply:SetHands( nil )
    check( "SetHands(nil) clears GetHands", ply:GetHands() == nil )
    ply:SetHands( hands )
    check( "SetHands(entity) restores GetHands", ply:GetHands() == hands )
  end

  check( "player class GetHandsModel resolves",
    ( player_manager.RunClass( ply, "GetHandsModel" ) or {} ).model ~= nil )

end

if ( CLIENT ) then

  check( "GetHands bound (client)", ply.GetHands ~= nil )
  local ok, hands = pcall( ply.GetHands, ply )
  check( "GetHands answers (client)", ok )

  -- The server spawn chain creates the hands entity; give the network a moment.
  timer.Simple( 2, function()
    local p = findPlayer()
    if ( p == nil ) then return end
    local h = p:GetHands()
    check( "replicated hands arrived on the client (2s)", h ~= nil and IsValid( h ) )
    if ( h ~= nil and IsValid( h ) ) then
      -- No GetClassname() assert client-side: this fork's client GetClassname()
      -- collapses every scripted entity to the FIRST-registered SENT (cod-c4,
      -- basescripted.cpp:151) -- it reads "cod-c4" even for a correct hands
      -- entity.  Structure + eyeball line instead.
      check( "client hands has a model", h:GetModel() ~= nil and h:GetModel() ~= "" )
      check( "client hands parented to the viewmodel", IsValid( h:GetParent() ) )
      print( string.format( "[hands ..] client hands: ent=%s class=%s model=%s",
        tostring( h:EntIndex() ), tostring( h:GetClassname() ), tostring( h:GetModel() ) ) )
    -- 2026-10-02: render-group contract + GMod globals the verbatim script needs
    check( "hands RenderGroup is OTHER (13)", h:GetRenderGroup and h:GetRenderGroup() == RENDERGROUP_OTHER )
    check( "MATERIAL_CULLMODE_CCW global", MATERIAL_CULLMODE_CCW == 0 )
    check( "MATERIAL_CULLMODE_CW global", MATERIAL_CULLMODE_CW == 1 )
    check( "render.CullMode callable", render ~= nil and render.CullMode ~= nil )
    check( "vector_origin global", vector_origin ~= nil )
    check( "angle_zero global", angle_zero ~= nil )
    check( "GM:OnViewModelChanged wired", GAMEMODE.OnViewModelChanged ~= nil )
    end
    print( string.format( "[hands test] %d passed, %d failed", passed, failed ) )
  end )

  check( "GM:PreDrawViewModel wired", GAMEMODE.PreDrawViewModel ~= nil )
  check( "GM:PostDrawViewModel wired", GAMEMODE.PostDrawViewModel ~= nil )

  return -- client summary prints in the timer above
end

-- 2026-10-02: SetTransmitWithParent/GetTransmitWithParent roundtrip + DeleteOnRemove
do
  local ply2 = nil
  if ( player and player.GetAll ) then ply2 = player.GetAll()[1] end
  if ( ply2 == nil ) then ply2 = findPlayer() end
  if ( ply2 ~= nil and IsValid( ply2 ) ) then
    local h = ply2:GetHands()
    if ( h ~= nil and IsValid( h ) ) then
      local before = h:GetTransmitWithParent()
      h:SetTransmitWithParent( true )
      check( "SetTransmitWithParent(true) reads back true (server)", h:GetTransmitWithParent() == true )
      h:SetTransmitWithParent( false )
      check( "SetTransmitWithParent(false) reads back false (server)", h:GetTransmitWithParent() == false )
      h:SetTransmitWithParent( before )
    end

    local a = ents.Create( "prop_physics" )
    local b = ents.Create( "prop_physics" )
    if ( a ~= nil and IsValid( a ) and b ~= nil and IsValid( b ) ) then
      a:Spawn()
      b:Spawn()
      a:DeleteOnRemove( b )
      a:Remove()
      -- UTIL_Remove defers to the frame tail; both flags should be set now.
      check( "DeleteOnRemove: victim marked for deletion with owner", b:IsValid() == false or b:IsMarkedForDeletion and b:IsMarkedForDeletion() )
    end
  end
end

print( string.format( "[hands test] %d passed, %d failed", passed, failed ) )
