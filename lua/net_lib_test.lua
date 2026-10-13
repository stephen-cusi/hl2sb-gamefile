--[[---------------------------------------------------------------------------
    net_lib_test.lua - full test suite for the GMod-style net rewrite.

    How to run (listen server, one process hosts both realms):
        lua_dofile    net_lib_test.lua     (server realm)
        lua_dofile_cl net_lib_test.lua     (client realm)

    Run BOTH commands for full cross-realm coverage (load the server side
    first; both sides handshake and retry for a few seconds, so a few seconds
    of gap is fine).  Either side alone also works: cross-realm sections then
    report SKIP with the reason.  Dedicated server + remote client: results
    print on each realm's own console, every line tagged [NETTEST SV] /
    [NETTEST CL].

    Layout:
      PART 0  local (per-realm) contract tests, no networking
      PART 1  cross-realm Write*/Read* roundtrips, both directions
      PART 2  send-function coverage (Send/Broadcast/SendOmit; SendPVS/PAS
              are unbound in this fork -> reported as SKIP)
      PART 3  boundary behaviour (64KB-class data, >65535 rejects, unpooled
              names, sv->cl 255B transport guard)
      PART 4  dispatcher semantics (lowercased receivers, ReadHeader id,
              net.Incoming overridable, Abort, duplicate Start)
      PART 5  STRESS (announced): flood, 32KB bursts, mixed bombardment,
              GC churn, overflow recovery

    Manual-only items (need a human / two machines, noted inline):
      - unreliable-channel loss behaviour on a real network
      - sustained multi-megabyte flood until the engine kicks the client
        ("Overflowed reliable channel") - deliberately not automated here

    Re-running the file resets its state (single global NETTEST).
---------------------------------------------------------------------------]]

NETTEST = { pass = 0, fail = 0, skip = 0, acks = {}, expect = {}, seq = 0 }

local TAG = SERVER and "[NETTEST SV]" or "[NETTEST CL]"
local function ok( cond, name )
	if cond then
		NETTEST.pass = NETTEST.pass + 1
		print( TAG .. " PASS  " .. name )
	else
		NETTEST.fail = NETTEST.fail + 1
		print( TAG .. " FAIL  " .. name )
	end
end

local function skip( name )
	NETTEST.skip = NETTEST.skip + 1
	print( TAG .. " SKIP  " .. name )
end

local function note( msg )
	print( TAG .. " ----  " .. msg )
end

-- ack-tracked sequence numbers; each realm only tracks the messages IT sent.
-- expectAbsent=true marks messages that must NEVER arrive (their ACK would
-- mean a leak); the summary does not count them as pending.
local function nextSeq( desc, expectAbsent )
	NETTEST.seq = NETTEST.seq + 1
	NETTEST.expect[ NETTEST.seq ] = desc
	NETTEST.acks[ NETTEST.seq ] = expectAbsent and "absent" or false
	return NETTEST.seq
end

local function ackSeq( seq )
	if NETTEST.expect[ seq ] == nil then
		NETTEST.fail = NETTEST.fail + 1
		print( TAG .. " FAIL  unexpected ACK seq " .. tostring( seq ) .. " (unsolicited/duplicate delivery)" )
		return
	end
	if NETTEST.acks[ seq ] == "absent" then
		NETTEST.fail = NETTEST.fail + 1
		print( TAG .. " FAIL  seq " .. tostring( seq ) .. " arrived although marked absent: " .. tostring( NETTEST.expect[ seq ] ) )
		return
	end
	NETTEST.acks[ seq ] = true
end

-- deterministic payload builder (includes NUL bytes on purpose)
local function makeData( n, salt )
	local parts = {}
	for i = 1, n do
		parts[ i ] = string.char( ( i * 7 + ( salt or 0 ) ) % 256 )
	end
	return table.concat( parts )
end

local function approx( a, b, eps )
	return math.abs( a - b ) < ( eps or 1e-6 )
end

