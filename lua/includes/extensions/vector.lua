
local meta = FindMetaTable( "Vector" )

--[[---------------------------------------------------------
	Converts Vector To Color - alpha precision lost, must reset
-----------------------------------------------------------]]
function meta:ToColor()

	local x, y, z = meta.Unpack( self )
	return Color( x * 255, y * 255, z * 255 )

end

--[[---------------------------------------------------------
	Converts Vector To Table - GMod returns { x, y, z }.  The ported
	DColorCube's copy menu concatenates it ("r g b" out of its color vector).
-----------------------------------------------------------]]
function meta:ToTable()

	return { self.x, self.y, self.z }

end
