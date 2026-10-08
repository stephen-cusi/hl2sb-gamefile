--[[----------------------------------------------------------------------------
    gamemodes/base/gamemode/save_load.lua  --  gm_save / gm_load.

    Lives in the base gamemode so every gamemode inherits the commands
    (the fork's "commands follow the base" rule).  An identical copy stays
    in deathmatch (included while that gamemode still lists it explicitly);
    double registration is safe - concommand.Add dedupes in the engine.

    GMod's sandbox/gamemode/save_load.lua port.  The serialisation layer is
    byte-for-byte GMod's (gmsave + duplicator.CopyEnts/Paste + JSON); what
    differs is the storage hop.  GMod ships the compressed duplicator JSON to
    the client and calls engine.WriteSave, which wraps it in a .gms archive the
    engine unwraps on load, firing the "LoadGModSave" hook back into the
    server.  This engine has neither engine.WriteSave nor the .gms loader, so
    the server writes the compressed JSON straight into
    data/hl2sb_saves/<name>.txt (the data/ write whitelist allows .txt and
    file.Write builds parent directories itself) and gm_load reads it back.
    Same flow, same file contents, one hop less.

    Admin rules are GMod's: single player always may save/load; multiplayer
    requires ply:IsAdmin() plus a 10 second cooldown (the serialisation walk is
    expensive on big maps).
--]]----------------------------------------------------------------------------

if ( not SERVER ) then return end

local SAVE_DIR = "hl2sb_saves"

-- ---------------------------------------------------------------------------
-- GMod sandbox/gamemode/commands.lua 的 MakeProp / MakeRagdoll。duplicator.Paste
-- 只认 duplicator.RegisterEntityClass 注册过的类，没有这些，读档时所有
-- prop_physics 都会被丢弃。这里的分叉差异：
--   * SetCreator 没有绑定（GMod 用它做撤销归属）——跳过；
--   * FixInvalidPhysicsObject 需要 PhysObj:GetAABB（也没有绑定）——跳过，
--     它只修"vphysics 盒与模型盒差太多"的坏档 prop，不影响正常粘贴。
-- ---------------------------------------------------------------------------

local function DoPropSpawnedEffect( e )

	if ( DisablePropCreateEffect ) then return end

	e:SetSpawnEffect( true )

end

local function MakeProp( ply, pos, ang, model, _, data )

	-- Uck.
	data.Pos = pos
	data.Angle = ang
	data.Model = model

	-- Make sure this is allowed
	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnProp", ply, model ) ) then return end

	local prop = ents.Create( "prop_physics" )
	if ( !IsValid( prop ) ) then return end -- Must've hit edict limit

	duplicator.DoGeneric( prop, data )
	prop:Spawn()

	duplicator.DoGenericPhysics( prop, ply, data )

	-- Tell the gamemode we just spawned something
	if ( IsValid( ply ) ) then
		gamemode.Call( "PlayerSpawnedProp", ply, model, prop )
	end

	DoPropSpawnedEffect( prop )

	return prop

end

duplicator.RegisterEntityClass( "prop_physics", MakeProp, "Pos", "Ang", "Model", "PhysicsObjects", "Data" )
duplicator.RegisterEntityClass( "prop_physics_multiplayer", MakeProp, "Pos", "Ang", "Model", "PhysicsObjects", "Data" )

local function MakeRagdoll( ply, _, _, model, _, data )

	if ( IsValid( ply ) && !gamemode.Call( "PlayerSpawnRagdoll", ply, model ) ) then return end

	local ent = ents.Create( "prop_ragdoll" )
	if ( !IsValid( ent ) ) then return end -- Must've hit edict limit

	duplicator.DoGeneric( ent, data )
	ent:Spawn()

	duplicator.DoGenericPhysics( ent, ply, data )

	ent:Activate()

	if ( IsValid( ply ) ) then
		gamemode.Call( "PlayerSpawnedRagdoll", ply, model, ent )
	end

	DoPropSpawnedEffect( ent )

	return ent

end

duplicator.RegisterEntityClass( "prop_ragdoll", MakeRagdoll, "Pos", "Ang", "Model", "PhysicsObjects", "Data" )

local function SaveFileName( name )

	name = string.Trim( tostring( name or "" ) )
	if ( name == "" ) then
		name = game.GetMap() .. " " .. util.DateStamp()
	end

	-- Keep it to something a filesystem and the menu list both like.
	name = string.gsub( name, "[^%w%-_ ]", "" )
	if ( name == "" ) then name = "untitled" end

	return name

end

local function CanUseSaveSystem( ply )

	if ( !IsValid( ply ) ) then return false end
	if ( game.SinglePlayer() ) then return true end

	return ply:IsAdmin() == true

end

concommand.Add( "gm_save", function( ply, cmd, args )

	if ( !CanUseSaveSystem( ply ) ) then return end

	if ( ply.m_NextSave && ply.m_NextSave > CurTime() && !game.SinglePlayer() ) then
		MsgN( tostring( ply ) .. " tried to save too quickly!" )
		return
	end

	ply.m_NextSave = CurTime() + 10

	MsgN( tostring( ply ) .. " requested a save." )

	local save = gmsave.SaveMap( ply )
	if ( !save ) then
		MsgN( "gm_save: couldn't serialise the map!" )
		return
	end

	local compressed_save = util.Compress( save )
	if ( !compressed_save ) then compressed_save = save end

	local name = SaveFileName( args and args[ 1 ] )
	local path = SAVE_DIR .. "/" .. name .. ".txt"

	file.Write( path, compressed_save )

	MsgN( "gm_save: wrote data/" .. path .. " (" .. string.len( compressed_save ) .. " bytes)" )

	hook.Run( "PostGameSaved" )

end, nil, "Save the map to data/hl2sb_saves/ (gm_save [name])." )

local function LoadGModSave( name )

	local path = SAVE_DIR .. "/" .. name .. ".txt"
	if ( !file.Exists( path, "DATA" ) ) then
		MsgN( "gm_load: no save named '" .. name .. "' (data/" .. path .. ")" )
		return
	end

	local compressed = file.Read( path, "DATA" )
	local savedata = util.Decompress( compressed )

	if ( !isstring( savedata ) ) then
		MsgN( "gm_load: couldn't decompress " .. path .. "!" )
		return
	end

	-- If we loaded the save before the player entity was ready (main-menu
	-- load path), wait for the player like GMod does.
	if ( game.SinglePlayer() && !IsValid( Entity( 1 ) ) ) then

		timer.Create( "LoadGModSave_WaitForPlayer", 0.1, 0, function()
			if ( !IsValid( Entity( 1 ) ) ) then return end

			timer.Remove( "LoadGModSave_WaitForPlayer" )
			LoadGModSave( name )
		end )

		return

	end

	local ply = nil
	if ( IsValid( Entity( 1 ) ) && game.SinglePlayer() ) then ply = Entity( 1 ) end
	if ( !IsValid( ply ) && #player.GetHumans() == 1 ) then ply = player.GetHumans()[ 1 ] end
	if ( game.IsDedicated() ) then ply = nil end -- For dedicated servers, we don't want it to latch to some random player

	gmsave.LoadMap( savedata, ply )

end

concommand.Add( "gm_load", function( ply, cmd, args )

	if ( !CanUseSaveSystem( ply ) ) then return end

	LoadGModSave( SaveFileName( args and args[ 1 ] ) )

end, nil, "Load a save from data/hl2sb_saves/ (gm_load [name])." )

-- Listing for the console / the menu page: names without the extension.
function gmsave.ListSaves()

	local out = {}

	local files = file.Find( SAVE_DIR .. "/*.txt", "DATA" )
	for _, name in ipairs( files or {} ) do
		out[ #out + 1 ] = string.gsub( name, "%.txt$", "" )
	end

	table.sort( out )

	return out

end
