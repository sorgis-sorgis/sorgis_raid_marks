--[[
    written by sorgis, intially released in 2023
    https://github.com/sorgis-sorgis/sorgis_raid_marks
]]

---------------------
-- IMPLEMENTATION
---------------------
local _G = getfenv(0)
local srm = {}

do
    local makeLogger = function(r, g, b)
        return function(...)
            local msg = ""
            for i, v in ipairs(arg) do
                msg = msg .. tostring(v) 
            end

            DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)
        end
    end

    srm.log = makeLogger(1, 1, 0.5)
    srm.print = makeLogger(1, 1, 0.5)
    srm.error = makeLogger(1, 0, 0)
end

srm.makeSlashCommand = function(aName, aBehaviour)
    local nameUpperCase = string.upper(aName)
    getfenv(0)["SLASH_" .. nameUpperCase .. 1] = "/" .. aName
    SlashCmdList[nameUpperCase] = aBehaviour
end

srm.unitIsAlive = function(aUnitID)
    return UnitIsDead(aUnitID) == nil
end

srm.unitExists = function(aUnitID) 
    return UnitExists(aUnitID) ~= nil 
end

srm.playerIsLeadOrAssist = function()
    return IsRaidLeader() == 1 
        or IsRaidOfficer() == 1 
        or IsPartyLeader() == 1
end

srm.unitHasRaidMark = function(aUnitID, aMark)
    --GetRaidTargetIndex incorrectly returns 1 (star) if the unit doesn't exist
    if not srm.unitExists(aUnitID) then return false end

    local unitMark = ({
        [1] = "star",
        [2] = "circle",
        [3] = "diamond",
        [4] = "triangle",
        [5] = "moon",
        [6] = "square",
        [7] = "cross",
        [8] = "skull",
    })[GetRaidTargetIndex(aUnitID)] or nil

    return aMark == unitMark
end

srm.markUnitWithRaidMark = function(aMark, aUnitID)
    aUnitID = aUnitID or "target"

    if not srm.unitExists(aUnitID) then return end

    local markIndex = ({
        ["star"] = 1,
        ["circle"] = 2,
        ["diamond"] = 3,
        ["triangle"] = 4,
        ["moon"] = 5,
        ["square"] = 6,
        ["cross"] = 7,
        ["skull"] = 8,
    })[aMark]

    if markIndex == nil then return end

    SetRaidTarget(aUnitID, markIndex) 
end

srm.clearMarkFromUnit = function(aUnitID)
    SetRaidTarget(aUnitID, 0)
end

do
    local frame = CreateFrame("FRAME")
    
    srm.clearAllMarks = function()
        if not srm.playerIsLeadOrAssist() then return end

        for i = 1, 8 do
            SetRaidTarget("player", i)
        end
   
        -- we must check until the server applies the final raid mark in order to remove it
        frame:SetScript("OnUpdate", function()
            if GetRaidTargetIndex("player") ~= 8
                and srm.playerIsLeadOrAssist() 
            then 
                return 
            end

            srm.clearMarkFromUnit("player")
            frame:SetScript("OnUpdate", nil)
        end)
    end
end

srm.playerIsInRaid = function()
    return GetNumRaidMembers() ~= 0
end

srm.playerIsInParty = function()
    return not srm.playerIsInRaid() and GetNumPartyMembers() ~= 0
end

do
    local getAttackSlotIndex
    do
        local attackSlotIndex
        getAttackSlotIndex = function()
            if attackSlotIndex == nil then
                for slotIndex = 1, 120 do 
                    if IsAttackAction(slotIndex) then
                        attackSlotIndex = slotIndex
                        break
                    end
                end
            end

            return attackSlotIndex
        end

        local frame = CreateFrame("FRAME")
        frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        frame:SetScript("OnEvent", function()
            if event == "ACTIONBAR_SLOT_CHANGED" then
                attackSlotIndex = nil
            end
        end)
    end

    srm.startAttack = function()
        local attackSlotIndex = getAttackSlotIndex()

        if not attackSlotIndex then 
            srm.error("sorgis_raid_marks startAttack feature requires the attack ability to be somewhere in your actionbars") 
            return
        end

        if not IsCurrentAction(attackSlotIndex) then 
            UseAction(attackSlotIndex)
        end
    end
end

