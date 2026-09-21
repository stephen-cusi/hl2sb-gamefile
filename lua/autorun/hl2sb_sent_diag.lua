--[[---------------------------------------------------------------------------
	HL2SB: scripted-entity state dump -- the verdict tool for "addon entity
	is invisible / has no model / cannot be used" reports.

	Console:  hl2sb_sent_diag [classname]        (default cod-c4)

	The command exists in BOTH realms (this file is autorun): run it on the
	client console AND in the server console (or via `hl2sb_sent_diag` from
	the client with sv cheats... no - the server copy is typed in the server
	console / dedicated terminal).  Compare the two prints: a model present
	on the server but null on the client, or EF_NODRAW set on either side,
	names the broken half immediately.

	Content-only on purpose: this is a diagnostic, not a feature.
-----------------------------------------------------------------------------]]

if ( not concommand or not concommand.Add ) then return end

local EF_NODRAW   = 0x020
local EF_NOSHADOW = 0x010

local function Dump( ply, cmd, args, str )

	local class = ( args ~= nil and args[ 1 ] ~= nil and args[ 1 ] ~= "" ) and args[ 1 ] or "cod-c4"

	local list = ents.FindByClass( class )

	local realm = ( CLIENT ) and "cl" or "sv"
	print( ("[HL2SB][sent-diag][%s] '%s': %d found"):format( realm, class, #list ) )

	for i, ent in ipairs( list ) do

		if ( not IsValid( ent ) ) then
			print( ("[HL2SB][sent-diag][%s] #%d INVALID"):format( realm, i ) )
		else
			local model   = tostring( ent:GetModel() or "(null)" )
			local pos     = ent:GetPos()
			local mt      = tonumber( ent:GetMoveType() ) or -1
			local solid   = tonumber( ent:GetSolid() ) or -1
			local nodraw  = false
			local noshadow = false
			if ( ent.IsEffectActive ~= nil ) then
				pcall( function() nodraw   = ent:IsEffectActive( EF_NODRAW ) end )
				pcall( function() noshadow = ent:IsEffectActive( EF_NOSHADOW ) end )
			end
			local hasLuaDraw = "n/a"
			if ( ent.GetTable ~= nil ) then
				local ok, t = pcall( ent.GetTable, ent )
				hasLuaDraw = ( ok and istable( t ) and t.Draw ~= nil ) and "yes" or "no"
			end

			print( ("[HL2SB][sent-diag][%s] #%d model=%s pos=(%.0f,%.0f,%.0f) movetype=%d solid=%d NODRAW=%s NOSHADOW=%s luaDraw=%s")
				:format( realm, i, model, pos.x, pos.y, pos.z, mt, solid,
				         tostring( nodraw ), tostring( noshadow ), tostring( hasLuaDraw ) ) )
		end
	end

	if ( #list == 0 and SERVER ) then
		print( "[HL2SB][sent-diag][sv] (throw one first, then run this again)" )
	end
end

concommand.Add( "hl2sb_sent_diag", Dump, nil, "Dump scripted entity state (model/solid/EF flags/Draw bound)." )
