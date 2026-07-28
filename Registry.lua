Forged_Mangosbot = Forged_Mangosbot or {}

local Registry = {}
local registryEntries = {}

Forged_Mangosbot.Registry = Registry

local function Registry_Clear()
    for key in pairs(registryEntries) do
        registryEntries[key] = nil
    end
end

local function Registry_CopyDef(id, category, source)
    local def = {}
    local key, value
    for key, value in pairs(source) do
        if key == "command" and type(value) == "table" then
            def.command = {}
            local commandKey, commandValue
            for commandKey, commandValue in pairs(value) do
                def.command[commandKey] = commandValue
            end
        else
            def[key] = value
        end
    end

    def.id = id
    def.category = category
    if def.group == nil then
        def.group = false
    end

    return def
end

local function Registry_AddTable(category, source)
    if type(source) ~= "table" then
        return
    end

    local key, value
    for key, value in pairs(source) do
        if type(value) == "table" then
            local id = category .. "." .. key
            registryEntries[id] = Registry_CopyDef(id, category, value)
        end
    end
end

local function Registry_HarvestFactory(frame, category, factoryName)
    local factory = nil
    if type(getglobal) == "function" then
        factory = getglobal(factoryName)
    elseif type(_G) == "table" then
        factory = _G[factoryName]
    end

    if type(factory) ~= "function" then
        return
    end

    local harvested = factory(frame, 0, "ForgedHarvest_" .. category, false, 0, 0, false)
    Registry_AddTable(category, harvested)
end

local function Registry_GetInlineActions()
    return {
        ["stats"] = {
            icon = "stats",
            command = {[0] = "stats"},
            strategy = "",
            tooltip = "Tell stats (XP, bag space, money, durability)",
            index = 0
        },
        ["whisper"] = {
            icon = "whisper",
            command = {[0] = ""},
            tooltip = "Start whisper chat",
            strategy = "",
            handler = StartChat,
            index = 1
        },
        ["loot"] = {
            icon = "loot",
            command = {[0] = "d add all loot", [1] = "d loot"},
            strategy = "",
            tooltip = "Loot everything",
            index = 2
        },
        ["talk"] = {
            icon = "talk",
            command = {[0] = "talk", [1] = "accept *"},
            strategy = "",
            tooltip = "Talk to nearby NPCs to complete or accept quests",
            index = 3
        },
        ["set_guard"] = {
            icon = "set_guard",
            command = {[0] = "position guard set"},
            strategy = "",
            tooltip = "Set guard position",
            index = 4
        },
        ["release"] = {
            icon = "release",
            command = {[0] = "release"},
            strategy = "",
            tooltip = "Release spirit",
            index = 5
        },
        ["revive"] = {
            icon = "revive",
            command = {[0] = "revive", [1] = "d revive from corpse"},
            strategy = "",
            tooltip = "Revive at Spirit Healer",
            index = 6
        },
        ["sell"] = {
            icon = "sell",
            command = {[0] = "s *"},
            strategy = "",
            tooltip = "Sell grey items",
            index = 7
        },
        ["repair"] = {
            icon = "repair",
            command = {[0] = "repair"},
            strategy = "",
            tooltip = "Repair items",
            index = 8
        }
    }
end

local function Registry_GetInlineInventory()
    return {
        ["los"] = {
            icon = "los",
            command = {[0] = "los gos"},
            strategy = "",
            tooltip = "Show nearby game objects",
            index = 0
        },
        ["count"] = {
            icon = "count",
            command = {[0] = "c"},
            strategy = "",
            tooltip = "Show inventory",
            index = 1
        },
        ["bank"] = {
            icon = "bank",
            command = {[0] = "bank"},
            strategy = "",
            tooltip = "Show bank",
            index = 2
        },
        ["spells"] = {
            icon = "spells",
            command = {[0] = "spells +"},
            strategy = "",
            tooltip = "Show tradeskill",
            index = 3
        },
        ["equip"] = {
            icon = "equip",
            command = {[0] = "e ?"},
            strategy = "",
            tooltip = "Show equipment",
            index = 4
        },
        ["mail"] = {
            icon = "mail",
            command = {[0] = "mail ?"},
            strategy = "",
            tooltip = "Show mail",
            index = 4
        },
        ["help"] = {
            icon = "help",
            command = {[0] = "help"},
            strategy = "",
            tooltip = "Help",
            index = 5
        }
    }
end

function Registry.Build()
    Registry_Clear()

    if type(CreateFrame) ~= "function" then
        return
    end

    local scratch = CreateFrame("Frame", nil, UIParent)
    scratch:Hide()

    Registry_HarvestFactory(scratch, "movement", "CreateMovementToolBar")
    Registry_HarvestFactory(scratch, "formation", "CreateFormationToolBar")
    Registry_HarvestFactory(scratch, "stance", "CreateStanceToolBar")
    Registry_HarvestFactory(scratch, "non_combat", "CreateGenericNonCombatToolBar")
    Registry_HarvestFactory(scratch, "combat", "CreateGenericCombatToolBar")
    Registry_HarvestFactory(scratch, "save_mana", "CreateSaveManaToolBar")
    Registry_HarvestFactory(scratch, "rti", "CreateRtiToolBar")
    Registry_HarvestFactory(scratch, "rti_cc", "CreateRtiCcToolBar")

    Registry_AddTable("actions", Registry_GetInlineActions())
    Registry_AddTable("inventory", Registry_GetInlineInventory())
end

function Registry.GetAll()
    return registryEntries
end

function Registry.Get(id)
    if not id then
        return nil
    end
    return registryEntries[id]
end
