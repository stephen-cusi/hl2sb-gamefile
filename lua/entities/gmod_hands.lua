--===========================================================================
-- HL2SB (2026-09-27): port of GMod's hands entity, verbatim from
-- garrysmod/gamemodes/base/entities/entities/gmod_hands.lua (77 lines).
--
-- DoSetup registers the entity on the player's replicated hands handle
-- (Player:SetHands -> the networked EHandle GetHands/SetHands resolve),
-- lets the gamemode pick the model (GM:PlayerSetHandsModel) and EF_BONEMERGEs
-- itself onto the viewmodel; GM:PostDrawViewModel (deathmatch cl_init.lua)
-- draws it after the viewmodel, gated on the weapon's UseHands -- exactly
-- GMod's pipeline.  The engine fires OnViewModelChanged on viewmodel model
-- swaps so the entity re-parents.
--
-- Deltas from the GMod original (missing engine surface, all inline):
--   * ENT:SetTransmitWithParent / Entity:DeleteOnRemove are not bound here;
--     the hands follow the owner-only viewmodel anyway, and Player:SetupHands
--     removes the previous pair on every respawn.
--   * vector_origin / angle_zero globals don't exist -> constructors.
--   * GMod's EF_BONEMERGE enum is published as BONE_MERGE here -> fallback.
--===========================================================================--

AddCSLuaFile()

ENT.Type = "anim"
ENT.RenderGroup = RENDERGROUP_OTHER
ENT.DisableDuplicator = true

function ENT:Initialize()

	hook.Add( "OnViewModelChanged", self, self.ViewModelChanged )

	self:SetNotSolid( true )
	self:DrawShadow( false )

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

	-- HL2SB delta: the entity can arrive here already removed (a stale hook
	-- key from a previous spawn); this fork's NULL-entity __index answers nil
	-- for methods, so GetOwner would throw.  GMod's original has no guard.
	if ( !IsValid( self ) ) then return end

	-- Ignore other people's viewmodel changes!
	if ( vm:GetOwner() != self:GetOwner() ) then return end

	self:AttachToViewmodel( vm )

end

function ENT:OnRemove( fullUpdate )

	-- HL2SB delta: drop the viewmodel hook too.  SetupHands replaces the hands
	-- on every spawn; without this the dead entity kept receiving
	-- OnViewModelChanged (each weapon model swap) and errored on GetOwner.
	hook.Remove( "OnViewModelChanged", self )

	if ( fullUpdate ) then return end

	-- Resolve engine complaints when unparenting from the viewmodel
	self:SetPos( Vector( 0, 0, 0 ) )

end

function ENT:AttachToViewmodel( vm )

	self:SetPos( self:GetOwner():GetPos() )
	self:SetAngles( QAngle( 0, 0, 0 ) )

	self:AddEffects( EF_BONEMERGE or BONE_MERGE )
	self:SetParent( vm )
	self:SetMoveType( MOVETYPE_NONE )

end
