local panel = vgui.GetControlTable( "DProperty_VectorColor" )
if ( !panel || panel.__hl2sb_enabled_fix ) then return end

local oldSetup = panel.Setup
if ( !isfunction( oldSetup ) ) then return end

panel.Setup = function( self, vars )
	oldSetup( self, vars )

	local setEnabled = self.SetEnabled
	if ( !isfunction( setEnabled ) || !debug || !debug.getupvalue ) then return end

	local button
	local genericSetEnabled
	for i = 1, 4 do
		local name, value = debug.getupvalue( setEnabled, i )
		if ( !name ) then break end
		if ( name == "btn" ) then button = value end
		if ( name == "oldSetEnabled" ) then genericSetEnabled = value end
	end

	if ( !IsValid( button ) || !isfunction( genericSetEnabled ) ) then return end

	local textEntry
	for i = 1, 4 do
		local name, value = debug.getupvalue( genericSetEnabled, i )
		if ( !name ) then break end
		if ( name == "text" ) then textEntry = value end
	end

	if ( !IsValid( textEntry ) ) then return end

	self.SetEnabled = function( slf, enabled )
		button:SetEnabled( enabled )
		textEntry:SetEnabled( enabled )
	end
end

panel.__hl2sb_enabled_fix = true
