Forged_Mangosbot = Forged_Mangosbot or {}

local CompanionList = {}
Forged_Mangosbot.CompanionList = CompanionList

local panelFrame = nil
local listInset = nil
local rows = {}
local emptyText = nil
local elapsedSinceRefresh = 0
local maxVisibleRows = 10
local rosterRefreshRequested = false
local socialTabInstalled = false
local socialSubFrameName = "Forged_Mangosbot_CompanionSocialFrame"
local socialSubFrame = nil
local socialContentFrame = nil
local socialTabId = 0
local socialShowSubFrameHooked = false

local socialBaseSubFrames = {
    "FriendsFrameFriendsScrollFrame",
    "FriendsFrameWhoFrame",
    "FriendsFrameIgnoreFrame",
    "FriendsFrameGuildFrame",
    "FriendsFrameGuildStatusFrame",
    "FriendsFrameRaidFrame"
}

local function CompanionList_RequestRosterRefresh()
    if type(SendBotCommand) == "function" then
        SendBotCommand(".bot list", "SAY")
        return true
    end

    if type(UpdateBotList) == "function" then
        UpdateBotList(1)
        return true
    end

    return false
end

local function CompanionList_GetRosterEntries()
    local entries = {}
    local seen = {}
    local name, bot

    if type(botTable) == "table" then
        for name, bot in pairs(botTable) do
            if name and name ~= "" then
                table.insert(entries, {
                    name = name,
                    class = bot and bot["class"] or nil,
                    online = bot and bot["online"] == true
                })
                seen[name] = true
            end
        end
    end

    if BotRoster and BotRoster.items then
        local i
        for i = 1, table.getn(BotRoster.items) do
            local item = BotRoster.items[i]
            if item and item.text and item.text.GetText then
                name = item.text:GetText()
                if name and name ~= "" and name ~= "Click!" and not seen[name] then
                    local className = nil
                    local online = false

                    if type(botTable) == "table" and botTable[name] then
                        className = botTable[name]["class"]
                        online = botTable[name]["online"] == true
                    end

                    table.insert(entries, {
                        name = name,
                        class = className,
                        online = online
                    })
                    seen[name] = true
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        local aOnline = a.online == true
        local bOnline = b.online == true
        if aOnline ~= bOnline then
            return aOnline
        end
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)

    return entries
end

local function CompanionList_GetClassIcon(className)
    if not className or className == "" then
        return "Interface\\Addons\\Mangosbot\\Images\\role_dps.tga"
    end

    return "Interface\\Addons\\Mangosbot\\Images\\cls_" .. string.lower(className) .. ".tga"
end

local function CompanionList_GetStatusText(entry)
    if not entry then
        return "Offline"
    end

    if entry.online then
        return "Online"
    end

    return "Offline"
end

local function CompanionList_GetDetailText(entry)
    if not entry then
        return "Unknown"
    end

    if entry.class and entry.class ~= "" then
        return entry.class
    end

    return "Unknown"
end

local function CompanionList_SetSelection(name)
    CurrentBot = name
    if type(QuerySelectedBot) == "function" then
        QuerySelectedBot(name)
    end
end

local function CompanionList_CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(34)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -8 - (index - 1) * 34)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -8 - (index - 1) * 34)

    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
    row.selected:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.selected:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.selected:SetVertexColor(1, 0.82, 0, 0.35)
    row.selected:Hide()

    row:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar", "ADD")
    row.highlight = row:GetHighlightTexture()
    if row.highlight then
        row.highlight:SetVertexColor(1, 1, 1, 0.2)
        row.highlight:ClearAllPoints()
        row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(16)
    row.icon:SetHeight(16)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -8)
    row.icon:SetTexture("Interface\\Addons\\Mangosbot\\Images\\role_dps.tga")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 2)
    row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetText("-")

    row.subText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.subText:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -1)
    row.subText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.subText:SetJustifyH("LEFT")
    row.subText:SetText("")

    row:SetScript("OnClick", function()
        if this.companionName and this.companionName ~= "" then
            CompanionList_SetSelection(this.companionName)
            CompanionList.Refresh()
        end
    end)

    return row
end

local function CompanionList_UpdateRowVisual(row)
    if row.companionName and CurrentBot and row.companionName == CurrentBot then
        row.selected:Show()
        row.text:SetTextColor(0.95, 0.95, 0.95, 1)
        row.subText:SetTextColor(0.95, 0.95, 0.95, 1)
    elseif row.isOnline then
        row.selected:Hide()
        row.text:SetTextColor(1, 0.82, 0, 1)
        row.subText:SetTextColor(0.9, 0.9, 0.9, 1)
    else
        row.selected:Hide()
        row.text:SetTextColor(0.72, 0.72, 0.72, 1)
        row.subText:SetTextColor(0.88, 0.88, 0.88, 1)
    end
