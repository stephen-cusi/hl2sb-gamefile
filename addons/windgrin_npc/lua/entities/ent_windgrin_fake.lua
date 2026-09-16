AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Editable		= true
ENT.PrintName		= "Windgrin greenhat"
ENT.Spawnable 		= false
ENT.AdminSpawnable 	= false



function ENT:Initialize()
	if( SERVER ) then
		 self:SetNWInt( "wc", math.random(1,2) )
		self:SetModel( "models/props/de_nuke/hr_nuke/nuke_hard_hat/nuke_hard_hat.mdl" )
	
		self:SetColor(Color(0,255,0))
		self:SetTrigger( true )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetModelScale( self:GetModelScale() * 4, 0 )
		self:SetVar( "hit", false )
		
		local phys = self:GetPhysicsObject()
		phys:EnableGravity( false )
	end
	
	if( CLIENT ) then
		local vec = self:GetPos()
		local emitter = ParticleEmitter( vec, false )
		
		//effects/fire_cloud1
		for cycles = 1, 10 do
			local particle = emitter:Add( Material( "effects/fire_cloud1" ), vec )
			if( particle ) then
				particle:SetVelocity( VectorRand() * 40 )
				particle:SetColor( 50, 200, 100 ) 
				particle:SetLifeTime( 0 )
				particle:SetDieTime( 1 )
				particle:SetAngles( Angle( math.Rand( 0, 360 ), 0, 0 ) )
				particle:SetAngleVelocity( Angle( math.Rand( -1, 1 ), 0, 0 ) )
				particle:SetStartSize( 20 )
				particle:SetEndSize( 10 )
				particle:SetStartAlpha( 255 )
				particle:SetEndAlpha( 0 )
				particle:SetGravity( Vector( 0, 0, 60 ) )
			end
		end
		
		emitter:Finish()
	end
end

if( SERVER ) then
	function ENT:Think()
		local parent = self:GetParent()
		
		if( parent:IsValid() ) then
			if( parent:IsPlayer() ) then
				if( parent:Health() <= 0 ) then
					self:Remove()
				end
			end
		end
	end

	function ENT:PhysicsUpdate( )
		if( !self:GetVar( "hit", NULL ) ) then
			if( self:GetVelocity():Length() < 1000 ) then
				self:SetVar( "hit", true )
				self:Fire( "Kill", "", 10 )
				local phys = self:GetPhysicsObject()
				phys:EnableGravity( true )
			end
		end
	end

	function ENT:PhysicsCollide( data, phys )
		if( !self:GetVar( "hit", NULL ) ) then
			if( data.Speed > 100 ) then
				local hitEnt = data.HitEntity
				
				if( hitEnt:GetClass() != "ent_windgrin_throw" && hitEnt != self.Owner ) then
					self:SetMoveType( MOVETYPE_NONE )
					self:SetPos( data.HitPos )
					self:SetSolid( SOLID_NONE )
					
					if( hitEnt:IsValid()) then
						//if hitEnt:Health() > 0 then
							hitEnt:TakeDamage( 25, self.Owner, self )
						
							self:SetParent( hitEnt, -1 )
							if not hitEnt:IsPlayer() then return end
							
							if( CLIENT ) then return end
                               local HangProps = {
    [1] = {model = "models/props_docks/dock02_pole02a_256.mdl", pos = Vector(100, 0, 39), ang = Angle(0,0,0)},
    [2] = {model = "models/props_docks/dock01_pole01a_128.mdl", pos = Vector(43, 0, 135), ang = Angle(0, -90, 90)}
}

local VictimPos1 = {
    Vector(0.08349609375, 4.9041748046875, 10.35856628418),
    Vector(-7.62841796875, 2.5777587890625, 19.235778808594),
    Vector(7.866943359375, 3.7470703125, 19.656280517578),
    Vector(9.823974609375, 2.7562255859375, 8.1713256835938),
    Vector(10.78173828125, -0.431640625, -2.8172454833984),
    Vector(-9.223876953125, 2.2598876953125, 7.7528839111328),
    Vector(-10.81884765625, -2.521240234375, -2.6094360351563),
    Vector(-4.3515625, 0.2113037109375, -0.05419921875),
    Vector(-7.78466796875, -0.5653076171875, -17.549179077148),
    Vector(0.08544921875, 1.6834716796875, 25.412673950195),
    Vector(4.400390625, -0.2120361328125, 0.064102172851563),
    Vector(6.23095703125, -0.237548828125, -17.736618041992),
    Vector(8.871337890625, 1.25146484375, -33.981475830078),
    Vector(-9.429443359375, 2.0859375, -33.777191162109)
}

