
--[[--------------------------------------------------------------------
    sh_anim.lua  --  GMod parity layer for the hold type system.

    GMod's sh_anim.lua builds self.ActivityTranslate (ACT_MP_* generic ->
    ACT_HL2MP_*_<holdtype>) and the GMod engine translates activities
    through it.  HL2SB's engine instead consumes the weapon's m_acttable
    directly (CBaseCombatWeapon::ActivityOverride), and shared.lua's
    SetHoldType() builds that table.

    This file keeps GMod's entry points working:
      * SetWeaponHoldType( t )  routes to SetHoldType( t ) in shared.lua
        (called at runtime, so include order does not matter).
      * TranslateActivity( act ) answers from m_acttable, and also fills
        self.ActivityTranslate for scripts that read GMod's table.
----------------------------------------------------------------------]]

local ActIndex = {
	[ "pistol" ]	= "PISTOL",
	[ "smg" ]		= "SMG1",
	[ "grenade" ]	= "GRENADE",
	[ "ar2" ]		= "AR2",
	[ "shotgun" ]	= "SHOTGUN",
	[ "rpg" ]		= "RPG",
	[ "physgun" ]	= "PHYSGUN",
	[ "crossbow" ]	= "CROSSBOW",
	[ "melee" ]		= "MELEE",
	[ "slam" ]		= "SLAM",
	[ "normal" ]	= nil,
	[ "fist" ]		= "FIST",
	[ "melee2" ]	= "MELEE2",
	[ "passive" ]	= "PASSIVE",
	[ "knife" ]		= "KNIFE",
	[ "duel" ]		= "DUEL",
	[ "camera" ]	= "CAMERA",
	[ "magic" ]		= "MAGIC",
	[ "revolver" ]	= "REVOLVER",
}

--[[---------------------------------------------------------
	Name: SetWeaponHoldType
	Desc: GMod's entry point.  The m_acttable build lives in
	      shared.lua:SetHoldType -- that is the table this engine reads.
-----------------------------------------------------------]]
function SWEP:SetWeaponHoldType( t )

	t = string.lower( t or "normal" )

	-- Fill GMod's ActivityTranslate for scripts that read it.  The engine
	-- itself does not consume this table; nothing here can break drawing.
	self.ActivityTranslate = {}

	local suffix = ActIndex[ t ]
	if ( suffix ~= nil and ACT_HL2MP_IDLE ~= nil ) then
		local index = _G[ "ACT_HL2MP_IDLE_" .. suffix ]
		local T = function( key, value )
			if ( key ~= nil and value ~= nil ) then
				self.ActivityTranslate[ key ] = value
			end
		end

		T( ACT_MP_STAND_IDLE,					index )
		T( ACT_MP_WALK,							index and index + 1 )
		T( ACT_MP_RUN,							index and index + 2 )
		T( ACT_MP_CROUCH_IDLE,					index and index + 3 )
		T( ACT_MP_CROUCHWALK,					index and index + 4 )
		T( ACT_MP_ATTACK_STAND_PRIMARYFIRE,		index and index + 5 )
		T( ACT_MP_ATTACK_CROUCH_PRIMARYFIRE,	index and index + 5 )
		T( ACT_MP_RELOAD_STAND,					index and index + 6 )
		T( ACT_MP_RELOAD_CROUCH,				index and index + 6 )
		T( ACT_MP_JUMP,							index and index + 7 )
		T( ACT_RANGE_ATTACK1,					index and index + 8 )
		T( ACT_MP_SWIM_IDLE,					index and index + 8 )
		T( ACT_MP_SWIM,							index and index + 9 )

		-- "normal" jump animation doesn't exist
		if ( t == "normal" ) then
			T( ACT_MP_JUMP, ACT_HL2MP_JUMP_SLAM )
		end
	end

	return self:SetHoldType( t )

end

--[[---------------------------------------------------------
	Name: TranslateActivity
	Desc: Answers from the engine-facing m_acttable so scripts that ask
	      (and the AI path) get the same translation the engine uses.
-----------------------------------------------------------]]
function SWEP:TranslateActivity( act )

	local rows = self.m_acttable
	if ( rows ) then
		for i = 1, #rows do
			if ( rows[ i ][ 1 ] == act ) then
				return rows[ i ][ 2 ]
			end
		end
	end

	return -1

end
