--[[----------------------------------------------------------------------------
    gmod_isvalid.lua

    Gives the entity and player metatables an IsValid() METHOD.

    Why this is needed
    ------------------
    GMod's own lua/includes/util.lua defines the global IsValid() like this
    (util.lua:314-323, shipped here byte for byte):

        function IsValid( object )
            if ( !object ) then return false end
            local isvalid = object.IsValid          -- <- needs a METHOD
            if ( !isvalid ) then return false end
            return isvalid( object )
        end

    So the whole thing hinges on `object.IsValid` existing.  This engine never
    bound one -- there is no "IsValid" entry in any entity or player metatable
    (lbaseentity_shared.cpp / lbaseplayer_shared.cpp / lc_baseentity.cpp) -- so
    `isvalid` was always nil and the global answered FALSE for every entity and
    every player, including LocalPlayer().

    Measured in game before this file, with hl2sb_hud_debug 1:

        LocalPlayer()=CBasePlayer: 2 "hut"   IsValid=false   IsAlive=true
        [HL2SB HUD] undo.Finish REJECTED: IsValid(Owner)=false owner=nil entities=0

    Two GMod HUDs died on that single wrong answer:
      * lua/game/client/hl2sb_cl_hudpickup.lua gates every pickup on
        IsValid/ Alive of the local player, so the list never filled;
      * lua/includes/modules/undo.lua gates AddEntity/SetPlayer/Finish on
        "if ( !IsValid( x ) ) then return end", so every undo was dropped and
        the undo command always answered "no undo entry recorded".

    Reaching this method at all means the userdata exists, i.e. the pointer is
    non-NULL -- an entity that has been removed is a NULL entity userdata and
    does not get here (see the engine __index fix that makes indexing one return
    nil instead of raising, which is what GMod's engine does).

    TODO(engine): bind IsValid() on the entity metatable in C++
    (lbaseentity_shared.cpp) and delete this file -- the plan's standing rule is
    to fill engine gaps in the engine, not in Lua.
----------------------------------------------------------------------------]]--

local function AddIsValid( metaName )
	if ( FindMetaTable == nil ) then return end

	local meta = FindMetaTable( metaName )
	if ( meta == nil ) then return end
	if ( meta.IsValid ~= nil ) then return end

	function meta:IsValid()
		-- The userdata resolved to this metatable, so the engine pointer is
		-- non-NULL.  An entity that was removed stays a NULL userdata and never
		-- reaches this method.
		return true
	end
end

AddIsValid( "Entity" )
AddIsValid( "Player" )

-- ===========================================================================
-- Panel:Prepare()
--
-- lua/includes/extensions/client/panel/scriptedpanels.lua:44 calls
-- panel:Prepare() right after merging the control table, and this engine never
-- bound it:
--
--     Hook 'hl2sb_notification' (OnUndo) Failed:
--       scriptedpanels.lua:44: attempt to call a nil value (method 'Prepare')
--
-- In GMod it is a no-op hook that panels may override (DListView and friends
-- use it to build their columns), so a no-op on the metatable is faithful.
-- ===========================================================================
do
	local panelMeta = FindMetaTable and FindMetaTable( "Panel" )
	if ( panelMeta ~= nil and panelMeta.Prepare == nil ) then
		function panelMeta:Prepare()
		end
	end
end
