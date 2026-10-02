------------------------------------------------------------------------------
-- hl2sb_gmod_enums.lua - HL2SB GMod compat (2026-09-25)
--
-- GMod exposes engine bit enums as *global* constants (MASK_SHOT_HULL,
-- DMG_BLAST, ...).  HL2SB registers some of the same values as *library
-- tables* (MASK.SHOT_HULL via lbspflags.cpp luaopen_MASK) - addons written
-- against GMod see nil instead and either misbehave (nil mask in TraceHull)
-- or hard error (bit.bor( nil, ... )).
--
-- This file installs the global aliases WITHOUT touching the engine tables.
-- Loads from lua/includes/extensions/ so it runs before modules and autorun.
--
-- Written as one explicit assignment per enum ON PURPOSE: plain assignments
-- at line start are what scan_bindings.py recognises as "provided", so the
-- tool sees these shims without special-casing.  Values reference the engine
-- enum libraries where one exists; DMG values are transcribed from the
-- fork's own game/shared/shareddefs.h (same numbers GMod ships).
------------------------------------------------------------------------------

if ( rawget( _G, "MASK" ) ~= nil ) then
	if ( rawget( _G, "MASK_ALL" ) == nil ) then MASK_ALL = MASK.ALL end
	if ( rawget( _G, "MASK_SOLID" ) == nil ) then MASK_SOLID = MASK.SOLID end
	if ( rawget( _G, "MASK_PLAYERSOLID" ) == nil ) then MASK_PLAYERSOLID = MASK.PLAYERSOLID end
	if ( rawget( _G, "MASK_NPCSOLID" ) == nil ) then MASK_NPCSOLID = MASK.NPCSOLID end
	if ( rawget( _G, "MASK_WATER" ) == nil ) then MASK_WATER = MASK.WATER end
	if ( rawget( _G, "MASK_OPAQUE" ) == nil ) then MASK_OPAQUE = MASK.OPAQUE end
	if ( rawget( _G, "MASK_OPAQUE_AND_NPCS" ) == nil ) then MASK_OPAQUE_AND_NPCS = MASK.OPAQUE_AND_NPCS end
	if ( rawget( _G, "MASK_BLOCKLOS" ) == nil ) then MASK_BLOCKLOS = MASK.BLOCKLOS end
	if ( rawget( _G, "MASK_BLOCKLOS_AND_NPCS" ) == nil ) then MASK_BLOCKLOS_AND_NPCS = MASK.BLOCKLOS_AND_NPCS end
	if ( rawget( _G, "MASK_VISIBLE" ) == nil ) then MASK_VISIBLE = MASK.VISIBLE end
	if ( rawget( _G, "MASK_VISIBLE_AND_NPCS" ) == nil ) then MASK_VISIBLE_AND_NPCS = MASK.VISIBLE_AND_NPCS end
	if ( rawget( _G, "MASK_SHOT" ) == nil ) then MASK_SHOT = MASK.SHOT end
	if ( rawget( _G, "MASK_SHOT_HULL" ) == nil ) then MASK_SHOT_HULL = MASK.SHOT_HULL end
	if ( rawget( _G, "MASK_SHOT_PORTAL" ) == nil ) then MASK_SHOT_PORTAL = MASK.SHOT_PORTAL end
	if ( rawget( _G, "MASK_SOLID_BRUSHONLY" ) == nil ) then MASK_SOLID_BRUSHONLY = MASK.SOLID_BRUSHONLY end
	if ( rawget( _G, "MASK_PLAYERSOLID_BRUSHONLY" ) == nil ) then MASK_PLAYERSOLID_BRUSHONLY = MASK.PLAYERSOLID_BRUSHONLY end
	if ( rawget( _G, "MASK_NPCSOLID_BRUSHONLY" ) == nil ) then MASK_NPCSOLID_BRUSHONLY = MASK.NPCSOLID_BRUSHONLY end
	if ( rawget( _G, "MASK_NPCWORLDSTATIC" ) == nil ) then MASK_NPCWORLDSTATIC = MASK.NPCWORLDSTATIC end
	if ( rawget( _G, "MASK_SPLITAREAPORTAL" ) == nil ) then MASK_SPLITAREAPORTAL = MASK.SPLITAREAPORTAL end
	if ( rawget( _G, "MASK_CURRENT" ) == nil ) then MASK_CURRENT = MASK.CURRENT end
	if ( rawget( _G, "MASK_DEADSOLID" ) == nil ) then MASK_DEADSOLID = MASK.DEADSOLID end
