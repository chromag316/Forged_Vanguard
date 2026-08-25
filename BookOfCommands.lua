Forged_Mangosbot = Forged_Mangosbot or {}

local BookOfCommands = {}
Forged_Mangosbot.BookOfCommands = BookOfCommands

local function BookOfCommands_Print(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

-- Native SpellBookFrame widgets we hide while our tab is active. There is no
-- grouped "sub frame" for the built-in book like FriendsFrame has, so we walk
-- the fixed-name widget sets Blizzard creates directly on SpellBookFrame.
local nativeSpellButtonCount = 12
local nativeSkillLineTabCount = 8

local spellbookTabsInstalled = false
local nativeTabId = 0
local bocTabId = 0
local spellbookUpdateHooked = false
local shouldRestoreOnShow = false

local bocFrame = nil
local bocTabContainer = nil
local socketButtons = {}
local movementTab = nil
local nativeTab = nil
local bocTab = nil
local tabOffsetX = 12
local tabOffsetY = 77

local currentPage = 1
local totalPages = 1
local socketsPerPage = 12

-- Resolve a command's icon path. Mirror CommandPanel_ResolveIcon: bare names
-- resolve to the Mangosbot image folder, absolute paths pass through.
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

-- Movement commands shown in the book, self-contained so the book does not
-- depend on the CommandPanel registry. These mirror the roster panel's group
-- movement toolbar buttons: clicking one orders the whole party.
--
-- group_follow = "Follow me" (order the party to follow you)
-- group_stay   = "Stay in place" (order the party to stay)
local BookOfCommands_MovementCommands = {
    { id = "movement.group_follow", label = "Follow", icon = "Interface\\Icons\\follow", strategy = "follow", tooltip = "Order companions in party to follow you", group = true, emote = "follow", command = {[0] = "#a follow ?"}, index = 0 },
    { id = "movement.group_stay", label = "Stay", icon = "Interface\\Icons\\stay", strategy = "stay", tooltip = "Order companions in party to stay", group = true, emote = "wait", command = {[0] = "#a stay ?"}, index = 1 }
}

-- Return a shallow copy of the movement commands (they are re-bound on every
-- page refresh so the sockets pick up the latest command tables).
local function BookOfCommands_GetMovementCommands()
    local list = {}
    local i
    for i = 1, table.getn(BookOfCommands_MovementCommands) do
        local src = BookOfCommands_MovementCommands[i]
        local def = {}
        local key, value
        for key, value in pairs(src) do
            if key == "command" and type(value) == "table" then
                def.command = {}
                local ck, cv
                for ck, cv in pairs(value) do
                    def.command[ck] = cv
                end
            else
                def[key] = value
            end
        end
        table.insert(list, def)
    end
    return list
end

-- Executes a BookOfCommands command dropped on an action bar. Macro bodies are
-- strings run in the global scope, so the macro calls this global entry which
-- then reaches the book's own command table.
local function BookOfCommands_FindDef(id)
    local i
    for i = 1, table.getn(BookOfCommands_MovementCommands) do
        if BookOfCommands_MovementCommands[i].id == id then
            return BookOfCommands_MovementCommands[i]
        end
    end
    return nil
end

local function BookOfCommands_ExecuteCommand(id)
    local def = BookOfCommands_FindDef(id)
    if def and type(ToolBarButtonOnClick) == "function" then
        ToolBarButtonOnClick(def, false)
    end
end
Forged_Mangosbot_BookOfCommandsRun = BookOfCommands_ExecuteCommand

-- Drag-to-actionbar support. In WoW (vanilla/TBC) custom addon commands can only
-- be bound to an action bar through a macro; there is no macro-free binding for
-- arbitrary /script commands. To keep the footprint small we reuse one cached
-- macro per command instead of creating a new one on every drag.
local MACRO_NAME_PREFIX = "MBC_"
local MACRO_LIMIT = 36

local function BookOfCommands_HashId(id)
    local hash = 0
    local i
    for i = 1, string.len(id) do
        local ch = string.byte(id, i)
        hash = math.mod((hash * 33 + ch), 2147483647)
    end
    return hash
end

-- Name of the macro created for a command. Use the command's short label
-- ("Follow" / "Stay") since vanilla 1.12 caps macro names at 16 characters.
-- Falls back to a hashed name if a def has no label.
local function BookOfCommands_MacroNameFor(def)
    local label = def and def.label
    if type(label) == "string" and label ~= "" then
        return string.sub(label, 1, 16)
    end
    return string.sub(MACRO_NAME_PREFIX .. tostring(BookOfCommands_HashId(def and def.id or "?")), 1, 16)
end

local function BookOfCommands_EnsureDB()
    if type(Forged_MangosbotMacroDB) ~= "table" then
        Forged_MangosbotMacroDB = {}
    end
end

-- The macro icon parameter is a texture name (string), and custom textures live
-- in Interface\\Icons. Point each macro at the same custom icon the book button
-- shows, so a dragged command lands on the action bar with the same art.
-- This client's CreateMacro strictly requires a numeric macro icon index. Index
-- 1 is the default question-mark icon; use it for all commands so the macro and
-- the book button both show the same question mark.
local function BookOfCommands_MacroIconFor(id)
    return 1 -- INV_Misc_QuestionMark default
end

-- The texture a given macro icon index renders to. This is what the book button
-- displays, so it exactly matches the icon the created macro / action-bar button
-- uses. Falls back to a safe default if the readback is unavailable.
local function BookOfCommands_MacroTexture(def)
    local macroIcon = BookOfCommands_MacroIconFor(def.id)
    local texture = nil
    if type(GetMacroIconInfo) == "function" then
        texture = GetMacroIconInfo(macroIcon)
    end
    if type(texture) == "string" and texture ~= "" then
        -- GetMacroIconInfo may return a bare icon name or a full path; SetTexture
        -- needs a full Interface\\Icons path, so normalize either form here.
        if string.find(texture, "\\") or string.find(texture, "/") then
            return texture
        end
        return "Interface\\Icons\\" .. texture
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function BookOfCommands_GetOrCreateMacro(def)
    BookOfCommands_EnsureDB()
    local id = def and def.id
    local existingName = Forged_MangosbotMacroDB[id]
    if type(existingName) == "string" then
        local existingIndex = GetMacroIndexByName(existingName)
        if existingIndex and existingIndex > 0 then
            return existingIndex
        end
    end
    local macroName = BookOfCommands_MacroNameFor(def)
    local macroBody = "/script Forged_Mangosbot_BookOfCommandsRun('" .. id .. "')"
    local macroIcon = BookOfCommands_MacroIconFor(id)
    local existingByName = GetMacroIndexByName(macroName)
    if existingByName and existingByName > 0 then
        EditMacro(existingByName, macroName, macroIcon, macroBody)
        Forged_MangosbotMacroDB[id] = macroName
        return existingByName
    end
    if type(GetNumMacros) == "function" then
        local globalCount, characterCount = GetNumMacros()
        if (globalCount or 0) + (characterCount or 0) >= MACRO_LIMIT then
            BookOfCommands_Print("Forged_Mangosbot: no free macro slots to place this command on the action bar.")
            return nil
        end
    end
    -- Prefer a global (account-wide) macro so dragging a command does not
    -- clutter your per-character macro list. Only fall back to a character
    -- macro if no global slot is available.
    local macroIndex = CreateMacro(macroName, macroIcon, macroBody, false, false)
    if not macroIndex or macroIndex == 0 then
        macroIndex = CreateMacro(macroName, macroIcon, macroBody, false, true)
    end
    if macroIndex and macroIndex > 0 then
        Forged_MangosbotMacroDB[id] = macroName
        return macroIndex
    end
    return nil
end

local function BookOfCommands_PickUp(def)
    local macroIndex = BookOfCommands_GetOrCreateMacro(def)
    if macroIndex and macroIndex > 0 and type(PickupMacro) == "function" then
        PickupMacro(macroIndex)
    end
end

local function BookOfCommands_SetNativeSpellbookWidgetsShown(shown)
    local i

    for i = 1, nativeSpellButtonCount do
        local button = getglobal("SpellButton" .. i)
        if button then
            if shown then
                button:Show()
            else
                button:Hide()
            end
        end
    end

    for i = 1, nativeSkillLineTabCount do
        local tab = getglobal("SpellBookSkillLineTab" .. i)
        if tab then
            if shown then
                tab:Show()
            else
                tab:Hide()
            end
        end
    end

    local prevButton = getglobal("SpellBookPrevPageButton")
    local nextButton = getglobal("SpellBookNextPageButton")
    local pageText = getglobal("SpellBookPageText")
    local titleText = getglobal("SpellBookTitleText") or getglobal("SpellBookFrameTitleText")

    if titleText then
        if shown then titleText:Show() else titleText:Hide() end
    end
    if prevButton then
        if shown then prevButton:Show() else prevButton:Hide() end
    end
    if nextButton then
        if shown then nextButton:Show() else nextButton:Hide() end
    end
    if pageText then
        if shown then pageText:Show() else pageText:Hide() end
    end
end

local function BookOfCommands_UpdatePage()
    local commands = BookOfCommands_GetMovementCommands()
    local total = table.getn(commands)
    totalPages = math.max(1, math.ceil(total / socketsPerPage))
    if currentPage > totalPages then
        currentPage = totalPages
    end

    local pageText = getglobal("Forged_Mangosbot_BookOfCommandsFramePageText")
    if pageText then
        pageText:SetText("Page " .. currentPage)
    end

    local prevButton = getglobal("Forged_Mangosbot_BookOfCommandsFramePrevPage")
    local nextButton = getglobal("Forged_Mangosbot_BookOfCommandsFrameNextPage")

    if prevButton then
        if currentPage > 1 then prevButton:Enable() else prevButton:Disable() end
    end
    if nextButton then
        if currentPage < totalPages then nextButton:Enable() else nextButton:Disable() end
    end

    -- Bind the movement commands to the sockets so clicking one runs
    -- it directly (action button behavior).
    local startIndex = (currentPage - 1) * socketsPerPage + 1
    local i
    for i = 1, table.getn(socketButtons) do
        local socket = socketButtons[i]
        local def = commands[startIndex + i - 1]

        if def then
            socket.def = def
            socket.icon:SetTexture(BookOfCommands_MacroTexture(def))
            socket.icon:Show()
            if socket.nameText then
                socket.nameText:SetText(def.label or def.tooltip or def.id or "")
            end
            -- Only filled sockets are interactive; re-enable mouse for them.
            socket:EnableMouse(true)
        else
            socket.def = nil
            socket.icon:SetTexture(nil)
            socket.icon:Hide()
            if socket.nameText then
                socket.nameText:SetText("")
            end
            -- Empty sockets must not be hoverable or clickable.
            socket:EnableMouse(false)
        end
    end
end

local function BookOfCommands_CreateSocket(parent, left, top, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width + 4)
    button:SetHeight(height + 4)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    -- Move the command button (hover area + icon) 12px left and 11px up from
    -- the slot; the slot background is counter-shifted below so it stays put.
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", left - 12, top + 11)

    -- Native spell buttons have a small hit box but a larger decorative slot art; match that look.
    -- (10, -10) shifts the decorative slot 1px left/up of its aligned position.
    button.slotBackground = button:CreateTexture(nil, "BACKGROUND")
    button.slotBackground:SetTexture("Interface\\Spellbook\\UI-Spellbook-SpellBackground")
    button.slotBackground:SetWidth(64)
    button.slotBackground:SetHeight(64)
    button.slotBackground:SetPoint("CENTER", button, "CENTER", 11, -10)

    -- The quickslot frame over the socket. In the spellbook (patch.MPQ's
    -- SpellBookFrame.xml) this is $parentNormalTexture = UI-Quickslot2, 64x64,
    -- centered, and it draws ABOVE the background but BELOW the icon (the icon is
    -- in the BORDER layer). Matching that here: BORDER layer so the crisp
    -- spellbackground stays visible and the icon renders on top, as in the game.
    button.emptySlot = button:CreateTexture(nil, "BORDER")
    button.emptySlot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.emptySlot:SetWidth(64)
    button.emptySlot:SetHeight(64)
    button.emptySlot:SetPoint("CENTER", button, "CENTER", 0, 1)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -1)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 2)
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    button.icon:Hide()

    -- Command label to the right of the slot, matching the native spellbook's
    -- spellname geometry exactly (read from SpellBookFrame.xml):
    --   font:        GameFontNormal
    --   size:        103 wide
    --   anchor:      LEFT of the text at the button's RIGHT, offset (4, 4)
    --   justifyH:    LEFT
    button.nameText = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    button.nameText:SetWidth(103)
    button.nameText:SetPoint("LEFT", button, "RIGHT", 4, 4)
    button.nameText:SetJustifyH("LEFT")
    button.nameText:SetText("")

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    button:SetScript("OnEnter", function()
        if this.def then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            -- Title in white (short command name, e.g. "Stay").
            GameTooltip:SetText(this.def.label or this.def.tooltip or this.def.id, 1, 1, 1)
            -- Description in yellow.
            GameTooltip:AddLine(this.def.tooltip or "", 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Action button: a single click issues the command directly. The group
    -- movement commands carry group=true, so they command the whole party.
    button:SetScript("OnClick", function()
        if arg1 ~= "LeftButton" then
            return
        end
        if this.def and type(ToolBarButtonOnClick) == "function" then
            ToolBarButtonOnClick(this.def, false)
        end
    end)

    -- Left-click and drag picks up a macro for the command so the player can
    -- drop it on an action bar. The macro is named after the command's label
    -- ("Follow" / "Stay").
    button:SetScript("OnDragStart", function()
        if this.def then
            BookOfCommands_PickUp(this.def)
        end
    end)

    return button
end

local function BookOfCommands_CreateMovementTab(parent)
    local tab = CreateFrame("CheckButton", nil, parent)
    tab:SetWidth(32)
    tab:SetHeight(32)
    tab:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -65)

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    tab.bg:SetWidth(64)
    tab.bg:SetHeight(64)
    tab.bg:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)

    -- Show the same icon as the native "General" skill-line section tab, so the
    -- Group Orders section tab matches the first section tab in the spellbook.
    -- Sized to match the native section tab (which is on the order of 24x24).
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetWidth(32)
    tab.icon:SetHeight(32)
    tab.icon:SetPoint("CENTER", tab, "CENTER", 0, 0)
    if type(GetSpellTabInfo) == "function" then
        local _, generalIcon = GetSpellTabInfo(1)
        if type(generalIcon) == "string" then
            tab.icon:SetTexture(generalIcon)
        end
    end

    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
    tab:SetChecked(true)

    tab.tooltipText = "Movement"

    tab:SetScript("OnEnter", function()
        local iconWidth = 0
        if this.icon and this.icon.GetWidth then
            iconWidth = this.icon:GetWidth() or 0
        end
        GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT", iconWidth, 0)
        GameTooltip:SetText(this.tooltipText)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    tab:SetScript("OnClick", function()
        this:SetChecked(true)
        currentPage = 1
        BookOfCommands_UpdatePage()
    end)

    return tab
end

local function BookOfCommands_BuildFrame()
    if bocFrame then
        return
    end

    local spellBookFrame = getglobal("SpellBookFrame")
    if not spellBookFrame then
        return
    end

    bocFrame = CreateFrame("Frame", "Forged_Mangosbot_BookOfCommandsFrame", spellBookFrame)
    bocFrame:SetAllPoints(spellBookFrame)
    bocFrame:Hide()

    local titleText = bocFrame:CreateFontString("Forged_Mangosbot_BookOfCommandsFrameTitleText", "ARTWORK", "GameFontNormal")
    titleText:SetPoint("TOP", bocFrame, "TOP", 0, -20)
    titleText:SetText("Group Orders")

    -- Match the native spellbook page indicator exactly (font, size and
    -- position). The native SpellBookPageText uses GameFontNormal, is 102 wide
    -- and is anchored to the bottom with offset x=-14 y=96.
    local pageText = bocFrame:CreateFontString("Forged_Mangosbot_BookOfCommandsFramePageText", "ARTWORK", "GameFontNormal")
    pageText:SetWidth(102)
    pageText:SetPoint("BOTTOM", bocFrame, "BOTTOM", -14, 96)

    local prevButton = CreateFrame("Button", "Forged_Mangosbot_BookOfCommandsFramePrevPage", bocFrame)
    prevButton:SetWidth(32)
    prevButton:SetHeight(32)
    prevButton:SetPoint("BOTTOMLEFT", bocFrame, "BOTTOMLEFT", 34, 89)
    prevButton:SetText("")
    prevButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    prevButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    prevButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    prevButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    prevButton:SetScript("OnClick", function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            BookOfCommands_UpdatePage()
        end
    end)

    local prevText = bocFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    prevText:SetPoint("LEFT", prevButton, "RIGHT", 0, 0)
    prevText:SetText("Prev")

    local nextButton = CreateFrame("Button", "Forged_Mangosbot_BookOfCommandsFrameNextPage", bocFrame)
    nextButton:SetWidth(32)
    nextButton:SetHeight(32)
    nextButton:SetPoint("BOTTOMRIGHT", bocFrame, "BOTTOMRIGHT", -54, 89)
    nextButton:SetText("")
    nextButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    nextButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    nextButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    nextButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    nextButton:SetScript("OnClick", function()
        if currentPage < totalPages then
            currentPage = currentPage + 1
            BookOfCommands_UpdatePage()
        end
    end)

    local nextText = bocFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nextText:SetPoint("RIGHT", nextButton, "LEFT", 0, 0)
    nextText:SetText("Next")

    bocTabContainer = CreateFrame("Frame", nil, bocFrame)
    bocTabContainer:SetAllPoints(bocFrame)
    movementTab = BookOfCommands_CreateMovementTab(bocTabContainer)

    local socketOffsetX = 10
    local socketOffsetY = -10

    local i
    for i = 1, socketsPerPage do
        local nativeButton = getglobal("SpellButton" .. i)
        local left, top, width, height = 28, -80 - ((i - 1) * 76), 36, 36

        if nativeButton and nativeButton.GetLeft and nativeButton:GetLeft() then
            left = nativeButton:GetLeft() - spellBookFrame:GetLeft()
            top = nativeButton:GetTop() - spellBookFrame:GetTop()
            width = nativeButton:GetWidth()
            height = nativeButton:GetHeight()
        end

        socketButtons[i] = BookOfCommands_CreateSocket(bocFrame, left + socketOffsetX, top + socketOffsetY, width, height)
    end

    BookOfCommands_UpdatePage()
end

function BookOfCommands.ShowNative()
    BookOfCommands_SetNativeSpellbookWidgetsShown(true)
    if bocFrame then
        bocFrame:Hide()
    end

    local spellBookFrame = getglobal("SpellBookFrame")
    if spellBookFrame and nativeTabId > 0 and type(PanelTemplates_SetTab) == "function" then
        spellBookFrame.selectedTab = nativeTabId
        PanelTemplates_SetTab(spellBookFrame, nativeTabId)
    end
end

function BookOfCommands.ShowBookOfCommands()
    BookOfCommands_BuildFrame()
    BookOfCommands_SetNativeSpellbookWidgetsShown(false)
    if bocFrame then
        bocFrame:Show()
    end
    BookOfCommands_UpdatePage()

    local spellBookFrame = getglobal("SpellBookFrame")
    if spellBookFrame and bocTabId > 0 and type(PanelTemplates_SetTab) == "function" then
        spellBookFrame.selectedTab = bocTabId
        PanelTemplates_SetTab(spellBookFrame, bocTabId)
    end
end

-- Same tab template already proven working for the FriendsFrame social tab in CompanionList.lua.
local spellbookTabTemplate = "FriendsFrameTabTemplate"

local function BookOfCommands_CreateTabButton(name, parent)
    local ok, tab = pcall(CreateFrame, "Button", name, parent, spellbookTabTemplate)
    if ok and tab then
        return tab
    end

    -- Template missing/incompatible on this client build; fall back to a manual tab button.
    tab = CreateFrame("Button", name, parent)
    tab:SetWidth(96)
    tab:SetHeight(32)
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)
    local text = tab:CreateFontString(name .. "Text", "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", tab, "CENTER", 0, 2)
    tab.text = text
    tab:SetScript("OnEnter", function()
        this.text:SetTextColor(1, 1, 1)
    end)
    tab:SetScript("OnLeave", function()
        this.text:SetTextColor(1, 0.82, 0)
    end)

    return tab
