------------------------------------------------------------------------------
-- hl2sb_gmod_msgc.lua - HL2SB GMod compat (2026-09-25)
--
-- GMod's global MsgC( color, ... ) - stock addons call it constantly at load
-- time (hitnumbers' printWarning), and a missing MsgC is a LOAD FAILING error,
-- not a cosmetic one.  The fork has no MsgC binding; this shim prints the
-- concatenated arguments with the leading Color skipped (plain console text -
-- real colour routing stays an engine-side upgrade).
--
-- Idempotent on purpose: the listen-server loader scans the autorun/includes
-- folders twice, so every definition here guards with a nil check.
------------------------------------------------------------------------------

if ( MsgC == nil ) then
	function MsgC( ... )
		local n = select( "#", ... )
		local parts = {}
		for i = 1, n do
			local v = select( i, ... )
			-- skip a leading Color (table with r/g/b) - GMod uses it for the console colour
			if ( i == 1 and type( v ) == "table" and v.r ~= nil and v.g ~= nil and v.b ~= nil ) then
				continue
			end
			parts[ #parts + 1 ] = tostring( v )
		end
		print( table.concat( parts ) )
	end
end
