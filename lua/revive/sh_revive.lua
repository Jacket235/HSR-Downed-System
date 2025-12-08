HSR = {}
HSR.downedPlayers = {}

CreateConVar("hsr_enable", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "Enable addon?")
CreateConVar("hsr_ragdoll_bleed_out_time", "30", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "How long the ragdoll will bleed out for")
CreateConVar("hsr_ragdoll_give_up_time", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "How long it takes to give up")
CreateConVar("hsr_ragdoll_revive_time", "4", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "How long it takes to revive someone")
CreateConVar("hsr_indicator_max_distance", "4000", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "From how far away can downed indicators be seen")
CreateConVar("hsr_npc_revive_allowed", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "Are NPCs allowed to revive you")
CreateConVar("hsr_ragdoll_npc_search_radius", "500", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "Maximum distance for NPCs to come to you")
CreateConVar("hsr_ragdoll_npc_revive_radius", "60", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "At what distance do the NPCs actually start reviving you")
CreateConVar("hsr_ragdoll_drag_allowed", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "Can players drag downed players")
CreateConVar("hsr_ragdoll_drag_force", "5", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "With how much force the ragdoll is dragged")
CreateConVar("hsr_remove_ragdoll_on_death", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "Should ragdolls be removed on death?")

HSR.boneToHitGroup = { 
    ["ValveBiped.Bip01_Head1"] = 1,
    ["ValveBiped.Bip01_R_UpperArm"] = 5,
    ["ValveBiped.Bip01_R_Forearm"] = 5,
    ["ValveBiped.Bip01_R_Hand"] = 5,
    ["ValveBiped.Bip01_L_UpperArm"] = 4,
    ["ValveBiped.Bip01_L_Forearm"] = 4,
    ["ValveBiped.Bip01_L_Hand"] = 4,
    ["ValveBiped.Bip01_Pelvis"] = 3,
    ["ValveBiped.Bip01_Spine2"] = 2,
    ["ValveBiped.Bip01_L_Thigh"] = 6,
    ["ValveBiped.Bip01_L_Calf"] = 6,
    ["ValveBiped.Bip01_L_Foot"] = 6,
    ["ValveBiped.Bip01_R_Thigh"] = 7,
    ["ValveBiped.Bip01_R_Calf"] = 7,
    ["ValveBiped.Bip01_R_Foot"] = 7
}

HSR.ragdollDamageBoneMultiplier = {		
	[HITGROUP_LEFTLEG] = 1,
	[HITGROUP_RIGHTLEG] = 1,

	[HITGROUP_GENERIC] = 2,

	[HITGROUP_LEFTARM] = 1,
	[HITGROUP_RIGHTARM] = 1,

	[HITGROUP_CHEST] = 2,
	[HITGROUP_STOMACH] = 2,

	[HITGROUP_HEAD] = 5,
}

cleanup.Register("hsr_corpses")

if CLIENT then
    language.Add("cleanup_hsr_corpses", "HSR Corpses")
    language.Add("cleaned_hsr_corpses", "Clean up all HSR Corpses")

    hook.Add("InitPostEntity", "hsr_add_button", function()
    	cleanup.UpdateUI()
	end)
end