end

function BookOfCommands.SetupSpellbookTabs()
    if spellbookTabsInstalled then
        return true
    end

    local spellBookFrame = getglobal("SpellBookFrame")
    if not spellBookFrame then
        BookOfCommands_Print("Forged_Mangosbot: Book of Commands setup skipped, SpellBookFrame not found yet.")
        return false
    end

    local ok, err = pcall(function()
        BookOfCommands_BuildFrame()

        nativeTabId = 1
        bocTabId = 2

        nativeTab = BookOfCommands_CreateTabButton("SpellBookFrameTab1", spellBookFrame)
        nativeTab:SetID(nativeTabId)
        nativeTab:SetPoint("TOPLEFT", spellBookFrame, "BOTTOMLEFT", tabOffsetX, tabOffsetY)
        local nativeTabText = getglobal("SpellBookFrameTab1Text") or nativeTab.text
        if nativeTabText then
            nativeTabText:SetText("Spellbook")
        end
        if type(PanelTemplates_TabResize) == "function" then
            PanelTemplates_TabResize(0, nativeTab)
        end
        nativeTab:SetScript("OnClick", function()
            BookOfCommands.ShowNative()
        end)

        bocTab = BookOfCommands_CreateTabButton("SpellBookFrameTab2", spellBookFrame)
        bocTab:SetID(bocTabId)
        bocTab:SetPoint("LEFT", nativeTab, "RIGHT", -16, 0)
        local bocTabText = getglobal("SpellBookFrameTab2Text") or bocTab.text
        if bocTabText then
            bocTabText:SetText("Orders")
        end
        if type(PanelTemplates_TabResize) == "function" then
            PanelTemplates_TabResize(0, bocTab)
        end
        bocTab:SetScript("OnClick", function()
            BookOfCommands.ShowBookOfCommands()
        end)

        if type(PanelTemplates_SetNumTabs) == "function" then
            PanelTemplates_SetNumTabs(spellBookFrame, bocTabId)
        end
        if type(PanelTemplates_SetTab) == "function" then
            spellBookFrame.selectedTab = nativeTabId
            PanelTemplates_SetTab(spellBookFrame, nativeTabId)
        end
    end)

    if not ok then
        BookOfCommands_Print("Forged_Mangosbot: Book of Commands spellbook tabs failed to load: " .. tostring(err))
        return false
    end

    if type(SpellBookFrame_Update) == "function" and not spellbookUpdateHooked then
        local originalUpdate = SpellBookFrame_Update
        SpellBookFrame_Update = function()
            originalUpdate()
            if spellBookFrame.selectedTab == bocTabId then
                BookOfCommands_SetNativeSpellbookWidgetsShown(false)
                if bocFrame then
                    bocFrame:Show()
                end
            end
        end
        spellbookUpdateHooked = true
    end

    if not spellBookFrame._forgedBocOnShowHooked then
        local originalOnShow = spellBookFrame:GetScript("OnShow")
        spellBookFrame:SetScript("OnShow", function()
            if originalOnShow then
                originalOnShow()
            end
            if shouldRestoreOnShow then
                shouldRestoreOnShow = false
                BookOfCommands.ShowBookOfCommands()
            end
        end)
        spellBookFrame._forgedBocOnShowHooked = true
    end

    if not spellBookFrame._forgedBocOnHideHooked then
        local originalOnHide = spellBookFrame:GetScript("OnHide")
        spellBookFrame:SetScript("OnHide", function()
            shouldRestoreOnShow = (spellBookFrame.selectedTab == bocTabId)
            if originalOnHide then
                originalOnHide()
            end
        end)
        spellBookFrame._forgedBocOnHideHooked = true
    end

    spellbookTabsInstalled = true

    local nativeTab = getglobal("SpellBookFrameTab1")
    local w, h = 0, 0
    if nativeTab and nativeTab.GetWidth then
        w, h = nativeTab:GetWidth(), nativeTab:GetHeight()
    end
    BookOfCommands_Print("Forged_Mangosbot: Book of Commands spellbook tabs installed (tab size " .. w .. "x" .. h .. ").")

    return true
