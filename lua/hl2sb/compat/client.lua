-- Native font and panel compatibility, loaded before original Derma.
include( "hl2sb/compat/drawing.lua" )

local hl2sb_CustomFonts = {
	-- family        file (relative to the game dir)
	--
	-- The name is only a label here: on Windows CMatSystemSurface::
	-- AddCustomFontFile ends in AddFontResourceExA(path, FR_PRIVATE) and GDI
	-- then keys the face by the family recorded INSIDE the ttf, not by this
	-- argument.  For the Roboto style variants those differ: GDI sees
	-- Roboto-Regular/Bold/Italic/BoldItalic as family "Roboto", but the
	-- Medium/Light face as "Roboto Lt", Black as "Roboto Bk" and the
	-- Condensed face as "Roboto Cn" (the Windows nameID 1 record carries the
	-- width; the Macintosh one does not).  So "Roboto" -- what DermaLarge and
	-- the spawnmenu markup ask for -- is supplied by the four straight faces
	-- below; the variants are registered for completeness and appear under
	-- their own families.  tools/ttf_gdi_families.lua prints this mapping.
	{ "Roboto",            "resource/Roboto-Regular.ttf" },          -- DermaLarge
	{ "Roboto",            "resource/Roboto-Bold.ttf" },
	{ "Roboto",            "resource/Roboto-Italic.ttf" },
	{ "Roboto",            "resource/Roboto-BoldItalic.ttf" },
	{ "Roboto",            "resource/Roboto-Medium.ttf" },            -- GDI: Roboto Lt
	{ "Roboto",            "resource/Roboto-MediumItalic.ttf" },      -- GDI: Roboto Lt
	{ "Roboto",            "resource/Roboto-Light.ttf" },             -- GDI: Roboto Lt
	{ "Roboto",            "resource/Roboto-LightItalic.ttf" },       -- GDI: Roboto Lt
	{ "Roboto",            "resource/Roboto-Thin.ttf" },              -- GDI: Roboto Th
	{ "Roboto",            "resource/Roboto-ThinItalic.ttf" },        -- GDI: Roboto Th
	{ "Roboto",            "resource/Roboto-Black.ttf" },             -- GDI: Roboto Bk
	{ "Roboto",            "resource/Roboto-BlackItalic.ttf" },       -- GDI: Roboto Bk
	{ "Roboto",            "resource/Roboto-Condensed.ttf" },         -- GDI: Roboto Cn
	{ "Roboto",            "resource/Roboto-BoldCondensed.ttf" },     -- GDI: Roboto Cn
	{ "Roboto",            "resource/Roboto-BoldCondensedItalic.ttf" }, -- GDI: Roboto Cn
	{ "Roboto",            "resource/Roboto-CondensedItalic.ttf" },   -- GDI: Roboto Cn
	-- game icon/hud families named by resource/clientscheme.res and by GMod's
	-- own Lua; the files were already in the tree, just never registered
	{ "HalfLife2",         "resource/halflife2.ttf" },
	{ "HL2MP",             "resource/hl2mp.ttf" },
	{ "HL2SB",             "resource/hl2sb.ttf" },
	{ "HL2EP2",            "resource/hl2ep2.ttf" },
	{ "HL2cross",          "resource/HL2crosshairs.ttf" },
	{ "cs",                "resource/cs.ttf" },
	{ "cs",                "resource/csd.ttf" },                     -- csd.ttf declares family "cs"
	{ "Counter-Strike",    "resource/cstrike.ttf" },
	{ "Akbar",             "resource/akbar.ttf" },
	{ "Coolvetica",        "resource/coolvetica.ttf" },
	-- NOT registered, deliberately:
	--   lucidaconsole.ttf / marlett.ttf -- Windows already ships both
	--   families, so the files are redundant here.
}

for _, hl2sb_font in ipairs( hl2sb_CustomFonts ) do

	local hl2sb_ok = surface.AddCustomFontFile( hl2sb_font[ 1 ], hl2sb_font[ 2 ] )

	if ( not hl2sb_ok ) then
		-- Not fatal: LISurface.cpp:195 falls back to Verdana, so the family
		-- degrades to a visible face rather than to nothing.  Say so loudly
		-- anyway, because "my font is the wrong face" is otherwise invisible.
		Msg( "[HL2SB] AddCustomFontFile failed for '" .. hl2sb_font[ 1 ] ..
			"' (" .. hl2sb_font[ 2 ] .. ") -- that family will fall back\n" )
	end

end

    -- Original scripted panels own control registration and inheritance.
    include("extensions/client/panel.lua")
    local panel = FindMetaTable("Panel")
    panel.SetFGColorEx = function(self, r, g, b, a)
        return panel.SetFgColor(self, Color(r or 255, g or 255, b or 255, a or 255))
    end
    panel.SetBGColorEx = function(self, r, g, b, a)
        return panel.SetBgColor(self, Color(r or 255, g or 255, b or 255, a or 255))
    end
    panel.GetFGColor = panel.GetFgColor
    panel.GetBGColor = panel.GetBgColor
    if (!panel.SetExpensiveShadow) then
        function panel:SetExpensiveShadow(offset, color)
            self.m_iExpensiveShadowOffset = offset
            self.m_colExpensiveShadow = color
        end
    end
    if (!vgui.GetKeyboardFocus) then vgui.GetKeyboardFocus = input.GetFocus end
