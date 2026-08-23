Forged_Mangosbot = Forged_Mangosbot or {}

BINDING_HEADER_FORGED_MANGOSBOT = "Forged Mangosbot"
BINDING_NAME_FORGED_MANGOSBOT_TOGGLE = "Toggle Book of Commands"
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

local function Forged_Mangosbot_ResolveBookOfCommandsHandlers()
    local initFn = nil
    local toggleFn = nil

    local module = Forged_Mangosbot.BookOfCommands
    if type(module) == "table" then
        if type(module.Init) == "function" then
            initFn = module.Init
        end
        if type(module.Toggle) == "function" then
            toggleFn = module.Toggle
        end
    end

    if not initFn and type(Forged_Mangosbot_BookOfCommands_Init) == "function" then
        initFn = Forged_Mangosbot_BookOfCommands_Init
    end
    if not toggleFn and type(Forged_Mangosbot_BookOfCommands_Toggle) == "function" then
        toggleFn = Forged_Mangosbot_BookOfCommands_Toggle
    end

    if (not initFn or not toggleFn) and type(dofile) == "function" then
        pcall(dofile, "Interface\\AddOns\\Forged_Mangosbot\\BookOfCommands.lua")
        if not initFn and type(Forged_Mangosbot_BookOfCommands_Init) == "function" then
            initFn = Forged_Mangosbot_BookOfCommands_Init
        end
        if not toggleFn and type(Forged_Mangosbot_BookOfCommands_Toggle) == "function" then
            toggleFn = Forged_Mangosbot_BookOfCommands_Toggle
        end
    end

    if initFn and toggleFn then
        Forged_Mangosbot.BookOfCommands = Forged_Mangosbot.BookOfCommands or {}
        Forged_Mangosbot.BookOfCommands.Init = initFn
        Forged_Mangosbot.BookOfCommands.Toggle = toggleFn
        return initFn, toggleFn
    end

    return nil, nil
end

local function Forged_Mangosbot_InstallXmlBookOfCommandsHandlers()
    local frameName = "Forged_Mangosbot_BookOfCommandsFrame"

    local function initFn()
        local frame = getglobal(frameName)
        if not frame then
            return nil
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
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)

        return frame
    end

    local function toggleFn()
        local frame = getglobal(frameName)
        if not frame then
            Forged_Mangosbot_Print("Forged_Mangosbot: missing frame '" .. frameName .. "'.")
            return
        end

        if frame:IsVisible() then
            if type(HideUIPanel) == "function" then
                HideUIPanel(frame)
            else
                frame:Hide()
            end
        else
            if type(ShowUIPanel) == "function" then
                ShowUIPanel(frame)
                if type(UpdateUIPanelPositions) == "function" then
                    UpdateUIPanelPositions()
                end
            else
                frame:Show()
            end
        end
    end

    local frame = getglobal(frameName)
    if not frame then
        return nil, nil
    end

    Forged_Mangosbot.BookOfCommands = Forged_Mangosbot.BookOfCommands or {}
    Forged_Mangosbot.BookOfCommands.Init = initFn
    Forged_Mangosbot.BookOfCommands.Toggle = toggleFn

    return initFn, toggleFn
end

local function Forged_Mangosbot_ValidateBookOfCommandsModule()
    local initFn, toggleFn = Forged_Mangosbot_ResolveBookOfCommandsHandlers()
    if not initFn or not toggleFn then
        initFn, toggleFn = Forged_Mangosbot_InstallXmlBookOfCommandsHandlers()
    end
    if not initFn or not toggleFn then
        local loadedFlag = tostring(Forged_Mangosbot_BookOfCommands_Loaded)
        local initFlag = tostring(type(Forged_Mangosbot_BookOfCommands_Init) == "function")
        local toggleFlag = tostring(type(Forged_Mangosbot_BookOfCommands_Toggle) == "function")
        local frameLoadedFlag = tostring(Forged_Mangosbot_BookOfCommands_FrameLoaded)
        Forged_Mangosbot_Print("Forged_Mangosbot: Book of Commands module did not load. loaded=" .. loadedFlag .. " init=" .. initFlag .. " toggle=" .. toggleFlag .. " frameLoaded=" .. frameLoadedFlag .. ". Check BookOfCommands.lua and BookOfCommands.xml.")
        return false, nil, nil
    end

    return true, initFn, toggleFn
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
        local ok, initFn, toggleFn = Forged_Mangosbot_ValidateBookOfCommandsModule()
        if not ok then
            return
        end

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

        toggleFn()
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

    local ok, initFn = Forged_Mangosbot_ValidateBookOfCommandsModule()
    if ok then
        initFn()
    end

    if type(SelectedBotPanel) == "table" and type(SelectedBotPanel.Hide) == "function" then
        Forged_Mangosbot_HookHideFrame(SelectedBotPanel)
    end

    Forged_Mangosbot_HookUnitPopupMenu()
end

function Forged_Mangosbot_ToggleBookOfCommands()
    local ok, _, toggleFn = Forged_Mangosbot_ValidateBookOfCommandsModule()
    if ok then
        toggleFn()
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
