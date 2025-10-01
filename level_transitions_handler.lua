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
--      from name -> { mapPath, x, y } for the destination.
--   3) When the player enters a transition, immediately switch to the destination map
--      and teleport the player to the appropriate side of the destination transition box.
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

  self.cooldown = 0   -- seconds to ignore new triggers after switching
  self._queuedSwitch = nil -- { mapPath, x, y }
  
  -- Commented out exit-based system
  --self.pending = nil  -- { name }
  --self.arrivalLatch = false
  --self.arrivalOverlaps = {} -- set of fixtures currently overlapping during arrival latch
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
  end
end

-- Commented out arrival latch system (no longer needed for immediate transitions)
--[[
-- External: when called (right after a map switch), suppress transitions until the player exits
function LevelTransitions:setArrivalLatch(flag)
  self.arrivalLatch = flag and true or false
  -- reset overlaps tracking whenever latch is set
  self.arrivalOverlaps = {}
end
--]]

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

-- Helper to get world points without relying on unpack/table.unpack (Lua version agnostic)
local function getWorldPointsExpanded(body, pts)
  local n = #pts
  if n == 2 then return body:getWorldPoints(pts[1], pts[2]) end
  if n == 4 then return body:getWorldPoints(pts[1], pts[2], pts[3], pts[4]) end
  if n == 6 then return body:getWorldPoints(pts[1], pts[2], pts[3], pts[4], pts[5], pts[6]) end
  if n == 8 then return body:getWorldPoints(pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[7], pts[8]) end
  if n == 10 then return body:getWorldPoints(pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[7], pts[8], pts[9], pts[10]) end
  if n == 12 then return body:getWorldPoints(pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[7], pts[8], pts[9], pts[10], pts[11], pts[12]) end
  if n == 14 then return body:getWorldPoints(pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[7], pts[8], pts[9], pts[10], pts[11], pts[12], pts[13], pts[14]) end
  if n == 16 then return body:getWorldPoints(pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[7], pts[8], pts[9], pts[10], pts[11], pts[12], pts[13], pts[14], pts[15], pts[16]) end
  -- Fallback: no points
  return nil
end

-- Compute an axis-aligned bounding box (AABB) for a fixture in pixel coordinates
local function getFixtureAABBInPixels(fix)
  if not fix or not fix.getShape or not fix.getBody then return nil end
  local shape = fix:getShape()
  if not shape then return nil end
  local body = fix:getBody()
  local meter = love.physics.getMeter()

  local stype = (shape.getType and shape:getType()) or nil
  if stype == 'circle' and shape.getRadius then
    local cx, cy = body:getPosition()
    local r = shape:getRadius()
    cx, cy, r = cx * meter, cy * meter, r * meter
    return cx - r, cy - r, cx + r, cy + r
  end

  -- For polygon/edge/chain, get world points and compute bounds
  if shape.getPoints and body.getWorldPoints then
    local pts = { shape:getPoints() }
    if #pts >= 2 then
      local wpts = { getWorldPointsExpanded(body, pts) }
      local minX, minY = math.huge, math.huge
      local maxX, maxY = -math.huge, -math.huge
      for i = 1, #wpts, 2 do
        local x, y = wpts[i] * meter, wpts[i + 1] * meter
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
      end
      return minX, minY, maxX, maxY
    end
  end

  -- Fallback: use body position with a default 16px half-extent
  local bx, by = body:getPosition()
  bx, by = bx * meter, by * meter
  return bx - 16, by - 16, bx + 16, by + 16
end

-- Get half extents (half-width, half-height) of fixture in pixels
local function getFixtureHalfExtents(fix)
  local minX, minY, maxX, maxY = getFixtureAABBInPixels(fix)
  if not minX then return 16, 16 end
  local hw = (maxX - minX) * 0.5
  local hh = (maxY - minY) * 0.5
  return hw, hh
end

-- Determine if a transition rectangle should be treated as horizontal (left/right) or vertical (up/down)
-- Per spec: height > width -> horizontal transition, width > height -> vertical transition
local function isHorizontalTransitionRect(obj)
  local w = (obj and obj.width) or 0
  local h = (obj and obj.height) or 0
  return h > w
end

-- Horizontal transition placement (left/right)
local function calculateSpawnPositionHorizontal(playerX, playerY, sourceObj, destObj, playerHalfWidth)
  playerHalfWidth = playerHalfWidth or 16
  local srcLeft = sourceObj.x
  local srcCenterX = sourceObj.x + sourceObj.width / 2
  local srcBottom = sourceObj.y + sourceObj.height
  local dstLeft = destObj.x
  local dstRight = destObj.x + destObj.width
  local dstBottom = destObj.y + destObj.height

  local verticalOffset = playerY - srcBottom
  local enteredFromRight = playerX > srcCenterX
  local spawnY = dstBottom + verticalOffset
  local gap = 1
  local spawnX
  if enteredFromRight then
    spawnX = (dstLeft - gap) - playerHalfWidth
  else
    spawnX = (dstRight + gap) + playerHalfWidth
  end
  return spawnX, spawnY
end

