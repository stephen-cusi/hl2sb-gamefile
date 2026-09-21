--======== Copyleft © 2010-2011, Team Sandbox, Some rights reserved. ========--
--
-- Purpose:
--
--===========================================================================--

include( "shared.lua" )

-- HL2SB (2026-09-21): the old Team Sandbox stub
--     function ENT:DrawModel( flags ) end
-- is GONE, and that is the whole fix for "spawned entities have no model".
-- base_gmodentity aliases onto prop_scripted, so every GMod SENT inherited
-- this table, and a Lua-table function BEATS the C++ metatable method in the
-- __index chain -- meaning every self:DrawModel() from ENT:Draw (both the
-- addon's own and the engine's fallback) resolved to this empty body and
-- drew nothing.  With the stub removed, "DrawModel" falls through to the
-- real C++ Entity:DrawModel binding (lc_baseentity.cpp), exactly like GMod,
-- where DrawModel has always been an engine function and never a Lua stub.

function ENT:ClientThink()
end
