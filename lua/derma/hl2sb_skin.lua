--[[----------------------------------------------------------------------------
	hl2sb_skin.lua  --  HL2SB's own skin system for the derma framework.

	API shaped like GMod's (derma.DefineSkin / derma.SkinHook / panel:SetSkin),
	implementation original: flat vector drawing through surface.* only -- no
	GWEN bitmap skins, no material lookups, nothing that can render as the
	purple error checker.

	The hook protocol matches what control files call:

		derma.SkinHook( "Paint",  "Button",     self, w, h )  ->  SKIN:PaintButton( self, w, h )
		derma.SkinHook( "Think",  "Button",     self )        ->  SKIN:ThinkButton( self )
		derma.SkinHook( "Layout", "Button",     self )        ->  SKIN:LayoutButton( self )

	Skins are plain tables registered under a name; the control that paints can
	also run WITHOUT a skin (every hook miss is a silent no-op), which is what
	keeps the framework usable from the GameUI state where the default skin may
	not have loaded yet.
-----------------------------------------------------------------------------]]

if ( not ( ( CLIENT or _GAMEUI ) and surface ) ) then return end

local Skins = {}
local DefaultSkinName = "HL2SBDefault"

derma = derma or {}

--[[-------------------------------------------------------------------------
	Fonts

	surface.CreateFont( name, table ) files a font under its name; the HFont
	handle is resolved lazily through surface.SetFont( name ) (which in this
	fork returns the handle), with draw.GetFont as the fallback -- the same
	resolution order lua/includes/init.lua settled on for Panel:SetFont.
---------------------------------------------------------------------------]]

local FontHandles = {}

derma.CreateFont = function( name, tbl )
	return surface.CreateFont( name, tbl )
end

function derma.GetFontHandle( name )
	if ( not name ) then return nil end

	local h = FontHandles[ name ]
	if ( h ~= nil ) then return h or nil end

	h = nil
	if ( surface.SetFont ) then
		h = surface.SetFont( name )
	end
	if ( ( not h or h == 0 ) and _G.draw and draw.GetFont ) then
		h = draw.GetFont( name )
	end

	FontHandles[ name ] = h or false		-- false = resolved-and-missing, do not retry
	return h or nil
end

--- Draw text with a font NAME, falling back gracefully.
function derma.DrawText( strFontName, x, y, strText, col )
	local font = derma.GetFontHandle( strFontName )
	if ( not font ) then return end

	surface.DrawSetTextFont( font )
	surface.DrawSetTextColor( col[ 1 ] or col.r or 255, col[ 2 ] or col.g or 255,
		col[ 3 ] or col.b or 255, col[ 4 ] or col.a or 255 )
	surface.DrawSetTextPos( x, y )
	surface.DrawPrintText( strText )
end

function derma.GetTextSize( strFontName, strText )
	local font = derma.GetFontHandle( strFontName )
	if ( not font ) then return 0, 0 end

	local w, h = surface.GetTextSize( font, strText )
	return w or 0, h or 0
end

--- Rounded rectangle as N axis-aligned spans (cheap, no material needed).
function derma.DrawRoundedBox( radius, w, h, col )
	surface.DrawSetColor( col[ 1 ] or col.r or 255, col[ 2 ] or col.g or 255,
		col[ 3 ] or col.b or 255, col[ 4 ] or col.a or 255 )

	radius = math.max( 0, math.min( radius, math.floor( math.min( w, h ) / 2 ) ) )

	surface.DrawFilledRect( radius, 0, w - radius * 2, h )			-- middle band
	surface.DrawFilledRect( 0, radius, w, h - radius * 2 )		-- full-width band

	-- four corners as quarter circles made of scanlines
	for i = 0, radius - 1 do
		local inset = radius - math.floor( math.sqrt( radius * radius - ( radius - i ) * ( radius - i ) ) )
		local yTop = ( i < radius ) and i or nil
		if ( yTop ) then
			local rowH = 1
			local x0 = inset
			local xW = radius - inset
			surface.DrawFilledRect( x0, yTop, xW, rowH )						-- top-left
			surface.DrawFilledRect( w - x0 - xW, yTop, xW, rowH )			-- top-right
			surface.DrawFilledRect( x0, h - yTop - rowH, xW, rowH )			-- bottom-left
			surface.DrawFilledRect( w - x0 - xW, h - yTop - rowH, xW, rowH )	-- bottom-right
		end
	end
end

--- GMod's Color() returns a table with r/g/b/a fields and is indexable both ways.
if ( not Color ) then
	function Color( r, g, b, a )
		return { r = r or 255, g = g or 255, b = b or 255, a = a or 255,
			[ 1 ] = r or 255, [ 2 ] = g or 255, [ 3 ] = b or 255, [ 4 ] = a or 255,
			Unpack = function( c ) return c[ 1 ], c[ 2 ], c[ 3 ], c[ 4 ] end }
	end
end

--[[-------------------------------------------------------------------------
	Skin registry + hook dispatch
---------------------------------------------------------------------------]]

--- GMod's derma.DefineSkin( name, description, skinTable ).  The table's
--- methods are called with the skin as self, e.g. SKIN:PaintButton( pnl, w, h ).

-- extensions/client/panel.lua (the surviving GMod-panel.lua helper) compares
-- derma.SkinChangeIndex() to a cached number to decide whether to re-resolve
-- panel skins; bump the counter whenever a skin is (re)defined.
local SkinChangeIndex = 0

function derma.SkinChangeIndex()
	return SkinChangeIndex
end

function derma.DefineSkin( strName, strDescription, tbl )
	Skins[ strName ] = tbl
	SkinChangeIndex = SkinChangeIndex + 1
	return tbl
end

function derma.GetSkinTable()
	return Skins
end

-- extensions/client/panel.lua's GetSkin chain resolves through these two.
function derma.GetDefaultSkin()
	return Skins[ DefaultSkinName ]
end

function derma.GetNamedSkin( strName )
	return Skins[ strName ]
end

function derma.GetDefaultSkinTable()
	return Skins[ DefaultSkinName ]
end

--- GMod's signature: derma.SkinHook( strType, strName, panel, ... ).
--- Returns false when nothing handled the hook (GMod returns nil-ish too).
function derma.SkinHook( strType, strName, pnl, ... )
	local skin = pnl.GetSkin and pnl:GetSkin() or nil
	if ( not skin ) then skin = Skins[ DefaultSkinName ] end
	if ( not skin ) then return false end

	local func = skin[ strType .. strName ]
	if ( not func ) then return false end

	local ok, err = pcall( func, skin, pnl, ... )
	if ( not ok ) then
		Warning( "derma.SkinHook: " .. strType .. strName .. " failed: " .. tostring( err ) .. "\n" )
	end
	return true
end

--- Resolve a panel's skin by name at paint time (GMod caches it on the panel;
--- a name lookup is a table hit, so no cache is needed).
function derma.SetSkin( pnl, strSkinName )
	if ( pnl.SetSkinName ) then pnl:SetSkinName( strSkinName ) end
end
