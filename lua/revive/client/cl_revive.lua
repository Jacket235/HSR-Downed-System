include("revive/sh_revive.lua")

function createFont()
    surface.CreateFont("plyNickFont", {
        font = "D-DIN",
        size = 72 * (ScrW() / 1600) 
    })
    surface.CreateFont("textFont", {
        font = "D-DIN",
        size = 32 * (ScrW() / 1600)
    })
end

createFont()

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

local EntityMeta = FindMetaTable("Entity")

function EntityMeta:GetPlayerColor()
    return self:GetNWVector("rag_ply_color") or Vector()
end

hook.Add("OnScreenSizeChanged", "abcdefghijklmnopqrstuvwxyz", function()
    createFont()
end)

hook.Add("CalcView", "downed_state_view", function(ply, pos, ang, fov)
	if IsValid(ply:GetNWEntity("downed_ragdoll")) then
        local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")

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
local health_icon = Material("homigrad_style_downs/small-health.png")

hook.Add("HUDPaintBackground", "downed_bleed_out_timer", function()
    local ply = LocalPlayer()
    local rag = ply:GetNWEntity("downed_ragdoll")

	if not IsValid(ply) or not IsValid(rag) or not ply:Alive() then return end

    local scale = ScrW() / 1600
    local savior = rag:GetNWEntity("savior")
    local isBeingRevived = IsValid(savior)

    // Math
    -- Bleed out
    local startBleedOutTime = rag:GetNWFloat("bleedOutStartTime", 0)
    local elapsedBleedOut = CurTime() - startBleedOutTime
    local fractionBleedOut = 1 - math.Clamp(elapsedBleedOut / BLEED_OUT_TIME, 0, 1)

    -- Revive
    local startReviveTime = rag:GetNWFloat("reviveStartTime", 0)
    local elapsedRevive = CurTime() - startReviveTime
    local fractionRevive = math.Clamp(elapsedRevive / REVIVE_TIME, 0, 1)

    // Text properties
    surface.SetFont("textFont")
    local downedMessage = isBeingRevived and "You are being helped up" or "You are bleeding out"
    local textW, textH = surface.GetTextSize(downedMessage)

    // Ring properties
    local pulseSpeed = 4
    local pulse = (math.sin(CurTime() * pulseSpeed) + 1) / 2
    local minGB = 100
    local g = minGB + (255 - minGB) * pulse
    local b = minGB + (255 - minGB) * pulse
    local ringRadius = 20 * scale
    local ringThickSkinJacket = 5 * scale
    local ringColor = isBeingRevived and Color(123, 183, 232, 255) or Color(255, g, b, 255)
    local ringFraction = isBeingRevived and fractionRevive or fractionBleedOut

    // Background box properties
    local boxW, boxH = ((textW + 10) + (ringRadius * 2 + 10)) * scale, 50 * scale
    local boxX, boxY = ScrW() / 2 - (boxW / 2), ScrH() / 2 - (boxH / 2) + (250 * scale)

    // Background box
    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(boxX, boxY, boxW, boxH)

    // Text 
    surface.SetDrawColor(255, 255, 255, 255)
    draw.SimpleText(downedMessage, "textFont", boxX + (textW / 2) + 5, boxY + (boxH / 2), Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    // Timer ring
    surface.SetDrawColor(ringColor)
    draw.JRing(boxX + boxW - (ringRadius) - 5, boxY + (boxH / 2), ringRadius, ringThickSkinJacket, 0, 360 * ringFraction)
end)

hook.Add("PostDrawOpaqueRenderables", "draw_downed_players_icons", function()
    if table.IsEmpty(downedPlayers) then return end

    local lp = LocalPlayer()
    local eyepos = EyePos()
    local maxDist = 4000
    local maxDistSqr = maxDist * maxDist

    for ply, rag in pairs(downedPlayers) do
        if not IsValid(rag) or not IsValid(ply) then continue end
        if ply == LocalPlayer() then continue end
        if eyepos:DistToSqr(rag:GetPos()) > maxDistSqr then continue end

        local pos = rag:GetPos()
        pos.z = pos.z + 20

        local ang = (eyepos - pos):Angle()
        ang:RotateAroundAxis(ang:Right(), 270)
        ang:RotateAroundAxis(ang:Up(), 90)

        local distance = eyepos:DistToSqr(pos)

        local pausedElapsed = rag:GetNWFloat("bleedOutPausedElapsed", -1)

        local startBleedOutTime = rag:GetNWFloat("bleedOutStartTime", 0)
        local elapsedBleedOut = 0
        if pausedElapsed >= 0 then
            elapsedBleedOut = pausedElapsed
        else
            elapsedBleedOut = CurTime() - startBleedOutTime
        end    
        local fractionBleedOut = 1 - math.Clamp(elapsedBleedOut / BLEED_OUT_TIME, 0, 1)

        local startReviveTime = rag:GetNWFloat("reviveStartTime", 0)
        local elapsedRevive = CurTime() - startReviveTime
        local fractionRevive = math.Clamp(elapsedRevive / REVIVE_TIME, 0, 1)
        
        cam.IgnoreZ(true)
        cam.Start3D2D(pos, ang, math.max(240, math.sqrt(distance)) / 2400)
            surface.SetMaterial(Material("vgui/white"))

            if LocalPlayer() == rag:GetNWEntity("savior") then
                surface.SetDrawColor(11, 16, 183, 255)
                draw.JRing(0, 0, 75, 10, 0, 360 * fractionRevive)
            end

            surface.SetDrawColor(57, 59, 61, 255)
            draw.JRing(0, 0, 60, 10, 0, 360)
            surface.SetDrawColor(167, 15, 16, 255)
            draw.JRing(0, 0, 60, 10, 0, 360 * fractionBleedOut)

            surface.SetDrawColor(123, 183, 232, 255)
            surface.SetMaterial(health_icon) 
            surface.DrawTexturedRect(-32, -32, 64, 64)

            draw.SimpleText(ply:Nick(), "plyNickFont", 0, -110, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) 
        cam.End3D2D()
        cam.IgnoreZ(false)
    end
end)

net.Receive("downedPlayerLocations", function()
    downedPlayers = net.ReadTable()
end)