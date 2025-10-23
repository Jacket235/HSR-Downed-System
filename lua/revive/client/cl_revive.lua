function draw.JCircle(PositionX, PositionY, Radius)
    local circle = {}
    local i = 0
    for ang = 0, 360 do
        i = i + 1
        circle[i] = {
            x = PositionX + math.cos(math.rad(ang)) * Radius,
            y = PositionY + math.sin(math.rad(ang)) * Radius
        }
    end
    return circle
end

function draw.JPie(PositionX, PositionY, Radius, StartAng, EndAng)

    StartAng = StartAng - 90
    EndAng = EndAng - 90
    local pie = {
        {x = PositionX, y = PositionY}
    }
    local i = 1
    for ang = StartAng, EndAng do
        i = i + 1
        pie[i] = {
            x = PositionX + math.cos(math.rad(ang)) * Radius,
            y = PositionY + math.sin(math.rad(ang)) * Radius
        }
    end
    return pie
end

function draw.JRing(PositionX, PositionY, Radius, Thickness, StartAng, EndAng)
    render.SetStencilWriteMask( 0xFF )
    render.SetStencilTestMask( 0xFF )
    render.SetStencilReferenceValue( 0 )
    render.SetStencilCompareFunction( STENCIL_ALWAYS )
    render.SetStencilPassOperation( STENCIL_KEEP )
    render.SetStencilFailOperation( STENCIL_KEEP )
    render.SetStencilZFailOperation( STENCIL_KEEP )
    render.ClearStencil()

    render.SetStencilEnable(true)
        render.SetStencilReferenceValue(1)
        render.SetStencilFailOperation(STENCIL_EQUAL)
        render.SetStencilCompareFunction(STENCIL_NEVER)
        surface.DrawPoly(draw.JCircle(PositionX, PositionY, Radius - Thickness))
        render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
        surface.DrawPoly(draw.JPie(PositionX, PositionY, Radius, StartAng, EndAng))
    render.SetStencilEnable(false)
end

hook.Add("CalcView", "downed_state_view", function(ply, pos, ang, fov)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")

	if IsValid(downed_ragdoll) then
		if ply:GetNWBool("downed") then
			downed_ragdoll:ManipulateBoneScale(6, Vector(0, 0, 0))
		else
			downed_ragdoll:ManipulateBoneScale(6, Vector(1, 1, 1))
		end
		
		if ply:GetNWBool("downed") then
			local eyes = downed_ragdoll:GetAttachment(downed_ragdoll:LookupAttachment("eyes"))
            return {
                origin = eyes.Pos,
                ang = ang,
                fov = fov,
                drawviewer = false
            }
		end
	end
end)

hook.Add("HUDPaint", "downed_bleed_out_timer", function()
	if IsValid(LocalPlayer():GetNWEntity("downed_ragdoll")) then
		local downed_ragdoll = LocalPlayer():GetNWEntity("downed_ragdoll")
		local startBleedOutTime = downed_ragdoll:GetNWFloat("bleedOutStartTime", 0)

		local elapsed = CurTime() - startBleedOutTime
    	local fraction = math.Clamp(elapsed / 5, 0, 1)

		surface.SetDrawColor(255, 255, 255, 255)
		draw.JRing(ScrW() / 2, ScrH() / 2, 75, 7, 0, 360 * (1 - fraction))
	end
end)