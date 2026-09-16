-- HL2SB: does a scripted weapon's NetworkVar (SWEP:Zoom) reach the client?
--
--   lua_dofile_cl hl2sb_zoom_probe.lua
--   lua_dofile_sv hl2sb_zoom_probe.lua
--
-- (the command prepends lua/ but does NOT append .lua, so keep the extension)
--
-- Run both with the camera equipped.  SERVER should print value=70 (or whatever
-- it zoomed to).  If CLIENT prints value=0, the scripted-weapon DT var is not
-- syncing, which is why SWEP:TranslateFOV hands the view a FOV of 0.

local realm = ( SERVER and "SERVER" ) or ( CLIENT and "CLIENT" ) or "?"

print( "[" .. realm .. "] FrameTime global: " .. type( FrameTime ) ..
	   ( ( type( FrameTime ) == "function" ) and ( " -> " .. tostring( FrameTime() ) ) or "" ) )

local function probe( ply )
	if ( !IsValid( ply ) ) then
		print( "[" .. realm .. "] no player to probe" )
		return
	end

	local wep = ply:GetActiveWeapon()

	if ( !IsValid( wep ) ) then
		print( "[" .. realm .. "] no active weapon (equip the camera first)" )
		return
	end

	print( "[" .. realm .. "] weapon class = " .. tostring( wep:GetClass() ) )
	print( "[" .. realm .. "] GetZoom is a " .. type( wep.GetZoom ) )

	local okZ, z = pcall( function() return wep:GetZoom() end )
	print( "[" .. realm .. "] GetZoom -> ok=" .. tostring( okZ ) .. " value=" .. tostring( z ) )

	local okR, r = pcall( function() return wep:GetRoll() end )
	print( "[" .. realm .. "] GetRoll -> ok=" .. tostring( okR ) .. " value=" .. tostring( r ) )

	-- What the weapon would answer for the view FOV, called the same way the
	-- engine now calls it (argument = the engine's own FOV).
	local okF, f = pcall( function()
		return wep.TranslateFOV and wep:TranslateFOV( 90 ) or "no TranslateFOV in this table"
	end )
	print( "[" .. realm .. "] TranslateFOV(90) -> ok=" .. tostring( okF ) .. " value=" .. tostring( f ) )

	-- The engine-side clamp: only [1, 179] may override the FOV.
	if ( okF and isnumber( f ) ) then
		print( "[" .. realm .. "] clamp accepts it? " .. tostring( f >= 1 and f <= 179 ) )
	end
end

local ply = nil

if ( CLIENT ) then
	ply = LocalPlayer()
end

if ( !IsValid( ply ) && SERVER && player && player.GetAll ) then
	local players = player.GetAll()
	ply = players and players[ 1 ]
end

probe( ply )
