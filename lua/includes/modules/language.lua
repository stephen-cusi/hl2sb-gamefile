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
	--
	-- The engine has no Lua GetUILanguage binding; cl_language is the convar
	-- the engine itself fills from Steam ("english", "schinese", "russian",
	-- ...).  Falls back to engine.GetUILanguage for when that shows up.
	local lang = nil
	if ( GetConVar ~= nil ) then
		local ok, cvar = pcall( GetConVar, "cl_language" )
		if ( ok and cvar ~= nil ) then
			local ok2, value = pcall( cvar.GetString, cvar )
			if ( ok2 and value ~= nil and value != "" ) then
				lang = value
			end
		end
	end
	if ( lang == nil and engine ~= nil and engine.GetUILanguage ~= nil ) then
		local ok, value = pcall( engine.GetUILanguage )
		if ( ok and value ~= nil ) then
			lang = value
		end
	end

	if ( lang ~= nil and entry[ lang ] ~= nil ) then
		return entry[ lang ]
	end

	return entry.en or next( entry ) or key
end

-------------------------------------------------------------------------------
-- Purpose: True when the token is registered here
-------------------------------------------------------------------------------
function HasPhrase( key )
	return Phrases[ StripHash( key ) ] ~= nil
end

-------------------------------------------------------------------------------
-- HL2SB: built-in phrases GMod ships in resource/localization/<lang>/
-- spawnmenu.properties.  These four back the weapon-selection info box
-- (weapon_base/cl_init.lua feeds "#entityinfo.*" to markup.Parse, which
-- resolves tokens through language.GetPhrase).  Values verbatim from GMod's
-- properties files; keys use the cl_language spelling ("schinese", not
-- "zh-cn").  Non-ASCII kept as \u{} escapes so the file stays pure ASCII.
-------------------------------------------------------------------------------
AddTable(
{
	[ "entityinfo.author" ] =
	{
		en			= "Author:",
		german		= "Autor",
		french		= "Auteur :",
		spanish		= "Autor:",
		russian		= "\u{0410}\u{0432}\u{0442}\u{043E}\u{0440}:",
		japanese	= "\u{4F5C}\u{6210}\u{8005}\u{FF1A}",
		korean		= "\u{C791}\u{C131}\u{C790}:",
		schinese	= "\u{4F5C}\u{8005}\u{FF1A}",
		tchinese	= "\u{4F5C}\u{8005}\u{FF1A}",
	},

	[ "entityinfo.contact" ] =
	{
		en			= "Contact:",
		german		= "Kontakt",
		french		= "Contact :",
		spanish		= "Contacto:",
		russian		= "\u{041A}\u{043E}\u{043D}\u{0442}\u{0430}\u{043A}\u{0442}\u{044B}:",
		japanese	= "\u{9023}\u{7D61}\u{5148}\u{FF1A}",
		korean		= "\u{C5F0}\u{B77D}\u{CC98}:",
		schinese	= "\u{8054}\u{7CFB}\u{65B9}\u{5F0F}\u{FF1A}",
		tchinese	= "\u{806F}\u{7D61}\u{65B9}\u{5F0F}\u{FF1A}",
	},

	[ "entityinfo.purpose" ] =
	{
		en			= "Purpose:",
		german		= "Zweck",
		french		= "Usage :",
		spanish		= "Prop\u{00F3}sito:",
		russian		= "\u{041D}\u{0430}\u{0437}\u{043D}\u{0430}\u{0447}\u{0435}\u{043D}\u{0438}\u{0435}:",
		japanese	= "\u{7528}\u{9014}\u{FF1A}",
		korean		= "\u{BAA9}\u{C801}:",
		schinese	= "\u{76EE}\u{7684}\u{FF1A}",
		tchinese	= "\u{76EE}\u{7684}\u{FF1A}",
	},

	[ "entityinfo.instructions" ] =
	{
		en			= "Instructions:",
		german		= "Anweisungen",
		french		= "Instructions\u{00A0}:",
		spanish		= "Instrucciones:",
		russian		= "\u{0418}\u{043D}\u{0441}\u{0442}\u{0440}\u{0443}\u{043A}\u{0446}\u{0438}\u{0438}:",
		japanese	= "\u{4F7F}\u{7528}\u{65B9}\u{6CD5}\u{FF1A}",
		korean		= "\u{C124}\u{BA85}:",
		schinese	= "\u{7528}\u{6CD5}\u{FF1A}",
		tchinese	= "\u{8AAA}\u{660E}\u{FF1A}",
	},
} )

