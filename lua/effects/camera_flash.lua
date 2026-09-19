
--[[--------------------------------------------------------------------
    camera_flash  --  the gmod_camera shutter flash.

    GMod shows this at the point a photograph was taken (the camera SWEP's
    DoShootEffect traces 256 units ahead and fires the effect there, true =
    broadcast so everyone sees the flash).  A white additive flare that
    pops in, expands and fades over a fraction of a second.
----------------------------------------------------------------------]]

local MatFlash = Material( "sprites/glow04_noz" )

function EFFECT:Init( data )

	self.Position = data:GetOrigin()
	self.LifeTime = 0.3
	self.DieTime = CurTime() + self.LifeTime

	local r = 220
	self:SetRenderBoundsWS( self.Position - Vector( r, r, r ), self.Position + Vector( r, r, r ) )

end

function EFFECT:Think()

	return CurTime() < self.DieTime

end

function EFFECT:Render()

	-- 0 at birth (tight and bright) -> 1 near death (huge and transparent)
	local frac = 1 - ( self.DieTime - CurTime() ) / self.LifeTime

	local size = 24 + frac * 180
	local alpha = 255 * ( 1 - frac ) ^ 1.5

	render.SetMaterial( MatFlash )
	render.DrawSprite( self.Position, size, size, Color( 255, 255, 255, alpha ) )

end
