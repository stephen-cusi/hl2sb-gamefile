--========= Copyleft 2010-2013, Team Sandbox, Some rights reserved. ===========--
--
-- Purpose: Saves dialog -- gm_save / gm_load from the GameUI menu.
--
-- HL2SB (2026-10-05): lists data/hl2sb_saves/*.txt (the gm_save output) and
-- drives the server-side save system through HL2SB_MenuConsoleCommand (the
-- menu realm has no engine library of its own; the bridge sanitizes the line
-- and hands it to the engine console, where the server Lua concommands live).
-- Delete is a plain data/ file delete done right here.  The serialisation
-- itself runs in gamemodes/deathmatch/gamemode/save_load.lua.
--
-- Control pattern follows addonsdialog.lua's PLAIN UI exactly: absolute
-- bounds recorded into a Layout table, then the closing sequence that makes
-- a menu-state frame actually appear - SetVisible + MoveToFront + Activate,
-- a position re-assert through the recorded bounds, HL2SB_MenuLayout() and
-- InvalidateLayout( true ) now and once more on the next frame, and a final
-- SetSize.  The first cut of this dialog skipped exactly that part: the
-- frame was created (the panel-gc log shows the instances) but never became
-- visible or clickable, which is the "点了没反应" report.
--===========================================================================--

include( "includes/extensions/table.lua" )
include( "includes/extensions/vgui.lua" )

local vgui = vgui

local M = 10
local DIALOG_W = 480

local COL_TEXT = Color( 200, 200, 200, 255 )
local COL_DIM  = Color( 140, 140, 140, 255 )

local m_Frame = nil

local function Say( s )
	Msg( "[HL2SB] " .. tostring( s ) .. "\n" )
end

local function ListSaves()
	local out = {}

	if ( file == nil or file.Find == nil ) then return out end

	for _, name in ipairs( file.Find( "hl2sb_saves/*.txt", "DATA" ) or {} ) do
		out[ #out + 1 ] = string.gsub( name, "%.txt$", "" )
	end

	table.sort( out )
	return out
end

local function OpenPlain()
	local parent = VGui_GetGameUIPanel and VGui_GetGameUIPanel() or nil
	if ( not parent ) then
		Say( "savesdialog: no GameUI root panel" )
		return nil
	end

	local frame = vgui.Frame( parent, "HL2SBSavesDialog", true )
	if ( not frame ) then return nil end

	m_Frame = frame

	frame:SetTitle( "存档" )
	frame:SetSize( DIALOG_W, 480 )

	local names = ListSaves()
	local Layout = {}

	local y = 30 + M

	local function NewLabel( x, yy, w, h, text, clr )
		local lbl = vgui.Create( "Label", frame )
		if ( lbl == nil ) then return nil end
		lbl:SetBounds( x, yy, w, h )
		lbl:SetText( text or "" )
		if ( lbl.SetFgColor ~= nil ) then
			lbl:SetFgColor( clr or COL_TEXT )
		end
		Layout[ #Layout + 1 ] = { lbl, x, yy, w, h }
		return lbl
	end

	local function NewButton( text, x, yy, w, h, cmd )
		if ( not vgui.Button ) then return nil end
		local btn = vgui.Button( frame, "saves_" .. cmd, text, frame, cmd )
		if ( btn == nil ) then return nil end
		btn:SetBounds( x, yy, w, h )
		Layout[ #Layout + 1 ] = { btn, x, yy, w, h }
		return btn
	end

	if ( #names == 0 ) then
		NewLabel( M, y, DIALOG_W - 2 * M, 20, "还没有存档。下方输入名字（留空 = 地图名+日期）后点保存。", COL_DIM )
		y = y + 26
	else
		for i, name in ipairs( names ) do
			if ( i > 12 ) then
				NewLabel( M, y, DIALOG_W - 2 * M, 18, "... 还有 " .. ( #names - 12 ) .. " 个（控制台 gm_load <名字>）", COL_DIM )
				y = y + 20
				break
			end

			NewLabel( M, y + 3, DIALOG_W - 2 * M - 170, 20, name, COL_TEXT )
			NewButton( "读取", DIALOG_W - M - 160, y, 75, 22, "load_" .. i )
			NewButton( "删除", DIALOG_W - M - 80, y, 75, 22, "del_" .. i )
			y = y + 28
		end
	end

	y = y + M

	-- save-name entry + the save button
	local entry = nil
	if ( vgui.TextEntry ) then
		entry = vgui.TextEntry( frame, "savesNameEntry" )
		if ( entry ~= nil ) then
			entry:SetBounds( M, y, DIALOG_W - 2 * M - 150, 24 )
			entry:SetText( "" )
			Layout[ #Layout + 1 ] = { entry, M, y, DIALOG_W - 2 * M - 150, 24 }
		end
	end
	NewButton( "保存当前地图", DIALOG_W - M - 140, y, 140, 24, "save" )
	y = y + 32

	NewLabel( M, y, DIALOG_W - 2 * M, 18, "单人直接可用；多人需要管理员。读取/保存由服务端执行，刷新后可见。", COL_DIM )
	y = y + 22

	NewButton( "刷新", M, y, 100, 26, "refresh" )
	NewButton( "关闭", DIALOG_W - M - 100, y, 100, 26, "Close" )
	y = y + 26 + M

	-- ---- the frame itself (addonsdialog.lua closing sequence) ---------------
	frame:SetSize( DIALOG_W, y )
	frame:MoveToCenterOfScreen()

	if ( frame.SetSizeable ) then frame:SetSizeable( false ) end

	frame.OnCommand = function( self, cmd )
		-- the scripted dispatcher may pass the command as arg 1 or 2
		if ( type( self ) == "string" ) then cmd = self end
		if ( not cmd ) then return end

		-- HL2SB probe (2026-10-05): the first cut of this dialog produced ZERO
		-- log lines on a save click - either this dispatcher never ran or the
		-- bridge global was nil and the old branch was guarded silent.  Log the
		-- click itself unconditionally so the next session pins the hop.
		Say( "savesdialog: OnCommand '" .. tostring( cmd ) .. "' bridge=" .. tostring( HL2SB_MenuConsoleCommand ~= nil ) )

		local function Reopen()
			if ( m_Frame and m_Frame.Close ) then m_Frame:Close() end
			m_Frame = nil
			OpenSavesDialog()
		end

		if ( cmd == "Close" ) then
			frame:Close()
			m_Frame = nil
		elseif ( cmd == "refresh" ) then
			Reopen()
		elseif ( cmd == "save" ) then
			-- probe 2: can THIS state write into the saves folder at all
			if ( file ~= nil and file.Write ~= nil ) then
				file.Write( "hl2sb_saves/_menu_probe.txt", "clicked" )
			end

			local typed = ( entry ~= nil and entry.GetValue ~= nil ) and entry:GetValue() or ""
			if ( HL2SB_MenuConsoleCommand ~= nil ) then
				if ( typed ~= nil and typed ~= "" ) then
					HL2SB_MenuConsoleCommand( "gm_save " .. typed )
				else
					HL2SB_MenuConsoleCommand( "gm_save" )
				end
				Say( "savesdialog: sent gm_save" )
			end
		elseif ( cmd:sub( 1, 5 ) == "load_" ) then
			local i = tonumber( cmd:sub( 6 ) )
			local name = i and names[ i ] or nil
			if ( name ~= nil and HL2SB_MenuConsoleCommand ~= nil ) then
				HL2SB_MenuConsoleCommand( "gm_load " .. name )
				Say( "savesdialog: sent gm_load " .. name )
			end
		elseif ( cmd:sub( 1, 4 ) == "del_" ) then
			local i = tonumber( cmd:sub( 5 ) )
			local name = i and names[ i ] or nil
			if ( name ~= nil and file.Delete ~= nil ) then
				file.Delete( "hl2sb_saves/" .. name .. ".txt", "DATA" )
				Reopen()
			end
		end
	end

	if ( frame.SetVisible ) then frame:SetVisible( true ) end
	if ( frame.MoveToFront ) then frame:MoveToFront() end
	frame:Activate()

	-- ---- run the layout pass NOW -------------------------------------------
	-- vgui2 applies child geometry in a layout pass, and nothing drives that
	-- pass for a menu-state frame on its own.  InvalidateLayout( true )
	-- performs the pass IMMEDIATELY; HL2SB_MenuLayout() additionally re-applies
	-- each panel's recorded geometry through the native setters.
	local function ReassertPositions()
		for i = 1, #Layout do
			local e = Layout[ i ]
			if ( e[ 1 ] ~= nil and e[ 1 ].SetBounds ~= nil ) then
				e[ 1 ]:SetBounds( e[ 2 ], e[ 3 ], e[ 4 ], e[ 5 ] )
			end
		end

		if ( HL2SB_MenuLayout ) then
			HL2SB_MenuLayout( frame )
		end

		if ( frame.InvalidateLayout ) then frame:InvalidateLayout( true ) end
	end

	ReassertPositions()

	-- ...and once more on the next frame: by then the frame is actually up,
	-- which is when the first pass normally happens.
	if ( timer and timer.Simple ) then
		timer.Simple( 0, function()
			if ( frame == nil or frame.SetBounds == nil ) then return end
			ReassertPositions()
		end )
	end

	-- Last word on the size: activating runs the scheme/layout pass, and the
	-- window must not end up smaller than what everything above was laid out
	-- for.
	frame:SetSize( DIALOG_W, y )

	return frame
end

local function Open()
	local ok, frame = pcall( OpenPlain )
	if ( not ok ) then
		Say( "savesdialog: open failed: " .. tostring( frame ) )
		return nil
	end
	return frame
end

function OpenSavesDialog()
	if ( m_Frame and m_Frame.Close ) then m_Frame:Close() end
	m_Frame = nil
	return Open()
end

concommand.Create( "OpenSavesDialog", function()
	OpenSavesDialog()
end, "Open the HL2SB saves dialog.", FCVAR_CLIENTDLL )

Say( "savesdialog loaded" )
