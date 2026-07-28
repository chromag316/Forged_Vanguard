Forged_Mangosbot = Forged_Mangosbot or {}

BINDING_HEADER_FORGED_MANGOSBOT = "Forged Mangosbot"
BINDING_NAME_FORGED_MANGOSBOT_TOGGLE = "Toggle Companion Command Book"
BINDING_NAME_FORGED_MANGOSBOT_FOLLOW = "Companion follow"
BINDING_NAME_FORGED_MANGOSBOT_STAY = "Companion stay"
BINDING_NAME_FORGED_MANGOSBOT_LOOT = "Companion loot"

local addonName = "Forged_Mangosbot"
local eventFrame = CreateFrame("Frame")
local ready = false
local initialized = false
local slashRegistered = false
local unitPopupHooked = false
local forgedUnitMenuToken = "FORGED_MANGOSBOT_OPEN"
local allowSelectedBotPanelShow = false

local function Forged_Mangosbot_Print(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local function Forged_Mangosbot_EnsureCommandBookFallback()
    Forged_Mangosbot.CommandBook = Forged_Mangosbot.CommandBook or {}

    local fallbackFrame = nil
    local fallbackButtons = {}
    local fallbackTabs = {}
    local fallbackCategory = "movement"
    local fallbackPage = 1
    local fallbackPerPage = 16
    local fallbackCategories = {
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

    local function Fallback_ResolveIcon(def)
        if not def or not def.icon then
            return "Interface\\Icons\\INV_Misc_QuestionMark"
        end
        local icon = def.icon
        if string.find(icon, "\\") or string.find(icon, "/") or string.find(icon, "%.") then
            return icon
        end
        return "Interface\\Addons\\Mangosbot\\Images\\" .. icon .. ".tga"
    end

    local function Fallback_GetCommands()
        local list = {}
        local registry = Forged_Mangosbot.Registry
        local all = registry and registry.GetAll and registry.GetAll() or {}
        local id, def
        for id, def in pairs(all) do
            if def.category == fallbackCategory then
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

    local function Fallback_Update()
        if not fallbackFrame then
            return
        end

        local i
        for i = 1, table.getn(fallbackTabs) do
            local tab = fallbackTabs[i]
            if tab.categoryKey == fallbackCategory then
                tab:SetBackdropColor(0.30, 0.20, 0.05, 0.95)
            else
                tab:SetBackdropColor(0.10, 0.10, 0.10, 0.85)
            end
        end

        if fallbackCategory == "companions" then
            fallbackFrame.gridContainer:Hide()
            fallbackFrame.companionContainer:Show()

            if fallbackFrame.prevButton then
                fallbackFrame.prevButton:Disable()
            end
            if fallbackFrame.nextButton then
                fallbackFrame.nextButton:Disable()
            end

            if fallbackFrame.pageText then
                fallbackFrame.pageText:SetText("Companions")
            end

            if Forged_Mangosbot.CompanionPanel and Forged_Mangosbot.CompanionPanel.Init then
                Forged_Mangosbot.CompanionPanel.Init(fallbackFrame.companionContainer)
                Forged_Mangosbot.CompanionPanel.Refresh()
            end
            return
        end

        fallbackFrame.gridContainer:Show()
        fallbackFrame.companionContainer:Hide()

        local commands = Fallback_GetCommands()
        local maxPage = math.max(1, math.ceil(table.getn(commands) / fallbackPerPage))
        if fallbackPage > maxPage then
            fallbackPage = maxPage
        end

        if fallbackFrame.pageText then
            fallbackFrame.pageText:SetText("Page " .. fallbackPage .. "/" .. maxPage)
        end

        if fallbackFrame.prevButton then
            if fallbackPage > 1 then
                fallbackFrame.prevButton:Enable()
            else
                fallbackFrame.prevButton:Disable()
            end
        end

        if fallbackFrame.nextButton then
            if fallbackPage < maxPage then
                fallbackFrame.nextButton:Enable()
            else
                fallbackFrame.nextButton:Disable()
            end
        end

        for i = 1, table.getn(fallbackButtons) do
            local idx = (fallbackPage - 1) * fallbackPerPage + i
            local def = commands[idx]
            local button = fallbackButtons[i]
            if def then
                button.def = def
                button.icon:SetTexture(Fallback_ResolveIcon(def))
                button:Show()
            else
                button.def = nil
                button:Hide()
            end
        end
    end

    local function Fallback_CreateFrame()
        local existing = getglobal("Forged_Mangosbot_CommandBookFrame")
        if existing then
            return existing
        end

        local f = CreateFrame("Frame", "Forged_Mangosbot_CommandBookFrame", UIParent)
        f:SetWidth(560)
        f:SetHeight(440)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:Hide()
        f:SetBackdrop({
            bgFile = "Interface/Spellbook/UI-SpellBook-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = false,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })

        local title = f:CreateFontString("Forged_Mangosbot_CommandBookFrameTitle", "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -14)
        title:SetText("Companion Abilities")

        local pageText = f:CreateFontString("Forged_Mangosbot_CommandBookFramePageText", "OVERLAY", "GameFontHighlightSmall")
        pageText:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)
        f.pageText = pageText

        local close = CreateFrame("Button", "Forged_Mangosbot_CommandBookFrameClose", f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

        local tabContainer = CreateFrame("Frame", "Forged_Mangosbot_CommandBookFrameTabContainer", f)
        tabContainer:SetWidth(120)
        tabContainer:SetHeight(360)
        tabContainer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -48)

        local grid = CreateFrame("Frame", "Forged_Mangosbot_CommandBookFrameGridContainer", f)
        grid:SetWidth(400)
        grid:SetHeight(320)
        grid:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -52)
        grid:SetBackdrop({
            bgFile = "Interface/Spellbook/UI-SpellBook-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = false,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        grid:SetBackdropColor(0.2, 0.16, 0.08, 0.95)

        f.gridContainer = grid

        local companions = CreateFrame("Frame", "Forged_Mangosbot_CommandBookFrameCompanionContainer", f)
        companions:SetWidth(400)
        companions:SetHeight(320)
        companions:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -52)
        companions:SetBackdrop({
            bgFile = "Interface/Spellbook/UI-SpellBook-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = false,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        companions:SetBackdropColor(0.2, 0.16, 0.08, 0.95)
        companions:Hide()

        f.companionContainer = companions

        local prev = CreateFrame("Button", "Forged_Mangosbot_CommandBookFramePrevPage", f, "UIPanelButtonTemplate")
        prev:SetWidth(26)
        prev:SetHeight(22)
        prev:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 120, -28)
        prev:SetText("<")
        prev:SetScript("OnClick", function()
            if fallbackPage > 1 then
                fallbackPage = fallbackPage - 1
                Fallback_Update()
            end
        end)

        f.prevButton = prev

        local next = CreateFrame("Button", "Forged_Mangosbot_CommandBookFrameNextPage", f, "UIPanelButtonTemplate")
        next:SetWidth(26)
        next:SetHeight(22)
        next:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", -120, -28)
        next:SetText(">")
        next:SetScript("OnClick", function()
            fallbackPage = fallbackPage + 1
            Fallback_Update()
        end)

        f.nextButton = next

        local i
        for i = 1, table.getn(fallbackCategories) do
            local cat = fallbackCategories[i]
            local tab = CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
            tab:SetWidth(112)
            tab:SetHeight(22)
            tab:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", 0, -(i - 1) * 24)
            tab:SetText(cat.label)
            if tab.SetNormalFontObject then
                tab:SetNormalFontObject(GameFontHighlightSmall)
            end
            tab:SetBackdrop({
                bgFile = "Interface/Buttons/WHITE8X8",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true,
                tileSize = 8,
                edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            tab:SetBackdropBorderColor(0.25, 0.18, 0.10, 1.0)
            tab:SetBackdropColor(0.10, 0.10, 0.10, 0.85)
            tab.categoryKey = cat.key
            tab:SetScript("OnClick", function()
                fallbackCategory = this.categoryKey
                fallbackPage = 1
                Fallback_Update()
            end)

            fallbackTabs[i] = tab
        end

        for i = 1, fallbackPerPage do
            local button = CreateFrame("Button", nil, grid)
            button:SetWidth(56)
            button:SetHeight(56)
            local col = math.mod(i - 1, 4)
            local row = math.floor((i - 1) / 4)
            button:SetPoint("TOPLEFT", grid, "TOPLEFT", 24 + col * 92, -22 - row * 74)
            button:EnableMouse(true)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button:RegisterForDrag("LeftButton", "RightButton")
            button:SetBackdrop({
                bgFile = "Interface/Buttons/WHITE8X8",
                edgeFile = "Interface/Buttons/UI-Quickslot2",
                tile = true,
                tileSize = 8,
                edgeSize = 16,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            })
            button:SetBackdropColor(0, 0, 0, 0.35)

            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -6)
            button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 6)
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

            button:SetScript("OnEnter", function()
                if this.def then
                    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                    GameTooltip:SetText(this.def.tooltip or this.def.id)
                    GameTooltip:AddLine("Left-click and drag: place on action bar", 0.8, 0.8, 0.8)
                    GameTooltip:AddLine("Right-click: execute", 0.8, 0.8, 0.8)
                    GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            button:SetScript("OnClick", function()
                if this.def then
                    if arg1 == "RightButton" then
                        ToolBarButtonOnClick(this.def, false)
                    end
                end
            end)
            button:SetScript("OnDragStart", function()
                if this.def and Forged_Mangosbot.MacroBridge and Forged_Mangosbot.MacroBridge.PickUp then
                    Forged_Mangosbot.MacroBridge.PickUp(this.def.id)
                end
            end)

            fallbackButtons[i] = button
        end

        if type(EnablePositionSaving) == "function" then
            EnablePositionSaving(f, "Forged_Mangosbot_CommandBookFrame")
        else
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", function() this:StartMoving() end)
            f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        end

        return f
    end

    if not Forged_Mangosbot.CommandBook.Init then
        Forged_Mangosbot.CommandBook.Init = function()
            fallbackFrame = fallbackFrame or Fallback_CreateFrame()
            if not fallbackFrame then
                Forged_Mangosbot_Print("Forged_Mangosbot: command book frame is missing. Reload UI and check XML load errors.")
                return
            end
            Fallback_Update()
            return fallbackFrame
        end
    end

    if not Forged_Mangosbot.CommandBook.Toggle then
        Forged_Mangosbot.CommandBook.Toggle = function()
            local frame = fallbackFrame
            if Forged_Mangosbot.CommandBook.Init then
                frame = Forged_Mangosbot.CommandBook.Init()
            end
            if not frame then
                frame = getglobal("Forged_Mangosbot_CommandBookFrame")
            end
            if not frame then
                Forged_Mangosbot_Print("Forged_Mangosbot: command book is unavailable. UI module may not have loaded.")
                return
            end

            if frame:IsVisible() then
                frame:Hide()
            else
                frame:Show()
                Fallback_Update()
            end
        end
    end
end

local function Forged_Mangosbot_DependencyReady()
    return type(SendBotCommand) == "function" and type(CreateMovementToolBar) == "function"
end

local function Forged_Mangosbot_HookHideFrame(frame)
    if not frame then
        return
    end

    frame:Hide()

    local previousOnShow = frame:GetScript("OnShow")
    frame:SetScript("OnShow", function()
        if allowSelectedBotPanelShow then
            allowSelectedBotPanelShow = false
            if previousOnShow then
                previousOnShow()
            end
            return
        end

        if previousOnShow then
            previousOnShow()
        end
        this:Hide()
    end)
end

local function Forged_Mangosbot_OpenLegacyCommandWindow()
    if type(SelectedBotPanel) ~= "table" then
        return
    end

    if type(SelectedBotPanel.Show) == "function" then
        allowSelectedBotPanelShow = true
        SelectedBotPanel:Show()
    end

    local title = SelectedBotPanel.header and SelectedBotPanel.header.text
    if title and type(title.SetText) == "function" then
        local selectedName = nil
        if type(GetUnitName) == "function" then
            selectedName = GetUnitName("target")
        end
        if (not selectedName or selectedName == "") and CurrentBot then
            selectedName = CurrentBot
        end
        if selectedName and selectedName ~= "" then
            title:SetText(selectedName)
        end
    end
end

local function Forged_Mangosbot_MenuContains(menu, token)
    if type(menu) ~= "table" then
        return false
    end

    local i
    for i = 1, table.getn(menu) do
        if menu[i] == token then
            return true
        end
    end

    return false
end

local function Forged_Mangosbot_RemoveMenuToken(menu, token)
    if type(menu) ~= "table" then
        return
    end

    local i
    for i = table.getn(menu), 1, -1 do
        if menu[i] == token then
            table.remove(menu, i)
        end
    end
end

local function Forged_Mangosbot_InsertMenuToken(menu, token)
    if type(menu) ~= "table" then
        return
    end

    if Forged_Mangosbot_MenuContains(menu, token) then
        return
    end

    local insertAt = table.getn(menu) + 1
    local i
    for i = 1, table.getn(menu) do
        if menu[i] == "CANCEL" then
            insertAt = i
            break
        end
    end

    table.insert(menu, insertAt, token)
end

local function Forged_Mangosbot_ShouldShowUnitMenu(which, unit, name)
    if which ~= "PLAYER" and which ~= "PARTY" and which ~= "RAID_PLAYER" and which ~= "FRIEND" and which ~= "CHAT_ROSTER" then
        return false
    end

    local resolvedName = name
    if (not resolvedName or resolvedName == "") and unit and type(UnitName) == "function" then
        resolvedName = UnitName(unit)
    end
    if (not resolvedName or resolvedName == "") and type(GetUnitName) == "function" then
        resolvedName = GetUnitName("target")
    end
    if not resolvedName or resolvedName == "" then
        return false
    end

    if type(botTable) == "table" and botTable[resolvedName] then
        return true
    end

    if CurrentBot and resolvedName == CurrentBot then
        return true
    end

    return false
end

local function Forged_Mangosbot_HookUnitPopupMenu()
    if unitPopupHooked then
        return
    end

    if type(UnitPopup_ShowMenu) ~= "function" or type(UnitPopup_OnClick) ~= "function" then
        return
    end

    if type(UnitPopupButtons) == "table" and not UnitPopupButtons[forgedUnitMenuToken] then
        UnitPopupButtons[forgedUnitMenuToken] = {
            text = "Command",
            dist = 0
        }
    end

    local originalShowMenu = UnitPopup_ShowMenu
    UnitPopup_ShowMenu = function(dropdownMenu, which, unit, name, userData)
        local menu = UnitPopupMenus and UnitPopupMenus[which]
        if menu then
            if Forged_Mangosbot_ShouldShowUnitMenu(which, unit, name) then
                Forged_Mangosbot_InsertMenuToken(menu, forgedUnitMenuToken)
            else
                Forged_Mangosbot_RemoveMenuToken(menu, forgedUnitMenuToken)
            end
        end

        return originalShowMenu(dropdownMenu, which, unit, name, userData)
    end

    local originalUnitPopupOnClick = UnitPopup_OnClick
    UnitPopup_OnClick = function()
        if this and this.value == forgedUnitMenuToken then
            Forged_Mangosbot_OpenLegacyCommandWindow()
            if CloseDropDownMenus then
                CloseDropDownMenus()
            elseif CloseDropDownMenu then
                CloseDropDownMenu()
            end
            return
        end

        return originalUnitPopupOnClick()
    end

    unitPopupHooked = true
end

local function Forged_Mangosbot_SetupSlashCommands()
    if slashRegistered then
        return
    end

    slashRegistered = true
    SLASH_FORGEDMANGOSBOT1 = "/forgedbot"
    SLASH_FORGEDMANGOSBOT2 = "/fmb"
    SlashCmdList.FORGEDMANGOSBOT = function()
        Forged_Mangosbot_EnsureCommandBookFallback()

        if not Forged_Mangosbot_DependencyReady() then
            Forged_Mangosbot_Print("Forged_Mangosbot requires Mangosbot to be installed and enabled.")
            return
        end

        if not ready then
            ready = true
        end

        if not initialized and Forged_Mangosbot_Initialize then
            Forged_Mangosbot_Initialize()
        end

        Forged_Mangosbot.CommandBook.Toggle()
    end
end

function Forged_Mangosbot_Initialize()
    if initialized or not ready then
        return
    end

    initialized = true

    if Forged_Mangosbot.Registry and Forged_Mangosbot.Registry.Build then
        Forged_Mangosbot.Registry.Build()
    end

    if Forged_Mangosbot.MacroBridge and Forged_Mangosbot.MacroBridge.Cleanup then
        Forged_Mangosbot.MacroBridge.Cleanup()
    end

    if Forged_Mangosbot.CommandBook and Forged_Mangosbot.CommandBook.Init then
        Forged_Mangosbot.CommandBook.Init()
    end

    if type(SelectedBotPanel) == "table" and type(SelectedBotPanel.Hide) == "function" then
        Forged_Mangosbot_HookHideFrame(SelectedBotPanel)
    end

    Forged_Mangosbot_HookUnitPopupMenu()
end

function Forged_Mangosbot_ToggleCommandBook()
    if Forged_Mangosbot.CommandBook and Forged_Mangosbot.CommandBook.Toggle then
        Forged_Mangosbot.CommandBook.Toggle()
    end
end

local function Forged_Mangosbot_RunFirst(ids)
    if not ids then
        return
    end

    local i
    for i = 1, table.getn(ids) do
        local id = ids[i]
        if Forged_Mangosbot.Registry and Forged_Mangosbot.Registry.Get and Forged_Mangosbot.Registry.Get(id) then
            Forged_Mangosbot_Run(id)
            return
        end
    end
end

function Forged_Mangosbot_BindingFollow()
    Forged_Mangosbot_RunFirst({"movement.follow", "movement.follow_master", "movement.near"})
end

function Forged_Mangosbot_BindingStay()
    Forged_Mangosbot_RunFirst({"movement.stay", "movement.wait"})
end

function Forged_Mangosbot_BindingLoot()
    Forged_Mangosbot_RunFirst({"actions.loot", "non_combat.loot"})
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == addonName then
        Forged_Mangosbot_EnsureCommandBookFallback()
        Forged_Mangosbot_SetupSlashCommands()

        if not Forged_Mangosbot_DependencyReady() then
            Forged_Mangosbot_Print("Forged_Mangosbot requires Mangosbot to be installed and enabled.")
            ready = false
            return
        end

        ready = true
        return
    end

    if event == "PLAYER_LOGIN" then
        if not ready then
            return
        end

        if not initialized then
            Forged_Mangosbot_Initialize()
        else
            return
        end
    end
end)
