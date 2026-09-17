--[[ DPanelOverlay -- an overlay that cuts curved corners into its parent (original).

	Wiki: https://wiki.facepunch.com/gmod/DPanelOverlay
	  "Adds curved corners."  Parent: DPanel.
	  Methods: GetColor / GetType / SetColor / SetType( type ) /
	           PaintInnerCorners( size ) / PaintDifferentColours( a, b, c, d, size )

	Types (GMod's own numbers, see its Paint):
	    1 - inner corners, 8 px        (the usual "panel inside a frame" look)
	    2 - inner corners, 4 px
	    3 - only the bottom two corners are the overlay colour, the top two are dark

	⚠️ The corners are a TEXTURE (GMod's `gui/icorner8`), and the corner colour lives
	in the draw colour, so the overlay can also be used to paint four different corner
	colours (PaintDifferentColours - DColorMixer uses that for its own frame).
	If that texture is not mounted (it is GMod content; this fork mounts GMod's VPKs
	as game+mod) the corners fall back to small filled squares, because an overlay that
	draws nothing at all would silently break every panel that relies on it.
--]]

local PANEL = {}

--- GMod: `surface.GetTextureID( "gui/icorner8" )` at file scope.  Guarded: a missing
--- texture must not take the whole control file down at include time.
local InnerCorner8 = nil

if ( surface.GetTextureID ) then
	local ok, id = pcall( surface.GetTextureID, "gui/icorner8" )

	if ( ok and type( id ) == "number" and id > 0 ) then
		InnerCorner8 = id
	end
end

function PANEL:Init()
	self.m_Color = color_white
	self.m_Type = 1

	self:SetMouseInputEnabled( false )
	self:SetKeyBoardInputEnabled( false )

	if ( self.SetDrawBackground ) then self:SetDrawBackground( false ) end
end

function PANEL:SetColor( col )
	self.m_Color = col or color_white
end

function PANEL:GetColor()
	return self.m_Color
end

function PANEL:SetType( n )
	self.m_Type = tonumber( n ) or 1
end

function PANEL:GetType()
	return self.m_Type
end

--- One corner: the rotated textured rect centred on ( cx, cy ), or - when the corner
--- texture is missing - a plain square of the same size.
local function DrawCorner( size, cx, cy, rot )
	if ( InnerCorner8 ) then
		surface.DrawSetTexture( InnerCorner8 )
		surface.DrawTexturedRectRotated( cx, cy, size, size, rot )
		return
	end

	surface.DrawFilledRect( math.floor( cx - size / 2 ), math.floor( cy - size / 2 ),
		math.floor( cx + size / 2 ), math.floor( cy + size / 2 ) )
end

--- Wiki: "Used internally by the panel for types 1 and 2."
function PANEL:PaintInnerCorners( size )
	local w, h = self:GetSize()

	DrawCorner( size, size * 0.5, size * 0.5, 0 )
	DrawCorner( size, w - size * 0.5, size * 0.5, -90 )
	DrawCorner( size, w - size * 0.5, h - size * 0.5, 180 )
	DrawCorner( size, size * 0.5, h - size * 0.5, 90 )
end

--- Wiki: "Used internally by the panel for type 3."
function PANEL:PaintDifferentColours( cola, colb, colc, cold, size )
	local w, h = self:GetSize()

	cola = cola or color_white
	colb = colb or color_white
	colc = colc or color_white
	cold = cold or color_white

	surface.DrawSetColor( cola.r or cola[ 1 ], cola.g or cola[ 2 ], cola.b or cola[ 3 ], cola.a or cola[ 4 ] )
	DrawCorner( size, size * 0.5, size * 0.5, 0 )

	surface.DrawSetColor( colb.r or colb[ 1 ], colb.g or colb[ 2 ], colb.b or colb[ 3 ], colb.a or colb[ 4 ] )
	DrawCorner( size, w - size * 0.5, size * 0.5, -90 )

	surface.DrawSetColor( colc.r or colc[ 1 ], colc.g or colc[ 2 ], colc.b or colc[ 3 ], colc.a or colc[ 4 ] )
	DrawCorner( size, w - size * 0.5, h - size * 0.5, 180 )

	surface.DrawSetColor( cold.r or cold[ 1 ], cold.g or cold[ 2 ], cold.b or cold[ 3 ], cold.a or cold[ 4 ] )
	DrawCorner( size, size * 0.5, h - size * 0.5, 90 )
end

function PANEL:Paint( w, h )
	-- GMod stretches the overlay over its parent on every paint (the overlay is
	-- expected to be the last child of the panel it decorates).
	local parent = self:GetParent()

	if ( IsValid( parent ) ) then
		local pw, ph = parent:GetSize()

		if ( self:GetWide() ~= pw or self:GetTall() ~= ph ) then
			self:SetPos( 0, 0 )
			self:SetSize( pw, ph )
		end
	end

	local col = self.m_Color or color_white

	surface.DrawSetColor( col.r or 255, col.g or 255, col.b or 255, col.a or 255 )

	if ( self.m_Type == 1 ) then return self:PaintInnerCorners( 8 ) end
	if ( self.m_Type == 2 ) then return self:PaintInnerCorners( 4 ) end

	if ( self.m_Type == 3 ) then
		local c = Color( 40, 40, 40, 255 )
		return self:PaintDifferentColours( c, c, self.m_Color, self.m_Color, 8 )
	end

	return false
end

derma.DefineControl( "DPanelOverlay", "Adds curved corners to its parent", PANEL, "DPanel" )
