--[[
Shows the player's health as a bar with "current / max" above it, just over the
candy perk icons at the bottom of the screen. The bar is green above half
health, yellow above a quarter and red below.

Toggled with the healthbar dvar from the console: "set healthbar 0" hides it,
"set healthbar 1" shows it. It's on by default.

Health comes from the same PlayerHealth and PlayerMaxHealth watches the game's
own CP health meter uses (ui/ingame/cp/playerhealth.lua), so it needs nothing
from the server.
--]]

if Engine.InFrontend() then
    return
end

local WIDTH = 255
local BAR_BOTTOM = -72
local BAR_HEIGHT = 8
local TEXT_HEIGHT = 24
local TEXT_GAP = 4

local GREEN = 0x33CC33
local YELLOW = 0xE6CC1A
local RED = 0xE62626

--[[
The UI state survives going back to the menu and the script loads again on the
next map, sometimes twice. Each load closes the previous load's bar, kept in
this shared table, so only one is drawn. It's stored with rawget and rawset
since the UI's global table may reject new globals.
--]]
local state = rawget(_G, "healthbar_state")
if not state then
    state = {}
    rawset(_G, "healthbar_state", state)
end

local function log(message)
    print("healthbar_lui " .. message)
end

--[[
Replaces owner[name] with wrapper, which gets the function it replaced as its
first argument. It wraps whatever is there now, the game's function or another
script's hook, and never puts an older function back, so it can't drop a hook
another script added since. Copies from earlier loads of this script pass
straight through. When the last load's copy is still the one in place, it's
swapped out instead of wrapped, so reloads don't stack up.
--]]
local function hook(owner, name, wrapper)
    local key = "hook_" .. name
    local last = state[key]
    local original = owner[name]
    if last and last.installed == original then
        original = last.original
    end

    local entry = {
        original = original
    }
    entry.installed = function(...)
        if state[key] ~= entry then
            return original(...)
        end

        return wrapper(original, ...)
    end

    state[key] = entry
    owner[name] = entry.installed
end

--[[
Hidden while the game's HUD is: when its widgets were last hidden (see
hook_hud), and while the ui_hide_hud omnvar is set, which the game does during
the map intro. It's also hidden when the dvar turns it off.
--]]
local function visible()
    if Engine.GetDvarString("healthbar") == "0" then
        return false
    end

    local hide = Game.GetOmnvar("ui_hide_hud")
    if hide == true or hide == 1 then
        return false
    end

    if state.hud_shown == false then
        return false
    end

    return true
end

--[[
Builds the bar's visible parts once the first real max health arrives. When
they were built as the script started, while the map was loading, they only
showed up after pausing. Why isn't known: the guess is that the game doesn't
draw elements built that early until it rebuilds the HUD.
--]]
local function build_bar(holder)
    local bar = LUI.UIElement.new()
    bar:SetAnchorsAndPosition(0.5, 0.5, 1, 0, -WIDTH / 2, WIDTH / 2, BAR_BOTTOM - BAR_HEIGHT - TEXT_GAP - TEXT_HEIGHT, BAR_BOTTOM)
    holder:addElement(bar)

    local background = LUI.UIImage.new()
    background:SetAnchorsAndPosition(0, 0, 1, 0, 0, 0, -BAR_HEIGHT, 0)
    background:setImage(RegisterMaterial("white"))
    background:SetRGBFromInt(0x000000)
    background:SetAlpha(0.6)
    bar:addElement(background)

    local fill = LUI.UIImage.new()
    fill:SetAnchorsAndPosition(0, 1, 1, 0, 0, WIDTH, -BAR_HEIGHT, 0)
    fill:setImage(RegisterMaterial("white"))
    bar:addElement(fill)

    local text = LUI.UIText.new()
    text:SetAnchorsAndPosition(0, 0, 0, 1, 0, 0, 0, TEXT_HEIGHT)
    text:SetFont(FONTS.GetFont(FONTS.MainBold.File))
    text:SetAlignment(LUI.Alignment.Center)
    bar:addElement(text)

    return {
        bar = bar,
        fill = fill,
        text = text
    }
end