function HSR.createDownedRagdoll(ply)
	local ragdoll = ents.Create("prop_ragdoll")
	ragdoll:SetNWFloat("bleedOutStartTime", CurTime() + .1)
	ragdoll:SetModel(ply:GetModel())
	ragdoll:SetPos(ply:GetPos())
	ragdoll:SetAngles(ply:GetAngles())
	ragdoll:SetNWVector("rag_ply_color", ply:GetPlayerColor())
	ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ragdoll:SetSkin(ply:GetSkin())
	ragdoll:Spawn()
	ragdoll:Activate()
	ragdoll:GetPhysicsObject():SetMass(12.775918006897)

	if ply.AddCleanup then
		ply:AddCleanup("hsr_corpses", ragdoll)
	end

	for i = 0, ply:GetNumBodyGroups() - 1 do
	    ragdoll:SetBodygroup(i, ply:GetBodygroup(i))
	end

    local vel = ply:GetVelocity()/1 + (force or Vector(0,0,0))
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local physobj = ragdoll:GetPhysicsObjectNum( i )
		local ragbonename = ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(i))
		local bone = ply:LookupBone(ragbonename)
		if(bone)then
			local bonemat = ply:GetBoneMatrix(bone)
			if(bonemat)then
				local bonepos = bonemat:GetTranslation()
				local boneang = bonemat:GetAngles()
				physobj:SetPos(bonepos, true)
				physobj:SetAngles(boneang)
				if not ply:Alive() then vel = vel end
				physobj:AddVelocity(vel)
			end
		end
	end

	ply:SetNWBool("downed", true)
	ply:SetNWEntity("downed_ragdoll", ragdoll)
	ply:SetNotSolid(true)
	ply:DrawViewModel(false)
	ply:SetNoDraw(true)
	ply:SetNoTarget(true)
	ply:SetMoveType(MOVETYPE_NONE)
	ply:SetLocalVelocity(Vector(0, 0, 0))
	ply:SetVelocity(Vector(0, 0, 0))

	return ragdoll
end

function HSR.createRagdollBullseye(ply, ragdoll)
	ragdoll.bullseye = ents.Create("npc_bullseye")
	ragdoll:SetNWEntity("owner", ply)

	local bullseye = ragdoll.bullseye
	bullseye:SetPos(ragdoll:GetPos() + Vector(0, 0, 8))
	bullseye:SetParent(ragdoll)
	bullseye:SetHealth(1000)
	bullseye:Spawn()
	bullseye:Activate()
	bullseye:SetSolid(SOLID_NONE)
	ply:StripWeapons()
end

function HSR.storeBones(ragdoll, ply)
	local function findPhysBone(bonename)
		local boneIndex = ply:LookupBone(bonename)
		if not boneIndex then return nil end
		local physID = ragdoll:TranslateBoneToPhysBone(boneIndex)
		return physID
	end

	ragdoll.LeftHandPhys  = findPhysBone("ValveBiped.Bip01_L_Hand")
	ragdoll.RightHandPhys = findPhysBone("ValveBiped.Bip01_R_Hand")
end

function HSR.storeWeapons(ragdoll, ply)
	ragdoll.weapons = {}

	for _, weapon in pairs(ply:GetWeapons()) do
	    local weaponInfo = {
	        class = weapon:GetClass(),
	        clip1 = weapon:Clip1(),
	        clip2 = weapon:Clip2(),
	        primaryAmmo = ply:GetAmmoCount(weapon:GetPrimaryAmmoType()),
	        secondaryAmmo = ply:GetAmmoCount(weapon:GetSecondaryAmmoType())
	    }
	    table.insert(ragdoll.weapons, weaponInfo)
	end
end

function HSR.revivePlayer(ply)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")
	local ragdollPos = downed_ragdoll:GetPhysicsObject():GetPos()
	local eyeAngles = ply:EyeAngles()

	ply:SetNWBool("downed", false)

	ply:UnSpectate()
	ply:Spawn()
	ply:SetHealth(ply:GetMaxHealth() * .3)
	ply:StripWeapons()
	ply:StripAmmo()
	ply:SetPos(ragdollPos)
	ply:SetEyeAngles(eyeAngles)

	for _, weaponInfo in pairs(downed_ragdoll.weapons or {}) do
        local weapon = ply:Give(weaponInfo.class)
        if IsValid(weapon) then
            weapon:SetClip1(weaponInfo.clip1)
            weapon:SetClip2(weaponInfo.clip2)

            local primaryType = weapon:GetPrimaryAmmoType()
        	local secondaryType = weapon:GetSecondaryAmmoType()

            ply:SetAmmo(weaponInfo.primaryAmmo, primaryType)
            ply:SetAmmo(weaponInfo.secondaryAmmo, secondaryType)
        end
    end
   
    ply:SetNWEntity("downed_ragdoll", nil)
    HSR.downedPlayers[ply] = nil
