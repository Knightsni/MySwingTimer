-- MySwingTimerRanged.lua
-- Ranged swing timer for Hunters in WoW Classic

local MySwingTimerRanged = CreateFrame("Frame", "MySwingTimerRangedFrame", UIParent)
MySwingTimerRanged:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

MySwingTimerRanged:RegisterEvent("PLAYER_LOGIN")

function MySwingTimerRanged:PLAYER_LOGIN()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
        return
    end

    -- Variables (global for main integration)
    swingStartRanged = 0  -- Timestamp when the last ranged swing started
    swingDurationRanged = 0  -- Ranged weapon speed
    isSwingingRanged = false  -- Flag for active ranged swing

    -- Table of haste buff spell IDs (duplicated for independence)
    local hasteBuffs = {
        [22888] = true,  -- Warchief's Blessing
        [26480] = true,  -- Flurry (Warrior rank 1)
        [12966] = true, -- Flurry (Warrior rank 2)
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

    local hasHasteBuff = false  -- Local for ranged

    -- Check initial haste buff status
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if name and hasteBuffs[spellId] then
            hasHasteBuff = true
            break
        end
    end

    -- Function to update ranged duration
    local function UpdateRangedDuration(preserveProgress)
        local oldDurationRanged = swingDurationRanged
        swingDurationRanged = UnitRangedDamage("player") or 0
        if preserveProgress and isSwingingRanged and oldDurationRanged > 0 and swingDurationRanged > 0 then
            local progressRanged = (GetTime() - swingStartRanged) / oldDurationRanged
            swingStartRanged = GetTime() - (progressRanged * swingDurationRanged)
        end
    end

    UpdateRangedDuration()  -- Initial ranged speed

    -- Create ranged bar (global)
    barRanged = CreateFrame("StatusBar", nil, UIParent)
    barRanged:SetSize(200, 20)
    barRanged:SetPoint("CENTER", 0, -44)  -- Default below OH
    barRanged:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barRanged:SetStatusBarColor(0.5, 1, 0)  -- Green for distinction
    barRanged:SetMinMaxValues(0, 1)
    barRanged:SetValue(0)
    barRanged.bg = barRanged:CreateTexture(nil, "BACKGROUND")
    barRanged.bg:SetAllPoints(true)
    barRanged.bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    barRanged.bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)
    barRanged.border = barRanged:CreateTexture(nil, "BORDER")
    barRanged.border:SetAllPoints(true)
    barRanged.border:SetTexture("Interface\\Buttons\\UI-Quickslot")
    barRanged.border:SetVertexColor(1, 1, 1, 0.4)
    barRanged.border:Hide()
    -- Add Ranged label
    barRanged.label = barRanged:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barRanged.label:SetPoint("CENTER", barRanged, "CENTER", 0, 0)
    barRanged.label:SetText("Ranged")
    barRanged.label:SetTextColor(1, 1, 1, 0.7)

    -- Make barRanged movable
    barRanged:SetMovable(true)
    barRanged:EnableMouse(true)
    barRanged:RegisterForDrag("LeftButton")
    barRanged:SetScript("OnDragStart", function(self)
        if MySwingTimerDB.lockBars then
            draggedBar = barMH
            barMH:StartMoving()
        else
            self:StartMoving()
            draggedBar = self
        end
        isDragging = true
    end)
    barRanged:SetScript("OnDragStop", function(self)
        if MySwingTimerDB.lockBars then
            barMH:StopMovingOrSizing()
            if dualWield and barOH then
                barOH:ClearAllPoints()
                barOH:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)
            end
            barRanged:ClearAllPoints()
            local anchor = dualWield and barOH or barMH
            barRanged:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
            MySwingTimerDB.pointMH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
            MySwingTimerDB.xMH = barMH:GetLeft() or 0
            MySwingTimerDB.yMH = barMH:GetBottom() or 0
            if dualWield then
                MySwingTimerDB.pointOH = "BOTTOMLEFT"
                MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
                MySwingTimerDB.xOH = barOH:GetLeft() or 0
                MySwingTimerDB.yOH = barOH:GetBottom() or 0
            end
            MySwingTimerDB.pointRanged = "BOTTOMLEFT"
            MySwingTimerDB.relativePointRanged = "BOTTOMLEFT"
            MySwingTimerDB.xRanged = barRanged:GetLeft() or 0
            MySwingTimerDB.yRanged = barRanged:GetBottom() or 0
            barMH:Show()
            if dualWield then barOH:Show() end
            barRanged:Show()
        else
            self:StopMovingOrSizing()
        end
        local rangedTop, rangedBottom = self:GetTop() or 0, self:GetBottom() or 0
        MySwingTimerDB.pointRanged = "BOTTOMLEFT"
        MySwingTimerDB.relativePointRanged = "BOTTOMLEFT"
        MySwingTimerDB.xRanged = self:GetLeft() or 0
        MySwingTimerDB.yRanged = self:GetBottom() or 0
        isDragging = false
        draggedBar = nil
        barMH.border:Hide()
        if barOH then barOH.border:Hide() end
        self.border:Hide()
        local snapThreshold = 8
        local unlockThreshold = 12
        local anchor = (dualWield and barOH or barMH)
        local anchorTop, anchorBottom = anchor:GetTop() or 0, anchor:GetBottom() or 0
        local distanceBelow = math.abs(rangedBottom - anchorTop)
        local distanceAbove = math.abs(rangedTop - anchorBottom)
        local distanceLeft = math.abs(self:GetLeft() - anchor:GetLeft())
        if distanceLeft <= snapThreshold and (distanceBelow <= snapThreshold or distanceAbove <= snapThreshold) then
            -- Snap to anchor
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
            MySwingTimerDB.lockBars = true
            MySwingTimerDB.pointRanged = "BOTTOMLEFT"
            MySwingTimerDB.relativePointRanged = "BOTTOMLEFT"
            MySwingTimerDB.xRanged = self:GetLeft() or 0
            MySwingTimerDB.yRanged = self:GetBottom() or 0
            barRanged:Show()
        elseif distanceBelow > unlockThreshold and distanceAbove > unlockThreshold then
            MySwingTimerDB.lockBars = false
        end
    end)

    -- Load saved position for ranged
    local screenWidth, screenHeight = GetPhysicalScreenSize()
    local validRangedPosition = MySwingTimerDB and MySwingTimerDB.pointRanged == "BOTTOMLEFT" and MySwingTimerDB.xRanged and MySwingTimerDB.yRanged and
                                MySwingTimerDB.xRanged >= 0 and MySwingTimerDB.xRanged <= screenWidth and MySwingTimerDB.yRanged >= -screenHeight and MySwingTimerDB.yRanged <= screenHeight
    if validRangedPosition then
        barRanged:ClearAllPoints()
        barRanged:SetPoint(MySwingTimerDB.pointRanged, UIParent, MySwingTimerDB.relativePointRanged, MySwingTimerDB.xRanged, MySwingTimerDB.yRanged)
    else
        barRanged:ClearAllPoints()
        barRanged:SetPoint("CENTER", 0, -44)
        MySwingTimerDB.pointRanged = "BOTTOMLEFT"
        MySwingTimerDB.relativePointRanged = "BOTTOMLEFT"
        MySwingTimerDB.xRanged = barRanged:GetLeft() or 0
        MySwingTimerDB.yRanged = barRanged:GetBottom() or 0
    end

    -- Register ranged-specific events
    self:RegisterEvent("START_AUTOREPEAT_SPELL")
    self:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    self:RegisterEvent("UNIT_RANGEDDAMAGE")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")

    -- OnUpdate for ranged bar
    self:SetScript("OnUpdate", function(self, elapsed)
        if not inCombat and not MySwingTimerDB.showOutsideCombat then
            barRanged:SetValue(0)
            barRanged:Hide()
            barRanged.label:Hide()
            isSwingingRanged = false
            return
        end

        if not isSwingingRanged then
            barRanged:SetValue(0)
        else
            local timeElapsedRanged = GetTime() - swingStartRanged
            local progressRanged = timeElapsedRanged / swingDurationRanged
            if progressRanged >= 1 then
                if not inCombat and progressRanged > 1.5 then  -- Timeout only out of combat
                    isSwingingRanged = false
                    barRanged:SetValue(0)
                else
                    barRanged:SetValue(1)
                end
            elseif progressRanged < 0 or progressRanged ~= progressRanged then
                progressRanged = 0
            else
                barRanged:SetValue(progressRanged)
            end
        end
    end)