local function create_bar(root)
    local holder = LUI.UIElement.new()
    holder.id = "healthbar_holder"
    holder:SetAnchorsAndPosition(0, 0, 0, 0, 0, 0, 0, 0)
    root:addElement(holder)

    local parts
    local health, max_health

    local function update()
        if not health or not max_health or max_health <= 0 then
            if parts then
                parts.bar:SetAlpha(0)
            end

            return
        end

        if not parts then
            parts = build_bar(holder)
        end

        parts.bar:SetAlpha(visible() and 1 or 0)

        local fraction = math.max(0, math.min(health / max_health, 1))
        parts.fill:SetRight(WIDTH * fraction)
        parts.fill:SetAlpha(fraction > 0 and 1 or 0)

        if fraction > 0.5 then
            parts.fill:SetRGBFromInt(GREEN)
        elseif fraction > 0.25 then
            parts.fill:SetRGBFromInt(YELLOW)
        else
            parts.fill:SetRGBFromInt(RED)
        end

        parts.text:setText(math.max(health, 0) .. " / " .. max_health)
    end

    --[[
    One element per watch, since every int watch alert arrives as the same
    event and wouldn't say which value changed.
    --]]
    local function watch(name, set)
        local watcher = LUI.UIElement.new()
        holder:addElement(watcher)
        watcher:setupUIIntWatch(name)
        watcher:registerEventHandler("int_watch_alert", function(element, event)
            set(event.newValue)
            local ok, err = pcall(update)
            if not ok then
                log("update failed: " .. tostring(err))
            end
        end)
    end

    watch("PlayerHealth", function(value)
        health = value
    end)
    watch("PlayerMaxHealth", function(value)
        max_health = value
    end)

    state.refresh = function()
        local ok, err = pcall(update)
        if not ok then
            log("update failed: " .. tostring(err))
        end
    end

    holder:addElement(LUI.UITimer.new(nil, {
        interval = 100,
        event = "healthbar_toggle"
    }))
    holder:addEventHandler("healthbar_toggle", function()
        local ok, err = pcall(update)
        if not ok then
            log("update failed: " .. tostring(err))
        end
    end)

    return holder
end

--[[
The game's HUD hides its widgets through LUI.HUD.UpdateWidgetsVisibility, which
calls SetWidgetVisibility(hud, widget, animation, shown) for each widget when
a menu or the scoreboard opens or closes. The bar copies each batch: shown if
any widget was shown, hidden if they all were. A batch that runs inside another
counts towards the outer one.
--]]
local function hook_hud()
    local batch

    local function pack(...)
        return {
            n = select("#", ...),
            ...
        }
    end

    hook(LUI.HUD, "SetWidgetVisibility", function(original, hud, widget, animation, shown, ...)
        if batch then
            batch.calls = batch.calls + 1
            if shown then
                batch.shown = true
            end
        end

        return original(hud, widget, animation, shown, ...)
    end)

    hook(LUI.HUD, "UpdateWidgetsVisibility", function(original, ...)
        local outer = batch
        local mine = {
            calls = 0,
            shown = false
        }
        batch = mine
        local results = pack(pcall(original, ...))
        batch = outer

        if outer then
            outer.calls = outer.calls + mine.calls
            outer.shown = outer.shown or mine.shown
        elseif mine.calls > 0 then
            state.hud_shown = mine.shown
            if state.refresh then
                state.refresh()
            end
        end

        if not results[1] then
            error(results[2], 0)
        end

        return unpack(results, 2, results.n)
    end)
end

local function find_root()
    local root = Engine.GetLuiRoot()
    if not root and LUI.UIRoot and LUI.UIRoot.GetRootForControllerIndex then
        root = LUI.UIRoot.GetRootForControllerIndex(0)
    end

    if not root and LUI.roots then
        root = LUI.roots.UIRoot0
    end

    if not root then
        root = LUI.primaryRoot
    end

    return root
end

local started = false

local function start()
    local root = find_root()
    if not root then
        return false
    end

    started = true

    if (Engine.GetDvarString("healthbar") or "") == "" then
        Engine.ExecNow("set healthbar 1")
    end

    if state.holder then
        pcall(function()
            state.holder:close()
        end)
    end

    state.hud_shown = nil
    state.holder = create_bar(root)
    hook_hud()

    return true
end

local function try_start()
    if started then
        return
    end

    local ok, err = pcall(start)
    if not ok then
        started = true
        log("start failed: " .. tostring(err))
    end
end

try_start()

--[[
The UI root doesn't exist yet when scripts load in game, so start on the first
widget the HUD builds instead.
--]]
if not started then
    hook(MenuBuilder, "BuildRegisteredType", function(original, ...)
        local element = original(...)
        try_start()
        return element
    end)
end
