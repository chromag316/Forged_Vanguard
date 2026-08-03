Forged_Mangosbot = Forged_Mangosbot or {}

local CompanionList = {}
Forged_Mangosbot.CompanionList = CompanionList

local panelFrame = nil
local rows = {}
local emptyText = nil
local elapsedSinceRefresh = 0
local maxVisibleRows = 10
local rosterRefreshRequested = false

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
    row:SetHeight(36)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16 - (index - 1) * 36)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -16 - (index - 1) * 36)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(18)
    row.icon:SetHeight(18)
    row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.icon:SetTexture("Interface\\Addons\\Mangosbot\\Images\\role_dps.tga")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetText("-")

    row.subText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.subText:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
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
        row.text:SetTextColor(1, 0.82, 0, 1)
        row.subText:SetTextColor(1, 1, 1, 1)
    else
        row.text:SetTextColor(0.82, 0.82, 0.82, 1)
        row.subText:SetTextColor(1, 1, 1, 1)
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
        return panelFrame
    end

    panelFrame = CreateFrame("Frame", "Forged_Mangosbot_CompanionPanel", parent)
    panelFrame:SetAllPoints(parent)

    emptyText = panelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyText:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 16, -16)
    emptyText:SetPoint("RIGHT", panelFrame, "RIGHT", -16, 0)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText("No companions detected yet.")

    local i
    for i = 1, maxVisibleRows do
        rows[i] = CompanionList_CreateRow(panelFrame, i)
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

Forged_Mangosbot.CompanionPanel = CompanionList