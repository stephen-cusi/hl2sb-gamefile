-- HL2SB: GMod keyboard-option binds that need a client-side toggle wrapper.
-- The Options -> Keyboard page (scripts/kb_act.lst) binds gmod_record_demo /
-- gmod_record_video; the engine only has non-toggle record/stop and
-- startmovie/endmovie, so these wrap them the way GMod's binds behave.

if not CLIENT then return end

local demoRecording = false
concommand.Add( "gmod_record_demo", function()
	if ( demoRecording ) then
		RunConsoleCommand( "stop" )
		demoRecording = false
		print( "[HL2SB] Demo recording stopped." )
	else
		-- record requires a name; reuse GMod's default demo name style
		RunConsoleCommand( "record", "gmod_demo" )
		demoRecording = true
		print( "[HL2SB] Demo recording started (record gmod_demo)." )
	end
end, nil, "Toggle demo recording", { FCVAR_DONTRECORD } )

local movieRecording = false
concommand.Add( "gmod_record_video", function()
	if ( movieRecording ) then
		RunConsoleCommand( "endmovie" )
		movieRecording = false
		print( "[HL2SB] Video recording stopped." )
	else
		RunConsoleCommand( "startmovie", "gmod_video 30" )
		movieRecording = true
		print( "[HL2SB] Video recording started (startmovie gmod_video 30)." )
	end
end, nil, "Toggle video recording", { FCVAR_DONTRECORD } )
