-- hl2sb: default sandbox fall damage off.
-- The create-server "Enable real fall damage" checkbox (GameUI) sets
-- mp_falldamage; here we ensure the sandbox default is OFF (0) so an
-- unchecked server never gets real fall damage even if a stale value
-- is left around. Players opting in simply re-enable it.
-- HL2SB: GetConVar returns nil when the name does not exist (GMod contract),
-- so this used to raise "attempt to call a nil value (method 'SetInt')" on every
-- level -- and on this ARM64EC host every raised Lua error is a chance to crash.
local hl2sb_fallDamage = GetConVar and GetConVar( "mp_falldamage" )

if ( hl2sb_fallDamage ~= nil and hl2sb_fallDamage.SetInt ~= nil ) then
	hl2sb_fallDamage:SetInt( 0 )
end
