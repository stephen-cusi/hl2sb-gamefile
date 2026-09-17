--[[ DImageButton -- icon + caption button (original implementation).

	The engine's texture path is surface.CreateNewTextureID() +
	DrawSetTextureFile( id, path, linear, load ); this fork's png fallback in
	CTextureManager means a plain .png path works, no .vmt needed.  The id is
	created once per image and cached on the panel. --]]

local PANEL = {}

function PANEL:Init()
	self:SetDrawBackground( false )
	self.m_strImage = ""
	self.m_iImageSize = 32
	self.m_iTexture = nil
end

function PANEL:SetImage( strPath, strBackup )
	strPath = strPath or ""
	if ( strPath == self.m_strImage ) then return end

	self.m_strImage = strPath
	self.m_strBackup = strBackup or self.m_strBackup
	self.m_iTexture = nil

	if ( strPath ~= "" and surface.CreateNewTextureID ) then
		local id = surface.CreateNewTextureID()
		-- binding: DrawSetTextureFile( id, path, linear<int>, load<bool> )
		surface.DrawSetTextureFile( id, strPath, 1, true )
		self.m_iTexture = id
	end
end

--- GMod: DImageButton:GetImage() -- "Returns the image path" (its dimagebutton.lua
--- delegates to the DImage it owns).  DIconBrowser identifies its buttons by this.
function PANEL:GetImage()
	return self.m_strImage or ""
end

--- GMod: DImageButton:SetOnViewMaterial( MatName, Backup ) (dimagebutton.lua:142)
--- and the DImage half (dimage.lua:25).  Same path-based image here; ImageName is
--- the field GMod's DImage keeps for it.
function PANEL:SetOnViewMaterial( MatName, Backup )
	self:SetImage( MatName, Backup )
	self.ImageName = MatName
end

function PANEL:SetImageSize( iSize )
	self.m_iImageSize = iSize
end

--- GMod: DImageButton:SetColor( col ) -- tints the image (its dimagebutton.lua:39).
--- DPropertySheet:SetupCloseButton sets the close button's colour, so DColorCombo's
--- popup needs it.
function PANEL:SetColor( col )
	self.m_colImage = col
end

function PANEL:GetColor()
	return self.m_colImage
end

--- GMod: DImageButton:SetStretchToFit( b ) / SetKeepAspect( b ) (dimagebutton.lua).
--- DNumberScratch turns stretching off (`self:SetStretchToFit( false )`) so the
--- icon keeps its own size inside the 16x16 button.
function PANEL:SetStretchToFit( b )
	self.m_bStretchToFit = ( b ~= false )
end

function PANEL:GetStretchToFit()
	return self.m_bStretchToFit ~= false
end

function PANEL:SetKeepAspect( b )
	self.m_bKeepAspect = ( b ~= false )
end

function PANEL:GetKeepAspect()
	return self.m_bKeepAspect ~= false
end

function PANEL:SetMaterial( mat )
	-- GMod's SetMaterial takes an IMaterial; store its path when possible.
	if ( mat and mat.GetName ) then
		self:SetImage( mat:GetName() )
	end
end

--- GMod: DImageButton:SizeToContents() -- the icon plus its caption.
--- DColumnSheet:UseButtonOnlyStyle() calls it on every tab button.
function PANEL:SizeToContents()
	local w = self.m_iImageSize
	local h = self.m_iImageSize

	local text = self:GetText()
	if ( text and text ~= "" ) then
		local tw, th = derma.GetTextSize( "DermaDefault", text )
		w = math.max( w, tw )
		h = h + th
	end

	self:SetSize( w + 4, h + 6 )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Button", self, w, h )

	if ( self.m_iTexture ) then
		local col = self.m_colImage
		if ( col ) then
			surface.DrawSetColor( col.r, col.g, col.b, col.a )
		end

		surface.DrawSetTexture( self.m_iTexture )

		if ( self.m_bStretchToFit == false ) then
			-- GMod's SetStretchToFit( false ): draw the icon at its own size, centred
			local isz = self.m_iImageSize
			surface.DrawTexturedRect( math.floor( ( w - isz ) / 2 ),
				math.max( 2, math.floor( ( h - isz ) / 2 ) - 6 ), isz, isz )
		else
			surface.DrawTexturedRect( 2, 2, math.max( 1, w - 4 ), math.max( 1, h - 4 ) )
		end
	end

	local text = self:GetText()
	if ( text ~= "" ) then
		local tw, th = derma.GetTextSize( "DermaDefault", text )
		derma.DrawText( "DermaDefault", math.floor( ( w - tw ) / 2 ), h - th - 4,
			text, Color( 220, 220, 220, 255 ) )
	end
end

derma.DefineControl( "DImageButton", "HL2SB icon button", PANEL, "DButton" )
