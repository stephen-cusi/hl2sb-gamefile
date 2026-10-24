-- Preserve the old fork command without replacing native help/team commands.
if ( !SERVER ) then return end

concommand.Add( "gm_showspawns", function( ply )
	hook.Run( "ShowSpawns", ply )
end, nil, "Open spawn menu", { FCVAR_DONTRECORD } )
