--[[----------------------------------------------------------------------------
    killicon.lua

    Ported from Garry's Mod:  garrysmod/lua/includes/modules/killicon.lua
    (205 lines).  The icon table, the height equalisation and the vertical
    fudges -- including GMod's own comments -- are kept as they are, so a kill
    icon registered by a GMod addon
        killicon.Add( "weapon_x", "path", Color( r, g, b ) )
    behaves exactly as it does there.

    A killicon is either
      * a glyph in an HL2MP death font ("HL2MPTypeDeath"; the scheme font comes
        from resource/clientscheme.res), or
      * a texture -- used by the "default" / suicide / world-death skull.

    Deviations from GMod's file, all forced by HL2SB's bindings:

      1. Text is measured through Measure() below instead of
         surface.GetTextSize( t.character ).  HL2SB's GetTextSize needs the HFont
         as argument #1 -- surface.GetTextSize( hfont, text ) -- and
         lua/game/client/font.lua, which loads AFTER lua/includes/extensions and
         therefore owns the name, requires it too.  surface.SetFont() returns the
         resolved HFont, so Measure() feeds it straight back in; GMod's
         one-argument form is not available (see gmod_surface.lua).

      2. Nothing else.  Color() really is a table with r/g/b/a fields in this
         fork (public/lua/lColor.cpp), so `t.color.r` is a number and
         `t.color.a = alpha` mutates it, exactly like GMod.

    Texture killicons go through the Material() shim, and surface.SetMaterial /
    DrawTexturedRect / DrawTexturedRectUV come from the same place:
    lua/includes/extensions/gmod_surface.lua.
-----------------------------------------------------------------------------]]--