end

function HSR.setupBullseyeRelationship(bullseye)
	if not IsValid(bullseye) then return end
	if bullseye:GetClass() != "npc_bullseye" then return end

	local parent = bullseye:GetParent()
	if not IsValid(parent) then return end

	local owner = parent:GetNWEntity("owner")
	if not IsValid(owner) then return end
	if not owner:Alive() then return end

	for _, npc in ipairs(ents.FindByClass("npc_*")) do
		if not npc.AddEntityRelationship then continue end

		local disp = npc:Disposition(owner)
		if disp == D_HT or disp == D_FR then
			npc:AddEntityRelationship(bullseye, D_HT, 0)
			npc:SetNPCState(NPC_STATE_COMBAT)
			npc:SetEnemy(bullseye)
		end
	end
end

function HSR.updateBullseyeRelationship(npc)
	if not IsValid(npc) or not npc.AddEntityRelationship then return end

	for _, bullseye in ipairs(ents.FindByClass("npc_bullseye")) do
		local parent = bullseye:GetParent()
		if not IsValid(parent) then continue end

		local owner = parent:GetNWEntity("owner")
		if not IsValid(owner) then continue end
		if not owner:Alive() then return end

		local disp = npc:Disposition(owner)
		if disp == D_HT or disp == D_FR then
			npc:AddEntityRelationship(bullseye, D_HT, 0)
			npc:SetNPCState(NPC_STATE_COMBAT)
			npc:SetEnemy(bullseye)
		end
	end
end

local SPRING = 15
local DAMPING = 9
local FORCE_CLAMP = 120

function HSR.applyForce(phys, trace)
	if not IsValid(phys) then return end

    local targetPos = trace.HitPos
    local currentPos = phys:GetPos()
    local dir = targetPos - currentPos
	local dist = dir:Length()
    
    dir:Normalize()
    local vel = phys:GetVelocity()
    
    local force = dir * dist * SPRING - vel * DAMPING

    -- clamp force so it can’t drag the body
    force.x = math.Clamp(force.x, -FORCE_CLAMP, FORCE_CLAMP)
    force.y = math.Clamp(force.y, -FORCE_CLAMP, FORCE_CLAMP)
    force.z = math.Clamp(force.z, -FORCE_CLAMP, FORCE_CLAMP)

    phys:ApplyForceCenter(force)
end

function HSR.getPhysicsBoneDamageInfo(ent, dmgInfo)
    -- Get the position where the damage occurred
    local pos = dmgInfo:GetDamagePosition()

    -- Get the direction of the damage force and normalize it
    local dir = dmgInfo:GetDamageForce():GetNormalized()

    -- Multiply the normalized direction by a scaling factor
    dir:Mul(1024 * 8)

    -- Initialize trace parameters
    local tr = {}
    tr.start = pos                      -- The start of the trace is the damage position
    tr.endpos = pos + dir               -- The endpoint of the trace is the damage position + scaled direction
    tr.filter = filter                   -- Filter entities to ignore during the trace (likely a player or other entities)
    filterEnt = ent                      -- Set the entity to be filtered (ignored in the trace)
    tr.ignoreworld = true                -- Ignore the world when tracing, only consider entities

    -- Perform the trace and store the result
    local result = util.TraceLine(tr)
    
    -- Check if the trace didn't hit the entity (i.e., the damage came from outside the entity)
    if result.Entity ~= ent then
        -- If the trace misses the entity, reverse the trace direction
        tr.endpos = pos - dir

        -- Perform a second trace in the reverse direction and return the physics bone hit
        return util.TraceLine(tr).PhysicsBone
    else
        -- If the trace hits the entity, return the physics bone it hit
        return result.PhysicsBone
    end
end