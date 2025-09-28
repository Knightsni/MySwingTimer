-- MySwingTimer.lua
-- Basic weapon swing timer for WoW Classic melee and ranged (hunter auto-shot and wands), with dual wield, haste buff support, and bar locking

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
local isRanged = false  -- Flag for ranged vs melee
inCombat = false  -- Track if player is in combat (global for options access)
local hasHasteBuff = false  -- Track any haste buff status
local isDragging = false  -- Track if either bar is being dragged
local draggedBar = nil  -- Track which bar is being dragged

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
    if MySwingTimerDB.lockBars and barMH and barOH then
        draggedBar = barMH  -- Set draggedBar for reference
        barMH:StartMoving()
        isDragging = true
    end
end)
dragHandle:SetScript("OnDragStop", function(self)
    if MySwingTimerDB.lockBars and barMH and barOH then
        barMH:StopMovingOrSizing()
        barOH:ClearAllPoints()
        barOH:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)  -- Anchor OH to MH
        MySwingTimerDB.pointMH = "BOTTOMLEFT"
        MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
        MySwingTimerDB.xMH = barMH:GetLeft() or 0
        MySwingTimerDB.yMH = barMH:GetBottom() or 0
        MySwingTimerDB.pointOH = "BOTTOMLEFT"
        MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
        MySwingTimerDB.xOH = barOH:GetLeft() or 0
        MySwingTimerDB.yOH = barOH:GetBottom() or 0
        dragHandle:ClearAllPoints()
        dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
        dragHandle:Show()
        barMH:Show()
        barOH:Show()  -- Ensure both bars remain visible
    end
    isDragging = false
    draggedBar = nil
    barMH.border:Hide()
    barOH.border:Hide()
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
barMH = CreateFrame("StatusBar", nil, UIParent)  -- Main hand or ranged bar (global for options access)
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
    MySwingTimerDB.pointMH = "BOTTOMLEFT"
    MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
    MySwingTimerDB.xMH = self:GetLeft() or 0
    MySwingTimerDB.yMH = self:GetBottom() or 0
    isDragging = false
    draggedBar = nil
    barMH.border:Hide()
    barOH.border:Hide()
    if MySwingTimerDB.lockBars and dragHandle then
        dragHandle:Show()
    else
        if dragHandle then dragHandle:Hide() end
    end
    if dualWield then
        local snapThreshold = 8  -- Snap threshold for locking
        local unlockThreshold = 12  -- Reduced threshold for unlocking
        local distanceMHBelowOH = math.abs(mhBottom - ohTop)
        local distanceMHAboveOH = math.abs(mhTop - ohBottom)
        local distanceOHBelowMH = math.abs(ohBottom - mhTop)
        local distanceOHAboveMH = math.abs(ohTop - mhBottom)
        if distanceMHBelowOH <= snapThreshold or distanceOHAboveMH <= snapThreshold then
            -- Snap MH below OH or OH above MH
            local left = self:GetLeft()
            local ohBottomY = barOH:GetBottom()
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, ohBottomY - 2)
            barOH:ClearAllPoints()
            barOH:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)  -- Anchor OH to MH
            MySwingTimerDB.lockBars = true
            dragHandle:ClearAllPoints()
            dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
            dragHandle:Show()
            MySwingTimerDB.pointMH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
            MySwingTimerDB.xMH = self:GetLeft() or 0
            MySwingTimerDB.yMH = self:GetBottom() or 0
            MySwingTimerDB.pointOH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
            MySwingTimerDB.xOH = barOH:GetLeft() or 0
            MySwingTimerDB.yOH = barOH:GetBottom() or 0
            barMH:Show()
            barOH:Show()
        elseif distanceMHAboveOH <= snapThreshold or distanceOHBelowMH <= snapThreshold then
            -- Snap MH above OH or OH below MH
            local left = self:GetLeft()
            local ohTopY = barOH:GetTop()
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, ohTopY - self:GetHeight() - 2)
            barOH:ClearAllPoints()
            barOH:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)  -- Anchor OH to MH
            MySwingTimerDB.lockBars = true
            dragHandle:ClearAllPoints()
            dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
            dragHandle:Show()
            MySwingTimerDB.pointMH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
            MySwingTimerDB.xMH = self:GetLeft() or 0
            MySwingTimerDB.yMH = self:GetBottom() or 0
            MySwingTimerDB.pointOH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
            MySwingTimerDB.xOH = barOH:GetLeft() or 0
            MySwingTimerDB.yOH = barOH:GetBottom() or 0
            barMH:Show()
            barOH:Show()
        elseif distanceMHBelowOH > unlockThreshold and distanceMHAboveOH > unlockThreshold and distanceOHBelowMH > unlockThreshold and distanceOHAboveMH > unlockThreshold then
            MySwingTimerDB.lockBars = false
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
    MySwingTimerDB.pointOH = "BOTTOMLEFT"
    MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
    MySwingTimerDB.xOH = self:GetLeft() or 0
    MySwingTimerDB.yOH = self:GetBottom() or 0
    isDragging = false
    draggedBar = nil
    barMH.border:Hide()
    barOH.border:Hide()
    if MySwingTimerDB.lockBars and dragHandle then
        dragHandle:Show()
    else
        if dragHandle then dragHandle:Hide() end
    end
    if dualWield then
        local snapThreshold = 8  -- Snap threshold for locking
        local unlockThreshold = 12  -- Larger threshold for unlocking
        local distanceMHBelowOH = math.abs(ohBottom - mhTop)
        local distanceMHAboveOH = math.abs(ohTop - mhBottom)
        local distanceOHBelowMH = math.abs(mhBottom - ohTop)
        local distanceOHAboveMH = math.abs(mhTop - ohBottom)
        if distanceMHBelowOH <= snapThreshold or distanceOHAboveMH <= snapThreshold then
            -- Snap MH below OH or OH above MH
            local left = barMH:GetLeft()
            local ohBottomY = self:GetBottom()
            barMH:ClearAllPoints()
            barMH:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, ohBottomY - 2)
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)  -- Anchor OH to MH
            MySwingTimerDB.lockBars = true
            dragHandle:ClearAllPoints()
            dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
            dragHandle:Show()
            MySwingTimerDB.pointMH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
            MySwingTimerDB.xMH = barMH:GetLeft() or 0
            MySwingTimerDB.yMH = barMH:GetBottom() or 0
            MySwingTimerDB.pointOH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
            MySwingTimerDB.xOH = self:GetLeft() or 0
            MySwingTimerDB.yOH = self:GetBottom() or 0
            barMH:Show()
            barOH:Show()
        elseif distanceMHAboveOH <= snapThreshold or distanceOHBelowMH <= snapThreshold then
            -- Snap MH above OH or OH below MH
            local left = barMH:GetLeft()
            local ohTopY = self:GetTop()
            barMH:ClearAllPoints()
            barMH:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, ohTopY - barMH:GetHeight() - 2)
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", barMH, "BOTTOMLEFT", 0, -2)  -- Anchor OH to MH
            MySwingTimerDB.lockBars = true
            dragHandle:ClearAllPoints()
            dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
            dragHandle:Show()
            MySwingTimerDB.pointMH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
            MySwingTimerDB.xMH = barMH:GetLeft() or 0
            MySwingTimerDB.yMH = barMH:GetBottom() or 0
            MySwingTimerDB.pointOH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
            MySwingTimerDB.xOH = self:GetLeft() or 0
            MySwingTimerDB.yOH = self:GetBottom() or 0
            barMH:Show()
            barOH:Show()
        elseif distanceMHBelowOH > unlockThreshold and distanceMHAboveOH > unlockThreshold and distanceOHBelowMH > unlockThreshold and distanceOHAboveMH > unlockThreshold then
            MySwingTimerDB.lockBars = false
        end
    end
