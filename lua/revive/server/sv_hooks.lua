util.AddNetworkString("downedPlayerLocation")

include("revive/sh_revive.lua")

hook.Add("PlayerHurt", "HSR_ph", function(ply, atkr, hp, dmg)
	if not ply:GetNWBool("downed") and hp <= 0  then 
		ply:SetHealth(100)

		local ragdoll = HSR.createDownedRagdoll(ply)
		if not IsValid(atkr) or atkr:IsWorld() or atkr == ply then
			ragdoll.attacker = ply
		else
			ragdoll.attacker = atkr
		end
		if IsValid(ragdoll.attacker) and (atkr:IsPlayer() or atkr:IsNPC())  then
			ragdoll.attackerWeapon = atkr:GetActiveWeapon()
		end
		HSR.storeBones(ragdoll, ply)
		HSR.storeWeapons(ragdoll, ply)


		local controller = HSR.createRagdollBullseye(ply, ragdoll)
		HSR.downedPlayers[ply] = ragdoll
	end
end)

hook.Add("OnEntityCreated", "HSR_target_bullseye", function(ent)
	timer.Simple(1, function()
		if not IsValid(ent) then return end
		
		if ent:GetClass() == "npc_bullseye" then
			HSR.setupBullseyeRelationship(ent)
		elseif ent:IsNPC() then	
			HSR.updateBullseyeRelationship(ent)
		end
	end)
end)

hook.Add("Think", "HSR_bleed_out", function()
	if table.IsEmpty(HSR.downedPlayers) then return end

	for ply, rag in pairs(HSR.downedPlayers) do
		if not ply:GetNWBool("downed") or not IsValid(rag) or not IsValid(ply) then continue end

		local bleed_out_time = GetConVar("hsr_ragdoll_bleed_out_time"):GetInt()
	    local give_up_time = GetConVar("hsr_ragdoll_give_up_time"):GetInt()

		local savior = rag:GetNWEntity("savior")
		local startBleedOutTime = rag:GetNWFloat("bleedOutStartTime")
		local startGiveUpTime = rag:GetNWFloat("giveUpStartTime")

		// This checks if player is being revived
		if IsValid(savior) and not rag.pauseBleedOutTime then
			rag.pauseBleedOutTime = CurTime()
			rag:SetNWFloat("bleedOutPausedElapsed", CurTime() - startBleedOutTime)
		end
		if not IsValid(savior) and rag.pauseBleedOutTime then
			local pauseDuration = CurTime() - rag.pauseBleedOutTime
			rag.pauseBleedOutTime = nil
			rag:SetNWFloat("bleedOutStartTime", startBleedOutTime + pauseDuration)
			rag:SetNWFloat("bleedOutPausedElapsed", -1)
			startBleedOutTime = rag:GetNWFloat("bleedOutStartTime")
		end

		// This checks if the player is giving up
		if ply:KeyDown(IN_JUMP) and not (startGiveUpTime >= 0) then
			rag:SetNWFloat("giveUpStartTime", CurTime())
		end
		if not ply:KeyDown(IN_JUMP) and (startGiveUpTime >= 0) then
			rag:SetNWFloat("giveUpStartTime", -1)
		end

		local elapsedTime = CurTime() - startBleedOutTime
		local elapsedGiveUpTime = startGiveUpTime > 0 and CurTime() - startGiveUpTime or 0
		
		if rag.pauseBleedOutTime then continue end

		if elapsedTime >= bleed_out_time or elapsedGiveUpTime >= give_up_time then
			local attacker = IsValid(rag.attacker) and rag.attacker or ply
			local inflictor = IsValid(rag.attackerWeapon) and rag.attackerWeapon or attacker

		    local dmg = DamageInfo()
		    dmg:SetDamage(ply:Health() + 1)
		    dmg:SetAttacker(attacker)
		    dmg:SetInflictor(inflictor)
		    dmg:SetDamageType(DMG_GENERIC)

		    ply:TakeDamageInfo(dmg)
		end
	end
end)