end

local bocEventFrame = CreateFrame("Frame")
bocEventFrame:RegisterEvent("PLAYER_LOGIN")
bocEventFrame:RegisterEvent("ADDON_LOADED")
bocEventFrame:SetScript("OnEvent", function()
    BookOfCommands.SetupSpellbookTabs()
end)

-- Safety net in case SpellBookFrame did not exist yet when the events above fired.
local spellBookFrameForHook = getglobal("SpellBookFrame")
if spellBookFrameForHook then
    local existingOnShow = spellBookFrameForHook:GetScript("OnShow")
    spellBookFrameForHook:SetScript("OnShow", function()
        BookOfCommands.SetupSpellbookTabs()
        if existingOnShow then
            existingOnShow()
        end
    end)
end

SLASH_FORGEDBOCDEBUG1 = "/fmbtabs"
SlashCmdList["FORGEDBOCDEBUG"] = function()
    local spellBookFrame = getglobal("SpellBookFrame")
    BookOfCommands_Print("Forged_Mangosbot: SpellBookFrame=" .. tostring(spellBookFrame ~= nil) ..
        " installed=" .. tostring(spellbookTabsInstalled) ..
        " tab1=" .. tostring(getglobal("SpellBookFrameTab1") ~= nil) ..
        " tab2=" .. tostring(getglobal("SpellBookFrameTab2") ~= nil))

    if spellBookFrame and nativeTab then
        BookOfCommands_Print(string.format(
            "Forged_Mangosbot: frame bottom=%.1f tab top=%.1f frame height=%.1f gap=%.1f",
            spellBookFrame:GetBottom() or 0,
            nativeTab:GetTop() or 0,
            spellBookFrame:GetHeight() or 0,
            (spellBookFrame:GetBottom() or 0) - (nativeTab:GetTop() or 0)))
    end

    if not spellbookTabsInstalled then
        BookOfCommands.SetupSpellbookTabs()
    end
end

-- Live reposition helper so the tab offset can be tuned without a UI reload.
SLASH_FORGEDBOCTABNUDGE1 = "/fmbtabsy"
SlashCmdList["FORGEDBOCTABNUDGE"] = function(msg)
    local dy = tonumber(msg)
    if not dy then
        BookOfCommands_Print("Forged_Mangosbot: usage /fmbtabsy <newYOffset>, current=" .. tabOffsetY)
        return
    end

    tabOffsetY = dy
    if nativeTab then
        nativeTab:ClearAllPoints()
        nativeTab:SetPoint("TOPLEFT", getglobal("SpellBookFrame"), "BOTTOMLEFT", tabOffsetX, tabOffsetY)
    end
    if bocTab then
        bocTab:ClearAllPoints()
        bocTab:SetPoint("LEFT", nativeTab, "RIGHT", -16, 0)
    end
    BookOfCommands_Print("Forged_Mangosbot: tab y offset set to " .. tabOffsetY)
end
