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

--[[----------------------------------------------------------------------------
	hl2sb_giveweapon <classname>

	SMenu's weapon page runs this instead of the engine's own "give", which is
	cheat flagged: with sv_cheats 0 (the multiplayer default) clicking a weapon in
	the spawn menu did nothing at all.  GiveNamedItem() is what "give" calls
	internally, so this is the same thing without the cheat check.
------------------------------------------------------------------------------]]
concommand.Add( "hl2sb_giveweapon", function( ply, cmd, args )
	if ( not IsValid( ply ) ) then return end

	local class = args and args[ 1 ]
	if ( class == nil or class == "" ) then
		Dbg( "hl2sb_giveweapon <classname>" )
		return
	end

	local ent = ply:GiveNamedItem( class )
	if ( not IsValid( ent ) ) then
		Dbg( "hl2sb_giveweapon: could not give '" .. class .. "'" )
	end
end, nil, "Give a weapon/item to the calling player (not cheat protected)" )

print( "[HL2SB] hl2sb_spawn_undo.lua loaded (GMod-style undo recording)" )
