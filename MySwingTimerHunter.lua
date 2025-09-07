-- MySwingTimerHunter.lua
-- Tracks bow/crossbow/gun swings in slot 18 for WoW Classic, integrates with MySwingTimer

-- Ensure saved variables are initialized
MySwingTimerDB = MySwingTimerDB or {}
MySwingTimerDB.showOutsideCombat = MySwingTimerDB.showOutsideCombat or true
MySwingTimerDB.lockBars = MySwingTimerDB.lockBars or false

local MySwingTimerHunter = CreateFrame("Frame", "MySwingTimerHunterFrame", UIParent)
MySwingTimerHunter:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

-- Variables
local swingStartBow = 0  -- Timestamp when the last bow swing started
local swingDurationBow = 0  -- Bow weapon speed
local isSwingingBow = false  -- Flag for active bow swing
local isBow = false  -- Flag for bow/crossbow/gun equipped
local lastDebugTime = 0  -- Timestamp for throttling debug messages
local debugThrottleInterval = 600  -- 10 minutes in seconds

-- Throttle debug messages to one every 10 minutes
local function ThrottleDebugPrint(message)
    local currentTime = GetTime()
    if currentTime - lastDebugTime >= debugThrottleInterval then
        print("[MySwingTimerHunter Debug] " .. message)
        lastDebugTime = currentTime
    end
end

