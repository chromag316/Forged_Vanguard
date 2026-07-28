Forged_Mangosbot = Forged_Mangosbot or {}

local MacroBridge = {}
local MACRO_PREFIX = "FMB_"
local MAX_TOTAL_MACROS = 36
local DEFAULT_ICON = "INV_Misc_QuestionMark"
local DEFAULT_ICON_INDEX = 1

Forged_Mangosbot.MacroBridge = MacroBridge

local function MacroBridge_EnsureDB()
    if type(Forged_MangosbotMacroDB) ~= "table" then
        Forged_MangosbotMacroDB = {}
    end
end

local function MacroBridge_Print(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local function MacroBridge_HashId(id)
    local hash = 0
    local i
    for i = 1, string.len(id) do
        local ch = string.byte(id, i)
        hash = math.mod((hash * 33 + ch), 2147483647)
    end
    return hash
end

local function MacroBridge_MacroNameForId(id)
    local hash = MacroBridge_HashId(id)
    local text = tostring(hash)
    return string.sub(MACRO_PREFIX .. text, 1, 16)
end

local function MacroBridge_MacroBodyForId(id)
    return "/script Forged_Mangosbot_Run(\"" .. id .. "\")"
end

local function MacroBridge_CreateMacroCompat(name, body, perCharacter)
    local isLocal = false
    return CreateMacro(name, DEFAULT_ICON_INDEX, body, isLocal, perCharacter)
end

local function MacroBridge_GetStoragePreference()
    local globalCount, characterCount = GetNumMacros()
    if globalCount < 18 then
        return false
    end
    if characterCount < 18 then
        return true
    end
    return nil
end

local function MacroBridge_TotalMacros()
    local globalCount, characterCount = GetNumMacros()
    return globalCount + characterCount
end

local function MacroBridge_ResolveIcon(def)
    if not def or not def.icon then
        return DEFAULT_ICON
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

local function MacroBridge_EnsurePopup()
    if not StaticPopupDialogs then
        return
    end

    if StaticPopupDialogs.FORGED_MANGOSBOT_MACRO_FULL then
        return
    end

    StaticPopupDialogs.FORGED_MANGOSBOT_MACRO_FULL = {
        text = "No free macro slots for companion commands. Open the Macro UI and delete one, then drag again.",
        button1 = "Open Macros",
        button2 = "Close",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnAccept = function()
            if MacroFrame then
                ShowUIPanel(MacroFrame)
            elseif ToggleCharacter then
                ToggleCharacter("MacroFrame")
            end
        end
    }
end

local function MacroBridge_ShowMacroFullPrompt()
    MacroBridge_Print("Forged_Mangosbot: macro slots are full (36/36). Free one macro slot, then drag the companion command again.")
    MacroBridge_EnsurePopup()
    if StaticPopup_Show then
        StaticPopup_Show("FORGED_MANGOSBOT_MACRO_FULL")
    end
end

function MacroBridge.GetOrCreateMacro(id)
    MacroBridge_EnsureDB()

    if type(id) ~= "string" then
        return nil
    end

    local existingName = Forged_MangosbotMacroDB[id]
    if type(existingName) == "string" then
        local existingIndex = GetMacroIndexByName(existingName)
        if existingIndex and existingIndex > 0 then
            return existingIndex
        end
    end

    local registry = Forged_Mangosbot.Registry
    local def = nil
    if registry and registry.Get then
        def = registry.Get(id)
    end

    if not def then
        MacroBridge_Print("Forged_Mangosbot: unknown companion command id " .. id)
        return nil
    end

    if MacroBridge_TotalMacros() >= MAX_TOTAL_MACROS then
        MacroBridge_ShowMacroFullPrompt()
        return nil
    end

    local macroName = MacroBridge_MacroNameForId(id)
    local macroBody = MacroBridge_MacroBodyForId(id)

    local existingByName = GetMacroIndexByName(macroName)
    if existingByName and existingByName > 0 then
        EditMacro(existingByName, macroName, DEFAULT_ICON_INDEX, macroBody)
        Forged_MangosbotMacroDB[id] = macroName
        return existingByName
    end

    local perCharacter = MacroBridge_GetStoragePreference()
    if perCharacter == nil then
        MacroBridge_ShowMacroFullPrompt()
        return nil
    end

    local macroIndex = MacroBridge_CreateMacroCompat(macroName, macroBody, perCharacter)
    if not macroIndex or macroIndex == 0 then
        macroIndex = MacroBridge_CreateMacroCompat(macroName, macroBody, false)
    end
    if not macroIndex or macroIndex == 0 then
        macroIndex = MacroBridge_CreateMacroCompat(macroName, macroBody, true)
    end

    if macroIndex and macroIndex > 0 then
        Forged_MangosbotMacroDB[id] = macroName
        return macroIndex
    end

    MacroBridge_Print("Forged_Mangosbot: failed to create macro for companion command " .. id)
    return nil
end

function MacroBridge.PickUp(id)
    local macroIndex = MacroBridge.GetOrCreateMacro(id)
    if macroIndex and macroIndex > 0 then
        PickupMacro(macroIndex)
    else
        MacroBridge_Print("Forged_Mangosbot: could not pick up companion command macro.")
    end
end

function MacroBridge.Cleanup()
    MacroBridge_EnsureDB()

    local id, macroName
    for id, macroName in pairs(Forged_MangosbotMacroDB) do
        if type(macroName) ~= "string" or GetMacroIndexByName(macroName) == 0 then
            Forged_MangosbotMacroDB[id] = nil
        end
    end
end

function Forged_Mangosbot_Run(id)
    if type(id) ~= "string" then
        return
    end

    local registry = Forged_Mangosbot.Registry
    if not registry or not registry.Get then
        return
    end

    local def = registry.Get(id)
    if not def then
        MacroBridge_Print("Forged_Mangosbot: command not found for id " .. id)
        return
    end

    if type(ToolBarButtonOnClick) ~= "function" then
        MacroBridge_Print("Forged_Mangosbot requires Mangosbot to be installed and enabled.")
        return
    end

    ToolBarButtonOnClick(def, false)
end
