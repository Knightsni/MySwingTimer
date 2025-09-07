-- MySwingTimer.lua
-- Basic weapon swing timer for WoW Classic melee (main hand and offhand), with dual wield, haste buff support, and bar locking

-- Initialize saved variables early
MySwingTimerDB = MySwingTimerDB or {}
MySwingTimerDB.showOutsideCombat = MySwingTimerDB.showOutsideCombat or true  -- Default to true for visibility
MySwingTimerDB.lockBars = MySwingTimerDB.lockBars or false  -- Track if bars are locked

local MySwingTimer = CreateFrame("Frame", "MySwingTimerFrame", UIParent)
MySwingTimer:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

-- Variables
local swingStartMH = 0  -- Timestamp when the last main hand swing started
local swingDurationMH = 0  -- Main hand weapon speed
local isSwingingMH = false  -- Flag for active main hand swing
local swingStartOH = 0  -- Timestamp when the last offhand swing started
local swingDurationOH = 0  -- Offhand weapon speed
local isSwingingOH = false  -- Flag for active offhand swing
local dualWield = false  -- Flag for dual wield detection
inCombat = false  -- Track if player is in combat (global for options access)
local hasHasteBuff = false  -- Track any haste buff status
local isDragging = false  -- Track if either bar is being dragged
local draggedBar = nil  -- Track which bar is being dragged
local lastDebugTime = 0  -- Timestamp for throttling debug messages
local debugThrottleInterval = 600  -- 10 minutes in seconds

-- Throttle debug messages to one every 10 minutes
local function ThrottleDebugPrint(message)
    local currentTime = GetTime()
    if currentTime - lastDebugTime >= debugThrottleInterval then
        print("[MySwingTimer Debug] " .. message)
        lastDebugTime = currentTime
    end
end

-- Table of haste buff spell IDs
local hasteBuffs = {
    [22888] = true,  -- Warchief's Blessing
    [26480] = true,  -- Flurry (Warrior rank 1)
    [12966] = true,  -- Flurry (Warrior rank 2)
    [12967] = true,  -- Flurry (Warrior rank 3)
    [12968] = true,  -- Flurry (Warrior rank 4)
    [12969] = true,  -- Flurry (Warrior rank 5)
    [12328] = true,  -- Flurry (Shaman rank 1)
    [16236] = true,  -- Flurry (Shaman rank 2)
    [16281] = true,  -- Flurry (Shaman rank 3)
    [16282] = true,  -- Flurry (Shaman rank 4)
    [16283] = true,  -- Flurry (Shaman rank 5)
    [20572] = true,  -- Berserking (Troll racial)
    [13750] = true,  -- Blade Flurry (Rogue)
    [20007] = true,  -- Serpent's Swiftness (Hunter rank 1)
    [20012] = true,  -- Serpent's Swiftness (Hunter rank 2)
    [20013] = true,  -- Serpent's Swiftness (Hunter rank 3)
    [20014] = true,  -- Serpent's Swiftness (Hunter rank 4)
    [20015] = true,  -- Serpent's Swiftness (Hunter rank 5)
    [19621] = true,  -- Improved Aspect of the Hawk (Hunter rank 1)
    [19582] = true,  -- Improved Aspect of the Hawk (Hunter rank 2)
    [19583] = true,  -- Improved Aspect of the Hawk (Hunter rank 3)
    [19584] = true,  -- Improved Aspect of the Hawk (Hunter rank 4)
    [19585] = true,  -- Improved Aspect of the Hawk (Hunter rank 5)
    [26393] = true,  -- Juju Flurry
}

-- Table of on-next-swing ability spell IDs (Heroic Strike, Cleave, Raptor Strike, Maul ranks) - affect MH
local onNextSwingSpells = {
    [78] = true, [284] = true, [285] = true, [1608] = true, [11564] = true,
    [11565] = true, [11566] = true, [11567] = true, [25286] = true,
    [475] = true, [845] = true, [7369] = true, [11608] = true, [11609] = true,
    [2973] = true, [14260] = true, [14261] = true, [14262] = true, [14263] = true,
    [14264] = true, [14265] = true, [14266] = true,
    [6807] = true, [6808] = true, [6809] = true, [8972] = true, [9745] = true,
    [9880] = true, [9881] = true, [26997] = true
}

-- Table of paladin seal spell IDs that may trigger with first swing - affect MH
local paladinSealSpells = {
    [20280] = true, [20281] = true, [20282] = true, [20283] = true, [20284] = true,
    [20285] = true, [20286] = true, [21084] = true,
    [20424] = true
}

