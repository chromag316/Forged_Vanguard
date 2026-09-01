Forged_Mangosbot = Forged_Mangosbot or {}

local CompanionList = {}
Forged_Mangosbot.CompanionList = CompanionList

local panelFrame = nil
local listInset = nil
local rows = {}
local emptyText = nil
local companionLevelCache = {}
local bulkActionButton = nil
local bulkInviteButton = nil
local bulkSummonButton = nil
local elapsedSinceRefresh = 0
local maxVisibleRows = 10
local rosterRefreshRequested = false
local socialTabInstalled = false
local socialSubFrameName = "Forged_Mangosbot_CompanionSocialFrame"
local socialSubFrame = nil
local socialContentFrame = nil
local socialTabId = 0
local socialShowSubFrameHooked = false
local socialShouldRestoreOnShow = false
local CompanionList_NormalizeClassAndLevel = nil
local CompanionList_GetObservedCompanionLevel = nil
local CompanionList_UpdateRowVisual = nil
local CompanionList_UpdateAllRowVisuals = nil

local socialBaseSubFrames = {
    "FriendsListFrame",
    "IgnoreListFrame",
    "WhoFrame",
    "GuildFrame",
    "RaidFrame"
}

local function CompanionList_BuildAllBotsList(entries)
    local names = {}
    local i

    for i = 1, table.getn(entries) do
        if entries[i] and entries[i].name and entries[i].name ~= "" then
            table.insert(names, entries[i].name)
        end
    end

    return table.concat(names, ",")
end

local function CompanionList_SplitNames(csv)
    local names = {}
    local name = nil
    local iterator = string.gmatch or string.gfind

    if not csv or csv == "" or type(iterator) ~= "function" then
        return names
    end

    for name in iterator(csv, "([^,]+)") do
        table.insert(names, name)
    end

    return names
end

local function CompanionList_HasOfflineEntries(entries)
    local i

    for i = 1, table.getn(entries) do
        if entries[i] and entries[i].online ~= true then
            return true
        end
    end

    return false
end

local function CompanionList_HasCompanionsOutsideParty(entries)
    local i
    local name

    for i = 1, table.getn(entries) do
        if entries[i] and entries[i].online == true and entries[i].name and entries[i].name ~= "" then
            name = entries[i].name
            if type(partyName) ~= "function" then
                return true
            end
            if partyName(1) ~= name and partyName(2) ~= name and partyName(3) ~= name and partyName(4) ~= name and partyName(5) ~= name then
                return true
            end
        end
    end

    return false
end

local function CompanionList_HasCompanionsInParty(entries)
    local i
    local name

    if type(partyName) ~= "function" then
        return false
    end

    for i = 1, table.getn(entries) do
        if entries[i] and entries[i].online == true and entries[i].name and entries[i].name ~= "" then
            name = entries[i].name
            if partyName(1) == name or partyName(2) == name or partyName(3) == name or partyName(4) == name or partyName(5) == name then
                return true
            end
        end
    end

    return false
end

local function CompanionList_HasCompanionsOnline(entries)
    local i

    for i = 1, table.getn(entries) do
        if entries[i] and entries[i].online == true then
            return true
        end
    end

    return false
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

local function CompanionList_GetNameText(entry)
    if not entry or not entry.name then
        return "-"
    end

    if entry.online then
        return entry.name
    end

    return entry.name .. " - Offline"
end

local function CompanionList_UpdateBulkActionButton(entries)
    if not bulkActionButton then
        return
    end

    if table.getn(entries) == 0 then
        bulkActionButton:SetText("Login All")
        bulkActionButton.allBots = nil
        bulkActionButton.action = nil
        bulkActionButton:Disable()
        bulkActionButton:Show()
        return
    end

    bulkActionButton.allBots = CompanionList_BuildAllBotsList(entries)
    if not bulkActionButton.allBots or bulkActionButton.allBots == "" then
        bulkActionButton:SetText("Login All")
        bulkActionButton.action = nil
        bulkActionButton:Disable()
        bulkActionButton:Show()
        return
    end

    if CompanionList_HasCompanionsOnline(entries) then
        bulkActionButton.action = "logout"
        bulkActionButton:SetText("Logout All")
    else
        bulkActionButton.action = "login"
        bulkActionButton:SetText("Login All")
    end

    bulkActionButton:Enable()
    bulkActionButton:Show()
