local addonName, addon = ...

-- Initialization SavedVariables
XPBoostDB = XPBoostDB or {
    lastPlayerMessage = "",
    currentStep = 1,
    isTransparent = false,
    minimapPos = 45
}

-- Exclusive quests group (Fortify the Runestones)
local RUNESTONE_QUESTS = { 90574, 90573, 90576, 90575 }

---------------------------------------------------------
-- DATA ENGINE & CONSTANTS
---------------------------------------------------------
local StepEngine = {
    Tag = "delver's call",
    XPTable = {
        [80] = 403725, [81] = 423390, [82] = 443395, [83] = 463740, [84] = 484430,
        [85] = 505455, [86] = 526825, [87] = 548535, [88] = 570590, [89] = 592980,
    },
    Spells = { Winds = 1214848, Surge = 1221184, DMF = 46668, WmA = 269083, WmB = 282559 },
    Mentors = { 42332, 42331, 42330, 42329, 42328 },
    MentorBonusMap = { [42332] = 25, [42331] = 20, [42330] = 15, [42329] = 10, [42328] = 5 },

    ZoneQuests = {
        [93372] = "Eversong Woods / Silvermoon City",
        [93384] = "Eversong Woods / Silvermoon City",
        [93385] = "Eversong Woods / Silvermoon City",
        [93386] = "Eversong Woods / Silvermoon City",
        [89507] = "Eversong Woods / Silvermoon City",
        [93416] = "Harandar", [93421] = "Harandar", [92720] = "Harandar",
        [93409] = "Zul'Aman", [93410] = "Zul'Aman",
        [93428] = "Voidstorm", [93427] = "Voidstorm",
    }
}

function StepEngine:HasAura(spellID)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        return ok and aura ~= nil
    end
    return false
end

function StepEngine:GetMentorPercent()
    for _, achID in ipairs(self.Mentors) do
        local _, _, _, completed = GetAchievementInfo(achID)
        if completed then return self.MentorBonusMap[achID] end
    end
    return 0
end

function StepEngine:IsDarkmoonActive()
    local d = date("*t")
    local firstSun = ((8 - d.wday) % 7) + 1
    return d.day >= firstSun and d.day <= (firstSun + 6)
end

function StepEngine:IsQuestReady(qID)
    return C_QuestLog.IsComplete(qID) or (C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(qID)) or false
end

function StepEngine:ScanQuests()
    local total, avail, ready, done = 0, 0, 0, 0
    local handledRunestones = false

    local checkQuest = function(qID)
        total = total + 1
        if C_QuestLog.IsQuestFlaggedCompleted(qID) then
            done = done + 1
        elseif C_QuestLog.IsOnQuest(qID) and self:IsQuestReady(qID) then
            ready = ready + 1
        else
            avail = avail + 1
        end
    end

    for qID in pairs(self.ZoneQuests) do
        checkQuest(qID)
    end

    total = total + 1
    for _, rID in ipairs(RUNESTONE_QUESTS) do
        if C_QuestLog.IsQuestFlaggedCompleted(rID) then
            done = done + 1; handledRunestones = true; break
        elseif C_QuestLog.IsOnQuest(rID) and self:IsQuestReady(rID) then
            ready = ready + 1; handledRunestones = true; break
        end
    end
    if not handledRunestones then avail = avail + 1 end

    return avail, ready, done, total
end

function StepEngine:CalculatePendingXP()
    local pendingXP = 0
    local count = C_QuestLog.GetNumQuestLogEntries()

    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden then
            local isTagged = info.title and info.title:lower():find(self.Tag, 1, true) ~= nil
            local isTracked = self.ZoneQuests[info.questID] ~= nil
            
            if not isTracked then
                for _, rID in ipairs(RUNESTONE_QUESTS) do
                    if info.questID == rID then isTracked = true; break end
                end
            end

            if (isTagged or isTracked) and self:IsQuestReady(info.questID) then
                pendingXP = pendingXP + (GetQuestLogRewardXP(info.questID) or 0)
            end
        end
    end
    return pendingXP
