---@diagnostic disable: undefined-global
-- map.lua: Centralizes STI map loading, Box2D world creation, and entity spawning/positions.
-- Inspired by your example structure: Map:load/init/update/draw and a spawnEntities() that reads Tiled.

local sti = require("sti")
local Player = require("player")
local Ball = require("ball")
local Box = require("box")
local Chain = require("chain")
local PlayerTextBox = require("player_text_box")
local Sensors = require("sensor_handler")

local Map = {}
Map.__index = Map

-- Internal state
local state = {
  currentLevel = "tiled/map/1", -- base path without .lua; call Map:setCurrentLevel() to change
  level = nil,         -- STI map
  world = nil,         -- Box2D world
  background = nil,    -- love.graphics Image
  scale = 2,           -- visual scale
  player = nil,        -- Player module instance (module table used by project)
  playerTextBox = nil,
  balls = {},          -- spawned balls
  boxes = {},          -- spawned boxes
  chain = nil,
  chain2 = nil,
  mapWidth = 0,
}

-- Preset sizes by name for simple variants. Edit here to change once for all.
-- Example: every Tiled object named "box1" uses the same width/height, regardless of
-- the object's drawn size in Tiled. Same idea for "box2", "ball1", "ball2".
local presets = {
  box = {
    box1 = { w = 16, h = 16 },
    box2 = { w = 28, h = 28 },
  },
  ball = {
    ball1 = { r = 8 },
    ball2 = { r = 12 },
  }
}

-- Optional registry to spawn custom types (future-proofing): spikes/stone/enemy/coin
-- You can register from anywhere: Map.registerTypeSpawner("coin", function(cx, cy, obj) Coin.new(cx, cy) end)
local typeSpawners = {}

function Map.registerTypeSpawner(t, fn)
  typeSpawners[t] = fn
end

-- Public accessors used by main.lua (for debug and overlays handled in main)
function Map:getWorld() return state.world end
function Map:getLevel() return state.level end
function Map:getPlayer() return state.player end
function Map:getScale() return state.scale end
function Map:getMapWidth() return state.mapWidth end

-- Optional: change or query current level base path (without .lua)
function Map:setCurrentLevel(basePath)
  state.currentLevel = basePath or state.currentLevel
end
function Map:getCurrentLevel()
  return state.currentLevel
end

-- Contact forwarding (to player + Sensors)
local function beginContact(a, b, collision)
  if state.player and state.player.beginContact then
    state.player:beginContact(a, b, collision)
  end
  Sensors.beginContact(a, b)
end

local function endContact(a, b, collision)
  if state.player and state.player.endContact then
    state.player:endContact(a, b, collision)
  end
  Sensors.endContact(a, b)
end

local function ensureSensorLayersCollidable(level)
  if level and level.layers then
    for _, layer in ipairs(level.layers) do
      if layer.type == 'objectgroup' and (layer.name == 'sensor' or layer.name == 'sensors') then
        layer.properties = layer.properties or {}
        if layer.properties.collidable ~= true then
          layer.properties.collidable = true
          print("[STI] Enabled collidable=true for '" .. layer.name .. "' layer at runtime")
        end
        if layer.objects then
          for _, obj in ipairs(layer.objects) do
            obj.properties = obj.properties or {}
            if obj.properties.collidable ~= true then
              obj.properties.collidable = true
            end
          end
        end
      end
    end
  end
end

local function mergeLayerPropsAndForceSensors(level)
  if level and level.box2d_collision then
    local merged, sensors = 0, 0
    for _, c in ipairs(level.box2d_collision) do
      if c and c.fixture then
        local ud = c.fixture:getUserData() or {}
        local props = {}
        if type(ud.properties) == 'table' then
          for k,v in pairs(ud.properties) do props[k] = v end
        end
        local layerProps = (c.object and c.object.layer and c.object.layer.properties) or nil
        if type(layerProps) == 'table' then
          for k,v in pairs(layerProps) do if props[k] == nil then props[k] = v end end
          -- If declared as a trigger (sensor1) ensure sensor behavior
          if props.sensor1 == true then c.fixture:setSensor(true) end
        end
        ud.properties = props
        c.fixture:setUserData(ud)
        if props and props.sensor1 then sensors = sensors + 1 end
        merged = merged + 1
      end
    end
    print(string.format("[STI] Fixtures: %d, sensor1 fixtures: %d", merged, sensors))
  end
end

local function hideDebugLayers(level)
  if not level then return end
  if level.layers.solid then level.layers.solid.visible = false end
  if level.layers.sensor then level.layers.sensor.visible = false end
  if level.layers.sensors then level.layers.sensors.visible = false end
end

