--==============================================================================
-- HL2SB in-game probe: the GMod concommand + draw compatibility added together
-- with the engine change in public/lua/tier1/lconvar.cpp.
--
-- Lives in lua/autorun/client/ so it runs by itself on every map load
-- (luasrc_dofolder_sorted loads lua/autorun/client/** recursively).  Nothing
-- else here draws, so the panel area it paints in is free.
--
-- WHAT IT CHECKS
--   1. concommand.Run / AutoComplete / GetTable exist.
--   2. The Lua side of Run delivers a GMod arguments table
--      (RunConsoleCommand -> concommand.Run -> callback).
--   3. THE ENGINE SIDE: type this in the console and read the log --
--
--          hl2sb_comprobe one two three
--
--      The engine's CC_ConCommand must now call Run( ply, cmd, { "one", "two",
--      "three" }, "one two three" ).  Before the change the arguments slot held
--      the raw string, which is why hl2sb_spawnprop / gmod_undonum / gmod_cleanup
--      all silently printed their usage text (they index args[1]).
--   4. vgui/white resolves -- surface.DrawGetTextureSize must report the 8x8
--      materials/vgui/white.png we ship, not the ERROR material that a missing
--      vgui/white used to give.
--   5. draw.NoTexture / draw.TexturedQuad / draw.DrawText execute inside a real
--      2D context (the first HudViewportPaint) without throwing.
--==============================================================================

local TAG = "[comprobe] "

-- ---- 1. surface of the module -------------------------------------------
local cc = concommand
local surface_ok = ( type( cc ) == "table" )
print( TAG .. "concommand module: " .. tostring( surface_ok )
	.. "  Run=" .. tostring( surface_ok and type( cc.Run ) == "function" )
	.. "  AutoComplete=" .. tostring( surface_ok and type( cc.AutoComplete ) == "function" )
	.. "  GetTable=" .. tostring( surface_ok and type( cc.GetTable ) == "function" ) )

local tCmd, tComplete = nil, nil
if ( surface_ok and type( cc.GetTable ) == "function" ) then
	tCmd, tComplete = cc.GetTable()
end
print( TAG .. "GetTable: commands=" .. tostring( type( tCmd ) == "table" ) .. " complete=" .. tostring( type( tComplete ) == "table" ) )

-- ---- 2. register the probe command --------------------------------------
local engineSawTable = false

concommand.Add( "hl2sb_comprobe", function( ply, cmd, args, argStr )
	local t = type( args )
	local first = ( t == "table" ) and tostring( args[ 1 ] ) or "<not a table>"
	local count = ( t == "table" ) and #args or -1

	print( TAG .. "command ran: cmd=" .. tostring( cmd )
		.. "  args-type=" .. t .. "  #args=" .. tostring( count )
		.. "  args[1]=" .. first
		.. "  argStr=" .. tostring( argStr ) )

	if ( t == "table" and count >= 1 ) then
		engineSawTable = true
		print( TAG .. "RESULT: PASS - the arguments slot is a GMod table" )
	else
		print( TAG .. "RESULT: FAIL - the arguments slot is " .. t .. " (GMod-style args[1] would be nil)" )
	end
end, function( cmd, argStr, args )
	print( TAG .. "autocomplete called: cmd=" .. tostring( cmd )
		.. "  argStr=" .. tostring( argStr )
		.. "  args-type=" .. type( args ) )
	return { "one", "two", "three" }
end, "HL2SB GMod concommand probe", {} )

-- ---- 3. the Lua path (RunConsoleCommand goes through concommand.Run) ----
print( TAG .. "self-test: RunConsoleCommand( 'hl2sb_comprobe', 'self', 'test' )" )
RunConsoleCommand( "hl2sb_comprobe", "self", "test" )

-- ---- 4. AutoComplete reachability ---------------------------------------
local ac = cc.AutoComplete( "hl2sb_comprobe", "o", {} )
print( TAG .. "AutoComplete -> " .. tostring( ac and ac[ 1 ] )
	.. "  (expect 'one'; nil means the callback was not stored)" )

-- ---- 5. does vgui/white resolve? ----------------------------------------
-- MEASURED (2026-09-15): vgui/white reports 1x1 even though the shipped
-- materials/vgui/white.png is 8x8, while a real .vtf reports its true size.  So
-- the reported size says something about how the material was created, NOT
-- whether the texture is usable -- and an earlier version of this probe called
-- that 1x1 a FAIL, which was wrong.  What actually matters for draw.NoTexture is
-- that binding it paints opaque white, which is what the 200x60 bar below shows.
-- The known-real gui/corner8 is printed next to it so the number is readable.
local whiteID = surface.GetTextureID( "vgui/white" )

local function DescribeTexture( path )
	local id = surface.GetTextureID( path )
	local tw, th = surface.DrawGetTextureSize( id )
	return string.format( "%s -> id=%s size=%sx%s valid=%s",
		path, tostring( id ), tostring( tw ), tostring( th ), tostring( surface.IsTextureIDValid( id ) ) )
end

print( TAG .. DescribeTexture( "gui/corner8" ) .. "   (a real .vtf, for comparison)" )
print( TAG .. DescribeTexture( "vgui/white" ) .. "   (1x1 = the engine's white, 8x8 = our PNG; both paint opaque white)" )

-- ---- 6. the draw calls, inside a real 2D context ------------------------
-- Opt-in, and it paints for ~400 frames on purpose.
--
-- VERSION 1 PAINTED EXACTLY ONE FRAME, which at 100+ fps is about 10 ms -- the
-- user reported "nothing appeared" while every call had returned cleanly.  A
-- one-frame probe cannot be seen, so it cannot prove anything: keep the window
-- long enough to look at, and report a frame count at the end.
--
-- Four independent markers, so a failure is localised instead of being a
-- yes/no on the whole thing:
--   1. surface.DrawRect        -- no texture involved at all (engine fill)
--   2. draw.TexturedQuad       -- needs the texture + NoTexture
--   3. draw.DrawText           -- needs the font path
--   4. draw.SimpleText         -- the CONTROL: the same text path the working
--                                 kill feed / undo notice use
-- If only 1 or only 4 shows up, the culprit is the middle one, not the paint
-- context.
local DRAW_FRAMES = 400

local bArmed, bReported = false, true
local nFrames, nDrawUntil, drawError = 0, 0, nil

concommand.Add( "hl2sb_comprobe_draw", function()
	bArmed, bReported = true, false
	nFrames, drawError = 0, nil
	print( TAG .. "draw probe armed -- painting for " .. DRAW_FRAMES .. " frames" )
end, nil, "Arm the HL2SB draw probe", {} )

hook.Add( "HudViewportPaint", "hl2sb_gmod_compat_probe", function()
	if ( bArmed ) then
		bArmed = false
		nDrawUntil = nFrames + DRAW_FRAMES
		nFrames = 0
		drawError = nil
	end

	if ( nFrames > nDrawUntil ) then
		if ( not bReported ) then
			bReported = true
			if ( drawError ~= nil ) then
				print( TAG .. "RESULT: FAIL - draw threw: " .. tostring( drawError ) )
			else
				print( TAG .. "done: painted " .. nFrames .. " frames with no Lua error." )
				print( TAG .. "look for: RED square (DrawRect) / WHITE bar (TexturedQuad) / GREEN text (DrawText) / YELLOW text (SimpleText control)" )
			end
		end
		return
	end

	nFrames = nFrames + 1

	local ok, err = pcall( function()
		-- 1. engine fill -- needs neither a texture nor a font
		surface.SetDrawColor( 255, 0, 0, 255 )
		surface.DrawRect( 40, 40, 60, 60 )

		-- 2. textured quad on the white texture NoTexture just bound
		draw.NoTexture()
		draw.TexturedQuad( {
			texture = whiteID,
			x = 120, y = 40, w = 200, h = 60,
			color = Color( 255, 255, 255, 255 ),
		} )

		-- 3. the new multi-line / tab text
		draw.DrawText( "comprobe line 1\nline 2\ttab", "Default", 40, 120, Color( 0, 255, 0, 255 ), draw.TEXT_ALIGN_LEFT )

		-- 4. control: the single-line primitive the kill feed already uses
		draw.SimpleText( "SimpleText control", "Default", 40, 190, Color( 255, 255, 0, 255 ) )
	end )

	if ( not ok ) then
		drawError = err
		nDrawUntil = -1          -- stop and report on the next frame
	end
end )

print( TAG .. "loaded -- 'hl2sb_comprobe one two three' tests the ENGINE path, 'hl2sb_comprobe_draw' tests the draw functions" )