end

if ( rawget( _G, "CONTENTS" ) ~= nil ) then
	if ( rawget( _G, "CONTENTS_EMPTY" ) == nil ) then CONTENTS_EMPTY = CONTENTS.EMPTY end
	if ( rawget( _G, "CONTENTS_SOLID" ) == nil ) then CONTENTS_SOLID = CONTENTS.SOLID end
	if ( rawget( _G, "CONTENTS_WINDOW" ) == nil ) then CONTENTS_WINDOW = CONTENTS.WINDOW end
	if ( rawget( _G, "CONTENTS_AUX" ) == nil ) then CONTENTS_AUX = CONTENTS.AUX end
	if ( rawget( _G, "CONTENTS_GRATE" ) == nil ) then CONTENTS_GRATE = CONTENTS.GRATE end
	if ( rawget( _G, "CONTENTS_SLIME" ) == nil ) then CONTENTS_SLIME = CONTENTS.SLIME end
	if ( rawget( _G, "CONTENTS_WATER" ) == nil ) then CONTENTS_WATER = CONTENTS.WATER end
	if ( rawget( _G, "CONTENTS_BLOCKLOS" ) == nil ) then CONTENTS_BLOCKLOS = CONTENTS.BLOCKLOS end
	if ( rawget( _G, "CONTENTS_OPAQUE" ) == nil ) then CONTENTS_OPAQUE = CONTENTS.OPAQUE end
	if ( rawget( _G, "CONTENTS_TESTFOGVOLUME" ) == nil ) then CONTENTS_TESTFOGVOLUME = CONTENTS.TESTFOGVOLUME end
	if ( rawget( _G, "CONTENTS_UNUSED" ) == nil ) then CONTENTS_UNUSED = CONTENTS.UNUSED end
	if ( rawget( _G, "CONTENTS_TEAM1" ) == nil ) then CONTENTS_TEAM1 = CONTENTS.TEAM1 end
	if ( rawget( _G, "CONTENTS_TEAM2" ) == nil ) then CONTENTS_TEAM2 = CONTENTS.TEAM2 end
	if ( rawget( _G, "CONTENTS_IGNORE_NODRAW_OPAQUE" ) == nil ) then CONTENTS_IGNORE_NODRAW_OPAQUE = CONTENTS.IGNORE_NODRAW_OPAQUE end
	if ( rawget( _G, "CONTENTS_MOVEABLE" ) == nil ) then CONTENTS_MOVEABLE = CONTENTS.MOVEABLE end
	if ( rawget( _G, "CONTENTS_AREAPORTAL" ) == nil ) then CONTENTS_AREAPORTAL = CONTENTS.AREAPORTAL end
	if ( rawget( _G, "CONTENTS_PLAYERCLIP" ) == nil ) then CONTENTS_PLAYERCLIP = CONTENTS.PLAYERCLIP end
	if ( rawget( _G, "CONTENTS_MONSTERCLIP" ) == nil ) then CONTENTS_MONSTERCLIP = CONTENTS.MONSTERCLIP end
	if ( rawget( _G, "CONTENTS_CURRENT_0" ) == nil ) then CONTENTS_CURRENT_0 = CONTENTS.CURRENT_0 end
	if ( rawget( _G, "CONTENTS_CURRENT_90" ) == nil ) then CONTENTS_CURRENT_90 = CONTENTS.CURRENT_90 end
	if ( rawget( _G, "CONTENTS_CURRENT_180" ) == nil ) then CONTENTS_CURRENT_180 = CONTENTS.CURRENT_180 end
	if ( rawget( _G, "CONTENTS_CURRENT_270" ) == nil ) then CONTENTS_CURRENT_270 = CONTENTS.CURRENT_270 end
	if ( rawget( _G, "CONTENTS_CURRENT_UP" ) == nil ) then CONTENTS_CURRENT_UP = CONTENTS.CURRENT_UP end
	if ( rawget( _G, "CONTENTS_CURRENT_DOWN" ) == nil ) then CONTENTS_CURRENT_DOWN = CONTENTS.CURRENT_DOWN end
	if ( rawget( _G, "CONTENTS_ORIGIN" ) == nil ) then CONTENTS_ORIGIN = CONTENTS.ORIGIN end
	if ( rawget( _G, "CONTENTS_MONSTER" ) == nil ) then CONTENTS_MONSTER = CONTENTS.MONSTER end
	if ( rawget( _G, "CONTENTS_DEBRIS" ) == nil ) then CONTENTS_DEBRIS = CONTENTS.DEBRIS end
	if ( rawget( _G, "CONTENTS_DETAIL" ) == nil ) then CONTENTS_DETAIL = CONTENTS.DETAIL end
	if ( rawget( _G, "CONTENTS_TRANSLUCENT" ) == nil ) then CONTENTS_TRANSLUCENT = CONTENTS.TRANSLUCENT end
	if ( rawget( _G, "CONTENTS_LADDER" ) == nil ) then CONTENTS_LADDER = CONTENTS.LADDER end
	if ( rawget( _G, "CONTENTS_HITBOX" ) == nil ) then CONTENTS_HITBOX = CONTENTS.HITBOX end
