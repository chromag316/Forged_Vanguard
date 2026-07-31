Forged_Mangosbot = Forged_Mangosbot or {}

local BookOfCommands = {}
Forged_Mangosbot.BookOfCommands = BookOfCommands
Forged_Mangosbot_BookOfCommands_Loaded = true

local MainWindow = Forged_Mangosbot.MainWindow or {}
local CompanionList = Forged_Mangosbot.CompanionList or {}

local function BookOfCommands_Print(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local frame = nil
local frameName = MainWindow.GetFrameName and MainWindow.GetFrameName() or "Forged_Mangosbot_BookOfCommandsFrame"
local tabButtons = {}
local mainTabs = {}
local gridButtons = {}
local currentMainTab = "companions"
local currentCategory = "movement"
local currentPage = 1
local perPage = 12

local mainTabOrder = {
    "companions",
    "commands"
}

local mainTabDefinitions = {
    companions = {
        id = 1,
        buttonText = "Companions",
        titleText = "Companion List"
    },
    commands = {
        id = 2,
        buttonText = "Commands",
        titleText = "Book of Commands"
    }
}

local categories = {
    { key = "movement", label = "Movement", icon = "Ability_Rogue_Sprint" },
    { key = "formation_stance", label = "Formation & Stance", icon = "Ability_Warrior_DefensiveStance" },
    { key = "combat", label = "Combat", icon = "Ability_DualWield" },
    { key = "save_mana", label = "Save Mana", icon = "Spell_Holy_MindVision" },
    { key = "rti", label = "RTI", icon = "INV_Misc_Head_Dragon_01" },
    { key = "rti_cc", label = "RTI-CC", icon = "Spell_Frost_ChainsofIce" },
    { key = "actions", label = "Actions", icon = "INV_Misc_Gear_01" },
    { key = "inventory", label = "Inventory", icon = "INV_Box_02" }
}

local function BookOfCommands_GetMainTabDefinition(tabKey)
    return mainTabDefinitions[tabKey] or mainTabDefinitions.commands
end

local function BookOfCommands_GetCurrentMainTabDefinition()
    return BookOfCommands_GetMainTabDefinition(currentMainTab)
end

local function BookOfCommands_IsCompanionTabActive()
    return currentMainTab == "companions"
end

local function BookOfCommands_IsCategorySelected(categoryKey)
    return currentCategory == categoryKey
end

local function BookOfCommands_SelectCategory(categoryKey)
    currentCategory = categoryKey
    currentPage = 1
    BookOfCommands_Refresh()
end

local function BookOfCommands_ResolveCategoryIcon(category)
    if not category or not category.icon then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local icon = category.icon
    if string.find(icon, "\\") or string.find(icon, "/") then
        return icon
    end

    if string.find(icon, "%.") then
        return icon
    end

    return "Interface\\Icons\\" .. icon
end

local function BookOfCommands_ResolveIcon(def)
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

local function BookOfCommands_GetCategoryIndex(category)
    local i
    for i = 1, table.getn(categories) do
        if categories[i].key == category then
            return i
        end
    end
    return 1
end

local function BookOfCommands_GetCommandsForCurrentCategory()
    local registry = Forged_Mangosbot.Registry
    local all = registry and registry.GetAll and registry.GetAll() or {}
    local list = {}
    local id, def

    for id, def in pairs(all) do
        if currentCategory == "formation_stance" then
            if def.category == "formation" or def.category == "stance" then
                table.insert(list, def)
            end
        elseif currentCategory == "actions" then
            if def.category == "actions" or def.category == "non_combat" then
                table.insert(list, def)
            end
        elseif def.category == currentCategory then
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

local function BookOfCommands_RunVisual(def, button)
    local proxy = {}
    local key, value
    for key, value in pairs(def) do
        proxy[key] = value
    end

    proxy.SetBackdropBorderColor = function()
    end

    if type(ToolBarButtonOnClick) == "function" then
        ToolBarButtonOnClick(proxy, true)
    end
end

local function BookOfCommands_UpdatePageText(total)
    local maxPage = math.max(1, math.ceil(total / perPage))
    if currentPage > maxPage then
        currentPage = maxPage
    end

    local pageTextValue = "Page " .. currentPage .. "/" .. maxPage
    if MainWindow.SetPageText then
        MainWindow.SetPageText(pageTextValue)
    else
        getglobal("Forged_Mangosbot_BookOfCommandsFramePageText"):SetText(pageTextValue)
    end

    local prevEnabled = false
    local nextEnabled = false

    if BookOfCommands_IsCompanionTabActive() then
        prevEnabled = false
        nextEnabled = false
    else
        prevEnabled = currentPage > 1
        nextEnabled = currentPage < maxPage
    end

    if MainWindow.SetPageButtonsEnabled then
        MainWindow.SetPageButtonsEnabled(prevEnabled, nextEnabled)
    else
        local prev = getglobal("Forged_Mangosbot_BookOfCommandsFramePrevPage")
        local next = getglobal("Forged_Mangosbot_BookOfCommandsFrameNextPage")

        if prev then
            if prevEnabled then
                prev:Enable()
            else
                prev:Disable()
            end
        end

        if next then
            if nextEnabled then
                next:Enable()
            else
                next:Disable()
            end
        end
    end
end

local function BookOfCommands_UpdateMainTabs()
    local i
    local currentTab = BookOfCommands_GetCurrentMainTabDefinition()

    for i = 1, table.getn(mainTabs) do
        local tab = mainTabs[i]
        local selected = tab.tabKey == currentMainTab

        if selected then
            tab:LockHighlight()
            if tab.SetButtonState then
                tab:SetButtonState("PUSHED", true)
            end
        else
            tab:UnlockHighlight()
            if tab.SetButtonState then
                tab:SetButtonState("NORMAL")
            end
        end
    end

    if frame and type(PanelTemplates_SetTab) == "function" then
        PanelTemplates_SetTab(frame, currentTab.id)
    end
end

local function BookOfCommands_UpdateWindowTitle()
    local titleTextValue = BookOfCommands_GetCurrentMainTabDefinition().titleText
    if MainWindow.SetTitle then
        MainWindow.SetTitle(titleTextValue)
        return
    end

    local titleText = getglobal("Forged_Mangosbot_BookOfCommandsFrameTitle")
    if not titleText then
        return
    end

    titleText:SetText(titleTextValue)
end

local function BookOfCommands_ApplyCategoryTabState(tab, selected)
    tab:SetChecked(selected)

    if tab.bg then
        if selected then
            tab.bg:SetVertexColor(1, 1, 1, 1)
        else
            tab.bg:SetVertexColor(0.85, 0.85, 0.85, 1)
        end
    end

    if tab.flash then
        if selected then
            tab.flash:Show()
        else
            tab.flash:Hide()
        end
    end
end

local function BookOfCommands_ConfigureCategoryTab(tab, category)
    tab.categoryKey = category.key
    tab.tooltipText = category.label
    tab.icon:SetTexture(BookOfCommands_ResolveCategoryIcon(category))
end

local function BookOfCommands_UpdateTabs()
    local i
    for i = 1, table.getn(tabButtons) do
        local tab = tabButtons[i]
        BookOfCommands_ApplyCategoryTabState(tab, BookOfCommands_IsCategorySelected(tab.categoryKey))
    end
end

local function BookOfCommands_UpdateGrid()
    local commands = BookOfCommands_GetCommandsForCurrentCategory()
    local total = table.getn(commands)
    local startIndex = (currentPage - 1) * perPage + 1
    local i

    for i = 1, table.getn(gridButtons) do
        local idx = startIndex + i - 1
        local button = gridButtons[i]
        local def = commands[idx]

        if def then
            button.def = def
            button.icon:SetTexture(BookOfCommands_ResolveIcon(def))
            button.icon:Show()
            button.nameText:SetText(def.label or def.tooltip or def.id or "")
            button:Enable()
        else
            button.def = nil
            button.icon:SetTexture(nil)
            button.icon:Hide()
            button.nameText:SetText("")
            button:Disable()
        end

        button:Show()
    end

    BookOfCommands_UpdatePageText(total)
end

local function BookOfCommands_ShowCompanionPanel()
    local companionContainer = MainWindow.GetCompanionContainer and MainWindow.GetCompanionContainer() or getglobal("Forged_Mangosbot_BookOfCommandsFrameCompanionContainer")
    local gridContainer = MainWindow.GetGridContainer and MainWindow.GetGridContainer() or getglobal("Forged_Mangosbot_BookOfCommandsFrameGridContainer")
    local tabContainer = MainWindow.GetTabContainer and MainWindow.GetTabContainer() or getglobal("Forged_Mangosbot_BookOfCommandsFrameTabContainer")

    if gridContainer then
        gridContainer:Hide()
    end
    if tabContainer then
        tabContainer:Hide()
    end
    if companionContainer then
        companionContainer:Show()
    end

    if CompanionList and CompanionList.Init then
        CompanionList.Init(companionContainer)
        CompanionList.Refresh()
    end

    BookOfCommands_UpdatePageText(0)
end

local function BookOfCommands_ShowGridPanel()
    local companionContainer = MainWindow.GetCompanionContainer and MainWindow.GetCompanionContainer() or getglobal("Forged_Mangosbot_BookOfCommandsFrameCompanionContainer")
    local gridContainer = MainWindow.GetGridContainer and MainWindow.GetGridContainer() or getglobal("Forged_Mangosbot_BookOfCommandsFrameGridContainer")
    local tabContainer = MainWindow.GetTabContainer and MainWindow.GetTabContainer() or getglobal("Forged_Mangosbot_BookOfCommandsFrameTabContainer")

    if companionContainer then
        companionContainer:Hide()
    end
    if tabContainer then
        tabContainer:Show()
    end
    if gridContainer then
        gridContainer:Show()
    end
    BookOfCommands_UpdateGrid()
end

local function BookOfCommands_Refresh()
    BookOfCommands_UpdateWindowTitle()
    BookOfCommands_UpdateMainTabs()
    BookOfCommands_UpdateTabs()
    if BookOfCommands_IsCompanionTabActive() then
        BookOfCommands_ShowCompanionPanel()
    else
        BookOfCommands_ShowGridPanel()
    end
end

local function BookOfCommands_SetMainTab(tabKey)
    currentMainTab = tabKey
    currentPage = 1
    BookOfCommands_Refresh()
end

local function BookOfCommands_CreateMainTab(parent, tabKey)
    local definition = BookOfCommands_GetMainTabDefinition(tabKey)
    local id = definition.id
    local name = parent:GetName() .. "Tab" .. id
    local tab = CreateFrame("Button", name, parent, "CharacterFrameTabButtonTemplate")
    tab:SetID(id)
    tab:SetText(definition.buttonText)
    tab.tabKey = tabKey

    if id == 1 then
        tab:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 46)
    else
        tab:SetPoint("LEFT", mainTabs[id - 1], "RIGHT", -14, 0)
    end

    if type(PanelTemplates_TabResize) == "function" then
        PanelTemplates_TabResize(0, tab)
    else
        tab:SetWidth(96)
        tab:SetHeight(24)
    end

    tab:SetScript("OnClick", function()
        BookOfCommands_SetMainTab(this.tabKey)
    end)

    return tab
