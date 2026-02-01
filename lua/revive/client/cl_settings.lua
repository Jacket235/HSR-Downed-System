function HSR.OpenSettings()
    if not LocalPlayer():IsAdmin() then return end

	local scale = ScrW() / 1920 
	local frameW, frameH = 800 * scale, 600 * scale

    local frame = vgui.Create("DFrame")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:SetTitle("HSR Settings")
    frame:MakePopup()
    function frame:Paint(w, h)
    	draw.RoundedBox(0, 0, 0, w, h, Color(18, 18, 24))
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(12, 12, 12, 12)
    function scroll:Paint(w, h)
    	draw.RoundedBox(8, 0, 0, w, h, Color(29, 29, 35))
    end

    local function AddHeader(parent, text)
        local lbl = vgui.Create("DLabel", parent)
        lbl:SetText(text)
        lbl:SetFont("DermaLarge")
        lbl:Dock(TOP)
        lbl:DockMargin(10, 0, 10, 10)
        lbl:SizeToContents()
        lbl:SetTall(lbl:GetTall() + 16)
        function lbl:Paint(w, h)
        	draw.RoundedBox(0, 0, h - 2, w, 2, Color(46, 46, 52))
        end

        return lbl
    end

    local function AddCheckbox(parent, text, convar, client)
        local cb = vgui.Create("DCheckBoxLabel", parent)
        cb:SetText(text)
        cb:Dock(TOP)
        cb:DockMargin(10, 2, 0, 2)
        cb:SetSize(18, 18)
        cb:SetChecked(GetConVar(convar):GetInt())
        cb.Label:SetTextColor(color_white)
        function cb:OnChange(val)
        	if client then
        		GetConVar(convar):SetInt(val and 1 or 0)
        		return
        	end
		    net.Start("changeConVarValue")
			    net.WriteString(convar)
			    net.WriteUInt(0, 2)
			    net.WriteBool(val)
		    net.SendToServer()
		end
		function cb:PaintOver(w, h) 
			draw.RoundedBox(5, 0, 0, 18, 18, Color(52, 52, 57))

			if self:GetChecked() then
				draw.RoundedBox(4, 3, 3, 12, 12, Color(57, 121, 201))
			end
		end

        return cb
    end

    local function AddSlider(parent, text, convar, min, max)
        local slider = vgui.Create("DNumSlider", parent)
        slider:SetText(text)
        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetDecimals(0)
        slider:SetValue(GetConVar(convar):GetInt())
        slider:Dock(TOP)
        slider:DockMargin(10, 0, 10, 0)
        function slider:OnValueChanged(val)
		    net.Start("changeConVarValue")
			    net.WriteString(convar)
			    net.WriteUInt(1, 2)
			    net.WriteFloat(math.Round(val))
		    net.SendToServer()
		end
		function slider.Slider:Paint(w, h)
        	// Background
        	draw.RoundedBox(4, 0, h / 2 - 3, w, 6, Color(100, 100, 100))
        	// Fill
        	local s = self:GetParent()

		    local percent = (s:GetValue() - s:GetMin()) / (s:GetMax() - s:GetMin())
		    local fill = w * percent
        	draw.RoundedBox(4, 0, h / 2 - 3, fill, 6, Color(57, 121, 201))
        	// Knob
        	local knobX = math.Clamp(fill - 6, 0, w - 12)
        	draw.RoundedBox(6, knobX, h/2 - 6, 12, 12, Color(255, 255, 255))
        end
        function slider.Slider.Knob:Paint(w, h) end

        return slider
    end

    local function AddTextEntry(parent, text, convar)
        local pnl = vgui.Create("DPanel", parent)
        pnl:Dock(TOP)
        pnl:DockMargin(10, 5, 10, 5)
        pnl:SetTall(50)
        pnl.Paint = function() end

        local lbl = vgui.Create("DLabel", pnl)
        lbl:SetText(text)
        lbl:SetFont("DermaDefault")
        lbl:SetTextColor(color_white)
        lbl:Dock(TOP)
        lbl:DockMargin(0, 0, 0, 5)

        local entry = vgui.Create("DTextEntry", pnl)
        entry:Dock(TOP)
        entry:SetTall(25)
        entry:SetText(GetConVar(convar):GetString())
        
        function entry:OnEnter()
            local val = self:GetValue()
            net.Start("changeConVarValue")
                net.WriteString(convar)
                net.WriteUInt(2, 2)
                net.WriteString(val)
            net.SendToServer()
        end
        
        function entry:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(52, 52, 57))
            self:DrawTextEntryText(color_white, Color(57, 121, 201), color_white)
        end

        return pnl
    end

    -- === MAIN SETTINGS ===
    AddHeader(scroll, "Main settings")

    AddCheckbox(scroll, "Enable HSR", "hsr_enable")
    AddCheckbox(scroll, "Enable first person downed camera", "hsr_ragdoll_first_person", true)
    AddCheckbox(scroll, "Enable remove ragdolls after death", "hsr_remove_ragdoll_on_death")
    AddCheckbox(scroll, "Enable invulnerable ragdolls", "hsr_ragdoll_invulnerable")
    AddCheckbox(scroll, "Enable dragging downed players", "hsr_ragdoll_drag_allowed")
    

    -- === GENERAL SETTINGS ===
    AddHeader(scroll, "General settings")

    AddSlider(scroll, "Bleedout time", "hsr_ragdoll_bleed_out_time", 1, 60)
    AddSlider(scroll, "Give up time", "hsr_ragdoll_give_up_time", 1, 5)
    AddSlider(scroll, "Revive time", "hsr_ragdoll_revive_time", 1, 30)
    AddSlider(scroll, "Downed indicator max. distance", "hsr_indicator_max_distance", 500, 2000)
    AddSlider(scroll, "Drag downed force", "hsr_ragdoll_drag_force", 1, 10)
    AddTextEntry(scroll, "Teams allowed to revive (Team IDs, seperated by a single space. Leave blank for everyone)", "hsr_revive_whitelist_teams")

    -- === NPC SETTINGS ===
    AddHeader(scroll, "NPC settings")

    AddCheckbox(scroll, "Enable NPCs to revive downed players", "hsr_npc_revive_allowed")
    AddSlider(scroll, "NPC search max. distance", "hsr_ragdoll_npc_search_radius", 100, 5000)
    AddSlider(scroll, "NPC revive distance", "hsr_ragdoll_npc_revive_radius", 50, 80)
end

concommand.Add("hsr_settings", HSR.OpenSettings)
