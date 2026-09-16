include('shared.lua')

ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Draw()
	self.Entity:DrawModel()
end

language.Add("npc_shaklin_scp096", "SCP 096")
killicon.Add("npc_shaklin_scp096","Hud/killicons/default",Color(255,255,255));