-- Method: spawn entities from Tiled entity layer
function Map:spawnEntities()
  local level = state.level
  local layer = (self.entityLayer) or (level and level.layers and level.layers.entity) or nil
  if not layer or not layer.objects then return end

  -- Clear existing spawns if re-initializing
  state.balls = {}
  state.boxes = {}

  for _, obj in ipairs(layer.objects) do
    -- Center coordinates: always use the object's position + half-size for placement,
    -- but NEVER use the object's width/height as the physics size for balls/boxes.
    local ox, oy = obj.x, obj.y
    local ow, oh = obj.width or 0, obj.height or 0
    local cx, cy = ox + ow / 2, oy + oh / 2

    -- Future entities: if obj.type is set, dispatch to registered spawner.
    if obj.type and obj.type ~= "" then
      local spawner = typeSpawners[obj.type]
      if spawner then spawner(cx, cy, obj) end
      goto continue
    end

    -- Normalize the name (e.g., "Box1" -> "box1") for preset lookup
    local rawName = obj.name or ""
    local name = rawName:lower():gsub("^%s*(.-)%s*$", "%1")

    if obj.shape == 'rectangle' then
      -- Use per-name preset width/height; fallback to a small box if unknown
      local cfg = presets.box[name]
      local w = (cfg and cfg.w) or 16
      local h = (cfg and cfg.h) or 16
      table.insert(state.boxes, Box.new(state.world, cx, cy, w, h, { type = 'dynamic', restitution = 0.2 }))
    elseif obj.shape == 'ellipse' then
      -- Use per-name preset radius; fallback to a small radius if unknown
      local cfg = presets.ball[name]
      local r = (cfg and cfg.r) or 8
      table.insert(state.balls, Ball.new(state.world, cx, cy, r, { restitution = 0.6, friction = 0.4 }))
    end

    ::continue::
  end
end

-- Initialize map/layers and spawn entities (pattern similar to your example)
function Map:init()
  -- Load STI map for the current level
  local base = state.currentLevel or "tiled/map/1"
  local path = base:match("%.lua$") and base or (base .. ".lua")
  state.level = sti(path, { "box2d" })

  -- Ensure sensor layers are collidable, then initialize Box2D colliders
  ensureSensorLayersCollidable(state.level)
  ---@diagnostic disable-next-line: undefined-field
  state.level:box2d_init(state.world)
  mergeLayerPropsAndForceSensors(state.level)

  -- Layer refs commonly used
  ---@diagnostic disable-next-line: undefined-field
  self.solidLayer = state.level.layers and state.level.layers.solid or nil
  ---@diagnostic disable-next-line: undefined-field
  self.entityLayer = state.level.layers and state.level.layers.entity or nil

  -- Try to find a ground tile layer by name or fallback to first tilelayer
  ---@diagnostic disable-next-line: undefined-field
  self.groundLayer = (state.level.layers and (state.level.layers.ground or state.level.layers["Tile Layer 1"])) or nil
  if not self.groundLayer then
    ---@diagnostic disable-next-line: undefined-field
    for _, layer in ipairs(state.level.layers or {}) do
      if layer.type == "tilelayer" then self.groundLayer = layer; break end
    end
  end

  -- Visibility: hide collision/debug/object layers
  local solidLayer = self.solidLayer
  local entityLayer = self.entityLayer
  ---@diagnostic disable-next-line: undefined-field
  if solidLayer then solidLayer.visible = false end
  ---@diagnostic disable-next-line: undefined-field
  if entityLayer then entityLayer.visible = false end
  hideDebugLayers(state.level)

  -- Map width in pixels (exported like your example via global MapWidth), plus internal copy
  ---@diagnostic disable-next-line: undefined-field
  local tilew = state.level.tilewidth or 16
  ---@diagnostic disable-next-line: undefined-field
  local tilesWide = (self.groundLayer and self.groundLayer.width) or state.level.width or 0
  state.mapWidth = tilesWide * tilew
  MapWidth = state.mapWidth -- optional global for external use (matches your snippet)

  -- Spawn entities now that layers are ready
  self:spawnEntities()
end

