---@diagnostic disable: undefined-global
-- SensorHandler: detects player overlap with named sensors from Tiled 'sensor' layer
-- Usage:
--   local Sensors = require('sensor_handler')
--   Sensors.init(world, map, getPlayerFixtureFn)
--   In beginContact/endContact: Sensors.beginContact(a,b), Sensors.endContact(a,b)
--   Query: if Sensors.sensor1 then ... end
--   Callbacks: Sensors.onEnter.sensor1 = function(fix) ... end; Sensors.onExit.sensor1 = function(fix) ... end

local Sensors = {}

local mt = {
    __index = function(t, k)
        if k == 'onEnter' then return rawget(t, '_onEnter') end
        if k == 'onExit' then return rawget(t, '_onExit') end
        local entry = rawget(t, '_entries')[k]
        return entry and (entry.count > 0) or false
    end,
    __newindex = function(t, k, v)
        -- Prevent arbitrary writes; only allow setting callbacks via onEnter/onExit subtables
        error("Sensors is read-only; use Sensors.onEnter[name] / onExit[name]", 2)
    end
}

local function isSensorFixture(fix)
    return fix and fix.isSensor and fix:isSensor()
end

local function getNameFromFixture(fix)
    local ud = fix and fix:getUserData()
    if type(ud) == 'table' then
        if ud.name then return ud.name end
        if ud.object and ud.object.name then return ud.object.name end
        -- allow property key like sensor1=true as a fallback
        if ud.properties then
            for k,v in pairs(ud.properties) do
                if v == true and tostring(k):match('^sensor%d+$') then return k end
            end
        end
    end
    return nil
end

local function markLayerObjectsAsSensors(map)
    if not map or not map.layers then return end
    for _, layer in ipairs(map.layers) do
        if layer.type == 'objectgroup' and (layer.name == 'sensor' or layer.name == 'sensors') then
            layer.properties = layer.properties or {}
            layer.properties.collidable = true
        end
    end
end

local function ensureFixturesAreSensors(map)
    if not map or not map.box2d_collision then return end
    for _, c in ipairs(map.box2d_collision) do
        if c and c.fixture then
            local ud = c.fixture:getUserData() or {}
            local isSensor = false
            local name = getNameFromFixture(c.fixture)
            if name then isSensor = true end
            if ud and ud.object and ud.object.layer and (ud.object.layer.name == 'sensor' or ud.object.layer.name == 'sensors') then
                isSensor = true
            end
            if isSensor then
                c.fixture:setSensor(true)
            end
        end
    end
end

local function defaultGetPlayerFixture(player)
    return player and player.physics and player.physics.fixture or nil
end

function Sensors.init(world, map, getPlayerFixtureFn, player)
    Sensors.world = world
    Sensors.map = map
    Sensors.getPlayerFixture = getPlayerFixtureFn or function() return defaultGetPlayerFixture(player) end
    Sensors._entries = {}
    Sensors._onEnter = {}
    Sensors._onExit = {}
    setmetatable(Sensors, mt)

    markLayerObjectsAsSensors(map)
    if map and map.box2d_init == nil and map.box2d_collision == nil then
        -- assume main already called map:box2d_init(world)
    end
    ensureFixturesAreSensors(map)

    -- Pre-register names from fixtures
    if map and map.box2d_collision then
        for _, c in ipairs(map.box2d_collision) do
            local name = getNameFromFixture(c.fixture)
            if name then
                Sensors._entries[name] = { count = 0, fixtures = Sensors._entries[name] and Sensors._entries[name].fixtures or {} }
                Sensors._entries[name].fixtures[c.fixture] = true
            end
        end
    end
end

local function isPlayerFixture(Sensors, fix)
    local pf = Sensors.getPlayerFixture and Sensors.getPlayerFixture() or nil
    return pf and fix == pf
end

local function handleEnter(name)
    local cb = Sensors._onEnter[name]
    if cb then cb(name) end
end

local function handleExit(name)
    local cb = Sensors._onExit[name]
    if cb then cb(name) end
end

function Sensors.beginContact(a, b)
    -- Ignore non-sensor contacts
    if not (isSensorFixture(a) or isSensorFixture(b)) then return end

    local nameA = getNameFromFixture(a)
    local nameB = getNameFromFixture(b)

    if nameA and isPlayerFixture(Sensors, b) then
        local entry = Sensors._entries[nameA] or { count = 0, fixtures = {} }
        Sensors._entries[nameA] = entry
        if entry.fixtures[a] == nil then entry.fixtures[a] = true end
        entry.count = entry.count + 1
        handleEnter(nameA)
    elseif nameB and isPlayerFixture(Sensors, a) then
        local entry = Sensors._entries[nameB] or { count = 0, fixtures = {} }
        Sensors._entries[nameB] = entry
        if entry.fixtures[b] == nil then entry.fixtures[b] = true end
        entry.count = entry.count + 1
        handleEnter(nameB)
    end
end

function Sensors.endContact(a, b)
    if not (isSensorFixture(a) or isSensorFixture(b)) then return end

    local nameA = getNameFromFixture(a)
    local nameB = getNameFromFixture(b)

    if nameA and Sensors._entries[nameA] and Sensors._entries[nameA].fixtures[a] and isPlayerFixture(Sensors, b) then
        local entry = Sensors._entries[nameA]
        entry.count = math.max(0, entry.count - 1)
        if entry.count == 0 then handleExit(nameA) end
    elseif nameB and Sensors._entries[nameB] and Sensors._entries[nameB].fixtures[b] and isPlayerFixture(Sensors, a) then
        local entry = Sensors._entries[nameB]
        entry.count = math.max(0, entry.count - 1)
        if entry.count == 0 then handleExit(nameB) end
    end
end

return Sensors
