--[[---------------------------------------------------------------------------
    HL2SB undo hook -> net broadcast (server side).

    The engine undo stack (hl2sb_undo.cpp) fires a server-side Lua hook
    hook.Run("OnUndo", classname, count) after an undo.  This script listens
    and broadcasts a net message to the client HUD, which draws a GMod-style
    popup + sound (the undo notification).

    Loaded every level from lua/game/server/.
-----------------------------------------------------------------------------]]

require( "hook" )
require( "net" )

hook.add( "OnUndo", "hl2sb_undo_notify", function( classname, count )
	if not classname then return end

	-- Sanitise the classname into something readable.
	local name = tostring( classname )
	if name == "" then name = "entity" end

	net.Start( "UndoNotify" )
		net.WriteString( name )
		net.WriteInt( count or 1 )
	net.Broadcast()

	-- Also log to the server console for debugging.
	print( "[HL2SB] undo notify: " .. name .. " (" .. tostring( count or 0 ) .. " ents)" )
end )
