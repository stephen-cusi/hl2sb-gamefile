--[[ DShape -- draw a shape on a panel (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DShape
	  "Draw a shape on a derma panel. Only one kind of shape, a rectangle, is
	   available for use."
	  Parent: DPanel.
	  Methods: GetBorderColor / GetColor / GetType / SetBorderColor / SetColor /
	           SetType( type )            -- "Rect" is the only type

	GMod implements the drawing with a RenderTypes dispatch table, so a new shape is a
	new function; that is kept, because addons poke RenderTypes.  The `VGUIRect( x, y,
	w, h )` convenience function at the bottom is part of GMod's file as well - a few
	of its own panels (and the property sheets) call it.

	⚠️ Two deliberate differences from GMod's copy:
	  * SetType defaults to "Rect", so a script that forgets SetType draws a rectangle
	    instead of dying in `RenderTypes[ nil ]` (GMod's own example always sets it).
	  * SetBorderColor stores the colour but does not draw (the wiki says "Currently
	    does nothing"), which is what GMod does too.
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_Color", "Color" )
AccessorFunc( PANEL, "m_BorderColor", "BorderColor" )
AccessorFunc( PANEL, "m_Type", "Type" )

--- one entry per shape type, called as RenderTypes[ type ]( pnl )
local RenderTypes = {}

RenderTypes.Rect = function( pnl )
	local col = pnl:GetColor() or color_white
	local w, h = pnl:GetSize()

	surface.DrawSetColor( col.r, col.g, col.b, col.a )
	surface.DrawFilledRect( 0, 0, w, h )
end

function PANEL:Init()
	self.m_Color = color_white
	self.m_BorderColor = Color( 0, 0, 0, 255 )
	self.m_Type = "Rect"

	-- a shape is drawn, never clicked
	self:SetMouseInputEnabled( false )
	self:SetKeyBoardInputEnabled( false )

	if ( self.SetDrawBackground ) then self:SetDrawBackground( false ) end
end

function PANEL:SetType( strType )
	self.m_Type = strType or "Rect"
end

function PANEL:GetType()
	return self.m_Type
end

function PANEL:Paint( w, h )
	local render = RenderTypes[ self.m_Type or "Rect" ]

	if ( render == nil ) then
		-- unknown type: say so once per panel instead of throwing every frame
		if ( not self.m_bBadTypeReported ) then
			self.m_bBadTypeReported = true
			Warning( "DShape: unknown type '" .. tostring( self.m_Type ) ..
				"' (only 'Rect' exists) - nothing drawn\n" )
		end

		return
	end

	render( self )
end

derma.DefineControl( "DShape", "A shape", PANEL, "DPanel" )

--- GMod's convenience function: a rectangle panel in one call.
function VGUIRect( x, y, w, h )
	local shape = vgui.Create( "DShape" )

	if ( not shape ) then return nil end

	shape:SetType( "Rect" )
	shape:SetPos( x, y )
	shape:SetSize( w, h )

	return shape
end
