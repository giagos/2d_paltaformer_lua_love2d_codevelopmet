---@diagnostic disable: undefined-global
-- SensorHandler
--
-- Purpose
--   Centralized trigger/sensor management for Tiled object layers named "sensor" or "sensors".
--   - Forces any fixture originating from those layers to be a Box2D sensor (non-solid).
--   - Supports named sensors via either object.name = "sensorN" or custom properties sensorN=true.
--   - Tracks player overlap with each named sensor and exposes a simple API:
--       - Query:    if Sensors.sensor1 then ... end
--       - Callbacks: Sensors.onEnter.sensor1 = function(name) ... end
--                    Sensors.onExit.sensor1  = function(name) ... end
--
-- Integration (typical flow)
--   1) map = sti('tiled/map/..', {'box2d'})
--   2) world = love.physics.newWorld(...)
--   3) map:box2d_init(world)
--   4) Sensors.init(world, map, function() return player.physics.fixture end)
--   5) In world callbacks: Sensors.beginContact(a,b), Sensors.endContact(a,b)
--
-- Notes
--   - Even if a sensor object does not have a sensorN flag, being in the sensor layer is enough to
--     make it non-solid (Box2D sensor). Named flags are only required if you want to query it by name
--     or receive onEnter/onExit events for that specific sensor.
--   - This module is read-only from the outside; use the provided callback tables to hook behavior.

local Sensors = {}

-- Layer names treated as sensor layers
local SENSOR_LAYER_NAMES = {
    sensor = true,
    sensors = true,
}

-- Metatable allows: Sensors.sensor1 → boolean, and exposes callbacks via Sensors.onEnter/onExit
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

-- Helper: is this fixture a Box2D sensor (non-solid)?
local function isSensorFixture(fix)
    return fix and fix.isSensor and fix:isSensor()
end

-- Collects sensor names from a fixture's userdata table.
-- Priority: object.name matching ^sensor%d+$, then properties.sensorN == true
local function collectNamesFromUD(ud)
    local names = {}
    if not ud then return names end
    -- object.name preferred if it matches sensor pattern
    local oname = (ud.name) or (ud.object and ud.object.name)
    if type(oname) == 'string' and oname:match('^sensor%d+$') then
        names[oname] = true
    end
    -- properties like sensor1=true, sensor2=true
    if type(ud.properties) == 'table' then
        for k, v in pairs(ud.properties) do
            if v == true and type(k) == 'string' and k:match('^sensor%d+$') then
                names[k] = true
            end
        end
    end
    return names
end

local function getNamesFromFixture(fix)
    local ud = fix and fix:getUserData()
    if type(ud) ~= 'table' then return {} end
    return collectNamesFromUD(ud)
end

-- Ensure sensor layers are treated as collidable by STI so fixtures are created at all.
-- This should ideally run before map:box2d_init(world). If called after, it's harmless.
local function markLayerObjectsAsSensors(map)
    if not map or not map.layers then return end
    for _, layer in ipairs(map.layers) do
        if layer.type == 'objectgroup' and SENSOR_LAYER_NAMES[layer.name] then
            layer.properties = layer.properties or {}
            layer.properties.collidable = true
        end
    end
end

-- After STI has created fixtures, convert appropriate ones into Box2D sensors (non-solid).
-- Rules:
--   1) Any object inside a layer named 'sensor' or 'sensors' becomes a sensor.
--   2) Any object with userdata.properties.sensor == true becomes a sensor.
--   3) Any object with one or more properties matching sensorN = true becomes a sensor.
-- The fixture's userdata.properties.sensor is set to true to reflect this.
local function ensureFixturesAreSensors(map)
    if not map or not map.box2d_collision then return end
    for _, c in ipairs(map.box2d_collision) do
        if c and c.fixture then
            local ud = c.fixture:getUserData() or {}
            local isSensor = false

            -- 1) Layer rule: any object inside 'sensor'/'sensors' layer is a sensor
            local inSensorLayer = (c.object and c.object.layer and SENSOR_LAYER_NAMES[c.object.layer.name]) or false
            if inSensorLayer then isSensor = true end

            -- 2) Explicit physics property 'sensor=true'
            if ud.properties and ud.properties.sensor == true then
                isSensor = true
            end

            -- 3) Any sensorN=true properties indicate trigger intent
            local names = collectNamesFromUD(ud)
            for _ in pairs(names) do isSensor = true break end

            if isSensor then
                c.fixture:setSensor(true)
                -- Reflect in userdata so other systems reading properties can see sensor=true
                ud.properties = ud.properties or {}
                if ud.properties.sensor ~= true then
                    ud.properties.sensor = true
                end
                c.fixture:setUserData(ud)
            end
        end
    end