end

local function CompanionList_UpdateBulkGroupButtons(entries)
    local hasOutsideParty = false
    local hasInParty = false
    local hasOnline = false

    if not bulkInviteButton or not bulkSummonButton then
        return
    end

    bulkInviteButton:SetText("Invite All")
    bulkSummonButton:SetText("Summon All")

    if table.getn(entries) == 0 then
        bulkInviteButton.names = nil
        bulkSummonButton.names = nil
        bulkInviteButton:Disable()
        bulkSummonButton:Disable()
        bulkInviteButton:Show()
        bulkSummonButton:Show()
        return
    end

    bulkInviteButton.names = CompanionList_BuildAllBotsList(entries)
    bulkSummonButton.names = bulkInviteButton.names
    if not bulkInviteButton.names or bulkInviteButton.names == "" then
        bulkInviteButton:Disable()
        bulkSummonButton:Disable()
        bulkInviteButton:Show()
        bulkSummonButton:Show()
        return
    end

    hasOutsideParty = CompanionList_HasCompanionsOutsideParty(entries)
    hasInParty = CompanionList_HasCompanionsInParty(entries)
    hasOnline = CompanionList_HasCompanionsOnline(entries)

    bulkInviteButton:ClearAllPoints()
    bulkSummonButton:ClearAllPoints()
    bulkInviteButton:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", -3, 1)
    bulkSummonButton:SetPoint("BOTTOMLEFT", bulkActionButton, "TOPLEFT", 0, 5)

    if hasOnline then
        bulkSummonButton.allBots = bulkInviteButton.names
        bulkSummonButton:Enable()
        bulkSummonButton:Show()
    else
        bulkSummonButton:Hide()
    end

    if not hasOnline then
        bulkInviteButton:Disable()
        bulkInviteButton.action = "invite"
        bulkInviteButton:SetText("Invite All")
        bulkInviteButton:Show()
        bulkSummonButton:Disable()
        bulkSummonButton:Show()
        return
    end

    if hasInParty then
        bulkInviteButton:ClearAllPoints()
        bulkInviteButton:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", -3, 1)
        bulkInviteButton.action = "uninvite"
        bulkInviteButton:SetText("Uninvite All")
        bulkInviteButton:Enable()
        bulkInviteButton:Show()
    elseif hasOutsideParty then
        bulkInviteButton:ClearAllPoints()
        bulkInviteButton:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", -3, 1)
        bulkInviteButton.action = "invite"
        bulkInviteButton:SetText("Invite All")
        bulkInviteButton:Enable()
        bulkInviteButton:Show()
    else
        bulkInviteButton:Hide()
    end
end

local function CompanionList_RunBulkAction(button)
    if not button or not button.allBots or button.allBots == "" or type(SendBotCommand) ~= "function" then
        return
    end

    if button.action == "logout" then
        SendBotCommand(".bot rm " .. button.allBots, "SAY")
        return
    end

    SendBotCommand(".bot add " .. button.allBots, "SAY")
end

local function CompanionList_RunBulkGroupAction(button)
    local names = nil
    local timeout = 0.1
    local i

    if not button or not button.names or button.names == "" then
        return
    end

    names = CompanionList_SplitNames(button.names)

    if button.action == "uninvite" then
        if type(SendBotCommand) ~= "function" then
            return
        end

        for i = 1, table.getn(names) do
            wait(timeout, function(uninviteName)
                SendBotCommand("leave", "WHISPER", nil, uninviteName)
            end, names[i])
            timeout = timeout + 0.1
        end
        return
    end

    if type(InviteByName) ~= "function" then
        return
    end

    for i = 1, table.getn(names) do
        wait(timeout, function(inviteName)
            InviteByName(inviteName)
        end, names[i])
        timeout = timeout + 0.1
    end

    if type(UpdateBotList) == "function" then
        UpdateBotList(1)
    end
