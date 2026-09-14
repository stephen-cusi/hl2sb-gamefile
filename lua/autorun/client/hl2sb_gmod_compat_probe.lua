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
local whiteID = surface.GetTextureID( "vgui/white" )
local w, h = surface.DrawGetTextureSize( whiteID )
print( TAG .. "vgui/white: id=" .. tostring( whiteID )
	.. "  size=" .. tostring( w ) .. "x" .. tostring( h )
	.. "  valid=" .. tostring( surface.IsTextureIDValid( whiteID ) )
	.. "  (expect 8x8 -- materials/vgui/white.png; an ERROR material is 32x32 or larger)" )

-- ---- 6. the draw calls, inside a real 2D context ------------------------
local drawn = false

hook.Add( "HudViewportPaint", "hl2sb_gmod_compat_probe", function()
	if ( drawn ) then return end
	drawn = true

	local ok, err = pcall( function()
		draw.NoTexture()
		surface.SetDrawColor( 255, 0, 0, 255 )
		surface.DrawRect( 8, 8, 6, 6 )   -- solid red, proves NoTexture left a usable state

		draw.TexturedQuad( {
			texture = whiteID,
			x = 24, y = 8, w = 96, h = 32,
			color = Color( 255, 255, 255, 255 ),
		} )

		draw.DrawText( "comprobe line 1\nline 2\ttab", "Default", 24, 48, Color( 0, 255, 0, 255 ), draw.TEXT_ALIGN_LEFT )
	end )

	if ( ok ) then
		print( TAG .. "draw.NoTexture + draw.TexturedQuad + draw.DrawText ran clean (see the screen: red dot, white bar, two green lines)" )
	else
		print( TAG .. "draw probe FAILED: " .. tostring( err ) )
	end
end )

print( TAG .. "loaded -- type 'hl2sb_comprobe one two three' in the console to test the ENGINE path" )
