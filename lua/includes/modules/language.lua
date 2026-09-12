--========== HL2SB - GMod compat ==========--
--
-- Purpose: Phrase table (ported from Garry's Mod's language library).
--
--   GMod resolves "#token" through the engine's localization files.  HL2SB
--   already loads hl2/hl2sb token files, so this module is the *script* side:
--   addons register their own phrases with language.Add and read them back with
--   language.GetPhrase.  Anything already known to the engine still wins,
--   because surface/vgui resolve "#token" themselves.
--
--===========================================================================--

module( "language", package.seeall )

local Phrases = {}

local function StripHash( key )
	if ( type( key ) == "string" and key:sub( 1, 1 ) == "#" ) then
		return key:sub( 2 )
	end
	return key
end

-- ===========================================================================
-- HL2SB: the engine's own phrase table.
--
-- This fork binds ILocalize to Lua as the `Localizations` library
-- (game/shared/lua/lsrcinit.cpp:120 -> luaopen_Localizations,
-- game/shared/lua/llocalization.cpp:27 Find / :52 AddString), which is exactly
-- GMod's language library done engine-side -- but nothing in lua/ ever called
-- it, so every phrase had to be registered by hand through language.Add.
--
-- That matters for the GMod spawnmenu: its ~75 "#spawnmenu.*", "#preset.*",
-- "#ropematerial.*" and "#menubar.*" tokens are now shipped in
-- resource/hl2sb_english.txt (and hl2sb_schinese.txt), which is where ILocalize
-- reads them from.  Asking the engine first also means the engine's Label
-- (which localises a "#token" passed to SetText) and Lua agree on the same
-- string.
-- ===========================================================================
local function EngineFind( token )
	if ( _G.Localizations == nil or Localizations.Find == nil ) then return nil end

	local candidates = { "#" .. token, token }

	for _, candidate in ipairs( candidates ) do
		local ok, str = pcall( Localizations.Find, candidate )
		-- ILocalize::Find returns NULL for an unknown token, and some builds
		-- hand the token straight back; neither counts as a translation.
		if ( ok and type( str ) == "string" and str ~= "" and str ~= candidate ) then
			return str
		end
	end

	return nil
end

-------------------------------------------------------------------------------
-- Purpose: Registers one phrase
-- Input  : key   - token, with or without a leading '#'
--          value - string, or a table of language -> string
-------------------------------------------------------------------------------
function Add( key, value )
	if ( type( key ) ~= "string" ) then return end

	local stripped = StripHash( key )

	if ( istable( value ) ) then
		Phrases[ stripped ] = value
	else
		Phrases[ stripped ] = { en = tostring( value ) }
	end

	-- HL2SB: register engine-side as well, so a "#token" handed straight to a
	-- panel (Panel:SetText( "#MyToken" ), which the engine's Label localises
	-- through ILocalize) resolves too, not just language.GetPhrase.
	if ( type( value ) == "string" and _G.Localizations ~= nil and Localizations.AddString ~= nil ) then
		pcall( Localizations.AddString, stripped, value )
	end
end

-------------------------------------------------------------------------------
-- Purpose: Registers every phrase in a table
-------------------------------------------------------------------------------
function AddTable( tbl )
	if ( not istable( tbl ) ) then return end

	for k, v in pairs( tbl ) do
		Add( k, v )
	end
end

-------------------------------------------------------------------------------
-- Purpose: Looks a phrase up. Falls back to the key itself so a missing token
--          shows up as readable text rather than nil.
-------------------------------------------------------------------------------
function GetPhrase( key )
	if ( type( key ) ~= "string" ) then return "" end

	-- HL2SB: the engine's ILocalize wins -- that is where
	-- resource/hl2sb_<language>.txt lives, and it is what the engine's own
	-- Label::SetText consults for a "#token".
	local fromEngine = EngineFind( StripHash( key ) )
	if ( fromEngine ~= nil ) then
		return fromEngine
	end

	local entry = Phrases[ StripHash( key ) ]
	if ( entry == nil ) then return key end

	-- Prefer the map language, then English, then whatever exists.
	if ( engine ~= nil and engine.GetUILanguage ~= nil ) then
		local ok, lang = pcall( engine.GetUILanguage )
		if ( ok and lang ~= nil and entry[ lang ] ~= nil ) then
			return entry[ lang ]
		end
	end

	return entry.en or next( entry ) or key
end

-------------------------------------------------------------------------------
-- Purpose: True when the token is registered here
-------------------------------------------------------------------------------
function HasPhrase( key )
	return Phrases[ StripHash( key ) ] ~= nil
end
