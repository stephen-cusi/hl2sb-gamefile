
local matScreen = Material( "models/weapons/v_toolgun/screen" )
local txBackground = surface.GetTextureID( "models/weapons/v_toolgun/screen_bg" )
local toolmode = GetConVar( "gmod_toolmode" )
local TEX_SIZE = 256

-- GetRenderTarget returns the texture if it exists, or creates it if it doesn't
local RTTexture = GetRenderTarget( "GModToolgunScreen", TEX_SIZE, TEX_SIZE )

surface.CreateFont( "GModToolScreen", {
	font	= "Helvetica",
	size	= 60,
	weight	= 900
} )

local function DrawScrollingText( text, y, texwide )

	-- HL2SB port adaptation (2026-10-16): the reference relies on the engine
	-- resolving a leading "#" localization token for BOTH calls it makes with
	-- the string.  This fork's surface.GetTextSize does exactly that
	-- (public/lua/vgui/LISurface.cpp binding: "A leading '#' is a
	-- localization token: resolve the phrase first and measure the localized
	-- text"), but surface.DrawText here is GMod's name for DrawPrintText,
	-- which converts the ANSI string as-is (lua/includes/extensions/
	-- gmod_surface.lua: surface.DrawText = surface.DrawPrintText).  Resolving
	-- the token once, up front, keeps the measured width and the drawn string
	-- identical instead of drawing a literal "#tool.rope.name".
	-- Look the phrase up by its key WITHOUT the leading '#': the language module
	-- resolves "tool.rope.name" from resource/localization/<lang>/tool.properties
	-- (this tree ships en/zh-cn/zh-tw), while passing the '#tool.rope.name' form
	-- makes it look for a key that includes the '#' and return the argument
	-- unchanged - which is exactly the literal token the screen showed.
	if ( string.sub( text, 1, 1 ) == "#" ) then
		local sKey = string.sub( text, 2 )
		local sPhrase = language.GetPhrase( sKey )
		if ( sPhrase != nil and sPhrase != "" ) then text = sPhrase end
	end

	local w, h = surface.GetTextSize( text )
	w = w + 64

	y = y - h / 2 -- Center text to y position

	local x = RealTime() * 250 % w * -1

	while ( x < texwide ) do

		surface.SetTextColor( 0, 0, 0, 255 )
		surface.SetTextPos( x + 3, y + 3 )
		surface.DrawText( text )

		surface.SetTextColor( 255, 255, 255, 255 )
		surface.SetTextPos( x, y )
		surface.DrawText( text )

		x = x + w

	end

end

--[[---------------------------------------------------------
	We use this opportunity to draw to the toolmode
		screen's rendertarget texture.
-----------------------------------------------------------]]
function SWEP:RenderScreen()
	-- HL2SB port adaptation (2026-10-16): GMod's global GetRenderTarget is an
	-- engine binding there; this fork answers it from Lua on top of
	-- render.CreateNamedRenderTarget (lua/includes/extensions/client/render.lua).
	-- If the texture could not be created while this weapon script loaded
	-- (material system not ready yet), retry on the first drawn frame
	-- instead of pushing a NULL render target every frame.
	if ( !RTTexture ) then RTTexture = GetRenderTarget( "GModToolgunScreen", TEX_SIZE, TEX_SIZE ) end
	if ( !RTTexture ) then return end


	-- Set the material of the screen to our render target
	matScreen:SetTexture( "$basetexture", RTTexture )

	-- Set up our view for drawing to the texture
	render.PushRenderTarget( RTTexture )
	cam.Start2D()

		-- Background
		surface.SetDrawColor( 255, 255, 255, 255 )
		surface.SetTexture( txBackground )
		surface.DrawTexturedRect( 0, 0, TEX_SIZE, TEX_SIZE )

		-- Give our toolmode the opportunity to override the drawing
		if ( self:GetToolObject() && self:GetToolObject().DrawToolScreen ) then

			self:GetToolObject():DrawToolScreen( TEX_SIZE, TEX_SIZE )

		else

			surface.SetFont( "GModToolScreen" )
			DrawScrollingText( "#tool." .. toolmode:GetString() .. ".name", 104, TEX_SIZE )

		end

	cam.End2D()
	render.PopRenderTarget()

end