-- HL2SB: lua/includes/modules/*.lua gets executed twice -- once by the engine's
-- luasrc_dofolder() over the directory, and again by any require() of it --
-- because dofolder does not populate package.loaded (see AGENTS.md 5.4).
-- module() reuses the module table, so a second execution would replace
-- `local Icons` with a fresh empty table and silently drop every icon that was
-- registered in between.
--
-- A plain re-entrancy guard would fix that but would also silently keep the OLD
-- code after a map reload / lua_dofile_cl, so a REVISION is compared instead,
-- and the icon table is carried across re-executions.  Bump KILLICON_REVISION
-- whenever the logic below changes and the next level picks it up.
local KILLICON_REVISION = 2

if ( _G.killicon and _G.killicon.__revision == KILLICON_REVISION ) then
	return _G.killicon
end

-- HL2SB: lua/includes/modules is loaded by BOTH realms, but everything in here
-- needs the client surface library (surface.SetFont / GetTextSize / DrawText)
-- and the Material() shim from lua/includes/extensions/gmod_surface.lua, which
-- is client-only.  Without this guard the server load dies on
-- `attempt to call a nil value (upvalue 'Material')` at Add("default", ...).
if ( not _CLIENT ) then return end

local type     = type     -- module() switches this chunk's env (AGENTS 9.1)
local _G       = _G       -- ... including the global _G itself
local surface  = surface
-- HL2SB: gmod_util.lua defines Msg, but it must not be fatal if it has not run
-- -- GetSize() reports a missing killicon through Msg, and that call happens
-- from inside the HudViewportPaint hook, where a throw gets the hook
-- unregistered for the rest of the level (hook.lua drops a hook that throws).
local Msg      = Msg or print
local Color    = Color
local Material = Material

-- HL2SB: surface.GetTextSize needs the font HANDLE as argument #1, and
-- surface.SetFont returns the one it resolved -- so GMod's font *name* works.
-- A font created in Lua (surface.CreateFont + SetFontGlyphSet, which is how
-- gmod_deathnotice.lua builds the HL2MP death-glyph font) is already a handle,
-- and passing a name to surface.SetFont would render empty boxes there, so hand
-- handles straight through.
local function Measure( font, text )
	if ( type( font ) == "string" ) then
		return surface.GetTextSize( surface.SetFont( font ), text )
	end

	return surface.GetTextSize( font, text )
end

-- The matching "make this the drawing font" call for both shapes.
local function SelectFont( font )
	if ( type( font ) == "string" ) then
		surface.SetFont( font )
	else
		surface.DrawSetTextFont( font )
	end
end

--[[---------------------------------------------------------
   Name: killicon
   Desc: Stores and serves killicons for deathnotice
-----------------------------------------------------------]]
module( "killicon" )

-- Icons are carried across re-executions of this file (see KILLICON_REVISION).
local Icons = ( _G.killicon and _G.killicon.__icons ) or {}
local TYPE_FONT = 0
local TYPE_MATERIAL = 1
local TYPE_MATERIAL_UV = 2

function AddFont( name, font, character, color, heightScale )

	Icons[name] = {
		type		= TYPE_FONT,
		font		= font,
		character	= character,
		color		= color or Color( 255, 80, 0 ),

		-- Correct certain icons
		heightScale = heightScale
	}

end

function Add( name, material, color )

	Icons[name] = {
		type		= TYPE_MATERIAL,
		material	= Material( material ),
		color		= color or Color( 255, 255, 255 )
	}

end

function AddTexCoord( name, material, color, x, y, w, h )

	Icons[name] = {
		type		= TYPE_MATERIAL_UV,
		material	= Material( material ),
		color		= color,
		tex_x		= x,
		tex_y		= y,
		tex_w		= w,
		tex_h		= h
	}

end

function AddAlias( name, alias )

	Icons[name] = Icons[alias]

end

function Exists( name )

	return Icons[name] != nil

end

function GetSize( name, dontEqualizeHeight )

	if ( !Icons[name] ) then
		Msg( "Warning: killicon not found '" .. name .. "'\n" )
		Icons[name] = Icons["default"]
	end

	local t = Icons[name]

	-- HL2SB: bail out instead of throwing.  GetSize runs inside the
	-- HudViewportPaint hook, and hook.lua unregisters a hook that throws -- one
	-- bad icon name would take the whole kill feed down for the level.
	if ( t == nil ) then return 0, 0 end

	-- Check the cache
	if ( t.size ) then

		-- Maintain the old behavior
		if ( !dontEqualizeHeight ) then return t.size.adj_w, t.size.adj_h end

		return t.size.w, t.size.h
	end

	local w, h = 0, 0

	if ( t.type == TYPE_FONT ) then

		w, h = Measure( t.font, t.character )

		if ( t.heightScale ) then h = h * t.heightScale end

	elseif ( t.type == TYPE_MATERIAL ) then

		w, h = t.material:Width(), t.material:Height()

	elseif ( t.type == TYPE_MATERIAL_UV ) then

		w = t.tex_w
		h = t.tex_h

	end

	t.size = {}
	t.size.w = w or 32
	t.size.h = h or 32

	-- Height adjusted behavior
	if ( t.type == TYPE_FONT ) then
		t.size.adj_w, t.size.adj_h = Measure( t.font, t.character )
		-- BUG: This is not same height as the texture icons, and we cannot change it beacuse backwards compability
	else
		local _, fh = Measure( "HL2MPTypeDeath", "0" )
		fh = fh * 0.75 -- Fudge it slightly

		-- Resize, maintaining aspect ratio
		t.size.adj_w = w * ( fh / h )
		t.size.adj_h = fh
	end

	-- Maintain the old behavior
	if ( !dontEqualizeHeight ) then return t.size.adj_w, t.size.adj_h end

	return w, h

end

local function DrawInternal( x, y, name, alpha, noCorrections, dontEqualizeHeight )

	alpha = alpha or 255

	if ( !Icons[name] ) then
		Msg( "Warning: killicon not found '" .. name .. "'\n" )
		Icons[name] = Icons["default"]
	end

	local t = Icons[name]

	local w, h = GetSize( name, dontEqualizeHeight )

	-- HL2SB: as in GetSize -- never throw, and nothing to draw if we have no
	-- size (Lua treats 0 as true, so GMod's `if ( !w or !h )` is not enough).
	if ( t == nil or w == nil or h == nil or w <= 0 or h <= 0 ) then return end

	if ( !noCorrections ) then x = x - w * 0.5 end

	if ( t.type == TYPE_FONT ) then

		-- HACK: Default font killicons are anchored to the top, so correct for it
		if ( noCorrections && !dontEqualizeHeight ) then
			local _, h2 = GetSize( name, !dontEqualizeHeight )
			y = y + ( h - h2 ) / 2
		end

		if ( !noCorrections ) then y = y - h * 0.1 end

		surface.SetTextPos( x, y )
		SelectFont( t.font )
		surface.SetTextColor( t.color.r, t.color.g, t.color.b, alpha )
		surface.DrawText( t.character )

	end

	if ( t.type == TYPE_MATERIAL ) then

		if ( !noCorrections ) then y = y - h * 0.3 end

		surface.SetMaterial( t.material )
		surface.SetDrawColor( t.color.r, t.color.g, t.color.b, alpha )
		surface.DrawTexturedRect( x, y, w, h )

	end

	if ( t.type == TYPE_MATERIAL_UV ) then

		if ( !noCorrections ) then y = y - h * 0.3 end

		local tw = t.material:Width()
		local th = t.material:Height()
		surface.SetMaterial( t.material )
		surface.SetDrawColor( t.color.r, t.color.g, t.color.b, alpha )
		surface.DrawTexturedRectUV( x, y, w, h, t.tex_x / tw, t.tex_y / th, ( t.tex_x + t.tex_w ) / tw, ( t.tex_y + t.tex_h ) / th )

	end

end

-- Old function with weird vertical adjustments
function Draw( x, y, name, alpha )

	DrawInternal( x, y, name, alpha )

end

-- The new function that doesn't have the weird vertical adjustments
function Render( x, y, name, alpha, dontEqualizeHeight )

	DrawInternal( x, y, name, alpha, true, dontEqualizeHeight )

end

local Color_Icon = Color( 255, 80, 0, 255 )

Add( "default", "HUD/killicons/default", Color_Icon )
AddAlias( "suicide", "default" )

-- Publish the icon table and this file's revision on the module table (see the
-- guard at the top).
__icons    = Icons
__revision = KILLICON_REVISION
