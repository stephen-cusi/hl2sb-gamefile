--[[----------------------------------------------------------------------------
    gmod_surface.lua

    GMod's `surface` drawing helpers, implemented in Lua on top of the engine's
    raw vgui::ISurface bindings.  HL2SB's surface library exposes the ISurface
    names (DrawSetColor / DrawFilledRect / DrawSetTexture / DrawSetTextureFile /
    CreateNewTextureID); GMod scripts use the friendlier ones.  GMod's own
    cl_hudpickup.lua needs SetDrawColor / DrawRect / SetTexture / GetTextureID,
    and most HUD addons need the same.

    Deliberately NOT provided:
      surface.DrawTexturedRectRotated( x, y, w, h, rot )
        Source 2013's vgui::ISurface has no rotated textured rect (GMod's engine
        added one).  Defining it as an unrotated draw would silently produce
        wrong output, so it stays undefined and fails loudly instead.

    Loaded every level from lua/includes/extensions/.
-----------------------------------------------------------------------------]]--

if ( not _CLIENT ) then return end

local surface = surface
local type    = type

local DrawSetColor    = surface.DrawSetColor
local DrawSetTextColor= surface.DrawSetTextColor
local DrawFilledRect  = surface.DrawFilledRect

-- ===========================================================================
-- Colour: accept either ( r, g, b [, a] ) or a Color table.
-- ===========================================================================

local function Channels( r, g, b, a )
	if ( type( r ) == "table" ) then
		return r.r or 255, r.g or 255, r.b or 255, r.a or 255
	end

	return r or 255, g or 255, b or 255, a or 255
end

if ( surface.SetDrawColor == nil ) then
	function surface.SetDrawColor( r, g, b, a )
		DrawSetColor( Channels( r, g, b, a ) )
	end
end

if ( surface.SetTextColor == nil ) then
	function surface.SetTextColor( r, g, b, a )
		DrawSetTextColor( Channels( r, g, b, a ) )
	end
end

-- ===========================================================================
-- DrawRect( x, y, w, h ) -- the engine wants two corners.
-- ===========================================================================

if ( surface.DrawRect == nil ) then
	function surface.DrawRect( x, y, w, h )
		DrawFilledRect( x, y, x + w, y + h )
	end
end

-- ===========================================================================
-- Textures
-- ===========================================================================

if ( surface.SetTexture == nil ) then
	surface.SetTexture = surface.DrawSetTexture
end

if ( surface.GetTextureID == nil ) then
	function surface.GetTextureID( path )
		local id = surface.CreateNewTextureID()
		-- DrawSetTextureFile( id, path, hardwareFilter, forceReload )
		surface.DrawSetTextureFile( id, tostring( path ), 1, false )
		return id
	end
end

print( "[HL2SB] gmod surface extension loaded" )
