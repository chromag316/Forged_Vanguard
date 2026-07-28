Forged_Mangosbot = Forged_Mangosbot or {}

local CommandBook = {}
Forged_Mangosbot.CommandBook = CommandBook

local function CommandBook_Print(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local frame = nil
local tabButtons = {}
local gridButtons = {}
local currentCategory = "movement"
local currentPage = 1
local perPage = 20

local categories = {
    { key = "movement", label = "Movement" },
    { key = "formation", label = "Formation" },
    { key = "stance", label = "Stance" },
    { key = "combat", label = "Combat" },
    { key = "non_combat", label = "Non-Combat" },
    { key = "save_mana", label = "Save Mana" },
    { key = "rti", label = "RTI" },
    { key = "rti_cc", label = "RTI-CC" },
    { key = "actions", label = "Actions" },
    { key = "inventory", label = "Inventory" },
    { key = "companions", label = "Companions" }
}

local function CommandBook_ResolveIcon(def)
    if not def or not def.icon then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local icon = def.icon
    if string.find(icon, "\\") or string.find(icon, "/") then
        return icon
    end

    if string.find(icon, "%.") then
        return icon
    end

    return "Interface\\Addons\\Mangosbot\\Images\\" .. icon .. ".tga"
end

local function CommandBook_GetCategoryIndex(category)
    local i
    for i = 1, table.getn(categories) do
        if categories[i].key == category then
            return i
        end
    end
    return 1
end

local function CommandBook_GetCommandsForCurrentCategory()
    local registry = Forged_Mangosbot.Registry
    local all = registry and registry.GetAll and registry.GetAll() or {}
    local list = {}
    local id, def

    for id, def in pairs(all) do
        if def.category == currentCategory then
            table.insert(list, def)
        end
    end

    table.sort(list, function(a, b)
        local ai = a.index or 0
        local bi = b.index or 0
        if ai == bi then
            return a.id < b.id
        end
        return ai < bi
    end)

    return list
end

local function CommandBook_RunVisual(def, button)
    local proxy = {}
    local key, value
    for key, value in pairs(def) do
        proxy[key] = value
    end

    proxy.SetBackdropBorderColor = function(_, r, g, b, a)
        button:SetBackdropBorderColor(r, g, b, a or 1.0)
    end

    if type(ToolBarButtonOnClick) == "function" then
        ToolBarButtonOnClick(proxy, true)
    end
end

local function CommandBook_UpdatePageText(total)
    local maxPage = math.max(1, math.ceil(total / perPage))
    if currentPage > maxPage then
        currentPage = maxPage
    end

    getglobal("Forged_Mangosbot_CommandBookFramePageText"):SetText("Page " .. currentPage .. "/" .. maxPage)

    local prev = getglobal("Forged_Mangosbot_CommandBookFramePrevPage")
    local next = getglobal("Forged_Mangosbot_CommandBookFrameNextPage")

    if currentCategory == "companions" then
        prev:Disable()
        next:Disable()
    else
        if currentPage <= 1 then
            prev:Disable()
        else
            prev:Enable()
        end

        if currentPage >= maxPage then
            next:Disable()
        else
            next:Enable()
        end
    end
end

local function CommandBook_UpdateTabs()
    local i
    for i = 1, table.getn(tabButtons) do
        local tab = tabButtons[i]
        if tab.categoryKey == currentCategory then
            tab:LockHighlight()
        else
            tab:UnlockHighlight()
        end
    end
end

local function CommandBook_UpdateGrid()
    local commands = CommandBook_GetCommandsForCurrentCategory()
    local total = table.getn(commands)
    local startIndex = (currentPage - 1) * perPage + 1
    local i

    for i = 1, table.getn(gridButtons) do
        local idx = startIndex + i - 1
        local button = gridButtons[i]
        local def = commands[idx]

        if def then
            button.def = def
            button.icon:SetTexture(CommandBook_ResolveIcon(def))
            button:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)
            button:Show()
        else
            button.def = nil
            button:Hide()
        end
    end

    CommandBook_UpdatePageText(total)
end

