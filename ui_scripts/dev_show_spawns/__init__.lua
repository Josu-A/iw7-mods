--[[
Draws a wireframe cube on each zombie spawn point near the player, out of flat
UI squares placed in the world the way the game places its arcade scoreboards.
A cube floats just over its spawn point and is 12 squares, whose borders make
up its 12 edges: its 4 sides, top and bottom, each one twice, back to back,
since a square only shows from its front. The top and bottom are there because
a flat border seen edge-on vanishes, which left only the upright edges from
above. Nothing is spawned in the game for them.

custom_scripts/cp/dev_show_spawns.gsc picks the spawn points and writes their
positions as "x y z;x y z", split over the dvars showspawns_data1 and
showspawns_data2, 900 characters each. "set showspawns 1" turns the
cubes on, showspawns_size is their width, showspawns_thick their edges'
thickness and "set showspawns_xray 1" shows them through walls. The host's game
shares its dvars with the server, so this script reads what that one sets, and
only the host sees the cubes. The positions are cleared as this script starts:
left from the last map, they were drawn while the next one loaded.
--]]

if Engine.InFrontend() then
    return
end

--[[
SCALE is how many world units one UI unit covers. LIFT is how far over its
spawn point a cube floats, in world units, which keeps its bottom square out of
the ground.
--]]
local SCALE = 0.25
local LIFT = 1
local COLOR = 0xFFD000
local DATA_DVARS = 2

--[[
No cube is built while the UI has less memory free than this, which leaves the
game's own menus room to open. Running out restarts the whole UI.
--]]
local MIN_FREE_BYTES = 2097152

--[[
The most cubes drawn, 792 squares: the most seen working. With 100 cubes, 1,200
squares, the game dropped with "Requested a command not received" as soon as
they were built, whether or not anything was being sent to it.
custom_scripts/cp/dev_show_spawns.gsc picks no more than this.
--]]
local MAX_CUBES = 66

--[[
A cube's 12 squares: how each is turned and which way it's pushed out from the
cube's centre. A square at yaw 0 and roll 0 stands along the X axis, and roll
tips it over, so 90 lays it flat. Every square has a twin facing the other way:
a side's is turned 180 degrees, the top's and bottom's are rolled the other
way.
--]]
local FACES = {}
for _, side in ipairs({{
    yaw = 0,
    x = 0,
    y = -1
}, {
    yaw = 0,
    x = 0,
    y = 1
}, {
    yaw = 90,
    x = 1,
    y = 0
}, {
    yaw = 90,
    x = -1,
    y = 0
}}) do
    for _, turn in ipairs({0, 180}) do
        FACES[#FACES + 1] = {
            yaw = side.yaw + turn,
            roll = 0,
            x = side.x,
            y = side.y,
            z = 0
        }
    end
end

for _, z in ipairs({-1, 1}) do
    for _, roll in ipairs({-90, 90}) do
        FACES[#FACES + 1] = {
            yaw = 0,
            roll = roll,
            x = 0,
            y = 0,
            z = z
        }
    end
end

--[[
The UI state survives going back to the menu and the script loads again on the
next map, sometimes twice. Each load closes the previous load's cubes, kept in
this shared table, so only one set is drawn. It's stored with rawget and rawset
since the UI's global table may reject new globals.
--]]
local state = rawget(_G, "showspawns_state")
if not state then
    state = {}
    rawset(_G, "showspawns_state", state)
end

local function log(message)
    print("showspawns_lui " .. message)
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
Builds one square of a cube: a border in the world, width UI units wide and
thickness UI units thick. It's a single element. As a square holding 4 bars, 5
elements, 60 cubes made the whole UI restart over and over. With xray set it's
drawn over walls too. That's set as the square is built, the way the campaign's
ops map does it: changing it on a square already on screen did nothing.
--]]
local function build_face(holder, width, thickness, xray)
    local face = LUI.UIBorder.new({
        borderThicknessLeft = thickness,
        borderThicknessRight = thickness,
        borderThicknessTop = thickness,
        borderThicknessBottom = thickness
    })
    face:SetAnchorsAndPosition(0, 1, 0, 1, 0, width, 0, width)
    face:SetRGBFromInt(COLOR)
    face:SetupInWorldElement({})
    face:SetInWorldScale(SCALE)
    if xray then
        face:SetDepthTestEnabled(false)
    end

    holder:addElement(face)
    return face