end

---------------------------------------------------------
-- ROUTE STEPS CONFIGURATION
---------------------------------------------------------
local ROUTE_STEPS = {
    {
        title = "Step 1",
        text = "Set Hearthstone to the inn.",
        icon = "Interface\\Icons\\inv_misc_rune_01",
        waypoint = { mapID = 2393, x = 0.564, y = 0.706 }
    },
    {
        title = "Step 2",
        quests = {
            { id = 93384, mapID = 2393, x = 0.4037, y = 0.5326 },
            { id = 93385, mapID = 2393, x = 0.3936, y = 0.3179 }
        }
    },
    {
        title = "Step 3",
        quests = {
            { id = 93386, mapID = 2424, x = 0.4786, y = 0.4168 }
        }
    },
    {
        title = "Step 4",
        text = "Use Hearthstone to Silvermoon City.",
        icon = "Interface\\Icons\\inv_misc_rune_01"
    },
    {
        title = "Step 5",
        text = "Fly to Eversong Woods.",
        quests = {
            { customName = "Fortify the Runestones", mapID = 2395, x = 0.4240, y = 0.4660, ids = RUNESTONE_QUESTS }
        }
    },
    {
        title = "Step 6",
        quests = {
            { id = 93372, mapID = 2395, x = 0.4550, y = 0.8619 }
        }
    },
    {
        title = "Step 7",
        text = "Flight to Zul'Aman:",
        quests = {
            { id = 93409, mapID = 2395, x = 0.6379, y = 0.8012 },
            { id = 93410, mapID = 2437, x = 0.2540, y = 0.8445 }
        }
    },
    {
        title = "Step 8",
        text = "Use toy Personal Key to the Arcantina\nand teleport to Harandar.",
        icon = 7322718,
        waypoint = { mapID = 2393, x = 0.3693, y = 0.6802 }
    },
    {
        title = "Step 9",
        quests = {
            { id = 92720, mapID = 2413, x = 0.5420, y = 0.5300 }
        }
    },
    {
        title = "Step 10",
        text = "Harandar:",
        quests = {
            { id = 93416, mapID = 2413, x = 0.3671, y = 0.4953 },
            { id = 93421, mapID = 2413, x = 0.7096, y = 0.6556 }
        }
    },
    {
        title = "Step 11",
        text = "Use the portal to Voidstorm.",
        waypoint = { mapID = 2576, x = 0.6176, y = 0.7340 }
    },
    {
        title = "Step 12",
        quests = {
            { id = 93428, mapID = 2405, x = 0.3735, y = 0.4792 },
            { id = 93427, mapID = 2405, x = 0.5480, y = 0.4717 }
        }
    },
    {
        title = "Step 13",
        text = "Use toy Dundun's Abundant Travel Method.",
        icon = "Interface\\Icons\\achievement_dungeon_ulduar80_25man",
        quests = { { id = 89507 } }
    },
    {
        title = "Step 14",
        text = "Enable War Mode and turn in all quests!"
    }
}

---------------------------------------------------------
-- UI INTERFACE BUILDER
---------------------------------------------------------
local UI = {}

