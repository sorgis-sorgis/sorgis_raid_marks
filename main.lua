--[[
    written by sorgis. currently playing on the turtle wow server. 2023
    https://github.com/sorgis-sorgis/sorgis_raid_marks
]]

---------------------
-- IMPLEMENTATION
---------------------
local _G = _G or getfenv(0)
local srm = _G.srm or {}

do
    local make_logger = function(r, g, b)
        return function(...)
            local msg = ""
            for i, v in ipairs(arg) do
                msg = msg .. tostring(v) 
            end

            DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)
        end
    end

    srm.log = make_logger(1, 1, 0.5)
    srm.error = make_logger(1, 0, 0)
end

srm.makeSlashCommand = function(aName, aBehaviour)
    local _G = _G or getfenv(0)
    local nameUpperCase = string.upper(aName)
    _G["SLASH_" .. nameUpperCase .. 1] = "/" .. aName
    SlashCmdList[nameUpperCase] = aBehaviour
end

srm.unitIsAlive = function(aUnit)
    return UnitIsDead(aUnit) == nil
end

srm.unitHasRaidMark = function(aUnit, aMark)
    local unitMark = ({
        [1] = "star",
        [2] = "circle",
        [3] = "diamond",
        [4] = "triangle",
        [5] = "moon",
        [6] = "square",
        [7] = "cross",
        [8] = "skull",
    })[GetRaidTargetIndex(aUnit)] or nil

    return aMark == unitMark
end

srm.markUnitWithRaidMark = function(aMark, aUnitID)
    aUnitID = aUnitID or "target"

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

srm.playerIsInRaid = function()
    return GetNumRaidMembers() ~= 0
end

srm.playerIsInParty = function()
    return not srm.playerIsInRaid() and GetNumPartyMembers() ~= 0
end

srm.startAttack = function()
    for slotIDIndex = 1, 108 do 
        if IsAttackAction(slotIDIndex) then
            if not IsCurrentAction(slotIDIndex) then 
                UseAction(slotIDIndex)
            end
            
            return
        end
    end

    srm.error("sorgis_raid_marks startAttack requires the attack ability to be somewhere in the actionbars")
end