do
    local PLAYER_UNIT_IDS = {
        [1] = "player",
        [2] = "target",
        [3] = "targettarget",
        [4] = "mouseover",
        [5] = "mouseovertarget",
        [6] = "pet",
        [7] = "pettarget",
        [8] = "pettargettarget",
    }

    local visitUnitIDs = function(aVisitor, aUnitIdList)
        for _, aUnitID in pairs(aUnitIdList) do
            if aVisitor(aUnitID) == true then return true end
        end

        return false
    end

    do
        local ALL_RAID_UNIT_IDS = (function()
            local unitIDs = {}
            for i = 1, 40 do table.insert(unitIDs, "raid" .. i) end
            for i = 1, 40 do table.insert(unitIDs, "raid" .. i .. "target") end
            for i = 1, 40 do table.insert(unitIDs, "raid" .. i .. "targettarget") end
            for i = 1, 40 do table.insert(unitIDs, "raidpet" .. i) end
            for i = 1, 40 do table.insert(unitIDs, "raidpet" .. i .. "target") end
            for i = 1, 40 do table.insert(unitIDs, "raidpet" .. i .. "targettarget") end

            return unitIDs
        end)()

        local ALL_PARTY_UNIT_IDS = (function()
            local unitIDs = {}
            table.insert(unitIDs, "player")
            for i = 1, 4 do table.insert(unitIDs, "party" .. i) end
            for i = 1, 4 do table.insert(unitIDs, "party" .. i .. "target") end
            for i = 1, 4 do table.insert(unitIDs, "party" .. i .. "targettarget") end
            for i = 1, 4 do table.insert(unitIDs, "partypet" .. i) end
            for i = 1, 4 do table.insert(unitIDs, "partypet" .. i .. "target") end
            for i = 1, 4 do table.insert(unitIDs, "partypet" .. i .. "targettarget") end
            
            return unitIDs
        end)()

        srm.visitAllUnitIDs = function(aVisitor)
            if 
                visitUnitIDs(aVisitor, PLAYER_UNIT_IDS) == true or
                visitUnitIDs(aVisitor, 
                    srm.playerIsInRaid() and ALL_RAID_UNIT_IDS or 
                    srm.playerIsInParty() and ALL_PARTY_UNIT_IDS or 
                    {}) == true 
            then 
                return true 
            end

            return false
        end
    end

    do
        local RAID_MEMBER_TARGET_UNIT_IDS = (function()
            local unitIDs = {}
            for i = 1, 40 do table.insert(unitIDs, "raid" .. i .. "target") end

            return unitIDs
        end)();

        local PARTY_MEMBER_TARGET_UNIT_IDS = (function()
            local unitIDs = {}
            for i = 1, 4 do table.insert(unitIDs, "party" .. i .. "target") end
            table.insert(unitIDs, "playertarget")

            return unitIDs
        end)();

        srm.visitGroupMemberTargetIDs = function(aVisitor)
            local units = 
                srm.playerIsInRaid() and RAID_MEMBER_TARGET_UNIT_IDS or
                srm.playerIsInParty() and PARTY_MEMBER_TARGET_UNIT_IDS or
                {}

            for _, unitID in pairs(units) do
                if aVisitor(unitID) == true then return true end
            end 

            return false
        end
    end

    srm.tryTargetUnitWithRaidMarkFromGroupMembers = function(aMark)
        return srm.visitAllUnitIDs(function(aUnitID)
            if srm.unitHasRaidMark(aUnitID, aMark) and srm.unitIsAlive(aUnitID) then
                TargetUnit(aUnitID)   
                return true
            end
        end)
    end
end

do
    local visitNamePlates 
    do
        local namePlates = {} 
        local lastWorldFrameChildCount = 0

        visitNamePlates = function(aVisitor)
            local getNamePlates = function()
                local worldFrameChildCount = WorldFrame:GetNumChildren()
                if lastWorldFrameChildCount < worldFrameChildCount then
                    local worldFrames = {WorldFrame:GetChildren()}
                    for index = lastWorldFrameChildCount, worldFrameChildCount do
                        local plate = worldFrames[index]
                        if plate ~= nil and plate:GetName() == nil then
                            -- This is a standard vanilla wow nameplate
                            if plate["name"] then
                                namePlates[plate] = true
                            else
                                -- this is a modified pfUI/Shagu nameplate
                                local _, shaguplate = plate:GetChildren()
                                if shaguplate ~= nil and type(shaguplate.platename) == "string" then
                                    local adapterplate = {}
                                    adapterplate.IsVisible = function(self) 
                                        return shaguplate:IsVisible()
                                    end
                                    adapterplate.Click = function(self)
                                        plate:Click() 
                                    end
                                    adapterplate.raidicon = shaguplate.raidicon

                                    namePlates[adapterplate] = true
                                end
                            end
                        end
                    end

                    lastWorldFrameChildCount = worldFrameChildCount
                end

                return namePlates
            end

            for plate, _ in pairs(getNamePlates()) do
                if plate:IsVisible() ~= nil then
                    if aVisitor(plate) == true then return true end
                end
            end

            return false
        end
    end

    local raidIconUVsToMarkName = function(aU, aV)
        local key = tostring(aU) .. "," .. tostring(aV)
        local UV_TO_RAID_ICONS = {
            ["0.75,0.25"] = "skull", 
            ["0.5,0.25"] = "cross", 
            ["0,0.25"] = "moon", 
            ["0,0"] = "star", 
            ["0.75,0"] = "triangle", 
            ["0.25,0"] = "circle", 
            ["0.25,0.25"] = "square", 
            ["0.5,0"] = "diamond", 
        }
        return UV_TO_RAID_ICONS[key]
    end

    srm.tryTargetRaidMarkInNamePlates = function(aRaidMark)
        return visitNamePlates(function(plate)
            if plate.raidicon:IsVisible() ~= nil then 
                local u, v = plate.raidicon:GetTexCoord()
                if raidIconUVsToMarkName(u, v) == aRaidMark then
                    plate:Click() 
                    return true
                end
            end
        end)
    end
