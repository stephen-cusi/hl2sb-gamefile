------------------------------------------------------------------------------
-- hl2sb_util_keyvalues.lua - HL2SB GMod compat (2026-09-25)
--
-- util.KeyValuesToTable( kvtext ) -> table|nil
--
-- GMod ships this exact function as LUA (lua/includes/extensions/util.lua),
-- so a Lua implementation here is faithful, not a shortcut - the engine-side
-- treatment is only for util.TableToJSON / util.JSONToTable, which GMod does
-- in C++ (see game/shared/lua/lutil_shared.cpp).
--
-- Valve KeyValues text: "name" { "key" "value" ... } blocks, // comments.
-- Leaves become strings, blocks become nested tables; the ROOT block's name
-- is discarded (GMod semantics - player_auth.lua's settings/users.txt relies
-- on the shape { group = { name = steamid } }).
------------------------------------------------------------------------------

if ( util ~= nil and util.KeyValuesToTable == nil ) then

	local function kvTokenize( text )
		local tokens = {}
		local i = 1
		local n = #text

		while ( i <= n ) do
			local c = text:sub( i, i )

			if ( c == '"' ) then
				local j = i + 1
				local out = {}
				while ( j <= n ) do
					local ch = text:sub( j, j )
					if ( ch == '\\' and j < n ) then
						out[ #out + 1 ] = text:sub( j + 1, j + 1 )
						j = j + 2
					elseif ( ch == '"' ) then
						break
					else
						out[ #out + 1 ] = ch
						j = j + 1
					end
				end
				tokens[ #tokens + 1 ] = table.concat( out )
				i = j + 1

			elseif ( c == '/' and text:sub( i + 1, i + 1 ) == '/' ) then
				local nl = text:find( '\n', i ) or n + 1
				i = nl

			elseif ( c == '{' or c == '}' ) then
				tokens[ #tokens + 1 ] = c
				i = i + 1

			elseif ( c:match( '%s' ) ) then
				i = i + 1

			else
				-- bare word: read until whitespace or a brace
				local j = i
				while ( j <= n ) do
					local ch = text:sub( j, j )
					if ( ch:match( '%s' ) or ch == '{' or ch == '}' ) then break end
					j = j + 1
				end
				tokens[ #tokens + 1 ] = text:sub( i, j - 1 )
				i = j
			end
		end

		return tokens
	end

	local function kvParseBlock( tokens, pos )
		local node = {}

		while ( pos <= #tokens ) do
			local tok = tokens[ pos ]
			if ( tok == "}" ) then
				return node, pos + 1
			end

			local key = tok
			pos = pos + 1

			if ( pos > #tokens ) then break end

			if ( tokens[ pos ] == "{" ) then
				local child
				child, pos = kvParseBlock( tokens, pos + 1 )
				node[ key ] = child
			else
				node[ key ] = tokens[ pos ]
				pos = pos + 1
			end
		end

		return node, pos
	end

	function util.KeyValuesToTable( text )
		if ( type( text ) ~= "string" or text == "" ) then return nil end

		local tokens = kvTokenize( text )
		-- a comment-only / empty file is a valid empty config, not an error
		if ( #tokens == 0 ) then return {} end

		-- The first token is the root block's name; GMod discards it.
		local startPos = 1
		if ( tokens[ 2 ] == "{" ) then
			startPos = 3
		end

		local ok, result, finalPos = pcall( kvParseBlock, tokens, startPos )
		if ( ok and type( result ) == "table" ) then return result end
		return nil
	end
end
