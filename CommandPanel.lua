Forged_Mangosbot = Forged_Mangosbot or {}

local CommandPanel = {}
Forged_Mangosbot.CommandPanel = CommandPanel
Forged_Mangosbot_CommandPanel_Loaded = true

local MainWindow = Forged_Mangosbot.MainWindow or {}

local function CommandPanel_Print(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local frame = nil
local frameName = MainWindow.GetFrameName and MainWindow.GetFrameName() or "Forged_Mangosbot_CommandPanelFrame"
local tabButtons = {}
local gridButtons = {}
local CommandPanel_Refresh
local currentCategory = "movement"
local currentPage = 1
local perPage = 12

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

local function CommandPanel_IsCategorySelected(categoryKey)
    return currentCategory == categoryKey
end

local function CommandPanel_SelectCategory(categoryKey)
    currentCategory = categoryKey
    currentPage = 1
    CommandPanel_Refresh()
end

local function CommandPanel_ResolveCategoryIcon(category)
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

local function CommandPanel_ResolveIcon(def)
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

local function CommandPanel_GetCategoryIndex(category)
    local i
    for i = 1, table.getn(categories) do
        if categories[i].key == category then
            return i
        end
    end
    return 1
end

local function CommandPanel_GetCommandsForCurrentCategory()
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

local function CommandPanel_RunVisual(def, button)
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

local function CommandPanel_UpdatePageText(total)
    local maxPage = math.max(1, math.ceil(total / perPage))
    if currentPage > maxPage then
        currentPage = maxPage
    end

    if MainWindow.SetPageControlsVisible then
        MainWindow.SetPageControlsVisible(true)
    end

    local pageTextValue = "Page " .. currentPage .. "/" .. maxPage
    if MainWindow.SetPageText then
        MainWindow.SetPageText(pageTextValue)
    else
        getglobal("Forged_Mangosbot_CommandPanelFramePageText"):SetText(pageTextValue)
    end

    local prevEnabled = currentPage > 1
    local nextEnabled = currentPage < maxPage

    if MainWindow.SetPageButtonsEnabled then
        MainWindow.SetPageButtonsEnabled(prevEnabled, nextEnabled)
    else
        local prev = getglobal("Forged_Mangosbot_CommandPanelFramePrevPage")
        local next = getglobal("Forged_Mangosbot_CommandPanelFrameNextPage")

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

local function CommandPanel_UpdateWindowTitle()
    local titleTextValue = "Book of Commands"
    if MainWindow.SetTitle then
        MainWindow.SetTitle(titleTextValue)
        return
    end

    local titleText = getglobal("Forged_Mangosbot_CommandPanelFrameTitle")
    if not titleText then
        return
    end

    titleText:SetText(titleTextValue)
end

local function CommandPanel_ApplyCategoryTabState(tab, selected)
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

local function CommandPanel_ConfigureCategoryTab(tab, category)
    tab.categoryKey = category.key
    tab.tooltipText = category.label
    tab.icon:SetTexture(CommandPanel_ResolveCategoryIcon(category))
end

local function CommandPanel_UpdateTabs()
    local i
    for i = 1, table.getn(tabButtons) do
        local tab = tabButtons[i]
        CommandPanel_ApplyCategoryTabState(tab, CommandPanel_IsCategorySelected(tab.categoryKey))
    end
end

local function CommandPanel_UpdateGrid()
    local commands = CommandPanel_GetCommandsForCurrentCategory()
    local total = table.getn(commands)
    local startIndex = (currentPage - 1) * perPage + 1
    local i

    for i = 1, table.getn(gridButtons) do
        local idx = startIndex + i - 1
        local button = gridButtons[i]
        local def = commands[idx]

        if def then
            button.def = def
            button.icon:SetTexture(CommandPanel_ResolveIcon(def))
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

    CommandPanel_UpdatePageText(total)
end

local function CommandPanel_ShowGridPanel()
    local companionContainer = MainWindow.GetCompanionContainer and MainWindow.GetCompanionContainer() or getglobal("Forged_Mangosbot_CommandPanelFrameCompanionContainer")
    local gridContainer = MainWindow.GetGridContainer and MainWindow.GetGridContainer() or getglobal("Forged_Mangosbot_CommandPanelFrameGridContainer")
    local tabContainer = MainWindow.GetTabContainer and MainWindow.GetTabContainer() or getglobal("Forged_Mangosbot_CommandPanelFrameTabContainer")

    if companionContainer then
        companionContainer:Hide()
    end
    if tabContainer then
        tabContainer:Show()
    end
    if gridContainer then
        gridContainer:Show()
    end
    CommandPanel_UpdateGrid()
end

CommandPanel_Refresh = function()
    CommandPanel_UpdateWindowTitle()
    CommandPanel_UpdateTabs()
    CommandPanel_ShowGridPanel()
end

local function CommandPanel_CreateTab(parent, category, index)
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
    CommandPanel_ConfigureCategoryTab(tab, category)

    tab:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText(this.tooltipText)
        GameTooltip:Show()
    end)

    tab:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    tab:SetScript("OnClick", function()
        CommandPanel_SelectCategory(this.categoryKey)
    end)

    return tab