end

local function BookOfCommands_CreateTab(parent, category, index)
    local tab = CreateFrame("CheckButton", nil, parent)
    tab:SetWidth(32)
    tab:SetHeight(32)
    tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * 38))
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    tab.bg:SetWidth(64)
    tab.bg:SetHeight(64)
    tab.bg:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")

    tab.icon = tab:CreateTexture(nil, "BORDER")
    tab.icon:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -6)
    tab.icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 6)

    tab.flash = tab:CreateTexture(nil, "OVERLAY")
    tab.flash:SetTexture("Interface\\Buttons\\CheckButtonGlow")
    tab.flash:SetWidth(64)
    tab.flash:SetHeight(64)
    tab.flash:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.flash:SetBlendMode("ADD")
    tab.flash:Hide()
    BookOfCommands_ConfigureCategoryTab(tab, category)

    tab:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText(this.tooltipText)
        GameTooltip:Show()
    end)

    tab:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    tab:SetScript("OnClick", function()
        BookOfCommands_SelectCategory(this.categoryKey)
    end)

    return tab
end

local function BookOfCommands_CreateGridButton(parent, index)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetWidth(37)
    button:SetHeight(37)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton", "RightButton")

    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")

    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:ClearAllPoints()
        normalTexture:SetPoint("CENTER", button, "CENTER", 0, 0)
        normalTexture:SetWidth(64)
        normalTexture:SetHeight(64)
    end

    local pushedTexture = button:GetPushedTexture()
    if pushedTexture then
        pushedTexture:ClearAllPoints()
        pushedTexture:SetPoint("CENTER", button, "CENTER", 0, 0)
        pushedTexture:SetWidth(64)
        pushedTexture:SetHeight(64)
    end

    local highlightTexture = button:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:ClearAllPoints()
        highlightTexture:SetPoint("CENTER", button, "CENTER", 0, 0)
        highlightTexture:SetWidth(37)
        highlightTexture:SetHeight(37)
    end

    local checkedTexture = button:GetCheckedTexture()
    if checkedTexture then
        checkedTexture:ClearAllPoints()
        checkedTexture:SetPoint("CENTER", button, "CENTER", 0, 0)
        checkedTexture:SetWidth(64)
        checkedTexture:SetHeight(64)
    end

    local rowsPerColumn = math.ceil(perPage / 2)
    local col = math.floor((index - 1) / rowsPerColumn)
    local row = math.mod(index - 1, rowsPerColumn)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 18 + col * 157, -16 - row * 51)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    button.slotBackground = button:CreateTexture(nil, "BACKGROUND")
    button.slotBackground:SetTexture("Interface\\Spellbook\\UI-Spellbook-SpellBackground")
    button.slotBackground:SetWidth(64)
    button.slotBackground:SetHeight(64)
    button.slotBackground:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)

    button.nameText = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    button.nameText:SetWidth(110)
    button.nameText:SetJustifyH("LEFT")
    button.nameText:SetPoint("LEFT", button, "RIGHT", 4, 0)
    button.nameText:SetText("")

    button:SetScript("OnEnter", function()
        if not this.def then
            return
        end

        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.def.tooltip or this.def.id)
        GameTooltip:AddLine("Left-click and drag: place on action bar", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: execute", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function()
        if this.def then
            if arg1 == "RightButton" then
                BookOfCommands_RunVisual(this.def, this)
            end
        end
    end)

    button:SetScript("OnDragStart", function()
        if this.def and Forged_Mangosbot.MacroBridge and Forged_Mangosbot.MacroBridge.PickUp then
            Forged_Mangosbot.MacroBridge.PickUp(this.def.id)
        end
    end)

    return button
