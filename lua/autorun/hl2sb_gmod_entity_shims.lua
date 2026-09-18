--[[----------------------------------------------------------------------------
    hl2sb_gmod_entity_shims.lua

    GMod Entity methods this fork does not have, added where an addon needs them.
    Shared (lua/autorun) on purpose: the cod_c4 entity declares its dynamic variables
    on the SERVER (its init.lua runs there), while DrawWorldModel runs on the client.

    Everything here follows the GMod wiki:
      Entity:DTVar( type, slot, name ) + SetDT<Type> / GetDT<Type> (five types)
          "Creates a dynamic variable ... networked"; the accessors take either the slot
          id or the declared name.  This fork has no dvar system, but it already keeps a
          per-entity NW store (SetNWFloat/SetNWInt/SetNWBool/SetNWString/SetNWEntity in
          game/shared/lua/lbaseentity_shared.cpp), so the declarations are recorded here
          and the values live in that store.
      Entity:SetRenderOrigin / SetRenderAngles
          "Sets the render origin of the entity. This does not affect the actual
          position."  This engine draws a C_BaseAnimating from its own origin, so the
          values are stored AND applied through SetAbsOrigin/SetAbsAngles - that is
          what the visible result needs, and the getters answer the stored values.
          (Deviation recorded here; the alternative is a client-entity member, i.e. a
          header change, which this fork only does when it must.)
--]]----------------------------------------------------------------------------

local EntityMeta = FindMetaTable( "Entity" )

if ( EntityMeta == nil ) then return end