-------------------------------------------------------------------------------
-- HL2SB: GMod ships its object names as Java-style .properties files under
-- resource/localization/<lang>/ -- entities.properties carries every built-in
-- HL2 NPC / weapon / prop / ammo display name, spawnmenu.properties the
-- entityinfo.* / undo.generic.* / spawnmenu.* strings, and so on.  The fork
-- mounts the garrysmod content as a GAME search path, so the tokens are
-- loaded straight from there in the UI language instead of hand-copying
-- hundreds of entries.  With the mount absent the table keeps the built-ins
-- registered above and GetPhrase falls back to the key, exactly like GMod
-- with a missing token.  English is loaded first as the base, the UI
-- language on top of it; entries are keyed by the cl_language spelling
-- ("schinese", not "zh-cn") because that is what GetPhrase looks up.
-------------------------------------------------------------------------------

local LANGUAGE_DIRS = {
	english		= "en",
	schinese	= "zh-cn",
	tchinese	= "zh-tw",
	russian		= "ru",
	japanese	= "ja",
	korean		= "ko",
	german		= "de",
	french		= "fr",
	spanish		= "es-es",
	italian		= "it",
	polish		= "pl",
	dutch		= "nl",
	turkish		= "tr",
	ukrainian	= "uk",
	czech		= "cs",
	danish		= "da",
	finnish		= "fi",
	greek		= "el",
	hungarian	= "hu",
	norwegian	= "no",
	swedish		= "sv-se",
	brazilian	= "pt-br",
	portuguese	= "pt-pt",
	romanian	= "ro",
	thai		= "th",
	vietnamese	= "vi",
	hebrew		= "he",
	croatian	= "hr",
	estonian	= "et",
	lithuanian	= "lt",
	slovak		= "sk",
	bulgarian	= "bg",
}

local PROPERTY_FILES = {
	"entities.properties",		-- class names: HL2 NPCs, weapons, props, ammo
	"spawnmenu.properties",		-- entityinfo.*, undo.generic.*, spawnmenu.*
	"tool.properties",
	"hints.properties",
	"postprocessing.properties",
	"community.properties",
	"context.properties",
}

local function PropertiesLanguageCode()
	local code = "english"
	if ( GetConVar ~= nil ) then
		local ok, cvar = pcall( GetConVar, "cl_language" )
		if ( ok and cvar ~= nil ) then
			local ok2, value = pcall( cvar.GetString, cvar )
			if ( ok2 and value ~= nil and value != "" ) then
				code = value
			end
		end
	end
	return code
end

local function UnescapePropertyValue( value )
	-- the Java properties escapes GMod's files actually use: "\uXXXX" (all
	-- the CJK / cyrillic values ship escaped), "\:" and "\=" (fr/es).
	local out = string.gsub( value, "\\u(%x%x%x%x)", function( hex )
		local n = tonumber( hex, 16 )
		if ( n == nil ) then return "" end
		return utf8.char( n )
	end )
	return string.gsub( out, "\\([:=])", "%1" )
end

local function LoadPropertiesFile( path, code )
	if ( file == nil or file.Read == nil ) then return end

	local ok, data = pcall( file.Read, path, "GAME" )
	if ( !ok or data == nil or data == "" ) then return end

	for line in string.gmatch( data, "([^\r\n]+)" ) do
		local first = string.sub( line, 1, 1 )
		if ( first ~= "#" and first ~= "!" ) then
			local key, value = string.match( line, "^%s*([^=]-)%s*=%s*(.*)$" )
			if ( key ~= nil and key ~= "" and value ~= nil ) then
				value = UnescapePropertyValue( value )

				local entry = Phrases[ key ]
				if ( entry == nil or type( entry ) ~= "table" ) then
					entry = {}
				end
				if ( code == "en" and entry.en == nil ) then
					entry.en = value
				end
				entry[ code ] = value
				Phrases[ key ] = entry
			end
		end
	end
end

local function LoadGModProperties()
	-- English base first, so any language falls back to it; the UI language
	-- on top.  The whole thing is pcall-guarded: a missing mount or a read
	-- hiccup must never take the module (and the loading screen) down.
	pcall( function()
		if ( file == nil or file.Read == nil ) then return end

		for _, name in ipairs( PROPERTY_FILES ) do
			LoadPropertiesFile( "resource/localization/en/" .. name, "en" )
		end

		local code = PropertiesLanguageCode()
		local dir = LANGUAGE_DIRS[ code ]
		if ( dir ~= nil and dir != "en" ) then
			for _, name in ipairs( PROPERTY_FILES ) do
				LoadPropertiesFile( "resource/localization/" .. dir .. "/" .. name, code )
			end
		end
	end )
end

LoadGModProperties()
