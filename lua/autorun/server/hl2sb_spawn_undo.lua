--[[----------------------------------------------------------------------------
    hl2sb_spawn_undo.lua  (server)

    GMod-style spawn commands that record their own undo entry.

    Why this exists
    ---------------
    In Garry's Mod the engine does NOT record undo for you -- the code that
    creates something calls the undo API itself.  There are 43 call sites of
    undo.Create() in GMod:

        gamemodes/sandbox/gamemode/commands.lua   the spawnmenu's spawn helpers
                                                  ("prop_physics", "prop_ragdoll",
                                                   "NPC", "SENT", "SWEP", ...)
        gmod_tool/stools/*.lua                    every tool stool (weld, rope,
                                                  axis, winch, wheel, duplicator, ...)
        lua/autorun/properties/*.lua              property edits

    That is why "anything a player creates can be undone" in GMod: every
    creation path opts in.  This file is HL2SB's equivalent for spawning --
    the same four calls, in the same order, with the same names:

        undo.Create( name )
            undo.SetPlayer( ply )
            undo.AddEntity( ent )
        undo.Finish( text )        -- text is what the client notification shows

    HL2SB already has a C++ recorder (HL2SB_UndoRecord, called from
    props.cpp / baseentity.cpp for prop_physics_create and ent_create).  This is
    the Lua-side route, so a spawn can be made undoable without going through
    that code -- and it reports its own failures instead of dropping them.

    Commands
    --------
        hl2sb_spawnprop <model>      e.g. hl2sb_spawnprop props_junk/wood_crate001a

    Then "undo" removes it.  hl2sb_hud_debug 1 traces both sides.
----------------------------------------------------------------------------]]--

if ( not SERVER ) then return end

local function Dbg( ... )
	if ( GetConVarNumber( "hl2sb_hud_debug" ) == 0 ) then return end

	local out = {}
	for i = 1, select( "#", ... ) do out[ i ] = tostring( ( select( i, ... ) ) ) end

	print( "[HL2SB spawn] " .. table.concat( out, " " ) .. "\n" )
end

-- GMod's commands.lua body, in one place.
local function RecordUndo( ply, ent, name )
	if ( undo == nil or undo.Create == nil ) then
		Dbg( "RecordUndo: no undo module (lua/includes/modules/undo.lua did not load)" )
		return false
	end

	-- pcall so a failure here names itself instead of silently producing an
	-- empty undo stack -- the exact symptom that made this hard to find.
	local ok, err = pcall( function()
		undo.Create( name )
			undo.SetPlayer( ply )
			undo.AddEntity( ent )
		undo.Finish( name )
	end )

	if ( not ok ) then
		Dbg( "RecordUndo failed:", tostring( err ) )
		return false
	end

	Dbg( "RecordUndo ok:", name )
	return true
end

local function SpawnProp( ply, model )
	local ent = ents.Create( "prop_physics" )
	if ( not IsValid( ent ) ) then
		Dbg( "ents.Create( prop_physics ) returned nothing" )
		return nil
	end

	ent:SetModel( model )

	-- Place it in front of the player.  EyeAngles():Forward() is not guaranteed
	-- to exist here, and a throw at this point would leave a half-built entity
	-- with no undo entry, so fall back to plain eye position.
	local pos = ply:EyePos()
	local ok, fwd = pcall( function() return ply:EyeAngles():Forward() end )
	if ( ok and fwd ~= nil ) then
		pos = pos + fwd * 80
	end
	ent:SetPos( pos )

	-- The model has to exist, otherwise the prop spawns invisible and the undo
	-- entry would remove nothing.
	if ( ent:GetModel() == nil or ent:GetModel() == "" ) then
		Dbg( "model not found:", tostring( model ) )
		ent:Remove()
		return nil
	end

	ent:Spawn()
	ent:Activate()

	return ent
end

concommand.Add( "hl2sb_spawnprop", function( ply, cmd, args )
	if ( not IsValid( ply ) ) then return end
	if ( args == nil or args[ 1 ] == nil or args[ 1 ] == "" ) then
		Dbg( "hl2sb_spawnprop <model>  -- e.g. props_junk/wood_crate001a" )
		return
	end

	local model = args[ 1 ]
	if ( string.sub( model, 1, 7 ) ~= "models/" ) then
		model = "models/" .. model
	end
	if ( string.sub( model, -4 ) ~= ".mdl" ) then
		model = model .. ".mdl"
	end

	Dbg( "spawning:", model )
	local ent = SpawnProp( ply, model )
	if ( not IsValid( ent ) ) then return end

	RecordUndo( ply, ent, "#prop_physics (" .. model .. ")" )
end, nil, "Spawn a prop and record it in the undo stack (GMod-style)" )

-- ⚠️ RETIRED: these four now live in the ENGINE - game/server/
-- hl2sb_gm_commands.cpp provides gm_giveswep / gm_spawn / gm_spawnvehicle /
-- gm_spawnnpc / gm_spawnprop, and records undo through HL2SB_UndoRecord instead of
-- coming back through Lua.  One spawn path for every client that spawns something,
-- which is the point of having it in the engine at all.
--
-- (kept below, unreachable, as the reference for what each one has to do)
if ( true ) then return end

-- ===========================================================================
-- GMod's own spawn commands.
--
-- GMod defines these in its sandbox gamemode
-- (gamemodes/sandbox/gamemode/commands.lua) and its spawn menu talks to nothing
-- else.  Two things they do that `ent_create` cannot:
--
--   * a WEAPON is handed to the player instead of being created in the world.  A
--     world weapon entity has no owner, and that is what crashed the client on
--     `ent_create weapon_rpg` - the RPG's own setup assumes someone is holding it.
--   * every spawn registers an UNDO entry under the name the CONTENT uses, so the
--     notification reads "Zombie" (or the addon's own name) instead of "npc_zombie".
-- ===========================================================================

--- The name the content uses for a class - the same order the client's
--- hl2sb_displayname.lua uses, so both sides print the same thing.
local function NiceName( class )
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

	return class
end

--- GMod places everything it spawns in front of the player's eyes.
local function PlaceInFront( ply, ent, dist )
	local pos = ply:EyePos()
	local ok, fwd = pcall( function() return ply:EyeAngles():Forward() end )

	if ( ok and fwd ~= nil ) then
		pos = pos + fwd * ( dist or 80 )
	end

	ent:SetPos( pos )
end

--- Create, place, spawn and register one entity.  `setup` runs BEFORE Spawn, which is
--- where keyvalues have to be set (the NPC's equipment, for instance).
local function SpawnAndRecord( ply, class, model, setup )
	if ( ply == nil or not IsValid( ply ) ) then return nil end

	local ent = ents.Create( class )
	if ( not IsValid( ent ) ) then
		Dbg( "ents.Create failed:", tostring( class ) )
		return nil
	end

	if ( model ~= nil and model ~= "" ) then ent:SetModel( model ) end

	PlaceInFront( ply, ent )

	if ( setup ~= nil ) then
		local ok, err = pcall( setup, ent )

		if ( not ok ) then Dbg( "setup failed:", tostring( err ) ) end
	end

	ent:Spawn()
	ent:Activate()

	RecordUndo( ply, ent, NiceName( class ) )

	return ent
end

concommand.Add( "gm_giveswep", function( ply, cmd, args )
	if ( not IsValid( ply ) ) then return end

	local class = args ~= nil and args[ 1 ] or nil
	if ( class == nil or class == "" ) then return end

	-- GMod's Player:Give - HL2SB's GiveNamedItem (lua/includes/extensions/
	-- gmod_compat.lua:377).  The weapon goes straight into the player's inventory, so
	-- no world weapon entity is ever created.
	local ok, err = pcall( function() ply:Give( class ) end )

	Dbg( "gm_giveswep", tostring( class ), ok and "ok" or tostring( err ) )
end, nil, "Give yourself a weapon (GMod)" )

concommand.Add( "gm_spawn", function( ply, cmd, args )
	if ( not IsValid( ply ) ) then return end

	local class = args ~= nil and args[ 1 ] or nil
	if ( class == nil or class == "" ) then return end

	local model = args ~= nil and args[ 2 ] or nil
	if ( model ~= nil and string.sub( model, 1, 7 ) ~= "models/" and model ~= "" ) then
		model = "models/" .. model
	end

	Dbg( "gm_spawn", tostring( class ), tostring( model ) )
	SpawnAndRecord( ply, class, model )
end, nil, "Spawn an entity / prop / SENT (GMod)" )

concommand.Add( "gm_spawnvehicle", function( ply, cmd, args )
	if ( not IsValid( ply ) ) then return end

	local class = args ~= nil and args[ 1 ] or nil
	if ( class == nil or class == "" ) then return end

	Dbg( "gm_spawnvehicle", tostring( class ) )
	SpawnAndRecord( ply, class, nil )
end, nil, "Spawn a vehicle (GMod)" )

concommand.Add( "gm_spawnnpc", function( ply, cmd, args )
	if ( not IsValid( ply ) ) then return end

	local class = args ~= nil and args[ 1 ] or nil
	if ( class == nil or class == "" ) then return end

	-- the weapon an NPC spawns with, set once from the spawn menu.  It comes as the
	-- SECOND ARGUMENT: this fork binds no CreateConVar, so there is no gmod_npcweapon
	-- cvar to read (GMod keeps it in one; here the menu simply sends its choice).
	-- A cvar is still consulted when one exists, so both routes work.
	--
	-- It has to be applied BEFORE Spawn - it is a keyvalue, and this fork's NPC
	-- equipment support (additionalequipment) reads it at spawn time.
	local weapon = ( args ~= nil and args[ 2 ] ) or ""

	if ( weapon == "" and _G.GetConVarString ~= nil ) then
		weapon = GetConVarString( "gmod_npcweapon" ) or ""
	end

	Dbg( "gm_spawnnpc", tostring( class ), "weapon=" .. tostring( weapon ) )

	SpawnAndRecord( ply, class, nil, function( ent )
		if ( weapon ~= "" ) then
			ent:SetKeyValue( "additionalequipment", weapon )
		end
	end )
end, nil, "Spawn an NPC with the configured weapon (GMod)" )

print( "[HL2SB] hl2sb_spawn_undo.lua loaded (GMod-style undo recording)" )
