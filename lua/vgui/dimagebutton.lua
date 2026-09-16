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

function PANEL:SetImage( strPath )
	strPath = strPath or ""
	if ( strPath == self.m_strImage ) then return end

	self.m_strImage = strPath
	self.m_iTexture = nil

	if ( strPath ~= "" and surface.CreateNewTextureID ) then
		local id = surface.CreateNewTextureID()
		-- binding: DrawSetTextureFile( id, path, linear<int>, load<bool> )
		surface.DrawSetTextureFile( id, strPath, 1, true )
		self.m_iTexture = id
	end
end

function PANEL:SetImageSize( iSize )
	self.m_iImageSize = iSize
end

function PANEL:SetMaterial( mat )
	-- GMod's SetMaterial takes an IMaterial; store its path when possible.
	if ( mat and mat.GetName ) then
		self:SetImage( mat:GetName() )
	end
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	derma.SkinHook( "Paint", "Button", self, w, h )

	if ( self.m_iTexture ) then
		surface.DrawSetTexture( self.m_iTexture )
		local isz = self.m_iImageSize
		surface.DrawTexturedRect( math.floor( ( w - isz ) / 2 ),
			math.max( 2, math.floor( ( h - isz ) / 2 ) - 6 ), isz, isz )
	end

	local text = self:GetText()
	if ( text ~= "" ) then
		local tw, th = derma.GetTextSize( "DermaDefault", text )
		derma.DrawText( "DermaDefault", math.floor( ( w - tw ) / 2 ), h - th - 4,
			text, Color( 220, 220, 220, 255 ) )
	end
end

derma.DefineControl( "DImageButton", "HL2SB icon button", PANEL, "DButton" )