end

-- damage types (game/shared/shareddefs.h; Lua 5.1 has no << so plain ints)
if ( rawget( _G, "DMG_GENERIC" ) == nil ) then DMG_GENERIC = 0 end
if ( rawget( _G, "DMG_CRUSH" ) == nil ) then DMG_CRUSH = 1 end
if ( rawget( _G, "DMG_BULLET" ) == nil ) then DMG_BULLET = 2 end
if ( rawget( _G, "DMG_SLASH" ) == nil ) then DMG_SLASH = 4 end
if ( rawget( _G, "DMG_BURN" ) == nil ) then DMG_BURN = 8 end
if ( rawget( _G, "DMG_VEHICLE" ) == nil ) then DMG_VEHICLE = 16 end
if ( rawget( _G, "DMG_FALL" ) == nil ) then DMG_FALL = 32 end
if ( rawget( _G, "DMG_BLAST" ) == nil ) then DMG_BLAST = 64 end
if ( rawget( _G, "DMG_CLUB" ) == nil ) then DMG_CLUB = 128 end
if ( rawget( _G, "DMG_SHOCK" ) == nil ) then DMG_SHOCK = 256 end
if ( rawget( _G, "DMG_SONIC" ) == nil ) then DMG_SONIC = 512 end
if ( rawget( _G, "DMG_ENERGYBEAM" ) == nil ) then DMG_ENERGYBEAM = 1024 end
if ( rawget( _G, "DMG_PREVENT_PHYSICS_FORCE" ) == nil ) then DMG_PREVENT_PHYSICS_FORCE = 2048 end
if ( rawget( _G, "DMG_NEVERGIB" ) == nil ) then DMG_NEVERGIB = 4096 end
if ( rawget( _G, "DMG_ALWAYSGIB" ) == nil ) then DMG_ALWAYSGIB = 8192 end
if ( rawget( _G, "DMG_DROWN" ) == nil ) then DMG_DROWN = 16384 end
if ( rawget( _G, "DMG_PARALYZE" ) == nil ) then DMG_PARALYZE = 32768 end
if ( rawget( _G, "DMG_NERVEGAS" ) == nil ) then DMG_NERVEGAS = 65536 end
if ( rawget( _G, "DMG_POISON" ) == nil ) then DMG_POISON = 131072 end
if ( rawget( _G, "DMG_RADIATION" ) == nil ) then DMG_RADIATION = 262144 end
if ( rawget( _G, "DMG_DROWNRECOVER" ) == nil ) then DMG_DROWNRECOVER = 524288 end
if ( rawget( _G, "DMG_ACID" ) == nil ) then DMG_ACID = 1048576 end
if ( rawget( _G, "DMG_SLOWBURN" ) == nil ) then DMG_SLOWBURN = 2097152 end
if ( rawget( _G, "DMG_REMOVENORAGDOLL" ) == nil ) then DMG_REMOVENORAGDOLL = 4194304 end
if ( rawget( _G, "DMG_PHYSGUN" ) == nil ) then DMG_PHYSGUN = 8388608 end
if ( rawget( _G, "DMG_PLASMA" ) == nil ) then DMG_PLASMA = 16777216 end
if ( rawget( _G, "DMG_AIRBOAT" ) == nil ) then DMG_AIRBOAT = 33554432 end
if ( rawget( _G, "DMG_DISSOLVE" ) == nil ) then DMG_DISSOLVE = 67108864 end
if ( rawget( _G, "DMG_BLAST_SURFACE" ) == nil ) then DMG_BLAST_SURFACE = 134217728 end
if ( rawget( _G, "DMG_DIRECT" ) == nil ) then DMG_DIRECT = 268435456 end
if ( rawget( _G, "DMG_BUCKSHOT" ) == nil ) then DMG_BUCKSHOT = 536870912 end

