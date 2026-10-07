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
-- GMod's Angle constructor.  This engine publishes the same thing as QAngle
-- (public/lua/mathlib/lvector.cpp QAngle_funcs); GMod scripts -- env_skypaint's
-- siblings, the sky editor family -- spell it Angle( p, y, r ).
-- ---------------------------------------------------------------------------
if ( Angle == nil and QAngle != nil ) then
	Angle = QAngle
	Msg( "[HL2SB]   Angle() global added (QAngle alias)\n" )
end

-- ---------------------------------------------------------------------------
-- DTVar
-- ---------------------------------------------------------------------------
if ( EntityMeta.SetDTFloat == nil ) then
	-- GMod's dynamic variables are five typed, INDEXED slots
	-- (lua/includes/extensions/entity.lua:255-295 - `ent[ "SetDT" .. typename ]`).
	--
	-- The accessor contract, verbatim from the GMod wiki (Entity.SetDTFloat):
	-- "Key can be a string that corresponds to the name of the DTVar given at creation,
	-- or an integer indicating the ID" - so BOTH forms have to work.
	--
	-- cod_c4 calls SetDTFloat the moment its entity is created (init.lua:41-42) and
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

	-- -----------------------------------------------------------------------
	-- HL2SB (2026-10-08): engine NetworkVar declarations.  The engine's
	-- HL2SB_EntityNetworkVar (basescripted seeds it as self:NetworkVar) is
	-- the REPLICATING store (six types incl. Vector/Angle, per-entity keys,
	-- local-first client reads) -- env_skypaint declares its whole palette
	-- through it, and GMod's matproxy/sky_paint.lua then reads the values
	-- back by SLOT with GetDTVector( 0 ) / GetDTFloat( 2 ) / GetDTBool( 0 ).
	-- Record every engine declaration so the SetDT/GetDT accessors below
	-- route engine-declared slots to their generated Get<Name>/Set<Name>,
	-- and so the KeyName option (map keyvalues -> variable) is kept.
	-- -----------------------------------------------------------------------
	local EngineNWFlag = setmetatable( {}, { __mode = "k" } )	-- [ tbl ] = { [ name ] = true }
	local EngineNWKey  = setmetatable( {}, { __mode = "k" } )	-- [ tbl ] = { [ lower keyname ] = name }
	local EngineNWName = setmetatable( {}, { __mode = "k" } )	-- [ tbl ] = { [ lower name ] = name }
	local ElementOrder = setmetatable( {}, { __mode = "k" } )	-- [ tbl ] = { [ "Angle_0" ] = { { component, name }, ... } }

	-- entity userdata -> its instance table (registries are keyed on the
	-- table SetupDataTables ran with; consumers hold the entity).
	-- HL2SB (2026-10-08): this engine's type() answers a userdata's METATABLE
	-- __type word ("entity"/"Player"/...), never the plain-Lua "userdata" --
	-- the old type(self) == "userdata" probe was false for EVERY entity and
	-- the whole instance-table layer here answered nil (the painted-sky map
	-- keyvalues were all rejected with "no instance table").  Gate on not
	-- being one of the plain Lua types instead.
	local function EngineTable( self )
		local t = type( self )
		if ( t == "table" ) then return self end
		if ( t != "nil" and t != "boolean" and t != "string" and t != "number"
			and t != "table" and t != "function" and self.GetTable != nil ) then
			return self:GetTable()
		end
		return nil
	end

	local function RecordEngineNW( tbl, strType, nIndex, strName, options )
		Declare( tbl, strType, nIndex, strName )

		local f = EngineNWFlag[ tbl ]
		if ( f == nil ) then f = {} EngineNWFlag[ tbl ] = f end
		f[ strName ] = true

		local k = EngineNWKey[ tbl ]
		if ( k == nil ) then k = {} EngineNWKey[ tbl ] = k end
		local n = EngineNWName[ tbl ]
		if ( n == nil ) then n = {} EngineNWName[ tbl ] = n end
		n[ string.lower( strName ) ] = strName
		if ( type( options ) == "table" and type( options.KeyName ) == "string" and options.KeyName != "" ) then
			k[ string.lower( options.KeyName ) ] = strName
		end
	end

	-- The registered engine name for a (type, key) slot, nil when the slot
	-- was not declared through the engine NetworkVar.
	local function ResolveEngineNW( self, strType, key )
		local t = EngineTable( self )
		if ( t == nil ) then return nil end

		local f = EngineNWFlag[ t ]
		if ( f == nil ) then return nil end

		local d = Declared[ t ]
		if ( type( key ) == "number" ) then
			local idx = math.floor( key )
			for n, dd in pairs( d or {} ) do
				if ( f[ n ] and dd.type == strType and dd.index == idx ) then return n end
			end
		else
			local name
			if ( d != nil and d[ key ] != nil and f[ key ] ) then
				name = key
			end
			if ( name == nil ) then
				local k = EngineNWKey[ t ]
				name = ( k != nil ) and k[ string.lower( tostring( key ) ) ] or nil
			end
			if ( name != nil and f[ name ] != nil ) then
				-- the stored name wins when the case differs
				local n = EngineNWName[ t ]
				return ( n != nil ) and ( n[ string.lower( name ) ] or name ) or name
			end
		end
		return nil
	end

	-- self:NetworkVar( type, slot, name [, options] ): keep the engine call
	-- (it builds the replicated accessors) and record the declaration.
	-- basescripted seeds whatever HL2SB_EntityNetworkVar holds at bind time,
	-- so a wrapped global reaches every SetupDataTables call.
	local EngineNWOriginal = HL2SB_EntityNetworkVar
	HL2SB_EntityNetworkVar = function( tbl, strType, nIndex, strName, options )
		if ( EngineNWOriginal != nil ) then
			EngineNWOriginal( tbl, strType, nIndex, strName )
		end
		RecordEngineNW( tbl, tostring( strType or "Float" ), math.floor( tonumber( nIndex ) or 0 ), tostring( strName ), options )
	end

	-- self:NetworkVarElement( type, slot, component, name [, options] ):
	-- GMod packs several named elements into ONE typed slot (env_skypaint
	-- stores StarScale/StarFade/StarSpeed as the p/y/r of Angle slot 0).
	-- This fork keeps each element as its own replicated Float variable and
	-- composes the slot on access -- GetDTAngle( 0 ) assembles the Angle,
	-- SetDTAngle( 0 ) distributes it back.  Observable contract matches.
	HL2SB_EntityNetworkVarElement = function( tbl, strType, iSlot, strComponent, strName, options )
		strType = tostring( strType or "Angle" )
		iSlot = math.floor( tonumber( iSlot ) or 0 )

		local t = ElementOrder[ tbl ]
		if ( t == nil ) then t = {} ElementOrder[ tbl ] = t end
		local slotKey = strType .. "_" .. tostring( iSlot )
		local list = t[ slotKey ]
		if ( list == nil ) then list = {} t[ slotKey ] = list end

		if ( EngineNWOriginal != nil ) then
			EngineNWOriginal( tbl, "Float", iSlot, strName )
		end
		-- Recorded at sentinel slot -1: the element is addressed BY NAME only
		-- (the composed GetDTAngle/SetDTAngle below and its own accessors) and
		-- must never answer a numeric Float slot -- GMod keeps the elements in
		-- the ANGLE slot, so Float slot <iSlot> stays free for real variables.
		RecordEngineNW( tbl, "Float", -1, strName, options )
		list[ #list + 1 ] = { component = tostring( strComponent ), name = tostring( strName ) }

		return { index = iSlot, name = strName, typename = strType }
	end

	function EntityMeta:DTVar( strType, nIndex, strName )
		return Declare( self, strType, nIndex, strName )
	end

	-- SetupDataTables() runs with the entity's LUA TABLE as self
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

	-- HL2SB (2026-10-08): Vector and Angle join the loop for the SLOT
	-- bookkeeping; this engine has no SetNWVector/GetNWVector, so an
	-- undeclared Vector/Angle DTVar answers nil instead of erroring, and an
	-- ENGINE-declared one (env_skypaint) routes through its replicated
	-- accessors below.
	DTVarTypes.Vector = { set = "SetNWVector", get = "GetNWVector" }
	DTVarTypes.Angle  = { set = "SetNWAngle",  get = "GetNWAngle" }

	-- HL2SB: last-resort slot -> accessor-name map for the painted-sky
	-- driver.  env_skypaint.lua (GMod verbatim) declares exactly this layout,
	-- so when the per-table engine records are unreachable on a realm the
	-- fixed names still reach the replicated accessors.  Read-only: SetDT*
	-- keeps the registry route.
	EngineFixedSlotNames = {
		Vector = { [0] = "TopColor", [1] = "BottomColor", [2] = "SunNormal", [3] = "SunColor", [4] = "DuskColor" },
		Float  = { [0] = "FadeBias", [1] = "HDRScale", [2] = "DuskScale", [3] = "DuskIntensity", [4] = "SunSize" },
		Bool   = { [0] = "DrawStars" },
		Int    = { [0] = "StarLayers" },
		String = { [0] = "StarTexture" },
		Angle  = {},
	}

	for strType, t in pairs( DTVarTypes ) do
		EntityMeta[ "SetDT" .. strType ] = function( self, key, value )
			-- engine-declared slot: the replicated accessor owns the value
			local nm = ResolveEngineNW( self, strType, key )
			if ( nm != nil ) then
				local f = self[ "Set" .. nm ]
				if ( f != nil ) then return f( self, value ) end
				return
			end

			if ( self[ t.set ] == nil ) then return end

			if ( strType == "Int" ) then value = math.floor( tonumber( value ) or 0 )
			elseif ( strType == "Float" ) then value = tonumber( value ) or 0
			elseif ( strType == "Bool" ) then value = value and true or false
			elseif ( strType == "String" ) then value = tostring( value ) end

			self[ t.set ]( self, Resolve( self, strType, key ), value )
		end

		EntityMeta[ "GetDT" .. strType ] = function( self, key )
			local nm = ResolveEngineNW( self, strType, key )
			if ( nm != nil ) then
				local f = self[ "Get" .. nm ]
				if ( f != nil ) then return f( self ) end
				return nil
			end

			-- HL2SB: last-resort fixed-name fallback for the painted-sky
			-- driver (env_skypaint's GMod-verbatim declaration order below);
			-- keeps GetDT* answering even if the per-table engine records
			-- were not reached on this realm.
			local fixed = EngineFixedSlotNames[ strType ]
			local nm2 = ( fixed != nil ) and fixed[ math.floor( tonumber( key ) or -1 ) ] or nil
			if ( nm2 != nil ) then
				local f = self[ "Get" .. nm2 ]
				if ( f != nil ) then return f( self ) end
			end

			if ( self[ t.get ] == nil ) then return nil end

			return self[ t.get ]( self, Resolve( self, strType, key ) )
		end
	end

	-- HL2SB (2026-10-08): Vector slots answer GMod's never-nil getter
	-- contract.  Route engine-declared slots to their replicated accessors;
	-- everything else falls through the NW store and finally to a zero
	-- vector.  A nil here made GMod's matproxy/sky_paint.lua throw
	-- "bad argument #2 to 'SetVector' (Vector expected, got nil)" on every
	-- painted-sky bind -- and each of those pcall errors underflowed the
	-- shared client Lua stack by one slot (the flagr abort).
	local s_bVectorMissLogged = false
	EntityMeta.GetDTVector = function( self, key )
		local nm = ResolveEngineNW( self, "Vector", key )
		if ( nm != nil ) then
			local f = self[ "Get" .. nm ]
			if ( f != nil ) then
				local v = f( self )
				if ( v != nil ) then return v end
			end
		end

		local fixed = EngineFixedSlotNames.Vector[ math.floor( tonumber( key ) or -1 ) ]
		if ( fixed != nil ) then
			local f = self[ "Get" .. fixed ]
			if ( f != nil ) then
				local v = f( self )
				if ( v != nil ) then return v end
			end
		end

		if ( self.GetNWVector != nil ) then
			local v = self:GetNWVector( Resolve( self, "Vector", key ) )
			if ( v != nil ) then return v end
		end

		if ( !s_bVectorMissLogged ) then
			s_bVectorMissLogged = true
			local t = EngineTable( self )
			local f = ( t != nil ) and EngineNWFlag[ t ] or nil
			local d = ( t != nil ) and Declared[ t ] or nil
			local nRec = 0
			for _ in pairs( f or {} ) do nRec = nRec + 1 end
			Msg( string.format(
				"[HL2SB] GetDTVector miss: self=%s table=%s engineRecords=%d declared=%s hasGetTopColor=%s -> zero vector\n",
				tostring( self ), tostring( t ), nRec, tostring( d != nil ),
				tostring( t != nil and rawget( t, "GetTopColor" ) != nil ) ) )
		end
		return Vector( 0, 0, 0 )
	end

	-- HL2SB (2026-10-08): Angle slots compose their NetworkVarElement
	-- elements (see the shim above) -- GMod keeps one Angle networkvar and
	-- answers it whole from GetDTAngle( 0 ); the fork stores the elements
	-- separately and rebuilds the Angle here.
	EntityMeta.GetDTAngle = function( self, key )
		local t = EngineTable( self )
		local list = ( t != nil and ElementOrder[ t ] != nil )
			and ElementOrder[ t ][ "Angle_" .. tostring( math.floor( tonumber( key ) or 0 ) ) ]
			or nil

		if ( list != nil ) then
			local function comp( want )
				for _, e in pairs( list ) do
					if ( e.component == want ) then
						local f = self[ "Get" .. e.name ]
						if ( f != nil ) then return tonumber( f( self ) ) or 0 end
					end
				end
				return 0
			end
			return Angle( comp( "p" ), comp( "y" ), comp( "r" ) )
		end

		-- HL2SB: last-resort fixed names (env_skypaint's element order)
		if ( self.GetStarScale != nil and self.GetStarFade != nil and self.GetStarSpeed != nil ) then
			return Angle( self:GetStarScale(), self:GetStarFade(), self:GetStarSpeed() )
		end

		if ( self.GetNWAngle != nil ) then
			return self:GetNWAngle( Resolve( self, "Angle", key ) )
		end
		return Angle( 0, 0, 0 )
	end

	EntityMeta.SetDTAngle = function( self, key, ang )
		local t = EngineTable( self )
		local list = ( t != nil and ElementOrder[ t ] != nil )
			and ElementOrder[ t ][ "Angle_" .. tostring( math.floor( tonumber( key ) or 0 ) ) ]
			or nil

		if ( list != nil and isangle( ang ) ) then
			for _, e in pairs( list ) do
				local f = self[ "Set" .. e.name ]
				if ( f != nil ) then f( self, ang[ e.component ] ) end
			end
			return
		end

		if ( self.SetNWAngle != nil ) then self:SetNWAngle( Resolve( self, "Angle", key ), ang ) end
	end

	-- -----------------------------------------------------------------------
	-- HL2SB (2026-10-08): Entity:SetNetworkKeyValue( key, value ).  GMod maps
	-- a networkvar's KeyName option (or its own name) to the variable and
	-- answers true when one matched.  Map keyvalues arrive as strings, so
	-- parse per the declared type.  env_skypaint's ENT:KeyValue is the caller.
	-- -----------------------------------------------------------------------
	function EntityMeta:SetNetworkKeyValue( key, value )
		local t = EngineTable( self )
		if ( t == nil ) then
			return false
		end

		local f = EngineNWFlag[ t ]
		local d = Declared[ t ]
		if ( f == nil or d == nil ) then
			return false
		end

		local strKey = string.lower( tostring( key ) )
		local name = EngineNWKey[ t ] and EngineNWKey[ t ][ strKey ] or nil
		if ( name == nil ) then name = EngineNWName[ t ] and EngineNWName[ t ][ strKey ] or nil end
		if ( name == nil or f[ name ] == nil ) then
			return false
		end

		local rec = d[ name ]
		local setter = self[ "Set" .. name ]
		if ( rec == nil or setter == nil ) then
			return false
		end

		local v = value
		if ( type( value ) == "string" ) then
			if ( rec.type == "Vector" ) then
				local x, y, z = string.match( value, "^%s*([%-%d%.eE]+)%s+([%-%d%.eE]+)%s+([%-%d%.eE]+)%s*$" )
				v = Vector( tonumber( x ) or 0, tonumber( y ) or 0, tonumber( z ) or 0 )
			elseif ( rec.type == "Angle" ) then
				local p, y2, r = string.match( value, "^%s*([%-%d%.eE]+)%s+([%-%d%.eE]+)%s+([%-%d%.eE]+)%s*$" )
				v = Angle( tonumber( p ) or 0, tonumber( y2 ) or 0, tonumber( r ) or 0 )
			elseif ( rec.type == "Float" ) then
				v = tonumber( value ) or 0
			elseif ( rec.type == "Int" ) then
				v = math.floor( tonumber( value ) or 0 )
			elseif ( rec.type == "Bool" ) then
				v = ( tonumber( value ) or 0 ) != 0
			end
		end

		setter( self, v )
		return true
	end

	-- -----------------------------------------------------------------------
	-- HL2SB (2026-10-08): Entity:SetNetworkVarsFromMapInput( name, data ).
	-- GMod maps a "Set<NetworkVar>" map input onto the variable and answers
	-- true when one matched (which also keeps developer 2 quiet about the
	-- input).  env_skypaint's ENT:AcceptInput is the caller.
	-- -----------------------------------------------------------------------
	function EntityMeta:SetNetworkVarsFromMapInput( name, data )
		local strName = tostring( name or "" )
		if ( string.sub( strName, 1, 3 ) != "Set" or string.len( strName ) <= 3 ) then return false end

		local t = EngineTable( self )
		if ( t == nil ) then return false end

		local n = EngineNWName[ t ]
		local base = ( n != nil ) and ( n[ string.lower( string.sub( strName, 4 ) ) ] or string.sub( strName, 4 ) ) or string.sub( strName, 4 )

		return self:SetNetworkKeyValue( base, data )
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
	-- that consumes it.  Do NOT mirror the value onto self.DeploySpeed: an instance
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

-- ---------------------------------------------------------------------------
-- GMod's legacy "Networked" spellings for the NW store.  The engine binds
-- SetNWInt/GetNWInt/SetNWBool/GetNWBool/SetNWEntity/GetNWEntity/... ; GMod
-- keeps the pre-13 names (SetNetworkedInt, GetNetworkedBool, ...) as aliases
-- of the same functions, and older addons (portalgun's info_hpd_controller,
-- the SWEP LastPortal slot) use nothing else.
-- ---------------------------------------------------------------------------
if ( EntityMeta.SetNWInt != nil and EntityMeta.SetNetworkedInt == nil ) then
	local NWAliasTypes = { "Int", "Bool", "Float", "String", "Entity", "Vector", "Angle" }

	for _, t in pairs( NWAliasTypes ) do
		if ( EntityMeta[ "SetNW" .. t ] != nil ) then
			EntityMeta[ "SetNetworked" .. t ] = EntityMeta[ "SetNW" .. t ]
			EntityMeta[ "SetNetworked" .. string.lower( t ) ] = EntityMeta[ "SetNW" .. t ]
		end
		if ( EntityMeta[ "GetNW" .. t ] != nil ) then
			EntityMeta[ "GetNetworked" .. t ] = EntityMeta[ "GetNW" .. t ]
			EntityMeta[ "GetNetworked" .. string.lower( t ) ] = EntityMeta[ "GetNW" .. t ]
		end
	end

	Msg( "[HL2SB]   Entity:SetNetworked*/GetNetworked* aliases added\n" )
end

-- ---------------------------------------------------------------------------
-- CRecipientFilter short spellings.  The engine binds AddRecipientsByPVS /
-- AddRecipientsByPAS; GMod keeps the short forms AddPVS / AddPAS (the
-- portalgun's in-portal footsteps build their recipient filter with them).
-- ---------------------------------------------------------------------------
local RecipientFilterMeta = FindMetaTable( "CRecipientFilter" )
if ( RecipientFilterMeta != nil and RecipientFilterMeta.AddPVS == nil ) then
	if ( RecipientFilterMeta.AddRecipientsByPVS != nil ) then
		RecipientFilterMeta.AddPVS = RecipientFilterMeta.AddRecipientsByPVS
	end
	if ( RecipientFilterMeta.AddRecipientsByPAS != nil ) then
		RecipientFilterMeta.AddPAS = RecipientFilterMeta.AddRecipientsByPAS
	end
	Msg( "[HL2SB]   CRecipientFilter:AddPVS/AddPAS aliases added\n" )
end

-- ---------------------------------------------------------------------------
-- DynamicLight( index ) -> dlight table.  GMod's global drives CL_AllocDlight
-- from the fields an addon writes (Pos/r/g/b/Brightness/Decay/Size/DieTime/
-- Style).  This fork has no Lua dlight surface, so the answer is a plain
-- table: every write is accepted and dropped.  The one consumer in the addon
-- set (the portalgun's portal glow) is opt-in via portal_dynamic_light and
-- defaults OFF, so the degradation is invisible unless the user turns it on -
-- at which point portals simply have no dynamic light, instead of erroring
-- every Think.
-- ---------------------------------------------------------------------------
if ( _G.DynamicLight == nil ) then
	function DynamicLight( index )
		return { Pos = Vector( 0, 0, 0 ), r = 255, g = 255, b = 255,
			Brightness = 0, Decay = 0, Size = 0, DieTime = 0, Style = 0,
			MinLight = 0, style = 0, KeyBind = index }
	end
	Msg( "[HL2SB]   DynamicLight stub added (writes accepted, no light)\n" )
end

-- ---------------------------------------------------------------------------
-- Entity:GetShootPos.  GMod binds it on BOTH the Player and the NPC
-- metatable; this engine binds it on the Player metatable only
-- (CBasePlayer::Weapon_ShootPosition).  The hitnumbers addon traces melee
-- swings from NPC:GetShootPos (sv_hitdamagenumbers.lua:416) and dies with
-- "attempt to call a nil value (method 'GetShootPos')" the first time an NPC
-- clubs or slashes something.  Our NPCs answer EyePos from the Entity
-- metatable (CBaseCombatCharacter's shoot position derives from the eye
-- point), so alias it there -- player userdata carries their own metatable
-- and never reach this.
-- ---------------------------------------------------------------------------
if ( EntityMeta.GetShootPos == nil and EntityMeta.EyePos != nil ) then
	EntityMeta.GetShootPos = EntityMeta.EyePos
	Msg( "[HL2SB]   Entity:GetShootPos shim added (EyePos alias, non-player entities)\n" )
end

Msg( "[HL2SB] gmod entity shims loaded\n" )
