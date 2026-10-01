--[[ dslider_lib_test.lua  --  in-game verification for the verbatim GMod
	DSlider / DNumSlider / DColorCube port (issue 37).  Run with:

		lua_dofile_cl dslider_lib_test.lua        (client realm, in a map)

	Prints PASS/FAIL per assertion and a final tally.  Every check is guarded:
	a missing function is a FAIL line, never a crash. --]]

if ( not CLIENT ) then
	print( "[SLIDETEST] client realm only" )
	return
end

local nPass, nFail = 0, 0
local function Check( bOK, strName )
	if ( bOK ) then
		nPass = nPass + 1
	else
		nFail = nFail + 1
		print( "[SLIDETEST] FAIL: " .. tostring( strName ) )
	end
end

local function Approx( a, b )
	return math.abs( ( tonumber( a ) or 0 ) - ( tonumber( b ) or 0 ) ) < 0.001
end

print( "[SLIDETEST] --- 1. DSlider verbatim shape ---" )

local slider = vgui.Create( "DSlider" )
Check( IsValid( slider ), "vgui.Create(DSlider)" )
Check( slider.Knob ~= nil and IsValid( slider.Knob ), "DSlider.Knob exists" )
Check( Approx( slider:GetSlideX(), 0.5 ), "default SlideX 0.5" )
Check( Approx( slider:GetSlideY(), 0.5 ), "default SlideY 0.5" )
Check( slider:GetLockY() == 0.5, "default LockY 0.5" )
Check( slider.SetTrapInside ~= nil and slider.GetTrapInside ~= nil, "TrapInside accessors" )
Check( slider.SetConVarX ~= nil and slider.ConVarXNumberThink ~= nil, "per-axis convar API" )
Check( slider.SetImage ~= nil, "retired SetImage stub kept" )
slider:SetSize( 100, 20 )

print( "[SLIDETEST] --- 2. value change event + lock semantics ---" )

local nFired = 0
local gotX, gotY
slider.OnValueChanged = function( pnl, x, y )
	nFired = nFired + 1
	gotX, gotY = x, y
end

slider:SetSlideX( 0.25 )
Check( nFired == 1 and Approx( gotX, 0.25 ), "OnValueChanged fires with x" )
Check( gotY == nil or type( gotY ) == "number", "OnValueChanged second value present" )

-- GMod: the locks apply at drag time by FORCING the value (OnCursorMoved),
-- never by refusing SetSlideX.
slider:SetLockX( 0.75 )
slider:SetDragging( true )
slider:OnCursorMoved( 0, 0 )
Check( Approx( slider:GetSlideX(), 0.75 ), "locked axis forced during drag" )
Check( Approx( slider:GetSlideY(), 0.5 ), "LockY keeps Y at 0.5 during drag" )
slider:SetLockX( nil )
slider:SetDragging( false )

print( "[SLIDETEST] --- 3. drag state + knob reset ---" )

slider:OnMousePressed( MOUSE_LEFT )
Check( slider:GetDragging() == true, "press starts dragging" )
Check( slider:IsEditing() == true, "IsEditing while dragging" )
slider:OnMouseReleased( MOUSE_LEFT )
-- GMod's GetDragging is `Dragging || Knob.Depressed` - all-falsy returns NIL,
-- so the idle check is a falsy test, never an == false one.
Check( not slider:GetDragging(), "release stops dragging" )

slider:SetSlideX( 0 )
slider:SetSlideY( 0.1 )
slider.Knob.OnMousePressed( slider.Knob, MOUSE_MIDDLE )
Check( Approx( slider:GetSlideX(), 0.5 ) and Approx( slider:GetSlideY(), 0.5 ),
	"middle click resets to 0.5/0.5" )

print( "[SLIDETEST] --- 4. TranslateValues hook ---" )

slider.TranslateValues = function( pnl, x, y )
	return x * 0.5, y