end

srm.tryTargetMark = function(aRaidMark)
    return srm.tryTargetUnitWithRaidMarkFromGroupMembers(aRaidMark) or 
        srm.tryTargetRaidMarkInNamePlates(aRaidMark)
end

srm.tryAttackMark = function(aRaidMark)
    if srm.tryTargetMark(aRaidMark) then
        srm.startAttack()
        return true
    end

    return false
end

---------------------
-- BINDINGS
---------------------
BINDING_HEADER_SORGIS_RAID_MARKS = "Sorgis Raid Marks"
BINDING_NAME_TRY_TARGET_STAR = "Try to target star"
BINDING_NAME_TRY_TARGET_CIRCLE = "Try to target circle"
BINDING_NAME_TRY_TARGET_DIAMOND = "Try to target diamond"
BINDING_NAME_TRY_TARGET_TRIANGLE = "Try to target triangle"
BINDING_NAME_TRY_TARGET_MOON = "Try to target moon"
BINDING_NAME_TRY_TARGET_SQUARE = "Try to target square"
BINDING_NAME_TRY_TARGET_CROSS = "Try to target cross"
BINDING_NAME_TRY_TARGET_SKULL = "Try to target skull"
SorgisRaidMarks_TryTargetMark = function(aMark)
    srm.tryTargetMark(aMark)
end

-----------------------
-- SLASH COMMANDS
-----------------------
srm.makeSlashCommand("trytargetmark", function(msg)
    msg = string.lower(msg)

    srm.tryTargetMark(msg)
end)

srm.makeSlashCommand("tryattackmark", function(msg)
    msg = string.lower(msg)

    srm.tryAttackMark(msg)
end)

srm.makeSlashCommand("setmark", function(msg)
    local matches = string.gfind(msg, "\(%w+\)")
    local mark = matches()
    local unitID = matches()

    srm.markUnitWithRaidMark(mark, unitID)
end)

srm.makeSlashCommand("clearmark", function(msg)
    local matches = string.gfind(msg, "\(%w+\)")
    local unitID = matches() or "target"

    srm.clearMarkFromUnit(unitID)
end)

srm.makeSlashCommand("clearallmarks", function()
    srm.clearAllMarks()
end)