-- Create ranged bar (global for options access)
barBow = CreateFrame("StatusBar", nil, UIParent)
barBow:SetSize(200, 20)  -- Width, Height
barBow:SetPoint("CENTER", 0, -44)  -- Middle of screen, below offhand
barBow:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
barBow:SetStatusBarColor(0, 1, 0)  -- Green color
barBow:SetMinMaxValues(0, 1)
barBow:SetValue(0)
barBow.bg = barBow:CreateTexture(nil, "BACKGROUND")
barBow.bg:SetAllPoints(true)
barBow.bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
barBow.bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)  -- Dark background
barBow.border = barBow:CreateTexture(nil, "BORDER")
barBow.border:SetAllPoints(true)
barBow.border:SetTexture("Interface\\Buttons\\UI-Quickslot")
barBow.border:SetVertexColor(1, 1, 1, 0.4)  -- Subtle white glow
barBow.border:Hide()
-- Add Ranged label
barBow.label = barBow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
barBow.label:SetPoint("CENTER", barBow, "CENTER", 0, 0)
barBow.label:SetText("Ranged")
barBow.label:SetTextColor(1, 1, 1, 0.7)  -- White with 0.7 opacity
-- Add tooltip for unlocking
barBow:SetScript("OnEnter", function(self)
    if MySwingTimerDB.lockBars then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag vertically more than 12 pixels to unlock")
        GameTooltip:Show()
    end
end)
barBow:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Make barBow movable (drag with left-click)
barBow:SetMovable(true)
barBow:EnableMouse(true)
barBow:RegisterForDrag("LeftButton")
barBow:SetScript("OnDragStart", function(self)
    self:StartMoving()
    draggedBar = self
    isDragging = true
end)
barBow:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local bowTop, bowBottom = self:GetTop() or 0, self:GetBottom() or 0
    local mhTop, mhBottom = barMH:GetTop() or 0, barMH:GetBottom() or 0
    local ohTop, ohBottom = barOH and barOH:GetTop() or 0, barOH and barOH:GetBottom() or 0
    MySwingTimerDB.pointBow = "BOTTOMLEFT"
    MySwingTimerDB.relativePointBow = "BOTTOMLEFT"
    MySwingTimerDB.xBow = self:GetLeft() or 0
    MySwingTimerDB.yBow = self:GetBottom() or 0
    isDragging = false
    draggedBar = nil
    barMH.border:Hide()
    if barOH then barOH.border:Hide() end
    barBow.border:Hide()
    if MySwingTimerDB.lockBars and dragHandle then
        dragHandle:Show()
    else
        if dragHandle then dragHandle:Hide() end
    end
    if dualWield or isBow then
        local snapThreshold = 8  -- Snap threshold for locking
        local unlockThreshold = 12  -- Reduced threshold for unlocking
        local distances = {}
        if barOH then
            table.insert(distances, math.abs(bowBottom - ohTop))
            table.insert(distances, math.abs(bowTop - ohBottom))
            table.insert(distances, math.abs(ohBottom - bowTop))
            table.insert(distances, math.abs(ohTop - bowBottom))
        end
        table.insert(distances, math.abs(bowBottom - mhTop))
        table.insert(distances, math.abs(bowTop - mhBottom))
        table.insert(distances, math.abs(mhBottom - bowTop))
        table.insert(distances, math.abs(mhTop - bowBottom))
        local shouldLock = false
        for _, distance in ipairs(distances) do
            if distance <= snapThreshold then
                shouldLock = true
                break
            end
        end
        local shouldUnlock = true
        for _, distance in ipairs(distances) do
            if distance <= unlockThreshold then
                shouldUnlock = false
                break
            end
        end
        if shouldLock then
            -- Snap bars together
            local left = barMH:GetLeft() or 0
            local prevBottom = barMH:GetBottom() or 0
            barMH:ClearAllPoints()
            barMH:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, prevBottom)
            if barOH then
                barOH:ClearAllPoints()
                barOH:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)
            end
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", barOH or barMH, "BOTTOMLEFT", 0, -2)
            MySwingTimerDB.lockBars = true
            if dragHandle then
                dragHandle:ClearAllPoints()
                dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)
                dragHandle:Show()
            end
            MySwingTimerDB.pointMH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
            MySwingTimerDB.xMH = barMH:GetLeft() or 0
            MySwingTimerDB.yMH = barMH:GetBottom() or 0
            if barOH then
                MySwingTimerDB.pointOH = "BOTTOMLEFT"
                MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
                MySwingTimerDB.xOH = barOH:GetLeft() or 0
                MySwingTimerDB.yOH = barOH:GetBottom() or 0
            end
            MySwingTimerDB.pointBow = "BOTTOMLEFT"
            MySwingTimerDB.relativePointBow = "BOTTOMLEFT"
            MySwingTimerDB.xBow = self:GetLeft() or 0
            MySwingTimerDB.yBow = self:GetBottom() or 0
            barMH:Show()
            if barOH then barOH:Show() end
            barBow:Show()
            print("[MySwingTimerHunter Debug] Bars snapped and locked, barMH pos = x: " .. tostring(MySwingTimerDB.xMH) .. ", y: " .. tostring(MySwingTimerDB.yMH) .. ", barOH pos = x: " .. tostring(MySwingTimerDB.xOH or "N/A") .. ", y: " .. tostring(MySwingTimerDB.yOH or "N/A") .. ", barBow pos = x: " .. tostring(MySwingTimerDB.xBow) .. ", y: " .. tostring(MySwingTimerDB.yBow))
        elseif shouldUnlock then
            MySwingTimerDB.lockBars = false
            print("[MySwingTimerHunter Debug] Bars unlocked")
        end
    end
end)

-- Function to update ranged swing duration
local function UpdateRangedSwingDuration(preserveProgress)
    local oldDurationBow = swingDurationBow
    isBow = false
    swingDurationBow = 0
    isSwingingBow = false
    C_Timer.After(0.5, function()  -- Delay for GetItemInfo
        local link = GetInventoryItemLink("player", 18)  -- Ranged slot
        if link then
            local _, _, _, _, _, _, subType = GetItemInfo(link)
            ThrottleDebugPrint("UpdateRangedSwingDuration: Ranged item type = " .. (subType or "none"))
            if subType and (subType:lower() == "bows" or subType:lower() == "crossbows" or subType:lower() == "guns") then
                isBow = true
                swingDurationBow = UnitRangedDamage("player") or 0
                if preserveProgress and isSwingingBow and oldDurationBow > 0 and swingDurationBow > 0 then
                    local progressBow = (GetTime() - swingStartBow) / oldDurationBow
                    swingStartBow = GetTime() - (progressBow * swingDurationBow)
                end
                if inCombat or MySwingTimerDB.showOutsideCombat then
                    barBow:Show()
                    barBow.label:Show()
                end
                ThrottleDebugPrint("UpdateRangedSwingDuration: Bow/Crossbow/Gun detected, isBow = true, swingDurationBow = " .. swingDurationBow)
            else
                barBow:Hide()
                barBow.label:Hide()
                ThrottleDebugPrint("UpdateRangedSwingDuration: No bow/crossbow/gun, isBow = false, subType = " .. (subType or "none"))
            end
        else
            barBow:Hide()
            barBow.label:Hide()
            ThrottleDebugPrint("UpdateRangedSwingDuration: No ranged item, isBow = false")
        end
    end)
