-- HL2SB: temporary diagnostic -- why are HL2's sounds missing?
--
-- Run from the console (no lua/ prefix):
--     lua_dofile_cl hl2sb_soundpath_test.lua
--
-- Delete once it has answered the question.

local function yesno( value )
    if ( value ) then return "YES" end
    return "no"
end

-- 1. What can the Lua mount actually see of HL2?
local vpks = file.Find( "hl2/*.vpk", "BASE_PATH" ) or {}
print( "[HL2SB] hl2 vpks seen by the mount: " .. tostring( #vpks ) .. "\n" )
for i = 1, math.min( #vpks, 6 ) do
    print( "[HL2SB]   vpk " .. tostring( vpks[ i ] ) .. "\n" )
end

-- 2. Are HL2's waves visible on the GAME search path?  These are the ones the
--    engine reports as missing (Failed to load sound ...).
local hl2sounds = {
    "items/ammo_pickup.wav",
    "weapons/smg1/smg1_fire1.wav",
    "player/pl_shell1.wav",
    "physics/concrete/concrete_impact_bullet4.wav",
}
for _, name in ipairs( hl2sounds ) do
    print( string.format( "[HL2SB] GAME %-46s %s\n", name, yesno( file.Exists( name, "GAME" ) ) ) )
end

-- 3. Control: this mod's own sound, which does play.
print( "[HL2SB] GAME garrysmod/balloon_pop_cute.wav (own content, control): " ..
       yesno( file.Exists( "garrysmod/balloon_pop_cute.wav", "GAME" ) ) .. "\n" )

-- 4. Control: the script registry from the sound.Add work.
local props = sound.GetProperties( "HL2SB.SoundAddTest" )
print( "[HL2SB] sound.GetProperties( HL2SB.SoundAddTest ): " .. tostring( props ~= nil ) .. "\n" )
