-- MySwingTimerOptions.lua
-- Handles saved variables and slash commands for configuration

-- Slash command for configuration
SLASH_MYSWINGTIMER1 = "/myswingtimer"
SlashCmdList["MYSWINGTIMER"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "show" then
        MySwingTimerDB.showOutsideCombat = not MySwingTimerDB.showOutsideCombat
        -- Update bar visibility if out of combat
        if barMH and not inCombat then
            if MySwingTimerDB.showOutsideCombat then
                barMH:Show()
                barMH.label:Show()
                if dualWield and barOH then
                    barOH:Show()
                    barOH.label:Show()
                end
                if barRanged then
                    barRanged:Show()
                    barRanged.label:Show()
                end
            else
                barMH:Hide()
                barMH.label:Hide()
                if barOH then
                    barOH:Hide()
                    barOH.label:Hide()
                end
                if barRanged then
                    barRanged:Hide()
                    barRanged.label:Hide()
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage(MySwingTimerDB.showOutsideCombat and "Swing bar always shown" or "Swing bar hidden outside combat")
    elseif msg == "reset" then
        -- Reset saved variables and bar positions
        MySwingTimerDB = {}
        MySwingTimerDB.showOutsideCombat = true  -- Default to visible
        MySwingTimerDB.lockBars = false
        if barMH then
            barMH:ClearAllPoints()
            barMH:SetPoint("CENTER", 0, 0)  -- Middle of screen
            MySwingTimerDB.pointMH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointMH = "BOTTOMLEFT"
            MySwingTimerDB.xMH = barMH:GetLeft() or 0
            MySwingTimerDB.yMH = barMH:GetBottom() or 0
        end
        if barOH then
            barOH:ClearAllPoints()
            barOH:SetPoint("CENTER", 0, -22)  -- Middle of screen, below main hand
            MySwingTimerDB.pointOH = "BOTTOMLEFT"
            MySwingTimerDB.relativePointOH = "BOTTOMLEFT"
            MySwingTimerDB.xOH = barOH:GetLeft() or 0
            MySwingTimerDB.yOH = barOH:GetBottom() or 0
        end
        if barRanged then
            barRanged:ClearAllPoints()
            barRanged:SetPoint("CENTER", 0, -44)  -- Middle of screen, below offhand
            MySwingTimerDB.pointRanged = "BOTTOMLEFT"
            MySwingTimerDB.relativePointRanged = "BOTTOMLEFT"
            MySwingTimerDB.xRanged = barRanged:GetLeft() or 0
            MySwingTimerDB.yRanged = barRanged:GetBottom() or 0
        end
        if not inCombat then
            if MySwingTimerDB.showOutsideCombat then
                if barMH then
                    barMH:Show()
                    barMH.label:Show()
                end
                if dualWield and barOH then
                    barOH:Show()
                    barOH.label:Show()
                end
                if barRanged then
                    barRanged:Show()
                    barRanged.label:Show()
                end
            else
                if barMH then
                    barMH:Hide()
                    barMH.label:Hide()
                end
                if barOH then
                    barOH:Hide()
                    barOH.label:Hide()
                end
                if barRanged then
                    barRanged:Hide()
                    barRanged.label:Hide()
                end
            end
        end
        local xOH, yOH = (barOH and barOH:GetLeft() or 0), (barOH and barOH:GetBottom() or 0)
        print("[MySwingTimer] Reset saved variables and bar positions, barOH position = CENTER, x: " .. tostring(xOH) .. ", y: " .. tostring(yOH))
    else
        -- Help message
        print("[MySwingTimer] Usage:")
        print("  /myswingtimer show - Toggle showing the timer bar(s) outside of combat")
        print("  /myswingtimer reset - Reset bar positions and saved variables")
    end
end