local VictimAng1 = {
    Angle(-87.673042297363, -109.66005706787, 294.1647644043),
    Angle(82.838233947754, -165.22711181641, 201.99559020996),
    Angle(79.187240600586, -26.850950241089, 355.43997192383),
    Angle(73.147010803223, -73.275413513184, 310.1682434082),
    Angle(80.774833679199, -150.97926330566, 325.01263427734),
    Angle(63.71996307373, -112.01448822021, 253.77954101563),
    Angle(77.913925170898, -69.091110229492, 173.12385559082),
    Angle(78.631988525391, -167.21780395508, 216.82838439941),
    Angle(79.116714477539, 121.81723022461, 146.85758972168),
    Angle(-89.117118835449, 92.446853637695, 267.04473876953),
    Angle(83.278358459473, -2.6300358772278, 12.258254051208),
    Angle(79.429931640625, 29.419277191162, 43.093002319336),
    Angle(37.975448608398, -70.136756896973, 293.39251708984),
    Angle(42.589946746826, -95.914726257324, 258.73498535156)
}

-- Kick leg = 9 and 14
local KickerPos = {
    Vector(0.151123046875, -0.55889892578125, 12.428649902344),
    Vector(-6.949951171875, -4.727294921875, 21.128128051758),
    Vector(8.18798828125, -4.1649780273438, 20.041198730469),
    Vector(12.109619140625, 6.8145751953125, 19.155548095703),
    Vector(8.816162109375, 16.727844238281, 14.390106201172),
    Vector(-10.9814453125, -12.980773925781, 13.879943847656),
    Vector(-7.9189453125, -24.001403808594, 14.877258300781),
    Vector(-4.06396484375, 0.56243896484375, -0.14239501953125),
    Vector(-0.764404296875, 15.5107421875, -9.5738525390625),
    Vector(1.176025390625, -7.4561767578125, 26.153648376465),
    Vector(3.85009765625, -0.55645751953125, -0.035125732421875),
    Vector(5.841796875, -1.1864624023438, -17.723190307617),
    Vector(4.7431640625, 4.4840698242188, -33.206146240234),
    Vector(0.028076171875, 27.153869628906, 2.1262817382813)
}

local KickerAng = {
    Angle(-72.853500366211, -77.192611694336, 258.47763061523),
    Angle(38.269737243652, -116.13293457031, 218.30332946777),
    Angle(4.3439903259277, 70.343925476074, 147.32099914551),
    Angle(24.522411346436, 108.37782287598, 157.29452514648),
    Angle(15.059949874878, 50.6491355896, 180.38879394531),
    Angle(-4.983060836792, -74.469413757324, 230.35047912598),
    Angle(1.2094515562057, -73.130561828613, 136.18098449707),
    Angle(32.704917907715, 77.20344543457, 82.96809387207),
    Angle(-45.073616027832, 86.105369567871, 82.506660461426),
    Angle(-79.46248626709, -65.311363220215, 68.129730224609),
    Angle(82.879898071289, -27.148105621338, 318.85842895508),
    Angle(69.541847229004, 100.96334838867, 80.36100769043),
    Angle(31.048385620117, -61.657707214355, 279.41061401367),
    Angle(-19.616451263428, 81.610832214355, 87.282814025879)
}

if self:GetNWInt("wc",0) == 1 then 
   hitEnt:EmitSound("windgrinbot/run.mp3")
    local Ragdoll = ents.Create("prop_ragdoll")

                Ragdoll:SetModel(hitEnt:GetModel())
                Ragdoll:SetPos(hitEnt:GetPos())
                Ragdoll:SetAngles(hitEnt:GetAngles())
                Ragdoll:Spawn()
                Ragdoll:Activate()
          

            if hitEnt:IsPlayer() then   
			hitEnt:StripWeapons() 
                hitEnt:Spectate(OBS_MODE_CHASE)
                hitEnt:SpectateEntity(Ragdoll)
				timer.Simple(10,function() 
     
	  hitEnt:UnSpectate()
	  hitEnt:KillSilent()
	  Ragdoll:Remove()
	end)
				end

                local HangOn
                for k,v in ipairs(HangProps) do
                    local prop = ents.Create("fadmin_jail")
                    prop.hitEnt = prop
                    prop:SetModel(v.model)
                    prop:SetPos(v.pos + hitEnt:GetPos())
                    prop:SetAngles(v.ang)
                    prop:Spawn()
                    prop:Activate()

                    local phys = prop:GetPhysicsObject()
                    if phys:IsValid() then phys:EnableMotion(false) end

             
                    HangOn = prop -- Hang on the last prop
                end
                if not HangOn then return false end

                Ragdoll:SetPos(HangOn:GetPos() - Vector(-50,0,10))
                timer.Simple(0.2, function() constraint.Rope(Ragdoll, HangOn, 10, 0, Vector(-2.4,0,-0.6), Vector(0,0,53), 10, 40, 0, 4, "cable/rope", false) end)

	elseif self:GetNWInt("wc",0) == 2 then
	 local Ragdoll = ents.Create("prop_ragdoll")

                Ragdoll:SetModel(hitEnt:GetModel())
                Ragdoll:SetPos(hitEnt:GetPos())

                Ragdoll:Spawn()
                Ragdoll:Activate()
