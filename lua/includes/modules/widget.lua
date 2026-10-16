

--
-- Widgets are like gui controls in the 3D world(!!!)
--

widgets = {}
local widgetEntities = {}

--
-- Holds the currently hovered widget
--
widgets.Hovered = nil
widgets.HoveredPos = vector_origin

--
-- Holds the current pressed widget
--
widgets.Pressed = nil

local function UpdateHovered( pl )

	if ( !IsValid( pl ) ) then return end

	if ( !pl:Alive() ) then
		pl:SetHoveredWidget( NULL )
		return
	end

	local eyePos = pl:EyePos()
	local aimVector = pl:GetAimVector()
	aimVector:Mul( 256 )
	aimVector:Add( eyePos )

--	debugoverlay.Line( eyePos, aimVector, 0.5 )

	-- HL2SB: util.TraceLine's "whitelist" flag is not implemented by this
	-- fork's trace parser (the AGENTS.md trace section records it as a known
	-- gap), and WITHOUT it the filter table would be read as an ignore list --
	-- every widget excluded from the trace and hover could never register.
	-- Reference behaviour is "only the entities in the table participate", so
	-- the same test is run directly: each widget's own TestCollision (the
	-- method the whitelisted trace consults) is asked for its ray hit, and
	-- the nearest one wins, exactly like a sorted trace result.
	widgets.Tracing = true

	local hitEntity = nil
	local hitPos = nil
	local hitFraction = nil

	for _, v in ipairs( widgetEntities ) do

		-- HL2SB: guard stale entries.  The client realm never dispatches the
		-- EntityRemoved hook this module prunes with, so a removed widget can
		-- still sit in the list here.
		if ( IsValid( v ) ) then

			local result = v:TestCollision( eyePos, aimVector - eyePos, false, nil )

			if ( result != nil and result.Fraction != nil ) then

				-- TestCollision already folds the widget's priority into the
				-- fraction (each implementation multiplies it in), so the
				-- raw value is comparable as-is.
				local fraction = result.Fraction

				if ( hitFraction == nil or fraction < hitFraction ) then
					hitEntity = v
					hitPos = result.HitPos
					hitFraction = fraction
				end

			end

		end

	end

	widgets.Tracing = false

	if ( !IsValid( hitEntity ) ) then
		pl:SetHoveredWidget( NULL )
		return
	end

--	debugoverlay.Cross( hitPos, 1, 60 )

	pl:SetHoveredWidget( hitEntity )
	pl.WidgetHitPos = hitPos

	return hitEntity

end

local function UpdateButton( pl, mv, btn, mousebutton, hvr, prs )

	-- HL2SB: this engine's CMoveData binds KeyDown/KeyReleased but not GMod's
	-- KeyWasDown; GetOldButtons carries the same "down last frame" bits the
	-- reference callback reads.
	local now = mv:KeyDown( btn )
	local was

	if ( mv.KeyWasDown != nil ) then
		was = mv:KeyWasDown( btn )
	else
		local old = mv:GetOldButtons()

		if ( bit != nil and bit.band != nil ) then
			was = old != nil and bit.band( old, btn ) != 0
		else
			was = old != nil and math.floor( old / btn ) % 2 >= 1
		end
	end

	if ( now && !was && IsValid( hvr ) ) then
		hvr:OnPress( pl, mousebutton, mv )
	end

	if ( !now && was && IsValid( prs ) ) then
		prs:OnRelease( pl, mousebutton, mv )
	end

end

--
-- The idea here is to have exactly the same
-- behaviour on the client as the server.
--
function widgets.PlayerTick( pl, mv )

	local hvr = UpdateHovered( pl )
	local prs = pl:GetPressedWidget()

	UpdateButton( pl, mv, IN_ATTACK, 1, hvr, prs )
	UpdateButton( pl, mv, IN_ATTACK2, 2, hvr, prs )

	if ( IsValid( prs ) ) then
		prs:PressedThinkInternal( pl, mv )
	end

end

---
---  Render the widgets!
---

-- Function stub for backwards compatibility
function widgets.RenderMe( ent )
	-- We do this solely for backwards compatibility
	ent._WantsWidgetRender = true
end

local function RenderWidgets()

	local prs = LocalPlayer():GetPressedWidget()
	local prsValid = IsValid( prs )

	cam.Start3D( EyePos(), EyeAngles() )

		for _, v in ipairs( widgetEntities ) do

			--
			-- The pressed widget gets to decide what should draw
			--
			if ( prsValid && !prs:PressedShouldDraw( v ) ) then continue end
			if ( !v._WantsWidgetRender ) then continue end

			v:OverlayRender()
			v._WantsWidgetRender = nil

		end

	cam.End3D()

end

hook.Add( "OnEntityCreated", "CreateWidgets", function( ent )

	timer.Simple( 0.001, function()

		-- HL2SB: an entity can already be gone by the time this 0.001s timer runs,
		-- and on a deleted entity every method lookup returns nil: the call then
		-- RAISES a Lua error, and on this ARM64EC host raising is where the game
		-- can die.  Check validity first.
		if ( not IsValid( ent ) ) then return end
		if ( !ent:IsWidget() ) then return end

		table.insert( widgetEntities, ent )
		hook.Add( "PlayerTick", "TickWidgets", widgets.PlayerTick )

		if ( CLIENT ) then
			hook.Add( "PostDrawEffects", "RenderWidgets", RenderWidgets )
		end

	end )

end )

hook.Add( "EntityRemoved", "RemoveWidgets", function( ent )

	if ( !ent:IsWidget() ) then return end

	for k, v in next, widgetEntities do
		if ( v == ent ) then
			table.remove( widgetEntities, k )
			break
		end
	end

	if ( #widgetEntities == 0 ) then
		hook.Remove( "PlayerTick", "TickWidgets" )

		if ( CLIENT ) then
			hook.Remove( "PostDrawEffects", "RenderWidgets" )
		end
	end

end )

local ENTITY = FindMetaTable( "Entity" )

function ENTITY:IsWidget()
	return self.Widget
end

