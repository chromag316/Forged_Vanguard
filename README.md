# Forged_Mangosbot

Forged_Mangosbot is a World of Warcraft 1.12 addon (Interface 11200) that depends on Mangosbot and provides a Spellbook-style Book of Commands while extending Mangosbot's bot selection UX.

## Dependency

- Hard dependency: Mangosbot
- Expected sibling path: Interface/AddOns/Mangosbot/
- This repository can be scaffolded standalone, but it will no-op in-game unless Mangosbot is installed and enabled.

## Installation

1. Install Mangosbot into Interface/AddOns/Mangosbot.
2. Install this addon into Interface/AddOns/Forged_Mangosbot.
3. Enable both addons in the character selection addon list.
4. Log in and run /forgedbot to open the Book of Commands.

## What This Addon Does

- Loads after Mangosbot and uses Mangosbot globals without modifying Mangosbot source.
- Uses a single XML-defined main window path (no Lua fallback window construction).
- Hides Mangosbot roster/control frames while preserving Mangosbot logic.
- Builds command definitions from Mangosbot factory functions plus inline actions/inventory sets.
- Displays commands in a tabbed, paged icon book.
- Click execution uses Mangosbot ToolBarButtonOnClick behavior.
- Dragging a command creates or reuses a macro and places it on the cursor for action bars.

## Bot Selection and Portrait Menu

- Clicking a bot character no longer auto-opens Mangosbot's Selected Bot command window.
- Right-clicking the selected character portrait now includes a `Command` menu entry when the unit is recognized as a bot.
- Selecting `Command` opens Mangosbot's legacy Selected Bot command window on demand.
- The Forged Book of Commands is still available via `/forgedbot`, `/fmb`, and keybinds.

## Macro Slot Constraint (WoW 1.12)

WoW 1.12 action bars can only hold spells, items, or macros. Forged_Mangosbot therefore bridges command drags through macros:

- Macros are created lazily, only when a command is dragged.
- One macro is maintained per command id, not per companion.
- Macro body calls /script Forged_Mangosbot_Run("[id]") so the currently selected companion is resolved when the macro is clicked.
- Mapping of command id to macro name is stored in Forged_MangosbotMacroDB.
- Total macro budget is 36 (18 account-wide + 18 per-character). When full, the UI shows a clear warning prompt instead of failing silently.

## Companion Tab

The Companions tab reads the hidden Mangosbot BotRoster item widgets (name and class icon) on a light polling cycle and lets you pick the current companion by setting CurrentBot.

## Extending Categories

If upstream Mangosbot adds, removes, or renames toolbar factory functions:

1. Update Registry.lua factory harvest list.
2. Add or remove a category in BookOfCommands.lua.
3. Verify id stability format ([category].[key]) for macro reuse.
4. Keep actions/inventory inline tables synced with Mangosbot if those definitions change upstream.

## Icons

This addon reuses icon textures from Interface/Addons/Mangosbot/Images/*.tga and does not duplicate image files.