hitEnt:EmitSound("windgrinbot/fake.mp3")
                -- The rotation angle (the direction the ragdoll is looking at)
                local angle = Angle(0, hitEnt:EyeAngles().y + 90, 0)
                for i = 1, Ragdoll:GetPhysicsObjectCount() do
                    local phys = Ragdoll:GetPhysicsObjectNum(i)
                    if phys and phys:IsValid() and VictimPos1[i] then
                        phys:EnableMotion(false)
                        -- Copy the vector
                        local pos = Vector(VictimPos1[i].x, VictimPos1[i].y, VictimPos1[i].z)
                        pos:Rotate(angle)

                        phys:SetPos(pos + Ragdoll:GetPos())
                        phys:SetAngles(VictimAng1[i] + angle)
                    end
                end

                -- The kicker's position is behind the target with distance 35, translated to stand a bit higher
                local aimVec = Vector(hitEnt:GetAimVector().x, hitEnt:GetAimVector().y, 0)
                local kickerPos = hitEnt:GetPos() - aimVec * 35 + Vector(0, 0, 5)
                local Kicker = ents.Create("prop_ragdoll")
                Kicker:SetModel("models/Police.mdl")
                Kicker:SetPos(kickerPos)
                Kicker:Spawn()
                Kicker:Activate()

                Kicker:EmitSound("npc/combine_soldier/vo/contactconfirmprosecuting.wav", 100, 100)

                for i = 1, Kicker:GetPhysicsObjectCount() do
                    local phys = Kicker:GetPhysicsObjectNum(i)
                    if phys and phys:IsValid() then
                        phys:EnableMotion(false)
                        if i == 8 or i == 9 or i == 14 then
                            phys:EnableCollisions(false)
                            timer.Simple(2, function()
                                if phys:IsValid() then
                                    phys:EnableMotion(true)
                                    phys:Wake()
                                    phys:SetVelocity(aimVec - Vector(0, 0, 1000))
                                end
                            end)
                        end

                        local pos = Vector(KickerPos[i].x, KickerPos[i].y, KickerPos[i].z)
                        pos:Rotate(angle)
                        phys:SetPos(pos + Kicker:GetPos())
                        phys:SetAngles(KickerAng[i] + angle)
                    end

                end

                hitEnt:StripWeapons()
				
                hitEnt:KillSilent()
              

                timer.Simple(2.1, function() if IsValid(Ragdoll) then
                    Ragdoll:EmitSound("physics/body/body_medium_impact_hard6.wav", 100, 100)
                    for i = 1, Ragdoll:GetPhysicsObjectCount() do
                        local phys = Ragdoll:GetPhysicsObjectNum(i)
                        if phys and phys:IsValid() then
                            phys:EnableCollisions(false)
                            phys:EnableMotion(true)
                            phys:SetVelocity((aimVec:GetNormalized() + Vector(0, 0, 1)) * 1000)
                        end
                    end
                end end)

                timer.Simple(2.2, function() if IsValid(Ragdoll) then
                    for i = 1, Ragdoll:GetPhysicsObjectCount() do
                        local phys = Ragdoll:GetPhysicsObjectNum(i)
                        if phys and phys:IsValid() then
                            phys:EnableCollisions(true)
                        end
                    end
                end end)

                timer.Simple(5, function()

                    if IsValid(Kicker) then
                        Kicker:Remove()
						
                    end
                end)
                timer.Simple(10,function() if IsValid(Ragdoll) then Ragdoll:Remove()
				end end)
				end
	
	
	
						//end
					end
					
					self:SetVar( "hit", true )
					self:Fire( "Kill", "", 10 )
					sound.Play( Sound( "undertale/sans/smash.wav" ), self:GetPos() )
				end
			end
		end
	end
end