--[[----------------------------------------------------------------------------
    hl2sb_displayname.lua  (client)

    One place that answers "what is this class CALLED?" for the UI.

    Why
    ---
    Two different places print an entity's name at the player:

        * the kill feed    (game/client/gmod_deathnotice.lua)
        * the undo notices (lua/includes/modules/undo.lua)

    and both were given what the engine knows - the CLASS NAME - so a Lua NPC was
    printed as "xxx_096", and a RESKINNED NPC as the class it inherits from
    ("combine_s") instead of the name its own script registered.

    GMod does not do that: its names come from the CONTENT, which is why an addon NPC
    reads the way its author wrote it.  So that is where this looks, in order:

        1. list.Get("NPC")   - what the spawn menu itself shows for that class
        2. scripted_ents     - the scripted entity's own PrintName
        3. weapons.Get       - a Lua SWEP's PrintName
        4. language          - the "#class" token, when it really resolves
        5. the class itself  - last resort

    It is a GLOBAL on purpose: undo.lua is a module that loads before autorun, so a
    local in either file could not be shared.  Callers read it at RUNTIME (inside a
    hook / net handler), never at load time, so load order does not matter.
------------------------------------------------------------------------------]]

if ( not CLIENT ) then return end

--- Only CLASS-SHAPED tokens are translated.  A player's name ("Player", "Steve") and
--- anything already human must come back exactly as it arrived.
local function ClassShaped( s )
	local class = s

	if ( string.sub( class, 1, 1 ) == "#" ) then class = string.sub( class, 2 ) end

	if ( string.match( class, "^[%w_]+$" ) == nil ) then return nil end

	return class
end

local function FromRegistries( class )
	if ( _G.list ~= nil and list.Get ~= nil ) then
		local npcs = list.Get( "NPC" )

		if ( npcs ~= nil ) then
			for _, t in pairs( npcs ) do
				if ( t ~= nil and t.Class == class and t.Name ~= nil and t.Name ~= "" ) then
					return t.Name
				end
			end
		end
	end

	if ( _G.scripted_ents ~= nil and scripted_ents.GetStored ~= nil ) then
		local stored = scripted_ents.GetStored( class )

		if ( stored ~= nil ) then
			local name = ( stored.t ~= nil and stored.t.PrintName ) or stored.PrintName

			if ( name ~= nil and name ~= "" ) then return name end
		end
	end

	if ( _G.weapons ~= nil and weapons.Get ~= nil ) then
		local w = weapons.Get( class )

		if ( w ~= nil and w.PrintName ~= nil and w.PrintName ~= "" ) then return w.PrintName end
	end

	if ( _G.language ~= nil and language.GetPhrase ~= nil ) then
		local phrase = language.GetPhrase( "#" .. class )

		-- an unresolved token comes back as "#class" - that is not a name
		if ( phrase ~= nil and phrase ~= "" and string.sub( phrase, 1, 1 ) ~= "#" ) then
			return phrase
		end
	end

	return nil
end

--- The name to SHOW for a string that may be a class name.  Anything that is not
--- class-shaped, and anything the content does not know, is returned untouched.
function HL2SB_GetDisplayName( s )
	if ( s == nil or s == "" ) then return s end

	local class = ClassShaped( s )
	if ( class == nil ) then return s end

	return FromRegistries( class ) or s
end