------------------------------------------------------------------------------
-- Entity:GetViewEntity() - GMod: the entity a player looks through (the
-- player itself in first person).  The fork has no binding for it, and
-- addons use it for billboard text (hitnumbers draws its damage numbers
-- facing "the entity the local player looks through"), so a missing method
-- killed the whole draw hook every frame.
-- Without engine view-entity tracking the correct first-person default is
-- the player itself, which is what every stock consumer needs.
------------------------------------------------------------------------------
if ( FindMetaTable ~= nil ) then
	local ENTITY_META = FindMetaTable( "Entity" )
	
	if ( ENTITY_META ~= nil and ENTITY_META.GetViewEntity == nil ) then
		function ENTITY_META:GetViewEntity()
			return self
		end
	end
end

------------------------------------------------------------------------------
-- Panel:AddControl( type, data ) - the GMod DForm spellings addons use to
-- populate spawnmenu tool panels (spawnmenu.AddToolMenuOption callbacks).
-- HL2SB's control panels are plain Panel userdata, so this maps the common
-- control types onto derma children.  Command accepts a string or a table of
-- strings, exactly like GMod.
------------------------------------------------------------------------------
if ( FindMetaTable ~= nil ) then
	local PANEL_META = FindMetaTable( "Panel" )

	if ( PANEL_META ~= nil and PANEL_META.AddControl == nil ) then
		function PANEL_META:AddControl( controlType, data )

			data = data or {}

			local function isString( v ) return type( v ) == "string" end
			local function isTable( v ) return type( v ) == "table" end

			local function buildCommandHandler( pnl )
				local commands = data.Command
				if ( isString( commands ) ) then
					commands = { commands }
				end

				if ( isTable( commands ) ) then
					function pnl:DoClick()
						for _, cmd in ipairs( commands ) do
							RunConsoleCommand( cmd )
						end
					end
				end
			end

			if ( vgui == nil or vgui.Create == nil ) then return nil end

			if ( controlType == "Button" ) then
				local btn = vgui.Create( "DButton", self )
				btn:SetText( data.Label or data.Text or "" )
				btn:Dock( TOP )
				buildCommandHandler( btn )
				return btn

			elseif ( controlType == "CheckBox" ) then
				local chk = vgui.Create( "DCheckBoxLabel", self )
				chk:SetText( data.Label or "" )
				chk:Dock( TOP )
				if ( isString( data.ConVar ) ) then chk:SetConVar( data.ConVar ) end
				return chk

			elseif ( controlType == "Slider" ) then
				local slider = vgui.Create( "DNumSlider", self )
				slider:SetText( data.Label or "" )
				slider:Dock( TOP )
				if ( data.min ~= nil ) then slider:SetMin( data.min ) end
				if ( data.max ~= nil ) then slider:SetMax( data.max ) end
				if ( data.decimal ~= nil ) then slider:SetDecimals( data.decimal ) end
				if ( isString( data.Command ) ) then slider:SetConVar( data.Command ) end
				return slider

			elseif ( controlType == "Header" ) then
				local header = vgui.Create( "DLabel", self )
				header:SetText( data.Description or data.Text or data.Label or "" )
				header:Dock( TOP )
				return header
			end

			return nil
		end
	end
end