-----------------------------------------------------------------------------
-- pooled names (server pools them; the client realm resolves via replication)
-----------------------------------------------------------------------------
local NAMES = {
	"nettest_ctl", "nettest_types", "nettest_lcase", "nettest_dup_a",
	"nettest_dup_b", "nettest_wd64k", "nettest_wd_reject", "nettest_big",
	"nettest_mixed", "nettest_flood", "nettest_ovf", "nettest_ovf_recovery",
	"nettest_canary", "nettest_canary2", "nettest_send", "nettest_bcast",
	"nettest_omit", "nettest_svcl_big",
}
if SERVER then
	for _, name in ipairs( NAMES ) do
		util.AddNetworkString( name )
	end
end

-----------------------------------------------------------------------------
-- PART 0 - local contract tests (no networking)
-----------------------------------------------------------------------------
local function runLocalTests()
	local common = { "Start", "WriteBit", "WriteInt", "WriteUInt", "WriteString", "WriteFloat",
		"WriteDouble", "WriteVector", "WriteAngle", "WriteEntity", "WriteBool", "ReadBool",
		"WriteData", "ReadData", "WriteColor", "ReadColor", "WriteTable", "ReadTable",
		"BytesWritten", "BytesLeft", "Abort", "ReadHeader", "ReadBit", "ReadInt", "ReadUInt",
		"ReadString", "ReadFloat", "ReadDouble", "ReadVector", "ReadAngle", "ReadEntity" }
	for _, name in ipairs( common ) do
		ok( type( net[ name ] ) == "function", "binding net." .. name )
	end
	ok( type( net.Receive ) == "function", "binding net.Receive (pure Lua)" )
	ok( type( net.Incoming ) == "function", "binding net.Incoming (pure Lua, overridable)" )
	ok( type( net.Receivers ) == "table", "binding net.Receivers (pure Lua)" )

	if CLIENT then
		ok( type( net.SendToServer ) == "function", "binding net.SendToServer (client)" )
	end
	if SERVER then
		for _, name in ipairs( { "Send", "Broadcast", "SendOmit", "WritePlayer", "ReadPlayer" } ) do
			ok( type( net[ name ] ) == "function", "binding net." .. name .. " (server)" )
		end
		if net.SendPVS == nil and net.SendPAS == nil then
			skip( "net.SendPVS / net.SendPAS unbound in this fork (GMod has them - known gap, not a regression)" )
		end
	end

	-- BytesWritten accounting: 16-bit id header first
	net.Start( "nettest_types" )
	ok( net.BytesWritten() == 2, "BytesWritten == 2 right after Start (16-bit id header)" )
	net.WriteInt( 1, 32 )
	ok( net.BytesWritten() == 6, "BytesWritten == 6 after WriteInt(32)" )
	net.Abort()
	ok( net.BytesWritten() == 0, "Abort deactivates the message (BytesWritten 0)" )

	-- pooling: idempotent, roundtrip, unknown name handling
	if SERVER then
		local id1 = util.AddNetworkString( "nettest_types" )
		local id2 = util.AddNetworkString( "nettest_types" )
		ok( id1 == id2 and id1 > 0, "AddNetworkString twice returns the same id" )
		ok( util.NetworkStringToID( "nettest_types" ) == id1, "NetworkStringToID roundtrip" )
		ok( util.NetworkIDToString( id1 ) == "nettest_types", "NetworkIDToString roundtrip" )
		ok( util.NetworkStringToID( "nettest_never_pooled_xyz" ) == 0, "unknown name -> id 0" )
		ok( util.NetworkIDToString( 65535 ) == nil, "unknown id -> nil" )
	end

	-- unpooled net.Start must raise the reference error text
	local errText = select( 2, pcall( function() net.Start( "nettest_never_pooled_xyz" ) end ) )
	ok( errText ~= nil and string.find( tostring( errText ), "unpooled message name", 1, true ) ~= nil,
		"unpooled net.Start errors with reference text" )

	-- receivers are stored lowercased (reference behaviour)
	net.Receive( "NETTEST_StorageCase", function() end )
	ok( net.Receivers[ "nettest_storagecase" ] ~= nil, "net.Receive stores lowercased key" )

	-- WriteData length guard, local half (>=65537 rejected before writing)
	net.Start( "nettest_types" )
	net.WriteData( makeData( 65537 ), 65537 )
	ok( net.BytesWritten() == 2, "WriteData(65537) rejected (no bytes written)" )
	net.Abort()
