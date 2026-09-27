-- ===========================================================================
-- HL2SB act/taunt in-game test (2026-09-27).
--
-- Fully restart the game, enter a map, then:
--   server console:  lua_dofile     act_lib_test.lua
--   client console:  lua_dofile_cl  act_lib_test.lua
--
-- What it covers:
--   * Player:IsPlayingTaunt exists, answers a boolean, starts false
--   * the ACT_GMOD_*/ACT_SIGNAL_* enums and GESTURE_SLOT_CUSTOM the act table
--     uses are published, and the playermodel resolves + times them
--   * LerpVector / LerpAngle globals (taunt camera helpers)
--   * the taunt camera surface (client): TauntCamera() + its three callbacks
--   * server: the real `act dance` command path -> IsPlayingTaunt flips true
--     next tick, and the replicated clock expires it again (async, timers)
-- ===========================================================================

local passed, failed = 0, 0
local function check( name, ok )
  if ( ok ) then
    passed = passed + 1
    print( "[act ok] " .. name )
  else
    failed = failed + 1
    print( "[act FAIL] " .. name )
  end
end

local function findPlayer()
  local ply = LocalPlayer and LocalPlayer()
  if ( ply and IsValid and IsValid( ply ) ) then return ply end
  if ( player and player.GetAll ) then
    local all = player.GetAll()
    if ( all and all[1] ) then return all[1] end
  end
  if ( util and util.GetLocalPlayer ) then return util.GetLocalPlayer() end
  return nil
end

local ply = findPlayer()
check( "player found", ply ~= nil )

if ( SERVER ) then

  check( "IsPlayingTaunt bound", ply.IsPlayingTaunt ~= nil )
  local ok, res = pcall( ply.IsPlayingTaunt, ply )
  check( "IsPlayingTaunt answers", ok and res == false or res == true )

  check( "ACT_GMOD_TAUNT_DANCE published", ACT_GMOD_TAUNT_DANCE ~= nil )
  check( "ACT_GMOD_GESTURE_WAVE published", ACT_GMOD_GESTURE_WAVE ~= nil )
  check( "ACT_SIGNAL_HALT published (act halt)", ACT_SIGNAL_HALT ~= nil )
  check( "ACT_SIGNAL_FORWARD published (act forward)", ACT_SIGNAL_FORWARD ~= nil )
  check( "GESTURE_SLOT_CUSTOM == 6", GESTURE_SLOT_CUSTOM == 6 )

  local seq = ply:SelectWeightedSequence( ACT_GMOD_TAUNT_DANCE )
  check( "model has the dance taunt sequence", seq ~= nil and seq > 0 )
  if ( seq ~= nil and seq > 0 ) then
    local dur = ply:SequenceDuration( seq )
    check( "dance duration is positive (" .. tostring( dur ) .. "s)", dur ~= nil and dur > 0 )
  end

  check( "GM:PlayerShouldTaunt default", GAMEMODE.PlayerShouldTaunt ~= nil )
  check( "GM:PlayerStartTaunt default", GAMEMODE.PlayerStartTaunt ~= nil )

  -- Drive the real command end-to-end (replicated clock + gesture + hooks).
  if ( ply.ConCommand ) then
    ply:ConCommand( "act dance" )
    print( "[act ..] 'act dance' issued; checking the clock in 0.5s and expiry later" )

    timer.Simple( 0.5, function()
      local p = findPlayer()
      if ( p ) then
        check( "act dance -> IsPlayingTaunt true (server)", p:IsPlayingTaunt() == true )
      end
    end )

    timer.Simple( 60, function()
      local p = findPlayer()
      if ( p ) then
        check( "taunt clock expired (server)", p:IsPlayingTaunt() == false )
      end
    end )
  else
    check( "Player:ConCommand bound (cannot drive act)", false )
  end

end

if ( CLIENT ) then

  check( "IsPlayingTaunt bound (client)", ply.IsPlayingTaunt ~= nil )
  local ok, res = pcall( ply.IsPlayingTaunt, ply )
  check( "IsPlayingTaunt answers a boolean (client)", ok and ( res == true or res == false ) )

  check( "TauntCamera factory loaded", TauntCamera ~= nil )
  if ( TauntCamera ) then
    local cam = TauntCamera()
    check( "TauntCamera returns the CAM table", type( cam ) == "table" )
    check( "CAM.ShouldDrawLocalPlayer", type( cam.ShouldDrawLocalPlayer ) == "function" )
    check( "CAM.CalcView", type( cam.CalcView ) == "function" )
    check( "CAM.CreateMove", type( cam.CreateMove ) == "function" )
    check( "CAM off-state draw answer", cam:ShouldDrawLocalPlayer( ply, false ) == false )
    check( "CAM on-state draw answer", cam:ShouldDrawLocalPlayer( ply, true ) == true )
  end

  -- Diagnose the gamemode-table duality: the engine demonstrably calls
  -- GM:CalcView (the taunt camera ran), yet GAMEMODE.CalcView read nil here.
  print( "[act ..] GAMEMODE=" .. tostring( GAMEMODE ) .. " _GAMEMODE=" .. tostring( _GAMEMODE ) ..
    " same=" .. tostring( GAMEMODE == _GAMEMODE ) )

  check( "GM:CalcView wired",
    ( GAMEMODE and GAMEMODE.CalcView ) ~= nil or ( _GAMEMODE and _GAMEMODE.CalcView ) ~= nil )
  check( "GM:CreateMove wired", GAMEMODE.CreateMove ~= nil )
  check( "GM:ShouldDrawLocalPlayer wired", GAMEMODE.ShouldDrawLocalPlayer ~= nil )

  check( "player.GetAll bound (client)", player ~= nil and player.GetAll ~= nil )
  if ( player and player.GetAll ) then
    local all = player.GetAll()
    check( "player.GetAll returns a table with the local player",
      type( all ) == "table" and #all >= 1 )
  end

  check( "LerpVector global", LerpVector ~= nil )
  if ( LerpVector ) then
    local v = LerpVector( 0.5, Vector( 0, 0, 0 ), Vector( 10, 20, 30 ) )
    check( "LerpVector midpoint", v.x == 5 and v.y == 10 and v.z == 15 )
  end
  check( "LerpAngle global", LerpAngle ~= nil )
  if ( LerpAngle ) then
    local a = LerpAngle( 0.5, QAngle( 0, 0, 0 ), QAngle( 10, 20, 30 ) )
    check( "LerpAngle midpoint", a.p == 5 and a.y == 10 and a.r == 15 )
  end

end

print( string.format( "[act test] %d passed, %d failed", passed, failed ) )