-- Create drag handle for locked bars (global)
dragHandle = CreateFrame("Frame", nil, UIParent)
dragHandle:SetSize(28, 28)  -- Padlock icon
dragHandle:SetPoint("CENTER", 0, -15)  -- Initial position
dragHandle.bg = dragHandle:CreateTexture(nil, "BACKGROUND")
dragHandle.bg:SetAllPoints(true)
dragHandle.bg:SetTexture("Interface\\Icons\\INV_Misc_Key_14")  -- Lock-like padlock icon
dragHandle.bg:SetVertexColor(1, 1, 1, 1)  -- Full opacity
dragHandle.border = dragHandle:CreateTexture(nil, "BORDER")
dragHandle.border:SetAllPoints(true)
dragHandle.border:SetTexture("Interface\\Buttons\\UI-Quickslot")  -- Clean white border
dragHandle.border:SetVertexColor(1, 1, 1, 0.2)  -- Subtle white border
dragHandle:Hide()
dragHandle:SetMovable(true)
dragHandle:EnableMouse(true)
dragHandle:RegisterForDrag("LeftButton")
dragHandle:SetScript("OnDragStart", function(self)
    if MySwingTimerDB.lockBars and barMH then
        draggedBar = barMH  -- Set draggedBar for reference
        print("[MySwingTimer Debug] Drag handle started, lockBars = " .. tostring(MySwingTimerDB.lockBars) .. ", draggedBar = barMH")
        barMH:StartMoving()
        isDragging = true
    else
        print("[MySwingTimer Debug] Drag handle error: lockBars = " .. tostring(MySwingTimerDB.lockBars) .. ", barMH = " .. tostring(barMH))
    end
end)
dragHandle:SetScript("OnDragStop", function(self)
    if MySwingTimerDB.lockBars and barMH then
        barMH:StopMovingOrSizing()
        if barOH then
            barOH:ClearAllPoints()
            barOH:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)
        end
        if barBow then
            barBow:ClearAllPoints()
            barBow:SetPoint("TOPLEFT", barOH or barMH, "BOTTOMLEFT", 0, -2)
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
        if barBow then
            MySwingTimerDB.pointBow = "BOTTOMLEFT"
            MySwingTimerDB.relativePointBow = "BOTTOMLEFT"
            MySwingTimerDB.xBow = barBow:GetLeft() or 0
            MySwingTimerDB.yBow = barBow:GetBottom() or 0
        end
        dragHandle:ClearAllPoints()
        dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
        dragHandle:Show()
        barMH:Show()
        if barOH then barOH:Show() end
        if barBow then barBow:Show() end
        print("[MySwingTimer Debug] Drag handle stopped, lockBars = " .. tostring(MySwingTimerDB.lockBars) .. ", barMH pos = x: " .. tostring(MySwingTimerDB.xMH) .. ", y: " .. tostring(MySwingTimerDB.yMH) .. ", barOH pos = x: " .. tostring(MySwingTimerDB.xOH or "N/A") .. ", y: " .. tostring(MySwingTimerDB.yOH or "N/A") .. ", barBow pos = x: " .. tostring(MySwingTimerDB.xBow or "N/A") .. ", y: " .. tostring(MySwingTimerDB.yBow or "N/A"))
    end
    isDragging = false
    draggedBar = nil
    barMH.border:Hide()
    if barOH then barOH.border:Hide() end
    if barBow then barBow.border:Hide() end
end)
dragHandle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Drag to move locked bars")
    GameTooltip:Show()
end)
dragHandle:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)
dragHandle:SetScript("OnShow", function(self)
    self:SetScale(1.2)  -- Scale up slightly when shown
    UIFrameFadeIn(self, 0.2, 0.8, 1)  -- Fade in animation
end)

