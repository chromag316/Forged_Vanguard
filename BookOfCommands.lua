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
    local maxPage = math.max(1, totalPages)
    if currentPage > maxPage then
        currentPage = maxPage
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
        if currentPage < maxPage then nextButton:Enable() else nextButton:Disable() end
    end

    -- No command data is bound to Movement yet, so every socket renders empty.
    local i
    for i = 1, table.getn(socketButtons) do
        local socket = socketButtons[i]
        socket.icon:Hide()
    end
end

local function BookOfCommands_CreateSocket(parent, left, top, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", left, top)

    -- Native spell buttons have a small hit box but a larger decorative slot art; match that look.
    button.slotBackground = button:CreateTexture(nil, "BACKGROUND")
    button.slotBackground:SetTexture("Interface\\Spellbook\\UI-Spellbook-SpellBackground")
    button.slotBackground:SetWidth(64)
    button.slotBackground:SetHeight(64)
    button.slotBackground:SetPoint("CENTER", button, "CENTER", 0, 0)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    button.icon:Hide()

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

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

    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
    tab:SetChecked(true)

    tab.tooltipText = "Movement"

    tab:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
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
    titleText:SetText("Book of Commands")

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
            bocTabText:SetText("Commands")
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