function UI:Construct()
    local frame = CreateFrame("Frame", "XPBoostMainFrame", UIParent)
    frame:SetSize(340, 280)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    if frame.SetResizeBounds then
        frame:SetResizeBounds(240, 180, 700, 600)
    else
        frame:SetMinResize(240, 180)
        frame:SetMaxResize(700, 600)
    end
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.09, 0.12, 0.95)

    local stroke = frame:CreateTexture(nil, "BORDER")
    stroke:SetPoint("TOPLEFT", -1, 1)
    stroke:SetPoint("BOTTOMRIGHT", 1, -1)
    stroke:SetColorTexture(0.2, 0.22, 0.28, 1)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    local opacBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    opacBtn:SetSize(20, 20)
    opacBtn:SetPoint("RIGHT", closeBtn, "LEFT", 0, 0)
    opacBtn:SetText("T")
    opacBtn:SetScript("OnClick", function()
        XPBoostDB.isTransparent = not XPBoostDB.isTransparent
        UI:ApplyTheme()
    end)

    local top = CreateFrame("Frame", nil, frame)
    top:SetPoint("TOPLEFT", 10, -6)
    top:SetPoint("RIGHT", -10, 0)
    top:SetHeight(65)

    local curLvl = top:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    curLvl:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE")
    curLvl:SetPoint("TOPLEFT", top, "TOPLEFT", 0, -2)

    local nextLvl = top:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nextLvl:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    nextLvl:SetPoint("BOTTOMLEFT", curLvl, "TOPRIGHT", 4, -6)
    nextLvl:SetTextColor(0, 1, 0.4)

    local qCount = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qCount:SetPoint("TOPLEFT", curLvl, "BOTTOMLEFT", 0, -2)

    local xpText = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xpText:SetPoint("TOPLEFT", qCount, "BOTTOMLEFT", 0, -2)
    xpText:SetTextColor(0.4, 0.7, 1)

    local line1 = frame:CreateTexture(nil, "ARTWORK")
    line1:SetHeight(2)
    line1:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -2)
    line1:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, -2)
    line1:SetColorTexture(0.3, 0.35, 0.45, 0.8)

    -- Middle panel (Buffs)
    local mid = CreateFrame("Frame", nil, frame)
    mid:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -2)
    mid:SetPoint("TOPRIGHT", line1, "BOTTOMRIGHT", 0, -2)
    mid:SetHeight(55)

    local buffFrames = {}
    for i = 1, 5 do
        local f = CreateFrame("Frame", nil, mid)
        f:SetSize(45, 48)

        local ico = f:CreateTexture(nil, "ARTWORK")
        ico:SetSize(28, 28)
        ico:SetPoint("TOP", f, "TOP", 0, 0)
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local txt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
        txt:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        txt:SetPoint("BOTTOM", ico, "BOTTOM", 0, 1)

        local st = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        st:SetFont("Fonts\\FRIZQT__.TTF", 8)
        st:SetPoint("TOP", ico, "BOTTOM", 0, -1)

        f.icon, f.txt, f.status = ico, txt, st
        buffFrames[i] = f
    end

    local line2 = frame:CreateTexture(nil, "ARTWORK")
    line2:SetHeight(2)
    line2:SetPoint("TOPLEFT", mid, "BOTTOMLEFT", 0, -2)
    line2:SetPoint("TOPRIGHT", mid, "BOTTOMRIGHT", 0, -2)
    line2:SetColorTexture(0.3, 0.35, 0.45, 0.8)

    local bot = CreateFrame("Frame", nil, frame)
    bot:SetPoint("TOPLEFT", line2, "BOTTOMLEFT", 0, -2)
    bot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

    local botInfo = bot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    botInfo:SetPoint("TOPLEFT", bot, "TOPLEFT", 0, -2)

    local stepTitle = bot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stepTitle:SetPoint("TOPLEFT", botInfo, "BOTTOMLEFT", 0, -3)

    local stepBox = CreateFrame("Frame", nil, bot)
    stepBox:SetPoint("TOPLEFT", stepTitle, "BOTTOMLEFT", 0, -2)
    stepBox:SetPoint("RIGHT", bot, "RIGHT", 0, 0)
    stepBox:SetHeight(120)

    local stepIcon = stepBox:CreateTexture(nil, "ARTWORK")
    stepIcon:SetSize(16, 16)

    local nextBtn = CreateFrame("Button", nil, bot, "UIPanelButtonTemplate")
    nextBtn:SetSize(100, 20)
    nextBtn:SetPoint("BOTTOMRIGHT", bot, "BOTTOMRIGHT", 0, 14)
    nextBtn:SetText("Next step")

    local msgText = bot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    msgText:SetFont("Fonts\\FRIZQT__.TTF", 8)
    msgText:SetPoint("BOTTOMLEFT", bot, "BOTTOMLEFT", 0, 0)
    msgText:SetPoint("RIGHT", bot, "RIGHT", -16, 0)
    msgText:SetJustifyH("LEFT")

    local resizer = CreateFrame("Button", nil, frame)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end end)
    resizer:SetScript("OnMouseUp", function(_, b) if b == "LeftButton" then frame:StopMovingOrSizing() end end)

    self.Main = frame
    self.BG = bg
    self.Stroke = stroke
    self.CurLvl = curLvl
    self.NextLvl = nextLvl
    self.QCount = qCount
    self.XPText = xpText
    self.Buffs = buffFrames
    self.BotInfo = botInfo
    self.StepTitle = stepTitle
    self.StepBox = stepBox
    self.StepIcon = stepIcon
    self.NextBtn = nextBtn
    self.MsgText = msgText
    self.MidPanel = mid
    self.WayButtons = {}
    self.MapButtons = {}
    self.Lines = {}

    nextBtn:SetScript("OnClick", function()
        if (XPBoostDB.currentStep or 1) < #ROUTE_STEPS then
            XPBoostDB.currentStep = (XPBoostDB.currentStep or 1) + 1
            UI:Update()
        end
    end)

    frame:SetScript("OnSizeChanged", function(_, w, h) UI:Scale(w, h) end)
