--[[ DModelPanel -- a 3D model projected onto a 2D panel (original implementation).

	Wiki: https://wiki.facepunch.com/gmod/DModelPanel
	  "DModelPanel is a VGUI element that projects a 3D model onto a 2D plane."
	  Parent: DButton.
	  Events: LayoutEntity( ent ) / PreDrawModel( ent ) -> bool / PostDrawModel( ent )
	  Methods: SetModel / GetModel / SetEntity / GetEntity / DrawModel / RunAnimation /
	           SetCamPos / GetCamPos / SetLookAt / GetLookAt / SetLookAng / GetLookAng /
	           SetFOV / GetFOV / SetAnimated / GetAnimated / SetAnimSpeed / GetAnimSpeed /
	           SetAmbientLight / GetAmbientLight / SetDirectionalLight / SetColor /
	           GetColor / StartScene

	This is GMod's implementation with the four calls this engine does not have swapped
	for the ones it does (all verified in the tree, sources in brackets):

	    cam.Start3D( pos, ang, fov, x, y, w, h, zNear, zFar )
	        -> render.PushView3D( ... )                     [game/client/lua/lrender.cpp:180]
	    cam.End3D()           -> render.PopView3D()         [lrender.cpp:211]
	    render.ResetModelLighting( r, g, b )
	        -> render.ResetAmbientLightCube( r, g, b )      [lrender.cpp:356]
	    render.SetModelLighting( i, r, g, b )
	        -> render.SetLight( r, g, b, 255, dir, i )      [lrender.cpp:401] (directional)
	    render.ClearDepth()   -> render.ClearBuffers( false, true, false )  [lrender.cpp:450]
	    surface.GetScissorRect() + render.SetScissorRect
	        -> render.SetScissorRectangle( l, t, r, b, on ) [lrender.cpp:475], with the rect
	           taken from the panel itself (LocalToScreen + size) since no getter exists.
	    Entity:SetIK( false ) -> skipped when the binding is absent.

	`ClientsideModel` is the fork's shim for Entities.CreateClientEntity
	(lua/includes/modules/gmod_compatibility/sh_init.lua:243 ->
	game/shared/lua/lbaseflex_shared.cpp:206), and `SetNoDraw` is the ENTITY_META shim
	that maps onto EF_NODRAW (sh_init.lua:772).
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_fAnimSpeed", "AnimSpeed" )
AccessorFunc( PANEL, "Entity", "Entity" )
AccessorFunc( PANEL, "vCamPos", "CamPos" )
AccessorFunc( PANEL, "fFOV", "FOV" )
AccessorFunc( PANEL, "vLookatPos", "LookAt" )
AccessorFunc( PANEL, "aLookAngle", "LookAng" )
AccessorFunc( PANEL, "colAmbientLight", "AmbientLight" )
AccessorFunc( PANEL, "colColor", "Color" )
AccessorFunc( PANEL, "bAnimated", "Animated" )

--- GMod's BOX_* face -> a direction for render.SetLight.  The numbers are the ones the
--- engine publishes (sh_enumerations.lua: BOX_FRONT = 0 ... BOX_TOP = 4), read at call
--- time so a missing enum cannot break the file's load.
local function FaceDirection( iDirection )
	local front = BOX_FRONT or 0
	local top = BOX_TOP or 4

	if ( iDirection == front ) then return Vector( 0, 1, 0 ) end

	local bottom = ( BOX_BOTTOM ~= nil ) and BOX_BOTTOM or 5
	local left = ( BOX_LEFT ~= nil ) and BOX_LEFT or 3
	local right = ( BOX_RIGHT ~= nil ) and BOX_RIGHT or 1
	local back = ( BOX_BACK ~= nil ) and BOX_BACK or 2

	if ( iDirection == top ) then return Vector( 0, 0, -1 ) end
	if ( iDirection == bottom ) then return Vector( 0, 0, 1 ) end
	if ( iDirection == left ) then return Vector( -1, 0, 0 ) end
	if ( iDirection == right ) then return Vector( 1, 0, 0 ) end
	if ( iDirection == back ) then return Vector( 0, -1, 0 ) end

	return Vector( 0, 1, 0 )
end

function PANEL:Init()
	self.Entity = nil
	self.LastPaint = 0
	self.DirectionalLight = {}
	self.FarZ = 4096

	self:SetCamPos( Vector( 50, 50, 50 ) )
	self:SetLookAt( Vector( 0, 0, 40 ) )
	self:SetFOV( 70 )

	self:SetText( "" )
	self:SetAnimSpeed( 0.5 )
	self:SetAnimated( false )

	self:SetAmbientLight( Color( 50, 50, 50 ) )

	self:SetDirectionalLight( BOX_TOP or 4, Color( 255, 255, 255 ) )
	self:SetDirectionalLight( BOX_FRONT or 0, Color( 255, 255, 255 ) )

	self:SetColor( color_white )
end

function PANEL:SetDirectionalLight( iDirection, color )
	self.DirectionalLight[ iDirection ] = color
end

--- Create the clientside model this panel draws.  GMod: `ClientsideModel( model,
--- RENDERGROUP_OTHER )`.
function PANEL:SetModel( strModelName )
	if ( IsValid( self.Entity ) ) then
		self.Entity:Remove()
		self.Entity = nil
	end

	if ( not strModelName or strModelName == "" ) then return end

	local create = _G.ClientsideModel
		or ( _G.ents and _G.ents.CreateClientEntity )

	if ( not create ) then
		if ( not self.m_bNoModelReported ) then
			self.m_bNoModelReported = true
			Warning( "DModelPanel: no ClientsideModel/ents.CreateClientEntity in this realm\n" )
		end

		return
	end

	local ok, ent = pcall( create, strModelName, RENDERGROUP_OTHER or 0 )

	if ( not ok or not IsValid( ent ) ) then
		if ( not self.m_bBadModelReported ) then
			self.m_bBadModelReported = true
			Warning( "DModelPanel: could not create a clientside model for '" ..
				tostring( strModelName ) .. "'\n" )
		end

		return
	end

	self.Entity = ent
	self.Entity:SetNoDraw( true )

	-- the IK binding does not exist in this fork (checked); GMod turns IK off so the
	-- sequence is not fighting the foot placement
	if ( self.Entity.SetIK ) then self.Entity:SetIK( false ) end

	-- Try to find a nice sequence to play (GMod's three candidates, in order)
	local iSeq = self.Entity:LookupSequence( "walk_all" )
	if ( ( not iSeq or iSeq <= 0 ) and self.Entity.LookupSequence ) then
		iSeq = self.Entity:LookupSequence( "WalkUnarmed_all" )
	end
	if ( ( not iSeq or iSeq <= 0 ) and self.Entity.LookupSequence ) then
		iSeq = self.Entity:LookupSequence( "walk_all_moderate" )
	end

	if ( iSeq and iSeq > 0 ) then self.Entity:ResetSequence( iSeq ) end
end

function PANEL:GetModel()
	if ( not IsValid( self.Entity ) ) then return end

	return self.Entity:GetModel()
end

--- Wiki: "Used by the DModelPanel's paint hook to draw the model and background."
function PANEL:DrawModel()
	-- GMod: render.ClearDepth( false ) + the panel's scissor rect around the draw
	render.ClearBuffers( false, true, false )

	if ( self:PreDrawModel( self.Entity ) ~= false ) then
		self.Entity:DrawModel()
		self:PostDrawModel( self.Entity )
	end
end

function PANEL:PreDrawModel( ent )
	return true
end

function PANEL:PostDrawModel( ent )
end

function PANEL:Paint( w, h )
	w = w or self:GetWide()
	h = h or self:GetTall()

	if ( not IsValid( self.Entity ) ) then return end
	if ( not ( render and render.PushView3D ) ) then return end

	local x, y = self:LocalToScreen( 0, 0 )

	self:LayoutEntity( self.Entity )

	local ang = self.aLookAngle
	if ( not ang ) then
		local delta = self.vLookatPos - self.vCamPos

		-- a camera exactly at its target has no direction: nudge it so Angle() is defined
		if ( delta:LengthSqr() < 1e-6 ) then delta = Vector( 0, 1, 0 ) end

		ang = delta:Angle()
	end

	-- clip the 3D view to the panel (this replaces GMod's
	-- surface.GetScissorRect -> render.SetScissorRect dance)
	if ( render.SetScissorRectangle ) then
		render.SetScissorRectangle( x, y, x + w, y + h, true )
	end

	render.PushView3D( self.vCamPos, ang, self.fFOV, x, y, w, h, 5, self.FarZ )

	render.SuppressEngineLighting( true )
	render.SetLightingOrigin( self.Entity:GetPos() )

	local amb = self.colAmbientLight or Color( 50, 50, 50 )
	render.ResetAmbientLightCube( amb.r / 255, amb.g / 255, amb.b / 255 )

	local col = self.colColor or color_white
	render.SetColorModulation( col.r / 255, col.g / 255, col.b / 255 )
	render.SetBlend( ( self:GetAlpha() / 255 ) * ( col.a / 255 ) )

	for i = 0, 6 do
		local lightCol = self.DirectionalLight[ i ]

		if ( lightCol ) then
			local dir = FaceDirection( i )

			render.SetLight( lightCol.r, lightCol.g, lightCol.b, 255, dir, i )
		end
	end

	self:DrawModel()

	-- ⚠️ A control's PreDrawModel can install studio LOCAL LIGHTS
	-- (render.SetLocalModelLights - the player model selector does exactly that for its
	-- three coloured point lights).  Those are GLOBAL render state that survives this
	-- draw: leaving them on lights every model and brush in the world with the preview's
	-- lamps, which is the same class of leak as the one documented in
	-- game/client/hl2sb_contextmenu.cpp:405-432 ("purple ERROR material / NaN dither
	-- noise after the overlay closes").  Calling it with no arguments disables them all
	-- (wiki: render.SetLocalModelLights).
	if ( render.SetLocalModelLights ) then render.SetLocalModelLights() end

	render.SuppressEngineLighting( false )
	render.PopView3D()

	if ( render.SetScissorRectangle ) then
		render.SetScissorRectangle( 0, 0, 0, 0, false )
	end

	self.LastPaint = RealTime()
end

function PANEL:RunAnimation()
	if ( IsValid( self.Entity ) and self.Entity.FrameAdvance ) then
		self.Entity:FrameAdvance()
	end
end

--- Wiki: "Runs a ClientsideScene on the panel's entity."
function PANEL:StartScene( name )
	if ( not _G.ClientsideScene ) then return end

	if ( IsValid( self.Scene ) ) then self.Scene:Remove() end

	self.Scene = ClientsideScene( name, self.Entity )
end

--- Wiki: "By default, this function slowly rotates and animates the entity being
--- rendered.  If you want to change this behavior, you should override it."
function PANEL:LayoutEntity( ent )
	if ( self.bAnimated ) then
		self:RunAnimation()
	end

	ent:SetAngles( Angle( 0, ( RealTime() * 10 ) % 360, 0 ) )
end

function PANEL:OnRemove()
	if ( IsValid( self.Entity ) ) then
		self.Entity:Remove()
		self.Entity = nil
	end
end

--- GMod's own property-sheet example (a crate, skin 2).
function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )

	ctrl:SetSize( 300, 300 )
	ctrl:SetModel( "models/props_junk/PlasticCrate01a.mdl" )

	if ( IsValid( ctrl:GetEntity() ) ) then
		ctrl:GetEntity():SetSkin( 2 )
	end

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DModelPanel", "A panel containing a model", PANEL, "DButton" )