hook.Add("Think", "HSR_ragdoll_control", function()
	if table.IsEmpty(HSR.downedPlayers) then return end

	for ply, rag in pairs(HSR.downedPlayers) do
		if not IsValid(ply) then
			if IsValid(rag) then rag:Remove() end

			HSR.downedPlayers[ply] = nil
			net.Start("downedPlayerLocation")
			    net.WriteEntity(NULL)       
			    net.WriteEntity(ply)        
			net.Send(player.GetAll())

			continue
		end
		if not ply:GetNWBool("downed") or not IsValid(ply:GetNWEntity("downed_ragdoll")) then continue end

		local downed_ragdoll = rag

		local headIndex = downed_ragdoll:LookupAttachment("eyes")
		local head = downed_ragdoll:GetAttachment(headIndex)

		local trace = util.TraceLine({
			start = head.Pos,
			endpos = head.Pos + ply:EyeAngles():Forward() * 150,
			filter = { ply, downed_ragdoll }
		})

		-- weak arm settings (injured feel)
        local springStrength = 15     -- weak pull
        local damping = 9             -- strong slowdown

		if ply:KeyDown(IN_ATTACK) and downed_ragdoll.LeftHandPhys then
			local phys = downed_ragdoll:GetPhysicsObjectNum(downed_ragdoll.LeftHandPhys)
			if not IsValid(phys) then continue end

            local targetPos = trace.HitPos
            local currentPos = phys:GetPos()
            local dir = targetPos - currentPos

            local dist = dir:Length()
            dir:Normalize()

            local vel = phys:GetVelocity()
            local force = dir * dist * springStrength - vel * damping

            -- clamp force so it can’t drag the body
            force.x = math.Clamp(force.x, -120, 120)
            force.y = math.Clamp(force.y, -120, 120)
            force.z = math.Clamp(force.z, -120, 120)

            phys:ApplyForceCenter(force)
		end

		if ply:KeyDown(IN_ATTACK2) then
			local phys = downed_ragdoll:GetPhysicsObjectNum(downed_ragdoll.RightHandPhys)
			if not IsValid(phys) then continue end

            local targetPos = trace.HitPos
            local currentPos = phys:GetPos()
            local dir = targetPos - currentPos

            local dist = dir:Length()
            dir:Normalize()

            local vel = phys:GetVelocity()
            local force = dir * dist * springStrength - vel * damping

            -- clamp force so it can’t drag the body
            force.x = math.Clamp(force.x, -120, 120)
            force.y = math.Clamp(force.y, -120, 120)
            force.z = math.Clamp(force.z, -120, 120)

            phys:ApplyForceCenter(force)
		end

		net.Start("downedPlayerLocation")
			net.WriteEntity(rag)
			net.WriteEntity(ply)
		net.Send(player.GetAll())
	end
end)

hook.Add("Think", "HSR_reviving", function()
	if table.IsEmpty(HSR.downedPlayers) then return end
 
	for ply, rag in pairs(HSR.downedPlayers) do
		local savior = rag:GetNWEntity("savior")

		if IsValid(savior) and not savior:IsNPC() then
			if not savior:KeyDown(IN_USE) then
				rag:SetNWEntity("savior", NULL)
				rag:SetNWFloat("reviveStartTime", CurTime())
			end

			local revive_time = GetConVar("hsr_ragdoll_revive_time"):GetInt()

			local elapsedTime = CurTime() - rag:GetNWFloat("reviveStartTime") 

			if elapsedTime >= revive_time then 
				HSR.revivePlayer(ply)

				HSR.downedPlayers[ply] = nil
				net.Start("downedPlayerLocation")
				    net.WriteEntity(NULL)       
				    net.WriteEntity(ply)        
				net.Send(player.GetAll())		
			end
		end
	end
end)

local nextNPCCheck = 0
local assignedNPCs = {}

