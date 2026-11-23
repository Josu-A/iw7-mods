--[[
Draws the player's position in small text at the top centre of the screen: X
and Y, the ground axes, side by side, and Z, the height, centred underneath.

Toggled with the showorigin dvar from the console: "set showorigin 1" shows it,
"set showorigin 0" hides it. It's off by default.

The UI has no way to read the player's position, so
custom_scripts/cp/dev_show_origin.gsc sends it in the showorigin_pos dvar as
"x y z". The client crashes when the server sets a dvar it doesn't have, so
this script creates it as soon as it starts, and the server waits for it.
--]]

if Engine.InFrontend() then
    return
end

local TOP = 6
local LINE = 16
local WIDTH = 300
local GAP = 8

--[[
The UI state survives going back to the menu and the script loads again on the
next map, sometimes twice. Each load closes the previous load's text, kept in
this shared table, so only one is drawn. It's stored with rawget and rawset
since the UI's global table may reject new globals.
--]]
local state = rawget(_G, "showorigin_state")
if not state then
    state = {}
    rawset(_G, "showorigin_state", state)
end

local function log(message)
    print("showorigin_lui " .. message)
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
the map intro. It's also hidden unless the dvar turns it on.
--]]
local function visible()
    if Engine.GetDvarString("showorigin") ~= "1" then
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

local function add_text(parent, alignment, left_anchor, right_anchor, left, right, top)
    local text = LUI.UIText.new()
    text:SetAnchorsAndPosition(left_anchor, right_anchor, 0, 1, left, right, top, top + LINE)
    text:SetFont(FONTS.GetFont(FONTS.MainBold.File))
    text:SetAlignment(alignment)
    parent:addElement(text)
    return text
end

--[[
Builds the text once the first position arrives. Elements built as the script
starts, while the map is loading, only showed up after pausing in
ui_scripts/health_bar, so nothing visible is built that early.
--]]
local function build_text(holder)
    local box = LUI.UIElement.new()
    box:SetAnchorsAndPosition(0.5, 0.5, 0, 1, -WIDTH / 2, WIDTH / 2, TOP, TOP + LINE * 2)
    holder:addElement(box)

    return {
        box = box,
        x = add_text(box, LUI.Alignment.Right, 0, 0.5, 0, -GAP, 0),
        y = add_text(box, LUI.Alignment.Left, 0.5, 0, GAP, 0, 0),
        z = add_text(box, LUI.Alignment.Center, 0, 0, 0, 0, LINE)
    }
end

local function create_text(root)
    local holder = LUI.UIElement.new()
    holder.id = "showorigin_holder"
    holder:SetAnchorsAndPosition(0, 0, 0, 0, 0, 0, 0, 0)
    root:addElement(holder)

    local parts
    local last

    local function update()
        local position = Engine.GetDvarString("showorigin_pos") or ""
        local x, y, z = position:match("^(%-?%d+) (%-?%d+) (%-?%d+)$")
        if not x or not visible() then
            if parts then
                parts.box:SetAlpha(0)
            end

            return
        end

        if not parts then
            parts = build_text(holder)
        end

        parts.box:SetAlpha(1)

        if position ~= last then
            last = position
            parts.x:setText("X=" .. x)
            parts.y:setText("Y=" .. y)
            parts.z:setText("Z=" .. z)
        end
    end

    state.refresh = function()
        local ok, err = pcall(update)
        if not ok then
            log("update failed: " .. tostring(err))
        end
    end

    holder:addElement(LUI.UITimer.new(nil, {
        interval = 50,
        event = "showorigin_poll"
    }))
    holder:addEventHandler("showorigin_poll", state.refresh)

    return holder
end

--[[
The game's HUD hides its widgets through LUI.HUD.UpdateWidgetsVisibility, which
calls SetWidgetVisibility(hud, widget, animation, shown) for each widget when
a menu or the scoreboard opens or closes. The text copies each batch: shown if
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

    if (Engine.GetDvarString("showorigin") or "") == "" then
        Engine.ExecNow("set showorigin 0")
    end

    Engine.ExecNow("set showorigin_pos 0")

    if state.holder then
        pcall(function()
            state.holder:close()
        end)
    end

    state.hud_shown = nil
    state.holder = create_text(root)
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
