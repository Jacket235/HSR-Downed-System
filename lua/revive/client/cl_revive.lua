surface.CreateFont("plyNickFont", {
    font = "Arial",
    size = 72
})

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

local downedPlayers = {}

hook.Add("HUDPaint", "downed_bleed_out_timer", function()
	if IsValid(LocalPlayer():GetNWEntity("downed_ragdoll")) and LocalPlayer():Alive() then
		local downed_ragdoll = LocalPlayer():GetNWEntity("downed_ragdoll")
		local startBleedOutTime = downed_ragdoll:GetNWFloat("bleedOutStartTime", 0)

		local elapsed = CurTime() - startBleedOutTime
    	local fraction = math.Clamp(elapsed / 30, 0, 1)

		surface.SetDrawColor(255, 255, 255, 255)
		draw.JRing(ScrW() / 2, ScrH() / 2, 75, 7, 0, 360 * (1 - fraction))
	end
end)

hook.Add("PostDrawOpaqueRenderables", "drawbullshit", function()
    local lp = LocalPlayer()
    local eyepos = EyePos()
    local maxDist = 4000
    local maxDistSqr = maxDist * maxDist

    for ply, rag in pairs(downedPlayers) do
        if not IsValid(rag) then continue end
        if ply == LocalPlayer() then continue end
        if eyepos:DistToSqr(rag:GetPos()) > maxDistSqr then continue end

        local pos = rag:GetPos()
        pos.z = pos.z + 40

        local ang = (eyepos - pos):Angle()
        ang:RotateAroundAxis(ang:Right(), 270)
        ang:RotateAroundAxis(ang:Up(), 90)

        local distance = eyepos:DistToSqr(pos)

        local startBleedOutTime = rag:GetNWFloat("bleedOutStartTime", 0)

        local elapsed = CurTime() - startBleedOutTime
        local fraction = math.Clamp(elapsed / 30, 0, 1)

        cam.IgnoreZ(true)
        cam.Start3D2D(pos, ang, math.max(240, math.sqrt(distance)) / 2400)
            surface.SetMaterial(Material("vgui/white"))

            surface.SetDrawColor(0, 0, 0, 200)
            surface.DrawPoly(draw.JCircle(0, 0, 60)) 

            surface.SetDrawColor(100, 100, 100, 255)
            draw.JRing(0, 0, 60, 5, 0, 360)
            surface.SetDrawColor(250, 27, 27, 255)
            draw.JRing(0, 0, 60, 5, 0, 360 * (1 - fraction))
        cam.End3D2D()
        cam.IgnoreZ(false)
    end
end)

net.Receive("downedPlayerLocations", function()
    downedPlayers = net.ReadTable()
end)