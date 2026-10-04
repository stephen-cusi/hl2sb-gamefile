-- head_bisect.lua -- HL2SB (2026-10-04) on-screen bisect.  Run: lua_dofile_cl head_bisect.lua
-- Seated in the jeep WITH the head visible.  Hides one candidate at a time,
-- 2.5s each, then restores everything.  WATCH THE SCREEN: when the head
-- disappears, note the name being printed.

local function setnodraw( e, state )
	if ( e and IsValid( e ) ) then e:SetNoDraw( state ) end
end

local steps = {}
table.insert( steps, { "ply (engine model)", function( s ) setnodraw( LocalPlayer(), s ) end } )
table.insert( steps, { "ply.Body (FPB copy)", function( s )
	local ply = LocalPlayer()
	if ( IsValid( ply ) and IsValid( ply.Body ) ) then ply.Body:SetNoDraw( s ) end
end } )
table.insert( steps, { "ply.Body_NoDraw", function( s )
	local ply = LocalPlayer()
	if ( IsValid( ply ) and IsValid( ply.Body_NoDraw ) ) then ply.Body_NoDraw:SetNoDraw( s ) end
end } )
for i = 1, 4 do
	table.insert( steps, { "ply.Body_Shadow_" .. i, function( s )
		local ply = LocalPlayer()
		local e = IsValid( ply ) and ply["Body_Shadow_" .. i] or nil
		setnodraw( e, s )
	end } )
end

print( "[bisect] starting in 2s -- make sure the head is on screen NOW" )

timer.Create( "head_bisect", 0.1, 0, function()
	local t = CurTime()
	if ( t < 2 ) then return end

	local idx = math.floor( ( t - 2 ) / 2.5 )
	if ( idx >= #steps ) then
		hook.Remove( "Think", "head_bisect" )
		-- restore everything visible
		for _, st in ipairs( steps ) do st[2]( false ) end
		print( "[bisect] done -- everything restored.  Tell me which step hid the head." )
		return
	end

	-- restore the previous step's target, hide this one
	if ( idx > 0 ) then steps[idx][2]( false ) end
	steps[idx + 1][2]( true )
	print( "[bisect] HIDING: " .. steps[idx + 1][1] )
end )