end

-- Default player fixture accessor; can be overridden in init()
local function defaultGetPlayerFixture(player)
    return player and player.physics and player.physics.fixture or nil
end

-- Initialize the sensor system.
-- world: Box2D world (unused currently but kept for future extensions)
-- map:   STI map (must have had map:box2d_init(world) called already)
-- getPlayerFixtureFn: () -> fixture (returns the player's main body fixture)
-- player: optional player reference if using default accessor
function Sensors.init(world, map, getPlayerFixtureFn, player)
    Sensors.world = world
    Sensors.map = map
    Sensors.getPlayerFixture = getPlayerFixtureFn or function() return defaultGetPlayerFixture(player) end
    Sensors._entries = {}       -- [name] = { count = number, active = { [fixture]=true, ... } }
    Sensors._onEnter = {}       -- [name] = function(name) ... end
    Sensors._onExit  = {}       -- [name] = function(name) ... end
    Sensors._fixtureNames = {}  -- [fixture] = { [name]=true, ... }
    setmetatable(Sensors, mt)

    markLayerObjectsAsSensors(map)
    if map and map.box2d_init == nil and map.box2d_collision == nil then
        -- assume main already called map:box2d_init(world)
    end
    ensureFixturesAreSensors(map)

    -- Pre-register names from fixtures
    if map and map.box2d_collision then
        for _, c in ipairs(map.box2d_collision) do
            local fix = c.fixture
            local names = getNamesFromFixture(fix)
            if next(names) ~= nil then
                Sensors._fixtureNames[fix] = names
                for name, _ in pairs(names) do
                    Sensors._entries[name] = Sensors._entries[name] or { count = 0, active = {} }
                end
            end
        end
    end
end

-- Internal: does this fixture belong to the player?
local function isPlayerFixture(Sensors, fix)
    local pf = Sensors.getPlayerFixture and Sensors.getPlayerFixture() or nil
    return pf and fix == pf
end

-- Fire enter/exit callbacks if defined
local function handleEnter(name)
    local cb = Sensors._onEnter[name]
    if cb then cb(name) end
end

local function handleExit(name)
    local cb = Sensors._onExit[name]
    if cb then cb(name) end
end

-- World callback: beginContact
-- Called from love.physics world:setCallbacks. Updates per-sensor state when the player
-- begins overlapping a sensor fixture. Triggers onEnter when count transitions 0 -> 1.
function Sensors.beginContact(a, b)
    -- Ignore non-sensor contacts
    if not (isSensorFixture(a) or isSensorFixture(b)) then return end

    local function touch(fixSensor, fixOther)
        if not isPlayerFixture(Sensors, fixOther) then return end
        local names = Sensors._fixtureNames[fixSensor] or getNamesFromFixture(fixSensor)
        if next(names) == nil then return end
        -- cache mapping if discovered late
        Sensors._fixtureNames[fixSensor] = names
        for name, _ in pairs(names) do
            Sensors._entries[name] = Sensors._entries[name] or { count = 0, active = {} }
            local entry = Sensors._entries[name]
            if not entry.active[fixSensor] then
                entry.active[fixSensor] = true
                local was = entry.count
                entry.count = entry.count + 1
                if was == 0 and entry.count == 1 then
                    handleEnter(name)
                end
            end
        end
    end

    if isSensorFixture(a) then touch(a, b) end
    if isSensorFixture(b) then touch(b, a) end
end

-- World callback: endContact
-- Called from love.physics world:setCallbacks. Updates per-sensor state when the player
-- stops overlapping a sensor fixture. Triggers onExit when count transitions 1 -> 0.
function Sensors.endContact(a, b)
    if not (isSensorFixture(a) or isSensorFixture(b)) then return end

    local function untouch(fixSensor, fixOther)
        if not isPlayerFixture(Sensors, fixOther) then return end
        local names = Sensors._fixtureNames[fixSensor]
        if not names then return end
        for name, _ in pairs(names) do
            local entry = Sensors._entries[name]
            if entry and entry.active[fixSensor] then
                entry.active[fixSensor] = nil
                local was = entry.count
                entry.count = math.max(0, entry.count - 1)
                if was > 0 and entry.count == 0 then
                    handleExit(name)
                end
            end
        end
    end

    if isSensorFixture(a) then untouch(a, b) end
    if isSensorFixture(b) then untouch(b, a) end
end

return Sensors