-- UI: Create movable progress bars
barMH = CreateFrame("StatusBar", nil, UIParent)  -- Main hand bar (global for options access)
barMH:SetSize(200, 20)  -- Width, Height
barMH:SetPoint("CENTER", 0, 0)  -- Middle of screen
barMH:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")  -- Simple texture
barMH:SetStatusBarColor(1, 0.5, 0)  -- Orange color
barMH:SetMinMaxValues(0, 1)
barMH:SetValue(0)
barMH.bg = barMH:CreateTexture(nil, "BACKGROUND")
barMH.bg:SetAllPoints(true)
barMH.bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
barMH.bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)  -- Dark background
barMH.border = barMH:CreateTexture(nil, "BORDER")
barMH.border:SetAllPoints(true)
barMH.border:SetTexture("Interface\\Buttons\\UI-Quickslot")  -- Clean white glow
barMH.border:SetVertexColor(1, 1, 1, 0.4)  -- Subtle white glow
barMH.border:Hide()
-- Add Mainhand label
barMH.label = barMH:CreateFontString(nil, "OVERLAY", "GameFontNormal")
barMH.label:SetPoint("CENTER", barMH, "CENTER", 0, 0)
barMH.label:SetText("Mainhand")
barMH.label:SetTextColor(1, 1, 1, 0.7)  -- White with 0.7 opacity
-- Add tooltip for unlocking
barMH:SetScript("OnEnter", function(self)
    if MySwingTimerDB.lockBars then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag vertically more than 12 pixels to unlock")
        GameTooltip:Show()
    end
end)
barMH:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Make barMH movable (drag with left-click)
barMH:SetMovable(true)
barMH:EnableMouse(true)
barMH:RegisterForDrag("LeftButton")
barMH:SetScript("OnDragStart", function(self)
    self:StartMoving()
    draggedBar = self
    isDragging = true
end)
barMH:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local mhTop, mhBottom = self:GetTop() or 0, self:GetBottom() or 0
    local ohTop, ohBottom = barOH and barOH:GetTop() or 0, barOH and barOH:GetBottom() or 0
    local bowTop, bowBottom = barBow and barBow:GetTop() or 0, barBow and barBow:GetBottom() or 0
    MySwingTimerDB.pointMH = "BOTTOMLEFT"
    MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
    MySwingTimerDB.xMH = self:GetLeft() or 0
    MySwingTimerDB.yMH = self:GetBottom() or 0
    isDragging = false
    draggedBar = nil
    barMH.border:Hide()
    if barOH then barOH.border:Hide() end
    if barBow then barBow.border:Hide() end
    if MySwingTimerDB.lockBars and dragHandle then
        dragHandle:Show()
    else
        if dragHandle then dragHandle:Hide() end
    end
    if dualWield or (barBow and barBow:IsVisible()) then
        local snapThreshold = 8  -- Snap threshold for locking
        local unlockThreshold = 12  -- Reduced threshold for unlocking
        local distances = {}
        if barOH then
            table.insert(distances, math.abs(mhBottom - ohTop))
            table.insert(distances, math.abs(mhTop - ohBottom))
            table.insert(distances, math.abs(ohBottom - mhTop))
            table.insert(distances, math.abs(ohTop - mhBottom))
        end
        if barBow then
            table.insert(distances, math.abs(mhBottom - bowTop))
            table.insert(distances, math.abs(mhTop - bowBottom))
            table.insert(distances, math.abs(bowBottom - mhTop))
            table.insert(distances, math.abs(bowTop - mhBottom))
            if barOH then
                table.insert(distances, math.abs(ohBottom - bowTop))
                table.insert(distances, math.abs(ohTop - bowBottom))
                table.insert(distances, math.abs(bowBottom - ohTop))
                table.insert(distances, math.abs(bowTop - ohBottom))
            end
        end
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
            local left = self:GetLeft() or 0
            local prevBottom = self:GetBottom() or 0
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, prevBottom)
            if barOH then
                barOH:ClearAllPoints()
                barOH:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)
            end
            if barBow then
                barBow:ClearAllPoints()
                barBow:SetPoint("TOPLEFT", barOH or barMH, "BOTTOMLEFT", 0, -2)
            end
            MySwingTimerDB.lockBars = true
            if dragHandle then
                dragHandle:ClearAllPoints()
                dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)
                dragHandle:Show()
            end
            MySwingTimerDB.pointMH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
            MySwingTimerDB.xMH = self:GetLeft() or 0
            MySwingTimerDB.yMH = self:GetBottom() or 0
            if barOH then
                MySwingTimerDB.pointOH = "BOTTOMLEFT"
                MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
                MySwingTimerDB.xOH = barOH:GetLeft() or 0
                MySwingTimerDB.yOH = barOH:GetBottom() or 0
            end
            if barBow then
                MySwingTimerDB.pointBow = "BOTTOMLEFT"
                MySwingTimerDB.relativePointBow = "BOTTOMLEFT"
                MySwingTimerDB.xBow = barBow:GetLeft() or 0
                MySwingTimerDB.yBow = barBow:GetBottom() or 0
            end
            barMH:Show()
            if barOH then barOH:Show() end
            if barBow then barBow:Show() end
            print("[MySwingTimer Debug] Bars snapped and locked, barMH pos = x: " .. tostring(MySwingTimerDB.xMH) .. ", y: " .. tostring(MySwingTimerDB.yMH) .. ", barOH pos = x: " .. tostring(MySwingTimerDB.xOH or "N/A") .. ", y: " .. tostring(MySwingTimerDB.yOH or "N/A") .. ", barBow pos = x: " .. tostring(MySwingTimerDB.xBow or "N/A") .. ", y: " .. tostring(MySwingTimerDB.yBow or "N/A"))
        elseif shouldUnlock then
            MySwingTimerDB.lockBars = false
            print("[MySwingTimer Debug] Bars unlocked")
        end
    end