local function CommandBook_ShowCompanionPanel()
    local companionContainer = getglobal("Forged_Mangosbot_CommandBookFrameCompanionContainer")
    local gridContainer = getglobal("Forged_Mangosbot_CommandBookFrameGridContainer")

    gridContainer:Hide()
    companionContainer:Show()

    if Forged_Mangosbot.CompanionPanel and Forged_Mangosbot.CompanionPanel.Init then
        Forged_Mangosbot.CompanionPanel.Init(companionContainer)
        Forged_Mangosbot.CompanionPanel.Refresh()
    end

    CommandBook_UpdatePageText(0)
end

local function CommandBook_ShowGridPanel()
    local companionContainer = getglobal("Forged_Mangosbot_CommandBookFrameCompanionContainer")
    local gridContainer = getglobal("Forged_Mangosbot_CommandBookFrameGridContainer")

    companionContainer:Hide()
    gridContainer:Show()
    CommandBook_UpdateGrid()
end

local function CommandBook_Refresh()
    CommandBook_UpdateTabs()
    if currentCategory == "companions" then
        CommandBook_ShowCompanionPanel()
    else
        CommandBook_ShowGridPanel()
    end
end

local function CommandBook_CreateTab(parent, category, index)
    local tab = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    tab:SetWidth(92)
    tab:SetHeight(20)

    local row = math.floor((index - 1) / 5)
    local col = math.mod(index - 1, 5)

    tab:SetPoint("TOPLEFT", parent, "TOPLEFT", col * 100 + 4, -row * 24 - 4)
    tab:SetText(category.label)
    tab.categoryKey = category.key

    tab:SetScript("OnClick", function()
        currentCategory = this.categoryKey
        currentPage = 1
        CommandBook_Refresh()
    end)

    return tab
end

local function CommandBook_CreateGridButton(parent, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(44)
    button:SetHeight(44)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    button:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    button:SetBackdropColor(0, 0, 0, 0.5)
    button:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)

    local col = math.mod(index - 1, 5)
    local row = math.floor((index - 1) / 5)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 24 + col * 94, -22 - row * 70)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    button:SetScript("OnEnter", function()
        if not this.def then
            return
        end

        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.def.tooltip or this.def.id)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function()
        if this.def then
            CommandBook_RunVisual(this.def, this)
        end
    end)

    button:SetScript("OnDragStart", function()
        if this.def and Forged_Mangosbot.MacroBridge and Forged_Mangosbot.MacroBridge.PickUp then
            Forged_Mangosbot.MacroBridge.PickUp(this.def.id)
        end
    end)

    return button
end

local function CommandBook_SetupPositionPersistence()
    if type(EnablePositionSaving) == "function" then
        EnablePositionSaving(frame, "Forged_Mangosbot_CommandBookFrame")
    else
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function()
            this:StartMoving()
        end)
        frame:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
        end)
    end
end

function CommandBook.Toggle()
    if not frame then
        CommandBook.Init()
    end

    if not frame then
        CommandBook_Print("Forged_Mangosbot: command book frame is missing. Please check for XML load errors on login.")
        return
    end

    if frame:IsVisible() then
        frame:Hide()
    else
        frame:Show()
        CommandBook_Refresh()
    end
end

function CommandBook.Init()
    if frame then
        return
    end

    frame = getglobal("Forged_Mangosbot_CommandBookFrame")
    if not frame then
        CommandBook_Print("Forged_Mangosbot: missing frame 'Forged_Mangosbot_CommandBookFrame'.")
        return
    end

    local tabContainer = getglobal("Forged_Mangosbot_CommandBookFrameTabContainer")
    local gridContainer = getglobal("Forged_Mangosbot_CommandBookFrameGridContainer")

    local i
    for i = 1, table.getn(categories) do
        tabButtons[i] = CommandBook_CreateTab(tabContainer, categories[i], i)
    end

    for i = 1, perPage do
        gridButtons[i] = CommandBook_CreateGridButton(gridContainer, i)
    end

    getglobal("Forged_Mangosbot_CommandBookFramePrevPage"):SetScript("OnClick", function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            CommandBook_Refresh()
        end
    end)

    getglobal("Forged_Mangosbot_CommandBookFrameNextPage"):SetScript("OnClick", function()
        currentPage = currentPage + 1
        CommandBook_Refresh()
    end)

    frame:SetScript("OnShow", function()
        CommandBook_Refresh()
    end)

    CommandBook_SetupPositionPersistence()
    CommandBook_Refresh()
end
