Forged_Mangosbot = Forged_Mangosbot or {}

local MainWindow = {}
Forged_Mangosbot.MainWindow = MainWindow

local frameName = "Forged_Mangosbot_BookOfCommandsFrame"
local frame = nil
local titleText = nil
local pageText = nil
local prevButton = nil
local nextButton = nil
local tabContainer = nil
local gridContainer = nil
local companionContainer = nil

local function MainWindow_Print(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

function MainWindow.GetFrame()
    return frame
end

function MainWindow.GetFrameName()
    return frameName
end

function MainWindow.GetCompanionContainer()
    return companionContainer
end

function MainWindow.GetGridContainer()
    return gridContainer
end

function MainWindow.GetTabContainer()
    return tabContainer
end

function MainWindow.SetTitle(text)
    if titleText and titleText.SetText then
        titleText:SetText(text or "")
    end
end

function MainWindow.SetPageText(text)
    if pageText and pageText.SetText then
        pageText:SetText(text or "")
    end
end

function MainWindow.SetPageButtonsEnabled(prevEnabled, nextEnabled)
    if prevButton then
        if prevEnabled then
            prevButton:Enable()
        else
            prevButton:Disable()
        end
    end

    if nextButton then
        if nextEnabled then
            nextButton:Enable()
        else
            nextButton:Disable()
        end
    end
end

function MainWindow.SetPageControlsVisible(visible)
    if pageText then
        if visible then
            pageText:Show()
        else
            pageText:Hide()
        end
    end

    if prevButton then
        if visible then
            prevButton:Show()
        else
            prevButton:Hide()
        end
    end

    if nextButton then
        if visible then
            nextButton:Show()
        else
            nextButton:Hide()
        end
    end
end

function MainWindow.Show()
    if not frame then
        MainWindow.Init()
    end

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

function MainWindow.Hide()
    if not frame then
        return
    end

    if type(HideUIPanel) == "function" then
        HideUIPanel(frame)
    else
        frame:Hide()
    end
end

function MainWindow.ApplySpellBookSize()
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

function MainWindow.ApplyLeftPanelPosition()
    if not frame then
        return
    end

    if frame.IsMovable and frame.SetUserPlaced and frame:IsMovable() then
        frame:SetUserPlaced(false)
    end
    frame:ClearAllPoints()

    if type(UIParent) == "table" then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function MainWindow.Init()
    if frame then
        return frame
    end

    frame = getglobal(frameName)
    if not frame then
        MainWindow_Print("Forged_Mangosbot: missing frame '" .. frameName .. "'.")
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
    MainWindow.ApplySpellBookSize()
    MainWindow.ApplyLeftPanelPosition()

    titleText = getglobal(frameName .. "Title")
    if titleText and titleText.SetFontObject then
        titleText:SetFontObject(GameFontNormal)
        titleText:ClearAllPoints()
        titleText:SetPoint("TOP", frame, "TOP", 6, -19)
    end

    pageText = getglobal(frameName .. "PageText")
    if pageText then
        pageText:SetFontObject(GameFontNormal)
        pageText:ClearAllPoints()
        pageText:SetPoint("BOTTOM", frame, "BOTTOM", -14, 96)
    end

    local closeButton = getglobal(frameName .. "Close")
    if closeButton then
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -9)
    end

    prevButton = getglobal(frameName .. "PrevPage")
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

    nextButton = getglobal(frameName .. "NextPage")
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

    tabContainer = getglobal(frameName .. "TabContainer")
    gridContainer = getglobal(frameName .. "GridContainer")
    companionContainer = getglobal(frameName .. "CompanionContainer")

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

    return frame
end