end)

barOH = CreateFrame("StatusBar", nil, UIParent)  -- Offhand bar
barOH:SetSize(200, 20)  -- Width, Height
barOH:SetPoint("CENTER", 0, -22)  -- Middle of screen, below main hand
barOH:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")  -- Simple texture
barOH:SetStatusBarColor(0, 0.5, 1)  -- Blue color for distinction
barOH:SetMinMaxValues(0, 1)
barOH:SetValue(0)
barOH.bg = barOH:CreateTexture(nil, "BACKGROUND")
barOH.bg:SetAllPoints(true)
barOH.bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
barOH.bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)  -- Dark background
barOH.border = barOH:CreateTexture(nil, "BORDER")
barOH.border:SetAllPoints(true)
barOH.border:SetTexture("Interface\\Buttons\\UI-Quickslot")  -- Clean white glow
barOH.border:SetVertexColor(1, 1, 1, 0.4)  -- Subtle white glow
barOH.border:Hide()
-- Add Offhand label
barOH.label = barOH:CreateFontString(nil, "OVERLAY", "GameFontNormal")
barOH.label:SetPoint("CENTER", barOH, "CENTER", 0, 0)
barOH.label:SetText("Offhand")
barOH.label:SetTextColor(1, 1, 1, 0.7)  -- White with 0.7 opacity
-- Add tooltip for unlocking
barOH:SetScript("OnEnter", function(self)
    if MySwingTimerDB.lockBars then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag vertically more than 12 pixels to unlock")
        GameTooltip:Show()
    end
end)
barOH:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Make barOH movable (drag with left-click)
barOH:SetMovable(true)
barOH:EnableMouse(true)
barOH:RegisterForDrag("LeftButton")
barOH:SetScript("OnDragStart", function(self)
    self:StartMoving()
    draggedBar = self
    isDragging = true
end)
barOH:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local ohTop, ohBottom = self:GetTop() or 0, self:GetBottom() or 0
    local mhTop, mhBottom = barMH:GetTop() or 0, barMH:GetBottom() or 0
    local bowTop, bowBottom = barBow and barBow:GetTop() or 0, barBow and barBow:GetBottom() or 0
    MySwingTimerDB.pointOH = "BOTTOMLEFT"
    MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
    MySwingTimerDB.xOH = self:GetLeft() or 0
    MySwingTimerDB.yOH = self:GetBottom() or 0
    isDragging = false
    draggedBar = nil
    barMH.border:Hide()
    barOH.border:Hide()
    if barBow then barBow.border:Hide() end
    if MySwingTimerDB.lockBars and dragHandle then
        dragHandle:Show()
    else
        if dragHandle then dragHandle:Hide() end
    end
    if dualWield or (barBow and barBow:IsVisible()) then
        local snapThreshold = 8  -- Snap threshold for locking
        local unlockThreshold = 12  -- Reduced threshold for unlocking
        local distances = {}
        table.insert(distances, math.abs(ohBottom - mhTop))
        table.insert(distances, math.abs(ohTop - mhBottom))
        table.insert(distances, math.abs(mhBottom - ohTop))
        table.insert(distances, math.abs(mhTop - ohBottom))
        if barBow then
            table.insert(distances, math.abs(ohBottom - bowTop))
            table.insert(distances, math.abs(ohTop - bowBottom))
            table.insert(distances, math.abs(bowBottom - ohTop))
            table.insert(distances, math.abs(bowTop - ohBottom))
            table.insert(distances, math.abs(mhBottom - bowTop))
            table.insert(distances, math.abs(mhTop - bowBottom))
            table.insert(distances, math.abs(bowBottom - mhTop))
            table.insert(distances, math.abs(bowTop - mhBottom))
        end
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
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)
            if barBow then
                barBow:ClearAllPoints()
                barBow:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            end
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
            MySwingTimerDB.pointOH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
            MySwingTimerDB.xOH = self:GetLeft() or 0
            MySwingTimerDB.yOH = self:GetBottom() or 0
            if barBow then
                MySwingTimerDB.pointBow = "BOTTOMLEFT"
                MySwingTimerDB.relativePointBow = "BOTTOMLEFT"
                MySwingTimerDB.xBow = barBow:GetLeft() or 0
                MySwingTimerDB.yBow = barBow:GetBottom() or 0
            end
            barMH:Show()
            barOH:Show()
            if barBow then barBow:Show() end
            print("[MySwingTimer Debug] Bars snapped and locked, barMH pos = x: " .. tostring(MySwingTimerDB.xMH) .. ", y: " .. tostring(MySwingTimerDB.yMH) .. ", barOH pos = x: " .. tostring(MySwingTimerDB.xOH) .. ", y: " .. tostring(MySwingTimerDB.yOH) .. ", barBow pos = x: " .. tostring(MySwingTimerDB.xBow or "N/A") .. ", y: " .. tostring(MySwingTimerDB.yBow or "N/A"))
        elseif shouldUnlock then
            MySwingTimerDB.lockBars = false
            print("[MySwingTimer Debug] Bars unlocked")
        end
    end