end

local function CompanionList_UpdateFromRoster()
    local count = 0
    local entries = CompanionList_GetRosterEntries()
    local i

    if table.getn(entries) == 0 then
        for i = 1, table.getn(rows) do
            rows[i]:Hide()
        end
        if emptyText then
            emptyText:SetText("Companion roster unavailable. Mangosbot may still be loading.")
            emptyText:Show()
        end
        return
    end

    for i = 1, math.min(table.getn(entries), table.getn(rows)) do
        local entry = entries[i]
        local row = rows[i]
        if row and entry then
            row.companionName = entry.name
            row.isOnline = entry.online == true
            row.text:SetText(entry.name .. " - " .. CompanionList_GetStatusText(entry))
            row.subText:SetText(CompanionList_GetDetailText(entry))
            row.icon:SetTexture(CompanionList_GetClassIcon(entry.class))
            CompanionList_UpdateRowVisual(row)
            row:Show()
            count = count + 1
        end
    end

    for i = count + 1, table.getn(rows) do
        rows[i]:Hide()
    end

    if emptyText then
        if count == 0 then
            emptyText:SetText("No companions detected yet. Open /bot once so Mangosbot can refresh its roster.")
            emptyText:Show()
        else
            emptyText:Hide()
        end
    end
end

function CompanionList.Refresh()
    if not rosterRefreshRequested then
        rosterRefreshRequested = CompanionList_RequestRosterRefresh()
    end

    CompanionList_UpdateFromRoster()
end

function CompanionList.Init(parent)
    if panelFrame then
        if parent then
            panelFrame:SetParent(parent)
            panelFrame:ClearAllPoints()
            panelFrame:SetAllPoints(parent)
        end
        return panelFrame
    end

    panelFrame = CreateFrame("Frame", "Forged_Mangosbot_CompanionPanel", parent)
    panelFrame:SetAllPoints(parent)

    listInset = CreateFrame("Frame", nil, panelFrame)
    listInset:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", -3, 3)
    listInset:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", -3, -1)
    listInset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    listInset:SetBackdropColor(0, 0, 0, 1)
    listInset:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    emptyText = listInset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyText:SetPoint("TOPLEFT", listInset, "TOPLEFT", 12, -12)
    emptyText:SetPoint("RIGHT", listInset, "RIGHT", -12, 0)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText("No companions detected yet.")

    local i
    for i = 1, maxVisibleRows do
        rows[i] = CompanionList_CreateRow(listInset, i)
        rows[i]:Hide()
    end

    panelFrame:SetScript("OnUpdate", function()
        if not arg1 then
            return
        end

        elapsedSinceRefresh = elapsedSinceRefresh + arg1
        if elapsedSinceRefresh >= 1 then
            elapsedSinceRefresh = 0
            CompanionList_UpdateFromRoster()
            if table.getn(CompanionList_GetRosterEntries()) > 0 then
                rosterRefreshRequested = false
            end
        end
    end)

    CompanionList_UpdateFromRoster()
    return panelFrame
end

local function CompanionList_ShowSocialSubFrame()
    local friendsFrame = getglobal("FriendsFrame")
    if not friendsFrame then
        return
    end

    if type(FriendsFrame_ShowSubFrame) == "function" and type(FRIENDSFRAME_SUBFRAMES) == "table" then
        FriendsFrame_ShowSubFrame(socialSubFrameName)
    else
        local i
        for i = 1, table.getn(socialBaseSubFrames) do
            local subFrame = getglobal(socialBaseSubFrames[i])
            if subFrame then
                subFrame:Hide()
            end
        end
        if socialSubFrame then
            socialSubFrame:Show()
        end
    end

    local titleText = getglobal("FriendsFrameTitleText")
    if titleText and titleText.SetText then
        titleText:SetText("Companion List")
    end

    if socialTabId > 0 and type(PanelTemplates_SetTab) == "function" then
        friendsFrame.selectedTab = socialTabId
        PanelTemplates_SetTab(friendsFrame, socialTabId)
    end
end