do
    local PLAYER_UNIT_IDS = {
        [0] = "player",
        [1] = "target",
        [2] = "pet",
        [3] = "pettarget",
    }

    local RAID_UNIT_IDS = (function()
        local units = {}
        
        for i = 1, 40 do table.insert(units, "raid" .. i) end
        for i = 1, 40 do table.insert(units, "raid" .. i .. "target") end
        for i = 1, 40 do table.insert(units, "raidpet" .. i) end
        for i = 1, 40 do table.insert(units, "raidpet" .. i .. "target") end

        return units
    end)()

    local PARTY_UNIT_IDS = (function()
        local units = {}

        for i = 1, 5 do table.insert(units, "party" .. i) end
        for i = 1, 5 do table.insert(units, "party" .. i .. "target") end
        for i = 1, 5 do table.insert(units, "partypet" .. i) end
        for i = 1, 5 do table.insert(units, "partypet" .. i .. "target") end
        
        return units
    end)()

    srm.tryTargetUnitWithRaidMarkFromGroupMembers = function(aMark)
        for _, aUnitID in pairs(PLAYER_UNIT_IDS) do
            if srm.unitHasRaidMark(aUnitID, aMark) and srm.unitIsAlive(aUnitID) then
                TargetUnit(aUnitID)   
                return true
            end
        end

        for _, aUnitID in pairs(srm.playerIsInRaid() and RAID_UNIT_IDS or 
            srm.playerIsInParty() and PARTY_UNIT_IDS or {}) do
            if srm.unitHasRaidMark(aUnitID, aMark) and srm.unitIsAlive(aUnitID) then
                TargetUnit(aUnitID)   
                return true
            end
        end

        return false
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
-- MACRO SLASH COMMANDS
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
                frame:EnableMouse(true)
                frame:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
                frame:SetScript("OnClick", function()
                    if arg1 == "LeftButton" then
                        srm.tryTargetMark(aMark)
                    elseif arg1 == "RightButton" then
                        srm.tryAttackMark(aMark)
                    end
                end)
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
                    srm.log("raidtray moved. type `", _G.SLASH_SRAIDMARKS1, "` to lock or hide")
                end

                rootFrame:StopMovingOrSizing()
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

            return {
                ["setScale"] = function(aScale)
                    frame:SetWidth(aScale) 
                    frame:SetHeight(aScale)
                    frame:SetPoint("CENTER", aX * aScale, aY * aScale)
                    raidMarkTexture:SetWidth(aScale)
                    raidMarkTexture:SetHeight(aScale)
                end,
                ["getScale"] = function(aScale)
                    return frame:GetWidth()
                end,
            }
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

        local gui = {
            ["setScale"] = function(aScale)
                for _, button in pairs(trayButtons) do
                    button.setScale(aScale)
                end
            end,
            ["getScale"] = function()
                return trayButtons[1].getScale()
            end,
            ["setVisibility"] = function(aVisibility)
                if aVisibility then
                    rootFrame:Show()
                else
                    rootFrame:Hide()
                end
            end,
            ["getVisibility"] = function()
                return rootFrame:IsVisible() ~= nil
            end,
            ["lock"] = function()
                rootFrame:SetMovable(false)
                rootFrame:StopMovingOrSizing()
            end,
            ["unlock"] = function()
                rootFrame:SetMovable(true)
            end,
            ["setMovable"] = function(aMovable)
                rootFrame:SetMovable(aMovable)
            end,
            ["getMovable"] = function()
                return rootFrame:IsMovable() ~= nil
            end,
            ["getPosition"] = function()
                local a, b, c, x, y = rootFrame:GetPoint()
                
                return x, y
            end,
            ["setPosition"] = function(x, y)
                rootFrame:SetPoint("TOPLEFT", x, y)
            end,
        }
        gui.reset = function()
            gui.setMovable(true)
            gui.setVisibility(true)
            gui.setScale(32)
       
            w = rootFrame:GetParent():GetWidth()
            h = rootFrame:GetParent():GetHeight()
 
            gui.setPosition(w/2,h/2*-1)
        end

        gui.reset()

        rootFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        rootFrame:RegisterEvent("PLAYER_LOGOUT")
        rootFrame:SetScript("OnEvent", function()
            if event == "PLAYER_ENTERING_WORLD" then
                sorgis_raid_marks = sorgis_raid_marks or {}
                sorgis_raid_marks.position = sorgis_raid_marks.position or {}

                gui.setScale(sorgis_raid_marks.scale or 32)
                gui.setVisibility(sorgis_raid_marks.visibility == nil or sorgis_raid_marks.visibility)
                gui.setMovable(sorgis_raid_marks.locked ~= true)

                if type(sorgis_raid_marks.position[1]) == "number" then
                    gui.setPosition(unpack(sorgis_raid_marks.position))
                end

            elseif event == "PLAYER_LOGOUT" then
                sorgis_raid_marks.position = {gui.getPosition()}
                sorgis_raid_marks.scale = gui.getScale()
                sorgis_raid_marks.visibility = gui.getVisibility()
                sorgis_raid_marks.locked = gui.getMovable() ~= true
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
                srm.log("tray locked")
            end
        },
        ["unlock"] = {
            "allows the tray to be dragged by the mouse",
            function()
                gui.unlock()
                srm.log("tray unlocked")
            end
        },
        ["hide"] = {
            "hides the tray",
            function()
                gui.setVisibility(false)
                srm.log("tray hidden")
            end
        },
        ["show"] = {
            "shows the tray",
            function()
                gui.setVisibility(true)
                srm.log("tray shown")
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

                srm.log("scale is: ", gui.getScale())
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
            local commandsString = ""
            for command, value in pairs(commands) do
                commandsString = commandsString .. "`" .. _G.SLASH_SRAIDMARKS1 .. " " .. command ..
                "` : " .. value[1] .. "\n"
            end 

            srm.log(commandsString)
        end)(unpack(arg))
    end)
end