-- ---------------------------------------------------------------------------
-- DTVar
-- ---------------------------------------------------------------------------
if ( EntityMeta.SetDTFloat == nil ) then
	-- GMod's dynamic variables are five typed, INDEXED slots
	-- (lua/includes/extensions/entity.lua:255-295 - `ent[ "SetDT" .. typename ]`).
	--
	-- ⚠️ The accessor contract, verbatim from the GMod wiki (Entity.SetDTFloat):
	-- "Key can be a string that corresponds to the name of the DTVar given at creation,
	-- or an integer indicating the ID" - so BOTH forms have to work.
	--
	-- ⚠️ cod_c4 calls SetDTFloat the moment its entity is created (init.lua:41-42) and
	-- never declares anything first: a name-keyed-only shim still left planting a C4
	-- raising "attempt to call a nil value (method 'SetDTFloat')".
	--
	-- This fork has no dvar system, so the values live in the per-entity NW store under a
	-- type+index key - networked to clients exactly like GMod's DTVars
	-- (GMod's own matproxy/sky_paint.lua:25 reads GetDTBool( 0 ) on the client).
	local DTVarTypes = {
		Bool   = { set = "SetNWBool",   get = "GetNWBool" },
		Float  = { set = "SetNWFloat",  get = "GetNWFloat" },
		Int    = { set = "SetNWInt",    get = "GetNWInt" },
		String = { set = "SetNWString", get = "GetNWString" },
		Entity = { set = "SetNWEntity", get = "GetNWEntity" },
	}

	local Declared = setmetatable( {}, { __mode = "k" } )	-- [ ent ] = { [ name ] = { type, index } }
	local Slots = setmetatable( {}, { __mode = "k" } )	-- [ ent ] = { [ type ] = { [ index ] = name } }

	local function SlotKey( strType, key )
		return "dvar_" .. strType .. "_" .. tostring( key )
	end

	--- A number is the slot id; a string is the name the slot was declared under (and an
	--- undeclared name gets its own storage, which is what GMod does too - the
	--- declaration only exists to name the slot).
	local function Resolve( ent, strType, key )
		local t = Declared[ ent ]

		if ( type( key ) ~= "number" and t ~= nil and t[ key ] ~= nil ) then
			return SlotKey( strType, t[ key ].index )
		end

		return SlotKey( strType, ( type( key ) == "number" ) and math.floor( key ) or key )
	end

	-- -----------------------------------------------------------------------
	-- HL2SB: GMod's Entity.dt accessor (self.dt.blockID etc.).  The proxy
	-- resolves declared DTVar names through the same NW store the SetDT/GetDT
	-- methods use.  Attached to the entity (and the SetupDataTables script
	-- table) the first time a DTVar is declared, which happens before any
	-- script code can reach for .dt.
	-- -----------------------------------------------------------------------
	local dtProxies = setmetatable( {}, { __mode = "k" } )

	-- HL2SB: resolve the ENTITY a proxy belongs to.  SetupDataTables hands the
	-- declaration the entity's SCRIPT TABLE (self = the class-table copy), so
	-- the proxy closures capture that table -- and indexing the TABLE for
	-- "SetNWInt"/"GetNWInt" answered nil (those live on the entity metatable),
	-- which raised "attempt to call a nil value (field '?')" from
	-- DTProxySet.  The table carries .Entity (the engine sets it before
	-- SetupDataTables runs), so go through it.
	local function DTResolveEntity( owner )
		if ( type( owner ) == "table" ) then
			return owner.Entity
		end
		return owner
	end

	local function DTProxyGet( owner, k )
		local d = Declared[ owner ] and Declared[ owner ][ k ]
		if ( d == nil ) then return nil end
		local ent = DTResolveEntity( owner )
		if ( ent == nil ) then return nil end
		return ent[ DTVarTypes[ d.type ].get ]( ent, d.index )
	end

	local function DTProxySet( owner, k, v )
		local d = Declared[ owner ] and Declared[ owner ][ k ]
		if ( d == nil ) then return nil end
		local ent = DTResolveEntity( owner )
		if ( ent == nil ) then return nil end
		return ent[ DTVarTypes[ d.type ].set ]( ent, d.index, v )
	end

	--- The declaration bookkeeping, shared by the entity method and by the table-level entry
	--- point below (the engine hands SetupDataTables the entity's Lua TABLE, not the entity).
	local function Declare( self, strType, nIndex, strName )
		strType = tostring( strType or "Float" )

		-- GMod: DTVar( "Float", "charge" ) picks the first free slot
		if ( type( nIndex ) == "string" and strName == nil ) then strName, nIndex = nIndex, nil end

		local t = Declared[ self ]
		if ( t == nil ) then t = {}; Declared[ self ] = t end

		local s = Slots[ self ]
		if ( s == nil ) then s = {}; Slots[ self ] = s end
		s[ strType ] = s[ strType ] or {}

		if ( nIndex == nil ) then
			nIndex = 0
			while ( s[ strType ][ nIndex ] ~= nil ) do nIndex = nIndex + 1 end
		else
			nIndex = math.floor( tonumber( nIndex ) or 0 )
		end

		if ( strName ~= nil ) then t[ strName ] = { type = strType, index = nIndex } end
		s[ strType ][ nIndex ] = strName or nIndex

		-- HL2SB: expose GMod's Entity.dt accessor (self.dt.blockID etc.).
		-- SetupDataTables runs with the script table as self and that table
		-- carries .Entity, so the proxy reaches both identities.
		local proxy = dtProxies[ self ]
		if ( proxy == nil ) then
			proxy = {}
			dtProxies[ self ] = proxy
			setmetatable( proxy, {
				__index    = function( _, k ) return DTProxyGet( self, k ) end,
				__newindex = function( _, k, v ) DTProxySet( self, k, v ) end,
			} )
			if ( type( self ) == "table" ) then
				rawset( self, "dt", proxy )
			else
				self.dt = proxy
			end
			local entRef = rawget( self, "Entity" )
			if ( entRef ~= nil and entRef ~= self and dtProxies[ entRef ] == nil ) then
				dtProxies[ entRef ] = proxy
				entRef.dt = proxy
			end
		end

		-- GMod answers the descriptor (SetupEditing / properties use it).
		return { index = nIndex, name = strName, typename = strType, Notify = {} }
	end

	function EntityMeta:DTVar( strType, nIndex, strName )
		return Declare( self, strType, nIndex, strName )
	end

	-- ⚠️ SetupDataTables() runs with the entity's LUA TABLE as self
	-- (game/shared/lua/basescripted.cpp:249 - "self: the entity's Lua table"), not with the
	-- entity userdata, so a method that exists only on the entity metatable is invisible
	-- there.  The engine copies this global onto that table, exactly like it already does for
	-- NetworkVar / NetworkVarNotify (basescripted.cpp:226-244).  cod_c4's
	-- ENT:SetupDataTables calls self:DTVar( "Float", 0, ... ) and raised
	-- "attempt to call a nil value (method 'DTVar')" on every C4 spawn before this existed
	-- (logged in D:\srceng\hl2sb\ds_debug.log:19986).
	function HL2SB_EntityDTVar( tbl, strType, nIndex, strName )
		return Declare( tbl, strType, nIndex, strName )
	end

	function EntityMeta:IsDTVarSlotUsed( strType, nIndex )
		local s = Slots[ self ]

		if ( s == nil or s[ strType ] == nil ) then return false end

		return s[ strType ][ math.floor( tonumber( nIndex ) or 0 ) ] ~= nil
	end

	for strType, t in pairs( DTVarTypes ) do
		EntityMeta[ "SetDT" .. strType ] = function( self, key, value )
			if ( self[ t.set ] == nil ) then return end

			if ( strType == "Int" ) then value = math.floor( tonumber( value ) or 0 )
			elseif ( strType == "Float" ) then value = tonumber( value ) or 0
			elseif ( strType == "Bool" ) then value = value and true or false
			elseif ( strType == "String" ) then value = tostring( value ) end

			self[ t.set ]( self, Resolve( self, strType, key ), value )
		end

		EntityMeta[ "GetDT" .. strType ] = function( self, key )
			if ( self[ t.get ] == nil ) then return nil end

			return self[ t.get ]( self, Resolve( self, strType, key ) )
		end
	end

	-- HL2SB extra (GMod has no such pair): read/write by the name given to DTVar.
	function EntityMeta:SetDTVar( strName, value )
		local t = Declared[ self ]

		if ( t == nil or t[ strName ] == nil ) then return end

		EntityMeta[ "SetDT" .. t[ strName ].type ]( self, t[ strName ].index, value )
	end

	function EntityMeta:GetDTVar( strName )
		local t = Declared[ self ]

		if ( t == nil or t[ strName ] == nil ) then return nil end

		return EntityMeta[ "GetDT" .. t[ strName ].type ]( self, t[ strName ].index )
	end

	Msg( "[HL2SB]   Entity:DTVar + SetDT/GetDT (Bool/Float/Int/String/Entity) added (NW store)\n" )
end

-- ---------------------------------------------------------------------------
-- render origin / angles
-- ---------------------------------------------------------------------------
if ( EntityMeta.SetRenderOrigin == nil ) then
	function EntityMeta:SetRenderOrigin( v )
		if ( v == nil ) then return end

		self.m_vHL2SBRenderOrigin = v

		if ( self.SetAbsOrigin ) then self:SetAbsOrigin( v ) end
	end

	function EntityMeta:GetRenderOrigin()
		return self.m_vHL2SBRenderOrigin or self:GetAbsOrigin()
	end

	function EntityMeta:SetRenderAngles( a )
		if ( a == nil ) then return end

		self.m_aHL2SBRenderAngles = a

		if ( self.SetAbsAngles ) then self:SetAbsAngles( a ) end
	end

	function EntityMeta:GetRenderAngles()
		return self.m_aHL2SBRenderAngles or self:GetAbsAngles()
	end

	Msg( "[HL2SB]   Entity:SetRenderOrigin / SetRenderAngles added (applied as Abs*)\n" )
end

-- ---------------------------------------------------------------------------
-- deploy speed (a SWEP method in GMod; the weapon IS an entity, so it lives here and is
-- available on both realms)
--
-- GMod wiki: SWEP:SetDeploySpeed( speed ) -- "Sets the deploy speed of the weapon."
-- The cod_c4 SWEP sets 1 in Initialize and again in Deploy ("something keeps setting
-- deploy speed to 4, this is a workaround").  This fork's weapon_base has no deploy-speed
-- concept, so the value is kept on the entity and read back with GetDeploySpeed(); 1 is
-- the normal speed, i.e. the addon's calls are a no-op in the visible sense.
-- ---------------------------------------------------------------------------
if ( EntityMeta.SetDeploySpeed == nil ) then
	-- GMod: SWEP.DeploySpeed is a FIELD on the weapon table ("SWEP.DeploySpeed = 1.4",
	-- terrortown/entities/weapons/weapon_tttbase.lua:120) and SetDeploySpeed is the method
	-- that consumes it.  ⚠️ Do NOT mirror the value onto self.DeploySpeed: an instance
	-- field shadows the DeploySpeed() method of this metatable, so the next
	-- `self:DeploySpeed( speed )` would try to call a number.
	function EntityMeta:SetDeploySpeed( flSpeed )
		self.m_flHL2SBDeploySpeed = tonumber( flSpeed ) or 1
	end

	function EntityMeta:GetDeploySpeed()
		return self.m_flHL2SBDeploySpeed or 1
	end

	-- GMod's weapon_base exposes the same thing as SWEP:DeploySpeed( speed ).
	function EntityMeta:DeploySpeed( flSpeed )
		if ( flSpeed ~= nil ) then self:SetDeploySpeed( flSpeed ) end

		return self:GetDeploySpeed()
	end

	Msg( "[HL2SB]   Entity:SetDeploySpeed / GetDeploySpeed / DeploySpeed added\n" )
end
