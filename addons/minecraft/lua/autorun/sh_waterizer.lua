-- Player, Move hook
hook.Add( "Move", "WaterizerHook", function( ply, move )
    -- Player is touching water
    if ply.w_WaterEnts then
        local Water = false
        for k, e in ipairs(ply.w_WaterEnts) do
            -- Check if the player is inside the water
            if  IsValid(e) then
                if e:IsPointInside( ply:GetPos() + Vector(0, 0, 32) ) then
                    Water = e
                    break
                end
            else
                table.remove(ply.w_WaterEnts, k)
                if #(ply.w_WaterEnts) == 0 then
                    ply.w_WaterEnts = nil
                    -- Reset gravity
                    if ply.w_IsInWater then
                        if SERVER then
                            ply:SetGravity(1)
                        end
                        ply.w_IsInWater = false
                    end
                end
            end
        end
        if IsValid( Water ) then
            -- Update gravity
            if not ply.w_IsInWater then
                if SERVER then
                    ply:SetGravity(0.1)
                end
                ply.w_IsInWater = true
            end
            -- The player is inside a valid water entity
            local FavVel = nil
            if ply:KeyDown( IN_FORWARD ) then
                -- Swim forward
                FavVel = ply:EyeAngles():Forward()
            elseif ply:KeyDown( IN_BACK ) then
                -- Swim backward
                FavVel = ply:EyeAngles():Forward()*-1
            end
            if ply:KeyDown( IN_MOVERIGHT ) then
                -- Right
                FavVel = ( FavVel or Vector(0,0,0) ) * 0.6 + ply:GetRight() * 0.6
            elseif ply:KeyDown( IN_MOVELEFT ) then
                -- Left
                FavVel = ( FavVel or Vector(0,0,0) ) * 0.6 + ply:GetRight() * -0.6
            end
            if ply:KeyDown( IN_JUMP ) then
                -- Swim upside
                if not FavVel then FavVel = Vector(0,0,0) end
                FavVel.z = 0.8
            end
            if not FavVel then
                FavVel = Vector(0, 0, -0.2)
            end
            -- Actually perform move
            local curVel = move:GetVelocity()
            FavVel = FavVel * (100 - Water:GetDensity()) * 5 + Water:GetVelocity()
            move:SetVelocity( curVel + (FavVel - curVel) * Water:GetDamping() / 100 )
        elseif ply.w_IsInWater then
            -- Reset gravity
            if SERVER then
                ply:SetGravity(1)
            end
            ply.w_IsInWater = false
        end
    end
end )

if SERVER then
    w_EntsInWater = {}
    -- Props, Tick hook
    hook.Add( "Tick", "WaterizerHook", function( )
        for k, ent in ipairs(w_EntsInWater) do
            if IsValid( ent ) and ent.w_WaterEnts then
                local Water = false
                for k, e in ipairs(ent.w_WaterEnts) do
                    -- Check if the player is inside the water
                    if IsValid(e) then
                        if e:IsPointInside( ent:LocalToWorld( ent:OBBCenter() ) ) then
                            Water = e
                            break
                        end
                    else
                        table.remove(ent.w_WaterEnts, k)
                        if #(ent.w_WaterEnts) == 0 then
                            ent.w_WaterEnts = nil
                            if ent.w_IsInWater then
                                ent:SetGravity(1)
                                ent.w_IsInWater = false
                            end
                        end
                    end
                end
                if IsValid( Water ) then
                    -- Update gravity
                    if not ent.w_IsInWater then
                        ent:SetGravity(0.1)
                        ent.w_IsInWater = true
                    end
                    -- Move prop here
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then
                        -- Calc new force
                        local curVel = phys:GetVelocity()
                        local massMup = math.Clamp( ( Water:GetBuoyancy() / 10 - phys:GetMass() ) / 10, -2, 3.5 )
                        local FavVel = Vector(0, 0, massMup) * (100 - Water:GetDensity()) + Water:GetVelocity()
                        phys:SetVelocityInstantaneous( curVel + (FavVel - curVel) * Water:GetDamping() / 100 )
                    end
                elseif ent.w_IsInWater then
                    -- Reset gravity
                    ent:SetGravity(1)
                    ent.w_IsInWater = false
                end
            else
                table.remove(w_EntsInWater, k)
            end
        end
    end )
end
