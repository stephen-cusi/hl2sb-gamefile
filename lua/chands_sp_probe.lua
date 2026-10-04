-- chands_sp_probe.lua (client realm) - SP duplicate-arms discriminator
local EF_BONEMERGE = 8

local function fv( name )
	local c = GetConVar and GetConVar( name ) or nil
	if ( c ~= nil and c.GetInt ~= nil ) then return c:GetInt() end
	return "?"
end

local function hdr( s ) print( "[chands-probe] " .. s ) end

hdr( "==== SP duplicate arms probe ====" )
hdr( "cl_localnetworkbackdoor=" .. fv( "cl_localnetworkbackdoor" )
	.. " cl_first_person_uses_world_model=" .. fv( "cl_first_person_uses_world_model" )
	.. " cl_predict=" .. fv( "cl_predict" )
	.. " r_drawviewmodel=" .. fv( "r_drawviewmodel" ) )

local ply = LocalPlayer()
if ( not IsValid( ply ) ) then hdr( "no local player" ) return end

local eye = ply:EyePos()

-- 1. local player body state (candidate a)
hdr( string.format( "localplayer ent=%d model=%s alive=%s",
	ply:EntIndex(), tostring( ply:GetModel() ), tostring( ply:Alive() ) ) )
if ( ply.ShouldDrawLocalPlayer ~= nil )
	then hdr( "Player:ShouldDrawLocalPlayer()=" .. tostring( ply:ShouldDrawLocalPlayer() ) ) end
if ( ply.IsPlayingTaunt ~= nil )
	then hdr( "IsPlayingTaunt=" .. tostring( ply:IsPlayingTaunt() ) ) end

-- 2. every gmod_hands on the client (candidate b): COUNT + bind state
local nHands = 0
hdr( "---- gmod_hands entities ----" )
for _, ent in ipairs( ents.GetAll() ) do
	local cls = ent.GetClassname and ent:GetClassname() or "?"
	if ( cls == "gmod_hands" ) then
		nHands = nHands + 1
		local grp = ent.GetRenderGroup and ent:GetRenderGroup() or -1
		local par = ent.GetParent and ent:GetParent() or nil
		local pos = ent.GetPos and ent:GetPos() or eye
		hdr( string.format( "hands#%d ent=%d renderGroup=%s (%s) parent=%s model=%s dorm=%s nodraw=%s bonemerge=%s dist=%.0f",
			nHands, ent:EntIndex(), tostring( grp ),
			grp == 13 and "OTHER-ok" or ( grp == 7 and "OPAQUE=WORLD-PASS-DRAWN" or "unexpected" ),
			IsValid( par ) and ( par:GetClassname() .. "#" .. par:EntIndex() ) or "nil",
			tostring( ent.GetModel and ent:GetModel() or "?" ),
			tostring( ent.IsDormant and ent:IsDormant() or "?" ),
			tostring( ent.GetNoDraw and ent:GetNoDraw() or "?" ),
			tostring( ent.IsEffectActive and ent:IsEffectActive( EF_BONEMERGE ) or "?" ),
			pos:Distance( eye ) ) )
	end
end
hdr( "gmod_hands count=" .. nHands .. " (expected 1; >1 = duplicate)" )

-- 3. every OTHER studio-model renderable near the eye (candidates a/c)
hdr( "---- near-eye model entities (dist<96) ----" )
for _, ent in ipairs( ents.GetAll() ) do
	if ( IsValid( ent ) and ent ~= ply ) then
		local mdl = ent.GetModel and ent:GetModel() or nil
		local pos = ent.GetPos and ent:GetPos() or nil
		if ( mdl ~= nil and pos ~= nil and mdl ~= "" and pos:Distance( eye ) < 96 ) then
			local grp = ent.GetRenderGroup and ent:GetRenderGroup() or -1
			local par = ent.GetParent and ent:GetParent() or nil
			hdr( string.format( "near ent=%d cls=%s model=%s grp=%s parent=%s dorm=%s pos=(%.0f %.0f %.0f)",
				ent:EntIndex(), ent.GetClassname and ent:GetClassname() or "?", tostring( mdl ),
				tostring( grp ),
				IsValid( par ) and ( par:GetClassname() .. "#" .. par:EntIndex() ) or "nil",
				tostring( ent.IsDormant and ent:IsDormant() or "?" ),
				pos.x, pos.y, pos.z ) )
		end
	end
end

-- 4. per-frame hook counters, 3-second window (candidate: double dispatch)
local counts = { PostDrawViewModel = 0, PreDrawPlayerHands = 0,
	PostDrawPlayerHands = 0, ViewModelDrawn = 0, OnViewModelChanged = 0 }
local t0 = CurTime()
for ev, _ in pairs( counts ) do
	hook.Add( ev, "chands_probe_" .. ev, function()
		counts[ ev ] = counts[ ev ] + 1
		-- return nothing: must not veto the chain
	end )
end
hdr( "counting hooks for 3s ..." )
timer.Simple( 3, function()
	hdr( string.format( "3s counters: PostDrawViewModel=%d PreDrawPlayerHands=%d PostDrawPlayerHands=%d ViewModelDrawn=%d OnViewModelChanged=%d",
		counts.PostDrawViewModel, counts.PreDrawPlayerHands, counts.PostDrawPlayerHands,
		counts.ViewModelDrawn, counts.OnViewModelChanged ) )
	hdr( string.format( "(~%d frames expected; PostDrawViewModel should equal frames; >frames = double dispatch)",
		math.floor( ( CurTime() - t0 ) / engine.TickInterval() ) ) )
	for ev, _ in pairs( counts ) do hook.Remove( ev, "chands_probe_" .. ev ) end
end )