------------------------------------------------------------------------------
-- EF_* / MOVETYPE_* globals (2026-09-29): GMod publishes these engine bit
-- enums as plain globals; HL2SB publishes the MEMBER VALUES only into
-- _E.<lib> (END_LUA_SET_ENUM_LIB writes _E[lib] = table and does NOT set a
-- global of that name) plus flat <lib>_<member> globals (MOVE_TYPE_NONE,
-- ENTITY_EFFECT_BONE_MERGE) -- never GMod's own spellings MOVETYPE_NONE /
-- EF_BONEMERGE.  Addon code written against GMod (gmod_hands.lua's
-- SetMoveType( MOVETYPE_NONE ), AddEffects( EF_BONEMERGE or BONE_MERGE ),
-- ...) therefore read nil, error mid-function and silently skip the rest of
-- the setup: gmod_hands aborted AT SetMoveType, so movetype stayed non-NONE,
-- IsFollowingEntity() was false, bone merge never ran, and the arms drew in
-- bind pose at the spawn point (feet) -- visible only when the pitch put
-- that spot in frustum.  Alias every member to its GMod global name here.
-- Second iteration: gate on _E.<lib> (NOT on _G.<lib>, which does not exist).
------------------------------------------------------------------------------

local _E = rawget( _G, "_E" ) or {}
local _EFF = rawget( _G, "EF" ) or _E.ENTITY_EFFECT or _E.EF
if ( _EFF ~= nil ) then
	if ( rawget( _G, "EF_BONEMERGE" ) == nil ) then EF_BONEMERGE = _EFF.BONE_MERGE end
	if ( rawget( _G, "EF_BONEMERGE_FASTCULL" ) == nil ) then EF_BONEMERGE_FASTCULL = _EFF.BONE_MERGE_FAST_CULL end
	if ( rawget( _G, "EF_BRIGHTLIGHT" ) == nil ) then EF_BRIGHTLIGHT = _EFF.BRIGHT_LIGHT end
	if ( rawget( _G, "EF_DIMLIGHT" ) == nil ) then EF_DIMLIGHT = _EFF.DIM_LIGHT end
	if ( rawget( _G, "EF_NOINTERP" ) == nil ) then EF_NOINTERP = _EFF.NO_INTERPOLATE end
	if ( rawget( _G, "EF_NOSHADOW" ) == nil ) then EF_NOSHADOW = _EFF.NO_SHADOW end
	if ( rawget( _G, "EF_NODRAW" ) == nil ) then EF_NODRAW = _EFF.NO_DRAW end
	if ( rawget( _G, "EF_NORECEIVESHADOW" ) == nil ) then EF_NORECEIVESHADOW = _EFF.NO_RECEIVE_SHADOW end
	if ( rawget( _G, "EF_ITEM_BLINK" ) == nil ) then EF_ITEM_BLINK = _EFF.ITEM_BLINK end
	if ( rawget( _G, "EF_PARENT_ANIMATES" ) == nil ) then EF_PARENT_ANIMATES = _EFF.PARENT_ANIMATES end
end

local _MT = rawget( _G, "MOVETYPE" ) or _E.MOVE_TYPE or _E.MOVETYPE
if ( _MT ~= nil ) then
	if ( rawget( _G, "MOVETYPE_NONE" ) == nil ) then MOVETYPE_NONE = _MT.NONE end
	if ( rawget( _G, "MOVETYPE_ISOMETRIC" ) == nil ) then MOVETYPE_ISOMETRIC = _MT.ISOMETRIC end
	if ( rawget( _G, "MOVETYPE_WALK" ) == nil ) then MOVETYPE_WALK = _MT.WALK end
	if ( rawget( _G, "MOVETYPE_STEP" ) == nil ) then MOVETYPE_STEP = _MT.STEP end
	if ( rawget( _G, "MOVETYPE_FLY" ) == nil ) then MOVETYPE_FLY = _MT.FLY end
	if ( rawget( _G, "MOVETYPE_FLYGRAVITY" ) == nil ) then MOVETYPE_FLYGRAVITY = _MT.FLY_GRAVITY end
	if ( rawget( _G, "MOVETYPE_VPHYSICS" ) == nil ) then MOVETYPE_VPHYSICS = _MT.VPHYSICS end
	if ( rawget( _G, "MOVETYPE_PUSH" ) == nil ) then MOVETYPE_PUSH = _MT.PUSH end
	if ( rawget( _G, "MOVETYPE_NOCLIP" ) == nil ) then MOVETYPE_NOCLIP = _MT.NOCLIP end
	if ( rawget( _G, "MOVETYPE_LADDER" ) == nil ) then MOVETYPE_LADDER = _MT.LADDER end
	if ( rawget( _G, "MOVETYPE_OBSERVER" ) == nil ) then MOVETYPE_OBSERVER = _MT.OBSERVER end
	if ( rawget( _G, "MOVETYPE_CUSTOM" ) == nil ) then MOVETYPE_CUSTOM = _MT.CUSTOM end
	if ( rawget( _G, "MOVETYPE_LAST" ) == nil ) then MOVETYPE_LAST = _MT.LAST end
