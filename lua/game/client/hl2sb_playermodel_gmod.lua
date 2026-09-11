--[[----------------------------------------------------------------------------
    hl2sb_playermodel_gmod.lua

    GMod-style player model selection panel.

    This is the Derma replacement for the old hand-rolled
    lua/game/client/hl2sb_playermodel.lua (and for the C++ spawn menu's model
    page).  It is written the way GMod writes panels -- a DFrame, a DListView and
    a ModelPanel built from lua/derma and lua/vgui, the files copied verbatim from
    GMod -- so the look comes from the real Derma skin rather than from hand-drawn
    rectangles.

    That only became possible today: until the docking port, the default skin,
    Material:GetColor, Label:SetFont and the rest were fixed, Derma panels could
    not be created or painted at all.

    Data comes from the engine's own model config (cfg/playermodel), which the
    C++ exposes directly:

        hl2sb.GetPlayerModels()        -> { { name=, model=, hands=, file= }, ... }
        hl2sb.GetCurrentPlayerModel()  -> name
        hl2sb.SetPlayerModel( name )
        hl2sb.IsModelPrecached( model )

    GMod's own flow is editor_player.lua in the sandbox gamemode, but it lives
    inside the spawnmenu UI (PanelSelect + icons + spawnmenu.CreateContentIcon),
    none of which exists here yet -- so this is a standalone panel with GMod's
    look, not a copy of that file.

    Console command:  hl2sb_playermodel_gmod
----------------------------------------------------------------------------]]--

local function Dbg( ... )
	if ( GetConVarNumber( "hl2sb_hud_debug" ) == 0 ) then return end

	local out = {}
	for i = 1, select( "#", ... ) do out[ i ] = tostring( ( select( i, ... ) ) ) end

	Msg( "[HL2SB playermodel] " .. table.concat( out, " " ) .. "\n" )
end

-- ---------------------------------------------------------------------------
-- Model list
-- ---------------------------------------------------------------------------
local function GetModels()
	local list = {}

	if ( hl2sb == nil or hl2sb.GetPlayerModels == nil ) then
		Dbg( "hl2sb.GetPlayerModels() is missing" )
		return list
	end

	local ok, models = pcall( hl2sb.GetPlayerModels )
	if ( not ok or type( models ) ~= "table" ) then
		Dbg( "GetPlayerModels failed:", tostring( models ) )
		return list
	end

	for _, entry in ipairs( models ) do
		if ( type( entry ) == "table" and entry.name and entry.model ) then
			list[ #list + 1 ] = entry
		end
	end

	return list
end

local function CurrentModelName()
	if ( hl2sb == nil or hl2sb.GetCurrentPlayerModel == nil ) then return nil end
	return hl2sb.GetCurrentPlayerModel()
end

local function Apply( entry )
	Dbg( "applying", tostring( entry.name ), tostring( entry.model ) )

	-- The engine keeps the authoritative list; this is what the server reads
	-- back out of cl_playermodel when the player spawns.
	if ( hl2sb ~= nil and hl2sb.SetPlayerModel ~= nil ) then
		local ok, err = pcall( hl2sb.SetPlayerModel, entry.name )
		if ( not ok ) then Dbg( "SetPlayerModel failed:", tostring( err ) ) end
	end

	RunConsoleCommand( "cl_playermodel", entry.name )

	-- Immediate local feedback, so the choice is visible without respawning.
	local ply = LocalPlayer()
	if ( IsValid( ply ) ) then
		local ok, err = pcall( function() ply:SetModel( entry.model ) end )
		if ( not ok ) then Dbg( "SetModel failed:", tostring( err ) ) end
	end

	return true
end

-- ---------------------------------------------------------------------------
-- The panel
-- ---------------------------------------------------------------------------
local function OpenPanel()
	if ( vgui == nil or vgui.Create == nil ) then
		Msg( "[HL2SB playermodel] vgui.Create is not available\n" )
		return
	end

	local models = GetModels()
	if ( #models == 0 ) then
		Msg( "[HL2SB playermodel] no player models in cfg/playermodel\n" )
		return
	end

	local current = CurrentModelName()

	local frame = vgui.Create( "DFrame" )
	frame:SetSize( 700, 480 )
	frame:SetPos( ( ScrW() - 700 ) / 2, ( ScrH() - 480 ) / 2 )
	frame:SetTitle( "Player Model" )
	frame:MakePopup()

	local list = vgui.Create( "DListView", frame )
	list:Dock( LEFT )
	list:SetWidth( 260 )
	list:AddColumn( "Model" )

	local preview = vgui.Create( "ModelPanel", frame )
	if ( preview ~= nil ) then
		preview:Dock( FILL )
	end

	local apply = vgui.Create( "DButton", frame )
	apply:SetText( "Apply" )
	apply:SetTall( 28 )
	apply:Dock( BOTTOM )
	apply:SetEnabled( false )

	local selected

	local function SelectEntry( entry )
		selected = entry

		if ( preview ~= nil and preview.SetModel ~= nil ) then
			local ok, err = pcall( function() preview:SetModel( entry.model ) end )
			if ( not ok ) then Dbg( "preview SetModel failed:", tostring( err ) ) end
		end

		if ( hl2sb ~= nil and hl2sb.IsModelPrecached ~= nil ) then
			local ok, precached = pcall( hl2sb.IsModelPrecached, entry.model )
			if ( ok and precached == false ) then
				Dbg( "model not precached:" .. tostring( entry.model ) )
			end
		end

		apply:SetEnabled( true )
	end

	local rowToEntry = {}

	for i, entry in ipairs( models ) do
		local line = list:AddLine( entry.name )
		line.PlayerModel = entry
		rowToEntry[ line ] = entry
	end

	list.OnRowSelected = function( _, rowIndex )
		local line = list:GetLine( rowIndex )
		if ( line ~= nil ) then
			SelectEntry( line.PlayerModel )
		end
	end

	-- Preselect whatever the engine currently reports.
	if ( current ) then
		for rowIndex, line in ipairs( list:GetLines() ) do
			if ( line.PlayerModel ~= nil and line.PlayerModel.name == current ) then
				list:SelectItem( line )
				SelectEntry( line.PlayerModel )
				break
			end
		end
	end

	apply.DoClick = function()
		if ( selected ~= nil ) then
			Apply( selected )
		end
	end

	frame.OnClose = function()
		-- Nothing to clean up; the row table dies with the frame.
		rowToEntry = nil
	end

	return frame
end

concommand.Create( "hl2sb_playermodel_gmod", function()
	OpenPanel()
end, "Open the GMod-style player model panel" )

print( "[HL2SB] hl2sb_playermodel_gmod.lua loaded - run 'hl2sb_playermodel_gmod'" )
