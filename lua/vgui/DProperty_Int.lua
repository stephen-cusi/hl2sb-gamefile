--[[ DProperty_Int -- an integer property (GMod port).

	Wiki: https://wiki.facepunch.com/gmod/DProperty_Int
	  Parent: DProperty_Float.  GMod's whole file is the decimals override, so a
	  number row asked for as "Number" (or "Int") gets a slider with 0 decimals.

	Ported from GMod's lua/vgui/prop_int.lua (17 lines).
--]]

local PANEL = {}

function PANEL:Init()
end

function PANEL:GetDecimals()
	return 0
end

derma.DefineControl( "DProperty_Int", "An integer property", PANEL, "DProperty_Float" )