end

-- Event: PLAYER_LOGIN (initialize on login)
function MySwingTimerHunter:PLAYER_LOGIN()
    UpdateRangedSwingDuration()
    C_Timer.After(0.5, function()  -- Delay for initialization
        local screenWidth, screenHeight = GetPhysicalScreenSize()
        local validBowPosition = MySwingTimerDB and MySwingTimerDB.pointBow == "BOTTOMLEFT" and MySwingTimerDB.xBow and MySwingTimerDB.yBow and
                                 MySwingTimerDB.xBow >= 0 and MySwingTimerDB.xBow <= screenWidth and MySwingTimerDB.yBow >= -screenHeight and MySwingTimerDB.yBow <= screenHeight
        if validBowPosition then
            barBow:ClearAllPoints()
            barBow:SetPoint(MySwingTimerDB.pointBow, UIParent, MySwingTimerDB.relativePointBow, MySwingTimerDB.xBow, MySwingTimerDB.yBow)
        else
            barBow:ClearAllPoints()
            barBow:SetPoint("CENTER", 0, -44)
            MySwingTimerDB.pointBow = "BOTTOMLEFT"
            MySwingTimerDB.relativePointBow = "BOTTOMLEFT"
            MySwingTimerDB.xBow = barBow:GetLeft() or 0
            MySwingTimerDB.yBow = barBow:GetBottom() or 0
        end
        barBow:SetMinMaxValues(0, 1)
        barBow:SetValue(0)
        barBow:SetSize(200, 20)
        barBow:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barBow:SetStatusBarColor(0, 1, 0)
        barBow:SetFrameStrata("HIGH")
        barBow:SetFrameLevel(12)
        if MySwingTimerDB.showOutsideCombat or inCombat then
            if isBow then
                barBow:Show()
                barBow.label:Show()
                if MySwingTimerDB.lockBars and dragHandle and (dualWield or isBow) then
                    dragHandle:ClearAllPoints()
                    dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)
                    dragHandle:Show()
                end
            else
                barBow:Hide()
                barBow.label:Hide()
            end
        else
            barBow:Hide()
            barBow.label:Hide()
        end
        local _, _, _, xBow, yBow = barBow:GetPoint()
        print("[MySwingTimerHunter Debug] PLAYER_LOGIN: isBow = " .. tostring(isBow) .. ", barBow visible = " .. tostring(barBow:IsVisible()) .. ", barBow pos = x: " .. tostring(xBow) .. ", y: " .. tostring(yBow))
    end)
end

-- Event: PLAYER_LOGOUT (save positions before logout)
function MySwingTimerHunter:PLAYER_LOGOUT()
    if barBow then
        MySwingTimerDB.pointBow = "BOTTOMLEFT"
        MySwingTimerDB.relativePointBow = "BOTTOMLEFT"
        MySwingTimerDB.xBow = barBow:GetLeft() or 0
        MySwingTimerDB.yBow = barBow:GetBottom() or 0
        print("[MySwingTimerHunter Debug] PLAYER_LOGOUT: Saved barBow pos = x: " .. tostring(MySwingTimerDB.xBow) .. ", y: " .. tostring(MySwingTimerDB.yBow))
    end
end