end)

-- Function to update weapon speeds and detect dual wield
local function UpdateSwingDuration(preserveProgress)
    local oldDurationMH = swingDurationMH
    local oldDurationOH = swingDurationOH
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    swingDurationMH = mainSpeed or 0
    swingDurationOH = offSpeed or 0
    if offSpeed and offSpeed > 0 then
        -- Confirm offhand is a valid weapon (not shield or non-attacking item)
        local link = GetInventoryItemLink("player", 17)
        if link then
            local _, _, _, _, _, _, subType = GetItemInfo(link)
            ThrottleDebugPrint("UpdateSwingDuration: Offhand item type = " .. (subType or "none"))
            if subType == "One-Handed Axes" or subType == "One-Handed Maces" or subType == "One-Handed Swords" or subType == "Daggers" or subType == "Fist Weapons" then
                dualWield = true
                if inCombat or MySwingTimerDB.showOutsideCombat then
                    barOH:Show()
                    barOH.label:Show()
                end
                if MySwingTimerDB.lockBars then
                    dragHandle:ClearAllPoints()
                    dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)
                    dragHandle:Show()
                end
                ThrottleDebugPrint("UpdateSwingDuration: dualWield = true, swingDurationOH = " .. swingDurationOH)
            else
                dualWield = false
                swingDurationOH = 0
                isSwingingOH = false
                barOH:Hide()
                barOH.label:Hide()
                dragHandle:Hide()
                ThrottleDebugPrint("UpdateSwingDuration: Invalid offhand, dualWield = false")
            end
        else
            dualWield = false
            swingDurationOH = 0
            isSwingingOH = false
            barOH:Hide()
            barOH.label:Hide()
            dragHandle:Hide()
            ThrottleDebugPrint("UpdateSwingDuration: No offhand item, dualWield = false")
        end
    else
        dualWield = false
        swingDurationOH = 0
        isSwingingOH = false
        barOH:Hide()
        barOH.label:Hide()
        dragHandle:Hide()
        ThrottleDebugPrint("UpdateSwingDuration: No offhand speed, dualWield = false")
    end
    -- Scale OH swing timer if haste changes
    if preserveProgress and isSwingingOH and dualWield and oldDurationOH > 0 and swingDurationOH > 0 then
        local progressOH = (GetTime() - swingStartOH) / oldDurationOH
        swingStartOH = GetTime() - (progressOH * swingDurationOH)
    end
    -- Scale MH swing timer if haste changes
    if preserveProgress and isSwingingMH and oldDurationMH > 0 and swingDurationMH > 0 then
        local progressMH = (GetTime() - swingStartMH) / oldDurationMH
        swingStartMH = GetTime() - (progressMH * swingDurationMH)
    end
end

