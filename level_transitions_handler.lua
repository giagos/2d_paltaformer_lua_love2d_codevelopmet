---@diagnostic disable: undefined-global
-- level_transitions_handler.lua
-- Handles transitions between STI maps using rectangle objects in a layer named 'transitions'.
--
-- Rules
-- - In each map, add an Object Layer named 'transitions'.
-- - Add rectangle objects named transition1, transition2, ... transition999.
-- - This module will:
--   1) In the current map, find all transitions and make their fixtures sensors.
--   2) Scan all maps under 'tiled/map' for matching transition names and build a mapping
--      from name -> { mapPath, x, y } for the destination center.
--   3) When the player overlaps a transition and then exits it, switch to the destination map
--      and teleport the player to the paired rectangle center, preserving velocity.
--   4) Prevent immediate re-trigger by using a short cooldown after teleport.

local LevelTransitions = {}
LevelTransitions.__index = LevelTransitions

local function isSensorFixture(fix)
  return fix and fix.isSensor and fix:isSensor()
end

local function rectCenter(obj)
  local x, y, w, h = obj.x or 0, obj.y or 0, obj.width or 0, obj.height or 0
  return x + w / 2, y + h / 2
end

local function isTransitionName(name)
  return type(name) == 'string' and name:match('^transition%d+$') ~= nil
end

-- Load a Tiled map data table from path like 'tiled/map/1.lua'
local function loadMapData(path)
  local info = love.filesystem.getInfo(path)
  if not info or info.type ~= 'file' then return nil end
  local chunk, err = love.filesystem.load(path)
  if not chunk then
    print('[Transitions] Failed to load ' .. path .. ': ' .. tostring(err))
    return nil
  end
  local ok, res = pcall(chunk)
  if not ok then
    print('[Transitions] Error executing ' .. path .. ': ' .. tostring(res))
    return nil
  end
  return res
end

-- Normalize a map path input to a base like 'tiled/map/2' (without .lua)
local function normalizeMapBasePath(input)
  if not input then return nil end
  if type(input) == 'number' or (type(input) == 'string' and input:match('^%d+$')) then
    return 'tiled/map/' .. tostring(input)
  end
  local s = tostring(input)
  s = s:gsub('%.lua$', '')
  return s
end

-- Find the center of a transition rectangle by name within a specific map base path
local function findDestInMap(mapBasePath, name)
  local path = mapBasePath .. '.lua'
  local data = loadMapData(path)
  if not data or type(data.layers) ~= 'table' then return nil, nil end
  for _, layer in ipairs(data.layers) do
    if layer.type == 'objectgroup' and layer.name == 'transitions' and type(layer.objects) == 'table' then
      for _, obj in ipairs(layer.objects) do
        if obj.shape == 'rectangle' and obj.name == name then
          local cx, cy = rectCenter(obj)
          local o = { x = obj.x or 0, y = obj.y or 0, width = obj.width or 0, height = obj.height or 0 }
          return cx, cy, o
        end
      end
    end
  end
  return nil, nil, nil
end