-- Vertical transition placement (up/down)
local function calculateSpawnPositionVertical(playerX, playerY, sourceObj, destObj, playerHalfWidth, playerHalfHeight)
  playerHalfWidth = playerHalfWidth or 16
  playerHalfHeight = playerHalfHeight or 16
  local srcLeft = sourceObj.x
  local srcCenterY = sourceObj.y + sourceObj.height / 2
  local dstLeft = destObj.x
  local dstTop = destObj.y
  local dstBottom = destObj.y + destObj.height

  -- Preserve horizontal offset from source left edge
  local horizontalOffset = playerX - srcLeft
  -- Clamp offset to stay within destination rectangle, leaving a tiny gap to edges
  local gap = 1
  local minOffset = playerHalfWidth + gap
  local maxOffset = math.max(minOffset, (destObj.width or 0) - playerHalfWidth - gap)
  horizontalOffset = math.max(minOffset, math.min(horizontalOffset, maxOffset))

  local enteredFromBelow = playerY > srcCenterY
  local spawnX = dstLeft + horizontalOffset
  local spawnY
  if enteredFromBelow then
    -- Coming from below, appear just above the destination top edge
    spawnY = (dstTop - gap) - playerHalfHeight
  else
    -- Coming from above, appear just below the destination bottom edge
    spawnY = (dstBottom + gap) + playerHalfHeight
  end
  return spawnX, spawnY
end

-- Decide between horizontal/vertical and compute spawn position accordingly
local function calculateSpawnPosition(playerX, playerY, sourceObj, destObj, playerHalfWidth, playerHalfHeight)
  if isHorizontalTransitionRect(sourceObj) then
    return calculateSpawnPositionHorizontal(playerX, playerY, sourceObj, destObj, playerHalfWidth)
  else
    return calculateSpawnPositionVertical(playerX, playerY, sourceObj, destObj, playerHalfWidth, playerHalfHeight)
  end
end

-- World callbacks: call from map's beginContact/endContact
function LevelTransitions:beginContact(a, b)
  -- Ignore during cooldown
  if self.cooldown > 0 then return end
  local function touch(fixSensor, fixOther)
    if not isSensorFixture(fixSensor) then return end
    if not isPlayerFixture(self, fixOther) then return end
    
    -- Is this a transition fixture?
    for name, entry in pairs(self.current) do
      if entry.fixture == fixSensor then
        -- Get player position for spawn calculation
        local meter = love.physics.getMeter()
        local pfix = self.getPlayerFixture and self.getPlayerFixture() or nil
        local px, py = 0, 0
        if pfix and pfix.getBody then px, py = pfix:getBody():getPosition() end
        px, py = px * meter, py * meter
        
        -- Determine destination. First, per-object override via properties
        local props = entry.props or {}
        local overrideMap = props.destMap or props.dest or props.level or props.map
        local overrideName = props.destName or props.target or props.transition
        local switched = false
        
        if overrideMap and self.switchLevel then
          local mapBase = normalizeMapBasePath(overrideMap)
          local targetName = overrideName or name
          local dx, dy, dobj = findDestInMap(mapBase, targetName)
          if dx and dy and dobj then
            print(string.format('[Transitions] Override to %s at %s', tostring(mapBase), tostring(targetName)))
            -- Calculate spawn position based on entry direction
            local src = entry.obj or { x = entry.x, y = entry.y, width = 0, height = 0 }
            local halfW, halfH = 16, 16
            if pfix and pfix.getShape then
              local hw, hh = getFixtureHalfExtents(pfix)
              if hw then halfW = hw end
              if hh then halfH = hh end
            end
            local spawnX, spawnY = calculateSpawnPosition(px, py, src, dobj, halfW, halfH)
            self._queuedSwitch = { mapPath = mapBase, x = spawnX, y = spawnY }
            self.cooldown = 0.25
            switched = true
          else
            -- If named destination not found in target map, still switch using center position
            print(string.format('[Transitions] Override map %s has no %s; switching to center', tostring(mapBase), tostring(targetName)))
            local fx, fy = entry.x, entry.y
            self._queuedSwitch = { mapPath = mapBase, x = fx, y = fy }
            self.cooldown = 0.25
            switched = true
          end
        end
        
        if not switched then
          -- Fallback to cross-map index built from names
          local dest = self.destinations[name]
          if dest and self.switchLevel then
            -- Calculate spawn position based on entry direction
            local src = entry.obj or { x = entry.x, y = entry.y, width = 0, height = 0 }
            local dst = dest.obj or { x = dest.x, y = dest.y, width = 0, height = 0 }
            local halfW, halfH = 16, 16
            if pfix and pfix.getShape then
              local hw, hh = getFixtureHalfExtents(pfix)
              if hw then halfW = hw end
              if hh then halfH = hh end
            end
            local spawnX, spawnY = calculateSpawnPosition(px, py, src, dst, halfW, halfH)
            self._queuedSwitch = { mapPath = dest.mapPath, x = spawnX, y = spawnY }
            self.cooldown = 0.25
          else
            print(string.format('[Transitions] No destination for %s', tostring(name)))
          end
        end
        break
      end
    end
  end
  touch(a, b)
  touch(b, a)
end

-- Commented out endContact - no longer needed for immediate transitions
--[[
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
--]]

return LevelTransitions