-- Event: PLAYER_LOGIN (initialize on login)
function MySwingTimer:PLAYER_LOGIN()
    -- Check initial haste buff status
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if name and hasteBuffs[spellId] then
            hasHasteBuff = true
            break
        end
    end
    UpdateSwingDuration()  -- Get initial weapon speeds
    -- Force bars to show initially to ensure they’re visible
    barMH:Show()
    barMH.label:Show()
    if dualWield then
        barOH:Show()
        barOH.label:Show()
    end
    -- Delay position setting to ensure frames are initialized
    C_Timer.After(0.1, function()
        -- Validate and load saved position for MH
        local screenWidth, screenHeight = GetPhysicalScreenSize()
        local validMHPosition = MySwingTimerDB and MySwingTimerDB.pointMH == "BOTTOMLEFT" and MySwingTimerDB.xMH and MySwingTimerDB.yMH and
                                MySwingTimerDB.xMH >= 0 and MySwingTimerDB.xMH <= screenWidth and MySwingTimerDB.yMH >= -screenHeight and MySwingTimerDB.yMH <= screenHeight
        if validMHPosition then
            barMH:ClearAllPoints()
            barMH:SetPoint(MySwingTimerDB.pointMH, UIParent, MySwingTimerDB.relativePointMH, MySwingTimerDB.xMH, MySwingTimerDB.yMH)
        else
            barMH:ClearAllPoints()
            barMH:SetPoint("CENTER", 0, 0)  -- Middle of screen
            MySwingTimerDB.pointMH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
            MySwingTimerDB.xMH = barMH:GetLeft() or 0
            MySwingTimerDB.yMH = barMH:GetBottom() or 0
        end
        -- Validate and load saved position for OH
        local validOHPosition = MySwingTimerDB and MySwingTimerDB.pointOH == "BOTTOMLEFT" and MySwingTimerDB.xOH and MySwingTimerDB.yOH and
                                MySwingTimerDB.xOH >= 0 and MySwingTimerDB.xOH <= screenWidth and MySwingTimerDB.yOH >= -screenHeight and MySwingTimerDB.yOH <= screenHeight
        if validOHPosition then
            barOH:ClearAllPoints()
            barOH:SetPoint(MySwingTimerDB.pointOH, UIParent, MySwingTimerDB.relativePointOH, MySwingTimerDB.xOH, MySwingTimerDB.yOH)
        else
            barOH:ClearAllPoints()
            barOH:SetPoint("CENTER", 0, -22)  -- Middle of screen, below main hand
            MySwingTimerDB.pointOH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
            MySwingTimerDB.xOH = barOH:GetLeft() or 0
            MySwingTimerDB.yOH = barOH:GetBottom() or 0
        end
        -- Reinitialize bar properties
        barMH:SetMinMaxValues(0, 1)
        barMH:SetValue(0)
        barMH:SetSize(200, 20)
        barMH:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barMH:SetStatusBarColor(1, 0.5, 0)  -- Orange
        barMH:SetFrameStrata("HIGH")
        barMH:SetFrameLevel(10)
        barOH:SetMinMaxValues(0, 1)
        barOH:SetValue(0)
        barOH:SetSize(200, 20)
        barOH:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barOH:SetStatusBarColor(0, 0.5, 1)  -- Blue
        barOH:SetFrameStrata("HIGH")
        barOH:SetFrameLevel(11)  -- Higher than barMH to avoid layering issues
        dragHandle:SetFrameStrata("HIGH")
        dragHandle:SetFrameLevel(12)  -- Highest to ensure visibility
        if MySwingTimerDB.showOutsideCombat or UnitAffectingCombat("player") then
            barMH:Show()
            barMH.label:Show()
            if dualWield then
                barOH:Show()
                barOH.label:Show()
                if MySwingTimerDB.lockBars then
                    dragHandle:ClearAllPoints()
                    dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
                    dragHandle:Show()
                end
            end
        else
            barMH:Hide()
            barMH.label:Hide()
            barOH:Hide()
            barOH.label:Hide()
            dragHandle:Hide()
        end
        if UnitAffectingCombat("player") then
            inCombat = true
        end
        local _, _, _, xMH, yMH = barMH:GetPoint()
        local _, _, _, xOH, yOH = barOH:GetPoint()
        print("[MySwingTimer Debug] PLAYER_LOGIN: dualWield = " .. tostring(dualWield) .. ", barMH visible = " .. tostring(barMH:IsVisible()) .. ", barMH pos = x: " .. tostring(xMH) .. ", y: " .. tostring(yMH) .. ", barOH visible = " .. tostring(barOH:IsVisible()) .. ", barOH pos = x: " .. tostring(xOH) .. ", y: " .. tostring(yOH) .. ", lockBars = " .. tostring(MySwingTimerDB.lockBars))
    end)
end

-- Event: PLAYER_LOGOUT (save positions before logout)
function MySwingTimer:PLAYER_LOGOUT()
    if barMH then
        MySwingTimerDB.pointMH = "BOTTOMLEFT"
        MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
        MySwingTimerDB.xMH = barMH:GetLeft() or 0
        MySwingTimerDB.yMH = barMH:GetBottom() or 0
    end
    if barOH then
        MySwingTimerDB.pointOH = "BOTTOMLEFT"
        MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
        MySwingTimerDB.xOH = barOH:GetLeft() or 0
        MySwingTimerDB.yOH = barOH:GetBottom() or 0
    end
    if barBow then
        MySwingTimerDB.pointBow = "BOTTOMLEFT"
        MySwingTimerDB.relativePointBow = "BOTTOMLEFT"
        MySwingTimerDB.xBow = barBow:GetLeft() or 0
        MySwingTimerDB.yBow = barBow:GetBottom() or 0
    end
    print("[MySwingTimer Debug] PLAYER_LOGOUT: Saved barMH pos = x: " .. tostring(MySwingTimerDB.xMH) .. ", y: " .. tostring(MySwingTimerDB.yMH) .. ", barOH pos = x: " .. tostring(MySwingTimerDB.xOH or "N/A") .. ", y: " .. tostring(MySwingTimerDB.yOH or "N/A") .. ", barBow pos = x: " .. tostring(MySwingTimerDB.xBow or "N/A") .. ", y: " .. tostring(MySwingTimerDB.yBow or "N/A"))
