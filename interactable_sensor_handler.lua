---@diagnostic disable: undefined-global
-- InteractableSensorHandler
--
-- Purpose
--   Wraps the existing SensorHandler to support "press to activate" sensors.
--   These are defined in Tiled sensor layers and named like:
--     interactableSensor1, interactableSensor2, ... up to 999
--
-- Behavior
--   - A sensor is considered "inside" when the player overlaps it (like normal Sensors).
--   - It only returns true when you press a specific key while inside.
--   - The required key can be provided via a Tiled property "key" on the object
--     (e.g., key = "e"). If missing, any key passed to onPress will be accepted.
--
-- API
--   Interact.init(world, map, getPlayerFixtureFn, player?)
--     - Call after STI colliders are built (usually in Map:init after box2d_init).
--   Interact.beginContact(a, b), Interact.endContact(a, b)
--     - Wire to world:setCallbacks, in addition to SensorHandler’s begin/end.
--   Interact.isInside(name) -> boolean
--   Interact.getRequiredKey(name) -> string|nil
--   Interact.onPress(nameOrNumber, key) -> boolean
--     - Returns true once when pressed while inside. nameOrNumber can be
--       "interactableSensor7" or 7. Key is from love.keypressed.
--   Interact.any(key) -> name|nil
--     - Returns the first interactable sensor name that accepts this key while inside.
--   Interact.onEnter[name] / Interact.onExit[name] = function(name) ... end
--     - Optional callbacks when the player enters/exits an interactable sensor.

local Sensors = require('sensor_handler')

local Interact = {}
-- Ensure callback tables exist even before init so other modules can register
Interact._onEnter = Interact._onEnter or {}
Interact._onExit  = Interact._onExit  or {}
-- Expose public tables for registering callbacks early
Interact.onEnter = Interact._onEnter
Interact.onExit  = Interact._onExit

-- Read-only interface with sensor-like tables
local mt = {
  __index = function(t, k)
    if k == 'onEnter' then return rawget(t, '_onEnter') end
    if k == 'onExit' then return rawget(t, '_onExit') end
    -- Allow Interact.interactableSensorN boolean check
    local entry = rawget(t, '_entries')[k]
    return entry and (entry.count > 0) or false
  end,
  __newindex = function()
    error('InteractableSensorHandler is read-only; assign callbacks via onEnter/onExit tables', 2)
  end
}

-- Pattern for interactable sensor names
local function isInteractableName(name)
  return type(name) == 'string' and name:match('^interactableSensor%d+$') ~= nil
end

local function normalizeName(nameOrNumber)
  if type(nameOrNumber) == 'number' then
    return ('interactableSensor%d'):format(nameOrNumber)
  end
  return nameOrNumber
end

-- Internal helpers
local function isPlayerFixture(Interact, fix)
  local pf = Interact.getPlayerFixture and Interact.getPlayerFixture() or nil
  return pf and fix == pf
end

local function isSensorFixture(fix)
  return fix and fix.isSensor and fix:isSensor()
end

