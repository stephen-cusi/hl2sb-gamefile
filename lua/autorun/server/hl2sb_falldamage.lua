-- hl2sb: default sandbox fall damage off.
-- The create-server "Enable real fall damage" checkbox (GameUI) sets
-- mp_falldamage; here we ensure the sandbox default is OFF (0) so an
-- unchecked server never gets real fall damage even if a stale value
-- is left around. Players opting in simply re-enable it.
GetConVar( "mp_falldamage" ):SetInt( 0 )