--------------------
-- USER INTERFACE
--------------------
do
    --------------------
    -- Target tray GUI
    --------------------
    local gui = (function()
        local rootFrame = CreateFrame("Frame", nil, UIParent)
        rootFrame:SetWidth(1)
        rootFrame:SetHeight(1)
        rootFrame:SetPoint("TOPLEFT", 0,0)
        rootFrame:SetMovable(true)

        local makeRaidMarkFrame = function(aX, aY, aMark)
            local SIZE = 32

            local frame = CreateFrame("Button", nil, rootFrame)
            frame:SetFrameStrata("BACKGROUND")
            frame:SetWidth(SIZE) 
            frame:SetHeight(SIZE)
            frame:SetPoint("CENTER", aX * SIZE, aY * SIZE)
            frame:Show() 

            do
                local buttonFrameIsDown = function(aButtonFrame)
                    return aButtonFrame:GetButtonState() == "PUSHED"
                end

                frame:EnableMouse(true)
                frame:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
                frame:SetScript("OnClick", function(a,b,c)
                    if arg1 == "LeftButton" and buttonFrameIsDown(frame) then
                        if IsControlKeyDown() then
                            if srm.unitHasRaidMark("target", aMark) then
                                srm.clearMarkFromUnit("target")
                            else
                                srm.markUnitWithRaidMark(aMark)
                            end
                        else
                            srm.tryTargetMark(aMark)
                        end
                    elseif arg1 == "RightButton" then
                        srm.tryAttackMark(aMark)
                    end
                end)
            end

            local raidMark = {}

            local fsCount = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
            do
                raidMark.setTargetCountIsEnabled = function(aIsEnabled)
                    if aIsEnabled then 
                        frame:SetScript("OnUpdate", function() 
                            local markTargetCount = 0
                            
                            srm.visitGroupMemberTargetIDs(function(aUnitID) 
                                if srm.unitHasRaidMark(aUnitID, aMark) then
                                    markTargetCount = markTargetCount + 1
                                end
                            end)

                            if markTargetCount > 0 then
                                fsCount:Show()
                                fsCount:SetText(tostring(markTargetCount))
                            else
                                fsCount:Hide()
                            end
                        end)
                    else
                        frame:SetScript("OnUpdate", nil)
                        fsCount:Hide()
                    end
                end
            end
            frame:RegisterForDrag("LeftButton")
            frame:SetMovable(true)
            frame:SetScript("OnDragStart", function()
                if rootFrame:IsMovable() then
                    rootFrame:StartMoving()
                end
            end)
            frame:SetScript("OnDragStop", function()
                if rootFrame:IsMovable() then
                    srm.print("raidtray moved. type `", _G.SLASH_SRAIDMARKS1, "` to lock or hide")
                end

                rootFrame:StopMovingOrSizing()

                raidMark.onDragStop()
            end)

            local raidMarkTexture = frame:CreateTexture(nil, "OVERLAY")
            raidMarkTexture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            raidMarkTexture:SetPoint("CENTER", 0, 0)
            raidMarkTexture:SetWidth(SIZE)
            raidMarkTexture:SetHeight(SIZE)

            local markNameToTextCoords = {
                ["star"] =     {0.00,0.25,0.00,0.25},
                ["circle"] =   {0.25,0.50,0.00,0.25},
                ["diamond"] =  {0.50,0.75,0.00,0.25},
                ["triangle"] = {0.75,1.00,0.00,0.25},
                ["moon"] =     {0.00,0.25,0.25,0.50},
                ["square"] =   {0.25,0.50,0.25,0.50},
                ["cross"] =    {0.50,0.75,0.25,0.50},
                ["skull"] =    {0.75,1.00,0.25,0.50},
            }
            raidMarkTexture:SetTexCoord(unpack(markNameToTextCoords[aMark]))

            raidMark.setScale = function(aScale)
                frame:SetWidth(aScale) 
                frame:SetHeight(aScale)
                frame:SetPoint("CENTER", aX * aScale, aY * aScale)

                raidMarkTexture:SetWidth(aScale)
                raidMarkTexture:SetHeight(aScale)

                fsCount:SetFont("Fonts\\FRIZQT__.TTF", aScale * 0.5, "OUTLINE, THICK")
                fsCount:SetPoint("BOTTOMRIGHT", aScale * 0.0, aScale * -0.1)
            end
            raidMark.getScale = function(aScale)
                return frame:GetWidth()
            end
            raidMark.onDragStop = function() end

            return raidMark
        end

        local trayButtons = {}
        table.insert(trayButtons, makeRaidMarkFrame(0,0, "star"))
        table.insert(trayButtons, makeRaidMarkFrame(1,0, "circle"))
        table.insert(trayButtons, makeRaidMarkFrame(2,0, "diamond"))
        table.insert(trayButtons, makeRaidMarkFrame(3,0, "triangle"))
        table.insert(trayButtons, makeRaidMarkFrame(4,0, "moon"))
        table.insert(trayButtons, makeRaidMarkFrame(5,0, "square"))
        table.insert(trayButtons, makeRaidMarkFrame(6,0, "cross"))
        table.insert(trayButtons, makeRaidMarkFrame(7,0, "skull"))

        local gui = {}

        gui.getScale = function()
            return trayButtons[1].getScale()
        end
        gui.setScale = function(aScale)
            for _, button in pairs(trayButtons) do
                button.setScale(aScale)
            end

            sorgis_raid_marks.scale = gui.getScale()
        end

        gui.getVisibility = function()
            return rootFrame:IsVisible() ~= nil
        end
        gui.setVisibility = function(aVisibility)
            if aVisibility then
                rootFrame:Show()
            else
                rootFrame:Hide()
            end

            sorgis_raid_marks.visibility = gui.getVisibility()
        end

        gui.lock = function()
            rootFrame:SetMovable(false)
            rootFrame:StopMovingOrSizing()

            sorgis_raid_marks.locked = gui.getMovable() ~= true
        end
        gui.unlock = function()
            rootFrame:SetMovable(true)

            sorgis_raid_marks.locked = gui.getMovable() ~= true
        end

        gui.getMovable = function()
            return rootFrame:IsMovable() ~= nil
        end
        gui.setMovable = function(aMovable)
            rootFrame:SetMovable(aMovable)
        end

        gui.getPosition = function()
            local a, b, c, x, y = rootFrame:GetPoint()
            
            return x, y
        end
        gui.setPosition = function(x, y)
            rootFrame:SetPoint("TOPLEFT", x, y)

            sorgis_raid_marks.position = {gui.getPosition()} 
        end
        for _, button in pairs(trayButtons) do
            button.onDragStop = function()
                sorgis_raid_marks.position = {gui.getPosition()} 
            end
        end

        gui.reset = function()
            gui.setMovable(true)
            gui.setVisibility(true)
            gui.setScale(32)
       
            w = rootFrame:GetParent():GetWidth()
            h = rootFrame:GetParent():GetHeight()
            gui.setPosition(w/2,h/2*-1)
        end

        gui.setTargetCountIsEnabled = function(aEnabled)
            for _, button in pairs(trayButtons) do
                button.setTargetCountIsEnabled(aEnabled)
            end

             sorgis_raid_marks.targetCountIsEnabled = aEnabled
        end

        rootFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        rootFrame:SetScript("OnEvent", function()
            if event == "PLAYER_ENTERING_WORLD" then
                sorgis_raid_marks = sorgis_raid_marks or {}
                sorgis_raid_marks.position = sorgis_raid_marks.position or {}

                gui.setScale(sorgis_raid_marks.scale or 32)
                gui.setVisibility(sorgis_raid_marks.visibility == nil or sorgis_raid_marks.visibility)
                gui.setMovable(sorgis_raid_marks.locked ~= true)
                gui.setTargetCountIsEnabled(sorgis_raid_marks.targetCountIsEnabled ~= nil and sorgis_raid_marks.targetCountIsEnabled)

                if type(sorgis_raid_marks.position[1]) == "number" then
                    gui.setPosition(unpack(sorgis_raid_marks.position))
                else
                    w = rootFrame:GetParent():GetWidth()
                    h = rootFrame:GetParent():GetHeight()
                    gui.setPosition(w/2,h/2*-1)
                end
            end
        end)

        return gui
    end)();

    ---------------------------
    -- target tray settings CLI
    ---------------------------
    local commands = {
        ["lock"] = {
            "prevent the tray from being dragged by the mouse",
            function()
                gui.lock()
                srm.print("tray locked")
            end
        },
        ["unlock"] = {
            "allows the tray to be dragged by the mouse",
            function()
                gui.unlock()
                srm.print("tray unlocked")
            end
        },
        ["hide"] = {
            "hides the tray",
            function()
                gui.setVisibility(false)
                srm.print("tray hidden")
            end
        },
        ["show"] = {
            "shows the tray",
            function()
                gui.setVisibility(true)
                srm.print("tray shown")
            end
        },
        ["reset"] = {
            "moves tray to center of the screen, resets all settings", 
            function()
                gui.reset()
            end
        },
        ["scale"] = {
            "resize the tray if given a number. Prints the current scale value if no number provided", 
            function(aScale)
                if aScale then
                    gui.setScale(tonumber(aScale)) 
                end

                srm.print("scale is: ", gui.getScale())
            end
        },
        ["enablecounter"] = {
            "tracks and displays the number of group members targeting each raid mark in the UI",
            function()
                gui.setTargetCountIsEnabled(true)

                srm.print("raidmark counters enabled")
            end
        },
        ["disablecounter"] = {
            "does not track or display the number of group members targeting each raid mark in the UI",
            function()
                gui.setTargetCountIsEnabled(false)
                
                srm.print("raidmark counters disabled")
            end
        },
    }
     
    srm.makeSlashCommand("sraidmarks", function(msg)
        local arg = {}
        
        for word in string.gfind(msg, "\(%w+\)") do
            table.insert(arg, word)
        end

        local commandName = table.remove(arg, 1);

        (commands[commandName] and commands[commandName][2] or function()
            for command, value in pairs(commands) do
                local commandsString = ""
                commandsString = commandsString .. "`" .. _G.SLASH_SRAIDMARKS1 .. " " .. command ..
                "` : " .. value[1] .. "\n"
                srm.print(commandsString)
            end 
        end)(unpack(arg))
    end)
end

