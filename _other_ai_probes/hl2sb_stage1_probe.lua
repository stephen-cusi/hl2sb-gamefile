-- Stage-1 engine patch probe (TextEntry / CheckButton Lua bindings).
-- Runs from lua/autorun/client on map load. Delete after verification.

local function Log( fmt, ... )
	print( "[STAGE1] " .. string.format( fmt, ... ) )
end

local ok, err = pcall( function()
	-- 1. TextEntry: existing bindings roundtrip
	local te = vgui.TextEntry()
	te.OnTextChanged = function( pnl )
		Log( "OnTextChanged fired, value=%q", pnl:GetValue() )
	end
	te.OnEnter = function( pnl )
		Log( "OnEnter fired, value=%q", pnl:GetValue() )
	end

	te:SetText( "hello" )
	Log( "SetText/GetText = %q", te:GetText() )

	te:SetValue( "42" )
	Log( "SetValue/GetValue = %q (float %s int %s)", te:GetValue(), tostring( te:GetValueAsFloat() ), tostring( te:GetValueAsInteger() ) )

	te:SetReadOnly( true )
	Log( "SetReadOnly -> IsEditable = %s", tostring( te:IsEditable() ) )
	te:SetReadOnly( false )

	-- this must trigger the FireActionSignal override
	te:InsertString( "!" )

	te:SetMultiline( true )
	Log( "SetMultiline -> IsMultiline = %s", tostring( te:IsMultiline() ) )

	-- 2. CheckButton: GMod names + SetSelected dispatch
	local cb = vgui.CheckButton( nil, "probe_cb", "probe" )
	cb.OnCheckButtonChecked = function( pnl, bChecked )
		Log( "OnCheckButtonChecked fired, checked=%s", tostring( bChecked ) )
	end
	cb:SetChecked( true )
	Log( "GetChecked = %s", tostring( cb:GetChecked() ) )
	cb:SetChecked( false )
	Log( "GetChecked = %s", tostring( cb:GetChecked() ) )

	-- 3. Panel additions
	Log( "Panel has Dock = %s, MoveToBack = %s",
		type( te.Dock ), type( te.MoveToBack ) )

	te:MarkForDeletion()
	cb:MarkForDeletion()
	Log( "PROBE DONE" )
end )

if not ok then
	Log( "PROBE ERROR: %s", tostring( err ) )
end