-- Event: START_AUTOREPEAT_SPELL (start ranged auto-shot)
function MySwingTimerHunter:START_AUTOREPEAT_SPELL()
    UpdateRangedSwingDuration()
    if isBow and swingDurationBow > 0 then
        swingStartBow = GetTime() - swingDurationBow + 0.5  -- Account for ~0.5s first shot delay
        isSwingingBow = true
        barBow:Show()
        barBow.label:Show()
        ThrottleDebugPrint("START_AUTOREPEAT_SPELL: Ranged auto-shot started, isBow = true, swingStartBow = " .. swingStartBow)
    end
end

-- Event: STOP_AUTOREPEAT_SPELL (stop ranged auto-shot)
function MySwingTimerHunter:STOP_AUTOREPEAT_SPELL()
    isSwingingBow = false
    barBow:SetValue(0)
    barBow:Hide()
    barBow.label:Hide()
    ThrottleDebugPrint("STOP_AUTOREPEAT_SPELL: Ranged auto-shot stopped")
end

-- Event: UNIT_INVENTORY_CHANGED (update speed on weapon change)
function MySwingTimerHunter:UNIT_INVENTORY_CHANGED(unit)
    if unit == "player" then
        UpdateRangedSwingDuration()
    end
end

-- Event: UNIT_RANGEDDAMAGE (update ranged speed on change)
function MySwingTimerHunter:UNIT_RANGEDDAMAGE(unit)
    if unit == "player" then
        UpdateRangedSwingDuration(true)
        ThrottleDebugPrint("UNIT_RANGEDDAMAGE: Updated ranged swing duration, isBow = " .. tostring(isBow))
    end
end

-- Event: UNIT_SPELLCAST_SUCCEEDED (reset for ranged auto-shot)
function MySwingTimerHunter:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellId)
    if unit == "player" and spellId == 75 and isBow then  -- Auto Shot
        if swingDurationBow > 0 then
            swingStartBow = GetTime()
            isSwingingBow = true
            barBow:Show()
            barBow.label:Show()
            ThrottleDebugPrint("UNIT_SPELLCAST_SUCCEEDED: Auto Shot detected, swingStartBow = " .. swingStartBow)
        end
    end
end

-- OnUpdate: Update the ranged bar every frame
MySwingTimerHunter:SetScript("OnUpdate", function(self, elapsed)
    if not inCombat and not MySwingTimerDB.showOutsideCombat then
        barBow:SetValue(0)
        barBow:Hide()
        barBow.label:Hide()
        isSwingingBow = false
        return
    end
    if not isBow then
        barBow:SetValue(0)
        barBow:Hide()
        barBow.label:Hide()
        isSwingingBow = false
        return
    end
    if not isSwingingBow then
        barBow:SetValue(0)
    else
        local timeElapsedBow = GetTime() - swingStartBow
        local progressBow = timeElapsedBow / swingDurationBow
        if progressBow >= 1 then
            if progressBow > 1.5 then  -- Timeout for stop detection
                isSwingingBow = false
                barBow:SetValue(0)
                barBow:Hide()
                barBow.label:Hide()
            else
                barBow:SetValue(1)
            end
        elseif progressBow < 0 or progressBow ~= progressBow then  -- Check for negative or NaN
            progressBow = 0
        else
            barBow:SetValue(progressBow)
        end
    end
    -- Maintain barBow position relative to barMH during drag
    if isDragging and MySwingTimerDB.lockBars and draggedBar == barMH and barMH and barBow then
        barBow:ClearAllPoints()
        barBow:SetPoint("TOPLEFT", barOH or barMH, "BOTTOMLEFT", 0, -2)
        barBow:Show()
        barBow.label:Show()
        print("[MySwingTimerHunter Debug] Dragging locked bars, barBow visible = " .. tostring(barBow:IsVisible()))
    end
    -- Keep dragHandle anchored to barMH when locked
    if MySwingTimerDB.lockBars and barMH and (dualWield or isBow) and dragHandle then
        dragHandle:ClearAllPoints()
        dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)
            end
        end)