--[[---------------------------------------------------------------------------
    umsg - GMod's usermessage writing half, rebuilt on this fork's net library.

    GMod ships umsg C-side; this fork only ever had the receiving half
    (includes/modules/usermessage.lua: usermessage.Hook / IncomingMessage were
    ported verbatim but nothing ever called IncomingMessage and the global
    umsg table did not exist, so every old-style addon died on its first
    umsg.Start - the portalgun could not move a portal, tell the client a
    prop entered one, or draw its debug OBBs).

    Wire format: one net message "hl2sb_umsg" carrying the usermessage name
    followed by the fields, written and read strictly in order - which is the
    umsg contract anyway.

    GMod quirks kept:
      * umsg.Start( name ) with no recipients broadcasts.
      * umsg.Start( name, ply ) / ( name, filter ) - a Player, a table of
        Players, or a CRecipientFilter object are all accepted.
      * writes are server-only (GMod errors on the client; we no-op into the
        same error the net layer raises).
---------------------------------------------------------------------------]]

local globals = _G	-- module() has no __index fallback; capture before module()

module( "umsg" )

local net = globals.net
local util = globals.util
local IsValid = globals.IsValid

local UMSG_NET_NAME = "hl2sb_umsg"

if ( SERVER ) then
	util.AddNetworkString( UMSG_NET_NAME )
end

-------------------------------------------------------------------------------
-- Server side: Start / write / End stream straight into the open net message.
-------------------------------------------------------------------------------

local function ResolveRecipients( filter )

	if ( filter == nil ) then return nil end	-- nil = net.Broadcast()

	if ( type( filter ) == "table" ) then return filter end

	-- A single Player entity.  type() on userdata answers the metatable
	-- name ("Entity") in this fork; util's isentity() is unreliable here.
	if ( type( filter ) == "Entity" ) then
		return { filter }
	end

	-- A CRecipientFilter object: flatten it to a player table for net.Send.
	local count = filter.GetRecipientCount and filter:GetRecipientCount() or 0
	local players = {}
	for i = 1, count do
		local r = filter.GetRecipientIndex and filter:GetRecipientIndex( i ) or nil
		if ( r != nil ) then
			if ( type( r ) != "Entity" and type( r ) == "number" ) then
				r = globals.Entity( r )
			end
			if ( IsValid( r ) ) then players[ #players + 1 ] = r end
		end
	end
	return players

end

local pendingFilter = nil

function Start( name, filter )

	if ( CLIENT ) then return end

	pendingFilter = filter

	net.Start( UMSG_NET_NAME )
	net.WriteString( name )

end

-- Field order IS the protocol: net writes land in the message in call order.
function Char( v ) if ( !CLIENT ) then net.WriteInt( v, 8 ) end end
function Short( v ) if ( !CLIENT ) then net.WriteInt( v, 16 ) end end
function Long( v ) if ( !CLIENT ) then net.WriteInt( v, 32 ) end end
function Float( v ) if ( !CLIENT ) then net.WriteFloat( v ) end end
function Bool( v ) if ( !CLIENT ) then net.WriteBool( v ) end end
function Entity( v ) if ( !CLIENT ) then net.WriteEntity( v ) end end
function Vector( v ) if ( !CLIENT ) then net.WriteVector( v ) end end
function Angle( v ) if ( !CLIENT ) then net.WriteAngle( v ) end end
function String( v ) if ( !CLIENT ) then net.WriteString( v ) end end

function End()

	if ( CLIENT ) then return end

	local recipients = ResolveRecipients( pendingFilter )
	pendingFilter = nil

	if ( recipients == nil ) then
		net.Broadcast()
	else
		net.Send( recipients )
	end

end

-------------------------------------------------------------------------------
-- Client side: a reader object with GMod's umsg:Read* spellings, fed by the
-- net receive in the same order the server wrote.
-------------------------------------------------------------------------------

if ( CLIENT ) then

	local reader = {}

	function reader:ReadChar() return net.ReadInt( 8 ) end
	function reader:ReadShort() return net.ReadInt( 16 ) end
	function reader:ReadLong() return net.ReadInt( 32 ) end
	function reader:ReadFloat() return net.ReadFloat() end
	function reader:ReadBool() return net.ReadBool() end
	function reader:ReadEntity() return net.ReadEntity() end
	function reader:ReadVector() return net.ReadVector() end
	function reader:ReadAngle() return net.ReadAngle() end
	function reader:ReadString() return net.ReadString() end

	globals.net.Receive( UMSG_NET_NAME, function()

		local name = net.ReadString()
		local usermessage = globals.usermessage

		if ( usermessage != nil and usermessage.IncomingMessage != nil ) then
			usermessage.IncomingMessage( name, reader )
		end

	end )

end
