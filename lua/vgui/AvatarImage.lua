--[[ AvatarImage -- a player avatar panel (nosteam stand-in for GMod's panel).

	GMod's AvatarImage shows a Steam avatar for a player or 64-bit steam id
	(SetPlayer( ply, size ) / SetSteamID( steamid, size ), both clientside).
	Its C++ panel keys everything by steam id, clamps the size hint to one of
	three tiers (<=32 small, <=64 medium, else large) and keeps showing the
	last avatar until the target changes; with no Steam layer there is no
	avatar to fetch, and the reference panel clears to a blank square.

	This control keeps the name, the API surface and the tier handling, and
	replaces the Steam fetch with a static local file read:

	  1. data/avatars/<steamid64>.png   (Player:SteamID64 / SetSteamID value)
	  2. data/avatars/<name>.png        (player name, filesystem-safe chars)
	  3. materials/avatars/default.png  (bundled stand-in, always shipped)

	The image is read once per SetPlayer/SetSteamID call - drop a file in and
	reconnect to see it (no hot reload).  Sizes: the file is drawn stretched
	over the panel like GMod draws its avatar; the tier argument is accepted
	and clamped exactly like the reference (0/1/2) but one file per key is
	looked up at every tier.

	The texture is an immediate RGBA upload (surface.DrawSetTexturePNG), which
	unlike texture-manager file entries survives level transitions.
--]]

local PANEL = {}

function PANEL:Init()
	self.m_iTexture = nil
	self.m_strAvatarKey = nil
	self.m_iAvatarSize = 0
end

--- Reference behavior: invalid targets clear the panel (no avatar drawn).
function PANEL:Clear()
	self.m_strAvatarKey = nil
	self.m_strFile = nil
	self.m_iAvatarSize = 0
	self.m_iTexture = nil
	self.m_bUploadFailed = false
end

--- GMod's size hint: values 32 / 64 / 184 map to tiers 0 / 1 / 2, anything
--- outside clamps to 0..2 (reference clamps in both SetPlayer and SetSteamID).
local function SizeTier( size )
	if ( !isnumber( size ) ) then return 0 end
	if ( size <= 32 ) then return 0 end
	if ( size <= 64 ) then return 1 end
	return 2
end

--- Filesystem-safe version of a key (player names may carry slashes/spaces).
local function SafeKey( key )
	return tostring( key or "" ):gsub( "[^%w%-_]", "" )
end

function PANEL:SetSteamID( steamid, size )
	if ( steamid == nil ) then
		self:Clear()
		return
	end

	self.m_iAvatarSize = SizeTier( size )
	self:LoadAvatarForKey( tostring( steamid ), { SafeKey( steamid ) } )
end

function PANEL:SetPlayer( ply, size )
	self.m_iAvatarSize = SizeTier( size )

	if ( !IsValid( ply ) ) then
		self:Clear()
		return
	end

	local candidates = {}

	local sid64 = nil
	if ( isfunction( ply.SteamID64 ) ) then
		sid64 = ply:SteamID64()
	end
	if ( isstring( sid64 ) and sid64 ~= "" ) then
		candidates[ #candidates + 1 ] = SafeKey( sid64 )
	end

	if ( isfunction( ply.Nick ) ) then
		local nick = SafeKey( ply:Nick() )
		if ( nick ~= "" ) then candidates[ #candidates + 1 ] = nick end
	end

	if ( #candidates == 0 ) then
		self:Clear()
		return
	end

	self:LoadAvatarForKey( candidates[ 1 ], candidates )
end

--- Probe the avatar files once per key set; the first hit wins, and the
--- bundled default covers "nothing found" (the reference shows a blank
--- square when Steam cannot answer - documented deviation).  The file is
--- remembered here and the RGBA upload happens on the first Paint, the same
--- lazy pattern the start-game dialog's map thumbnails use.
function PANEL:LoadAvatarForKey( key, candidates )
	-- Same target as before: keep the current image, like the reference
	-- early-outs when the steam id and tier did not change.
	if ( self.m_strAvatarKey == key ) then return end

	local files = {}
	for _, cand in ipairs( candidates ) do
		if ( cand ~= "" ) then
			files[ #files + 1 ] = "data/avatars/" .. cand .. ".png"
		end
	end

	local default = "materials/avatars/default.png"
	local found = nil
	for _, f in ipairs( files ) do
		if ( file.Exists( f, "GAME" ) ) then
			found = f
			break
		end
	end
	if ( found == nil and file.Exists( default, "GAME" ) ) then
		found = default
	end

	if ( found == nil ) then
		self:Clear()
		return
	end

	self.m_strAvatarKey = key
	self.m_strFile = found
	self.m_iTexture = nil
	self.m_bUploadFailed = false
end

function PANEL:GetSteamID()
	return self.m_strAvatarKey
end

function PANEL:Paint( w, h )
	-- First draw: read + decode + one immediate RGBA write onto the texture
	-- id, nothing registered in the texture manager (nothing to invalidate on
	-- map change).  One attempt per file, like the start-game dialog's map
	-- thumbnails this pattern is taken from.
	if ( self.m_iTexture == nil and not self.m_bUploadFailed and self.m_strFile ~= nil ) then
		self.m_bUploadFailed = true
		local id = surface.CreateNewTextureID( true )
		if ( surface.DrawSetTexturePNG ~= nil and surface.DrawSetTexturePNG( id, self.m_strFile ) ) then
			self.m_iTexture = id
			self.m_bUploadFailed = false
		end
	end

	if ( self.m_iTexture == nil ) then return end

	w = w or self:GetWide()
	h = h or self:GetTall()

	-- vgui multiplies textured draws by the current draw colour; reset to
	-- white so a previous textured pass cannot tint the avatar.
	surface.DrawSetColor( 255, 255, 255, 255 )
	surface.DrawSetTexture( self.m_iTexture )
	surface.DrawTexturedRect( 0, 0, w, h )
end

derma.DefineControl( "AvatarImage", "A player avatar panel (nosteam file backed)", PANEL, "Panel" )
