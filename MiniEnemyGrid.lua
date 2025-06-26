local addonName = ...
local framePool = {}
local activeEnemies = {}
local savedVars = MiniEnemyGridDB or {}

local container = CreateFrame("Frame", "MiniEnemyGridContainer", UIParent, "BackdropTemplate")
container:SetSize(300, 200)
container:SetPoint(savedVars.point or "CENTER", UIParent, savedVars.relativePoint or "CENTER", savedVars.xOfs or 0, savedVars.yOfs or 0)
container:SetMovable(true)
container:EnableMouse(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", container.StartMoving)
container:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    MiniEnemyGridDB = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
end)
container:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background" })

local function CreateEnemyFrame(index)
    local f = CreateFrame("Button", "MiniEnemyGridFrame"..index, container, "SecureUnitButtonTemplate,BackdropTemplate")
    f:SetSize(140, 30)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12
    })
    f:SetPoint("TOPLEFT", container, "TOPLEFT", (index - 1) % 2 * 150, -math.floor((index - 1) / 2) * 35)

    f:SetAttribute("unit", nil)
    f:SetAttribute("type1", "target")               -- Left click targets the unit
    f:SetAttribute("type2", "spell")                -- Right click casts a spell
    f:SetAttribute("spell2", "Shadow Bolt")         -- Change spell as needed
    f:SetAttribute("shift-type2", "spell")          -- Shift + right click
    f:SetAttribute("shift-spell2", "Fear")          -- Change spell as needed

    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.name:SetPoint("LEFT", f, "LEFT", 5, 0)

    f.health = CreateFrame("StatusBar", nil, f)
    f.health:SetSize(100, 10)
    f.health:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 5, 5)
    f.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(1)
    f.health:SetStatusBarColor(0.8, 0.1, 0.1)

    f.healthText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.healthText:SetPoint("RIGHT", f.health, "RIGHT", -2, 0)

    f:Hide()
    return f
end

local function UpdateEnemyFrames()
    for i, f in ipairs(framePool) do
        f:Hide()
    end

    local i = 1
    for unitID in pairs(activeEnemies) do
        local f = framePool[i]
        if not f then
            f = CreateEnemyFrame(i)
            framePool[i] = f
        end

        f.unit = unitID
        f:SetAttribute("unit", unitID)

        local name = UnitName(unitID) or "???"
        local hp, max = UnitHealth(unitID), UnitHealthMax(unitID)
        local percent = max > 0 and hp / max or 0

        f.name:SetText(name)
        f.health:SetValue(percent)
        f.healthText:SetText(string.format("%d%%", percent * 100))

        local inRange = UnitInRange(unitID)
        f:SetAlpha(inRange and 1 or 0.4)

        local threat = UnitThreatSituation("player", unitID)
        if threat == 3 then
            f:SetBackdropBorderColor(1, 0, 0)
        else
            f:SetBackdropBorderColor(0.5, 0.5, 0.5)
        end

        f:Show()
        i = i + 1
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        MiniEnemyGridDB = MiniEnemyGridDB or {}
        container:ClearAllPoints()
        container:SetPoint(
            MiniEnemyGridDB.point or "CENTER",
            UIParent,
            MiniEnemyGridDB.relativePoint or "CENTER",
            MiniEnemyGridDB.xOfs or 0,
            MiniEnemyGridDB.yOfs or 0
        )
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        if UnitCanAttack("player", unit) and not UnitIsPlayer(unit) then
            activeEnemies[unit] = true
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        activeEnemies[unit] = nil
    elseif event == "UNIT_HEALTH" and activeEnemies[unit] then
        for _, f in ipairs(framePool) do
            if f.unit == unit then
                local hp, max = UnitHealth(unit), UnitHealthMax(unit)
                local percent = max > 0 and hp / max or 0
                f.health:SetValue(percent)
                f.healthText:SetText(string.format("%d%%", percent * 100))
                break
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(1, function()
            for unit in pairs(activeEnemies) do
                if not UnitExists(unit) then
                    activeEnemies[unit] = nil
                end
            end
            UpdateEnemyFrames()
        end)
        return
    end

    UpdateEnemyFrames()
end)