end

local function CommandPanel_CreateGridButton(parent, index)
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
                CommandPanel_RunVisual(this.def, this)
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

local function CommandPanel_SetupPositionPersistence()
    -- Intentionally disabled so the frame behaves like a managed Blizzard panel.
end

local function CommandPanel_ShowPanel()
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

local function CommandPanel_HidePanel()
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

local function CommandPanel_ApplyLeftPanelPosition()
    if MainWindow.ApplyLeftPanelPosition then
        MainWindow.ApplyLeftPanelPosition()
    end
end

local function CommandPanel_ApplySpellBookSize()
    if MainWindow.ApplySpellBookSize then
        MainWindow.ApplySpellBookSize()
    end
end

function CommandPanel.Toggle()
    if not frame then
        CommandPanel.Init()
    end

    if not frame then
        CommandPanel_Print("Forged_Mangosbot: Book of Commands frame is missing. Please check for XML load errors on login.")
        return
    end

    if frame:IsVisible() then
        CommandPanel_HidePanel()
    else
        CommandPanel_ShowPanel()
        CommandPanel_Refresh()
    end
end

function CommandPanel.Init()
    if frame then
        return
    end

    frame = MainWindow.Init and MainWindow.Init() or getglobal(frameName)
    if not frame then
        CommandPanel_Print("Forged_Mangosbot: missing frame 'Forged_Mangosbot_CommandPanelFrame'.")
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

    CommandPanel_ApplySpellBookSize()
    CommandPanel_ApplyLeftPanelPosition()

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

    local i
    for i = 1, table.getn(categories) do
        tabButtons[i] = CommandPanel_CreateTab(tabContainer, categories[i], i)
    end

    for i = 1, perPage do
        gridButtons[i] = CommandPanel_CreateGridButton(gridContainer, i)
    end

    getglobal(frameName .. "PrevPage"):SetScript("OnClick", function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            CommandPanel_Refresh()
        end
    end)

    getglobal(frameName .. "NextPage"):SetScript("OnClick", function()
        currentPage = currentPage + 1
        CommandPanel_Refresh()
    end)

    frame:SetScript("OnShow", function()
        CommandPanel_ApplySpellBookSize()
        CommandPanel_ApplyLeftPanelPosition()
        CommandPanel_Refresh()
    end)

    CommandPanel_SetupPositionPersistence()
    CommandPanel_Refresh()
end

-- Publish stable hooks so the core file can re-bind the module table if needed.
Forged_Mangosbot_CommandPanel_Init = CommandPanel.Init
Forged_Mangosbot_CommandPanel_Toggle = CommandPanel.Toggle
