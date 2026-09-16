--========== HL2SB - GMod compat ==========--
--
-- Purpose: server entry point of the base_nextbot entity (see shared.lua for
--          the contract and sv_nextbot.lua for the behaviour layer).
--
--   HL2SB's entity loader reads lua/entities/<name>/init.lua on the server and
--   shared.lua on both realms, so this file only has to pull the shared half in
--   - the same shape lua/entities/prop_scripted/init.lua uses.
--===========================================================================--

include( "shared.lua" )
