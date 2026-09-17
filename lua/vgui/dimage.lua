--[[ DImage -- an image/thumbnail panel (original implementation).

	GMod's DImage draws an IMaterial.  This fork has no Lua IMaterial objects, so the
	image is a texture id, created once per NAME and shared (surface.CreateNewTextureID
	+ DrawSetTextureFile - the same path lua/vgui/DImageButton.lua uses).  What GMod's
	control actually promises is kept: the image can be fitted to the panel or drawn at
	its own size, SetKeepAspect decides whether the aspect ratio survives that, colour
	can tint it, and a backup image is used when the first one is missing.

	Wiki contract: https://wiki.facepunch.com/gmod/DImage

	Used by the spawnmenu grid, where the cheapest thing to build per cell is an image
	that does not need its own texture id (hundreds of cells, a handful of images).
--]]

local PANEL = {}

-- one texture id per material NAME, shared by every DImage that wants it
local TexIds = {}

local function TextureID( path )
	local id = TexIds[ path ]

	if ( id == nil ) then
		if ( surface.CreateNewTextureID ) then
			id = surface.CreateNewTextureID()
			surface.DrawSetTextureFile( id, path, 1, true )
		else
			id = false
		end

		TexIds[ path ] = id
	end

	return id or nil
end

function PANEL:Init()
	-- An image is decoration, not a hit target: GMod's DImage does the same
	-- (_legacy_gmod/vgui/dimage.lua:13-14).  DPanel no longer disables mouse input for
	-- its children (see the note in lua/vgui/DPanel.lua), so this has to be explicit.
	self:SetMouseInputEnabled( false )
	self:SetKeyBoardInputEnabled( false )
	self:SetDrawBackground( false )

	self.m_strImage = ""
	self.m_strMatName = ""
	self.m_strFailsafe = ""
	self.m_colImage = Color( 255, 255, 255, 255 )
	self.m_bKeepAspect = true
	self.m_iTexture = nil
end

function PANEL:SetImage( strImage, strBackup )
	self.m_strImage = strImage or ""
	self.m_strMatName = self.m_strImage
	self.m_strFailsafe = strBackup or ""
	self.m_iTexture = nil
end

function PANEL:GetImage() return self.m_strImage end

--- GMod: DImage:SetOnViewMaterial( MatName, MatNameBackup ) (dimage.lua:25-31) --
--- the spawnmenu's material lists use it to defer loading; here it is the same
--- path-based image plus GMod's ImageName field.
function PANEL:SetOnViewMaterial( MatName, MatNameBackup )
	self:SetImage( MatName, MatNameBackup )
	self.ImageName = MatName
end

function PANEL:SetMatName( strMat )
	self.m_strMatName = strMat or ""
	self.m_iTexture = nil
end

function PANEL:GetMatName() return self.m_strMatName end

function PANEL:SetFailsafeMatName( strMat )
	self.m_strFailsafe = strMat or ""
end

function PANEL:GetFailsafeMatName() return self.m_strFailsafe end

function PANEL:SetMaterial( mat )
	if ( mat and mat.GetName ) then
		self:SetImage( mat:GetName() )
	end
end

function PANEL:GetMaterial()
	return self.m_iTexture and { __path = self.m_strMatName, GetName = function( s ) return s.__path end } or nil
end

function PANEL:SetImageColor( col ) self.m_colImage = col or Color( 255, 255, 255, 255 ) end
function PANEL:GetImageColor() return self.m_colImage end

function PANEL:SetKeepAspect( b ) self.m_bKeepAspect = ( b ~= false ) end
function PANEL:GetKeepAspect() return self.m_bKeepAspect end

--- Resolve (once) and answer the texture id, falling back to the backup name.
function PANEL:DoLoadMaterial()
	if ( self.m_iTexture ~= nil ) then return self.m_iTexture end

	self.m_iTexture = false

	for _, name in ipairs( { self.m_strMatName, self.m_strFailsafe } ) do
		if ( name and name ~= "" ) then
			local id = TextureID( name )

			if ( id ) then
				self.m_iTexture = id
				break
			end
		end
	end

	return self.m_iTexture
end

--- GMod's LoadMaterial: bind it.  There is nothing else to bind here.
function PANEL:LoadMaterial()
	return self:DoLoadMaterial()
end

--- The image's own pixel size, when the engine can answer (surface.DrawGetTextureSize).
--- GMod's GetSize answers the material size, not the panel size.
function PANEL:GetSize()
	local id = self:DoLoadMaterial()
	local w, h = self:GetWide(), self:GetTall()

	if ( id and surface.DrawGetTextureSize ) then
		local tw, th = surface.DrawGetTextureSize( id )
		if ( tw and th and tw > 0 and th > 0 ) then return tw, th end
	end

	return w, h
end

--- GMod: SizeToContents().  GMod sizes itself from the material's own dimensions
--- (dimage.lua:143, "self:SetSize( self.ActualWidth, self.ActualHeight )").  Here
--- GetSize answers the texture's pixel size when the engine can report it, so an
--- icon16/folder.png becomes 16x16 - which is exactly what a DTree_Node needs, its
--- PerformLayout places the label's text inset from the icon's width.  When the
--- size is unknown GetSize answers the panel's current size, so this stays a no-op
--- rather than collapsing the image to 0x0.
function PANEL:SizeToContents()
	local w, h = self:GetSize()

	if ( w and h and w > 0 and h > 0 ) then
		self:SetSize( w, h )
	end
end

--- GMod's PaintAt( x, y, w, h ): draw the image into that rect, honouring
--- SetKeepAspect (letterbox inside the rect) and SetImageColor (tint).
function PANEL:PaintAt( x, y, w, h )
	local id = self:DoLoadMaterial()

	if ( not id ) then
		return
	end

	x, y, w, h = x or 0, y or 0, w or self:GetWide(), h or self:GetTall()

	if ( self.m_bKeepAspect and surface.DrawGetTextureSize ) then
		local tw, th = surface.DrawGetTextureSize( id )

		if ( tw and th and tw > 0 and th > 0 ) then
			local scale = math.min( w / tw, h / th )
			local dw, dh = tw * scale, th * scale

			x = x + ( w - dw ) / 2
			y = y + ( h - dh ) / 2
			w, h = dw, dh
		end
	end

	local c = self.m_colImage

	surface.DrawSetColor( c.r, c.g, c.b, c.a )
	surface.DrawSetTexture( id )
	surface.DrawTexturedRect( math.floor( x ), math.floor( y ), math.floor( w ), math.floor( h ) )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Image", self, w, h )

	self:PaintAt( 0, 0, w, h )
end

derma.DefineControl( "DImage", "HL2SB image/material panel", PANEL, "DPanel" )
