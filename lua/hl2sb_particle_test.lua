-- HL2SB 粒子系统冒烟测试（只读自检，不产生可见特效）
-- 运行: 控制台 `lua_dofile_cl hl2sb_particle_test.lua`
if not _CLIENT then return end

local ok = function( name, val ) print( "[HL2SB ptest] " .. name .. " = " .. tostring( val ) ) end

-- 1) 独立 Lua 粒子发射器（Nuke Pack 用的路径）
local emitter = ParticleEmitter( Vector( 0, 0, 0 ) )
ok( "ParticleEmitter", emitter ~= nil )
local particle = emitter and emitter:Add( "particles/smokey", Vector( 0, 0, 0 ) )
ok( "emitter:Add 返回粒子", particle ~= nil )
if particle then particle:SetDieTime( 0.1 ) particle:SetStartAlpha( 0 ) particle:SetEndAlpha( 0 ) end
if emitter then emitter:Finish() end

-- 2) 枚举与全局
ok( "PATTACH_ABSORIGIN", PATTACH_ABSORIGIN )
ok( "PATTACH_POINT_FOLLOW", PATTACH_POINT_FOLLOW )
ok( "PrecacheParticleSystem", PrecacheParticleSystem )
ok( "ParticleEffect", ParticleEffect )
ok( "ParticleEffectAttach", ParticleEffectAttach )
ok( "CreateParticleSystem", CreateParticleSystem )
ok( "CreateParticleSystemNoEntity", CreateParticleSystemNoEntity )

-- 3) 元表
local entmeta = FindMetaTable( "Entity" )
ok( "Entity:CreateParticleEffect", entmeta and entmeta.CreateParticleEffect )
ok( "Entity:StopParticles", entmeta and entmeta.StopParticles )
ok( "Entity:StopParticlesInvolving", entmeta and entmeta.StopParticlesInvolving )
ok( "FindMetaTable(CNewParticleEffect)", FindMetaTable( "CNewParticleEffect" ) ~= nil )
local pmeta = FindMetaTable( "CNewParticleEffect" )
if pmeta then
	ok( "CNewParticleEffect:StopEmission", pmeta.StopEmission )
	ok( "CNewParticleEffect:SetControlPoint", pmeta.SetControlPoint )
end

print( "[HL2SB ptest] 完成。带 .pcf 的实测: 见 AGENTS.md §31 的 particleitup 例子" )