end

local function build_cube(holder, size, thick, xray)
    local cube = {}
    for i = 1, #FACES do
        cube[i] = build_face(holder, size / SCALE, thick / SCALE, xray)
    end

    return cube
end

--[[
Moves a cube so it floats over (x, y, z), and shows it. Every square reaches
the cube's corners, so neighbours share their whole edge: with the top and
bottom set inside the cube, a hairline showed through where they met the sides.
--]]
local function place(cube, x, y, z, size)
    local half = size / 2
    for i, spot in ipairs(FACES) do
        local face = cube[i]
        face:SetWorldSpacePosition(x + spot.x * half, y + spot.y * half, z + LIFT + half + spot.z * half)
        face:SetWorldSpacePitch(0)
        face:SetWorldSpaceYaw(spot.yaw)
        face:SetWorldSpaceRoll(spot.roll)
        face:SetAlpha(1)
    end
end

local function hide(cube)
    for _, face in ipairs(cube) do
        face:SetAlpha(0)
    end
end

--[[
Draws the cubes whenever the positions or the dvars change. Cubes are built as
they're first needed and kept, then moved to the new positions; those left over
are hidden. They're only rebuilt when their size, thickness or x-ray changes.
When the UI is low on memory the cubes still missing are left out until the
positions next change. Nothing is built as the script starts: elements built
while the map is loading only showed up after pausing in
ui_scripts/health_bar.
--]]
local function create_cubes(root)
    local holder = LUI.UIElement.new()
    holder.id = "showspawns_holder"
    holder:SetAnchorsAndPosition(0, 0, 0, 0, 0, 0, 0, 0)
    root:addElement(holder)

    local cubes = {}
    local built_size
    local built_thick
    local built_xray
    local last
    local warned = false

    local function update()
        local on = (tonumber(Engine.GetDvarString("showspawns")) or 0) ~= 0
        local size = tonumber(Engine.GetDvarString("showspawns_size")) or 40
        local thick = tonumber(Engine.GetDvarString("showspawns_thick")) or 1
        local xray = Engine.GetDvarString("showspawns_xray") == "1"

        local parts = {}
        if on then
            for i = 1, DATA_DVARS do
                parts[i] = Engine.GetDvarString("showspawns_data" .. i) or ""
            end
        end

        local data = table.concat(parts, ";")
        local key = data .. "|" .. size .. "|" .. thick .. "|" .. tostring(xray)
        if key == last then
            return
        end

        if size ~= built_size or thick ~= built_thick or xray ~= built_xray then
            for _, cube in ipairs(cubes) do
                for _, face in ipairs(cube) do
                    face:close()
                end
            end

            cubes = {}
            built_size = size
            built_thick = thick
            built_xray = xray
            warned = false
        end

        last = key

        local count = 0
        local built = 0
        for x, y, z in data:gmatch("(%-?%d+) (%-?%d+) (%-?%d+)") do
            if count == MAX_CUBES then
                break
            end

            if not cubes[count + 1] then
                if Engine.GetBytesFree() < MIN_FREE_BYTES then
                    if not warned then
                        warned = true
                        log("UI memory is low, stopped at " .. count .. " cubes, " .. Engine.GetBytesFree() ..
                                " bytes free")
                    end

                    break
                end

                cubes[count + 1] = build_cube(holder, size, thick, xray)
                built = built + 1
            end

            count = count + 1
            place(cubes[count], tonumber(x), tonumber(y), tonumber(z), size)
        end

        for i = count + 1, #cubes do
            hide(cubes[i])
        end

        if built > 0 then
            log("built " .. built .. " cubes, " .. #cubes .. " in all, " .. Engine.GetBytesFree() .. " bytes free")
        end
    end

    holder:addElement(LUI.UITimer.new(nil, {
        interval = 100,
        event = "showspawns_poll"
    }))
    holder:addEventHandler("showspawns_poll", function()
        local ok, err = pcall(update)
        if not ok then
            log("update failed: " .. tostring(err))
        end
    end)

    return holder
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

    for i = 1, DATA_DVARS do
        Engine.ExecNow("set showspawns_data" .. i .. " none")
    end

    if state.holder then
        pcall(function()
            state.holder:close()
        end)
    end

    state.holder = create_cubes(root)

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