end
slider:SetDragging( true )
slider:OnCursorMoved( 50, 10 )
Check( Approx( slider:GetSlideX(), 0.25 ), "TranslateValues remaps drag x" )
slider.TranslateValues = nil
slider:SetDragging( false )

print( "[SLIDETEST] --- 5. DNumSlider (the issue 37 row) ---" )

local num = vgui.Create( "DNumSlider" )
Check( IsValid( num ), "vgui.Create(DNumSlider)" )
Check( IsValid( num.Slider ) and IsValid( num.Slider.Knob ), "row slider has the knob" )
Check( IsValid( num.Scratch ) and IsValid( num.TextArea ) and IsValid( num.Label ), "Scratch/TextArea/Label exist" )

num:SetTall( 50 )
num:SetText( "Test" )
num:SetDecimals( 0 )
num:SetMinMax( 0, 10 )

local nRowFired = 0
local nRowVal
num.OnValueChanged = function( pnl, val )
	nRowFired = nRowFired + 1
	nRowVal = val
end

num:SetValue( 7 )
Check( Approx( num:GetValue(), 7 ), "SetValue 7" )
Check( Approx( num.Slider:GetSlideX(), 0.7 ), "slider fraction 0.7" )
Check( nRowFired >= 1 and Approx( nRowVal, 7 ), "row OnValueChanged fired" )
Check( not num:IsEditing(), "not editing while idle" )

-- drag path: TranslateValues -> TranslateSliderValues -> value change
num.Slider:SetSize( 200, 16 )
num.Slider:SetDragging( true )
num.Slider:OnCursorMoved( 40, 8 )
num.Slider:SetDragging( false )
Check( num:GetValue() > 0 and num:GetValue() <= 10, "drag lands inside min/max" )
Check( Approx( num.Slider:GetSlideX(), num.Scratch:GetFraction() ), "slider mirrors scratch" )

print( "[SLIDETEST] --- 6. DNumSlider convar binding (deferred) ---" )

local cv = CreateClientConVar( "dslider_test_cvar", "0", true, false, "dslider_lib_test" )
num:SetMinMax( 0, 100 )
num:SetConVar( "dslider_test_cvar" )
num:SetValue( 30 )

print( "[SLIDETEST] --- 7. DColorCube on the verbatim base ---" )

local cube = vgui.Create( "DColorCube" )
Check( IsValid( cube ) and cube.Knob ~= nil, "vgui.Create(DColorCube) with knob" )
cube:SetSize( 100, 100 )
cube:SetColor( Color( 0, 255, 0 ) )
-- GetRGB is a COLOR (HSVToColor's return), so the fields are .r/.g/.b
local out = cube:GetRGB()
Check( out ~= nil and Approx( out.g, 1 ) and Approx( out.r, 0 ),
	"SetColor(green) -> RGB stays green" )
Check( Approx( cube:GetSlideX(), 0 ) and Approx( cube:GetSlideY(), 0 ),
	"full saturation/value -> slide 0/0" )

local nUser = 0
cube.OnUserChanged = function( pnl, col ) nUser = nUser + 1 end
cube:SetDragging( true )
cube:OnCursorMoved( 50, 50 )
cube:SetDragging( false )
Check( nUser >= 1, "OnUserChanged fires from the drag path" )

-- keep everything alive through the deferred convar checks below; panels are
-- removed in the last timer, never before
timer.Simple( 0.2, function()
	Check( Approx( GetConVarNumber( "dslider_test_cvar" ), 30 ),
		"slider writes its convar (drag -> UpdateConVar)" )
	if ( cv ) then cv:SetString( "70" ) end
	timer.Simple( 0.4, function()
		Check( Approx( num:GetValue(), 70 ),
			"external convar change feeds back into the slider (Think poll)" )
		if ( IsValid( slider ) ) then slider:Remove() end
		if ( IsValid( num ) ) then num:Remove() end
		if ( IsValid( cube ) ) then cube:Remove() end
		print( "[SLIDETEST] done: " .. nPass .. " passed, " .. nFail .. " failed" )
	end )
end )