end

------------------------------------------------------------------------------
-- RENDERGROUP_* globals (2026-09-29): same story as EF_*/MOVETYPE_* -- GMod
-- publishes them as globals, HL2SB had none, so `ENT.RenderGroup =
-- RENDERGROUP_TRANSLUCENT` (sent_ball) silently assigned nil and every
-- scripted entity rendered in the default opaque group.  Values transcribed
-- from public/engine/IClientLeafSystem.h RenderGroup_t (this engine's own
-- numbering, which is what CBaseScripted::GetRenderGroup compares against):
--   OPAQUE_STATIC_HUGE=0, OPAQUE_ENTITY_HUGE=1, OPAQUE_STATIC=6,
--   OPAQUE_ENTITY=7, TRANSLUCENT_ENTITY=8, TWOPASS=9,
--   VIEW_MODEL_OPAQUE=10, VIEW_MODEL_TRANSLUCENT=11, OPAQUE_BRUSH=12,
--   OTHER=13.
------------------------------------------------------------------------------

if ( rawget( _G, "RENDERGROUP_STATIC" ) == nil ) then RENDERGROUP_STATIC = 0 end
if ( rawget( _G, "RENDERGROUP_OPAQUE" ) == nil ) then RENDERGROUP_OPAQUE = 7 end
if ( rawget( _G, "RENDERGROUP_TRANSLUCENT" ) == nil ) then RENDERGROUP_TRANSLUCENT = 8 end
if ( rawget( _G, "RENDERGROUP_TWOPASS" ) == nil ) then RENDERGROUP_TWOPASS = 9 end
if ( rawget( _G, "RENDERGROUP_VIEWMODEL" ) == nil ) then RENDERGROUP_VIEWMODEL = 10 end
if ( rawget( _G, "RENDERGROUP_OTHER" ) == nil ) then RENDERGROUP_OTHER = 13 end

------------------------------------------------------------------------------
-- MATERIAL_CULLMODE_* globals (2026-10-02): GMod publishes them as globals for
-- render.CullMode (GM:PostDrawViewModel flips to CW around hands:DrawModel for
-- ViewModelFlip weapons).  Values = this engine's MaterialCullMode_t
-- (public/materialsystem/imaterialsystem.h: CCW=0, CW=1).
------------------------------------------------------------------------------

if ( rawget( _G, "MATERIAL_CULLMODE_CCW" ) == nil ) then MATERIAL_CULLMODE_CCW = 0 end
if ( rawget( _G, "MATERIAL_CULLMODE_CW" ) == nil ) then MATERIAL_CULLMODE_CW = 1 end

------------------------------------------------------------------------------
-- vector_origin / angle_zero globals (2026-10-02): GMod exposes both as
-- constants; gmod_hands.lua uses them verbatim (AttachToViewmodel, OnRemove).
------------------------------------------------------------------------------

if ( rawget( _G, "vector_origin" ) == nil ) then vector_origin = Vector( 0, 0, 0 ) end
if ( rawget( _G, "angle_zero" ) == nil ) then angle_zero = QAngle( 0, 0, 0 ) end

------------------------------------------------------------------------------
-- HUD_PRINT_* globals: GMod publishes the Entity:PrintMessage routing types
-- as globals.  hitnumbers' client toggle passes HUD_PRINTTALK verbatim, and
-- with the enum undefined the whole concommand died on a bad argument.
------------------------------------------------------------------------------

if ( rawget( _G, "HUD_PRINTNOTIFY" ) == nil ) then HUD_PRINTNOTIFY = 1 end
if ( rawget( _G, "HUD_PRINTCONSOLE" ) == nil ) then HUD_PRINTCONSOLE = 2 end
if ( rawget( _G, "HUD_PRINTTALK" ) == nil ) then HUD_PRINTTALK = 3 end
if ( rawget( _G, "HUD_PRINTCENTER" ) == nil ) then HUD_PRINTCENTER = 4 end