end

local function BookOfCommands_SetupPositionPersistence()
    -- Intentionally disabled so the frame behaves like a managed Blizzard panel.
end

local function BookOfCommands_ShowPanel()
    if not frame then
        return
    end

    if MainWindow.Show then
        MainWindow.Show()
        return
    end

    if type(ShowUIPanel) == "function" then
        ShowUIPanel(frame)
        if type(UpdateUIPanelPositions) == "function" then
            UpdateUIPanelPositions()
        end
    else
        frame:Show()
    end
end

local function BookOfCommands_HidePanel()
    if not frame then
        return
    end

    if MainWindow.Hide then
        MainWindow.Hide()
        return
    end

    if type(HideUIPanel) == "function" then
        HideUIPanel(frame)
    else
        frame:Hide()
    end
end

local function BookOfCommands_ApplyLeftPanelPosition()
    if MainWindow.ApplyLeftPanelPosition then
        MainWindow.ApplyLeftPanelPosition()
    end
end

local function BookOfCommands_ApplySpellBookSize()
    if MainWindow.ApplySpellBookSize then
        MainWindow.ApplySpellBookSize()
    end
end

function BookOfCommands.Toggle()
    if not frame then
        BookOfCommands.Init()
    end

    if not frame then
        BookOfCommands_Print("Forged_Mangosbot: Book of Commands frame is missing. Please check for XML load errors on login.")
        return
    end

    if frame:IsVisible() then
        BookOfCommands_HidePanel()
    else
        BookOfCommands_ShowPanel()
        BookOfCommands_Refresh()
    end