end

-- Event: PLAYER_REGEN_DISABLED (enter combat)
function MySwingTimer:PLAYER_REGEN_DISABLED()
    inCombat = true
    barMH:Show()
    barMH.label:Show()
    if dualWield then
        barOH:Show()
        barOH.label:Show()
        if MySwingTimerDB.lockBars then
            dragHandle:ClearAllPoints()
            dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
            dragHandle:Show()
        end
    end
    ThrottleDebugPrint("PLAYER_REGEN_DISABLED: dualWield = " .. tostring(dualWield) .. ", barOH visible = " .. tostring(barOH:IsVisible()) .. ", lockBars = " .. tostring(MySwingTimerDB.lockBars))
end

-- Event: PLAYER_REGEN_ENABLED (leave combat)
function MySwingTimer:PLAYER_REGEN_ENABLED()
    inCombat = false
    isSwingingMH = false
    isSwingingOH = false
    barMH:SetValue(0)
    barOH:SetValue(0)
    if not MySwingTimerDB.showOutsideCombat then
        barMH:Hide()
        barMH.label:Hide()
        barOH:Hide()
        barOH.label:Hide()
        if dragHandle then dragHandle:Hide() end
    elseif dualWield and MySwingTimerDB.lockBars then
        dragHandle:ClearAllPoints()
        dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
        dragHandle:Show()
    end
    ThrottleDebugPrint("PLAYER_REGEN_ENABLED: dualWield = " .. tostring(dualWield) .. ", barOH visible = " .. tostring(barOH:IsVisible()) .. ", lockBars = " .. tostring(MySwingTimerDB.lockBars))
end

-- Event: UNIT_AURA (check for haste buff changes)
function MySwingTimer:UNIT_AURA(unit)
    if unit == "player" then
        local found = false
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
            if name and hasteBuffs[spellId] then
                found = true
                break
            end
        end
        if found ~= hasHasteBuff then
            hasHasteBuff = found
            UpdateSwingDuration(true)  -- Update speeds and preserve swing progress
        end
    end
end

-- Event: UNIT_INVENTORY_CHANGED (update speed on weapon change)
function MySwingTimer:UNIT_INVENTORY_CHANGED(unit)
    if unit == "player" then
        UpdateSwingDuration()
    end
end

-- Event: UNIT_ATTACK_SPEED (update melee speed on change)
function MySwingTimer:UNIT_ATTACK_SPEED(unit)
    if unit == "player" then
        UpdateSwingDuration(true)  -- Preserve swing progress
    end
end

-- Event: COMBAT_LOG_EVENT_UNFILTERED (detect melee swings, paladin seals, and parry haste)
function MySwingTimer:COMBAT_LOG_EVENT_UNFILTERED()
    local timestamp, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, _ = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")

    if sourceGUID == playerGUID and inCombat then
        if subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED" then
            local isOffHand
            if subEvent == "SWING_DAMAGE" then
                isOffHand = select(21, CombatLogGetCurrentEventInfo()) or false
            elseif subEvent == "SWING_MISSED" then
                isOffHand = select(13, CombatLogGetCurrentEventInfo()) or false
            end
            if isOffHand then
                swingStartOH = GetTime()
                isSwingingOH = true
                barOH:Show()
                barOH.label:Show()
                if MySwingTimerDB.lockBars then
                    dragHandle:ClearAllPoints()
                    dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
                    dragHandle:Show()
                end
            else
                swingStartMH = GetTime()
                isSwingingMH = true
                barMH:Show()
                barMH.label:Show()
            end
        elseif subEvent == "SPELL_DAMAGE" then
            local spellId = select(12, CombatLogGetCurrentEventInfo())
            if paladinSealSpells[spellId] then  -- Paladin seal damage (e.g., Seal of Righteousness) - reset MH
                swingStartMH = GetTime()
                isSwingingMH = true
                barMH:Show()
                barMH.label:Show()
            end
        end
    end

    -- Parry haste: When player parries an incoming attack - affects MH only
    if sourceGUID ~= playerGUID and destGUID == playerGUID and subEvent == "SWING_MISSED" and inCombat then
        local missType = select(12, CombatLogGetCurrentEventInfo())
        if missType == "PARRY" then
            if isSwingingMH then
                swingStartMH = swingStartMH - (swingDurationMH * 0.4)
                -- Cap to prevent exceeding duration
                if (GetTime() - swingStartMH) > swingDurationMH then
                    swingStartMH = GetTime() - swingDurationMH + 0.001
                end
                barMH:Show()
                barMH.label:Show()
            end
        end
    end
