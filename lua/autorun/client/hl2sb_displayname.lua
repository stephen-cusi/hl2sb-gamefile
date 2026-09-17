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
        5. the cosmetic strip - "npc_zombie" -> "Zombie" (last resort, see CosmeticName)

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

--- The engine's cosmetic spelling of a class name: strip the prefix, capitalise what is
--- left.  This mirrors KillFeed_DisplayName (game/client/hl2mp/hud_killfeed.cpp:100) --
--- but that C++ helper used to run BEFORE Lua saw the string, and stripping "npc_" off
--- "npc_shaklin_scp096" left "Shaklin_scp096", a string no content registry is keyed by:
--- the kill feed printed it instead of the NPC's own ENT.PrintName ("SCP 096").  The
--- engine now hands Lua the RAW class (KillFeed_RawClassName), so this runs last and
--- only for classes the content does not know - the game's own NPCs still read as
--- "Zombie"/"Headcrab" because they have no PrintName anywhere.
local COSMETIC_STRIP = { "npc_", "monster_", "weapon_", "item_", "ammo_", "entity_", "func_", "prop_" }

local function CosmeticName( class )
	for _, prefix in ipairs( COSMETIC_STRIP ) do
		if ( string.sub( class, 1, #prefix ) == prefix ) then
			local rest = string.sub( class, #prefix + 1 )

			if ( rest == "" ) then return nil end

			return string.upper( string.sub( rest, 1, 1 ) ) .. string.sub( rest, 2 )
		end
	end

	return nil
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

	-- Nothing in the content knows this class: fall back to the engine's cosmetic
	-- spelling ("npc_zombie" -> "Zombie"), which is what the kill feed used to show for
	-- EVERYTHING.  It is the last resort now, not the first word.
	return CosmeticName( class )
end

--- The name to SHOW for a string that may be a class name.  Anything that is not
--- class-shaped, and anything the content does not know, is returned untouched.
function HL2SB_GetDisplayName( s )
	if ( s == nil or s == "" ) then return s end

	local class = ClassShaped( s )
	if ( class == nil ) then return s end

	return FromRegistries( class ) or s
end
