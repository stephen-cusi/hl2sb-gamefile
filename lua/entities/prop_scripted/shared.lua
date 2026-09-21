--======== Copyleft © 2010-2011, Team Sandbox, Some rights reserved. ========--
--
-- Purpose:
--
--===========================================================================--

ENT.__base = "prop_scripted"
ENT.__factory = "CBaseAnimating"

function ENT:Initialize()
end

function ENT:StartTouch( pOther )
end

function ENT:Touch( pOther )
end

function ENT:EndTouch( pOther )
end

function ENT:VPhysicsUpdate( pPhysics )
end

-- HL2SB (2026-09-21): GMod 的基类表为每个 ENT:On* 钩子都提供默认空实现，
-- 而 prop_scripted 一直缺 OnRemove。npc_scp173 的 Initialize 会把
-- BaseClass.OnRemove 拷成自己的方法（`function self:OnRemove(...) return
-- BaseClass.OnRemove(self, ...)`），基类没有时这一行直接报
-- "attempt to call a nil value (field 'OnRemove')"，Initialize 中断。
function ENT:OnRemove()
end