end

-----------------------------------------------------------------------------
-- cross-realm plumbing: ctl channel
-----------------------------------------------------------------------------
-- kinds: 1=ACK(seq) 2=HELLO 3=FLOOD_COUNT(count) 4=BEGIN_OVERRIDE 5=RESTORE_OVERRIDE
local function sendCtl( kind, a, b )
	net.Start( "nettest_ctl" )
	net.WriteUInt( kind, 8 )
	net.WriteUInt( a or 0, 16 )
	net.WriteUInt( b or 0, 32 )
	if SERVER then net.Broadcast() else net.SendToServer() end
end

local function otherPresent() return NETTEST.peer == true end

-----------------------------------------------------------------------------
-- types battery (composed/verified symmetrically on both realms)
-----------------------------------------------------------------------------
local function writeTypes()
	net.WriteBit( 1 )
	net.WriteBit( 0 )
	net.WriteBool( true )
	net.WriteBool( false )
	net.WriteInt( -99, 8 )
	net.WriteInt( -30000, 16 )
	net.WriteInt( 123456789, 32 )
	net.WriteUInt( 255, 8 )
	net.WriteUInt( 65535, 16 )
	net.WriteUInt( 2147483647, 32 )
	net.WriteString( "plain ascii + utf8 你好" )
	net.WriteFloat( 0.25 )
	net.WriteDouble( 1 / 3 )
	net.WriteDouble( 123456789012345 )
	net.WriteVector( Vector( 1.5, -2.25, 1000 ) )
	net.WriteAngle( Angle( 10.5, 20.25, 30.125 ) )
	net.WriteColor( Color( 12, 34, 56, 78 ) )
	net.WriteData( makeData( 1024 ), 1024 )
	net.WriteTable( { n = 42, s = "你好", b = true, t = { 1, 2, 3 } } )
	net.WriteType( 3.5 )
	-- entity + player: encode the index so the receiver can verify identity
	local ply = nil
	if SERVER then ply = player.GetAll()[ 1 ] elseif LocalPlayer and IsValid( LocalPlayer() ) then ply = LocalPlayer() end
	local idx = ( ply ~= nil and ply:IsValid() ) and ply:entindex() or 0
	net.WriteUInt( idx, 16 )
	net.WriteEntity( ply )
	if net.WritePlayer then net.WritePlayer( ply ) end
end