end

function UI:Toggle()
    if self.Main:IsShown() then
        self.Main:Hide()
    else
        self.Main:Show()
        self:Update()
    end
end

function UI:ApplyTheme()
    if XPBoostDB.isTransparent then
        self.BG:SetColorTexture(0.08, 0.09, 0.12, 0.15)
        self.Stroke:SetColorTexture(0.2, 0.22, 0.28, 0.3)
    else
        self.BG:SetColorTexture(0.08, 0.09, 0.12, 0.95)
        self.Stroke:SetColorTexture(0.2, 0.22, 0.28, 1.0)
    end
end

function UI:GetWaypointBtn(index)
    if not self.WayButtons[index] then
        local btn = CreateFrame("Button", nil, self.StepBox, "UIPanelButtonTemplate")
        btn:SetSize(35, 16)
        btn:SetText("Pin")
        self.WayButtons[index] = btn
    end
    return self.WayButtons[index]
end

function UI:GetMapBtn(index)
    if not self.MapButtons[index] then
        local btn = CreateFrame("Button", nil, self.StepBox, "UIPanelButtonTemplate")
        btn:SetSize(35, 16)
        btn:SetText("Map")
        self.MapButtons[index] = btn
    end
    return self.MapButtons[index]
end

function UI:GetLineFS(index)
    if not self.Lines[index] then
        local fs = self.StepBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        self.Lines[index] = fs
    end
    return self.Lines[index]
end

function UI:SetFontHeight(fs, base, scale)
    local path, _, flags = fs:GetFont()
    fs:SetFont(path, math.max(6, math.floor(base * scale + 0.5)), flags)
end

function UI:Scale(w, h)
    local s = math.min(w / 340, h / 280)
    self:SetFontHeight(self.CurLvl, 26, s)
    self:SetFontHeight(self.NextLvl, 14, s)
    self:SetFontHeight(self.QCount, 10, s)
    self:SetFontHeight(self.XPText, 10, s)
    self:SetFontHeight(self.BotInfo, 10, s)
    self:SetFontHeight(self.StepTitle, 11, s)
    self:SetFontHeight(self.MsgText, 8, s)

    local iconS = math.floor(28 * s)
    local spacing = self.MidPanel:GetWidth() / 5
    for i = 1, 5 do
        self.Buffs[i].icon:SetSize(iconS, iconS)
        self:SetFontHeight(self.Buffs[i].txt, 10, s)
        self:SetFontHeight(self.Buffs[i].status, 8, s)
        self.Buffs[i]:SetPoint("CENTER", self.MidPanel, "LEFT", spacing * (i - 0.5), 0)
    end

    self.StepIcon:SetSize(math.floor(16 * s), math.floor(16 * s))
    for _, btn in ipairs(self.WayButtons) do btn:SetSize(math.floor(35 * s), math.floor(16 * s)) end
    for _, btn in ipairs(self.MapButtons) do btn:SetSize(math.floor(38 * s), math.floor(16 * s)) end
    self.NextBtn:SetSize(math.floor(100 * s), math.floor(20 * s))