-- Build a lookup of transition destinations across all maps in tiled/map
local function buildDestinationsIndex(currentMapPath)
  local index = {} -- name -> array of { mapPath, x, y }
  local dir = 'tiled/map'
  local files = love.filesystem.getDirectoryItems(dir)
  if not files or #files == 0 then
    print('[Transitions] No files found under ' .. dir)
  end
  for _, fname in ipairs(files) do
    if fname:match('%.lua$') then
      local path = dir .. '/' .. fname
      local mapdata = loadMapData(path)
      if type(mapdata) == 'table' and type(mapdata.layers) == 'table' then
        -- Find transitions layer
        local transitionsLayer = nil
        for _, layer in ipairs(mapdata.layers) do
          if layer.type == 'objectgroup' and layer.name == 'transitions' then
            transitionsLayer = layer
            break
          end
        end
        if transitionsLayer and type(transitionsLayer.objects) == 'table' then
          for _, obj in ipairs(transitionsLayer.objects) do
            if obj.shape == 'rectangle' and isTransitionName(obj.name) then
              local cx, cy = rectCenter(obj)
              index[obj.name] = index[obj.name] or {}
              table.insert(index[obj.name], {
                mapPath = path:gsub('%.lua$', ''),
                x = cx,
                y = cy,
                obj = { x = obj.x or 0, y = obj.y or 0, width = obj.width or 0, height = obj.height or 0 }
              })
            end
          end
        else
          --print('[Transitions] No transitions layer in ' .. path)
        end
      end
    end
  end

  -- Reduce to unique destination per name, excluding current map
  local reduced = {} -- name -> { mapPath, x, y } or nil if ambiguous
  local candidates = {} -- name -> array of { mapPath, x, y } excluding current map
  for name, list in pairs(index) do
    local unique = {}
    for _, e in ipairs(list) do
      if e.mapPath ~= currentMapPath then
        table.insert(unique, e)
      end
    end
    candidates[name] = unique
    if #unique == 1 then
      reduced[name] = unique[1]
    elseif #unique > 1 then
      print(string.format('[Transitions] Ambiguous destinations for %s: %d candidates, skipping', name, #unique))
      reduced[name] = nil
    end
    -- if 0, leave nil (no destination in other maps)
  end
  local count = 0
  for _ in pairs(reduced) do count = count + 1 end
  print(string.format('[Transitions] Destination index built: %d names', count))
  -- Attach candidates for debug UI
  reduced.__candidates = candidates
  reduced.__current = currentMapPath
  return reduced
end

-- Ensure transitions in current map are sensors and cache fixtures
local function collectCurrentTransitions(map)
  local fixturesByName = {} -- name -> { fixture, x, y }
  if not map or not map.box2d_collision then
    print('[Transitions] No map or no box2d_collision to collect transitions from')
    return fixturesByName
  end
  for _, c in ipairs(map.box2d_collision) do
    if c and c.fixture and c.object then
      local isTransLayer = (c.object.layer and c.object.layer.name == 'transitions')
      local name = c.object and c.object.name
      if isTransitionName(name) and c.object.shape == 'rectangle' and (isTransLayer or (c.object.layer == nil)) then
        -- Convert to sensor (non-solid)
        c.fixture:setSensor(true)
        -- Remember center position in case needed
        local cx, cy = rectCenter(c.object)
        fixturesByName[name] = fixturesByName[name] or {}
        fixturesByName[name].fixture = c.fixture
        fixturesByName[name].x = cx
        fixturesByName[name].y = cy
        fixturesByName[name].props = (c.object and c.object.properties) or {}
        fixturesByName[name].obj = { x = c.object.x or 0, y = c.object.y or 0, width = c.object.width or 0, height = c.object.height or 0 }
      end
    end
  end
  local n=0; for _ in pairs(fixturesByName) do n=n+1 end
  print(string.format('[Transitions] Current map transitions collected: %d', n))
  return fixturesByName
end

function LevelTransitions.init(world, map, getPlayerFixtureFn, switchLevelFn, currentMapPath)
  local self = setmetatable({}, LevelTransitions)
  self.world = world
  self.map = map
  self.getPlayerFixture = getPlayerFixtureFn
  self.switchLevel = switchLevelFn -- function(mapPath, x, y)
  self.currentMapPath = currentMapPath or ''

  self.current = collectCurrentTransitions(map)         -- name -> { fixture, x, y }
  self.destinations = buildDestinationsIndex(self.currentMapPath) -- name -> { mapPath, x, y }

  self.pending = nil  -- { name }
  self.cooldown = 0   -- seconds to ignore new triggers after switching
  self._queuedSwitch = nil -- { mapPath, x, y }
  self.arrivalLatch = false
  self.arrivalOverlaps = {} -- set of fixtures currently overlapping during arrival latch
  return self
end

function LevelTransitions:update(dt)
  if self.cooldown > 0 then
    self.cooldown = math.max(0, self.cooldown - dt)
  end
  -- Perform any queued map switch AFTER physics step (Map calls update after world:update)
  if self._queuedSwitch and self.switchLevel then
    local sw = self._queuedSwitch
    self._queuedSwitch = nil
    self.switchLevel(sw.mapPath, sw.x, sw.y)
    -- set a small cooldown to avoid immediate re-trigger on arrival
    self.cooldown = math.max(self.cooldown, 0.25)
    -- Engage arrival latch to suppress triggering until player exits all transition fixtures
    self.arrivalLatch = true
    self.arrivalOverlaps = {}
  end
end

-- External: when called (right after a map switch), suppress transitions until the player exits
function LevelTransitions:setArrivalLatch(flag)
  self.arrivalLatch = flag and true or false
  -- reset overlaps tracking whenever latch is set
  self.arrivalOverlaps = {}
end

local function isPlayerFixture(LevelTransitions, fix)
  local pf = LevelTransitions.getPlayerFixture and LevelTransitions.getPlayerFixture() or nil
  if not pf or not fix then return false end
  if fix == pf then return true end
  if pf.getBody and fix.getBody then
    local pbody = pf:getBody()
    local fbody = fix:getBody()
    return pbody ~= nil and fbody ~= nil and pbody == fbody
  end
  return false
end

-- World callbacks: call from map's beginContact/endContact
function LevelTransitions:beginContact(a, b)
  -- Ignore during cooldown
  if self.cooldown > 0 then return end
  local function touch(fixSensor, fixOther)
    if not isSensorFixture(fixSensor) then return end
    if not isPlayerFixture(self, fixOther) then return end
    -- If we just arrived in a new map, ignore any begin contacts until player exits
    if self.arrivalLatch then
      self.arrivalOverlaps[fixSensor] = true
      return
    end
    -- Is this a transition fixture?
    for name, entry in pairs(self.current) do
      if entry.fixture == fixSensor then
        -- Determine destination. First, per-object override via properties
        local props = entry.props or {}
        local overrideMap = props.destMap or props.dest or props.level or props.map
        local overrideName = props.destName or props.target or props.transition
        local switched = false
        if overrideMap and self.switchLevel then
          local mapBase = normalizeMapBasePath(overrideMap)
          local targetName = overrideName or name
          local dx, dy, dobj = findDestInMap(mapBase, targetName)
          if dx and dy then
            print(string.format('[Transitions] Override to %s at %s', tostring(mapBase), tostring(targetName)))
            -- Preserve player's vertical offset from source bottom edge to destination bottom edge
            local meter = love.physics.getMeter()
            local pfix = self.getPlayerFixture and self.getPlayerFixture() or nil
            local px, py = 0, 0
            if pfix and pfix.getBody then px, py = pfix:getBody():getPosition() end
            px, py = px * meter, py * meter
            local src = entry.obj or { x = entry.x, y = entry.y, width = 0, height = 0 }
            local srcBottom = (src.y or (entry.y or 0)) + (src.height or 0)
            local offset = (py - srcBottom)
            local dstBottom = (dobj and (dobj.y + dobj.height)) or dy
            local ny = dstBottom + offset
            self._queuedSwitch = { mapPath = mapBase, x = dx, y = ny }
            self.cooldown = 0.25
            self.pending = nil
            switched = true
          else
            -- If named destination not found in target map, still switch and keep player position
            print(string.format('[Transitions] Override map %s has no %s; switching without teleport coords', tostring(mapBase), tostring(targetName)))
            -- Use current entry.x/y as a fallback; destination coords may be off but better than nothing
            local fx, fy = entry.x, entry.y
            self._queuedSwitch = { mapPath = mapBase, x = fx, y = fy }
            self.cooldown = 0.25
            self.pending = nil
            switched = true
          end
        end
        if not switched then
          -- Fallback to cross-map index built from names
          local dest = self.destinations[name]
          if dest and self.switchLevel then
            -- Compute vertical offset from source bottom to destination bottom
            local meter = love.physics.getMeter()
            local pfix = self.getPlayerFixture and self.getPlayerFixture() or nil
            local px, py = 0, 0
            if pfix and pfix.getBody then px, py = pfix:getBody():getPosition() end
            px, py = px * meter, py * meter
            local src = entry.obj or { x = entry.x, y = entry.y, width = 0, height = 0 }
            local srcBottom = (src.y or (entry.y or 0)) + (src.height or 0)
            local offset = (py - srcBottom)
            local dst = dest.obj or { x = dest.x, y = dest.y, width = 0, height = 0 }
            local dstBottom = (dst.y or dest.y or 0) + (dst.height or 0)
            local ny = dstBottom + offset
            self._queuedSwitch = { mapPath = dest.mapPath, x = dest.x, y = ny }
            self.cooldown = 0.25
            self.pending = nil
          else
            print(string.format('[Transitions] No destination for %s', tostring(name)))
            -- Fall back to pending-exit path in case destination becomes available later
            self.pending = { name = name }
          end
        end
        break
      end
    end
  end
  touch(a, b)
  touch(b, a)
end

function LevelTransitions:endContact(a, b)
  -- If we're in arrival latch, track exits and clear latch when nothing overlaps
  if self.arrivalLatch then
    local function clearIfDone(fixSensor, fixOther)
      if not isSensorFixture(fixSensor) then return end
      if not isPlayerFixture(self, fixOther) then return end
      if self.arrivalOverlaps[fixSensor] then
        self.arrivalOverlaps[fixSensor] = nil
        -- check if set empty
        local any = false
        for _ in pairs(self.arrivalOverlaps) do any = true; break end
        if not any then
          self.arrivalLatch = false
        end
      end
    end
    clearIfDone(a, b)
    clearIfDone(b, a)
    return
  end

  if not self.pending then return end
  local name = self.pending.name
  local function untouch(fixSensor, fixOther)
    local entry = self.current[name]
    if not entry or entry.fixture ~= fixSensor then return end
    if not isPlayerFixture(self, fixOther) then return end
    -- Perform switch if we know the destination
    local dest = self.destinations[name]
    if dest and self.switchLevel then
      -- Queue switch; actual switch will run in update() after physics step
      self._queuedSwitch = { mapPath = dest.mapPath, x = dest.x, y = dest.y }
      self.cooldown = 0.25
    else
      print(string.format('[Transitions] No destination for %s', tostring(name)))
    end
    self.pending = nil
  end
  untouch(a, b)
  untouch(b, a)
end

return LevelTransitions