function Interact.init(world, map, getPlayerFixtureFn, player)
  Interact.world = world
  Interact.map = map
  Interact.getPlayerFixture = getPlayerFixtureFn or function()
    return player and player.physics and player.physics.fixture or nil
  end

  -- State
  Interact._entries = {}           -- [name] = { count = number, active = { [fixture]=true } }
  Interact._fixtureNames = {}      -- [fixture] = { [name]=true }
  Interact._keyByName = {}         -- [name] = 'e'|'f'|nil
  -- _onEnter/_onExit already exist from module load; keep references for safety
  Interact._onEnter = Interact._onEnter or {}
  Interact._onExit  = Interact._onExit  or {}
  -- Ensure public alias tables remain stable (in case someone keeps the reference)
  Interact.onEnter = Interact._onEnter
  Interact.onExit  = Interact._onExit
  setmetatable(Interact, mt)

  -- Discover fixtures from STI map: only those inside 'sensor'/'sensors' layers with our name pattern
  if map and map.box2d_collision then
    for _, c in ipairs(map.box2d_collision) do
      local fix = c.fixture
      local obj = c.object
      local layerName = obj and obj.layer and obj.layer.name
      if fix and layerName and (layerName == 'sensor' or layerName == 'sensors') then
        local oname = obj and obj.name
        if isInteractableName(oname) then
          -- Register name
          Interact._fixtureNames[fix] = Interact._fixtureNames[fix] or {}
          Interact._fixtureNames[fix][oname] = true
          Interact._entries[oname] = Interact._entries[oname] or { count = 0, active = {} }
          -- Extract required key from object properties if present
          local keyProp = nil
          if obj.properties and type(obj.properties.key) == 'string' then
            keyProp = obj.properties.key:lower()
          end
          Interact._keyByName[oname] = keyProp
          -- Ensure it’s a Box2D sensor
          fix:setSensor(true)
        end
      end
    end
  end
end

local function handleEnter(Interact, name)
  local cb = Interact._onEnter[name]
  if cb then cb(name) end
end

local function handleExit(Interact, name)
  local cb = Interact._onExit[name]
  if cb then cb(name) end
end

function Interact.beginContact(a, b)
  if not (isSensorFixture(a) or isSensorFixture(b)) then return end

  local function touch(fixSensor, fixOther)
    if not isPlayerFixture(Interact, fixOther) then return end
    local names = Interact._fixtureNames[fixSensor]
    if not names then return end
    for name, _ in pairs(names) do
      local entry = Interact._entries[name]
      if entry and not entry.active[fixSensor] then
        entry.active[fixSensor] = true
        local was = entry.count
        entry.count = entry.count + 1
        if was == 0 and entry.count == 1 then
          handleEnter(Interact, name)
        end
      end
    end
  end

  if isSensorFixture(a) then touch(a, b) end
  if isSensorFixture(b) then touch(b, a) end
end

function Interact.endContact(a, b)
  if not (isSensorFixture(a) or isSensorFixture(b)) then return end

  local function untouch(fixSensor, fixOther)
    if not isPlayerFixture(Interact, fixOther) then return end
    local names = Interact._fixtureNames[fixSensor]
    if not names then return end
    for name, _ in pairs(names) do
      local entry = Interact._entries[name]
      if entry and entry.active[fixSensor] then
        entry.active[fixSensor] = nil
        local was = entry.count
        entry.count = math.max(0, entry.count - 1)
        if was > 0 and entry.count == 0 then
          handleExit(Interact, name)
        end
      end
    end
  end

  if isSensorFixture(a) then untouch(a, b) end
  if isSensorFixture(b) then untouch(b, a) end
end

-- Query: is the player currently inside this interactable sensor?
function Interact.isInside(nameOrNumber)
  local name = normalizeName(nameOrNumber)
  local entry = Interact._entries[name]
  return entry and entry.count > 0 or false
end

-- Query the required key for a sensor (lowercase) or nil if any key is accepted
function Interact.getRequiredKey(nameOrNumber)
  return Interact._keyByName[normalizeName(nameOrNumber)]
end

-- Attempt to activate while inside: returns true on press if key matches (or any allowed)
function Interact.onPress(nameOrNumber, key)
  local name = normalizeName(nameOrNumber)
  local entry = Interact._entries[name]
  if not (entry and entry.count > 0) then return false end
  local need = Interact._keyByName[name]
  if need and type(key) == 'string' then
    return key:lower() == need
  else
    return key ~= nil -- any key considered valid if no specific key configured
  end
end

-- Return the first interactable sensor name that accepts this key (if player is inside), or nil
function Interact.any(key)
  for name, entry in pairs(Interact._entries) do
    if entry.count > 0 then
      local need = Interact._keyByName[name]
      if (need and type(key) == 'string' and key:lower() == need) or (not need and key ~= nil) then
        return name
      end
    end
  end
  return nil
end

return Interact