-- returns true when every decoded value matches
local function verifyTypes()
	local good = true
	local function chk( cond, name )
		if not cond then good = false end
		ok( cond, "types rx: " .. name )
	end

	chk( net.ReadBit() == 1, "ReadBit 1" )
	chk( net.ReadBit() == 0, "ReadBit 0" )
	chk( net.ReadBool() == true, "ReadBool true" )
	chk( net.ReadBool() == false, "ReadBool false" )
	chk( net.ReadInt( 8 ) == -99, "ReadInt 8-bit" )
	chk( net.ReadInt( 16 ) == -30000, "ReadInt 16-bit" )
	chk( net.ReadInt( 32 ) == 123456789, "ReadInt 32-bit" )
	chk( net.ReadUInt( 8 ) == 255, "ReadUInt 8-bit" )
	chk( net.ReadUInt( 16 ) == 65535, "ReadUInt 16-bit" )
	chk( net.ReadUInt( 32 ) == 2147483647, "ReadUInt 32-bit (INT_MAX; C binding takes int32)" )
	chk( net.ReadString() == "plain ascii + utf8 你好", "ReadString (utf8 payload)" )
	chk( net.ReadFloat() == 0.25, "ReadFloat exact" )
	chk( approx( net.ReadDouble(), 1 / 3, 1e-9 ), "ReadDouble 1/3" )
	chk( approx( net.ReadDouble(), 123456789012345, 1 ), "ReadDouble large" )
	local v = net.ReadVector()
	chk( v ~= nil and v.x == 1.5 and v.y == -2.25 and v.z == 1000, "ReadVector exact components" )
	local a = net.ReadAngle()
	chk( a ~= nil and a.p == 10.5 and a.y == 20.25 and a.r == 30.125, "ReadAngle exact components" )
	local c = net.ReadColor()
	chk( c ~= nil and c.r == 12 and c.g == 34 and c.b == 56 and c.a == 78, "ReadColor rgba" )
	local data = net.ReadData( 1024 )
	chk( #data == 1024 and data == makeData( 1024 ), "ReadData 1KB with NUL bytes" )
	local t = net.ReadTable()
	chk( t ~= nil and t.n == 42 and t.s == "你好" and t.b == true and t.t ~= nil and t.t[ 3 ] == 3, "ReadTable nested" )
	chk( net.ReadType() == 3.5, "ReadType number" )
	local idx = net.ReadUInt( 16 )
	local ent = net.ReadEntity()
	chk( idx > 0 and ent ~= nil and ent:IsValid() and ent:entindex() == idx,
		"ReadEntity roundtrip (index " .. idx .. ")" )
	if net.ReadPlayer then
		local ply = net.ReadPlayer()
		chk( ply ~= nil and ply:IsValid() and ply:entindex() == idx, "ReadPlayer roundtrip (index " .. idx .. ")" )
	end
	chk( net.BytesLeft() == 0, "BytesLeft == 0 after consuming everything" )
	return good
end

-----------------------------------------------------------------------------
-- receivers (registered on both realms; only the addressed side fires)
-----------------------------------------------------------------------------
net.Receive( "nettest_types", function( len )
	local seq = net.ReadUInt( 16 )
	if verifyTypes() then ok( true, "types battery payload verified (len " .. len .. " bits)" ) end
	sendCtl( 1, seq )
end )

net.Receive( "nettest_lcase", function()
	ok( true, "lowercase receiver caught message started as UPPERCASE name" )
	sendCtl( 1, net.ReadUInt( 16 ) )
end )

net.Receive( "nettest_dup_a", function()
	-- reference behaviour: the second net.Start discards this message, so it
	-- must never arrive; an ACK here trips the driver's unexpected-ACK path
	sendCtl( 1, net.ReadUInt( 16 ) )
end )

net.Receive( "nettest_dup_b", function()
	ok( net.ReadString() == "B", "duplicate Start: newest message survived" )
	sendCtl( 1, net.ReadUInt( 16 ) )
end )

net.Receive( "nettest_wd64k", function()
	local seq = net.ReadUInt( 16 )
	local data = net.ReadData( 65533 )
	local crcOk = util.CRC( data ) == net.ReadString()
	ok( #data == 65533 and crcOk, "64KB-class payload (65533B) intact, CRC match" )
	-- reference behaviour: ReadData above 65535 raises
	local err = select( 2, pcall( net.ReadData, 65536 ) )
	ok( err ~= nil and string.find( tostring( err ), "Invalid length", 1, true ) ~= nil,
		"ReadData(65536) errors (Invalid length)" )
	sendCtl( 1, seq )
end )

net.Receive( "nettest_wd_reject", function()
	local seq = net.ReadUInt( 16 )
	-- the rejected 65537B write must have contributed zero bytes
	local marker = net.ReadString()
	ok( marker == "after-reject", "WriteData(65537) rejected: only the post-reject marker arrived" )
	sendCtl( 1, seq )
end )

net.Receive( "nettest_big", function()
	local seq = net.ReadUInt( 16 )
	net.ReadUInt( 8 ) -- total count marker
	local data = net.ReadData( 32768 )
	local crcOk = util.CRC( data ) == net.ReadString()
	ok( #data == 32768 and crcOk, "32KB big message seq " .. seq .. " intact" )
	sendCtl( 1, seq )
end )

net.Receive( "nettest_mixed", function()
	local seq = net.ReadUInt( 16 )
	local expectSeq = net.ReadUInt( 16 )
	local kind = net.ReadUInt( 8 )
	local payloadOk
	if kind == 1 then
		payloadOk = net.ReadString() == "mix" .. expectSeq
	else
		payloadOk = net.ReadData( 4096 ) == makeData( 4096, expectSeq % 251 )
	end
	ok( seq == expectSeq and payloadOk, "mixed seq " .. expectSeq .. " in order, payload ok" )
	sendCtl( 1, seq )
end )

NETTEST.floodSeen = 0
NETTEST.floodLastSeq = 0
net.Receive( "nettest_flood", function()
	NETTEST.floodSeen = NETTEST.floodSeen + 1
	local seq = net.ReadUInt( 16 )
	if seq ~= NETTEST.floodLastSeq + 1 then
		ok( false, "flood sequence break at " .. NETTEST.floodLastSeq .. " -> " .. seq )
	end
	NETTEST.floodLastSeq = seq
	if NETTEST.floodSeen % 100 == 0 then collectgarbage( "step" ) end
end )

net.Receive( "nettest_ovf", function()
	-- arrives truncated (the 64KB buffer overflow cut it); record arrival
	local seq = net.ReadUInt( 16 )
	local data = net.ReadData( net.BytesLeft() )
	ok( #data > 0 and #data < 80000, "overflowed message delivered truncated (" .. #data .. " bytes)" )
	sendCtl( 1, seq )
end )

net.Receive( "nettest_ovf_recovery", function()
	local seq = net.ReadUInt( 16 )
	ok( net.ReadString() == "recovered", "post-overflow message arrived intact (state recovered)" )
	sendCtl( 1, seq )
end )

net.Receive( "nettest_canary", function()
	-- default-dispatch path of the Incoming-override test (after restore)
	ok( true, "canary dispatched again after net.Incoming restored" )
	sendCtl( 1, net.ReadUInt( 16 ) )
end )

net.Receive( "nettest_send", function()
	ok( net.ReadString() == "via net.Send", "net.Send delivered to target player" )
	sendCtl( 1, net.ReadUInt( 16 ) )
end )

net.Receive( "nettest_bcast", function()
	ok( net.ReadString() == "via net.Broadcast", "net.Broadcast delivered" )
	sendCtl( 1, net.ReadUInt( 16 ) )
end )

net.Receive( "nettest_omit", function()
	-- must NOT reach the omitted player; an ACK here = leak = driver failure
	ok( false, "net.SendOmit message LEAKED to the omitted player" )
	sendCtl( 1, net.ReadUInt( 16 ) )
end )

net.Receive( "nettest_svcl_big", function()
	-- sv->cl rides the usermessage transport (255B cap): oversize payloads
	-- must be refused server-side and never arrive
	ok( false, "sv->cl oversize message was NOT refused by the transport guard" )
	sendCtl( 1, net.ReadUInt( 16 ) )
end )

net.Receive( "nettest_ctl", function()
	local kind = net.ReadUInt( 8 )
	local a = net.ReadUInt( 16 )
	local b = net.ReadUInt( 32 )
	if kind == 1 then
		ackSeq( a )
	elseif kind == 2 then
		if not NETTEST.peer then
			NETTEST.peer = true
			sendCtl( 2 ) -- handshake echo (guarded, no storm)
		end
	elseif kind == 3 then
		if SERVER then
			-- request: reply with our receive count
			sendCtl( 3, 0, NETTEST.floodSeen )
		else
			NETTEST.floodCountReply = b
		end
	elseif kind == 4 then
		-- receiver side: override net.Incoming for the canary window.  The
		-- override restores ITSELF on the first call: the RESTORE control
		-- message that follows also dispatches through net.Incoming, so a
		-- fixed override would swallow its own restore and deafen the realm.
		NETTEST.origIncoming = net.Incoming
		NETTEST.overrideSawHeader = false
		net.Incoming = function()
			-- prove the C side only calls net.Incoming and the 16-bit id
			-- header is intact: resolve it ourselves
			local id = net.ReadHeader()
			local name = util.NetworkIDToString( id )
			NETTEST.overrideSawHeader = ( name == "nettest_canary" )
			ok( NETTEST.overrideSawHeader,
				"overridden net.Incoming read header -> " .. tostring( name ) .. " (id " .. id .. ")" )
			net.Incoming = NETTEST.origIncoming or net.Incoming
			-- swallow the canary: do not dispatch it
		end
	elseif kind == 5 then
		net.Incoming = NETTEST.origIncoming or net.Incoming
		ok( NETTEST.overrideSawHeader, "canary was swallowed by the override (never dispatched)" )
		sendCtl( 1, a )
	end
end )

-----------------------------------------------------------------------------
-- drivers
-----------------------------------------------------------------------------
local function sendToOther()
	if SERVER then net.Broadcast() else net.SendToServer() end
end

local function runDriverCross()
	-- PART 1: type roundtrips
	do
		local seq = nextSeq( "types battery roundtrip" )
		net.Start( "nettest_types" )
		net.WriteUInt( seq, 16 )
		writeTypes()
		sendToOther()
	end

	-- PART 4: lowercase receiver vs UPPERCASE Start
	do
		local seq = nextSeq( "uppercase Start -> lowercase Receive" )
		net.Start( "NETTEST_LCASE" )
		net.WriteUInt( seq, 16 )
		sendToOther()
	end

	-- PART 4: duplicate Start discards the older message
	do
		local seqA = nextSeq( "dup Start: FIRST message discarded (no ACK expected)", true )
		local seqB = nextSeq( "dup Start: newest message delivered" )
		net.Start( "nettest_dup_a" )
		net.WriteUInt( seqA, 16 )
		net.Start( "nettest_dup_b" )
		net.WriteUInt( seqB, 16 )
		net.WriteString( "B" )
		sendToOther()
	end

	-- PART 3: >65535 reject end-to-end
	do
		local seq = nextSeq( "WriteData 65537 rejected, post-reject marker intact" )
		net.Start( "nettest_wd_reject" )
		net.WriteUInt( seq, 16 )
		net.WriteData( makeData( 65537 ), 65537 ) -- warns "Invalid length 65537!", writes nothing
		net.WriteString( "after-reject" )
		sendToOther()
	end

	-- PART 3: 64KB-class data only fits the cl->sv leg; the sv->cl leg is the
	-- 255B usermessage transport (documented deviation)
	if CLIENT then
		local seq = nextSeq( "cl->sv WriteData 65533 accepted, CRC intact" )
		local data = makeData( 65533 )
		net.Start( "nettest_wd64k" )
		net.WriteUInt( seq, 16 )
		net.WriteData( data, 65533 )
		net.WriteString( util.CRC( data ) )
		net.SendToServer()
	else
		skip( "sv->cl 64KB-class data: usermessage leg caps at 255B (documented deviation)" )
		-- positive guard instead: an oversize sv->cl payload must be refused
		local seq = nextSeq( "sv->cl oversize payload refused by transport guard (no ACK expected)", true )
		net.Start( "nettest_svcl_big" )
		net.WriteUInt( seq, 16 )
		net.WriteData( makeData( 4096 ), 4096 )
		net.Broadcast()
	end

	-- PART 2: server send-function coverage (listen host = player 1)
	if SERVER then
		do
			local seq = nextSeq( "net.Send to player 1" )
			local ply = player.GetAll()[ 1 ]
			if ply then
				net.Start( "nettest_send" )
				net.WriteUInt( seq, 16 )
				net.WriteString( "via net.Send" )
				net.Send( ply )
			else
				skip( "net.Send: no player on server" )
			end
		end
		do
			local seq = nextSeq( "net.Broadcast" )
			net.Start( "nettest_bcast" )
			net.WriteUInt( seq, 16 )
			net.WriteString( "via net.Broadcast" )
			net.Broadcast()
		end
		do
			local seq = nextSeq( "net.SendOmit omits player 1 (no ACK expected)", true )
			local ply = player.GetAll()[ 1 ]
			if ply then
				net.Start( "nettest_omit" )
				net.WriteUInt( seq, 16 )
				net.SendOmit( ply )
			else
				NETTEST.acks[ seq ] = true
			end
			-- manual MP check: with >1 players, omit(player1) should arrive on
			-- the OTHER clients' consoles and never on player 1
		end
	end
end

-- driver side (server only): prove net.Incoming is overridable on the receiver
local function runIncomingOverrideChoreography()
	sendCtl( 4 )
	timer.Simple( 0.3, function()
		local seq = nextSeq( "canary swallowed by overridden net.Incoming (no ACK expected)", true )
		net.Start( "nettest_canary" )
		net.WriteUInt( seq, 16 )
		net.Broadcast()
	end )
	timer.Simple( 0.6, function()
		local seq = nextSeq( "override self-restored: RESTORE ctl dispatched normally" )
		sendCtl( 5, seq )
	end )
	timer.Simple( 1.0, function()
		local seq = nextSeq( "canary dispatched again after restore" )
		net.Start( "nettest_canary" )
		net.WriteUInt( seq, 16 )
		net.Broadcast()
	end )
end

-----------------------------------------------------------------------------
-- PART 5 - stress
-----------------------------------------------------------------------------
local function runStress()
	note( "==== STRESS SECTION / 以下为压力测试 ====" )

	if CLIENT then
		-- 5a flood: scp173-style - 300 small SendToServer per burst, 10
		-- bursts over ~5s, GC stepped every burst; server reconciles counts
		NETTEST.floodSent = 0
		NETTEST.floodSeq = 0
		note( "flood: 10 bursts x 300 messages (SendToServer), GC per burst" )
		for burst = 1, 10 do
			timer.Simple( burst * 0.5, function()
				for i = 1, 300 do
					NETTEST.floodSeq = NETTEST.floodSeq + 1
					NETTEST.floodSent = NETTEST.floodSent + 1
					net.Start( "nettest_flood" )
					net.WriteUInt( NETTEST.floodSeq, 16 )
					net.SendToServer()
				end
				collectgarbage( "step" )
			end )
		end
	end

	-- 5b: 32KB messages x10, both directions
	local function sendBigs()
		for i = 1, 10 do
			local seq = nextSeq( "32KB message " .. i .. "/10 intact" )
			local data = makeData( 32768, i )
			net.Start( "nettest_big" )
			net.WriteUInt( seq, 16 )
			net.WriteUInt( 10, 8 )
			net.WriteData( data, 32768 )
			net.WriteString( util.CRC( data ) )
			sendToOther()
		end
	end
	if SERVER then
		timer.Simple( 2.0, sendBigs )
	else
		timer.Simple( 8.5, sendBigs )
	end

	-- 5c: mixed bombardment, 100 ordered items alternating small/4KB
	local function sendMixed()
		for i = 1, 100 do
			local seq = nextSeq( "mixed item " .. i .. "/100" )
			net.Start( "nettest_mixed" )
			net.WriteUInt( seq, 16 )
			net.WriteUInt( i, 16 )
			net.WriteUInt( ( i % 2 ) + 1, 8 )
			if i % 2 == 1 then
				net.WriteString( "mix" .. i )
			else
				net.WriteData( makeData( 4096, i % 251 ), 4096 )
			end
			sendToOther()
		end
	end
	if SERVER then
		timer.Simple( 10.0, sendMixed )
	else
		timer.Simple( 10.5, sendMixed )
	end

	-- 5d: overflow then recovery
	local function sendOverflow()
		local seq = nextSeq( "overflowed message warned + delivered truncated" )
		net.Start( "nettest_ovf" )
		net.WriteUInt( seq, 16 )
		net.WriteData( makeData( 40000 ), 40000 )
		net.WriteData( makeData( 40000, 7 ), 40000 ) -- pushes past 64KB -> overflow flag
		sendToOther()

		local seq2 = nextSeq( "post-overflow recovery message intact" )
		net.Start( "nettest_ovf_recovery" )
		net.WriteUInt( seq2, 16 )
		net.WriteString( "recovered" )
		sendToOther()
	end
	if SERVER then
		timer.Simple( 12.0, sendOverflow )
	else
		timer.Simple( 12.5, sendOverflow )
	end

	-- 5e GC churn: collectgarbage("step") runs per flood burst (client) and
	-- every 100 flood receives (server) - see the receivers above.
end

-----------------------------------------------------------------------------
-- summary
-----------------------------------------------------------------------------
local function summarize()
	for seq, desc in pairs( NETTEST.expect ) do
		local st = NETTEST.acks[ seq ]
		if st ~= true and st ~= "absent" then
			if otherPresent() then
				NETTEST.fail = NETTEST.fail + 1
				print( TAG .. " FAIL  no ACK: " .. desc )
			else
				NETTEST.skip = NETTEST.skip + 1
				print( TAG .. " SKIP  " .. desc .. " (对端未加载测试套件)" )
			end
		end
	end
	print( TAG .. " ============================================================" )
	if NETTEST.fail == 0 then
		print( TAG .. " ALL PASSED  (" .. NETTEST.pass .. " passed, " .. NETTEST.skip .. " skipped)" )
	else
		print( TAG .. " " .. NETTEST.fail .. " FAILED  (" .. NETTEST.pass .. " passed, " .. NETTEST.skip .. " skipped)" )
	end
	print( TAG .. " 双向全覆盖需要两端都加载: 服务端 lua_dofile net_lib_test.lua + 客户端 lua_dofile_cl net_lib_test.lua" )
end

-----------------------------------------------------------------------------
-- schedule (handshake with retries so manual console timing is forgiving)
-----------------------------------------------------------------------------
runLocalTests()

local function handshake()
	if NETTEST.peer then return end
	sendCtl( 2 )
end

if SERVER then
	for _, t in ipairs( { 0.5, 1.5, 2.5, 3.5 } ) do
		timer.Simple( t, handshake )
	end
	timer.Simple( 5.0, function()
		if otherPresent() then
			runDriverCross()
			runStress()
			timer.Simple( 2.5, runIncomingOverrideChoreography )
			timer.Simple( 20.0, summarize )
		else
			skip( "全部跨端测试项 (客户端未加载: 先/同时跑 lua_dofile_cl net_lib_test.lua)" )
			timer.Simple( 0.1, summarize )
		end
	end )
else
	for _, t in ipairs( { 0.5, 1.5, 2.5, 3.5 } ) do
		timer.Simple( t, handshake )
	end
	timer.Simple( 5.5, function()
		if otherPresent() then
			runDriverCross()
			runStress()
			-- flood reconciliation: ask the server for its receive count
			timer.Simple( 7.0, function()
				sendCtl( 3 )
				timer.Simple( 1.0, function()
					local got = NETTEST.floodCountReply or -1
					ok( got == NETTEST.floodSent,
						"flood reconciliation: sent " .. NETTEST.floodSent .. ", server received " .. got )
				end )
			end )
			timer.Simple( 21.0, summarize )
		else
			skip( "全部跨端测试项 (服务端未加载: 先/同时跑 lua_dofile net_lib_test.lua)" )
			timer.Simple( 0.1, summarize )
		end
	end )
end

note( "suite loaded: local tests done, cross-realm phases scheduled" )