local function CompanionList_BuildSocialPanel()
    local friendsFrame = getglobal("FriendsFrame")
    if not friendsFrame or socialSubFrame then
        return
    end

    socialSubFrame = CreateFrame("Frame", socialSubFrameName, friendsFrame)
    socialSubFrame:SetAllPoints(friendsFrame)
    socialSubFrame:Hide()

    socialContentFrame = CreateFrame("Frame", nil, socialSubFrame)
    socialContentFrame:SetPoint("TOPLEFT", socialSubFrame, "TOPLEFT", 18, -74)
    socialContentFrame:SetPoint("BOTTOMRIGHT", socialSubFrame, "BOTTOMRIGHT", -36, 80)

    socialSubFrame:SetScript("OnShow", function()
        CompanionList.Init(socialContentFrame)
        CompanionList.Refresh()
    end)
end

function CompanionList.SetupSocialTab()
    if socialTabInstalled then
        return true
    end

    local friendsFrame = getglobal("FriendsFrame")
    if not friendsFrame then
        return false
    end

    CompanionList_BuildSocialPanel()

    local existingTabs = 0
    while getglobal("FriendsFrameTab" .. (existingTabs + 1)) do
        existingTabs = existingTabs + 1
    end

    socialTabId = existingTabs + 1
    local tabName = "FriendsFrameTab" .. socialTabId
    local tab = CreateFrame("Button", tabName, friendsFrame, "FriendsFrameTabTemplate")

    tab:SetID(socialTabId)
    local friendsTab = getglobal("FriendsFrameTab1")
    if friendsTab then
        tab:SetPoint("LEFT", friendsTab, "RIGHT", -16, 0)

        local i
        for i = 2, existingTabs do
            local shiftedTab = getglobal("FriendsFrameTab" .. i)
            local anchorTab = nil

            if i == 2 then
                anchorTab = tab
            else
                anchorTab = getglobal("FriendsFrameTab" .. (i - 1))
            end

            if shiftedTab and anchorTab then
                shiftedTab:ClearAllPoints()
                shiftedTab:SetPoint("LEFT", anchorTab, "RIGHT", -16, 0)
            end
        end
    else
        local previousTab = getglobal("FriendsFrameTab" .. existingTabs)
        if previousTab then
            tab:SetPoint("LEFT", previousTab, "RIGHT", -16, 0)
        else
            tab:SetPoint("TOPLEFT", friendsFrame, "BOTTOMLEFT", 12, 7)
        end
    end

    local tabText = getglobal(tabName .. "Text")
    if tabText and tabText.SetText then
        tabText:SetText("Companions")
    elseif tab.SetText then
        tab:SetText("Companions")
    end

    if type(PanelTemplates_TabResize) == "function" then
        PanelTemplates_TabResize(0, tab)
    end

    tab:SetScript("OnClick", function()
        CompanionList_ShowSocialSubFrame()
    end)

    if type(PanelTemplates_SetNumTabs) == "function" then
        PanelTemplates_SetNumTabs(friendsFrame, socialTabId)
    end

    if type(FriendsFrame_ShowSubFrame) == "function" and not socialShowSubFrameHooked then
        local originalShowSubFrame = FriendsFrame_ShowSubFrame
        FriendsFrame_ShowSubFrame = function(frameName)
            originalShowSubFrame(frameName)

            if frameName == socialSubFrameName then
                if socialSubFrame then
                    socialSubFrame:Show()
                end

                local titleText = getglobal("FriendsFrameTitleText")
                if titleText and titleText.SetText then
                    titleText:SetText("Companion List")
                end

                local ff = getglobal("FriendsFrame")
                if ff and socialTabId > 0 and type(PanelTemplates_SetTab) == "function" then
                    ff.selectedTab = socialTabId
                    PanelTemplates_SetTab(ff, socialTabId)
                end
            elseif socialSubFrame then
                socialSubFrame:Hide()
            end
        end

        socialShowSubFrameHooked = true
    end

    if type(FRIENDSFRAME_SUBFRAMES) == "table" then
        local found = false
        local i
        for i = 1, table.getn(FRIENDSFRAME_SUBFRAMES) do
            if FRIENDSFRAME_SUBFRAMES[i] == socialSubFrameName then
                found = true
                break
            end
        end
        if not found then
            table.insert(FRIENDSFRAME_SUBFRAMES, socialSubFrameName)
        end
    end

    socialTabInstalled = true
    return true
end

local socialEventFrame = CreateFrame("Frame")
socialEventFrame:RegisterEvent("PLAYER_LOGIN")
socialEventFrame:SetScript("OnEvent", function()
    CompanionList.SetupSocialTab()
end)

Forged_Mangosbot.CompanionPanel = CompanionList