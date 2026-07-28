Forged_Mangosbot = Forged_Mangosbot or {}

local BookOfCommands = {}
Forged_Mangosbot.BookOfCommands = BookOfCommands
Forged_Mangosbot_BookOfCommands_Loaded = true

local function BookOfCommands_Print(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local frame = nil
local frameName = "Forged_Mangosbot_BookOfCommandsFrame"
local tabButtons = {}
local gridButtons = {}
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

    getglobal("Forged_Mangosbot_BookOfCommandsFramePageText"):SetText("Page " .. currentPage .. "/" .. maxPage)

    local prev = getglobal("Forged_Mangosbot_BookOfCommandsFramePrevPage")
    local next = getglobal("Forged_Mangosbot_BookOfCommandsFrameNextPage")

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

local function BookOfCommands_UpdateTabs()
    local i
    for i = 1, table.getn(tabButtons) do
        local tab = tabButtons[i]
        if tab.categoryKey == currentCategory then
            tab:SetChecked(true)
            if tab.bg then
                tab.bg:SetVertexColor(1, 1, 1, 1)
            end
            if tab.flash then
                tab.flash:Show()
            end
        else
            tab:SetChecked(false)
            if tab.bg then
                tab.bg:SetVertexColor(0.85, 0.85, 0.85, 1)
            end
            if tab.flash then
                tab.flash:Hide()
            end
        end
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
    local companionContainer = getglobal("Forged_Mangosbot_BookOfCommandsFrameCompanionContainer")
    local gridContainer = getglobal("Forged_Mangosbot_BookOfCommandsFrameGridContainer")

    gridContainer:Hide()
    companionContainer:Show()

    if Forged_Mangosbot.CompanionPanel and Forged_Mangosbot.CompanionPanel.Init then
        Forged_Mangosbot.CompanionPanel.Init(companionContainer)
        Forged_Mangosbot.CompanionPanel.Refresh()
    end

    BookOfCommands_UpdatePageText(0)
end

local function BookOfCommands_ShowGridPanel()
    local companionContainer = getglobal("Forged_Mangosbot_BookOfCommandsFrameCompanionContainer")
    local gridContainer = getglobal("Forged_Mangosbot_BookOfCommandsFrameGridContainer")

    companionContainer:Hide()
    gridContainer:Show()
    BookOfCommands_UpdateGrid()
end

local function BookOfCommands_Refresh()
    BookOfCommands_UpdateTabs()
    if currentCategory == "companions" then
        BookOfCommands_ShowCompanionPanel()
    else
        BookOfCommands_ShowGridPanel()
    end
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
    tab.icon:SetTexture(BookOfCommands_ResolveCategoryIcon(category))

    tab.flash = tab:CreateTexture(nil, "OVERLAY")
    tab.flash:SetTexture("Interface\\Buttons\\CheckButtonGlow")
    tab.flash:SetWidth(64)
    tab.flash:SetHeight(64)
    tab.flash:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.flash:SetBlendMode("ADD")
    tab.flash:Hide()
    tab.categoryKey = category.key
    tab.tooltipText = category.label

    tab:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText(this.tooltipText)
        GameTooltip:Show()
    end)

    tab:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    tab:SetScript("OnClick", function()
        currentCategory = this.categoryKey
        currentPage = 1
        BookOfCommands_Refresh()
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

    if type(HideUIPanel) == "function" then
        HideUIPanel(frame)
    else
        frame:Hide()
    end
end

local function BookOfCommands_ApplyLeftPanelPosition()
    if not frame then
        return
    end

    if frame.IsMovable and frame.SetUserPlaced and frame:IsMovable() then
        frame:SetUserPlaced(false)
    end
    frame:ClearAllPoints()

    if type(UIParent) == "table" then
        -- Match Blizzard left-side panels (Character, Spellbook, Talents, Social).
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function BookOfCommands_ApplySpellBookSize()
    if not frame then
        return
    end

    local spellBook = getglobal("SpellBookFrame")
    if spellBook and spellBook.GetWidth and spellBook.GetHeight then
        local w = spellBook:GetWidth()
        local h = spellBook:GetHeight()
        if w and h and w > 0 and h > 0 then
            frame:SetWidth(w)
            frame:SetHeight(h)
        end
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

    frame = getglobal(frameName)
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

    frame:SetMovable(false)
    frame:RegisterForDrag()
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    frame:SetClampedToScreen(true)
    BookOfCommands_ApplySpellBookSize()
    BookOfCommands_ApplyLeftPanelPosition()

    local titleText = getglobal("Forged_Mangosbot_BookOfCommandsFrameTitle")
    if titleText and titleText.SetFontObject then
        titleText:SetFontObject(GameFontNormal)
        titleText:ClearAllPoints()
        titleText:SetPoint("TOP", frame, "TOP", 6, -20)
    end

    local pageText = getglobal("Forged_Mangosbot_BookOfCommandsFramePageText")
    if pageText then
        pageText:SetFontObject(GameFontNormal)
        pageText:ClearAllPoints()
        pageText:SetPoint("BOTTOM", frame, "BOTTOM", -14, 96)
    end

    local closeButton = getglobal("Forged_Mangosbot_BookOfCommandsFrameClose")
    if closeButton then
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -9)
    end

    local prevButton = getglobal("Forged_Mangosbot_BookOfCommandsFramePrevPage")
    if prevButton then
        prevButton:ClearAllPoints()
        prevButton:SetPoint("CENTER", frame, "BOTTOMLEFT", 50, 105)
        prevButton:SetWidth(32)
        prevButton:SetHeight(32)
        prevButton:SetText("")
        prevButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
        prevButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
        prevButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
        prevButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    end

    local nextButton = getglobal("Forged_Mangosbot_BookOfCommandsFrameNextPage")
    if nextButton then
        nextButton:ClearAllPoints()
        nextButton:SetPoint("CENTER", frame, "BOTTOMLEFT", 314, 105)
        nextButton:SetWidth(32)
        nextButton:SetHeight(32)
        nextButton:SetText("")
        nextButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        nextButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        nextButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
        nextButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    end

    if not frame.forgedSpellBookIcon and frame.CreateTexture then
        frame.forgedSpellBookIcon = frame:CreateTexture(nil, "BACKGROUND")
        frame.forgedSpellBookIcon:SetTexture("Interface\\Spellbook\\Spellbook-Icon")
        frame.forgedSpellBookIcon:SetWidth(58)
        frame.forgedSpellBookIcon:SetHeight(58)
        frame.forgedSpellBookIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    end

    local tabContainer = getglobal("Forged_Mangosbot_BookOfCommandsFrameTabContainer")
    local gridContainer = getglobal("Forged_Mangosbot_BookOfCommandsFrameGridContainer")
    local companionContainer = getglobal("Forged_Mangosbot_BookOfCommandsFrameCompanionContainer")

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
        companionContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -132)
        companionContainer:SetWidth(330)
        companionContainer:SetHeight(310)
    end

    local i
    for i = 1, table.getn(categories) do
        tabButtons[i] = BookOfCommands_CreateTab(tabContainer, categories[i], i)
    end

    for i = 1, perPage do
        gridButtons[i] = BookOfCommands_CreateGridButton(gridContainer, i)
    end

    getglobal("Forged_Mangosbot_BookOfCommandsFramePrevPage"):SetScript("OnClick", function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            BookOfCommands_Refresh()
        end
    end)

    getglobal("Forged_Mangosbot_BookOfCommandsFrameNextPage"):SetScript("OnClick", function()
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
