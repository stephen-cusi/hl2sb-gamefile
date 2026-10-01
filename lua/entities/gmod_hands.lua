--===========================================================================
-- HL2SB (2026-10-02): verbatim GMod garrysmod/gamemodes/base/entities/
-- entities/gmod_hands.lua - every fork delta removed now that the engine
-- surface exists (Entity:SetTransmitWithParent, Entity:DeleteOnRemove,
-- vector_origin/angle_zero globals).  The entity is EF_BONEMERGE'd onto the
-- owner's viewmodel, carries RENDERGROUP_OTHER so the world pass never draws
-- it, and GM:PostDrawViewModel (deathmatch cl_init.lua) owns its single draw.
--===========================================================================--

AddCSLuaFile()

ENT.Type = "anim"
ENT.RenderGroup = RENDERGROUP_OTHER
ENT.DisableDuplicator = true

function ENT:Initialize()

	hook.Add( "OnViewModelChanged", self, self.ViewModelChanged )

	self:SetNotSolid( true )
	self:DrawShadow( false )
	self:SetTransmitWithParent( true ) -- Transmit only when the viewmodel does!

end

function ENT:DoSetup( ply, spec )

	-- Set these hands to the player
	ply:SetHands( self )
	self:SetOwner( ply )

	-- Which hands should we use? Let the gamemode decide
	hook.Call( "PlayerSetHandsModel", GAMEMODE, spec or ply, self )

	-- Attach them to the viewmodel
	local vm = ( spec or ply ):GetViewModel( 0 )
	self:AttachToViewmodel( vm )

	vm:DeleteOnRemove( self )
	ply:DeleteOnRemove( self )

end

function ENT:GetPlayerColor()

	--
	-- Make sure there's an owner and they have this function
	-- before trying to call it!
	--
	local owner = self:GetOwner()
	if ( !IsValid( owner ) ) then return end
	if ( !owner.GetPlayerColor ) then return end

	return owner:GetPlayerColor()

end

function ENT:ViewModelChanged( vm, old, new )

	-- Ignore other people's viewmodel changes!
	if ( vm:GetOwner() != self:GetOwner() ) then return end

	self:AttachToViewmodel( vm )

end

function ENT:OnRemove( fullUpdate )

	if ( fullUpdate ) then return end

	-- Resolve engine complaints when unparenting from the viewmodel
	self:SetPos( vector_origin )

end

function ENT:AttachToViewmodel( vm )

	self:SetPos( self:GetOwner():GetPos() )
	self:SetAngles( angle_zero )

	self:AddEffects( EF_BONEMERGE )
	self:SetParent( vm )
	self:SetMoveType( MOVETYPE_NONE )

end