end

local function CompanionList_RunBulkSummonAction(button)
    local names = nil
    local timeout = 0.1
    local i

    if not button or not button.names or button.names == "" or type(SendBotCommand) ~= "function" then
        return
    end

    names = CompanionList_SplitNames(button.names)

    for i = 1, table.getn(names) do
        wait(timeout, function(summonName)
            SendBotCommand("summon", "WHISPER", nil, summonName)
        end, names[i])
        timeout = timeout + 0.1
    end
end

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
    local className = nil
    local level = nil
    local levelField = nil
    local observedLevel = nil

    if type(botTable) == "table" then
        for name, bot in pairs(botTable) do
            if name and name ~= "" then
                className = bot and bot["class"] or nil
                levelField = bot and (bot["level"] or bot["lvl"]) or nil
                className, level = CompanionList_NormalizeClassAndLevel(className, levelField)

                observedLevel = nil
                if bot and bot["online"] == true then
                    observedLevel = CompanionList_GetObservedCompanionLevel(name)
                    if observedLevel then
                        companionLevelCache[name] = observedLevel
                    end
                end

                if not level and observedLevel then
                    level = observedLevel
                end
                if not level and companionLevelCache[name] then
                    level = companionLevelCache[name]
                end

                table.insert(entries, {
                    name = name,
                    class = className,
                    level = level,
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
                    local level = nil
                    local online = false
                    local observedLevel = nil

                    if type(botTable) == "table" and botTable[name] then
                        className = botTable[name]["class"]
                        className, level = CompanionList_NormalizeClassAndLevel(className, botTable[name]["level"] or botTable[name]["lvl"])
                        online = botTable[name]["online"] == true
                    end

                    if online then
                        observedLevel = CompanionList_GetObservedCompanionLevel(name)
                        if observedLevel then
                            companionLevelCache[name] = observedLevel
                        end
                    end

                    if not level and observedLevel then
                        level = observedLevel
                    end
                    if not level and companionLevelCache[name] then
                        level = companionLevelCache[name]
                    end

                    table.insert(entries, {
                        name = name,
                        class = className,
                        level = level,
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

CompanionList_GetObservedCompanionLevel = function(name)
    local i
    local unitName = nil
    local level = nil
    local unitId = nil

    if not name or name == "" or type(UnitLevel) ~= "function" then
        return nil
    end

    if type(partyName) == "function" then
        for i = 1, 5 do
            if partyName(i) == name then
                unitId = "party" .. i
                level = UnitLevel(unitId)
                if level and level > 0 then
                    return level
                end
            end
        end
    end

    if type(UnitName) == "function" and type(UnitExists) == "function" and UnitExists("target") then
        unitName = UnitName("target")
        if unitName == name then
            level = UnitLevel("target")
            if level and level > 0 then
                return level
            end
        end
    end

    return nil
end

CompanionList_NormalizeClassAndLevel = function(rawClass, rawLevel)
    local className = rawClass
    local level = rawLevel
    local levelText = nil
    local parsedClass = nil
    local _start = nil
    local _end = nil

    if type(level) == "string" then
        level = tonumber(level)
    end

    if (not level) and type(className) == "string" and className ~= "" then
        _start, _end, levelText, parsedClass = string.find(className, "^(%d+)%s+(.+)$")
        if levelText and parsedClass then
            level = tonumber(levelText)
            className = parsedClass
        end
    end

    if (not level) and type(className) == "string" and className ~= "" then
        _start, _end, parsedClass, levelText = string.find(className, "^(.+)%s+(%d+)$")
        if parsedClass and levelText then
            level = tonumber(levelText)
            className = parsedClass
        end
    end

    return className, level
end

local function CompanionList_GetDetailText(entry)
    if not entry then
        return "Unknown"
    end

    if entry.level and entry.class and entry.class ~= "" then
        return "Level " .. entry.level .. " " .. entry.class
    end

    if entry.level then
        return "Level " .. entry.level
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

local function CompanionList_GetRosterActionTexture(isOnline)
    if isOnline then
        return "Interface\\Addons\\Mangosbot\\Images\\logout.tga"
    end

    return "Interface\\Addons\\Mangosbot\\Images\\login.tga"
end

local function CompanionList_IsCompanionInParty(name)
    local i

    if not name or name == "" or type(partyName) ~= "function" then
        return false
    end

    for i = 1, 5 do
        if partyName(i) == name then
            return true
        end
    end

    return false
end

local function CompanionList_GetRosterActionTooltip(isOnline)
    if isOnline then
        return "Logout"
    end

    return "Login"
end

local function CompanionList_RunRosterAction(name, isOnline)
    if not name or name == "" or type(SendBotCommand) ~= "function" then
        return
    end

    if isOnline then
        SendBotCommand(".bot rm " .. name, "SAY")
        return
    end

    SendBotCommand(".bot add " .. name, "SAY")
end

local function CompanionList_GetGroupActionTexture(isInParty)
    if isInParty then
        return "Interface\\Addons\\Mangosbot\\Images\\leave.tga"
    end

    return "Interface\\Addons\\Mangosbot\\Images\\invite.tga"
end

local function CompanionList_GetGroupActionTooltip(isInParty)
    if isInParty then
        return "Uninvite"
    end

    return "Invite"
end

local function CompanionList_RunGroupAction(name, isInParty)
    if not name or name == "" then
        return
    end

    if isInParty then
        if type(SendBotCommand) == "function" then
            SendBotCommand("leave", "WHISPER", nil, name)
        end
        return
    end

    if type(InviteByName) == "function" then
        InviteByName(name)
    end
end

local function CompanionList_GetSummonActionTexture()
    return "Interface\\Addons\\Mangosbot\\Images\\summon.tga"
end

local function CompanionList_GetSummonActionTooltip()
    return "Summon"
end

local function CompanionList_RunSummonAction(name)
    if not name or name == "" or type(SendBotCommand) ~= "function" then
        return
    end

    SendBotCommand("summon", "WHISPER", nil, name)
end

local function CompanionList_CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(298)
    row:SetHeight(31)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -2 - (index - 1) * 31)

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.highlight = row:GetHighlightTexture()
    if row.highlight then
        row.highlight:ClearAllPoints()
        row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    end
    row:UnlockHighlight()

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -3)
    row.text:SetPoint("RIGHT", row, "RIGHT", -82, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetText("-")

    row.subText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.subText:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, 0)
    row.subText:SetPoint("RIGHT", row, "RIGHT", -82, 0)
    row.subText:SetJustifyH("LEFT")
    row.subText:SetText("")

    row.summonButton = CreateFrame("Button", nil, row)
    row.summonButton:SetWidth(20)
    row.summonButton:SetHeight(20)
    row.summonButton:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.summonButton:EnableMouse(true)
    row.summonButton:RegisterForClicks("LeftButtonDown")

    row.summonButton.texture = row.summonButton:CreateTexture(nil, "ARTWORK")
    row.summonButton.texture:SetPoint("TOPLEFT", row.summonButton, "TOPLEFT", 2, -2)
    row.summonButton.texture:SetWidth(16)
    row.summonButton.texture:SetHeight(16)
    row.summonButton.texture:SetTexture(CompanionList_GetSummonActionTexture())

    row.summonButton:SetScript("OnEnter", function()
        if not this.ownerRow then
            return
        end

        this.ownerRow:LockHighlight()

        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(CompanionList_GetSummonActionTooltip())
        GameTooltip:Show()
    end)
    row.summonButton:SetScript("OnLeave", function()
        if this.ownerRow then
            CompanionList_UpdateRowVisual(this.ownerRow)
        end

        GameTooltip:Hide()
    end)
    row.summonButton:SetScript("OnClick", function()
        if not this.ownerRow or not this.ownerRow.companionName then
            return
        end

        CompanionList_SetSelection(this.ownerRow.companionName)
        CompanionList_UpdateAllRowVisuals()
        CompanionList_RunSummonAction(this.ownerRow.companionName)
    end)
    row.summonButton.ownerRow = row

    row.groupButton = CreateFrame("Button", nil, row)
    row.groupButton:SetWidth(20)
    row.groupButton:SetHeight(20)
    row.groupButton:SetPoint("RIGHT", row, "RIGHT", -30, 0)
    row.groupButton:EnableMouse(true)
    row.groupButton:RegisterForClicks("LeftButtonDown")

    row.groupButton.texture = row.groupButton:CreateTexture(nil, "ARTWORK")
    row.groupButton.texture:SetPoint("TOPLEFT", row.groupButton, "TOPLEFT", 2, -2)
    row.groupButton.texture:SetWidth(16)
    row.groupButton.texture:SetHeight(16)
    row.groupButton.texture:SetTexture("Interface\\Addons\\Mangosbot\\Images\\invite.tga")

    row.groupButton:SetScript("OnEnter", function()
        if not this.ownerRow then
            return
        end

        this.ownerRow:LockHighlight()

        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(CompanionList_GetGroupActionTooltip(this.ownerRow.isInParty == true))
        GameTooltip:Show()
    end)
    row.groupButton:SetScript("OnLeave", function()
        if this.ownerRow then
            CompanionList_UpdateRowVisual(this.ownerRow)
        end

        GameTooltip:Hide()
    end)
    row.groupButton:SetScript("OnClick", function()
        if not this.ownerRow or not this.ownerRow.companionName then
            return
        end

        CompanionList_SetSelection(this.ownerRow.companionName)
        CompanionList_UpdateAllRowVisuals()
        CompanionList_RunGroupAction(this.ownerRow.companionName, this.ownerRow.isInParty == true)
    end)
    row.groupButton.ownerRow = row

    row.actionButton = CreateFrame("Button", nil, row)
    row.actionButton:SetWidth(20)
    row.actionButton:SetHeight(20)
    row.actionButton:SetPoint("RIGHT", row, "RIGHT", -52, 0)
    row.actionButton:EnableMouse(true)
    row.actionButton:RegisterForClicks("LeftButtonDown")

    row.actionButton.texture = row.actionButton:CreateTexture(nil, "ARTWORK")
    row.actionButton.texture:SetPoint("TOPLEFT", row.actionButton, "TOPLEFT", 2, -2)
    row.actionButton.texture:SetWidth(16)
    row.actionButton.texture:SetHeight(16)
    row.actionButton.texture:SetTexture("Interface\\Addons\\Mangosbot\\Images\\login.tga")

    row.actionButton:SetScript("OnEnter", function()
        if not this.ownerRow then
            return
        end

        this.ownerRow:LockHighlight()

        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(CompanionList_GetRosterActionTooltip(this.ownerRow.isOnline == true))
        GameTooltip:Show()
    end)
    row.actionButton:SetScript("OnLeave", function()
        if this.ownerRow then
            CompanionList_UpdateRowVisual(this.ownerRow)
        end

        GameTooltip:Hide()
    end)
    row.actionButton:SetScript("OnClick", function()
        if not this.ownerRow or not this.ownerRow.companionName then
            return
        end

        CompanionList_SetSelection(this.ownerRow.companionName)
        CompanionList_UpdateAllRowVisuals()
        CompanionList_RunRosterAction(this.ownerRow.companionName, this.ownerRow.isOnline == true)
    end)
    row.actionButton.ownerRow = row

    row:SetScript("OnClick", function()
        if this.companionName and this.companionName ~= "" then
            CompanionList_SetSelection(this.companionName)
            CompanionList.Refresh()
        end
    end)

    return row
end

CompanionList_UpdateRowVisual = function(row)
    if row.companionName and CurrentBot and row.companionName == CurrentBot then
        row:LockHighlight()
        row.text:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
        row.subText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    else
        row:UnlockHighlight()
        if row.isOnline then
            row.text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
            row.subText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
        else
            row.text:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
            row.subText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
        end
    end
end

CompanionList_UpdateAllRowVisuals = function()
    local i

    for i = 1, table.getn(rows) do
        if rows[i] then
            CompanionList_UpdateRowVisual(rows[i])
        end
    end
end

local function CompanionList_UpdateFromRoster()
    local count = 0
    local entries = CompanionList_GetRosterEntries()
    local i

    CompanionList_UpdateBulkActionButton(entries)
    CompanionList_UpdateBulkGroupButtons(entries)

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
            row.isInParty = row.isOnline and CompanionList_IsCompanionInParty(entry.name)
            row.text:SetText(CompanionList_GetNameText(entry))
            row.subText:SetText(CompanionList_GetDetailText(entry))
            if row.summonButton and row.summonButton.texture then
                row.summonButton.texture:SetTexture(CompanionList_GetSummonActionTexture())
                if row.isOnline then
                    row.summonButton:Show()
                else
                    row.summonButton:Hide()
                end
            end
            if row.groupButton and row.groupButton.texture then
                if row.isOnline then
                    row.groupButton.texture:SetTexture(CompanionList_GetGroupActionTexture(row.isInParty))
                    row.groupButton:Show()
                else
                    row.groupButton:Hide()
                end
            end
            if row.actionButton and row.actionButton.texture then
                row.actionButton.texture:SetTexture(CompanionList_GetRosterActionTexture(row.isOnline))
                row.actionButton:Show()
            end
            CompanionList_UpdateRowVisual(row)
            row:Show()
            count = count + 1
        end
    end

    for i = count + 1, table.getn(rows) do
        if rows[i].summonButton then
            rows[i].summonButton:Hide()
        end
        if rows[i].groupButton then
            rows[i].groupButton:Hide()
        end
        if rows[i].actionButton then
            rows[i].actionButton:Hide()
        end
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

    bulkActionButton = CreateFrame("Button", "Forged_Mangosbot_CompanionBulkActionButton", panelFrame, "UIPanelButtonTemplate")
    bulkActionButton:SetWidth(131)
    bulkActionButton:SetHeight(21)
    bulkActionButton:SetPoint("BOTTOMLEFT", panelFrame, "BOTTOMLEFT", -1, 1)
    bulkActionButton:SetText("Login All")
    bulkActionButton:Disable()
    bulkActionButton:Show()
    bulkActionButton:SetScript("OnClick", function()
        CompanionList_RunBulkAction(this)
    end)

    bulkInviteButton = CreateFrame("Button", "Forged_Mangosbot_CompanionBulkInviteButton", panelFrame, "UIPanelButtonTemplate")
    bulkInviteButton:SetWidth(131)
    bulkInviteButton:SetHeight(21)
    bulkInviteButton:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", -3, 1)
    bulkInviteButton:SetText("Invite All")
    bulkInviteButton:Disable()
    bulkInviteButton:Show()
    bulkInviteButton:SetScript("OnClick", function()
        CompanionList_RunBulkGroupAction(this)
    end)

    bulkSummonButton = CreateFrame("Button", "Forged_Mangosbot_CompanionBulkSummonButton", panelFrame, "UIPanelButtonTemplate")
    bulkSummonButton:SetWidth(131)
    bulkSummonButton:SetHeight(21)
    bulkSummonButton:SetPoint("BOTTOMLEFT", bulkActionButton, "TOPLEFT", 0, 5)
    bulkSummonButton:SetText("Summon All")
    bulkSummonButton:Disable()
    bulkSummonButton:Show()
    bulkSummonButton:SetScript("OnClick", function()
        CompanionList_RunBulkSummonAction(this)
    end)

    listInset = CreateFrame("Frame", nil, panelFrame)
    listInset:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 0, 0)
    listInset:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", 0, 0)
    -- listInset:SetBackdrop({
    --     bgFile = "Interface\\Buttons\\WHITE8X8",
    --     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    --     edgeSize = 16,
    --     insets = { left = 4, right = 4, top = 4, bottom = 4 }
    -- })
    -- listInset:SetBackdropColor(0, 0, 0, 1)
    -- listInset:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    emptyText = listInset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyText:SetPoint("TOPLEFT", listInset, "TOPLEFT", 15, -5)
    emptyText:SetPoint("RIGHT", listInset, "RIGHT", -10, 0)
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

-- Apply the Friends panel's corner/background textures to the Friends frame.
-- The native FriendsFrame_Update swaps these four textures on every tab switch,
-- so when we activate our own Companions tab we must set them explicitly to the
-- friends theme or they keep whatever the previous tab left behind. The same
-- four texture globals (and paths) the Friends tab (selectedTab == 1) uses.
local function CompanionList_SetFriendsTheme()
    local pairsToSet = {
        { "FriendsFrameTopLeft", "Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft" },
        { "FriendsFrameTopRight", "Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight" },
        { "FriendsFrameBottomLeft", "Interface\\FriendsFrame\\UI-FriendsFrame-BotLeft" },
        { "FriendsFrameBottomRight", "Interface\\FriendsFrame\\UI-FriendsFrame-BotRight" }
    }
    local i

    for i = 1, table.getn(pairsToSet) do
        local name = pairsToSet[i][1]
        local path = pairsToSet[i][2]
        local tex = getglobal(name)
        if tex and tex.SetTexture then
            tex:SetTexture(path)
        end
    end
end

local function CompanionList_ShowSocialSubFrame()
    local friendsFrame = getglobal("FriendsFrame")
    if not friendsFrame then
        return
    end

    -- Give our panel the Friends tab's background so it does not inherit
    -- the corner art from whichever tab was active before.
    CompanionList_SetFriendsTheme()

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

    CompanionList.Init(socialContentFrame)
    CompanionList.Refresh()
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
            if frameName == socialSubFrameName then
                socialShouldRestoreOnShow = true
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

                local titleText = getglobal("FriendsFrameTitleText")
                if titleText and titleText.SetText then
                    titleText:SetText("Companion List")
                end

                local ff = getglobal("FriendsFrame")
                if ff and socialTabId > 0 and type(PanelTemplates_SetTab) == "function" then
                    ff.selectedTab = socialTabId
                    PanelTemplates_SetTab(ff, socialTabId)
                end
            else
                originalShowSubFrame(frameName)

                if socialSubFrame then
                    socialSubFrame:Hide()
                end

                socialShouldRestoreOnShow = false
            end
        end

        socialShowSubFrameHooked = true
    end

    if not friendsFrame._forgedCompanionOnShowHooked then
        local originalFriendsOnShow = friendsFrame:GetScript("OnShow")
        friendsFrame:SetScript("OnShow", function()
            if originalFriendsOnShow then
                originalFriendsOnShow()
            end

            if socialTabId > 0 and socialShouldRestoreOnShow then
                socialShouldRestoreOnShow = false
                CompanionList_ShowSocialSubFrame()
            end
        end)
        friendsFrame._forgedCompanionOnShowHooked = true
    end

    if not friendsFrame._forgedCompanionOnHideHooked then
        local originalFriendsOnHide = friendsFrame:GetScript("OnHide")
        friendsFrame:SetScript("OnHide", function()
            if socialTabId > 0 then
                socialShouldRestoreOnShow = (friendsFrame.selectedTab == socialTabId)
            else
                socialShouldRestoreOnShow = false
            end

            if originalFriendsOnHide then
                originalFriendsOnHide()
            end
        end)
        friendsFrame._forgedCompanionOnHideHooked = true
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