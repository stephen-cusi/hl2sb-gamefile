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

-- ===========================================================================
-- GMod's DOCK enum
--
-- https://wiki.facepunch.com/gmod/Enums/DOCK -- and that page notes this enum is
-- the one exception that has NO DOCK_ prefix, so the globals are bare names.
-- notification.lua:174 is `self.Label:Dock( FILL )`.
--
-- The numbers must match the DOCK_* defines in
-- source-engine/vgui2/vgui_controls/Panel.cpp and the bindings in
-- source-engine/public/lua/vgui_controls/lPanel.cpp.
--
-- Set defensively: this engine may already own one of these very generic names,
-- and silently overwriting it would break whatever else uses it.  A warning says
-- which one clashed and what it was.
-- ===========================================================================
local DOCK_ENUM = {
	{ "NODOCK", 0 },
	{ "FILL",   1 },
	{ "LEFT",   2 },
	{ "RIGHT",  3 },
	{ "TOP",    4 },
	{ "BOTTOM", 5 },
}

for _, entry in ipairs( DOCK_ENUM ) do
	local name, value = entry[ 1 ], entry[ 2 ]

	if ( _G[ name ] == nil ) then
		_G[ name ] = value
	elseif ( _G[ name ] ~= value ) then
		print( "[HL2SB] WARNING: global '" .. name .. "' is already " .. tostring( _G[ name ] )
			.. ", but GMod's DOCK enum needs it to be " .. tostring( value )
			.. " -- docking may misbehave\n" )
	end
end

-- ===========================================================================
-- GMod vs vgui2 spelling differences on the Panel metatable
--
-- This fork spells these with a capital B -- vgui2's own spelling, e.g.
-- scriptedhudviewport.cpp calls SetKeyBoardInputEnabled( false ) -- while GMod's
-- Lua API spells them with a lowercase b, and GMod's own panel files use the
-- GMod spelling:
--
--     Hook 'hl2sb_notification' (OnUndo) Failed:
--       lua/vgui/DLabel.lua:29: attempt to call a nil value (method 'SetKeyboardInputEnabled')
--
-- Alias both ways instead of renaming, so vgui2 C++ and GMod Lua both work.
--
-- Add to this table whenever the log names the next one; that is what the whole
-- class of failures looks like (GetRefTable/GetTable, call/Call, this).
-- ===========================================================================
local PANEL_METHOD_ALIASES = {
	{ "SetKeyboardInputEnabled", "SetKeyBoardInputEnabled" },
	{ "IsKeyboardInputEnabled",  "IsKeyBoardInputEnabled"  },
	{ "SetMouseInputEnabled",    "SetMouseInputEnabled"    },
	{ "IsMouseInputEnabled",     "IsMouseInputEnabled"     },
}

do
	local panelMeta = FindMetaTable and FindMetaTable( "Panel" )
	if ( panelMeta ~= nil ) then
		for _, pair in ipairs( PANEL_METHOD_ALIASES ) do
			local gmodName, engineName = pair[ 1 ], pair[ 2 ]

			if ( panelMeta[ gmodName ] == nil and panelMeta[ engineName ] ~= nil ) then
				panelMeta[ gmodName ] = panelMeta[ engineName ]
			end

			if ( panelMeta[ engineName ] == nil and panelMeta[ gmodName ] ~= nil ) then
				panelMeta[ engineName ] = panelMeta[ gmodName ]
			end
		end
	end
end
