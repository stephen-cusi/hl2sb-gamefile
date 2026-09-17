--[[ DAdjustableModelPanel -- a DModelPanel whose camera the user can fly (original).

	Wiki: https://wiki.facepunch.com/gmod/DAdjustableModelPanel
	  "A derivative of the DModelPanel in which the user may modify the perspective of the
	   model with their mouse and keyboard by clicking and dragging.
	   ... When the left mouse is used, the Shift key holds the current `y` angle steady."
	  Parent: DModelPanel.
	  Methods: CaptureMouse / FirstPersonControls / SetFirstPerson / GetFirstPerson /
	           SetMovementScale / GetMovementScale
	  + the example: SetLookAng( Angle( 45, 0, 0 ) ), SetCamPos( Vector( -20, 0, 20 ) ).

	Behaviour kept from GMod: left-drag orbits around the model, right-drag flies the
	camera (WASD/arrows/space/ctrl, shift = 4x), the wheel changes FOV, and the cursor is
	parked in the panel centre each frame while capturing.

	⚠️ Substitutions, because this fork has no `util.IntersectRayWithPlane` and no
	`Entity:GetModelBounds` binding:
	  * The orbit point is the model's own centre (GetModelRenderBounds -> OBBCenter ->
	    origin + 24 units, whichever answers first) instead of a ray/box hit.
	  * `input.LookupKeyBinding` and `input.IsShiftDown` are used only when they exist;
	    the key checks then fall back to input.IsKeyDown( KEY_* ), which is bound.
	  * Think is driven from OnThink (this fork dispatches OnThink, see lua/vgui/DScrollPanel.lua).
--]]

local PANEL = {}

AccessorFunc( PANEL, "m_bFirstPerson", "FirstPerson", FORCE_BOOL )
AccessorFunc( PANEL, "m_iMoveScale", "MovementScale", FORCE_NUMBER )

function PANEL:Init()
	self.mx = 0
	self.my = 0
	self.aLookAngle = angle_zero or Angle( 0, 0, 0 )
	self.Capturing = false

	self:SetMovementScale( 1 )
end

--- The middle of the model, with every accessor this fork might or might not bind.
local function ModelCenter( ent )
	if ( not IsValid( ent ) ) then return vector_origin or Vector( 0, 0, 0 ) end

	if ( ent.GetModelRenderBounds ) then
		local ok, mn, mx = pcall( ent.GetModelRenderBounds, ent )

		if ( ok and isnumber( mn.x ) and isnumber( mx.x ) ) then
			return ( mn + mx ) * 0.5
		end
	end

	if ( ent.OBBCenter ) then
		local ok, c = pcall( ent.OBBCenter, ent )

		if ( ok and isnumber( c.x ) ) then
			return ent:GetPos() + c
		end
	end

	return ent:GetPos() + Vector( 0, 0, 24 )
end

function PANEL:OnMousePressed( mousecode )
	if ( gui and gui.IsGameUIVisible and gui.IsGameUIVisible() ) then return end
	if ( mousecode ~= MOUSE_LEFT and mousecode ~= MOUSE_RIGHT ) then return end

	self:SetCursor( "none" )
	self:MouseCapture( true )
	self.Capturing = true
	self.MouseKey = mousecode

	self:SetFirstPerson( true )
	self:CaptureMouse()

	if ( IsValid( self.Entity ) ) then
		self.OrbitPoint = ModelCenter( self.Entity )
	else
		self.OrbitPoint = vector_origin or Vector( 0, 0, 0 )
	end

	self.OrbitDistance = ( self.OrbitPoint - self.vCamPos ):Length()
end

--- Wiki: "Used by the panel to perform mouse capture operations when adjusting the model."
function PANEL:CaptureMouse()
	if ( gui and gui.IsGameUIVisible and gui.IsGameUIVisible() ) then return 0, 0 end
	if ( not input or not input.GetCursorPos ) then return 0, 0 end

	local x, y = input.GetCursorPos()

	local dx = x - self.mx
	local dy = y - self.my

	local centerx, centery = self:LocalToScreen( self:GetWide() * 0.5, self:GetTall() * 0.5 )

	if ( input.SetCursorPos ) then input.SetCursorPos( centerx, centery ) end

	self.mx = centerx
	self.my = centery

	return dx, dy
