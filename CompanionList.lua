Forged_Mangosbot = Forged_Mangosbot or {}

local CompanionList = {}
Forged_Mangosbot.CompanionList = CompanionList

local panelFrame = nil
local rows = {}
local emptyText = nil
local elapsedSinceRefresh = 0

local function CompanionList_SetSelection(name)
    CurrentBot = name
    if type(QuerySelectedBot) == "function" then
        QuerySelectedBot(name)
    end
end

local function CompanionList_CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(468)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -14 - (index - 1) * 26)
    row:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    row:SetBackdropColor(0, 0, 0, 0.2)
    row:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(18)
    row.icon:SetHeight(18)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetTexture("Interface\\Addons\\Mangosbot\\Images\\role_dps.tga")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.text:SetWidth(360)
    row.text:SetJustifyH("LEFT")
    row.text:SetText("-")

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
        row:SetBackdropBorderColor(0.1, 0.8, 0.3, 1.0)
    else
        row:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)
    end
end

local function CompanionList_UpdateFromRoster()
    local count = 0
    local i

    if not BotRoster or not BotRoster.items then
        for i = 1, table.getn(rows) do
            rows[i]:Hide()
        end
        if emptyText then
            emptyText:SetText("Companion roster unavailable. Mangosbot may still be loading.")
            emptyText:Show()
        end
        return
    end

    for i = 1, 10 do
        local item = BotRoster.items[i]
        if item and item.text and item.text.GetText then
            local name = item.text:GetText()
            if name and name ~= "" and name ~= "Click!" then
                count = count + 1
                local row = rows[count]
                if row then
                    row.companionName = name
                    row.text:SetText(name)
                    if item.cls and item.cls.texture and item.cls.texture.GetTexture then
                        local clsTexture = item.cls.texture:GetTexture()
                        if clsTexture then
                            row.icon:SetTexture(clsTexture)
                        else
                            row.icon:SetTexture("Interface\\Addons\\Mangosbot\\Images\\role_dps.tga")
                        end
                    end
                    CompanionList_UpdateRowVisual(row)
                    row:Show()
                end
            end
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
    CompanionList_UpdateFromRoster()
end

function CompanionList.Init(parent)
    if panelFrame then
        return panelFrame
    end

    panelFrame = CreateFrame("Frame", "Forged_Mangosbot_CompanionPanel", parent)
    panelFrame:SetAllPoints(parent)

    local title = panelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 16, -14)
    title:SetText("Companions")

    emptyText = panelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyText:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 16, -40)
    emptyText:SetWidth(468)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText("No companions detected yet.")

    local i
    for i = 1, 10 do
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
        end
    end)

    CompanionList_UpdateFromRoster()
    return panelFrame
end

Forged_Mangosbot.CompanionPanel = CompanionList