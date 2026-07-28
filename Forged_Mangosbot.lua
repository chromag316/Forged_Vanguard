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

local function Forged_Mangosbot_Print(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local function Forged_Mangosbot_EnsureCommandBookFallback()
    Forged_Mangosbot.CommandBook = Forged_Mangosbot.CommandBook or {}

    local fallbackFrame = nil
    local fallbackButtons = {}
    local fallbackCategory = "movement"
    local fallbackPage = 1
    local fallbackPerPage = 20
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
        { key = "inventory", label = "Inventory" }
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

        local commands = Fallback_GetCommands()
        local maxPage = math.max(1, math.ceil(table.getn(commands) / fallbackPerPage))
        if fallbackPage > maxPage then
            fallbackPage = maxPage
        end

        if fallbackFrame.pageText then
            fallbackFrame.pageText:SetText("Page " .. fallbackPage .. "/" .. maxPage)
        end

        local i
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
        f:SetWidth(540)
        f:SetHeight(430)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:Hide()
        f:SetBackdrop({
            bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })

        local title = f:CreateFontString("Forged_Mangosbot_CommandBookFrameTitle", "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -14)
        title:SetText("Companion Command Book")

        local pageText = f:CreateFontString("Forged_Mangosbot_CommandBookFramePageText", "OVERLAY", "GameFontHighlightSmall")
        pageText:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)
        f.pageText = pageText

        local close = CreateFrame("Button", "Forged_Mangosbot_CommandBookFrameClose", f)
        close:SetWidth(22)
        close:SetHeight(22)
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
        close:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
        close:SetPushedTexture("Interface/Buttons/UI-Panel-MinimizeButton-Down")
        close:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight")
        close:SetScript("OnClick", function() f:Hide() end)

        local tabContainer = CreateFrame("Frame", "Forged_Mangosbot_CommandBookFrameTabContainer", f)
        tabContainer:SetWidth(510)
        tabContainer:SetHeight(56)
        tabContainer:SetPoint("TOP", f, "TOP", 0, -42)

        local grid = CreateFrame("Frame", "Forged_Mangosbot_CommandBookFrameGridContainer", f)
        grid:SetWidth(500)
        grid:SetHeight(300)
        grid:SetPoint("TOP", tabContainer, "BOTTOM", 0, -8)
        grid:SetBackdrop({
            bgFile = "Interface/ChatFrame/ChatFrameBackground",
            tile = true,
            tileSize = 16,
            edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        grid:SetBackdropColor(0, 0, 0, 0.35)

        local companions = CreateFrame("Frame", "Forged_Mangosbot_CommandBookFrameCompanionContainer", f)
        companions:SetWidth(500)
        companions:SetHeight(300)
        companions:SetPoint("TOP", tabContainer, "BOTTOM", 0, -8)
        companions:Hide()

        local prev = CreateFrame("Button", "Forged_Mangosbot_CommandBookFramePrevPage", f, "UIPanelButtonTemplate")
        prev:SetWidth(24)
        prev:SetHeight(22)
        prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 200, 10)
        prev:SetText("<")
        prev:SetScript("OnClick", function()
            if fallbackPage > 1 then
                fallbackPage = fallbackPage - 1
                Fallback_Update()
            end
        end)

        local next = CreateFrame("Button", "Forged_Mangosbot_CommandBookFrameNextPage", f, "UIPanelButtonTemplate")
        next:SetWidth(24)
        next:SetHeight(22)
        next:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -200, 10)
        next:SetText(">")
        next:SetScript("OnClick", function()
            fallbackPage = fallbackPage + 1
            Fallback_Update()
        end)

        local i
        for i = 1, table.getn(fallbackCategories) do
            local cat = fallbackCategories[i]
            local tab = CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
            tab:SetWidth(92)
            tab:SetHeight(20)
            local row = math.floor((i - 1) / 5)
            local col = math.mod(i - 1, 5)
            tab:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", col * 100 + 4, -row * 24 - 4)
            tab:SetText(cat.label)
            tab.categoryKey = cat.key
            tab:SetScript("OnClick", function()
                fallbackCategory = this.categoryKey
                fallbackPage = 1
                Fallback_Update()
            end)
        end

        for i = 1, fallbackPerPage do
            local button = CreateFrame("Button", nil, grid)
            button:SetWidth(44)
            button:SetHeight(44)
            local col = math.mod(i - 1, 5)
            local row = math.floor((i - 1) / 5)
            button:SetPoint("TOPLEFT", grid, "TOPLEFT", 24 + col * 94, -22 - row * 70)
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

            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
            button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

            button:SetScript("OnEnter", function()
                if this.def then
                    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                    GameTooltip:SetText(this.def.tooltip or this.def.id)
                    GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            button:SetScript("OnClick", function()
                if this.def then
                    ToolBarButtonOnClick(this.def, false)
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
        if previousOnShow then
            previousOnShow()
        end
        this:Hide()
    end)
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

    Forged_Mangosbot_HookHideFrame(BotRoster)
    Forged_Mangosbot_HookHideFrame(SelectedBotPanel)

    if Forged_Mangosbot.Registry and Forged_Mangosbot.Registry.Build then
        Forged_Mangosbot.Registry.Build()
    end

    if Forged_Mangosbot.MacroBridge and Forged_Mangosbot.MacroBridge.Cleanup then
        Forged_Mangosbot.MacroBridge.Cleanup()
    end

    if Forged_Mangosbot.CommandBook and Forged_Mangosbot.CommandBook.Init then
        Forged_Mangosbot.CommandBook.Init()
    end
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