end

function UI:Update()
    if not self.Main:IsShown() then return end
    self:ApplyTheme()

    local lvl = UnitLevel("player")
    self.CurLvl:SetText(lvl)

    local pendingXP = StepEngine:CalculatePendingXP()
    local cap = StepEngine.XPTable[lvl] or 592980
    local estLvl = lvl + math.floor((UnitXP("player") + pendingXP) / cap)
    self.NextLvl:SetText("-> " .. estLvl .. " lvl")

    local avail, ready, done, total = StepEngine:ScanQuests()
    self.QCount:SetText(string.format("Quests: %d (Available:%d | Ready:%d | Completed:%d)", total, avail, ready, done))
    self.XPText:SetText(string.format("Ready XP: +%s", BreakUpLargeNumbers(pendingXP)))

    local currentZone = C_Map.GetBestMapForUnit("player")
    local inSilvermoon = (currentZone == 2393)

    local b1 = StepEngine:HasAura(StepEngine.Spells.Winds)
    if b1 then
        self.Buffs[1]:Show()
        self.Buffs[1].icon:SetTexture(6439633)
        self.Buffs[1].txt:SetText("+20%")
        self.Buffs[1].status:SetText("|cff00ff00ACTIVE|r")
    else
        self.Buffs[1]:Hide()
    end

    local b2 = StepEngine:HasAura(StepEngine.Spells.Surge)
    self.Buffs[2].icon:SetTexture("Interface\\Icons\\inv_potion_20")
    self.Buffs[2].txt:SetText("+10%")
    if b2 then
        self.Buffs[2].status:SetText("|cff00ff00ACTIVE|r")
    else
        local hasItem = (C_Item and C_Item.GetItemCount) and (C_Item.GetItemCount(239142, true) > 0) or (GetItemCount(239142, true) > 0)
        self.Buffs[2].status:SetText(hasItem and "|cffffd100HAS ITEM|r" or "|cffff0000NO|r")
    end

    local wmA = StepEngine:HasAura(StepEngine.Spells.WmA)
    local wmB = StepEngine:HasAura(StepEngine.Spells.WmB)
    if inSilvermoon then
        self.Buffs[3].icon:SetTexture("Interface\\Icons\\achievement_legionpvptier4")
        self.Buffs[3].txt:SetText("+10%")
        self.Buffs[3].status:SetText("|cffff0000NO\n(city)|r")
    else
        local activeWM = wmA or wmB
        self.Buffs[3].icon:SetTexture(wmB and "Interface\\Icons\\achievement_legionpvptier3" or "Interface\\Icons\\achievement_legionpvptier4")
        self.Buffs[3].txt:SetText("+10%")
        self.Buffs[3].status:SetText(activeWM and "|cff00ff00ACTIVE|r" or "|cffff0000NO|r")
    end

    local mPct = StepEngine:GetMentorPercent()
    self.Buffs[4].icon:SetTexture("Interface\\Icons\\achievement_explore_argus")
    self.Buffs[4].txt:SetText(mPct > 0 and ("+" .. mPct .. "%") or "")
    self.Buffs[4].status:SetText(mPct > 0 and "|cff00ff00ACTIVE|r" or "|cffff0000NO|r")

    local dmfActive = StepEngine:IsDarkmoonActive()
    local b5 = StepEngine:HasAura(StepEngine.Spells.DMF)
    self.Buffs[5].icon:SetTexture(237554)
    self.Buffs[5].txt:SetText("+10%")
    self.Buffs[5].status:SetText(dmfActive and (b5 and "|cff00ff00ACTIVE|r" or "|cffff0000NO|r") or "|cff808080Closed|r")

    local sub = GetSubZoneText()
    local zone = GetZoneText()
    local loc = (zone ~= "" and zone or "Unknown") .. (sub ~= "" and " (" .. sub .. ")" or "")
    self.BotInfo:SetText(string.format("Character: |cffffd100%d lvl|r | Location: |cffffd100%s|r", lvl, loc))

    for _, btn in ipairs(self.WayButtons) do btn:Hide() end
    for _, btn in ipairs(self.MapButtons) do btn:Hide() end
    for _, line in ipairs(self.Lines) do line:Hide() end
    self.StepIcon:Hide()

    local stepIdx = XPBoostDB.currentStep or 1
    local sData = ROUTE_STEPS[stepIdx]

    if sData then
        self.StepTitle:SetText(sData.title)
        local lineIdx, btnIdx = 1, 1
        local lastFrame = nil

        if sData.text then
            local line = self:GetLineFS(lineIdx)
            line:SetText(sData.text)
            line:ClearAllPoints()

            if sData.icon then
                self.StepIcon:SetTexture(sData.icon)
                self.StepIcon:ClearAllPoints()
                self.StepIcon:SetPoint("TOPLEFT", self.StepBox, "TOPLEFT", 0, 0)
                self.StepIcon:Show()
                line:SetPoint("LEFT", self.StepIcon, "RIGHT", 4, 0)
            else
                line:SetPoint("TOPLEFT", self.StepBox, "TOPLEFT", 0, 0)
            end
            line:Show()
            lastFrame = line
            lineIdx = lineIdx + 1

            if sData.waypoint then
                local wBtn = self:GetWaypointBtn(btnIdx)
                wBtn:ClearAllPoints()
                wBtn:SetPoint("LEFT", line, "RIGHT", 6, 0)
                wBtn:SetScript("OnClick", function()
                    if C_Map and C_Map.SetUserWaypoint then
                        local pt = UiMapPoint.CreateFromCoordinates(sData.waypoint.mapID, sData.waypoint.x, sData.waypoint.y)
                        C_Map.SetUserWaypoint(pt)
                        print(string.format("|cff00ff00[XP Boost]|r Waypoint set: /way #%d %.2f %.2f", sData.waypoint.mapID, sData.waypoint.x * 100, sData.waypoint.y * 100))
                    end
                end)
                wBtn:Show()

                local mBtn = self:GetMapBtn(btnIdx)
                mBtn:ClearAllPoints()
                mBtn:SetPoint("LEFT", wBtn, "RIGHT", 4, 0)
                mBtn:SetScript("OnClick", function()
                    if WorldMapFrame then
                        if not WorldMapFrame:IsShown() then
                            ShowUIPanel(WorldMapFrame)
                        end
                        WorldMapFrame:SetMapID(sData.waypoint.mapID)
                    end
                end)
                mBtn:Show()

                btnIdx = btnIdx + 1
            end
        end

        if sData.quests then
            for _, q in ipairs(sData.quests) do
                local qName = q.customName or C_QuestLog.GetTitleForQuestID(q.id)
                if not qName or qName == "" then qName = "Quest #" .. (q.id or 0) end

                local line = self:GetLineFS(lineIdx)
                line:SetText(string.format("Accept quest «|cffffd100%s|r»", qName))
                line:ClearAllPoints()

                if lastFrame then
                    line:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -4)
                else
                    line:SetPoint("TOPLEFT", self.StepBox, "TOPLEFT", 0, 0)
                end
                line:Show()

                if q.mapID and q.x and q.y then
                    local wBtn = self:GetWaypointBtn(btnIdx)
                    wBtn:ClearAllPoints()
                    wBtn:SetPoint("LEFT", line, "RIGHT", 6, 0)
                    wBtn:SetScript("OnClick", function()
                        if C_Map and C_Map.SetUserWaypoint then
                            local pt = UiMapPoint.CreateFromCoordinates(q.mapID, q.x, q.y)
                            C_Map.SetUserWaypoint(pt)
                            print(string.format("|cff00ff00[XP Boost]|r Waypoint set (%s): /way #%d %.2f %.2f", qName, q.mapID, q.x * 100, q.y * 100))
                        end
                    end)
                    wBtn:Show()

                    local mBtn = self:GetMapBtn(btnIdx)
                    mBtn:ClearAllPoints()
                    mBtn:SetPoint("LEFT", wBtn, "RIGHT", 4, 0)
                    mBtn:SetScript("OnClick", function()
                        if WorldMapFrame then
                            if not WorldMapFrame:IsShown() then
                                ShowUIPanel(WorldMapFrame)
                            end
                            WorldMapFrame:SetMapID(q.mapID)
                        end
                    end)
                    mBtn:Show()

                    btnIdx = btnIdx + 1
                end

                lastFrame = line
                lineIdx = lineIdx + 1
            end
        end
    end

    self.MsgText:SetText("XP Boost Tracker v1.7.4")
    self:Scale(self.Main:GetWidth(), self.Main:GetHeight())
