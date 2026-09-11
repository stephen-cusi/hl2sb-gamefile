--[[----------------------------------------------------------------------------
    gmod_surface.lua

    GMod's `surface` drawing helpers, implemented in Lua on top of the engine's
    raw vgui::ISurface bindings.  HL2SB's surface library exposes the ISurface
    names (DrawSetColor / DrawFilledRect / DrawSetTexture / DrawSetTextureFile /
    CreateNewTextureID); GMod scripts use the friendlier ones.  GMod's own
    cl_hudpickup.lua needs SetDrawColor / DrawRect / SetTexture / GetTextureID,
    and most HUD addons need the same.

    What is NOT here anymore (2026-09-11):
      surface.DrawTexturedRectRotated( x, y, w, h, rot ) and
      surface.DrawTexturedRectUV( x, y, w, h, u0, v0, u1, v1 )
        These used to be missing/emulated in Lua.  They are now real engine
        bindings in public/lua/vgui/LISurface.cpp -- rotated rects are built as a
        quad and handed to ISurface::DrawTexturedPolygon, so no interface change
        was needed.  Nothing here may shadow them.

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

-- ===========================================================================
-- Text placement and text drawing -- GMod's names for the ISurface ones.
-- ===========================================================================

if ( surface.SetTextPos == nil ) then
	surface.SetTextPos = surface.DrawSetTextPos
end

if ( surface.DrawText == nil ) then
	-- DrawPrintText renders with the font/colour/position already selected by
	-- DrawSetTextFont / DrawSetTextColor / DrawSetTextPos, which is exactly what
	-- GMod's surface.DrawText( text ) does.  HL2SB buffers that text -- draw.lua
	-- flushes right after every DrawPrintText -- so flush here too, otherwise a
	-- caller that draws text and nothing else would draw nothing at all.
	function surface.DrawText( text )
		surface.DrawPrintText( text )
		surface.DrawFlushText()
	end
end

-- NOTE: surface.GetTextSize is deliberately NOT wrapped here.  GMod's
-- one-argument form, surface.GetTextSize( text ), cannot be provided from this
-- file: lua/game/client/font.lua loads AFTER lua/includes/extensions (see the
-- order in cdll_client_int.cpp) and re-points GetTextSize at its own wrapper,
-- which requires ( font, text ).  Callers that want a GMod-like read pass back
-- the HFont that surface.SetFont() returns:
--
--     local hfont = surface.SetFont( "HL2MPTypeDeath" )
--     local w, h  = surface.GetTextSize( hfont, "0" )
--
-- (Providing it properly would mean putting that wrapper in lua/autorun/client/,
-- which loads after font.lua.  Nothing needs it yet.)

-- ===========================================================================
-- Textured rectangles.
--
-- The engine binding named DrawTexturedRect takes the far CORNER:
--     surface.DrawTexturedRect( x, y, x1, y1 )
-- GMod's takes a size:
--     surface.DrawTexturedRect( x, y, w, h )
-- GMod code (and killicon.lua) means the latter, so the name is re-pointed at
-- the GMod meaning and the engine one stays reachable as
-- surface.__hl2sb_cornerRect.  hl2sb_undo_notify.lua was the only in-tree user
-- of the corner form and was converted at the same time.
-- ===========================================================================

local CornerRect = surface.__hl2sb_cornerRect or surface.DrawTexturedRect

surface.__hl2sb_cornerRect = CornerRect

function surface.DrawTexturedRect( x, y, w, h )
	CornerRect( x, y, x + w, y + h )
end

if ( surface.DrawTexturedRectUV == nil ) then
	function surface.DrawTexturedRectUV( x, y, w, h, u0, v0, u1, v1 )
		-- DrawTexturedSubRect( x0, y0, x1, y1, s0, t0, s1, t1 )
		surface.DrawTexturedSubRect( x, y, x + w, y + h, u0, v0, u1, v1 )
	end
end

-- ===========================================================================
-- Materials.
--
-- GMod hands Material( path ) around and asks it for its size:
--     local mat = Material( "HUD/killicons/default" )
--     local w, h = mat:Width(), mat:Height()
--     surface.SetMaterial( mat )
--     surface.DrawTexturedRect( x, y, w, h )
-- Source 2013's Lua surface has no material objects, so this is a lazy wrapper
-- around a texture id.  The texture is only created when it is first asked for,
-- so a Material() call at file scope cannot fail on a missing file.
-- ===========================================================================

local function TextureSize( texid )
	if ( surface.DrawGetTextureSize ) then
		local w, h = surface.DrawGetTextureSize( texid )
		if ( w and h and w > 0 and h > 0 ) then return w, h end
	end

	-- GMod's killicons, and hud/killicons/default, are square -- and that is how
	-- the old kill feed (hl2sb_deathnotice.lua, now replaced by
	-- gmod_deathnotice.lua) drew them too.
	return 32, 32
end

if ( Material == nil ) then
	function Material( path )
		local mat = { __path = tostring( path ) }

		function mat:GetName() return self.__path end
		function mat:IsError() return false end

		-- HL2SB: pixel sampling, which the Derma skin needs AT LOAD TIME.
		--
		-- GWEN.CreateTextureBorder samples the atlas through this while it builds
		-- its nine-slice borders, i.e. while lua/skins/default.lua is loading:
		--
		--     lua/derma/derma_gwen.lua:125:  return mat:GetColor( x, y )
		--
		-- This proxy only wraps a texture id, so it genuinely cannot read a pixel
		-- (that needs IMaterial::GetLowResColorSample).  Returning white is what
		-- lets the skin LOAD, and that is the whole point: without it
		-- DefineSkin( "Default", ... ) at the end of the file never ran,
		-- derma.DefaultSkin stayed empty, derma.SkinHook returned early for every
		-- type ("if ( !func ) then return end") and NO Derma panel painted
		-- anything -- the undo notice played its sound and drew nothing.
		--
		-- Only a few border pieces take their tint from here; a DPanel's own
		-- background passes its colour straight to the draw call, so the notice
		-- still looks right.
		--
		-- TODO(engine): bind a real Material( path ) returning an IMaterial --
		-- public/lua/materialsystem/limaterial.cpp already has IMaterial:GetColor
		-- -- and delete this whole proxy along with this stub.
		function mat:GetColor( x, y )
			return Color( 255, 255, 255, 255 )
		end

		function mat:GetTextureID()
			if ( not self.__texid ) then
				self.__texid = surface.GetTextureID( self.__path )
			end

			return self.__texid
		end

		function mat:Width()
			if ( not self.__w ) then
				self.__w, self.__h = TextureSize( self:GetTextureID() )
			end

			return self.__w
		end

		function mat:Height()
			if ( not self.__h ) then
				self.__w, self.__h = TextureSize( self:GetTextureID() )
			end

			return self.__h
		end

		-- ITexture-shaped handle, for code that asks the material for its texture.
		function mat:GetTexture()
			return {
				GetTextureID = function() return mat:GetTextureID() end,
				GetName      = function() return mat.__path end,
				Width        = function() return mat:Width() end,
				Height       = function() return mat:Height() end,
			}
		end

		return mat
	end
end

if ( surface.SetMaterial == nil ) then
	function surface.SetMaterial( mat )
		if ( type( mat ) == "table" and mat.GetTextureID ) then
			surface.DrawSetTexture( mat:GetTextureID() )
			return
		end

		if ( type( mat ) == "number" ) then
			surface.DrawSetTexture( mat )
			return
		end

		-- A bare path is accepted too, which is what the old kill feed did.
		if ( type( mat ) == "string" ) then
			surface.DrawSetTexture( surface.GetTextureID( mat ) )
		end
	end
end

--[[---------------------------------------------------------
	DisableClipping( b ) -- GMod exposes this as a *global*, not just a surface
	method, and GMod's own skins/derma call it that way:

	    local wasEnabled = DisableClipping( true )
	    ...
	    DisableClipping( wasEnabled )

	It returns the previous state, which is exactly what the engine binding
	(built in the same commit as this shim) returns, so this is a passthrough.
	Without it every painted panel threw
	    lua/skins/default.lua:344: attempt to call a nil value (global 'DisableClipping')
-----------------------------------------------------------]]
if ( CLIENT and !DisableClipping ) then
	function DisableClipping( b )
		return surface.DisableClipping( b and true or false )
	end
end

print( "[HL2SB] gmod surface extension loaded" )