hook.Add("Think", "HSR_npc_reviving", function()
	if GetConVar("hsr_npc_allowed_revive"):GetInt() <= 0 then return end
	if table.IsEmpty(HSR.downedPlayers) then return end
	if CurTime() < nextNPCCheck then return end
	nextNPCCheck = CurTime() + 1

	local maxNPCSearchRadius = GetConVar("hsr_ragdoll_npc_search_radius"):GetInt()
	local reviveDistance = GetConVar("hsr_ragdoll_npc_revive_radius"):GetInt()
	
	// Find a downed player to help
	for ply, rag in pairs(HSR.downedPlayers) do
		if not IsValid(rag) or not ply:GetNWBool("downed") then continue end

		local npcSavior = assignedNPCs[ply]
		if IsValid(npcSavior) then
			local dist = npcSavior:GetPos():DistToSqr(rag:GetPos())

			if dist <= reviveDistance * reviveDistance then
				local revive_time = GetConVar("hsr_ragdoll_revive_time"):GetInt()

				if not npcSavior.isReviving then
					rag:SetNWEntity("savior", npcSavior)
					rag:SetNWFloat("reviveStartTime", CurTime())
					npcSavior.isReviving = true
				end

				local elapsedTime = CurTime() - rag:GetNWFloat("reviveStartTime", CurTime())

				if npcSavior.isReviving and elapsedTime >= revive_time then
					HSR.revivePlayer(ply)

					HSR.downedPlayers[ply] = nil
					npcSavior.isReviving = false
					assignedNPCs[ply] = nil
					net.Start("downedPlayerLocation")
					    net.WriteEntity(NULL)       
					    net.WriteEntity(ply)        
					net.Send(player.GetAll())		
				end
			end

			npcSavior:SetLastPosition(rag:GetPos())
			npcSavior:SetSchedule(SCHED_FORCED_GO_RUN)

			continue 
		end

		// Find a suitable NPC
		for _, npc in ipairs(ents.FindByClass("npc_*")) do
			if not IsValid(npc) then continue end
			if not npc.HasCondition then continue end
			if npc:HasCondition(COND.SEE_ENEMY) or npc:HasCondition(COND.HEAVY_DAMAGE) then continue end
			if npc:GetClass() == "npc_bullseye" then continue end

			local disp = npc:Disposition(ply)

			if disp != D_LI and disp != D_NU then continue end

			if npc:GetPos():DistToSqr(rag:GetPos()) > maxNPCSearchRadius * maxNPCSearchRadius then continue end

			npc.reviveTarget = rag
			assignedNPCs[ply] = npc

			npc:SetLastPosition(rag:GetPos())
			npc:SetSchedule(SCHED_FORCED_GO_RUN)

			break
		end
	end

	for ply, npc in pairs(assignedNPCs) do
		if not IsValid(ply) or not IsValid(npc) then
			assignedNPCs[ply] = nil
			continue
		end

		if not ply:GetNWBool("downed") then
			assignedNPCs[ply] = nil
		end
	end
end)

hook.Add("EntityTakeDamage", "HSR_etd", function(rag, dmgInfo)
	local ply = rag:GetNWEntity("owner")
	if not IsValid(ply) or not ply:Alive() then return end

	local dmgType = dmgInfo:GetDamageType()
	if CurTime() - rag:GetNWFloat("bleedOutStartTime") < 2 and dmgType == DMG_CRUSH then return end

	if dmgType == DMG_CRUSH then
        dmgInfo:ScaleDamage(0.02)
    end

	local physBone = HSR.getPhysicsBoneDamageInfo(rag, dmgInfo)
	local boneName = rag:GetBoneName(rag:TranslatePhysBoneToBone(physBone))
	local hitGroup = HSR.boneToHitGroup[boneName]
	local multiplier = HSR.ragdollDamageBoneMultiplier[hitGroup]

	if rag and multiplier then dmgInfo:ScaleDamage(multiplier) end

	ply:TakeDamageInfo(dmgInfo)
end)

hook.Add("PlayerUse", "HSR_pu", function(user, ent)
	if ent:GetNWEntity("owner") and ent:GetClass() == "prop_ragdoll" then
		local plyDowned = ent:GetNWEntity("owner")

		for ply, rag in pairs(HSR.downedPlayers) do
			if ent == rag then
				if IsValid(rag:GetNWEntity("savior")) then continue end
				if ply != plyDowned then continue end

				rag:SetNWEntity("savior", user)
				rag:SetNWFloat("reviveStartTime", CurTime())
			end
		end
	end
end)

hook.Add("PlayerDeath", "HSR_pd", function(ply, _, atkr)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")

	if IsValid(downed_ragdoll) then 
		if IsValid(ply:GetRagdollEntity()) then
			ply:GetRagdollEntity():Remove()
		end

		ply:SetNWBool("downed", false)
        ply:Spectate(OBS_MODE_CHASE)
        ply:SetMoveType(MOVETYPE_OBSERVER)
        ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        ply:SpectateEntity(downed_ragdoll)
        
        HSR.downedPlayers[ply] = nil
        net.Start("downedPlayerLocation")
		    net.WriteEntity(NULL)      
		    net.WriteEntity(ply)       
		net.Send(player.GetAll())
	end
end)

hook.Add("PlayerSpawn", "HSR_ps", function(ply, _)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")
	
	if IsValid(downed_ragdoll) then
		ply:UnSpectate()
		downed_ragdoll:Remove()
		ply:SetNWEntity("downed_ragdoll", nil)

		ply:DrawViewModel(true)
		ply:SetNoDraw(false)
		ply:SetNoTarget(false)
		ply:SetNotSolid(false)
	end
end)