end

function MySwingTimerRanged:START_AUTOREPEAT_SPELL()
    local duration = UnitRangedDamage("player") or 0
    if duration > 0 then
        swingStartRanged = GetTime() - duration + 0.5  -- First shot delay
        isSwingingRanged = true
        barRanged:Show()
        barRanged.label:Show()
    end
end

function MySwingTimerRanged:STOP_AUTOREPEAT_SPELL()
    isSwingingRanged = false
    barRanged:SetValue(0)
end

function MySwingTimerRanged:UNIT_RANGEDDAMAGE(unit)
    if unit == "player" then
        local oldDuration = swingDurationRanged
        swingDurationRanged = UnitRangedDamage("player") or 0
        if isSwingingRanged and oldDuration > 0 and swingDurationRanged > 0 then
            local progress = (GetTime() - swingStartRanged) / oldDuration
            swingStartRanged = GetTime() - (progress * swingDurationRanged)
        end
    end
end

function MySwingTimerRanged:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellId)
    if unit == "player" and (spellId == 75 or spellId == 5019) then  -- Auto Shot or Wand Shoot
        if swingDurationRanged > 0 then
            swingStartRanged = GetTime()
            isSwingingRanged = true
            barRanged:Show()
            barRanged.label:Show()
        end
    end
end

function MySwingTimerRanged:UNIT_AURA(unit)
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
            local oldDuration = swingDurationRanged
            swingDurationRanged = UnitRangedDamage("player") or 0
            if isSwingingRanged and oldDuration > 0 and swingDurationRanged > 0 then
                local progress = (GetTime() - swingStartRanged) / oldDuration
                swingStartRanged = GetTime() - (progress * swingDurationRanged)
            end
        end
    end
end

function MySwingTimerRanged:UNIT_INVENTORY_CHANGED(unit)
    if unit == "player" then
        local oldDuration = swingDurationRanged
        swingDurationRanged = UnitRangedDamage("player") or 0
        if isSwingingRanged and oldDuration > 0 and swingDurationRanged > 0 then
            local progress = (GetTime() - swingStartRanged) / oldDuration
            swingStartRanged = GetTime() - (progress * swingDurationRanged)
        end
    end
end