end

-- OnUpdate: Update the progress bars every frame
MySwingTimer:SetScript("OnUpdate", function(self, elapsed)
    if not inCombat and not MySwingTimerDB.showOutsideCombat then
        barMH:SetValue(0)
        barOH:SetValue(0)
        barMH:Hide()
        barMH.label:Hide()
        barOH:Hide()
        barOH.label:Hide()
        if dragHandle then dragHandle:Hide() end
        isSwingingMH = false
        isSwingingOH = false
        return
    end

    -- Update MH bar
    if not isSwingingMH then
        barMH:SetValue(0)
    else
        local timeElapsedMH = GetTime() - swingStartMH
        local progressMH = timeElapsedMH / swingDurationMH
        if progressMH >= 1 then
            if progressMH > 1.5 then  -- Timeout for melee stop detection
                isSwingingMH = false
                barMH:SetValue(0)
            else
                barMH:SetValue(1)
            end
        elseif progressMH < 0 or progressMH ~= progressMH then  -- Check for negative or NaN
            progressMH = 0
        else
            barMH:SetValue(progressMH)
        end
    end

    -- Update OH bar if dual wielding
    if dualWield then
        if not isSwingingOH then
            barOH:SetValue(0)
        else
            local timeElapsedOH = GetTime() - swingStartOH
            if not timeElapsedOH then timeElapsedOH = 0 end
            local progressOH = timeElapsedOH / swingDurationOH
            if progressOH >= 1 then
                if progressOH > 1.5 then  -- Timeout for OH stop detection
                    isSwingingOH = false
                    barOH:SetValue(0)
                else
                    barOH:SetValue(1)
                end
            elseif progressOH < 0 or progressOH ~= progressOH then  -- Check for negative or NaN
                progressOH = 0
            else
                barOH:SetValue(progressOH)
            end
        end
    end

    -- Maintain barOH and barBow position relative to barMH during drag
    if isDragging and MySwingTimerDB.lockBars and draggedBar == barMH and barMH then
        if barOH then
            barOH:ClearAllPoints()
            barOH:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)
            barOH:Show()
            barOH.label:Show()
        end
        if barBow then
            barBow:ClearAllPoints()
            barBow:SetPoint("TOPLEFT", barOH or barMH, "BOTTOMLEFT", 0, -2)
            barBow:Show()
            barBow.label:Show()
        end
        print("[MySwingTimer Debug] Dragging locked bars, barOH visible = " .. tostring(barOH and barOH:IsVisible()) .. ", barBow visible = " .. tostring(barBow and barBow:IsVisible()))
    end

    -- Keep dragHandle anchored to barMH when locked
    if MySwingTimerDB.lockBars and barMH and (dualWield or (barBow and barBow:IsVisible())) and dragHandle then
        dragHandle:ClearAllPoints()
        dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)
        dragHandle:Show()
    end

    -- Check for locking condition during drag
    if isDragging and (dualWield or (barBow and barBow:IsVisible())) and draggedBar then
        local targetBar = (draggedBar == barMH) and (barOH or barBow) or barMH
        local draggedTop, draggedBottom = draggedBar:GetTop() or 0, draggedBar:GetBottom() or 0
        local targetTop, targetBottom = targetBar and targetBar:GetTop() or 0, targetBar and targetBar:GetBottom() or 0
        local snapThreshold = 8
        if targetBar and (math.abs(draggedBottom - targetTop) <= snapThreshold or math.abs(draggedTop - targetBottom) <= snapThreshold) then
            targetBar.border:Show()
        else
            if barOH then barOH.border:Hide() end
            if barBow then barBow.border:Hide() end
            barMH.border:Hide()
        end
    end
end)

-- Register events
MySwingTimer:RegisterEvent("PLAYER_LOGIN")
MySwingTimer:RegisterEvent("PLAYER_LOGOUT")
MySwingTimer:RegisterEvent("PLAYER_REGEN_DISABLED")
MySwingTimer:RegisterEvent("PLAYER_REGEN_ENABLED")
MySwingTimer:RegisterEvent("UNIT_AURA")
MySwingTimer:RegisterEvent("UNIT_INVENTORY_CHANGED")
MySwingTimer:RegisterEvent("UNIT_ATTACK_SPEED")
MySwingTimer:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")