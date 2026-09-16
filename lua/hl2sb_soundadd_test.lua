-- HL2SB: temporary smoke test for sound.Add / sound.GetProperties / sound.GetTable.
--
-- Run from the console (no lua/ prefix):
--     lua_dofile_cl hl2sb_soundadd_test.lua
--
-- Delete once it has passed.

local NAME = "HL2SB.SoundAddTest"

local function describe( value )
    if ( type( value ) == "table" ) then
        return string.format( "{%s, %s}", tostring( value[ 1 ] ), tostring( value[ 2 ] ) )
    end
    return tostring( value )
end

local function report( label, props )
    if ( not props ) then
        print( "[HL2SB] " .. label .. ": GetProperties returned nil\n" )
        return
    end

    print( string.format( "[HL2SB] %s name=%s channel=%s level=%s volume=%s pitch=%s sound=%s\n",
        label, describe( props.name ), describe( props.channel ), describe( props.level ),
        describe( props.volume ), describe( props.pitch ), describe( props.sound ) ) )
end

-- Full SoundData: every field GMod documents, including the { min, max } pitch.
-- Expect pitch to read back as { 95, 110 }, not { 95, 205 }.
sound.Add( {
    name = NAME,
    channel = CHAN_STATIC,
    volume = 0.6,
    level = 80,
    pitch = { 95, 110 },
    sound = "garrysmod/balloon_pop_cute.wav"
} )
report( "full", sound.GetProperties( NAME ) )

-- Minimal SoundData: channel/level/volume/pitch all have documented defaults, so
-- this must register too, and read back CHAN_AUTO / 75 / 1 / 100.
sound.Add( { name = NAME .. ".Minimal", sound = "garrysmod/balloon_pop_cute.wav" } )
report( "minimal", sound.GetProperties( NAME .. ".Minimal" ) )

-- A script with several files: sound comes back as a sequential table.
sound.Add( {
    name = NAME .. ".Many",
    sound = { "garrysmod/balloon_pop_cute.wav", "garrysmod/balloon_pop_cute.wav" }
} )
report( "many", sound.GetProperties( NAME .. ".Many" ) )

local all = sound.GetTable()
print( "[HL2SB] registered scripts=" .. tostring( all and #all or 0 ) .. "\n" )
print( "[HL2SB] has " .. NAME .. ": " .. tostring( table.HasValue( all or {}, NAME ) ) .. "\n" )

--[[
    Three play attempts, to separate "the script is not resolved" from "the engine
    cannot play this file at all":

      1. by script name      -- script -> wave resolution + engine playback
      2. by raw wave path    -- engine playback only (no script registry involved)
      3. Entity:EmitSound    -- GMod's own entry point for a script name

    Only (1) failing means the script registry is the problem; (1) and (2) both
    failing means the file/engine side is.
]]
local origin = IsValid( LocalPlayer() ) and LocalPlayer():GetPos() or Vector( 0, 0, 0 )

print( "[HL2SB] 1) sound.Play( script name )\n" )
sound.Play( NAME, origin, 80, 100, 1, CHAN_STATIC )

print( "[HL2SB] 2) sound.Play( raw wave path )\n" )
sound.Play( "garrysmod/balloon_pop_cute.wav", origin, 80, 100, 1, CHAN_STATIC )

print( "[HL2SB] 3) Entity:EmitSound( script name )\n" )
if ( IsValid( LocalPlayer() ) ) then
    LocalPlayer():EmitSound( NAME )
end

print( "[HL2SB] done -- enable 'sv_soundemitter_trace 1' for the resolution trace\n" )