end

---------------------------------------------------------
-- NATIVE MINIMAP BUTTON (NO LIBRARIES)
---------------------------------------------------------
local function CreateNativeMinimapButton()
    local btn = CreateFrame("Button", "XPBoostMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\XP_Icon")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local function UpdatePosition()
        local angle = math.rad(XPBoostDB.minimapPos or 45)
        local radius = 103
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale

            local deg = math.deg(math.atan2(cy - my, cx - mx))
            XPBoostDB.minimapPos = deg
            UpdatePosition()
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            UI:Toggle()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("XP Boost Tracker", 1, 1, 1)
        GameTooltip:AddLine("Left-Click to toggle window", 0.2, 0.8, 1)
        GameTooltip:AddLine("Drag to move icon", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition()
end

---------------------------------------------------------
-- ADVANCEMENT & EVENTS HANDLER
---------------------------------------------------------
local function CheckAutoAdvance()
    local sIdx = XPBoostDB.currentStep or 1
    local currentMap = C_Map.GetBestMapForUnit("player")

    if sIdx == 4 and currentMap == 2393 then
        XPBoostDB.currentStep = 5
        UI:Update()
        return
    elseif sIdx == 8 and currentMap == 2576 then
        XPBoostDB.currentStep = 9
        UI:Update()
        return
    elseif sIdx == 11 and currentMap == 2405 then
        XPBoostDB.currentStep = 12
        UI:Update()
        return
    end

    local sData = ROUTE_STEPS[sIdx]
    if sData and sData.quests then
        local allDone = true
        for _, q in ipairs(sData.quests) do
            if q.ids then
                local groupReady = false
                for _, subID in ipairs(q.ids) do
                    if StepEngine:IsQuestReady(subID) then groupReady = true; break end
                end
                if not groupReady then allDone = false; break end
            elseif q.id and not StepEngine:IsQuestReady(q.id) then
                allDone = false; break
            end
        end
        if allDone and sIdx < #ROUTE_STEPS then
            XPBoostDB.currentStep = sIdx + 1
            UI:Update()
        end
    end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("ADDON_LOADED")
listener:RegisterEvent("PLAYER_LEVEL_UP")
listener:RegisterEvent("QUEST_LOG_UPDATE")
listener:RegisterEvent("QUEST_DATA_LOAD_RESULT")
listener:RegisterEvent("UNIT_AURA")
listener:RegisterEvent("BAG_UPDATE")
listener:RegisterEvent("ZONE_CHANGED_NEW_AREA")

listener:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        UI:Construct()
        CreateNativeMinimapButton()
    else
        CheckAutoAdvance()
        UI:Update()
    end
end)

SLASH_XPBOOST1 = "/xpboost"
SlashCmdList["XPBOOST"] = function()
    UI:Toggle()
end