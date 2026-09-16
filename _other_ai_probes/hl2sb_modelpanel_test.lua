--[[----------------------------------------------------------------------------
    hl2sb_modelpanel_test.lua

    Smoke test for the new vgui.ModelPanel binding (the Lua-side 3D preview that
    the GMod-style player model menu will be built on).

    Run from the console:
        lua_dofile_cl game/client/hl2sb_modelpanel_test.lua
        hl2sb_test_modelpanel

    Watch ds_debug.log for the [HL2SB] ModelPanel test lines.
----------------------------------------------------------------------------]]--

local bPanel = nil

concommand.Create( "hl2sb_test_modelpanel", function()
	print( "[HL2SB] ModelPanel test: start\n" )

	-- ---- hl2sb library (player model data) ----------------------------
	if ( not hl2sb ) then
		print( "[HL2SB] ModelPanel test: FAIL - hl2sb library missing\n" )
		return
	end
	local models = hl2sb.GetPlayerModels()
	print( string.format( "[HL2SB] ModelPanel test: hl2sb.GetPlayerModels() -> %d entries (count=%d)\n",
		#models, hl2sb.GetPlayerModelCount() ) )
	if ( #models > 0 ) then
		print( string.format( "[HL2SB] ModelPanel test: first = name='%s' model='%s' hands='%s'\n",
			tostring( models[1].name ), tostring( models[1].model ), tostring( models[1].hands ) ) )
	end
	print( string.format( "[HL2SB] ModelPanel test: FindPlayerModel('gmod_alyx') = %s\n",
		tostring( hl2sb.FindPlayerModel( "gmod_alyx" ) ~= nil ) ) )
	print( string.format( "[HL2SB] ModelPanel test: FindPlayerModel('nope') = %s (expect nil)\n",
		tostring( hl2sb.FindPlayerModel( "nope" ) ) ) )
	print( string.format( "[HL2SB] ModelPanel test: current model = '%s'\n",
		tostring( hl2sb.GetCurrentPlayerModel() ) ) )

	-- Which of the configured models can the client actually render?
	local nPrecached, pszSample = 0, nil
	for _, m in ipairs( models ) do
		if ( hl2sb.IsModelPrecached( m.model ) ) then
			nPrecached = nPrecached + 1
			if ( not pszSample ) then pszSample = m.model end
		end
	end
	print( string.format( "[HL2SB] ModelPanel test: precached on client = %d / %d\n", nPrecached, #models ) )
	print( string.format( "[HL2SB] ModelPanel test: first precached = '%s'\n", tostring( pszSample ) ) )
	print( string.format( "[HL2SB] ModelPanel test: current model precached = %s\n",
		tostring( hl2sb.IsModelPrecached( hl2sb.GetCurrentPlayerModel() ) ) ) )

	-- ---- vgui.ModelPanel ----------------------------------------------
	if ( not vgui or not vgui.ModelPanel ) then
		print( "[HL2SB] ModelPanel test: FAIL - vgui.ModelPanel is not registered\n" )
		return
	end
	print( "[HL2SB] ModelPanel test: vgui.ModelPanel exists\n" )

	-- IsValid/Remove are not bound on Panel, so track the frame ourselves and
	-- retire the old one with MarkForDeletion (which is bound).
	if ( bPanel ) then
		bPanel:MarkForDeletion()
		bPanel = nil
	end

	local sw, sh = surface.GetScreenSize()

	local frm = vgui.Frame( nil, "HL2SBModelPanelTest", false )
	frm:SetSize( 420, 520 )
	frm:SetPos( sw * 0.5 - 210, sh * 0.5 - 260 )
	-- Frame_SetTitle takes (title, surfaceTitle)
	frm:SetTitle( "ModelPanel test", true )
	frm:MakePopup()
	-- MakePopup() alone leaves the frame hidden, and a hidden panel never runs
	-- Paint(), so CModelPanel never creates its entity.
	frm:SetVisible( true )

	-- Report the frame's real geometry: if the Lua root panel is not parented /
	-- visible, this frame is a child of an invisible panel and never renders.
	local fx, fy = frm:GetPos()
	local fw, fh = frm:GetSize()
	print( string.format(
		"[HL2SB] ModelPanel test: frame visible=%s pos=%d,%d size=%dx%d screen=%dx%d parent=%s\n",
		tostring( frm:IsVisible() ), fx, fy, fw, fh, sw, sh, tostring( frm:GetParent() ) ) )
	print( string.format( "[HL2SB] ModelPanel test: frame alpha=%s paintbg=%s proportional=%s\n",
		tostring( frm:GetAlpha() ), tostring( frm:IsOpaque() ), tostring( frm:IsProportional() ) ) )

	local mdl = vgui.ModelPanel( frm, "Preview" )
	mdl:SetPos( 10, 34 )
	mdl:SetSize( 400, 476 )
	mdl:SetFOV( 54 )
	mdl:SetZoomLimits( 0.25, 4.0 )

	-- exercise the inherited Panel methods, to prove __index chains correctly
	print( string.format( "[HL2SB] ModelPanel test: panel=%s visible=%s size=%dx%d\n",
		tostring( mdl ), tostring( mdl:IsVisible() ), mdl:GetWide(), mdl:GetTall() ) )

	-- Prefer a model the client actually has, so the preview really renders.
	local pszTestModel = pszSample or "models/player/alyx.mdl"
	local ok = mdl:SetModel( pszTestModel )
	print( string.format( "[HL2SB] ModelPanel test: SetModel('%s')=%s model='%s' seqs=%d\n",
		pszTestModel, tostring( ok ), tostring( mdl:GetModel() ), mdl:GetSequenceCount() ) )

	-- print a few sequence names so we can confirm GetSequenceName works
	local names = {}
	local n = mdl:GetSequenceCount()
	for i = 0, math.min( n - 1, 5 ) do
		names[#names + 1] = tostring( mdl:GetSequenceName( i ) )
	end
	print( string.format( "[HL2SB] ModelPanel test: first seqs = %s\n", table.concat( names, ", " ) ) )

	-- play whatever "walk" resolves to, then check yaw/zoom round-trip
	local bPlayed = mdl:PlaySequence( "walk" )
	print( string.format( "[HL2SB] ModelPanel test: PlaySequence(walk)=%s\n", tostring( bPlayed ) ) )

	mdl:SetYaw( 90 )
	mdl:SetZoom( 1.5 )
	print( string.format( "[HL2SB] ModelPanel test: yaw=%.1f zoom=%.2f (expect 90 / 1.50)\n",
		mdl:GetYaw(), mdl:GetZoom() ) )

	-- a model that does not exist must fail cleanly, not crash
	local bad = mdl:SetModel( "models/player/does_not_exist.mdl" )
	print( string.format( "[HL2SB] ModelPanel test: SetModel(missing)=%s (expect false)\n", tostring( bad ) ) )

	mdl:SetModel( pszTestModel )
	mdl:RefitCamera()

	bPanel = frm

	-- CModelPanel creates its entity during the next UpdateModel(), so the
	-- sequence list is only populated a frame or two later.  Check again after
	-- a short delay rather than reporting 0 as a failure.
	local nFrames = 0
	hook.add( "HudViewportPaint", "hl2sb_modelpanel_test", function()
		nFrames = nFrames + 1
		if ( nFrames < 20 ) then return end

		hook.remove( "HudViewportPaint", "hl2sb_modelpanel_test" )

		local n = mdl:GetSequenceCount()
		print( string.format( "[HL2SB] ModelPanel test: after %d frames seqs=%d model='%s'\n",
			nFrames, n, tostring( mdl:GetModel() ) ) )

		if ( n > 0 ) then
			print( string.format( "[HL2SB] ModelPanel test: seq0='%s' seq1='%s'\n",
				tostring( mdl:GetSequenceName( 0 ) ), tostring( mdl:GetSequenceName( 1 ) ) ) )
			print( string.format( "[HL2SB] ModelPanel test: PlaySequence('walk')=%s\n",
				tostring( mdl:PlaySequence( "walk" ) ) ) )
		end

		local fx2, fy2 = frm:GetPos()
		local fw2, fh2 = frm:GetSize()
		print( string.format( "[HL2SB] ModelPanel test: frame still visible=%s pos=%d,%d size=%dx%d\n",
			tostring( frm:IsVisible() ), fx2, fy2, fw2, fh2 ) )

		-- The model reportedly vanishes after a while.  Poll every 2 seconds
		-- for 3 minutes, printing every sample so the timeline is visible.
		-- seqs staying constant rules out "the entity was deleted".
		--
		-- Something hides the frame (or its parent) about 40s in; a hidden
		-- panel is not painted, which is what makes the model look like it
		-- vanished.  Re-assert visibility so the diagnostic can run its course.
		local nTick = 0
		hook.add( "HudViewportPaint", "hl2sb_modelpanel_test_poll", function()
			nTick = nTick + 1

			if ( not frm:IsVisible() ) then
				frm:SetVisible( true )
				print( string.format( "[HL2SB] poll %ds: frame was hidden - re-shown\n",
					math.floor( nTick / 60 ) ) )
			end

			if ( nTick % 120 ~= 0 ) then return end

			print( string.format(
				"[HL2SB] poll %ds: seqs=%d model='%s' panelVis=%s frameVis=%s yaw=%.0f zoom=%.2f\n",
				math.floor( nTick / 60 ), mdl:GetSequenceCount(), tostring( mdl:GetModel() ),
				tostring( mdl:IsVisible() ), tostring( frm:IsVisible() ),
				mdl:GetYaw(), mdl:GetZoom() ) )

			if ( nTick >= 60 * 180 ) then
				hook.remove( "HudViewportPaint", "hl2sb_modelpanel_test_poll" )
				print( "[HL2SB] poll: finished after 180s\n" )
			end
		end )
	end )

	print( "[HL2SB] ModelPanel test: done - a window should be on screen\n" )
end, "Smoke test for vgui.ModelPanel" )

print( "[HL2SB] hl2sb_modelpanel_test.lua loaded - run 'hl2sb_test_modelpanel'\n" )
