util.AddNetworkString("downedPlayerLocation")

include("revive/sh_revive.lua")

hook.Add("PlayerHurt", "HSR_ph", function(ply, atkr, hp, dmg)
	if GetConVar("hsr_enable"):GetInt() < 1 then return end 

	if not ply:GetNWBool("downed") and hp <= 0  then 
		ply:SetHealth(ply:GetMaxHealth())
		if ply:InVehicle() then ply:ExitVehicle() end

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

		timer.Simple(.1, function()
			if not IsValid(ragdoll) then return end
			
			net.Start("downedPlayerLocation")
				net.WriteEntity(ragdoll)
				net.WriteEntity(ply)
			net.Broadcast()
		end)
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
			net.Broadcast()

			continue
		end
		if not ply:GetNWBool("downed") or not IsValid(ply:GetNWEntity("downed_ragdoll")) then continue end

		local headAttachment = rag.cachedEyeAttachment
		if not headAttachment then
			headAttachment = rag:LookupAttachment("eyes")
            rag.cachedEyeAttachment = headAttachment
		end

		local head = rag:GetAttachment(headAttachment)
		if not head then continue end

		local startPos = head.Pos
		local endPos = ply:EyeAngles():Forward()
		local trace = util.TraceLine({
			start = startPos,
			endpos = startPos + endPos * 150,
			filter = { ply, rag }
		})

		if ply:KeyDown(IN_ATTACK) then
			local phys = rag:GetPhysicsObjectNum(rag.LeftHandPhys)
			HSR.applyForce(phys, trace)
		end

		if ply:KeyDown(IN_ATTACK2) then
			local phys = rag:GetPhysicsObjectNum(rag.RightHandPhys)
			HSR.applyForce(phys, trace)
		end
	end
end)

hook.Add("Think", "HSR_reviving", function()
	if table.IsEmpty(HSR.downedPlayers) then return end
 
	for ply, rag in pairs(HSR.downedPlayers) do
		if not IsValid(ply) or not IsValid(rag) then
			if IsValid(rag) then rag:Remove() end
			if IsValid(ply) then 
				ply:Kill() 
				ply:SetNWBool("downed", false) 
			end
			
			HSR.downedPlayers[ply] = nil
			net.Start("downedPlayerLocation")
			    net.WriteEntity(NULL)       
			    net.WriteEntity(ply)        
			net.Broadcast()

			continue
		end

		local savior = rag:GetNWEntity("savior")

		if IsValid(savior) and not savior:IsNPC() then
			-- Drag logic
			if GetConVar("hsr_ragdoll_drag_allowed"):GetInt() > 0 then
				local dragForce = GetConVar("hsr_ragdoll_drag_force"):GetInt()
				if savior:KeyDown(IN_USE) then
					local forward = savior:GetForward()
					local targetPos = savior:GetPos() + forward * 40 + Vector(0,0,10)
					local phys = rag:GetPhysicsObject()
					if IsValid(phys) then
						phys:SetVelocity((targetPos - rag:GetPos()) * dragForce)
					end
				end
			end

			-- Revive logic
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
				net.Broadcast()		
			end
		end
	end
end)

local nextNPCCheck = 0
local assignedNPCs = {}

hook.Add("Think", "HSR_npc_reviving", function()
	if GetConVar("hsr_npc_revive_allowed"):GetInt() <= 0 then return end
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
					net.Broadcast()		
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

hook.Add("EntityTakeDamage", "HSR_etd", function(ent, dmgInfo)
	if not IsValid(ent) then return end

	local ply = ent:GetNWEntity("owner")
	if not IsValid(ply) or not ply:Alive() then return end

	local dmgType = dmgInfo:GetDamageType()
	if CurTime() - ent:GetNWFloat("bleedOutStartTime") < 2 and dmgType == DMG_CRUSH then return end

	if dmgType == DMG_CRUSH then
        dmgInfo:ScaleDamage(0.02)
    end

	local physBone = HSR.getPhysicsBoneDamageInfo(ent, dmgInfo)
	local boneName = ent:GetBoneName(ent:TranslatePhysBoneToBone(physBone))
	local hitGroup = HSR.boneToHitGroup[boneName]
	local multiplier = HSR.ragdollDamageBoneMultiplier[hitGroup]

	if multiplier then dmgInfo:ScaleDamage(multiplier) end

	ply:TakeDamageInfo(dmgInfo)
end)

hook.Add("PlayerUse", "HSR_pu", function(user, ent)
	if not IsValid(ent) or ent:GetClass() != "prop_ragdoll" then return end
	local plyDowned = ent:GetNWEntity("owner")
	if not IsValid(plyDowned) then return end

	local rag = HSR.downedPlayers[plyDowned]
	if rag != ent then return end

	if IsValid(rag:GetNWEntity("savior")) then return end
	if user == plyDowned then return end
	rag:SetNWEntity("savior", user)
	rag:SetNWFloat("reviveStartTime", CurTime())
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
		net.Broadcast()

		for _, npc in ipairs(ents.FindByClass("npc_*")) do
			if not IsValid(npc) or not npc:IsNPC() then continue end
			
			if npc:GetEnemy() == downed_ragdoll.bullseye then
				npc:AddEntityRelationship(downed_ragdoll.bullseye, D_NU, 0)
			end
		end
	end
end)

hook.Add("PlayerSpawn", "HSR_ps", function(ply, _)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")
	
	if IsValid(downed_ragdoll) then
		ply:UnSpectate()
		downed_ragdoll:SetNWEntity("owner", nil)
		if GetConVar("hsr_remove_ragdoll_on_death"):GetInt() >= 1 then
			downed_ragdoll:Remove()
		end
		ply:SetNWEntity("downed_ragdoll", nil)

		ply:DrawViewModel(true)
		ply:SetNoDraw(false)
		ply:SetNoTarget(false)
		ply:SetNotSolid(false)
	end
end)

hook.Add( "PlayerCanPickupWeapon", "HSR_no_pickup_while_downed", function(ply, _)
	if ply:GetNWBool("downed") then return false end
end)

hook.Add("CanPlayerEnterVehicle", "PrintPlayersInVehicles", function(ply, _, _)
	if ply:GetNWBool("downed") then return false end 
end)