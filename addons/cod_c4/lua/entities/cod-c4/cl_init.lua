include( "shared.lua" )

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:Draw()
	self:DrawShadow( false )
	self:DrawModel()
	local RedLightConVar = GetConVar("C4_RedLight")
	if C4Flash and RedLightConVar and RedLightConVar:GetBool() then
		local pos = self:GetPos() + self:GetUp() * 4.3 + self:GetForward() * -2.75 -- Position of the sprite
		local size = 15 -- Size of the sprite
		local color = Color(237, 72, 65, 255) -- Color of the sprite (red)
		local sprite =  Material("sprites/glow04_noz") -- The sprite texture
		render.SetMaterial( sprite )
		render.DrawSprite(pos, size, size, color)
	end
end

function ENT:Initialize()
	if not timer.Exists("C4FlashTimer") then
		C4Flash = false
		timer.Create("C4FlashTimer", 1, 0, function()
			C4Flash = true
			timer.Simple(0.1, function()
				C4Flash = false
			end)
		end)
	end
end

surface.CreateFont( "Arialfc4", {
	font = "Arial",
	antialias = true,
	size = 35,
	outline = true
} )


hook.Add("HUDPaint","C4HudText",function()
	local LocalPlayerEntity = LocalPlayer()
	if not IsValid(LocalPlayerEntity) or not LocalPlayerEntity:Alive() then
		return
	end

	local trace = util.TraceLine({
		start = LocalPlayerEntity:EyePos(),
		endpos = LocalPlayerEntity:EyePos() + LocalPlayerEntity:EyeAngles():Forward() * 85,
		filter = {LocalPlayerEntity}
	})
	local visible_entity = trace.Entity
	if not IsValid(visible_entity) then
		return
	end
	local player_to_entity_distance = LocalPlayer():EyePos():Distance(visible_entity:GetPos())
	if (visible_entity:GetClass()  == "cod-c4") then
		if (player_to_entity_distance < 85) and visible_entity:IsValid() then
			local ActiveWeapon = LocalPlayerEntity:GetActiveWeapon()
			if visible_entity:GetNWString("OwnerID") == LocalPlayerEntity:SteamID() and IsValid(ActiveWeapon) and ActiveWeapon:GetClass() == "seal6-c4" then
				if visible_entity:GetNWBool("Hit") then
					local useKey = input.LookupBinding("+reload") or "R" -- fallback to "R" if not bound
					draw.DrawText("Press " .. string.upper(useKey) .. " to Pick Up C4", "Arialfc4", ScrW()/2, ScrH()/2+200, Color(255, 255, 255, 255),TEXT_ALIGN_CENTER)
				end
			end
		end
	end
end)