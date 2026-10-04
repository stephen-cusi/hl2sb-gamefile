-- chands_v3_probe.lua (client) - identity + table-truth after vehicle exit
local ply = LocalPlayer()
if ( not IsValid( ply ) ) then print( "[v3] no local player" ) return end
local vm    = ply.GetViewModel and ply:GetViewModel( 0 ) or nil
local hands = ply.GetHands and ply:GetHands() or nil
local EF_BONEMERGE = 8

print( "[v3] GetHands()=" .. tostring( hands ) .. " idx=" ..
	tostring( IsValid( hands ) and hands:EntIndex() or "?" ) )
print( "[v3] hands MODEL=" .. tostring( IsValid( hands ) and hands:GetModel() or "?" ) ..
	"  (expect models/arms/qiandai_se_arms.mdl; C4/ball model = wrong entity assigned)" )
if ( IsValid( hands ) ) then
	-- table truth: reads the REF'D TABLE, immune to the GetClassname collapse
	print( "[v3] table.ClassName=" .. tostring( hands.ClassName ) ..
		" table.RenderGroup=" .. tostring( hands.RenderGroup ) ..
		" has ENT:ViewModelChanged=" .. tostring( hands.ViewModelChanged ~= nil ) )
	print( "[v3] GetClass()=" .. tostring( hands.GetClass and hands:GetClass() or "?" ) ..
		" GetClassname()=" .. tostring( hands.GetClassname and hands:GetClassname() or "?" ) )
	print( "[v3] grp=" .. tostring( hands.GetRenderGroup and hands:GetRenderGroup() or "?" ) ..
		" parent=" .. tostring( hands:GetParent() ) ..
		" bonemerge=" .. tostring( hands:IsEffectActive( EF_BONEMERGE ) ) ..
		" pos=" .. tostring( hands:GetPos() ) .. " modelidx=" ..
		tostring( hands:GetModelIndex() ) )
end

-- identity sweep: every scripted-looking / arms-model entity on the client
print( "[v3] ---- all arms-model + known-index entities ----" )
for _, idx in ipairs( { 89, 117 } ) do
	local e = Entity( idx )
	print( "[v3] Entity(" .. idx .. ")=" .. tostring( e ) .. " valid=" ..
		tostring( IsValid( e ) ) .. " model=" ..
		tostring( IsValid( e ) and e:GetModel() or "-" ) .. " parent=" ..
		tostring( IsValid( e ) and tostring( e:GetParent() ) or "-" ) )
end
for _, ent in ipairs( ents.GetAll() ) do
	local mdl = ent.GetModel and ent:GetModel() or nil
	if ( mdl ~= nil and string.find( string.lower( mdl ), "arms", 1, true ) ) then
		print( "[v3] arms-model ent=" .. ent:EntIndex() .. " model=" .. mdl ..
			" grp=" .. tostring( ent.GetRenderGroup and ent:GetRenderGroup() or "?" ) ..
			" parent=" .. tostring( ent:GetParent() ) .. " pos=" .. tostring( ent:GetPos() ) )
	end
end
print( "[v3] vm=" .. tostring( vm ) .. " model=" ..
	tostring( IsValid( vm ) and vm:GetModel() or "?" ) )

-- SERVER TRUTH: save these two lines as sv_probe.lua and run `lua_dofile sv_probe.lua`
-- (server realm) in the same broken state:
--   local h = Entity(1):GetHands()
--   print("[v3-sv] hands=" .. tostring(h) .. " idx=" .. tostring(h and h:EntIndex()) ..
--     " model=" .. tostring(h and h:GetModel() or "?") .. " parent=" ..
--     tostring(h and h:GetParent() or "?") .. " pos=" .. tostring(h and h:GetPos() or "?"))
-- V-A  server hands alive+parented  -> backdoor partial-copy corruption (client-only):
--      then rerun the exit test with `dt_UsePartialChangeEnts 0` - arms surviving the
--      exit seals it (mitigation), and the fix is the partial-path audit.
-- V-B  server hands NULL/other     -> server-side removal/reassignment: find the remover,
--      or fallback `GM:PlayerLeaveVehicle -> ply:SetupHands()` (harmless in MP).
