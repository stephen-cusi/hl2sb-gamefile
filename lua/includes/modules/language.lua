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

-------------------------------------------------------------------------------
-- Purpose: Registers one phrase
-- Input  : key   - token, with or without a leading '#'
--          value - string, or a table of language -> string
-------------------------------------------------------------------------------
function Add( key, value )
	if ( type( key ) ~= "string" ) then return end

	key = StripHash( key )

	if ( istable( value ) ) then
		Phrases[ key ] = value
	else
		Phrases[ key ] = { en = tostring( value ) }
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