end

function BookOfCommands.Init()
    if frame then
        return
    end

    frame = MainWindow.Init and MainWindow.Init() or getglobal(frameName)
    if not frame then
        BookOfCommands_Print("Forged_Mangosbot: missing frame 'Forged_Mangosbot_BookOfCommandsFrame'.")
        return
    end

    if type(UIPanelWindows) == "table" then
        UIPanelWindows[frameName] = {
            area = "left",
            pushable = 0,
            xoffset = 0,
            yoffset = 0,
            whileDead = 1
        }
    end

    if frame.SetMovable then
        frame:SetMovable(false)
    end
    if frame.RegisterForDrag then
        frame:RegisterForDrag()
    end
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end

    BookOfCommands_ApplySpellBookSize()
    BookOfCommands_ApplyLeftPanelPosition()

    local tabContainer = MainWindow.GetTabContainer and MainWindow.GetTabContainer() or getglobal(frameName .. "TabContainer")
    local gridContainer = MainWindow.GetGridContainer and MainWindow.GetGridContainer() or getglobal(frameName .. "GridContainer")
    local companionContainer = MainWindow.GetCompanionContainer and MainWindow.GetCompanionContainer() or getglobal(frameName .. "CompanionContainer")

    if tabContainer then
        tabContainer:ClearAllPoints()
        tabContainer:SetPoint("TOPLEFT", frame, "TOPRIGHT", -32, -65)
        tabContainer:SetWidth(32)
        tabContainer:SetHeight(430)
    end

    if gridContainer then
        gridContainer:ClearAllPoints()
        gridContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -69)
        gridContainer:SetWidth(330)
        gridContainer:SetHeight(310)
    end

    if companionContainer then
        companionContainer:ClearAllPoints()
        companionContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -69)
        companionContainer:SetWidth(330)
        companionContainer:SetHeight(310)
    end

    local mainTabIndex
    for mainTabIndex = 1, table.getn(mainTabOrder) do
        mainTabs[mainTabIndex] = BookOfCommands_CreateMainTab(frame, mainTabOrder[mainTabIndex])
    end

    if type(PanelTemplates_SetNumTabs) == "function" then
        PanelTemplates_SetNumTabs(frame, table.getn(mainTabOrder))
    end
    if type(PanelTemplates_SetTab) == "function" then
        PanelTemplates_SetTab(frame, BookOfCommands_GetCurrentMainTabDefinition().id)
    end

    local i
    for i = 1, table.getn(categories) do
        tabButtons[i] = BookOfCommands_CreateTab(tabContainer, categories[i], i)
    end

    for i = 1, perPage do
        gridButtons[i] = BookOfCommands_CreateGridButton(gridContainer, i)
    end

    getglobal(frameName .. "PrevPage"):SetScript("OnClick", function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            BookOfCommands_Refresh()
        end
    end)

    getglobal(frameName .. "NextPage"):SetScript("OnClick", function()
        currentPage = currentPage + 1
        BookOfCommands_Refresh()
    end)

    frame:SetScript("OnShow", function()
        BookOfCommands_ApplySpellBookSize()
        BookOfCommands_ApplyLeftPanelPosition()
        BookOfCommands_Refresh()
    end)

    BookOfCommands_SetupPositionPersistence()
    BookOfCommands_Refresh()
end

-- Publish stable hooks so the core file can re-bind the module table if needed.
Forged_Mangosbot_BookOfCommands_Init = BookOfCommands.Init
Forged_Mangosbot_BookOfCommands_Toggle = BookOfCommands.Toggle