end

--- GMod walks every key code looking for the binding; only done when the binding API
--- exists, and always combined with the plain key check.
local function IsBoundKeyDown( cmd, keyCode )
	if ( input and input.LookupKeyBinding and input.IsKeyDown ) then
		local last = ( BUTTON_CODE_LAST or 200 )

		for code = 1, last do
			if ( input.LookupKeyBinding( code ) == cmd and input.IsKeyDown( code ) ) then
				return true
			end
		end
	end

	if ( keyCode and input and input.IsKeyDown and input.IsKeyDown( keyCode ) ) then
		return true
	end

	return false
end

--- Wiki: "Used to adjust the perspective in the model panel via the keyboard, when the
--- right mouse button is used."
function PANEL:FirstPersonControls()
	local x, y = self:CaptureMouse()

	local scale = self:GetFOV() / 180
	x = x * -0.5 * scale
	y = y * 0.5 * scale

	if ( self.MouseKey == MOUSE_LEFT ) then
		-- orbit: the camera swings around the model point, the angle stays put on shift
		if ( input and input.IsShiftDown and input.IsShiftDown() ) then y = 0 end

		self.aLookAngle = self.aLookAngle + Angle( y * 4, x * 4, 0 )
		self.vCamPos = self.OrbitPoint - self.aLookAngle:Forward() * ( self.OrbitDistance or 100 )

		return
	end

	-- fly: look with the mouse, move with the keys
	self.aLookAngle = self.aLookAngle + Angle( y, x, 0 )
	self.aLookAngle.p = math.Clamp( self.aLookAngle.p, -90, 90 )

	local movement = vector_origin or Vector( 0, 0, 0 )
	local fwd = self.aLookAngle:Forward()
	local rgt = self.aLookAngle:Right()
	local up = vector_up or Vector( 0, 0, 1 )

	if ( IsBoundKeyDown( "+forward", KEY_UP ) ) then movement = movement + fwd end
	if ( IsBoundKeyDown( "+back", KEY_DOWN ) ) then movement = movement - fwd end
	if ( IsBoundKeyDown( "+moveleft", KEY_LEFT ) ) then movement = movement - rgt end
	if ( IsBoundKeyDown( "+moveright", KEY_RIGHT ) ) then movement = movement + rgt end
	if ( IsBoundKeyDown( "+jump", KEY_SPACE ) ) then movement = movement + up end
	if ( IsBoundKeyDown( "+duck", KEY_LCONTROL ) ) then movement = movement - up end

	local speed = 0.5

	if ( input and input.IsShiftDown and input.IsShiftDown() ) then speed = 4.0 end

	self.vCamPos = self.vCamPos + movement * speed * self:GetMovementScale()
end

function PANEL:OnThink()
	if ( not self.Capturing ) then return end

	if ( self.m_bFirstPerson ) then
		return self:FirstPersonControls()
	end
end

--- GMod spells it Panel:Think; this fork dispatches OnThink, so both are wired.
function PANEL:Think()
	self:OnThink()
end

--- Wheel = zoom (GMod clamps FOV to 0.001 .. 179).
function PANEL:OnMouseWheeled( dlta )
	local scale = self:GetFOV() / 180

	self.fFOV = math.Clamp( self.fFOV + dlta * -10.0 * scale, 0.001, 179 )
end

function PANEL:OnMouseReleased( mousecode )
	self:SetCursor( "arrow" )
	self:MouseCapture( false )
	self.Capturing = false
end

function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )
	local ctrl = vgui.Create( ClassName )

	ctrl:SetSize( 300, 300 )
	ctrl:SetModel( "models/props_junk/PlasticCrate01a.mdl" )

	if ( IsValid( ctrl:GetEntity() ) ) then
		ctrl:GetEntity():SetSkin( 2 )
	end

	ctrl:SetLookAng( Angle( 45, 0, 0 ) )
	ctrl:SetCamPos( Vector( -20, 0, 20 ) )

	if ( PropertySheet and PropertySheet.AddSheet ) then
		PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )
	end

	return ctrl
end

derma.DefineControl( "DAdjustableModelPanel", "A model panel you can fly around", PANEL, "DModelPanel" )