end)

-- Function: Update swing durations on change (weapon speed, dual wield, haste)
function UpdateSwingDuration(preserveProgress)
    local oldDurationMH = swingDurationMH
    local oldDurationOH = swingDurationOH
    swingDurationMH, swingDurationOH = UnitAttackSpeed("player")
    swingDurationMH = swingDurationMH or 0
    swingDurationOH = swingDurationOH or 0
    dualWield = swingDurationOH > 0
    if dualWield then
        barOH:Show()
        barOH.label:Show()
        if MySwingTimerDB.lockBars then
            dragHandle:ClearAllPoints()
            dragHandle:SetPoint("CENTER", barMH, "RIGHT", 10, 0)  -- Anchor to barMH's right side
            dragHandle:Show()
        end
    else
        dualWield = false
        swingDurationOH = 0
        isSwingingOH = false
        barOH:Hide()
        barOH.label:Hide()
        dragHandle:Hide()
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
        DEFAULT_CHAT_FRAME:AddMessage("/myswingtimer for options")
    end)
end

-- Event: PLAYER_LOGOUT (save positions before logout)
function MySwingTimer:PLAYER_LOGOUT()
    if barMH and barOH then
        MySwingTimerDB.pointMH = "BOTTOMLEFT"
        MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
        MySwingTimerDB.xMH = barMH:GetLeft() or 0
        MySwingTimerDB.yMH = barMH:GetBottom() or 0
        MySwingTimerDB.pointOH = "BOTTOMLEFT"
        MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
        MySwingTimerDB.xOH = barOH:GetLeft() or 0
        MySwingTimerDB.yOH = barOH:GetBottom() or 0
    end
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

-- Event: UNIT_SPELLCAST_SUCCEEDED (reset for on-next-swing abilities - MH)
function MySwingTimer:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellId)
    if unit == "player" then
        if onNextSwingSpells[spellId] then  -- On-next-swing abilities (Heroic Strike, Raptor Strike, etc.) - reset MH
            if swingDurationMH > 0 then
                swingStartMH = GetTime()
                isSwingingMH = true
                barMH:Show()
                barMH.label:Show()
            end
        end
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
end)

-- Register events
MySwingTimer:RegisterEvent("PLAYER_LOGIN")
MySwingTimer:RegisterEvent("PLAYER_LOGOUT")
MySwingTimer:RegisterEvent("PLAYER_REGEN_DISABLED")
MySwingTimer:RegisterEvent("PLAYER_REGEN_ENABLED")
MySwingTimer:RegisterEvent("UNIT_AURA")
MySwingTimer:RegisterEvent("UNIT_INVENTORY_CHANGED")
MySwingTimer:RegisterEvent("UNIT_ATTACK_SPEED")
MySwingTimer:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
MySwingTimer:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")