function Map:load(scale)
  state.scale = scale or state.scale

  -- Create physics world
  state.world = love.physics.newWorld(0, 1200)
  ---@diagnostic disable-next-line: undefined-field
  state.world:setCallbacks(beginContact, endContact)

  -- Initialize map, layers, and spawn entities
  self:init()

  -- Background
  state.background = love.graphics.newImage("asets/sprites/background.png")

  -- Player
  state.player = Player
  state.player:load(state.world, 64, 64)

  -- Sensors (DebugMenu is initialized in main and is independent of Map)
  Sensors.init(state.world, state.level, function()
    return state.player and state.player.physics and state.player.physics.fixture or nil
  end)

  -- Example sensor callbacks
  Sensors.onEnter.sensor1 = function()
    if state.playerTextBox and state.playerTextBox.show then state.playerTextBox:show("Sensor1 hit!", 2) end
    print("[Sensor1] ENTER")
  end
  Sensors.onExit.sensor1 = function() print("[Sensor1] EXIT") end

  -- Example sensor2 callbacks for testing
  Sensors.onEnter.sensor2 = function()
    if state.playerTextBox and state.playerTextBox.show then state.playerTextBox:show("Sensor2 hit!", 2) end
    print("[Sensor2] ENTER")
  end
  Sensors.onExit.sensor2 = function() print("[Sensor2] EXIT") end

  -- Player text box
  state.playerTextBox = PlayerTextBox.new(state.player)

  -- Entities spawned during init via self:spawnEntities()

  -- Chains (manual anchors for now)
  state.chain = Chain.new(state.world, 220, 1, 8, 16, 6, { group = -1 })
  state.chain2 = Chain.new(state.world, 300, 1, 8, 16, 6, { group = -2, dragTarget = 'both', endAnchored = true, color = {0.8, 0.9, 0.8, 1} })
end

function Map:update(dt)
  ---@diagnostic disable-next-line: undefined-field
  if state.level and state.level.update then state.level:update(dt) end
  ---@diagnostic disable-next-line: undefined-field
  if state.level and state.level.box2d_update then state.level:box2d_update(dt) end
  ---@diagnostic disable-next-line: undefined-field
  if state.world then state.world:update(dt) end

  if state.player and state.player.update then state.player:update(dt) end
  for _, b in ipairs(state.balls) do if b.update then b:update(dt) end end
  for _, b in ipairs(state.boxes) do if b.update then b:update(dt) end end
  if state.chain and state.chain.update then state.chain:update(dt) end
  if state.chain2 and state.chain2.update then state.chain2:update(dt) end
  if state.playerTextBox and state.playerTextBox.update then state.playerTextBox:update(dt) end
end

function Map:draw()
  -- Background (unscaled)
  love.graphics.draw(state.background)

  love.graphics.push()
  ---@diagnostic disable-next-line: undefined-field
  if state.level and state.level.draw then
    ---@diagnostic disable-next-line: undefined-field
    state.level:draw(0, 0, state.scale, state.scale)
  end
  love.graphics.scale(state.scale, state.scale)

  -- Optional world-space overlay (e.g., debug colliders). Provided by main via setter.
  if self._worldOverlayDrawFn then self._worldOverlayDrawFn() end

  if state.chain and state.chain.draw then state.chain:draw() end
  if state.chain2 and state.chain2.draw then state.chain2:draw() end
  for _, b in ipairs(state.balls) do if b.draw then b:draw() end end
  for _, b in ipairs(state.boxes) do if b.draw then b:draw() end end
  if state.player and state.player.draw then state.player:draw() end

  if state.playerTextBox and state.playerTextBox.draw then state.playerTextBox:draw() end
  love.graphics.pop()

end

-- Allow consumers to register a function that draws world-space overlays inside the scaled block
function Map:setWorldOverlayDrawFn(fn)
  self._worldOverlayDrawFn = fn
end

function Map:keypressed(key)
  if key == 'r' then
    local meter = love.physics.getMeter()
    if state.player and state.player.physics and state.player.physics.body then
      state.player.physics.body:setLinearVelocity(0,0)
      state.player.physics.body:setPosition(64 / meter, 64 / meter)
    end
  elseif key == 'escape' then
    love.event.quit()
  end
  if state.player and state.player.keypressed then
    state.player:keypressed(key)
  end
end

function Map:mousepressed(x, y, button)
  local sx, sy = x / state.scale, y / state.scale
  local captured = false
  if state.chain2 and state.chain2.isMouseOver and state.chain2.mousepressed then
    if state.chain2:isMouseOver(sx, sy) then
      state.chain2:mousepressed(sx, sy, button)
      captured = true
    end
  end
  if (not captured) and state.chain and state.chain.isMouseOver and state.chain.mousepressed then
    if state.chain:isMouseOver(sx, sy) then
      state.chain:mousepressed(sx, sy, button)
      captured = true
    end
  end
end

function Map:mousereleased(x, y, button)
  local sx, sy = x / state.scale, y / state.scale
  if state.chain and state.chain.mousereleased then state.chain:mousereleased(sx, sy, button) end
  if state.chain2 and state.chain2.mousereleased then state.chain2:mousereleased(sx, sy, button) end
end

function Map:mousemoved(x, y, dx, dy)
  local sx, sy = x / state.scale, y / state.scale
  if state.chain and state.chain.mousemoved then state.chain:mousemoved(sx, sy, dx / state.scale, dy / state.scale) end
  if state.chain2 and state.chain2.mousemoved then state.chain2:mousemoved(sx, sy, dx / state.scale, dy / state.scale) end
end

return Map
