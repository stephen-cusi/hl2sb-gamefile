local meta = FindMetaTable( "Entity" )
if ( !meta ) then return end

function meta:GetVar( name, default )

	local Val = self:GetTable()[ name ]
	if ( Val == nil ) then return default end

	return Val

end

if ( SERVER ) then

	function meta:SetCreator( ply --[[= NULL]] )
		if ( ply == nil ) then
			ply = NULL
		elseif ( !isentity( ply ) ) then
			error( "bad argument #1 to 'SetCreator' (Entity expected, got " .. type( ply ) .. ")", 2 )
		end

		self.m_PlayerCreator = ply
	end

	function meta:GetCreator()
		return self.m_PlayerCreator or NULL
	end

end

--[[---------------------------------------------------------
	Name: Returns true if the entity has constraints attached to it
-----------------------------------------------------------]]
function meta:IsConstrained()

	if ( CLIENT ) then return self:GetNWBool( "IsConstrained" ) end

	local c = self:GetTable().Constraints
	local bIsConstrained = false

	if ( c ) then

		for k, v in pairs( c ) do
			if ( IsValid( v ) ) then bIsConstrained = true break end
			c[ k ] = nil
		end

	end

	self:SetNWBool( "IsConstrained", bIsConstrained )
	return bIsConstrained

end

--[[---------------------------------------------------------
	Name: Short cut to set tables on the entity table
-----------------------------------------------------------]]
function meta:SetVar( name, value )

	self:GetTable()[ name ] = value

end

--[[---------------------------------------------------------
	Name: CallOnRemove
	Desc: Call this function when this entity dies.
	Calls the function like Function( <entity>, <optional args> )
-----------------------------------------------------------]]
function meta:CallOnRemove( name, func, ... )

	local mytable = self:GetTable()
	mytable.OnDieFunctions = mytable.OnDieFunctions or {}

	mytable.OnDieFunctions[ name ] = { Name = name, Function = func, Args = { ... } }

end

--[[---------------------------------------------------------
	Name: RemoveCallOnRemove
	Desc: Removes the named hook
-----------------------------------------------------------]]
function meta:RemoveCallOnRemove( name )

	local mytable = self:GetTable()
	mytable.OnDieFunctions = mytable.OnDieFunctions or {}
	mytable.OnDieFunctions[ name ] = nil

end

--[[---------------------------------------------------------
	Simple mechanism for calling the die functions.
-----------------------------------------------------------]]
local function DoDieFunction( ent )

	if ( !ent.OnDieFunctions ) then return end

	for name, data in pairs( ent.OnDieFunctions ) do

		-- Functions aren't saved - so this could be nil if we loaded a game.
		if ( data && data.Function ) then

			ProtectedCall( data.Function, ent, unpack( data.Args ) )

		end

	end

end

hook.Add( "EntityRemoved", "DoDieFunction", DoDieFunction )

function meta:PhysWake()

	local phys = self:GetPhysicsObject()
	if ( !IsValid( phys ) ) then return end

	phys:Wake()

end

