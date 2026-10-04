-- vehicle_eyeprobe.lua v4 -- HL2SB (2026-10-04) culprit projector.  Run: lua_dofile_cl vehicle_eyeprobe.lua
-- Seated in the jeep, AIM AT THE HEAD.  For every candidate model, projects its
-- head-bone position onto the view axis: the culprit is the one whose head is
-- dead-center in front of the camera (offaxis ~ 0).

timer.Remove( "head_bisect" )
timer.Remove( "probe3" )
timer.Remove( "probe4" )
hook.Remove( "Think", "head_bisect" )
hook.Remove( "CalcView", "probe2_offset" )

local function isEnt( v ) return type( v ) == "Entity" end

local function headPos( e )
	local h = e:LookupBone( "ValveBiped.Bip01_Head1" )
	if ( h and h >= 0 ) then
		local p = e:GetBonePosition( h )
		if ( p ) then return p end
	end
	return nil
end

local n = 0
timer.Create( "probe4", 0.5, 24, function()
	n = n + 1
	local ply = LocalPlayer()
	if ( not IsValid( ply ) ) then return end
	local eye = EyePos()
	local fwd = EyeAngles():Forward()

	print( string.format( "[probe4 f%02d] camera %s", n, tostring( eye ) ) )
	-- candidates: the player + every entity field on the player table
	local candidates = { { "ply(engine)", ply } }
	local tbl = ply:GetTable()
	for k, v in pairs( tbl ) do
		if ( isEnt( v ) and IsValid( v ) ) then
			candidates[#candidates + 1] = { "ply." .. tostring( k ), v }
		end
	end
	for _, c in ipairs( candidates ) do
		local hp = headPos( c[2] )
		if ( hp ) then
			local rel = hp - eye
			local along = rel:Dot( fwd )
			local off = rel - fwd * along
			local nodraw = c[2]:IsEffectActive( EF_NODRAW )
			print( string.format( "   %-16s head dot=%8.1f offaxis=%6.2f nodraw=%s",
				c[1], along, off:Length(), tostring( nodraw ) ) )
		else
			print( string.format( "   %-16s no head bone", c[1] ) )
		end
	end
end )
print( "[probe4] running 24x0.5s -- AIM AT THE HEAD now" )
